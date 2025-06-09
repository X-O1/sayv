// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SayvVaultFactory} from "../../src/SayvVaultFactory.sol";
import {SayvVault} from "../../src/SayvVault.sol";
import {DeploySayvVaultFactory} from "../../script/DeploySayvVaultFactory.s.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract SayvVaultFactoryTest is Test {
    SayvVault sayvVault;
    address sayvVaultAddress;
    SayvVaultFactory sayvVaultFactory;

    MockUSDC usdc;
    address usdcAddress = 0x2e234DAe75C793f67A35089C9d99245E1C58470b;
    address dev;
    address user = makeAddr("user");
    address usdcBaseSepoliaAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    uint256 baseSepoliaChainId = 84532;
    uint256 tokenDecimals = 6;
    address activePool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    uint256 anvilChainId = 31337;

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

    function testCreatingNewVaults() public isOwner {
        sayvVaultFactory.createVault(usdcAddress, tokenDecimals, activePool);
    }

    function testMockUsdc() public {
        vm.prank(dev);
        uint256 usdcBalance = usdc.balanceOf(dev);
        vm.prank(dev);
        assertEq(usdcBalance > 10, true);
    }
}
