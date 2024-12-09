// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {AgentTestBase} from "test/shared/AgentTestBase.t.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

contract AgentSetCapTest is AgentTestBase {
    function setUp() public override {
        super.setUp();
    }

    function test_SetCap() public {
        address user = address(0x1);

        vm.startPrank(user);
        bytes32 marketId = keccak256(abi.encode("mock market"));

        bytes32[] memory markets = new bytes32[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = marketId;
        caps[0] = 1000;
        agent.batchConfigMarkets(markets, caps);
        vm.stopPrank();

        assertEq(agent.marketCap(user, marketId), caps[0]);
    }

    function test_SetCap_Batch() public {
        address user = address(0x1);

        vm.startPrank(user);
        bytes32[] memory markets = new bytes32[](2);
        uint256[] memory caps = new uint256[](2);
        markets[0] = keccak256(abi.encode("mock market 1"));
        caps[0] = 1000;
        markets[1] = keccak256(abi.encode("mock market 2"));
        caps[1] = 2000;
        agent.batchConfigMarkets(markets, caps);
        vm.stopPrank();

        assertEq(agent.marketCap(user, markets[0]), caps[0]);
        assertEq(agent.marketCap(user, markets[1]), caps[1]);
    }

    function test_RevertIf_LengthMismatch() public {
        address user = address(0x1);

        vm.startPrank(user);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        agent.batchConfigMarkets(new bytes32[](0), new uint256[](1));
        vm.stopPrank();
    }
}
