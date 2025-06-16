// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Sayv} from "../../src/Sayv.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

/**
 * @title Test for Sayv.sol on the BASE Mainnet
 * @notice All addresses are for Base Mainnet
 */
contract SayvTest is Test {
    Sayv sayv;
    address sayvAddress;
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
            sayv = new Sayv(usdcAddress, addressProvider, aUSDC);
            sayvAddress = sayv.getVaultAddress();

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

    modifier deposit() {
        vm.prank(fakeUser);
        sayv.depositToVault(100);
        _;
    }

    function testDepositAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(100);
        assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 0);
        assertEq(IERC20(aUSDC).balanceOf(sayvAddress), 100);
        assertEq(sayv.getAccountShareValue(fakeUser), 100);
    }

    function testWithdrawAndAccounting() public ifBaseMainnet {
        vm.prank(fakeUser);
        sayv.depositToVault(100);

        vm.warp(block.timestamp + 356 days);

        vm.prank(dev);
        sayv.depositToVault(100);

        vm.prank(fakeUser);
        sayv.withdrawFromVault(100);
        console.logUint(sayv.getAccountShareValue(fakeUser));
        assertEq(IERC20(usdcAddress).balanceOf(fakeUser), 100);
    }
}
