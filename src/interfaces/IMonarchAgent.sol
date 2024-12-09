// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";

struct RebalanceMarketParams {
    MarketParams market;
    uint256 assets;
    uint256 shares;
}

interface IMonarchAgent {
    /// @notice Emitted when a rebalancer is set for a user
    event RebalancerSet(address indexed user, address indexed rebalancer);

    /// @notice Emitted when a market is enabled for a user
    event MarketConfigured(address indexed user, bytes32 indexed marketId, uint256 cap);

    /// @notice Emitted when a rebalancing operation is performed
    event Rebalance(
        address indexed user, address indexed token, RebalanceMarketParams[] fromMarkets, RebalanceMarketParams[] toMarkets
    );

    /// @notice Authorizes a rebalancer address to perform rebalancing operations on behalf of the caller
    /// @param rebalancer The address to be authorized as a rebalancer
    function authorize(address rebalancer) external;

    /// @notice Revokes the current rebalancer's authorization
    function revoke() external;

    /// @notice Performs a rebalancing operation between markets
    /// @param onBehalf The address for which the rebalancing is being performed
    /// @param token The address of the token being rebalanced
    /// @param fromMarkets Array of markets to withdraw from, including market params, assets, and shares
    /// @param toMarkets Array of markets to supply to, including market params, assets, and shares
    /// @dev This function handles the movement of assets between different Morpho Blue markets
    function rebalance(
        address onBehalf,
        address token,
        RebalanceMarketParams[] calldata fromMarkets,
        RebalanceMarketParams[] calldata toMarkets
    ) external payable;
}
