// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MonarchAgentV1} from "../../src/agents/MonarchAgent.sol";
import {BaseTest} from "morpho-blue/test/forge/BaseTest.sol";
import {MarketParamsLib} from "morpho-blue/src/libraries/MarketParamsLib.sol";
import {MarketParams, RebalanceMarketParams} from "../../src/interfaces/IMonarchAgent.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

contract AgentTest is BaseTest {
    using MarketParamsLib for MarketParams;

    MonarchAgentV1 public agent;

    function setUp() public override {
        super.setUp();
        _setUpAgent(address(morpho));
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

    function _prepareRebalanceMarketParms(
        uint256 lltv1,
        uint256 lltv2,
        uint256 withdrawAmount,
        uint256 withdrawShares,
        uint256 supplyAmount,
        uint256 supplyShares
    ) internal returns (RebalanceMarketParams[] memory, RebalanceMarketParams[] memory) {
        MarketParams memory market1 = _createMarket(lltv1);
        MarketParams memory market2 = _createMarket(lltv2);

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](1);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](1);
        from_markets[0] = RebalanceMarketParams(market1, withdrawAmount, withdrawShares);
        to_markets[0] = RebalanceMarketParams(market2, supplyAmount, supplyShares);

        return (from_markets, to_markets);
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

    function testMorphoZeroAddress() public {
        address fakeMorpho = address(0);
        vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
        _setUpAgent(fakeMorpho);
    }

    function testRebalanceUnAuthorizedRebalancer(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);
        address unauthorized = address(0x3);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(unauthorized);
        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_REBALANCER));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceFromMarketInvalidToken(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        for (uint256 i; i < from_markets.length; ++i) {
            from_markets[i].market.loanToken = address(collateralToken);
        }
        vm.expectRevert(bytes(ErrorsLib.INVALID_TOKEN));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceToMarketInvalidToken(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        for (uint256 i; i < to_markets.length; ++i) {
            to_markets[i].market.loanToken = address(collateralToken);
        }
        vm.expectRevert(bytes(ErrorsLib.INVALID_TOKEN));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceZeroMarket(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets,) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(bytes(ErrorsLib.ZERO_MARKET));
        RebalanceMarketParams[] memory empty;
        agent.rebalance(user, address(loanToken), empty, empty);
    }

    function testRebalanceDeltaNonZero(uint256 totalSupplyAmount, uint256 supplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        supplyAmount = bound(supplyAmount, 1, withdrawAmount - 1);

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        vm.expectRevert(bytes(ErrorsLib.DELTA_NON_ZERO));
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceByShares(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawShares;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, 0, withdrawShares, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        withdrawShares = morpho.position(from_markets[0].market.id(), user).supplyShares;
        from_markets[0].shares = withdrawShares;

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function test_Rebalance(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount = totalSupplyAmount;
        uint256 supplyAmount = totalSupplyAmount;

        (RebalanceMarketParams[] memory from_markets, RebalanceMarketParams[] memory to_markets) =
            _prepareRebalanceMarketParms(0.9 ether, 0.8 ether, withdrawAmount, 0, supplyAmount, 0);

        _supplyMorpho(from_markets[0].market, totalSupplyAmount, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }

    function testRebalanceMultipleMarkets(uint256 totalSupplyAmount) public {
        address user = address(0x1);
        address rebalancer = address(0x2);

        totalSupplyAmount = bound(totalSupplyAmount, 2, 1000);
        loanToken.setBalance(user, totalSupplyAmount);

        uint256 withdrawAmount1 = totalSupplyAmount / 2;
        uint256 withdrawAmount2 = totalSupplyAmount - withdrawAmount1;

        uint256 supplyAmount1;
        supplyAmount1 = bound(supplyAmount1, 1, totalSupplyAmount - 1);
        uint256 supplyAmount2 = totalSupplyAmount - supplyAmount1;

        MarketParams memory market1 = _createMarket(0.09 ether);
        MarketParams memory market2 = _createMarket(0.08 ether);
        MarketParams memory market3 = _createMarket(0.085 ether);
        MarketParams memory market4 = _createMarket(0.07 ether);

        RebalanceMarketParams[] memory from_markets = new RebalanceMarketParams[](2);
        RebalanceMarketParams[] memory to_markets = new RebalanceMarketParams[](2);

        from_markets[0] = RebalanceMarketParams(market1, withdrawAmount1, 0);
        from_markets[1] = RebalanceMarketParams(market2, withdrawAmount2, 0);
        to_markets[0] = RebalanceMarketParams(market3, supplyAmount1, 0);
        to_markets[1] = RebalanceMarketParams(market4, supplyAmount2, 0);

        _supplyMorpho(market1, withdrawAmount1, 0, user);
        _supplyMorpho(market2, withdrawAmount2, 0, user);

        _setAuthorization(user, address(agent), true);

        vm.startPrank(user);
        agent.authorize(rebalancer);
        vm.stopPrank();

        vm.prank(rebalancer);
        agent.rebalance(user, address(loanToken), from_markets, to_markets);
    }
}
