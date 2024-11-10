// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { AgentTestBase } from "test/shared/AgentTestBase.t.sol";

contract AgentAuthorizeTest is AgentTestBase {
    function setUp() public override {
        super.setUp();
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
