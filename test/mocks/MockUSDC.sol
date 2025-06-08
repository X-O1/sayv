// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor(address _dev) ERC20("USDC", "USDC") {
        _mint(_dev, 1000000e18);
    }
}
