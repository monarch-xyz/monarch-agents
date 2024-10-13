// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IMonarchAgent, RebalanceMarketParams} from "../interfaces/IMonarchAgent.sol";
import {IMorpho} from "morpho-blue/src/interfaces/IMorpho.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";

/**
 * @title MonarchAgent
 * @notice MonarchAgent is a contract designed to work for Morpho Blue
 */
contract MonarchAgentV1 is IMonarchAgent {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable morphoBlue;

    /// @notice only rebalancers can rebalance users' positions on their behalf
    mapping(address user => address rebalancer) public rebalancers;

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
     * @notice Rebalances the user's position from one set of markets to another
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

        int256 tokenDelta;

        for (uint256 i; i < fromMarkets.length; ++i) {
            require(fromMarkets[i].market.loanToken == token, ErrorsLib.INVALID_TOKEN);
            (uint256 assetsWithdrawn,) =
                morphoBlue.withdraw(fromMarkets[i].market, fromMarkets[i].assets, fromMarkets[i].shares, onBehalf, address(this));
            tokenDelta += int256(assetsWithdrawn);
        }

        _approveMaxTo(token, address(morphoBlue));

        for (uint256 i; i < toMarkets.length; ++i) {
            require(toMarkets[i].market.loanToken == token, ErrorsLib.INVALID_TOKEN);
            (uint256 assetsSupplied,) =
                morphoBlue.supply(toMarkets[i].market, toMarkets[i].assets, toMarkets[i].shares, onBehalf, bytes(""));
            tokenDelta -= int256(assetsSupplied);
        }

        require(tokenDelta == 0, ErrorsLib.DELTA_NON_ZERO);
    }

    /// @dev Gives the max approval to spender to spend the given asset if not already approved.
    /// @dev Assumes that type(uint256).max is large enough to never have to increase the allowance again.
    function _approveMaxTo(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }
}
