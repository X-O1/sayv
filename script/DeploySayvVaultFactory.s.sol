// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SayvVaultFactory} from "../../src/SayvVaultFactory.sol";
import {Script} from "forge-std/Script.sol";

contract DeploySayvVaultFactory is Script {
    function run() external returns (SayvVaultFactory) {
        vm.startBroadcast();
        SayvVaultFactory sayvVaultFactory = new SayvVaultFactory();
        vm.stopBroadcast();
        return sayvVaultFactory;
    }
}
