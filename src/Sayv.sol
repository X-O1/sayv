// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

contract Sayv {
    ITokenRegistry public iTokenRegistry;
    address public s_tokenRegistryAddress;

    error NOT_OWNER(address caller, address owner);
    error TOKEN_NOT_APPROVED(address tokenAddress);
    error REGISTRY_ADDRESS_ALREADY_SET(address attemptedRegistryAddress, address activeRegistryAddress);
    error WITHDRAW_GOAL_NOT_MET(uint256 currentAmount, uint256 goalAmount);
    error ACCOUNT_ALREADY_GOAL_LOCKED(address account, address token, uint256 goalAmount);

    address immutable i_owner;

    struct AccountType {
        bool yieldBarring;
        bool goalLocked;
        bool inheritable;
    }

    mapping(address account => AccountType) public s_accountTypes;
    mapping(address account => mapping(address token => uint256 amount)) public s_tokenBalances;
    mapping(address account => mapping(address token => uint256 goalAmount)) public s_goalLockAmounts;

    event New_Token_Registry_Set(address indexed caller, address indexed newRegistry);
    event Account_Was_Goal_Locked(address indexed account, address indexed token, uint256 indexed goalAmount);

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

    function _addAndSetGoalLockAmount(address _account, address _token, uint256 _goalAmount) internal {
        if (_isGoalLocked(_account)) {
            revert ACCOUNT_ALREADY_GOAL_LOCKED(_account, _token, _goalAmount);
        } else {
            AccountType storage account = s_accountTypes[_account];
            account.goalLocked = true;
            s_goalLockAmounts[_account][_token] = _goalAmount;
        }
        emit Account_Was_Goal_Locked(_account, _token, _goalAmount);
    }

    function _isApprovedOnRegistry(address _tokenAddress) internal view returns (bool) {
        return iTokenRegistry.checkIfTokenIsApproved(_tokenAddress);
    }

    function _isGoalLocked(address _account) internal view returns (bool) {
        AccountType storage account = s_accountTypes[_account];
        return account.goalLocked;
    }

    function _isYieldBarring(address _account) internal view returns (bool) {
        AccountType storage account = s_accountTypes[_account];
        return account.yieldBarring;
    }

    function _isInheritable(address _account) internal view returns (bool) {
        AccountType storage account = s_accountTypes[_account];
        return account.inheritable;
    }

    function getRegistryContractAddress() public view returns (address) {
        return s_tokenRegistryAddress;
    }
}
