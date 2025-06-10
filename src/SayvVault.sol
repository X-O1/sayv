// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title SayvVault
/// @notice Handles user deposits, withdrawals, advances on yield, and interactions with an external yield pool
/// @dev Integrates an external yield pool like Aave IPool for yield operations using vaultToken as underlying asset
contract SayvVault {
    using FixedPointMathLib for uint256;

    /// @notice Aave pool contract
    IPool public immutable i_activePool;
    /// @notice Address of the Aave Pool
    IPoolAddressesProvider public immutable i_addressesProvider;
    /// @notice The ERC20 token this vault accepts (e.g. USDC)
    IERC20 public immutable i_vaultToken;
    IERC20 public immutable i_yieldBarringToken;
    /// @notice Owner of the contract, has special permissions
    address public immutable i_owner;

    /// @notice Number of decimals the vault token has. Needed to convert WAD numbers
    uint256 public immutable i_vaultTokenNumOfDecimals;

    /// @notice Represents a user's balances within the vault
    struct AccountBalance {
        /// @notice User’s total equity (deposited amount)
        uint256 accountDeposits;
        /// @notice Portion locked due to an active advance
        uint256 lockedDeposits;
        /// @notice Amount user owes due to taking an advance (includes fee)
        uint256 advanced;
    }

    /// @notice Represents the state of the vault itself
    struct VaultBalance {
        /// @notice Total user deposits
        uint256 totalDeposits;
        /// @notice Total value advanced from the vault
        uint256 totalAdvances;
    }

    mapping(address vault => mapping(address token => uint256 amount)) public s_yieldBarringTokenBalance;
    /// @notice Maps user address to their balance state
    mapping(address account => mapping(address token => AccountBalance)) public s_accountBalances;
    /// @notice Maps vault to its total state
    mapping(address vault => mapping(address token => VaultBalance)) public s_vaultBalances;

    /// @notice Emitted when a user deposits into the vault
    event Deposit_To_Vault(address indexed account, address indexed token, uint256 indexed amount);
    /// @notice Emitted when a user withdraws from the vault
    event Withdraw_From_Vault(address indexed token, uint256 indexed amount, address indexed to);
    /// @notice Emitted when funds are supplied to Aave or another pool
    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    /// @notice Emitted when funds are withdrawn from the pool
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    /// @notice Emitted when a user takes an advance on their yield
    event Advance_Taken(address indexed account, uint256 indexed amount);
    /// @notice Emitted when a user repays their advance
    event Advance_Repayment(address indexed account, uint256 indexed advanceBalance);

    /// @notice Constructor sets immutable parameters
    /// @param _token The vault token (e.g. USDC)
    /// @param _addressProvider The external yield protocol address (e.g. Aave pool)
    constructor(address _token, uint256 _numOfTokenDecimals, address _addressProvider, address _yieldBarringToken) {
        i_vaultToken = IERC20(_token); // Sets the token contract for vault operations
        i_yieldBarringToken = IERC20(_yieldBarringToken);
        i_addressesProvider = IPoolAddressesProvider(_addressProvider);
        i_activePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender; // Sets the owner of the contract to the deployer
        i_vaultTokenNumOfDecimals = _numOfTokenDecimals;
        i_vaultToken.approve(address(i_activePool), type(uint256).max);
    }

    /// @notice Deposits tokens into the vault and optionally repays user's outstanding advance
    /// @param _amount Amount to deposit
    /// @param _repay Whether this deposit should be applied to the user's debt
    function depositToVault(address _token, uint256 _amount, bool _repay) public {
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
        // If user chose to repay their advance with this deposit
        if (_repay) {
            _repayAdvance(_token, _amount); // Apply deposit to advance repayment
        } else {
            // If not repaying, treat it as a deposit
            s_accountBalances[msg.sender][_token].accountDeposits += _amount; // Add to user’s equity
            s_vaultBalances[address(this)][_token].totalDeposits += _amount; // Add to total vault deposits
        }
        // Supply deposit to Aave or similar pool
        _depositToPool(_token, _amount, address(this), 0);

        emit Deposit_To_Vault(msg.sender, _token, _amount); // Log deposit
    }

    /// @notice Withdraws available equity from the vault, optionally user can repay locked equity to unlock and withdraw
    /// @param _amount Amount to withdraw
    function withdrawFromVault(address _token, uint256 _amount, bool _repay) external {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        // If user chose to repay their advance before withdrawl
        if (_repay) {
            depositToVault(_token, _amount, _repay);
        }
        // // Ensure withdrawal amount is within available (non-locked) equity
        if (_amount > _getAmmountApprovedForWithdrawl(msg.sender, _token)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }
        if (!_repay) {
            s_accountBalances[msg.sender][_token].accountDeposits -= _amount;
            s_vaultBalances[address(this)][_token].totalDeposits -= _amount;
        }
        // Withdraw funds from the external pool and send to user
        _withdrawFromPool(_token, _amount, address(msg.sender));

        emit Withdraw_From_Vault(_token, _amount, msg.sender); // Log withdrawal
    }

    /// @notice Allows a user to borrow against their future yield (advance)
    /// @param _deposits Amount of their equity to lock as collateral
    /// @param _amount Advance amount the user is requesting
    function takeAdvance(address _token, uint256 _deposits, uint256 _amount) external {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        // Ensure the vault has enough liquidity to offer advances
        if (!_isTotalAdvancesLessThanTotalDeposits(_token)) {
            revert ADVANCES_NOT_AVAILABLE();
        }

        // // User can't borrow more than their available equity
        if (_amount > _getAmmountApprovedForWithdrawl(msg.sender, _token)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }

        // // Enforce max advance % logic (e.g. can’t borrow 90% of equity if cap is 60%)
        if (_getPercentage(_amount, _getAccountAdvancedBalance(msg.sender, _token)) > _getAdvancePercentageMax(_token))
        {
            revert ADVANCE_MAX_REACHED();
        }
        // Calculate fees based on vault config + amount being borrowed
        uint256 advanceFee = _getFeeForAdvance(_token, _deposits, _amount);
        uint256 requestedAdvancePlusFee = _amount + advanceFee; // Total debt incurred
        uint256 advanceMinusFee = _amount - advanceFee; // Actual funds user receives

        // Update vault state
        s_vaultBalances[address(this)][_token].totalAdvances += _amount;
        s_vaultBalances[address(this)][_token].totalDeposits -= _amount;

        // Lock equity and assign the full advance balance (with fee) to the user
        s_accountBalances[msg.sender][_token].lockedDeposits += _deposits;
        s_accountBalances[msg.sender][_token].advanced += requestedAdvancePlusFee;

        // Send funds to user
        _withdrawFromPool(_token, advanceMinusFee, msg.sender);

        emit Advance_Taken(msg.sender, _amount); // Log advance
    }

    /// @notice Internal: Repays user’s outstanding advance
    /// @param _amount Amount sent to repay the advance
    function _repayAdvance(address _token, uint256 _amount) internal {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        uint256 advanceBalance = _getAccountAdvancedBalance(msg.sender, _token);

        // Full repayment
        if (_amount >= advanceBalance) {
            s_accountBalances[msg.sender][_token].accountDeposits += (_amount - advanceBalance); // leftover goes to equity
            s_accountBalances[msg.sender][_token].advanced = 0;
            s_accountBalances[msg.sender][_token].lockedDeposits = 0;
            s_vaultBalances[address(this)][_token].totalDeposits += _amount;
            s_vaultBalances[address(this)][_token].totalAdvances -= _amount;
        }

        // Partial repayment
        if (_amount < advanceBalance) {
            s_accountBalances[msg.sender][_token].advanced -= _amount;
            s_vaultBalances[address(this)][_token].totalDeposits += _amount;
            s_vaultBalances[address(this)][_token].totalAdvances -= _amount;
        }

        emit Advance_Repayment(msg.sender, advanceBalance); // Log advance repayment
    }

    /// @notice Supplies tokens to external yield protocol
    function _depositToPool(address _token, uint256 _amount, address _onBehalfOf, uint16 _referralCode) private {
        i_activePool.supply(_token, _amount, _onBehalfOf, _referralCode);
        emit Deposit_To_Pool(_token, _amount); // Logs deposit
    }

    /// @notice Withdraws from external yield protocol and sends to target address
    function _withdrawFromPool(address _token, uint256 _amount, address _to) private {
        i_activePool.withdraw(_token, _amount, _to);
        emit Withdraw_From_Pool(_token, _amount, _to); // Logs withdraw
    }

    /// @notice Gets the amount of account's funds available for withdrawl
    function _getAmmountApprovedForWithdrawl(address _account, address _token) internal view returns (uint256) {
        uint256 totalVaultYieldBarringTokenBalanceIncludingYield = _getVaultYieldTokenBalance();
        uint256 totalVaultDeposits = _getVaultTotalDeposits(_token);
        uint256 totalAccountDeposits = _getAccountDeposits(_account, _token);
        uint256 totalAccountLockedDeposits = _getAccountLockedDeposits(_account, _token);
        uint256 accountEquityPercentage = _getPercentage(totalAccountDeposits, totalVaultDeposits);
        uint256 totalAccountVaultEquity =
            _getPercentageAmount(totalVaultYieldBarringTokenBalanceIncludingYield, accountEquityPercentage);
        uint256 availableForWithdraw = totalAccountVaultEquity - totalAccountLockedDeposits;
        return availableForWithdraw;
    }

    /// @notice Returns vault’s current advance fee, capped at 25%
    function _getVaultAdvanceFee(address _token) internal view returns (uint256) {
        return _getAdvancePercentageOfDeposits(_token);
    }

    /// @notice Gets the maximum advance percentage a user is allowed
    function _getAdvancePercentageMax(address _token) internal view returns (uint256) {
        return 100 - _getAdvancePercentageOfDeposits(_token);
    }

    /// @notice Calculates the fee for a specific advance
    function _getFeeForAdvance(address _token, uint256 _deposits, uint256 _amount) internal view returns (uint256) {
        uint256 baseFeePercentage = _getVaultAdvanceFee(_token);
        uint256 advanceToEquityPercentage = _getPercentage(_amount, _deposits);

        uint256 baseFee = _getPercentageAmount(_amount, baseFeePercentage);
        uint256 bonusFee = _getPercentageAmount(baseFee, advanceToEquityPercentage);

        return baseFee + bonusFee;
    }

    /// @notice Gets what % of the vault's total deposits are currently advanced
    function _getAdvancePercentageOfDeposits(address _token) internal view returns (uint256) {
        uint256 totalVaultAdvances = s_vaultBalances[address(this)][_token].totalAdvances;
        uint256 totalVaultDeposits = s_vaultBalances[address(this)][_token].totalDeposits;
        return _getPercentage(totalVaultAdvances, totalVaultDeposits);
    }

    /// @notice Checks if there is room for more advances (advances < deposits)
    function _isTotalAdvancesLessThanTotalDeposits(address _token) internal view returns (bool) {
        bool isLessThan;
        s_vaultBalances[address(this)][_token].totalAdvances < _getVaultYieldTokenBalance()
            ? isLessThan = true
            : isLessThan = false;
        return isLessThan;
    }

    function _getPercentage(uint256 _partNumber, uint256 _wholeNumber) internal pure returns (uint256) {
        return (_partNumber * 100) / _wholeNumber;
    }

    function _getPercentageAmount(uint256 _wholeNumber, uint256 _percent) internal pure returns (uint256) {
        return (_wholeNumber * _percent) / 100;
    }

    /// @notice Returns total equity of a user
    function _getAccountDeposits(address _account, address _token) public view returns (uint256) {
        return s_accountBalances[_account][_token].accountDeposits;
    }

    /// @notice Returns user’s outstanding advance balance
    function _getAccountAdvancedBalance(address _account, address _token) public view returns (uint256) {
        return s_accountBalances[_account][_token].advanced;
    }

    /// @notice Returns amount of equity locked due to an advance
    function _getAccountLockedDeposits(address _account, address _token) public view returns (uint256) {
        return s_accountBalances[_account][_token].lockedDeposits;
    }

    function _getVaultTotalDeposits(address _token) public view returns (uint256) {
        return s_vaultBalances[address(this)][_token].totalDeposits;
    }

    function _getVaultTotalAdvances(address _token) public view returns (uint256) {
        return s_vaultBalances[address(this)][_token].totalAdvances;
    }

    function _getVaultYieldTokenBalance() public view returns (uint256) {
        return i_yieldBarringToken.balanceOf(address(this));
    }

    function _getVaultYield(address _token) internal view returns (uint256) {
        return _getVaultYieldTokenBalance() - s_vaultBalances[address(this)][_token].totalDeposits;
    }

    function getVaultAddress() external view returns (address) {
        return address(this);
    }

    function getActivePoolAddress() external view returns (address) {
        return address(i_activePool);
    }
}
