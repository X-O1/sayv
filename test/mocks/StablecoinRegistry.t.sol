// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {StablecoinRegistry} from "../../src/StablecoinRegistry.sol";
import {Test, console} from "forge-std/Test.sol";

contract StablecoinRegistryTest is Test {
    StablecoinRegistry stablecoinRegistry;

    function setUp() external {
        stablecoinRegistry = new StablecoinRegistry();
    }

    function test() public {}
}
