// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {AccountManager} from "../../src/AccountManager.sol";

contract AccountingTest is Test {
    AccountManager public accountManager;

    address dev = makeAddr("dev");
    address user = makeAddr("user");
    address usdcBaseSepoliaAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    uint256 baseSepoliaChainId = 84532;
    uint256 anvilChainId = 31337;
    address tokenRegistryContractAddress;

    modifier isOwner() {
        vm.prank(dev);
        _;
    }

    function setUp() external {
        vm.startPrank(dev);
        accountManager = new AccountManager();
        vm.stopPrank();

        vm.deal(dev, 10 ether);
        vm.deal(user, 10 ether);
    }

    function testConsoleLogs() public view {}
}
