// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {AgentTestBase} from "test/shared/AgentTestBase.t.sol";
import {SigUtils} from "morpho-blue/test/forge/helpers/SigUtils.sol";
import {Authorization, Signature} from "morpho-blue/src/interfaces/IMorpho.sol";

contract BatchSetupTest is AgentTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_BatchSetup() public {
        // setup a new user
        uint privateKey = 0xBEEF;
        address user = vm.addr(privateKey);
        address rebalancer = address(0x2);

        bytes[] memory data = new bytes[](3);

        // data[1]: authorize agent on morphoBlue
        (Authorization memory authorization, Signature memory sig) = _signMorphoAuthorization(privateKey);
        data[0] = abi.encodeWithSelector(agent.setMorphoAuthorization.selector, authorization, sig);

        // data[2]: authorize rebalancer on agent
        data[1] = abi.encodeWithSelector(agent.authorize.selector, rebalancer);

        // data[3]: set caps
        bytes32 marketId = keccak256(abi.encode("mock market"));
        bytes32[] memory markets = new bytes32[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = marketId;
        caps[0] = 1000;
        data[2] = abi.encodeWithSelector(agent.batchConfigMarkets.selector, markets, caps);

        vm.startPrank(user);
        agent.multicall(data);
        vm.stopPrank();

        // Assertions
        assertEq(morpho.isAuthorized(user, address(agent)), true);
        assertEq(agent.rebalancers(user), rebalancer);
        assertEq(agent.marketCap(user, marketId), caps[0]);
    }

    function _signMorphoAuthorization(uint pk) internal returns (Authorization memory authorization, Signature memory sig) {
        // setup user
        address user = vm.addr(pk);

        authorization.authorizer = user;
        authorization.authorized = address(agent);
        authorization.isAuthorized = true;
        authorization.deadline = block.timestamp + 86400;
        authorization.nonce = morpho.nonce(user);

        bytes32 digest = SigUtils.getTypedDataHash(morpho.DOMAIN_SEPARATOR(), authorization);
        (sig.v, sig.r, sig.s) = vm.sign(pk, digest);

        return (authorization, sig);
    }
}
