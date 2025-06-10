// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SayvVault} from "../../src/SayvVault.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract SayvVaultTest is Test {
    SayvVault sayvVault;
    address sayvVaultAddress;
    address dev = 0xCb7c7C73D1Ae0dD7e1c9bc76826FA4314411643d;
    address usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 tokenDecimals = 6;
    address addressProvider = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address poolAddress = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address aUSDCAddress = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address user = 0x94a10586cd1B325b42459397b8F030a92b9B5c67;
    address user2 = 0xA38EE4A24886FEE6F696C65A7b26cE5F42f73f68;

    function setUp() external {
        if (block.chainid == 1) {
            sayvVault = new SayvVault(usdcAddress, tokenDecimals, addressProvider);
            sayvVaultAddress = sayvVault.getVaultAddress();

            vm.deal(dev, 10 ether);
            vm.deal(sayvVaultAddress, 10 ether);

            vm.prank(dev);
            IERC20(usdcAddress).approve(sayvVaultAddress, type(uint256).max);
            vm.prank(user);
            IERC20(usdcAddress).approve(sayvVaultAddress, type(uint256).max);
            vm.prank(user2);
            IERC20(usdcAddress).approve(sayvVaultAddress, type(uint256).max);
        }
    }

    modifier ifEthMainnet() {
        if (block.chainid == 1) {
            _;
        }
    }

    modifier depositWithoutRepayment() {
        vm.prank(dev);
        sayvVault.depositToVault(1000e6, false);
        vm.prank(user);
        sayvVault.depositToVault(1000e6, false);
        vm.prank(user2);
        sayvVault.depositToVault(1000e6, false);
        _;
    }

    function testDepositWithoutRepaymentAndAccounting() public ifEthMainnet {
        vm.prank(dev);
        sayvVault.depositToVault(1000e6, false);
        vm.prank(user);
        sayvVault.depositToVault(750e6, false);
        vm.prank(user2);
        sayvVault.depositToVault(500e6, false);

        assertEq(sayvVault._getAccountEquity(dev), 1000e6);
        assertEq(sayvVault._getAccountEquity(user), 750e6);
        assertEq(sayvVault._getAccountEquity(user2), 500e6);
        assertEq(sayvVault._getVaultTotalDeposits(), 2250e6);
    }

    // function testWithdrawWithoutRepayment() public ifEthMainnet depositWithoutRepayment {
    //     // test withrawing more % of the pool than i own
    //     // test withdrawing more than available equity
    // }
}
