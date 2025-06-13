// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {YieldAdapter} from "../../src/YieldAdapter.sol";
import {YieldLeasing} from "../../src/YieldLeasing.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

/**
 * @title Test for YieldAdapter.sol on the BASE Mainnet
 * @notice All addresses are for Base Mainnet
 */
contract YieldAdaptertTest is Test {
    YieldAdapter yieldAdapter;
    address yieldAdapterAddress;
    YieldLeasing yieldLeasing;
    address yieldLeasingAddress;
    address dev = 0xa3EC4bE8cAdBf2257be5bc149de628177b75b276;
    address usdcAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address aUSDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;
    address addressProvider = 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D;
    address poolAddress = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address user = 0xa9D6855Ab011b8607E21b21a097692D55A15F985;
    address user2 = 0xAd68fd8233A729aA24E4A3eafFBD425d8d24c558;
    uint256 baseMainnetChainID = 8453;

    function setUp() external {
        if (block.chainid == baseMainnetChainID) {
            yieldAdapter = new YieldAdapter(usdcAddress, addressProvider, aUSDC);
            yieldAdapterAddress = yieldAdapter.getVaultAddress();
            yieldLeasing = new YieldLeasing(yieldAdapterAddress, usdcAddress, aUSDC);
            yieldLeasingAddress = yieldLeasing.getVaultAddress();
            yieldAdapter.setYieldLeasingContractAddress(yieldLeasingAddress);

            vm.deal(dev, 10 ether);
            vm.deal(yieldAdapterAddress, 10 ether);

            vm.prank(dev);
            IERC20(usdcAddress).transfer(yieldLeasingAddress, 1000);
            vm.prank(dev);
            IERC20(usdcAddress).approve(yieldAdapterAddress, type(uint256).max);
            vm.prank(yieldLeasingAddress);
            IERC20(usdcAddress).approve(poolAddress, type(uint256).max);
            vm.prank(user);
            IERC20(usdcAddress).approve(yieldAdapterAddress, type(uint256).max);
            vm.prank(user2);
            IERC20(usdcAddress).approve(yieldAdapterAddress, type(uint256).max);
        }
    }

    modifier ifBaseMainnet() {
        if (block.chainid == baseMainnetChainID) {
            _;
        }
    }

    modifier deposit() {
        vm.prank(dev);
        yieldAdapter.depositToVault(usdcAddress, 10000);
        vm.prank(user);
        yieldAdapter.depositToVault(usdcAddress, 10000);
        vm.prank(user2);
        yieldAdapter.depositToVault(usdcAddress, 10000);
        _;
    }

    function testSupplyingLiquidityAndAccounting() public ifBaseMainnet {
        vm.prank(dev);
        yieldAdapter.depositToVault(usdcAddress, 1000);
        assertEq(yieldAdapter._getVaultYieldTokenBalance(), 1000);
        assertEq(yieldAdapter._getAccountDeposits(dev, usdcAddress), 1000);

        vm.prank(dev);
        yieldLeasing.supplyLiquidity(usdcAddress, 400);
        assertEq(yieldLeasing._getVaultYieldTokenBalance(), 400);
        assertEq(yieldLeasing.getLiquidityDeposited(dev, usdcAddress), 400);
        assertEq(yieldLeasing.getTotalLiquidityDeposited(yieldLeasingAddress, usdcAddress), 400);
        assertEq(yieldAdapter._getAccountDeposits(dev, usdcAddress), 600);

        vm.prank(dev);
        vm.expectRevert();
        yieldLeasing.supplyLiquidity(usdcAddress, 700);
    }

    function testWithdrawingLiquidityAndAccounting() public ifBaseMainnet deposit {
        vm.prank(dev);
        yieldLeasing.supplyLiquidity(usdcAddress, 1000);
        // vm.prank(user);
        // yieldLeasing.supplyLiquidity(usdcAddress, 1000);
        // vm.prank(user2);
        // yieldLeasing.supplyLiquidity(usdcAddress, 1000);
        console.logUint(yieldLeasing._getVaultYieldTokenBalance());

        vm.warp(block.timestamp + 365 days);
        console.logUint(yieldLeasing._getVaultYieldTokenBalance());
        vm.prank(dev);
        yieldLeasing._withdrawYield(dev);
        console.logUint(yieldLeasing._getVaultYieldTokenBalance());
        vm.prank(dev);
        yieldLeasing._withdrawYield(dev);
        console.logUint(yieldLeasing._getVaultYieldTokenBalance());
        vm.prank(dev);
        yieldLeasing._withdrawYield(dev);
        console.logUint(yieldLeasing._getVaultYieldTokenBalance());
        // vm.prank(user);
        // yieldLeasing._withdrawYield(user);
        // console.logUint(yieldLeasing._getVaultYieldTokenBalance());
        // vm.prank(user2);
        // yieldLeasing._withdrawYield(user2);
        // console.logUint(yieldLeasing._getVaultYieldTokenBalance());

        // assertEq(yieldLeasing.getLiquidityDeposited(dev, usdcAddress), 500);
        // assertEq(yieldLeasing.getTotalLiquidityDeposited(yieldLeasingAddress, usdcAddress), 500);
    }
}
