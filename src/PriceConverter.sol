// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice() internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);
        (, int256 price,,,) = priceFeed.latestRoundData();

        require(price > 0, "Invalid price");

        return uint256(price) * 1e6;
    }

    function getConversionRate(uint256 amount) internal view returns (uint256) {
        uint256 usdcPrice = getPrice();
        uint256 usdcAmountInUsd = (usdcPrice * amount) / 1e8;
        return usdcAmountInUsd;
    }

    function getVersion() internal view returns (uint256) {
        return AggregatorV3Interface(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238).version();
    }
}
