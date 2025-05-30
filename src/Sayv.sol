// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

contract Sayv {
    ITokenRegistry public iTokenRegistry;
    address tokenRegistryAddress;

    error NOT_OWNER(address caller, address owner);
    error TOKEN_NOT_APPROVED(address tokenAddress);

    address immutable i_owner;

    constructor(address _tokenRegistryAddress) {
        i_owner = msg.sender;
        iTokenRegistry = ITokenRegistry(_tokenRegistryAddress);
        tokenRegistryAddress = _tokenRegistryAddress;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    function setTokenRegistry(address _tokenRegistryAddress) external onlyOwner {
        iTokenRegistry = ITokenRegistry(_tokenRegistryAddress);
        tokenRegistryAddress = _tokenRegistryAddress;
    }

    function isApprovedOnRegistry(address _tokenAddress) public view returns (bool) {
        return iTokenRegistry.checkIfTokenIsApproved(_tokenAddress);
    }

    function getRegistryContractAddress() public view returns (address) {
        return tokenRegistryAddress;
    }

    function getRegistryContractOwnerAddress() public view returns (address) {
        return iTokenRegistry.getRegistryContractOwnerAddress();
    }

    function getSayvContractOwnerAddress() public view returns (address) {
        return i_owner;
    }

    function getSayvContractAddress() public view returns (address) {
        return address(this);
    }
}
