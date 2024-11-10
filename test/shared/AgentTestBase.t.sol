// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {MonarchAgentV1} from "../../src/agents/MonarchAgent.sol";
import {BaseTest} from "morpho-blue/test/forge/BaseTest.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {MarketParams, RebalanceMarketParams} from "../../src/interfaces/IMonarchAgent.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

contract AgentTestBase is BaseTest {
    using MarketParamsLib for MarketParams;

    MonarchAgentV1 public agent;

    function setUp() public virtual override {
        super.setUp();
        _setUpAgent(address(morpho));
    }


    function _createMarket(uint256 lltv) internal returns (MarketParams memory) {
        _setLltv(lltv);
        return MarketParams(address(loanToken), address(collateralToken), address(oracle), address(irm), lltv);
    }

    function _supplyMorpho(MarketParams memory market, uint256 assets, uint256 shares, address user) internal {
        vm.startPrank(user);
        loanToken.approve(address(morpho), type(uint256).max);
        morpho.supply(market, assets, shares, user, hex"");
        vm.stopPrank();
    }

    function _setAuthorization(address user, address authorized, bool newIsAuthorized) internal {
        vm.startPrank(user);
        morpho.setAuthorization(authorized, newIsAuthorized);
        vm.stopPrank();
    }

    function _setUpAgent(address morphoBlue) internal {
        agent = new MonarchAgentV1(morphoBlue);
    }
}
