// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";
import {IPool} from "@aave-v3-core/IPool.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract SayvVault {
    bool public isVaultActive; // Vault factory must call true to activate the vault.

    IAccountManager immutable i_AccountManager;
    IPool immutable i_activeYieldPool;
    address immutable i_owner;
    address immutable i_vaultToken;

    mapping(address vault => mapping(address token => uint256 balance)) public s_VaultBalance;
    mapping(address vault => mapping(address token => uint256 balance)) public s_advanceBalance;
    mapping(address vault => mapping(address token => uint256 balance)) public s_advanceFeesEarned;

    constructor(address _accountManager, address _activeYieldPool, address _token) {
        i_owner = msg.sender;
        i_AccountManager = IAccountManager(_accountManager);
        i_activeYieldPool = IPool(_activeYieldPool);
        i_vaultToken = _token;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    function deposit(address _token, uint256 _amount) external {}
    // Deposit into sayv auto sends to aave.
}
