// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

contract Sayv {
    ITokenRegistry public iTokenRegistry;

    error NOT_OWNER(address caller, address owner);

    address immutable i_owner;

    constructor() {
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        } else {
            _;
        }
    }

    function setTokenRegistry(address _tokenRegistryAddress) external onlyOwner {
        iTokenRegistry = ITokenRegistry(_tokenRegistryAddress);
    }
}
