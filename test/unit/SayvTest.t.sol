// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Sayv} from "../../contracts/Sayv.sol";
import {YieldAdvance} from "@yield-advance/YieldAdvance.sol";
import {TokenRegistry} from "@token-registry/TokenRegistry.sol";
import {MockPool} from "../mocks/MockPool.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {MockAUSDC} from "../mocks/MockAUSDC.sol";

/**
 * @title Test for Sayv.sol with mock assets and mock aave pool
 */
contract SayvTest is Test {
    Sayv sayv;
    address sayvAddress;
    YieldAdvance yieldAdvance;
    address yieldAdvanceAddress;
    TokenRegistry tokenRegistry;
    MockPool mockPool;
    address addressProvider;
    address tokenRegistryAddress;
    MockUSDC usdc;
    MockAUSDC aUSDC;
    address usdcAddress;
    address aUSDCAddress;
    address dev = makeAddr("dev");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    uint256 RAY = 1e27;

    function setUp() external {
        usdc = new MockUSDC();
        usdc.mint(user, 1000);
        usdc.mint(user2, 1000);
        usdc.mint(dev, 1000);
        usdcAddress = usdc.getAddress();
        aUSDC = new MockAUSDC();
        aUSDCAddress = aUSDC.getAddress();
        mockPool = new MockPool(usdcAddress, aUSDCAddress);
        addressProvider = mockPool.getPool();
        yieldAdvance = new YieldAdvance(addressProvider);
        yieldAdvanceAddress = yieldAdvance.getYieldAdvanceContractAddress();
        tokenRegistry = new TokenRegistry();
        tokenRegistryAddress = tokenRegistry.getTokenRegistryAddress();
        vm.startPrank(dev);
        sayv = new Sayv(addressProvider, yieldAdvanceAddress, tokenRegistryAddress);
        vm.stopPrank();
        sayvAddress = sayv.getVaultAddress();
        vm.prank(dev);
        sayv.managePermittedTokens(usdcAddress, true);
        vm.prank(dev);
        sayv.managePermittedTokens(aUSDCAddress, true);
        vm.deal(dev, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(sayvAddress, 10 ether);
        vm.prank(user);
        usdc.approve(sayvAddress, type(uint256).max);
        vm.prank(user2);
        usdc.approve(sayvAddress, type(uint256).max);
        vm.prank(sayvAddress);
        usdc.approve(addressProvider, type(uint256).max);
    }

    modifier deposit() {
        vm.prank(user);
        sayv.depositToVault(usdcAddress, 100);
        _;
    }

    function testDepositAndAccounting() public {
        assertEq(usdc.balanceOf(user), 1000);
        vm.prank(user);
        sayv.depositToVault(usdcAddress, 100);
        assertEq(usdc.balanceOf(user), 900);
        assertEq(aUSDC.balanceOf(sayvAddress), 100);
        assertEq(sayv.getAccountShareValue(user, usdcAddress), 100 * RAY);
        console.logUint(sayv.getAccountShareValue(user, usdcAddress));
        vm.prank(dev);
        mockPool.setLiquidityIndex(address(usdc), 12e26);
        assertEq(sayv.getAccountShareValue(user, usdcAddress), 120 * RAY);
    }

    function testWithdrawAndAccounting() public {
        vm.prank(user);
        sayv.depositToVault(usdcAddress, 100);
        assertEq(usdc.balanceOf(user), 900);
        assertEq(aUSDC.balanceOf(sayvAddress), 100);
        console.logUint(aUSDC.balanceOf(sayvAddress));
        vm.prank(dev);
        console.logUint(sayv.getAccountNumOfShares(user, usdcAddress));
        mockPool.setLiquidityIndex(address(usdc), 2e27);
        vm.prank(user);
        sayv.withdrawFromVault(usdcAddress, 50);
        // assertEq(sayv.getAccountShareValue(user, usdcAddress), 100);j
        assertEq(usdc.balanceOf(user), 950);
        console.logUint(aUSDC.balanceOf(sayvAddress));
    }

    function testGettingYieldAdvance() public {
        vm.prank(user);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(user2);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(user);
        sayv.getYieldAdvance(usdcAddress, 100, 20);
        assertEq(sayv.getAccountShareValue(user, usdcAddress), 0);
        assertEq(sayv.getValueOfTotalRevenueShares(usdcAddress), 6 * RAY);
        assertEq(usdc.balanceOf(user), 914);
    }

    function testRepayingYieldAdvanceWithDepositAndWithdrawingCollateral() public {
        vm.prank(user);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(user2);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(user);
        sayv.getYieldAdvance(usdcAddress, 100, 20);
        vm.prank(user);
        vm.expectRevert();
        sayv.withdrawYieldAdvanceCollateral(usdcAddress);
        vm.prank(user);
        sayv.repayYieldAdvanceWithDeposit(usdcAddress, 20);
        vm.prank(user);
        sayv.withdrawYieldAdvanceCollateral(usdcAddress);
        vm.prank(user);
        assertEq(sayv.getAccountShareValue(user, usdcAddress), 100 * RAY);
    }

    function testDepositWithTokenNotPermitted() public {
        vm.prank(user);
        vm.expectRevert();
        sayv.depositToVault(0xa9D6855Ab011b8607E21b21a097692D55A15F985, 100);
    }
}
