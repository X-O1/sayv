// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";
import {SayvVault} from "./SayvVault.sol";

contract SayvVaultFactory {
    IAccountManager immutable i_AccountManager;
    address immutable i_accountManagerAddress;
    address immutable i_owner;
    address[] public s_allActiveVaults; // To start USDC and aUSDC

    mapping(address vault => bool isActive) public s_activeVaults;

    event Vault_Created(address indexed token, address indexed activeYieldPool);

    constructor(address _accountManager) {
        i_owner = msg.sender;
        i_AccountManager = IAccountManager(_accountManager);
        i_AccountManager.lockAuthority(address(this));
        i_accountManagerAddress = _accountManager;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function createVault(address activeYieldPool, address _token) external onlyOwner returns (SayvVault) {
        if (!i_AccountManager._isTokenApprovedOnRegistry(_token)) {
            revert TOKEN_NOT_ALLOWED();
        }
        if (s_activeVaults[_token]) {
            revert VAULT_ALREADY_EXIST();
        }
        s_activeVaults[_token] = true;
        s_allActiveVaults.push(_token);

        SayvVault sayvVault = new SayvVault(i_accountManagerAddress, activeYieldPool, _token);
        emit Vault_Created(_token, activeYieldPool);
        return sayvVault;
    }
}
