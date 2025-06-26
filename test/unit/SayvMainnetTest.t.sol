// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Sayv} from "../../contracts/Sayv.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {YieldAdvance} from "@yield-advance/YieldAdvance.sol";
import {TokenRegistry} from "@token-registry/TokenRegistry.sol";

/**
 * @title Test for Sayv.sol on a forked BASE Mainnet
 * @notice All addresses are for Base Mainnet
 */
contract SayvMainnetTest is Test {
    Sayv sayv;
    address sayvAddress;
    YieldAdvance yieldAdvance;
    address yieldAdvanceAddress;
    TokenRegistry tokenRegistry;
    address tokenRegistryAddress;
    address dev = 0x7Cc00Dc8B6c0aC2200b989367E30D91B7C7F5F43;
    address fakeUser = 0x7e6Af92Df2aEcD6113325c0b58F821ab1dCe37F6;
    address usdcAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address aUSDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;
    address addressProvider = 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D;
    address poolAddress = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address user = 0xa9D6855Ab011b8607E21b21a097692D55A15F985;
    address user2 = 0xAd68fd8233A729aA24E4A3eafFBD425d8d24c558;
    uint256 baseMainnetChainID = 8453;
    uint256 RAY = 1e27;

    function setUp() external {
        if (block.chainid == baseMainnetChainID) {
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
            sayv.managePermittedTokens(aUSDC, true);
            vm.deal(dev, 10 ether);
            vm.deal(sayvAddress, 10 ether);
            vm.prank(dev);
            IERC20(usdcAddress).approve(sayvAddress, type(uint256).max);
            vm.prank(dev);
            IERC20(aUSDC).approve(sayvAddress, type(uint256).max);
            vm.prank(dev);
            IERC20(usdcAddress).transfer(fakeUser, 100);
            vm.prank(fakeUser);
            IERC20(aUSDC).approve(sayvAddress, type(uint256).max);
            vm.prank(fakeUser);
            IERC20(usdcAddress).approve(sayvAddress, type(uint256).max);
            vm.prank(sayvAddress);
            IERC20(aUSDC).approve(poolAddress, type(uint256).max);
        }
    }

    modifier ifBaseMainnet() {
        if (block.chainid == baseMainnetChainID) {
            _;
        }
    }

    function testDepositAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(usdcAddress, 100);
        assertEq(sayv.getAccountShareValue(fakeUser, usdcAddress), 100 * RAY);
        assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 0);
    }

    function testInstantWithdrawAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(fakeUser);
        console.logUint(sayv.withdrawFromVault(usdcAddress, 100));
    }

    function testWithdrawAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(usdcAddress, 100);
        vm.warp(block.timestamp + 356 days);
        vm.prank(dev);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(fakeUser);
        sayv.withdrawFromVault(usdcAddress, 100);
        console.logUint(sayv.getAccountShareValue(fakeUser, usdcAddress));
        assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 100);
    }

    function testGettingYieldAdvance() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(dev);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(fakeUser);
        sayv.getYieldAdvance(usdcAddress, 100, 20);
        assertEq(sayv.getAccountShareValue(fakeUser, usdcAddress), 0);
        assertApproxEqAbs(sayv.getValueOfTotalRevenueShares(usdcAddress), 6 * RAY, 2);
        assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 14);
    }

    function testRepayingYieldAdvanceWithDepositAndWithdrawingCollateral() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(dev);
        sayv.depositToVault(usdcAddress, 100);
        vm.prank(fakeUser);
        sayv.getYieldAdvance(usdcAddress, 100, 20);
        vm.prank(fakeUser);
        vm.expectRevert();
        sayv.withdrawYieldAdvanceCollateral(usdcAddress);
        vm.prank(dev);
        IERC20(usdcAddress).transfer(fakeUser, 20);
        vm.prank(fakeUser);
        sayv.repayYieldAdvanceWithDeposit(usdcAddress, 20);
        vm.prank(fakeUser);
        sayv.withdrawYieldAdvanceCollateral(usdcAddress);
        assertEq(sayv.getAccountShareValue(fakeUser, usdcAddress), 100 * RAY);
    }

    function testDepositWithTokenNotPermitted() public ifBaseMainnet {
        vm.prank(fakeUser);
        vm.expectRevert();
        sayv.depositToVault(0xa9D6855Ab011b8607E21b21a097692D55A15F985, 100);
    }
}
