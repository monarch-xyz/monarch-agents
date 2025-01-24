// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {MonarchAgentV1} from "../../src/agents/MonarchAgent.sol";
import {BaseTest} from "morpho-blue/test/forge/BaseTest.sol";
import {MarketParamsLib, Id} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {MarketParams} from "morpho-blue/src/interfaces/IMorpho.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";

contract AgentTestBase is BaseTest {
    using MarketParamsLib for MarketParams;

    MonarchAgentV1 public agent;

    function setUp() public virtual override {
        super.setUp();
        _setUpAgent(address(morpho));
    }

    function _setUpAgent(address morphoBlue) internal {
        agent = new MonarchAgentV1(morphoBlue);
    }

    function _enableMarket(address user, MarketParams memory market) internal {
        _setMarketCap(user, market, type(uint256).max);
    }

    function _createMarket(uint256 lltv) internal returns (MarketParams memory) {
        _setLltv(lltv);
        return MarketParams(address(loanToken), address(collateralToken), address(oracle), address(irm), lltv);
    }

    function _createAndEnableMarket(address user, uint256 lltv) internal returns (MarketParams memory market) {
        market = _createMarket(lltv);
        _enableMarket(user, market);
    }

    function _createAndEnableMarketFake(address user, uint256 lltv, address fakeAgent)
        internal
        returns (MarketParams memory market)
    {
        market = _createMarket(lltv);

        vm.startPrank(user);
        bytes32 marketId = Id.unwrap(market.id());
        bytes32[] memory markets = new bytes32[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = marketId;
        caps[0] = type(uint256).max;
        FakeAgent(fakeAgent).batchConfigMarkets(markets, caps);
        vm.stopPrank();
    }

    function _setMarketCap(address user, MarketParams memory market, uint256 cap) internal {
        vm.startPrank(user);
        bytes32 marketId = Id.unwrap(market.id());
        bytes32[] memory markets = new bytes32[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = marketId;
        caps[0] = cap;
        agent.batchConfigMarkets(markets, caps);
        vm.stopPrank();
    }

    function _supplyMorpho(MarketParams memory market, uint256 assets, uint256 shares, address user) internal {
        vm.startPrank(user);
        loanToken.approve(address(morpho), type(uint256).max);
        morpho.supply(market, assets, shares, user, hex"");
        vm.stopPrank();
    }

    function _setMorphoAuthorization(address user, address authorized, bool newIsAuthorized) internal {
        vm.startPrank(user);
        morpho.setAuthorization(authorized, newIsAuthorized);
        vm.stopPrank();
    }

    function _authorizeRebalancer(address user, address rebalancer) internal {
        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();
    }
}

contract FakeAgent is MonarchAgentV1 {
    using SafeTransferLib for ERC20;

    constructor(address morphoBlue) MonarchAgentV1(morphoBlue) {}

    function approve(address asset, address spender) public {
        ERC20(asset).safeApprove(spender, 1);
    }
}
