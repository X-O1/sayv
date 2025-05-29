// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Sayv} from "../src/Sayv.sol";

pragma solidity ^0.8.30;

contract DeploySayv is Script {
    function run() external returns (Sayv) {
        // HelperConfig helperConfig = new HelperConfig();
        // address usdcPriceFeed = helperConfig.activeNetworkConfig();
        // vm.startBroadcast();
        // Sayv sayv = new Sayv(usdcPriceFeed);
        // vm.stopBroadcast();
        // return sayv;
    }
}
