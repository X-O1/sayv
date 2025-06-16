// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {YieldAdapter} from "../../src/YieldAdapter.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";

/**
 * @title Test for YieldAdapter.sol on the BASE Mainnet
 * @notice All addresses are for Base Mainnet
 */
contract YieldAdaptertTest is Test {
    YieldAdapter yieldAdapter;
    address yieldAdapterAddress;
    address dev = 0x7Cc00Dc8B6c0aC2200b989367E30D91B7C7F5F43;
    address fakeUser = 0x7e6Af92Df2aEcD6113325c0b58F821ab1dCe37F6;
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

            vm.deal(dev, 10 ether);
            vm.deal(yieldAdapterAddress, 10 ether);

            vm.prank(dev);
            IERC20(usdcAddress).approve(yieldAdapterAddress, type(uint256).max);

            vm.prank(dev);
            IERC20(aUSDC).approve(yieldAdapterAddress, type(uint256).max);
            vm.prank(dev);
            IERC20(usdcAddress).transfer(fakeUser, 100);

            vm.prank(fakeUser);
            IERC20(aUSDC).approve(yieldAdapterAddress, type(uint256).max);
            vm.prank(fakeUser);
            IERC20(usdcAddress).approve(yieldAdapterAddress, type(uint256).max);

            vm.prank(yieldAdapterAddress);
            IERC20(aUSDC).approve(poolAddress, type(uint256).max);
        }
    }

    modifier ifBaseMainnet() {
        if (block.chainid == baseMainnetChainID) {
            _;
        }
    }

    modifier deposit() {
        vm.prank(fakeUser);
        yieldAdapter.depositToVault(100);
        _;
    }

    function testDepositAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        yieldAdapter.depositToVault(100);
        assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 0);
        assertEq(IERC20(aUSDC).balanceOf(yieldAdapterAddress), 100);
        assertEq(yieldAdapter.getAccountShareValue(fakeUser), 100);
    }

    function testWithdrawAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        yieldAdapter.depositToVault(100);

        vm.warp(block.timestamp + 356 days);

        vm.prank(dev);
        yieldAdapter.depositToVault(100);

        vm.prank(fakeUser);
        yieldAdapter.withdrawFromVault(100);
        console.logUint(yieldAdapter.getAccountShareValue(fakeUser));

        // assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 100);
        // assertEq(yieldAdapter.getAccountShareValue(fakeUser), 0);
        // assertEq(IERC20(aUSDC).balanceOf(yieldAdapterAddress), 0);
        // assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 100);

        // IPool(poolAddress).supply(usdcAddress, 1, msg.sender, 0);
    }
}
