// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {MarketParams, RebalanceMarketParams} from "../../src/interfaces/IMonarchAgent.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {AgentTestBase, FakeAgent} from "test/shared/AgentTestBase.t.sol";

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

    function test_MorphoZeroAddress() public {
        address fakeMorpho = address(0);
        vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
        _setUpAgent(fakeMorpho);
    }

    function test_RebalanceUnAuthorizedRebalancer(uint256 totalSupplyAmount) public {
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

    function test_RevertIf_RebalanceFromMarketInvalidToken(uint256 totalSupplyAmount) public {
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

    function test_RevertIf_RebalanceToMarketInvalidToken(uint256 totalSupplyAmount) public {
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

    function test_RevertIf_RebalanceToNewMarket(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParams(lltv_90, lltv_80, withdrawAmount, 0, supplyAmount, 0);

        // swap the toMarket to an unauthorized market
        MarketParams memory lltv_99 = _createMarket(0.99e18);
        to_markets[0] = RebalanceMarketParams(lltv_99, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);

        vm.expectRevert(bytes(ErrorsLib.CAP_EXCEEDED));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function test_RevertIf_RebalanceZeroMarket(uint256 totalSupplyAmount) public {
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

    function test_RevertIf_RebalanceDeltaNonZero(uint256 totalSupplyAmount, uint256 supplyAmount) public {
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

    function test_RebalanceByShares(uint256 totalSupplyAmount) public {
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

    function test_RebalanceApprovalDepleted(uint256 totalSupplyAmount) public {
        FakeAgent fakeAgent = new FakeAgent(address(morpho));
        vm.startPrank(user);
        morpho.setAuthorization(address(fakeAgent), true);
        fakeAgent.authorize(rebalancer);
        vm.stopPrank();

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        uint256 lltv1 = lltv_90;
        uint256 lltv2 = lltv_80;

        MarketParams memory market1 = _createAndEnableMarketFake(user, lltv1, address(fakeAgent));
        MarketParams memory market2 = _createAndEnableMarketFake(user, lltv2, address(fakeAgent));

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](1);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](1);
        from_markets[0] = RebalanceMarketParams(market1, withdrawAmount, 0);
        to_markets[0] = RebalanceMarketParams(market2, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        fakeAgent.approve(address(loanToken), address(morpho));
        vm.prank(rebalancer);
        vm.expectRevert();
        fakeAgent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function test_RebalanceMultipleMarkets(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount1 = totalSupplyAmount / 2;
        uint256 withdrawAmount2 = totalSupplyAmount - withdrawAmount1;

        uint256 supplyAmount1;
        supplyAmount1 = bound(supplyAmount1, 1, totalSupplyAmount - 1);
        uint256 supplyAmount2 = totalSupplyAmount - supplyAmount1;

        MarketParams memory market1 = _createMarket(0.9e18);
        MarketParams memory market2 = _createMarket(0.8e18);

        // create + set maximize cap
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

    function test_RebalanceMultipleMarkets_WithMaxUintAmount(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount1 = totalSupplyAmount / 2;
        uint256 withdrawAmount2 = totalSupplyAmount - withdrawAmount1;

        uint256 supplyAmount1;
        supplyAmount1 = bound(supplyAmount1, 1, totalSupplyAmount - 1);

        MarketParams memory market1 = _createMarket(0.9e18);
        MarketParams memory market2 = _createMarket(0.8e18);

        // create + set maximize cap
        MarketParams memory market3 = _createAndEnableMarket(user, 0.85e18);

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](2);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](1);

        from_markets[0] = RebalanceMarketParams(market1, withdrawAmount1, 0);
        from_markets[1] = RebalanceMarketParams(market2, withdrawAmount2, 0);
        to_markets[0] = RebalanceMarketParams(market3, type(uint256).max, 0);

        _supplyMorpho(market1, withdrawAmount1, 0, user);
        _supplyMorpho(market2, withdrawAmount2, 0, user);

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function test_RevertIf_RebalanceCapExceeded(uint256 totalSupplyAmount) public {
        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000_000000);
        loanToken.setBalance(user, totalSupplyAmount);

        MarketParams memory market1 = _createMarket(0.9e18);
        MarketParams memory market2 = _createMarket(0.8e18);

        // only allow half of the total supply to be supplied to market2
        _setMarketCap(user, market2, totalSupplyAmount / 2);

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](1);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](1);

        from_markets[0] = RebalanceMarketParams(market1, totalSupplyAmount, 0);
        to_markets[0] = RebalanceMarketParams(market2, totalSupplyAmount, 0);

        _supplyMorpho(market1, totalSupplyAmount, 0, user);

        vm.prank(rebalancer);
        vm.expectRevert(bytes(ErrorsLib.CAP_EXCEEDED));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }
}
