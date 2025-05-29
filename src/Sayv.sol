// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {TokenRegistry} from "../src/TokenRegistry.sol";

/**
 * @title Sayv
 * @notice Main Functions
 * @dev ..
 * @custom:author https://github.com/X-O1
 * @custom:version v1.0
 */
contract Sayv {
    using PriceConverter for uint256;

    AggregatorV3Interface private s_priceFeed;
    TokenRegistry private s_tokenRegistry;

    constructor(address _tokenRegistry, address _priceFeed) {
        s_priceFeed = AggregatorV3Interface(_priceFeed);
        s_tokenRegistry = TokenRegistry(_tokenRegistry);
    }
}
