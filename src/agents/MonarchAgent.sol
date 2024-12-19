// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IMonarchAgent, RebalanceMarketParams} from "../interfaces/IMonarchAgent.sol";
import {IMorpho, Id, MarketParams, Position, Signature, Authorization} from "morpho-blue/src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {Multicall} from "openzeppelin/utils/Multicall.sol";

/**
 * @title MonarchAgent
 * @notice MonarchAgent is a contract designed to work for Morpho Blue
 */
contract MonarchAgentV1 is IMonarchAgent, Multicall {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable morphoBlue;

    /// @notice only rebalancers can rebalance users' positions on their behalf
    mapping(address user => address rebalancer) public rebalancers;

    /// @notice rebalancers can only rebalance to enabled market
    mapping(address user => mapping(bytes32 marketId => uint256 cap)) public marketCap;

    /* CONSTRUCTOR */

    constructor(address _morphoBlue) {
        require(_morphoBlue != address(0), ErrorsLib.ZERO_ADDRESS);
        morphoBlue = IMorpho(_morphoBlue);
    }

    /* MODIFIERS */

    /// @dev Prevents a function to be called by an unauthorized rebalancer.
    modifier onlyRebalancer(address onBehalf) {
        require(onBehalf == msg.sender || rebalancers[onBehalf] == msg.sender, ErrorsLib.UNAUTHORIZED_REBALANCER);
        _;
    }

    /* EXTERNAL */

    /**
     * @notice Users need to explicitly set which addresses can call the rebalance function on their behalf
     * @param rebalancer The user to delegate the rebalance function to
     */
    function authorize(address rebalancer) external {
        rebalancers[msg.sender] = rebalancer;

        emit RebalancerSet(msg.sender, rebalancer);
    }

    /**
     * @notice Users can revoke the authorization of a rebalancer
     */
    function revoke() external {
        delete rebalancers[msg.sender];

        emit RebalancerSet(msg.sender, address(0));
    }

    /**
     * @notice Authorize this contract to manage a user's position on MorphoBlue with signature
     * @dev The function is added here for batched setup. All verification is done in Morpho.sol
     * @param authorization The `Authorization` struct.
     * @param signature The signature.
     */
    function setMorphoAuthorization(Authorization calldata authorization, Signature calldata signature) external {
        morphoBlue.setAuthorizationWithSig(authorization, signature);
    }

    /**
     * @notice enable rebalancers to rebalance to specific market ids
     * @param marketIds array of market id
     * @param caps array of market cap
     */
    function batchConfigMarkets(bytes32[] calldata marketIds, uint256[] calldata caps) external {
        require(marketIds.length == caps.length, ErrorsLib.INVALID_LENGTH);
        for (uint256 i; i < marketIds.length; i++) {
            marketCap[msg.sender][marketIds[i]] = caps[i];

            emit MarketConfigured(msg.sender, marketIds[i], caps[i]);
        }
    }

    /**
     * @notice Rebalance the user's position from one set of markets to another
     * @param onBehalf The user to rebalance the position for
     * @param token The token to rebalance
     * @param fromMarkets The markets to withdraw assets from
     * @param toMarkets The markets to supply assets to
     */
    function rebalance(
        address onBehalf,
        address token,
        RebalanceMarketParams[] calldata fromMarkets,
        RebalanceMarketParams[] calldata toMarkets
    ) external payable onlyRebalancer(onBehalf) {
        require(fromMarkets.length > 0 && toMarkets.length > 0, ErrorsLib.ZERO_MARKET);

        uint256 tokenDelta;

        for (uint256 i; i < fromMarkets.length; ++i) {
            require(fromMarkets[i].market.loanToken == token, ErrorsLib.INVALID_TOKEN);
            (uint256 assetsWithdrawn,) =
                morphoBlue.withdraw(fromMarkets[i].market, fromMarkets[i].assets, fromMarkets[i].shares, onBehalf, address(this));
            tokenDelta += assetsWithdrawn;
        }

        _approveMaxTo(token, address(morphoBlue));

        for (uint256 i; i < toMarkets.length; ++i) {
            require(toMarkets[i].market.loanToken == token, ErrorsLib.INVALID_TOKEN);

            // It might be hard to calculate exactly how much amount should be specified due to interest, So we allow putting max(uin256)
            // to put in all remaining delta.
            uint256 assetsToUse = toMarkets[i].assets == type(uint256).max ? tokenDelta : toMarkets[i].assets;
            uint256 assetsSupplied = _supplyAndCheckCap(toMarkets[i].market, assetsToUse, toMarkets[i].shares, onBehalf);
            tokenDelta -= assetsSupplied;
        }

        require(tokenDelta == 0, ErrorsLib.DELTA_NON_ZERO);

        emit Rebalance(onBehalf, token, fromMarkets, toMarkets);
    }

    /// @dev Gives the max approval to spender to spend the given asset if not already approved.
    /// @dev Assumes that type(uint256).max is large enough to never have to increase the allowance again.
    function _approveMaxTo(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }

    /// @dev supply asset on behalf of user and check if the cap is exceeded
    /// @dev returns total assets supplied
    function _supplyAndCheckCap(MarketParams memory market, uint256 assets, uint256 shares, address onBehalf)
        internal
        returns (uint256 assetsSupplied)
    {
        Id marketId = market.id();

        uint256 sharesSupplied;
        (assetsSupplied, sharesSupplied) = morphoBlue.supply(market, assets, shares, onBehalf, bytes(""));

        // the final supplied asset cannot exceed the cap if set
        Position memory position = morphoBlue.position(marketId, onBehalf);
        uint256 totalSupplyAssets = position.supplyShares * assetsSupplied / sharesSupplied;

        require(marketCap[onBehalf][Id.unwrap(marketId)] >= totalSupplyAssets, ErrorsLib.CAP_EXCEEDED);
    }
}
