// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IMonarchAgent} from "../interfaces/IMonarchAgent.sol";
import {IMorpho, MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";
import {SafeTransferLib, ERC20} from "lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title MonarchAgent
 * @notice MonarchAgent is a contract designed to work for Morpho Blue
 */
contract MonarchAgentV1 is IMonarchAgent {
    using SafeTransferLib for ERC20;

    /* CONSTANTS */

    address constant UNSET = address(1);

    /* STORAGE */

    /// @notice Keeps track of the agent's latest initiator.
    /// @dev Also prevents interacting with the agent outside of an initiated execution context.
    address private _initiator = UNSET;

    /// @notice The address of the user that is currently being rebalanced.
    address private _onBehalf = UNSET;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable morphoBlue;

    /// @notice only rebalancers can rebalance users' positions on their behalf
    mapping(address user => address rebalancer) public rebalancers;

    /* CONSTRUCTOR */

    constructor(address _morphoBlue) {
        require(_morphoBlue != address(0), "MonarchAgent: ZERO_ADDRESS");
        morphoBlue = IMorpho(_morphoBlue);
    }

    /* MODIFIERS */

    /// @dev Prevents a function to be called by an unauthorized rebalancer.
    modifier onlyRebalancer(address onBehalfOf) {
        require(onBehalfOf == msg.sender || rebalancers[onBehalfOf] == msg.sender, "MonarchAgent: UNAUTHORIZED_REBALANCER");
        _;
    }

    /// @dev Prevents a function to be called outside an initiated `multicall` context and protects a function from
    /// being called by an unauthorized sender inside an initiated multicall context.
    modifier protected() {
        require(_initiator != UNSET, "MonarchAgent: UNAUTHORIZED_CONTEXT");
        require(_isSenderAuthorized(), "MonarchAgent: UNAUTHORIZED_SENDER");

        _;
    }

    /* PUBLIC */

    /// @notice Returns the address of the initiator of the multicall transaction.
    /// @dev Specialized getter to prevent using `_initiator` directly.
    function initiator() public view returns (address) {
        return _initiator;
    }

    /// @notice Returns the address of the user that is currently being rebalanced.
    function onBehalf() public view returns (address) {
        return _onBehalf;
    }

    /*  CALLBACKS */

    function onMorphoSupply(uint256, bytes calldata data) external {
        _callback(data);
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
     * @notice Users can call this function to rebalance their positions
     * @param data The data to be passed to the rebalance function
     */
    function rebalance(address onBehalfOf, bytes[] memory data) external payable onlyRebalancer(onBehalfOf) {
        require(_initiator == UNSET, "MonarchAgent: INITIATOR_ALREADY_SET");
        require(_onBehalf == UNSET, "MonarchAgent: ON_BEHALF_ALREADY_SET");

        _initiator = msg.sender;
        _onBehalf = onBehalfOf;

        _multicall(data);

        _initiator = UNSET;
        _onBehalf = UNSET;
    }

    function morphoWithdraw(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        address receiver
    ) external payable protected {
        (uint256 withdrawnAssets, uint256 withdrawnShares) =
            morphoBlue.withdraw(marketParams, assets, shares, onBehalf(), receiver);

        if (assets > 0) require(withdrawnShares <= slippageAmount, "MonarchAgent: SLIPPAGE_EXCEEDED");
        else require(withdrawnAssets >= slippageAmount, "MonarchAgent: SLIPPAGE_EXCEEDED");
    }

    function morphoSupply(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        uint256 slippageAmount,
        bytes calldata data
    ) external payable protected {
        require(onBehalf() != address(this), "MonarchAgent: INVALID_ON_BEHALF");

        if (assets == type(uint256).max) assets = ERC20(marketParams.loanToken).balanceOf(address(this));

        _approveMaxTo(marketParams.loanToken, address(morphoBlue));

        (uint256 suppliedAssets, uint256 suppliedShares) = morphoBlue.supply(marketParams, assets, shares, onBehalf(), data);

        if (assets > 0) require(suppliedShares >= slippageAmount, "MonarchAgent: SLIPPAGE_EXCEEDED");
        else require(suppliedAssets <= slippageAmount, "MonarchAgent: SLIPPAGE_EXCEEDED");
    }

    /* INTERNAL */

    /// @dev Executes a series of delegate calls to the contract itself.
    /// @dev All functions delegatecalled must be payable if msg.value is non-zero.
    function _multicall(bytes[] memory data) internal {
        for (uint256 i; i < data.length; ++i) {
            (bool success, bytes memory returnData) = address(this).delegatecall(data[i]);
            // No need to check that address(this) has code in case of success.
            if (!success) _revert(returnData);
        }
    }

    /// @dev Bubbles up the revert reason / custom error encoded in returnData.
    /// @dev Assumes returnData is the return data of any kind of failing CALL to a contract.
    function _revert(bytes memory returnData) internal pure {
        uint256 length = returnData.length;
        require(length > 0, "MonarchAgent: REVERT");

        assembly ("memory-safe") {
            revert(add(32, returnData), length)
        }
    }

    /// @dev Triggers _multicall logic during a callback.
    function _callback(bytes calldata data) internal {
        require(msg.sender == address(morphoBlue), "MonarchAgent: UNAUTHORIZED_CALLBACK");

        _multicall(abi.decode(data, (bytes[])));
    }

    /// @dev Returns whether the sender of the call is authorized.
    /// @dev Assumes to be inside a properly initiated `multicall` context.
    function _isSenderAuthorized() internal view virtual returns (bool) {
        return msg.sender == _initiator;
    }

    /// @dev Gives the max approval to spender to spend the given asset if not already approved.
    /// @dev Assumes that type(uint256).max is large enough to never have to increase the allowance again.
    function _approveMaxTo(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }
}
