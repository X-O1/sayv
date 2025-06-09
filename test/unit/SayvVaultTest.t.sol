// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SayvVault} from "../../src/SayvVault.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract SayvVaultTest is Test {
    SayvVault sayvVault;
    address sayvVaultAddress;
    address dev = 0xCb7c7C73D1Ae0dD7e1c9bc76826FA4314411643d;
    address usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 tokenDecimals = 6;
    address addressProvider = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address poolAddress = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address yieldBarringToken = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    function setUp() external {
        sayvVault = new SayvVault(usdcAddress, tokenDecimals, addressProvider);
        sayvVaultAddress = sayvVault.getVaultAddress();

        vm.deal(dev, 10 ether);
        vm.deal(sayvVaultAddress, 10 ether);
    }

    modifier depositWithoutRepayment() {
        vm.prank(dev);
        IERC20(usdcAddress).approve(sayvVaultAddress, 10e6);
        vm.prank(sayvVaultAddress);
        IERC20(usdcAddress).approve(poolAddress, 10e6);
        vm.prank(dev);
        sayvVault.depositToVault(10e6, false);
        _;
    }

    function testDepositWithoutRepayment() public {
        vm.prank(dev);
        IERC20(usdcAddress).approve(sayvVaultAddress, 10e6);
        vm.prank(sayvVaultAddress);
        IERC20(usdcAddress).approve(poolAddress, 10e6);
        vm.prank(dev);
        sayvVault.depositToVault(10e6, false);
        console.logUint((IERC20(yieldBarringToken).balanceOf(sayvVaultAddress)));
    }

    // function testWithdrawWithoutRepayment() public depositWithoutRepayment {
    //     vm.prank(dev);
    //     sayvVault.withdrawFromVault(10e6, false);
    //     console.logUint((IERC20(yieldBarringToken).balanceOf(sayvVaultAddress)));
    // }
}
