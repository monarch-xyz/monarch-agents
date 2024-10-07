// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {IMonarchAgent} from "../interfaces/IMonarchAgent.sol";
import {IMorpho} from "morpho-blue/src/interfaces/IMorpho.sol";
/**
 * @title MonarchAgent
 * @notice MonarchAgent is a contract designed to work for Morpho Blue
 */

contract MonarchAgentV1 is IMonarchAgent {
    IMorpho public immutable morphoBlue;

    /// @notice only rebalancers can rebalance users' positions on their behalf
    mapping(address user => address rebalancer) public rebalancers;

    constructor(address _morphoBlue) {
        morphoBlue = IMorpho(_morphoBlue);
    }

    /**
     * @notice Users need to explicitly set which addresses can call the rebalance function on their behalf
     * @param rebalancer The user to delegate the rebalance function to
     */
    function authorize(address rebalancer) external {
        rebalancers[msg.sender] = rebalancer;

        emit RebalancerSet(msg.sender, rebalancer);
    }
}
