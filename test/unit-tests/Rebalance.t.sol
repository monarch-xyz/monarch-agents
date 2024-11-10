// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {MarketParams, RebalanceMarketParams} from "../../src/interfaces/IMonarchAgent.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {AgentTestBase} from "test/shared/AgentTestBase.t.sol";

contract AgentRebalanceTest is AgentTestBase {
    using MarketParamsLib for MarketParams;

    address immutable user = address(0x1);
    address immutable rebalancer = address(0x2);

    uint256 constant lltv_90 = 0.9e18;
    uint256 constant lltv_80 = 0.8e18;

    function setUp() public override {
        super.setUp();

        // all tests here assume already authorizing rebalancer
        _setMorphoAuthorization(user, address(agent), true);

        // authorize rebalancer at the agent level for rebalancing
        _authorizeRebalancer(user, rebalancer);
    }

    function _prepareRebalanceMarketParams(
        uint256 lltv1,
        uint256 lltv2,
        uint256 withdrawAmount,
        uint256 withdrawShares,
        uint256 supplyAmount,
        uint256 supplyShares
    ) internal returns (RebalanceMarketParams[] memory, RebalanceMarketParams[] memory) {
        MarketParams memory market1 = _createAndEnableMarket(user, lltv1);
        MarketParams memory market2 = _createAndEnableMarket(user, lltv2);

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](1);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](1);
        from_markets[0] = RebalanceMarketParams(market1, withdrawAmount, withdrawShares);
        to_markets[0] = RebalanceMarketParams(market2, supplyAmount, supplyShares);

        return (from_markets, to_markets);
    }

    function testMorphoZeroAddress() public {
        address fakeMorpho = address(0);
        vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
        _setUpAgent(fakeMorpho);
    }

    function testRebalanceUnAuthorizedRebalancer(uint256 totalSupplyAmount) public {
        address unauthorized = address(0x3);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(unauthorized);
        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_REBALANCER));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceFromMarketInvalidToken(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);
        for (uint256 i; i < from_markets.length; ++i) {
            from_markets[i].market.loanToken = address(collateralToken);
        }
        vm.expectRevert(bytes(ErrorsLib.INVALID_TOKEN));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceToMarketInvalidToken(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);
        for (uint256 i; i < to_markets.length; ++i) {
            to_markets[i].market.loanToken = address(collateralToken);
        }
        vm.expectRevert(bytes(ErrorsLib.INVALID_TOKEN));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceZeroMarket(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets,) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);
        vm.expectRevert(bytes(ErrorsLib.ZERO_MARKET));
        RebalanceMarketParams[] memory empty;
        agent.rebalance(user, address(loanToken), empty, empty);
    }

    function testRebalanceDeltaNonZero(uint256 totalSupplyAmount, uint256 supplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        supplyAmount = bound(supplyAmount, 1, withdrawAmount - 1);

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);
        vm.expectRevert(bytes(ErrorsLib.DELTA_NON_ZERO));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceByShares(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawShares;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, 0, withdrawShares, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        withdrawShares = morpho.position(from_markets[0].market.id(), user).supplyShares;
        from_markets[0].shares = withdrawShares;

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function test_Rebalance(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceMultipleMarkets(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount1 = totalSupplyAmount / 2;
        uint256 withdrawAmount2 = totalSupplyAmount - withdrawAmount1;

        uint256 supplyAmount1;
        supplyAmount1 = bound(supplyAmount1, 1, totalSupplyAmount - 1);
        uint256 supplyAmount2 = totalSupplyAmount - supplyAmount1;

        MarketParams memory market1 = _createAndEnableMarket(user, 0.9e18);
        MarketParams memory market2 = _createAndEnableMarket(user, 0.8e18);
        MarketParams memory market3 = _createAndEnableMarket(user, 0.85e18);
        MarketParams memory market4 = _createAndEnableMarket(user, 0.7e18);

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](2);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](2);

        from_markets[0] = RebalanceMarketParams(market1, withdrawAmount1, 0);
        from_markets[1] = RebalanceMarketParams(market2, withdrawAmount2, 0);
        to_markets[0] = RebalanceMarketParams(market3, supplyAmount1, 0);
        to_markets[1] = RebalanceMarketParams(market4, supplyAmount2, 0);

        _supplyMorpho(market1, withdrawAmount1, 0, user);
        _supplyMorpho(market2, withdrawAmount2, 0, user);

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }
}
