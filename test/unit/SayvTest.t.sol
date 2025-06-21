// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Sayv} from "../../src/Sayv.sol";
import {YieldWield} from "@yieldwield/YieldWield.sol";
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
    YieldWield yieldWield;
    address yieldWieldAddress;
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
    uint256 RAY = 1e26;

    function setUp() external {
        usdc = new MockUSDC();
        usdc.mint(user, 1000);
        usdc.mint(user2, 1000);
        usdcAddress = usdc.getAddress();

        aUSDC = new MockAUSDC();
        aUSDCAddress = aUSDC.getAddress();

        mockPool = new MockPool(usdcAddress, aUSDCAddress);
        addressProvider = mockPool.getPool();

        yieldWield = new YieldWield(addressProvider);
        yieldWieldAddress = yieldWield.getYieldWieldContractAddress();

        tokenRegistry = new TokenRegistry();
        tokenRegistryAddress = tokenRegistry.getTokenRegistryAddress();

        vm.startPrank(dev);
        sayv = new Sayv(addressProvider, yieldWieldAddress, tokenRegistryAddress);
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
        assertEq(sayv.getAccountShareValue(usdcAddress, user), 100);

        vm.prank(dev);
        mockPool.setLiquidityIndex(address(usdc), 12 * RAY);
        assertEq(sayv.getAccountShareValue(usdcAddress, user), 120);
    }

    // function testWithdrawAndAccounting() public {
    //     vm.prank(user);
    //     sayv.depositToVault(usdcAddress, 100);

    //     vm.warp(block.timestamp + 356 days);

    //     vm.prank(dev);
    //     sayv.depositToVault(usdcAddress, 100);

    //     vm.prank(user);
    //     sayv.withdrawFromVault(usdcAddress, 100);
    //     console.logUint(sayv.getAccountShareValue(usdcAddress, user));
    //     assertEq(IERC20(usdcAddress).balanceOf(user), 100);
    // }

    // function testGettingYieldAdvance() public {
    //     vm.prank(user);
    //     sayv.depositToVault(usdcAddress, 100);
    //     vm.prank(dev);
    //     sayv.depositToVault(usdcAddress, 100);

    //     vm.prank(user);
    //     sayv.getYieldAdvance(usdcAddress, 100, 20);
    //     assertEq(sayv.getAccountShareValue(usdcAddress, user), 0);
    //     assertEq(sayv.getValueOfTotalRevenueShares(usdcAddress), 6);
    //     assertEq(IERC20(usdcAddress).balanceOf(user), 14);
    // }

    // function testRepayingYieldAdvanceWithDepositAndWithdrawingCollateral() public {
    //     vm.prank(user);
    //     sayv.depositToVault(usdcAddress, 100);
    //     vm.prank(dev);
    //     sayv.depositToVault(usdcAddress, 100);

    //     vm.prank(user);
    //     sayv.getYieldAdvance(usdcAddress, 100, 20);

    //     vm.prank(user);
    //     vm.expectRevert();
    //     sayv.withdrawYieldAdvanceCollateral(usdcAddress);

    //     vm.prank(dev);
    //     IERC20(usdcAddress).transfer(user, 20);

    //     vm.prank(user);
    //     sayv.repayYieldAdvanceWithDeposit(usdcAddress, 20);

    //     vm.prank(user);
    //     sayv.withdrawYieldAdvanceCollateral(usdcAddress);
    //     assertEq(sayv.getAccountShareValue(usdcAddress, user), 100);
    // }

    // function testDepositWithTokenNotPermitted() public {
    //     vm.prank(user);
    //     vm.expectRevert();
    //     sayv.depositToVault(0xa9D6855Ab011b8607E21b21a097692D55A15F985, 100);
    // }
}
