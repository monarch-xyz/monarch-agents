// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";

struct RebalanceMarketParams {
    MarketParams market;
    uint256 assets;
    uint256 shares;
}

interface IMonarchAgent {
    event RebalancerSet(address indexed user, address indexed rebalancer);

    event MarketEnabled(address indexed user, bytes32 indexed marketId, bool enabled);

    function authorize(address rebalancer) external;
    function revoke() external;
    function rebalance(
        address onBehalf,
        address token,
        RebalanceMarketParams[] calldata fromMarkets,
        RebalanceMarketParams[] calldata toMarkets
    ) external payable;
}
