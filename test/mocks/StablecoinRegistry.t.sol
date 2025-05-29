// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TokenRegistry} from "../../src/TokenRegistry.sol";
import {Test, console} from "forge-std/Test.sol";

contract TokenRegistryTest is Test {
    TokenRegistry stablecoinRegistry;

    function setUp() external {
        stablecoinRegistry = new TokenRegistry();
    }

    function test() public {}
}
