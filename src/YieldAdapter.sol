// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {YieldLeasing} from "./YieldLeasing.sol";

/// @title SayvVault
/// @notice Handles user deposits, withdrawals, and interactions with an external yield pool
contract YieldAdapter {
    IPool public immutable i_activePool;
    IPoolAddressesProvider public immutable i_addressesProvider;
    IERC20 public immutable i_vaultToken;
    IERC20 public immutable i_yieldBarringToken;
    address public immutable i_owner;
    YieldLeasing internal s_yieldLeasing;
    bool public s_yieldLeasingContractAddressIsSet;

    mapping(address account => mapping(address token => uint256 amount)) public s_deposits;
    mapping(address vault => mapping(address token => uint256 amount)) public s_totalDeposits;

    event Deposit_To_Vault(address indexed account, address indexed token, uint256 indexed amount);
    event Withdraw_From_Vault(address indexed token, uint256 indexed amount, address indexed to);
    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    event Yield_Leasing_Contract_Address_Set(address indexed yieldLeasingAddress);
    event Yield_Leasing_Opt_In_Transfer(address indexed account, address indexed token, uint256 amount);

    /// @notice Constructor sets immutable parameters
    /// @param _token The vault token (e.g. USDC)
    /// @param _addressProvider The external yield protocol address (e.g. Aave pool)
    constructor(address _token, address _addressProvider, address _yieldBarringToken) {
        i_vaultToken = IERC20(_token); // Sets the token contract for vault operations
        i_yieldBarringToken = IERC20(_yieldBarringToken);
        i_addressesProvider = IPoolAddressesProvider(_addressProvider);
        i_activePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender; // Sets the owner of the contract to the deployer
        i_vaultToken.approve(address(i_activePool), type(uint256).max);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    modifier onlyYieldLeasingContract() {
        if (msg.sender != address(s_yieldLeasing)) {
            revert NOT_OWNER();
        }
        _;
    }

    function setYieldLeasingContractAddress(address _yieldLeasingAddress) public onlyOwner {
        if (s_yieldLeasingContractAddressIsSet) {
            revert YIELD_LEASING_ADDRESS_ALREADY_SET();
        }
        s_yieldLeasing = YieldLeasing(_yieldLeasingAddress);
        s_yieldLeasingContractAddressIsSet = true;
        i_yieldBarringToken.approve(address(s_yieldLeasing), type(uint256).max);

        emit Yield_Leasing_Contract_Address_Set(_yieldLeasingAddress);
    }

    /// @notice Deposits tokens into the vault and optionally repays user's outstanding advance
    /// @param _amount Amount to deposit
    function depositToVault(address _token, uint256 _amount) public {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        // Approve this contract to spend vaultToken (this is redundant unless allowance was reset or first deposit)
        if (i_vaultToken.allowance(msg.sender, address(this)) < _amount) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }
        // Move tokens from user to vault
        if (!i_vaultToken.transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        // If not repaying, treat it as a deposit
        s_deposits[msg.sender][_token] += _amount; // Add to user’s equity
        s_totalDeposits[address(this)][_token] += _amount; // Add to total vault deposits
        // Supply deposit to Aave or similar pool
        _depositToPool(_token, _amount, address(this), 0);

        emit Deposit_To_Vault(msg.sender, _token, _amount); // Log deposit
    }

    /// @notice Withdraws available equity from the vault, optionally user can repay locked equity to unlock and withdraw
    /// @param _amount Amount to withdraw
    function withdrawFromVault(address _token, uint256 _amount) external {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }

        // // Ensure withdrawal amount is within available (non-locked) equity
        if (_amount > _getAmountApprovedForWithdrawl(msg.sender, _token)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }

        s_deposits[msg.sender][_token] -= _amount;
        s_totalDeposits[address(this)][_token] -= _amount;
        // Withdraw funds from the external pool and send to user
        _withdrawFromPool(_token, _amount, address(msg.sender));

        emit Withdraw_From_Vault(_token, _amount, msg.sender); // Log withdrawal
    }

    function _addDeposit(address _account, address _token, uint256 _amount) external {
        s_deposits[_account][_token] += _amount;
        s_totalDeposits[address(this)][_token] += _amount;
    }

    function _removeDeposit(address _account, address _token, uint256 _amount) external {
        if (_getAccountDeposits(_account, _token) < _amount || _getTotalDeposits(address(this), _token) < _amount) {
            revert ERROR_UPDATING_BALANCES();
        }
        s_deposits[_account][_token] -= _amount;
        s_totalDeposits[address(this)][_token] -= _amount;
    }

    /// @notice Supplies tokens to external yield protocol
    function _depositToPool(address _token, uint256 _amount, address _onBehalfOf, uint16 _referralCode) internal {
        i_activePool.supply(_token, _amount, _onBehalfOf, _referralCode);
        emit Deposit_To_Pool(_token, _amount); // Logs deposit
    }

    /// @notice Withdraws from external yield protocol and sends to target address
    function _withdrawFromPool(address _token, uint256 _amount, address _to) internal {
        i_activePool.withdraw(_token, _amount, _to);
        emit Withdraw_From_Pool(_token, _amount, _to); // Logs withdraw
    }

    /// @notice Gets the amount of account's funds available for withdrawl.
    function _getAmountApprovedForWithdrawl(address _account, address _token) public view returns (uint256) {
        uint256 totalVaultYieldBarringTokenBalanceIncludingYield = _getVaultYieldTokenBalance();
        uint256 totalVaultDeposits = s_totalDeposits[address(this)][_token];
        uint256 totalAccountDeposits = s_deposits[_account][_token];

        uint256 accountEquityPercentage = _getPercentage(totalAccountDeposits, totalVaultDeposits);
        uint256 totalAccountVaultEquity =
            _getPercentageAmount(totalVaultYieldBarringTokenBalanceIncludingYield, accountEquityPercentage);

        uint256 availableForWithdraw = totalAccountVaultEquity;

        return availableForWithdraw;
    }

    /// @notice Returns total equity of a user
    function _getAccountDeposits(address _account, address _token) public view returns (uint256) {
        return s_deposits[_account][_token];
    }

    function _getTotalDeposits(address _account, address _token) public view returns (uint256) {
        return s_totalDeposits[_account][_token];
    }

    function _getVaultYieldTokenBalance() public view returns (uint256) {
        return i_yieldBarringToken.balanceOf(address(this));
    }

    function _getVaultYield(address _token) internal view returns (uint256) {
        return _getVaultYieldTokenBalance() - s_totalDeposits[address(this)][_token];
    }

    function _getPercentage(uint256 _partNumber, uint256 _wholeNumber) internal pure returns (uint256) {
        return (_partNumber * 100) / _wholeNumber;
    }

    function _getPercentageAmount(uint256 _wholeNumber, uint256 _percent) internal pure returns (uint256) {
        return (_wholeNumber * _percent) / 100;
    }

    function getVaultAddress() external view returns (address) {
        return address(this);
    }

    function getActivePoolAddress() external view returns (address) {
        return address(i_activePool);
    }
}
