// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {AccountManager} from "../src/AccountManager.sol";

pragma solidity ^0.8.30;

contract DeploySayv is Script {
    event Give_Owner(address indexed owner);

    function run() external returns (AccountManager) {
        vm.startBroadcast();
        AccountManager accountManager = new AccountManager();
        vm.stopBroadcast();
        return (accountManager);
    }
}
