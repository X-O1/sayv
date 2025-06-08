// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SayvVaultFactory} from "../../src/SayvVaultFactory.sol";
import {SayvVault} from "../../src/SayvVault.sol";
import {DeploySayvVaultFactory} from "../../script/DeploySayvVaultFactory.s.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract SayvVaultTest is Test {
    SayvVault sayvVault;
    SayvVaultFactory sayvVaultFactory;
    address sayvVaultAddress;
    MockUSDC usdc;
    address dev;
    address usdcAddress = 0x2e234DAe75C793f67A35089C9d99245E1C58470b;
    address user = makeAddr("user");
    uint256 tokenDecimals = 6;
    address activePool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    modifier isOwner() {
        vm.prank(dev);
        _;
    }

    function setUp() external {
        DeploySayvVaultFactory deploySayvVaultFactory = new DeploySayvVaultFactory();
        sayvVaultFactory = deploySayvVaultFactory.run();
        dev = sayvVaultFactory.getOwner();
        usdc = new MockUSDC(dev);
        vm.prank(dev);
        sayvVault = sayvVaultFactory.createVault(usdcAddress, tokenDecimals, activePool);
        sayvVaultAddress = sayvVault.getVaultAddress();
        vm.deal(dev, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(sayvVaultAddress, 10 ether);
    }

    function testDepositWithoutRepayment() public {
        vm.prank(dev);
        usdc.approve(sayvVaultAddress, 1000);
        vm.prank(dev);
        sayvVault.depositToVault(100, false);
    }

    function testDepositWithRepayment() public {}

    function testWithdrawWithoutRepayment() public {}

    function testWithdrawWithRepayment() public {}
}
