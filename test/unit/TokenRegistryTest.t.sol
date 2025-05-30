// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TokenRegistry} from "../../src/TokenRegistry.sol";
import {Test, console} from "forge-std/Test.sol";

// import {DeployTokenRegistry} from "../../script/DeployTokenRegistry.s.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;

    address dev = makeAddr("dev");
    address user = makeAddr("user");
    address usdcBaseSepoliaAddress = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address usdcBaseSepoliaPriceFeed = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    uint256 baseMainnetChainId = 8453;
    uint256 baseSepoliaChainId = 84532;
    uint256 anvilChainId = 31337;

    function setUp() external {
        // DeployTokenRegistry deployTokenRegistry = new DeployTokenRegistry();
        // tokenRegistry = deployTokenRegistry.run();

        vm.startPrank(dev);
        tokenRegistry = new TokenRegistry();
        vm.stopPrank();

        vm.deal(dev, 10 ether);
        vm.deal(user, 10 ether);
    }

    function testOwnerOfContractIsDeployer() public view {
        assertEq(tokenRegistry.getContractOwnerAddress(), dev);
    }

    function testOnlyOwnerCanAddTokenToRegistry() public {
        vm.expectRevert();
        vm.prank(user);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId, usdcBaseSepoliaPriceFeed);
    }

    function testOnlyOwnerCanRemoveTokenFromRegistry() public {
        vm.expectRevert();
        vm.prank(user);
        tokenRegistry.removeTokenFromRegistry(usdcBaseSepoliaAddress, anvilChainId, usdcBaseSepoliaPriceFeed);
    }

    function testTokenAddedMustBeOnActiveChain() public {
        vm.expectRevert();
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, 1, usdcBaseSepoliaPriceFeed);
    }

    function testTokenRemovedMustBeOnActiveChain() public {
        vm.expectRevert();
        vm.prank(dev);
        tokenRegistry.removeTokenFromRegistry(usdcBaseSepoliaAddress, 1, usdcBaseSepoliaPriceFeed);
    }

    function testAddingTokenToRegistry() public {
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId, usdcBaseSepoliaPriceFeed);
    }

    function testTokenApprovedListIsUpdatedAfterAddingAndRemoving() public {
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId, usdcBaseSepoliaPriceFeed);
        vm.prank(dev);
        assertEq(tokenRegistry.checkIfTokenIsApproved(usdcBaseSepoliaAddress), true);

        vm.prank(dev);
        tokenRegistry.removeTokenFromRegistry(usdcBaseSepoliaAddress, anvilChainId, usdcBaseSepoliaPriceFeed);
        vm.prank(dev);
        assertEq(tokenRegistry.checkIfTokenIsApproved(usdcBaseSepoliaAddress), false);
    }

    function testGettingTokenDetails() public {
        vm.prank(dev);
        tokenRegistry.addTokenToRegistry(usdcBaseSepoliaAddress, anvilChainId, usdcBaseSepoliaPriceFeed);
        vm.prank(dev);
        assertEq(tokenRegistry.getTokenDetails(usdcBaseSepoliaAddress).chainId, anvilChainId);
        vm.prank(dev);
        assertEq(tokenRegistry.getTokenDetails(usdcBaseSepoliaAddress).priceFeed, usdcBaseSepoliaPriceFeed);
    }
}
