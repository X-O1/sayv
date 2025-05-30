// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TokenRegistry} from "../../src/TokenRegistry.sol";
import {Test, console} from "forge-std/Test.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;

    address dev = makeAddr("dev");
    address user = makeAddr("user");
    address usdcBaseSepoliaAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    uint256 baseSepoliaChainId = 84532;
    uint256 anvilChainId = 31337;

    function setUp() external {
        vm.startPrank(dev);
        tokenRegistry = new TokenRegistry();
        vm.stopPrank();

        vm.deal(dev, 10 ether);
        vm.deal(user, 10 ether);
    }

    function testOwnerOfContractIsDeployer() public view {
        assertEq(tokenRegistry.getRegistryContractOwnerAddress(), dev);
    }

    function testOnlyOwnerCanAddTokenToRegistry() public {
        vm.expectRevert();
        vm.prank(user);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId);
    }

    function testOnlyOwnerCanRemoveTokenFromRegistry() public {
        vm.expectRevert();
        vm.prank(user);
        tokenRegistry.removeTokenFromRegistry(usdcBaseSepoliaAddress, anvilChainId);
    }

    function testTokenAddedMustBeOnActiveChain() public {
        vm.expectRevert();
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, 1);
    }

    function testTokenRemovedMustBeOnActiveChain() public {
        vm.expectRevert();
        vm.prank(dev);
        tokenRegistry.removeTokenFromRegistry(usdcBaseSepoliaAddress, 1);
    }

    function testAddingTokenToRegistry() public {
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId);
    }

    function testTokenApprovedListIsUpdatedAfterAddingAndRemoving() public {
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId);
        vm.prank(dev);
        assertEq(tokenRegistry.checkIfTokenIsApproved(usdcBaseSepoliaAddress), true);

        vm.prank(dev);
        tokenRegistry.removeTokenFromRegistry(usdcBaseSepoliaAddress, anvilChainId);
        vm.prank(dev);
        assertEq(tokenRegistry.checkIfTokenIsApproved(usdcBaseSepoliaAddress), false);
    }

    function testGettingTokenDetails() public {
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId);
        vm.prank(dev);
        assertEq(tokenRegistry.getTokenDetails(usdcBaseSepoliaAddress).chainId, anvilChainId);
    }
}
