// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Sayv} from "../src/Sayv.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";

pragma solidity ^0.8.30;

contract DeploySayv is Script {
    event Give_Owner(address indexed owner);

    function run() external returns (Sayv) {
        vm.startBroadcast();
        TokenRegistry tokenRegistry = new TokenRegistry();
        address tokenRegistryContractAddress = tokenRegistry.getRegistryContractAddress();
        Sayv sayv = new Sayv(tokenRegistryContractAddress);
        vm.stopBroadcast();
        return (sayv);
    }
}
