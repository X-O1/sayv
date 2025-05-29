// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TokenRegistry} from "../../src/TokenRegistry.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployTokenRegistry} from "../../script/DeployTokenRegistry.s.sol";

contract TokenRegistryTest is Test {
    TokenRegistry tokenRegistry;

    function setUp() external {
        DeployTokenRegistry deployTokenRegistry = new DeployTokenRegistry();
        tokenRegistry = deployTokenRegistry.run();
    }

    function test() public {}
}
