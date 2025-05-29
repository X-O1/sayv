// SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Sayv} from "../src/Sayv.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol.sol";

pragma solidity ^0.8.30;

contract HelperConfig is Script {
    address public activeNetworkConfig;

    struct NetworkConfig {
        address token;
        address priceFeed;
    }

    constructor() {
        activeNetworkConfig = getUsdcConfig(block.chainid);
    }

    function getUsdcConfig(uint256 _chainId) public returns (address priceFeed) {
        NetworkConfig memory ethMainnet = NetworkConfig({
            token: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            priceFeed: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
        });
        NetworkConfig memory ethSepolia = NetworkConfig({
            token: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            priceFeed: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
        });
        NetworkConfig memory baseMainnet = NetworkConfig({
            token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            priceFeed: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B
        });
        NetworkConfig memory baseSepolia = NetworkConfig({
            token: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
            priceFeed: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165
        });

        if (_chainId == 1) {
            return ethMainnet.priceFeed;
        } else if (_chainId == 11155111) {
            return ethSepolia.priceFeed;
        } else if (_chainId == 8453) {
            return baseMainnet.priceFeed;
        } else if (_chainId == 84532) {
            return baseSepolia.priceFeed;
        } else {
            return _getOrCreateAnvilEthConfig();
        }
    }

    function _getOrCreateAnvilEthConfig() internal returns (address) {
        if (activeNetworkConfig != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(8, 2000e0);
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({token: address(0), priceFeed: address(mockPriceFeed)});
        return anvilConfig.priceFeed;
    }
}

// function getUsdtConfig(uint256 _chainId) public returns (NetworkConfig memory priceFeed) {
//     NetworkConfig memory ethMainnet = NetworkConfig({priceFeed: 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D});
//     NetworkConfig memory baseMainnet = NetworkConfig({priceFeed: 0xf19d560eB8d2ADf07BD6D13ed03e1D11215721F9});
//     NetworkConfig memory baseSepolia = NetworkConfig({priceFeed: 0x3ec8593F930EA45ea58c968260e6e9FF53FC934f});

//     if (_chainId == 1) {
//         return ethMainnet;
//     } else if (_chainId == 8453) {
//         return baseMainnet;
//     } else if (_chainId == 84532) {
//         return baseSepolia;
//     } else {
//         return getOrCreateAnvilEthConfig();
//     }
// }

// function getDaiConfig(uint256 _chainId) public returns (NetworkConfig memory priceFeed) {
//     NetworkConfig memory ethMainnet = NetworkConfig({priceFeed: 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9});
//     NetworkConfig memory ethSepolia = NetworkConfig({priceFeed: 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19});
//     NetworkConfig memory baseMainnet = NetworkConfig({priceFeed: 0x591e79239a7d679378eC8c847e5038150364C78F});
//     NetworkConfig memory baseSepolia = NetworkConfig({priceFeed: 0xD1092a65338d049DB68D7Be6bD89d17a0929945e});

//     if (_chainId == 1) {
//         return ethMainnet;
//     } else if (_chainId == 11155111) {
//         return ethSepolia;
//     } else if (_chainId == 8453) {
//         return baseMainnet;
//     } else if (_chainId == 84532) {
//         return baseSepolia;
//     } else {
//         return getOrCreateAnvilEthConfig();
//     }
// }
