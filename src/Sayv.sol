// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IYieldWield} from "@yieldwield/interfaces/IYieldWield.sol";
import {ITokenRegistry} from "@token-registry/Interfaces/ITokenRegistry.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

contract Sayv is ReentrancyGuard {
    // External contract interface for yield management
    IYieldWield public immutable i_yieldWield;
    // Token registry contract to manage allowed tokens
    ITokenRegistry public immutable i_tokenRegistry;
    // Aave pool to handle deposit/withdraw operations
    IPool public immutable i_aavePool;
    // Provider for getting the Aave pool
    IPoolAddressesProvider public immutable i_addressesProvider;
    // Contract owner address
    address public immutable i_owner;
    // Total shares issued for yield deposits
    uint256 private s_totalYieldShares;
    // Total shares collected as revenue (fees)
    uint256 private s_totalRevenueShares;

    // Mapping of user => token => yield share amount
    mapping(address account => mapping(address token => uint256 amount)) public s_yieldShares;

    // Emitted on deposit
    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    // Emitted on withdrawal
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    // Emitted when a user takes an advance against yield
    event Advance_Taken(address indexed account, address indexed token, uint256 collateral, uint256 advanceMinusFee);
    // Emitted when user collateral is withdrawn
    event Withdraw_Collateral(address indexed account, address indexed token, uint256 collateralWithdrawn);
    // Emitted when user repays advance
    event Advance_Repayment_Deposit(
        address indexed account, address indexed token, uint256 repaidAmount, uint256 currentDebt
    );

    // Constructor sets up external references and stores deployer as owner
    constructor(address _addressProviderAddress, address _yieldWieldAddress, address _tokenRegistryAddress) {
        i_addressesProvider = IPoolAddressesProvider(_addressProviderAddress);
        i_aavePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender;
        i_yieldWield = IYieldWield(_yieldWieldAddress);
        i_tokenRegistry = ITokenRegistry(_tokenRegistryAddress);
    }

    // Modifier to restrict function to only the contract owner
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    /// @notice Adds or removes a token from the permitted list and approves Aave if adding
    /// @param _tokenAddress The token to add or remove
    /// @param _isApproved True to add to the registry, false to remove
    function managePermittedTokens(address _tokenAddress, bool _isApproved) external onlyOwner {
        _isApproved
            ? i_tokenRegistry.addTokenToRegistry(_tokenAddress)
            : i_tokenRegistry.removeTokenFromRegistry(_tokenAddress);

        if (_isApproved) {
            IERC20(_tokenAddress).approve(address(i_aavePool), type(uint256).max);
        }
    }

    /// @notice Deposits tokens into Aave and mints yield shares
    /// @param _token The token to deposit
    /// @param _amount The amount of tokens to deposit
    function depositToVault(address _token, uint256 _amount) public {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();
        if (IERC20(_token).allowance(msg.sender, address(this)) < _amount) revert ALLOWANCE_NOT_ENOUGH();
        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) revert DEPOSIT_FAILED();

        i_aavePool.supply(_token, _amount, address(this), 0);
        uint256 sharesClaimed = _shareConverter(_token, _amount);
        s_yieldShares[msg.sender][_token] += sharesClaimed;
        s_totalYieldShares += sharesClaimed;

        emit Deposit_To_Pool(_token, _amount);
    }

    /// @notice Redeems yield shares and withdraws tokens
    /// @param _token The token to withdraw
    /// @param _amount The amount of tokens to withdraw
    function withdrawFromVault(address _token, uint256 _amount) external nonReentrant {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();
        if (_amount > getAccountShareValue(_token, msg.sender)) revert INSUFFICIENT_AVAILABLE_FUNDS();

        uint256 sharesRedeemed = _shareConverter(_token, _amount);
        if (s_yieldShares[msg.sender][_token] < sharesRedeemed || s_totalYieldShares < sharesRedeemed) {
            revert UNDERFLOW();
        }

        s_yieldShares[msg.sender][_token] -= sharesRedeemed;
        s_totalYieldShares -= sharesRedeemed;

        i_aavePool.withdraw(_token, _amount, msg.sender);
        emit Withdraw_From_Pool(_token, _amount, msg.sender);
    }

    /// @notice Allows a user to take an advance on future yield by pledging existing yield shares as collateral
    /// @param _token The token to use for collateral and to receive as advance
    /// @param _collateral The amount of token to offer as collateral
    /// @param _advanceAmount The amount of token the user wants to receive as an advance
    function getYieldAdvance(address _token, uint256 _collateral, uint256 _advanceAmount) external nonReentrant {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();
        if (i_yieldWield.getTotalDebt(_token) >= getShareValue(_token, s_totalYieldShares)) {
            revert ADVANCES_AT_MAX_CAPACITY();
        }

        address account = msg.sender;
        if (_collateral > getAccountShareValue(_token, account)) revert INSUFFICIENT_AVAILABLE_FUNDS();

        uint256 sharesOffered = _shareConverter(_token, _collateral);
        s_yieldShares[account][_token] -= sharesOffered;
        s_totalYieldShares -= sharesOffered;

        uint256 advanceMinusFee = i_yieldWield.getAdvance(account, _token, _collateral, _advanceAmount);
        uint256 newRevenueShares = i_yieldWield.claimRevenue(_token);
        s_totalRevenueShares += newRevenueShares;

        i_aavePool.withdraw(_token, advanceMinusFee, account);
        emit Advance_Taken(account, _token, _collateral, advanceMinusFee);
    }

    /// @notice Repays an outstanding yield advance using token deposit
    /// @param _token The token being used to repay
    /// @param _amount The amount to repay
    function repayYieldAdvanceWithDeposit(address _token, uint256 _amount) external {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();

        address account = msg.sender;
        uint256 currentDebt = i_yieldWield.getAndupdateAccountDebtFromYield(account, _token);
        if (currentDebt == 0) revert ACCOUNT_HAS_NO_DEBT();
        if (_amount > currentDebt) revert AMOUNT_IS_GREATER_THAN_TOTAL_DEBT();

        uint256 updatedDebt = i_yieldWield.repayAdvanceWithDeposit(account, _token, _amount);
        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) revert DEPOSIT_FAILED();

        i_aavePool.supply(_token, _amount, address(this), 0);
        emit Advance_Repayment_Deposit(account, _token, _amount, updatedDebt);
    }

    /// @notice Withdraws user's collateral after full debt repayment and remints yield shares
    /// @param _token The token for which collateral is being withdrawn
    function withdrawYieldAdvanceCollateral(address _token) external {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();

        address account = msg.sender;
        uint256 collateralWithdrawn = i_yieldWield.withdrawCollateral(account, _token);
        uint256 shares = _shareConverter(_token, collateralWithdrawn);

        s_yieldShares[account][_token] += shares;
        s_totalYieldShares += shares;

        emit Withdraw_Collateral(account, _token, collateralWithdrawn);
    }

    // Convenience fee calculation (10%)
    function _getConvenienceFee(uint256 _amount) internal pure returns (uint256) {
        return _getPercentageAmount(_amount, 10);
    }

    // Calculates a percentage
    function _getPercentage(uint256 _partNumber, uint256 _wholeNumber) internal pure returns (uint256) {
        return (_partNumber * 100) / _wholeNumber;
    }

    // Returns value of a percentage of an amount
    function _getPercentageAmount(uint256 _wholeNumber, uint256 _percent) internal pure returns (uint256) {
        return (_wholeNumber * _percent) / 100;
    }

    // Address of this vault
    function getVaultAddress() external view returns (address) {
        return address(this);
    }

    // Returns Aave pool address in use
    function getActivePoolAddress() external view returns (address) {
        return address(i_aavePool);
    }

    // Reads current Aave liquidity index (scaled down)
    function _getCurrentLiquidityIndex(address _token) internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = i_aavePool.getReserveData(_token);
        return uint256(reserve.liquidityIndex) / 1e21;
    }

    // Converts token amount to share units based on index
    function _shareConverter(address _token, uint256 _usdcAmount) private view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) revert INVALID_LIQUIDITY_INDEX();
        return (_usdcAmount * 1e27) / currentLiquidityIndex;
    }

    // Returns user’s share balance for token
    function getAccountNumOfShares(address _account, address _token) public view returns (uint256) {
        return s_yieldShares[_account][_token];
    }

    // Returns token value of a user’s shares
    function getAccountShareValue(address _token, address _account) public view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) revert INVALID_LIQUIDITY_INDEX();
        return (s_yieldShares[_account][_token] * currentLiquidityIndex + 1e27 - 1) / 1e27;
    }

    // Returns value of shares in token terms
    function getShareValue(address _token, uint256 _shares) public view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) revert INVALID_LIQUIDITY_INDEX();
        return (_shares * currentLiquidityIndex + 1e27 - 1) / 1e27;
    }

    // Returns value of all collected revenue shares
    function getValueOfTotalRevenueShares(address _token) external view returns (uint256) {
        return getShareValue(_token, s_totalRevenueShares);
    }

    // Checks if token is allowed
    function _isTokenPermitted(address _token) internal view returns (bool) {
        return i_tokenRegistry.checkIfTokenIsApproved(_token);
    }
}
