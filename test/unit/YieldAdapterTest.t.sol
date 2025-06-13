// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {YieldAdapter} from "../../src/YieldAdapter.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

/**
 * @title Test for YieldAdapter.sol on the BASE Mainnet
 * @notice All addresses are for Base Mainnet
 */
contract YieldAdaptertTest is Test {
    YieldAdapter yieldAdapter;
    address yieldAdapterAddress;
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

            vm.deal(dev, 10 ether);
            vm.deal(yieldAdapterAddress, 10 ether);

            vm.prank(dev);
            IERC20(usdcAddress).approve(yieldAdapterAddress, type(uint256).max);
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
        yieldAdapter.depositToVault(usdcAddress, 1000);
        vm.prank(user);
        yieldAdapter.depositToVault(usdcAddress, 5000);
        vm.prank(user2);
        yieldAdapter.depositToVault(usdcAddress, 4000);
        _;
    }

    function testDepositAndAccounting() public ifBaseMainnet {
        vm.prank(dev);
        yieldAdapter.depositToVault(usdcAddress, 1000);
        vm.prank(user);
        yieldAdapter.depositToVault(usdcAddress, 750);
        vm.prank(user2);
        yieldAdapter.depositToVault(usdcAddress, 500);

        assertEq(yieldAdapter._getAccountDeposits(dev, usdcAddress), 1000);
        assertEq(yieldAdapter._getAccountDeposits(user, usdcAddress), 750);
        assertEq(yieldAdapter._getAccountDeposits(user2, usdcAddress), 500);
        assertEq(yieldAdapter._getVaultYieldTokenBalance(), 2250);
    }

    function testWithdrawAndAccounting() public ifBaseMainnet deposit {
        // test withdrawing available funds and
        vm.prank(dev);
        yieldAdapter.withdrawFromVault(usdcAddress, 500);
        assertEq(yieldAdapter._getAccountDeposits(dev, usdcAddress), 500);
        assertEq(yieldAdapter._getVaultYieldTokenBalance(), 9500);

        // test withrawing more % of the pool than i own
        // test withdrawing more than available equity
        vm.prank(dev);
        vm.expectRevert();
        yieldAdapter.withdrawFromVault(usdcAddress, 1500);
    }
}
