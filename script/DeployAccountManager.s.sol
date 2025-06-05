// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {AccountManager} from "../src/AccountManager.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";

pragma solidity ^0.8.30;

contract DeploySayv is Script {
    event Give_Owner(address indexed owner);

    function run() external returns (AccountManager) {
        vm.startBroadcast();
        TokenRegistry tokenRegistry = new TokenRegistry();
        address tokenRegistryContractAddress = tokenRegistry.getRegistryContractAddress();
        AccountManager accountManager = new AccountManager(tokenRegistryContractAddress);
        vm.stopBroadcast();
        return (accountManager);
    }
}
