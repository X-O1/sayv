// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";

pragma solidity ^0.8.30;

contract DeployTokenRegistry is Script {
    function run() external returns (TokenRegistry) {
        vm.startBroadcast();
        TokenRegistry tokenRegistry = new TokenRegistry();
        vm.stopBroadcast();
        return tokenRegistry;
    }
}
