// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";
import {IPool} from "@aave-v3-core/IPool.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract SayvVault {
    IERC20 immutable i_vaultToken;
    address immutable i_owner;
    address immutable i_accountManager;
    address immutable i_vaultTokenAddress;
    address immutable i_activeYieldPool;

    mapping(address vault => mapping(address token => uint256 balance)) public s_VaultBalance;
    mapping(address vault => mapping(address token => uint256 balance)) public s_advanceBalance;
    mapping(address vault => mapping(address token => uint256 balance)) public s_advanceFeesEarned;

    event Deposit_To_Vault(address indexed account, address indexed token, uint256 indexed amount);
    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);

    constructor(address _token, address _activeYieldPool, address _accountManager) {
        i_vaultToken = IERC20(_token);
        i_owner = msg.sender;
        i_activeYieldPool = _activeYieldPool;
        i_vaultTokenAddress = _token;
        i_accountManager = _accountManager;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    modifier onlyVaultAuthorized() {
        if (msg.sender != address(this)) {
            revert NOT_AUTHORIZED();
        }
        _;
    }

    function depositToVault(address _token, uint256 _amount) external {
        if (_token != i_vaultTokenAddress) {
            revert TOKEN_NOT_ALLOWED();
        }

        if (!i_vaultToken.approve(address(this), _amount)) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }

        if (i_vaultToken.allowance(msg.sender, address(this)) < _amount) {
            revert AMOUNT_NOT_APPROVED();
        }

        IAccountManager(i_accountManager).updateAccountBalance(msg.sender, _token, _amount);
        s_VaultBalance[address(this)][_token] += _amount;

        if (!i_vaultToken.transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        _depositToPool(_token, _amount, address(this), 0);

        emit Deposit_To_Vault(msg.sender, _token, _amount);
    }

    function _depositToPool(address _token, uint256 _amount, address _onBehalfOf, uint16 _referralCode)
        internal
        onlyVaultAuthorized
    {
        if (_token != i_vaultTokenAddress) {
            revert TOKEN_NOT_ALLOWED();
        }
        IPool(_token).supply(_token, _amount, _onBehalfOf, _referralCode);

        emit Deposit_To_Pool(_token, _amount);
    }

    function _withdrawFromPool(address _token, uint256 _amount, address _to)
        internal
        onlyVaultAuthorized
        returns (uint256)
    {
        if (_token != i_vaultTokenAddress) {
            revert TOKEN_NOT_ALLOWED();
        }
        emit Withdraw_From_Pool(_token, _amount, _to);
        return IPool(_token).withdraw(_token, _amount, _to);
    }
}
