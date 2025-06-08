// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/IPool.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

/// @title SayvVault
/// @notice Handles user deposits, withdrawals, advances on yield, and interactions with an external yield pool
/// @dev Integrates an external yield pool like Aave IPool for yield operations using vaultToken as underlying asset
contract SayvVault {
    using FixedPointMathLib for uint256;

    /// @notice The ERC20 token this vault accepts (e.g. USDC)
    IERC20 immutable i_vaultToken;
    /// @notice Owner of the contract, has special permissions
    address immutable i_owner;
    /// @notice Cached address of the vault token
    address immutable i_vaultTokenAddress;
    /// @notice Address of the Aave Pool or similar yield strategy
    address immutable i_activePool;
    /// @notice Number of decimals the vault token has. Needed to convert WAD numbers
    uint256 immutable i_vaultTokenNumOfDecimals;

    /// @dev Initialized to track total vault-wide deposits and advances
    uint256 private s_totalVaultDeposits = s_vaultBalances[address(this)].totalDeposits;
    uint256 private s_totalVaultAdvances = s_vaultBalances[address(this)].totalAdvances;

    /// @notice Represents a user's balances within the vault
    struct AccountBalance {
        /// @notice User’s total equity (deposited amount)
        uint256 accountEquity;
        /// @notice Portion locked due to an active advance
        uint256 lockedEquity;
        /// @notice Amount user owes due to taking an advance (includes fee)
        uint256 advancedEquity;
    }

    /// @notice Represents the state of the vault itself
    struct VaultBalance {
        /// @notice Total user deposits
        uint256 totalDeposits;
        /// @notice Total value advanced from the vault
        uint256 totalAdvances;
    }

    /// @notice Maps user address to their balance state
    mapping(address account => AccountBalance) public s_accountBalances;
    /// @notice Maps vault to its total state
    mapping(address vault => VaultBalance) public s_vaultBalances;

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
    /// @param _activePool The external yield protocol address (e.g. Aave pool)
    constructor(address _token, uint256 _numOfTokenDecimals, address _activePool) {
        i_vaultToken = IERC20(_token); // Sets the token contract for vault operations
        i_owner = msg.sender; // Sets the owner of the contract to the deployer
        i_activePool = _activePool; // Saves the yield pool address (like Aave’s)
        i_vaultTokenAddress = _token; // Cache for token address (for readability/logs)
        i_vaultTokenNumOfDecimals = _numOfTokenDecimals;
    }

    /// @notice Restricts access to the contract owner
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(); // Only allow owner to proceed
        }
        _;
    }

    /// @notice Deposits tokens into the vault and optionally repays user's outstanding advance
    /// @param _amount Amount to deposit
    /// @param _repay Whether this deposit should be applied to the user's debt
    function depositToVault(uint256 _amount, bool _repay) public {
        // Approve this contract to spend vaultToken (this is redundant unless allowance was reset or first deposit)
        if (!i_vaultToken.approve(address(this), _amount)) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }

        // If user chose to repay their advance with this deposit
        if (_repay) {
            _repayAdvance(_amount); // Apply deposit to advance repayment
        }

        // If not repaying, treat it as a deposit
        if (!_repay) {
            s_accountBalances[msg.sender].accountEquity += _amount; // Add to user’s equity
            s_vaultBalances[address(this)].totalDeposits += _amount; // Add to total vault deposits
        }

        // Move tokens from user to vault
        if (!i_vaultToken.transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        // Supply deposit to Aave or similar pool
        _depositToPool(_amount, address(this), 0);

        emit Deposit_To_Vault(msg.sender, i_vaultTokenAddress, _amount); // Log deposit
    }

    /// @notice Withdraws available equity from the vault, optionally user can repay locked equity to unlock and withdraw
    /// @param _amount Amount to withdraw
    function withdrawFromVault(uint256 _amount, bool _repay) external {
        // If user chose to repay their advance before withdrawl
        if (_repay) {
            depositToVault(_amount, _repay);
        }
        // Ensure withdrawal amount is within available (non-locked) equity

        if (_amount > fromWadToTokenDecimals(getAccountAvailableEquity(msg.sender), i_vaultTokenNumOfDecimals)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }
        if (!_repay) {
            s_accountBalances[msg.sender].accountEquity -= _amount;
            s_vaultBalances[address(this)].totalDeposits -= _amount;
        }

        // Withdraw funds from the external pool and send to user
        _withdrawFromPool(_amount, msg.sender);

        emit Withdraw_From_Vault(i_vaultTokenAddress, _amount, msg.sender); // Log withdrawal
    }

    /// @notice Allows a user to borrow against their future yield (advance)
    /// @param _equity Amount of their equity to lock as collateral
    /// @param _amount Advance amount the user is requesting
    function takeAdvance(uint256 _equity, uint256 _amount) external {
        // Ensure the vault has enough liquidity to offer advances
        if (!_isTotalAdvancesLessThanTotalDeposits()) {
            revert ADVANCES_NOT_AVAILABLE();
        }

        // User can't borrow more than their available equity
        if (_amount > fromWadToTokenDecimals(getAccountAvailableEquity(msg.sender), i_vaultTokenNumOfDecimals)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }

        // Enforce max advance % logic (e.g. can’t borrow 90% of equity if cap is 60%)
        if (
            fromWadToTokenDecimals(
                _getAdvanceToEquityRatio(_amount, getAccountAvailableEquity(msg.sender)), i_vaultTokenNumOfDecimals
            ) > fromWadToTokenDecimals(_getAdvancePercentageMax(), i_vaultTokenNumOfDecimals)
        ) {
            revert ADVANCE_MAX_REACHED();
        }
        // Calculate fees based on vault config + amount being borrowed
        uint256 advanceFee = fromWadToTokenDecimals(_getFeeForAdvance(_equity, _amount), i_vaultTokenNumOfDecimals);
        uint256 requestedAdvancePlusFee = _amount + advanceFee; // Total debt incurred
        uint256 advanceMinusFee = _amount - advanceFee; // Actual funds user receives

        // Update vault state
        s_vaultBalances[address(this)].totalAdvances += _amount;
        s_vaultBalances[address(this)].totalDeposits -= _amount;

        // Lock equity and assign the full advance balance (with fee) to the user
        s_accountBalances[msg.sender].lockedEquity += _equity;
        s_accountBalances[msg.sender].advancedEquity += requestedAdvancePlusFee;

        // Send funds to user
        _withdrawFromPool(advanceMinusFee, msg.sender);

        emit Advance_Taken(msg.sender, _amount); // Log advance
    }

    /// @notice Internal: Repays user’s outstanding advance
    /// @param _amount Amount sent to repay the advance
    function _repayAdvance(uint256 _amount) internal {
        uint256 advanceBalance = getAccountAdvancedEquity(msg.sender);

        // Full repayment
        if (_amount >= advanceBalance) {
            s_accountBalances[msg.sender].accountEquity += (_amount - advanceBalance); // leftover goes to equity
            s_accountBalances[msg.sender].advancedEquity = 0;
            s_accountBalances[msg.sender].lockedEquity = 0;
            s_vaultBalances[address(this)].totalDeposits += _amount;
            s_vaultBalances[address(this)].totalAdvances -= _amount;
        }

        // Partial repayment
        if (_amount < advanceBalance) {
            s_accountBalances[msg.sender].advancedEquity -= _amount;
            s_vaultBalances[address(this)].totalDeposits += _amount;
            s_vaultBalances[address(this)].totalAdvances -= _amount;
        }

        emit Advance_Repayment(msg.sender, advanceBalance); // Log advance repayment
    }

    /// @notice Supplies tokens to external yield protocol
    function _depositToPool(uint256 _amount, address _onBehalfOf, uint16 _referralCode) private {
        IPool(i_activePool).supply(i_vaultTokenAddress, _amount, _onBehalfOf, _referralCode);
        emit Deposit_To_Pool(i_vaultTokenAddress, _amount); // Logs deposit
    }

    /// @notice Withdraws from external yield protocol and sends to target address
    function _withdrawFromPool(uint256 _amount, address _to) private {
        IPool(i_activePool).withdraw(i_vaultTokenAddress, _amount, _to);
        emit Withdraw_From_Pool(i_vaultTokenAddress, _amount, _to); // Logs withdraw
    }

    /// @notice Returns vault’s current advance fee, capped at 25%
    function _getVaultAdvanceFee() internal view returns (uint256) {
        return _getAdvancePercentageOfDeposits() > 25 ? 25 : _getAdvancePercentageOfDeposits();
    }

    /// @notice Gets the maximum advance percentage a user is allowed
    function _getAdvancePercentageMax() internal view returns (uint256) {
        return 100 - _getAdvancePercentageOfDeposits();
    }

    /// @notice Calculates the fee for a specific advance
    function _getFeeForAdvance(uint256 _equity, uint256 _amount) internal view returns (uint256) {
        uint256 baseFeePercentage = _getVaultAdvanceFee();
        uint256 advanceToEquityRatio = _getAdvanceToEquityRatio(_amount, _equity);
        uint256 baseFee = _amount.mulWadDown(baseFeePercentage);
        uint256 bonusFee = baseFee.mulWadDown(advanceToEquityRatio);

        return baseFee + bonusFee;
    }

    /// @notice Calculates advance/equity ratio in percent
    function _getAdvanceToEquityRatio(uint256 _amount, uint256 _equity) internal pure returns (uint256) {
        return _amount.divWadDown(_equity);
    }

    /// @notice Gets what % of the vault's total deposits are currently advanced
    function _getAdvancePercentageOfDeposits() internal view returns (uint256) {
        return s_totalVaultAdvances.divWadDown(s_totalVaultDeposits);
    }

    /// @notice Returns the percentage of the vault owned by a user
    function _getAccountVaultEquity(address _account) internal view returns (uint256) {
        return getAccountTotalEquity(_account).divWadDown(s_totalVaultDeposits);
    }

    /// @notice Checks if there is room for more advances (advances < deposits)
    function _isTotalAdvancesLessThanTotalDeposits() internal view returns (bool) {
        bool isLessThan;
        s_totalVaultAdvances < s_totalVaultDeposits ? isLessThan = true : isLessThan = false;
        return isLessThan;
    }

    /// @notice Returns total equity of a user
    function getAccountTotalEquity(address _account) public view returns (uint256) {
        return s_accountBalances[_account].accountEquity;
    }

    /// @notice Returns how much equity a user can withdraw (not locked)
    function getAccountAvailableEquity(address _account) public view returns (uint256) {
        return _getAccountVaultEquity(_account) - s_accountBalances[_account].lockedEquity;
    }

    /// @notice Returns user’s outstanding advance balance
    function getAccountAdvancedEquity(address _account) public view returns (uint256) {
        return s_accountBalances[_account].advancedEquity;
    }

    /// @notice Returns amount of equity locked due to an advance
    function getAccountLockedEquity(address _account) public view returns (uint256) {
        return s_accountBalances[_account].lockedEquity;
    }

    /// @notice Converts wad numbers to their orginal decimals
    function fromWadToTokenDecimals(uint256 _wadAmount, uint256 _tokenDecimals) internal pure returns (uint256) {
        if (_tokenDecimals >= 18) {
            revert TOO_MANY_DECIMALS();
        }
        return _wadAmount / (10 ** (18 - _tokenDecimals));
    }
}
