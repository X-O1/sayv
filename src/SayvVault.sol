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

    event Deposit(address indexed account, address indexed token, uint256 indexed amount);

    constructor(address _accountManager, address _activeYieldPool, address _token) {
        i_owner = msg.sender;
        i_AccountManager = IAccountManager(_accountManager);
        i_activeYieldPool = IPool(_activeYieldPool);
        i_vaultToken = _token;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function deposit(address _token, uint256 _amount) external {
        if (!i_AccountManager._isTokenApprovedOnRegistry(_token)) {
            revert TOKEN_NOT_ALLOWED();
        }

        if (!IERC20(_token).approve(address(this), _amount)) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }

        if (IERC20(_token).allowance(msg.sender, address(this)) < _amount) {
            revert AMOUNT_NOT_APPROVED();
        }

        s_VaultBalance[address(this)][_token] += _amount;
        i_AccountManager.updateAccountBalance(msg.sender, _token, _amount);

        if (IERC20(_token).transferFrom(msg.sender, address(this), _amount)) {
            emit Deposit(msg.sender, _token, _amount);
        }

        //update aUSDC balance but may make that its own vault and have aave send to it onBehalf.
        IPool(_token).supply(_token, _amount, address(this), 0);
    }
}
