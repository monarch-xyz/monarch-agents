// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {AgentTestBase} from "test/shared/AgentTestBase.t.sol";
import {SigUtils} from "morpho-blue/test/forge/helpers/SigUtils.sol";
import {Authorization, Signature} from "morpho-blue/src/interfaces/IMorpho.sol";

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

    function test_SetMorphoAuth() public {
        // setup a new user
        uint256 privateKey = 0xBEEF;
        address user = vm.addr(privateKey);

        // set authorization and sign the signature
        Authorization memory authorization;

        authorization.authorizer = user;
        authorization.authorized = address(agent);
        authorization.isAuthorized = true;
        authorization.deadline = block.timestamp + 86400;
        authorization.nonce = 0;

        Signature memory sig;
        bytes32 digest = SigUtils.getTypedDataHash(morpho.DOMAIN_SEPARATOR(), authorization);
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        vm.startPrank(user);
        agent.setMorphoAuthorization(authorization, sig);
        vm.stopPrank();

        assertEq(morpho.isAuthorized(user, address(agent)), true);
    }
}
