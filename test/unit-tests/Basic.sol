// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MonarchAgentV1} from "../../src/agents/MonarchAgent.sol";
import {BaseTest} from "morpho-blue/test/forge/BaseTest.sol";

contract AgentTest is BaseTest {
    MonarchAgentV1 public agent;

    function setUp() public override {
        super.setUp();
        agent = new MonarchAgentV1(address(morpho));
    }

    function test_SetRebalancer() public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        vm.prank(user);
        agent.authorize(rebalancer);

        assertEq(agent.rebalancers(user), rebalancer);
    }

    function test_RevokeRebalancer() public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        agent.revoke();

        vm.stopPrank();
        assertEq(agent.rebalancers(user), address(0));
    }
}
