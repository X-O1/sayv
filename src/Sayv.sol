// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

contract Sayv {
    ITokenRegistry public iTokenRegistry;
    address public s_tokenRegistryAddress;

    error NOT_OWNER(address caller, address owner);
    error TOKEN_NOT_APPROVED(address tokenAddress);
    error REGISTRY_ADDRESS_ALREADY_SET(address attemptedRegistryAddress, address activeRegistryAddress);

    address immutable i_owner;

    struct AccountType {
        bool yieldBarring;
        bool goalLocked;
        bool inheritable;
    }

    mapping(address account => AccountType) public s_accountTypes;
    mapping(address account => mapping(address token => uint256 amount)) public s_tokenBalances;

    event New_Token_Registry_Set(address indexed caller, address indexed newRegistry);

    constructor(address _tokenRegistryAddress) {
        i_owner = msg.sender;
        iTokenRegistry = ITokenRegistry(_tokenRegistryAddress);
        s_tokenRegistryAddress = _tokenRegistryAddress;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    function setTokenRegistry(address _tokenRegistryAddress) external onlyOwner {
        if (s_tokenRegistryAddress == _tokenRegistryAddress) {
            revert REGISTRY_ADDRESS_ALREADY_SET(_tokenRegistryAddress, s_tokenRegistryAddress);
        } else {
            iTokenRegistry = ITokenRegistry(_tokenRegistryAddress);
            s_tokenRegistryAddress = _tokenRegistryAddress;
        }
        emit New_Token_Registry_Set(msg.sender, s_tokenRegistryAddress);
    }

    function isApprovedOnRegistry(address _tokenAddress) public view returns (bool) {
        return iTokenRegistry.checkIfTokenIsApproved(_tokenAddress);
    }

    function getRegistryContractAddress() public view returns (address) {
        return s_tokenRegistryAddress;
    }

    function getSayvContractOwnerAddress() public view returns (address) {
        return i_owner;
    }

    function getSayvContractAddress() public view returns (address) {
        return address(this);
    }
}
