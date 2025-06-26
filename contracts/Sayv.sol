// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
/**
 * @title SAYV
 * @notice Manages deposits, withrawls, advances on future yield via YieldWield's Yield Advance, and yield generation via Aave v3
 * @dev All token amounts are internally converted to RAY (1e27) units.
 */

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IYieldAdvance} from "@yield-advance/interfaces/IYieldAdvance.sol";
import {ITokenRegistry} from "@token-registry/Interfaces/ITokenRegistry.sol";
import {WadRayMath} from "@aave-v3-core/protocol/libraries/math/WadRayMath.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

contract Sayv is ReentrancyGuard {
    using WadRayMath for uint256;

    // yield-advance interface for yield advance management
    IYieldAdvance public immutable i_yieldAdvance;
    // token registry contract to manage allowed tokens
    ITokenRegistry public immutable i_tokenRegistry;
    // aave pool to handle yield generation operations
    IPool public immutable i_aavePool;
    // provider for getting the aave pool
    IPoolAddressesProvider public immutable i_addressesProvider;
    // contract owner address
    address public immutable i_owner;
    // total shares issued for yield deposits
    uint256 public s_totalYieldShares;
    // total shares collected as revenue (fees)
    uint256 public s_totalRevenueShares;
    // RAY units(1e27)
    uint256 public RAY = 1e27;

    // user yield shares amount
    mapping(address account => mapping(address token => uint256 amount)) public s_yieldShares;

    // emitted on deposit
    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    // emitted on withdrawal
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    // emitted when a user takes an advance against yield
    event Advance_Taken(address indexed account, address indexed token, uint256 collateral, uint256 advanceMinusFee);
    // emitted when user collateral is withdrawn
    event Withdraw_Collateral(address indexed account, address indexed token, uint256 collateralWithdrawn);
    // emitted when user repays advance
    event Advance_Repayment_Deposit(
        address indexed account, address indexed token, uint256 repaidAmount, uint256 currentDebt
    );

    // sets up external references and stores deployer as owner
    constructor(address _addressProviderAddress, address _yieldAdvanceAddress, address _tokenRegistryAddress) {
        i_addressesProvider = IPoolAddressesProvider(_addressProviderAddress);
        i_aavePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender;
        i_yieldAdvance = IYieldAdvance(_yieldAdvanceAddress);
        i_tokenRegistry = ITokenRegistry(_tokenRegistryAddress);
    }

    // modifier to restrict function to only the contract owner
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NOT_OWNER();
        _;
    }

    /// @notice adds or removes a token from the permitted list and approves aave pool if adding
    /// @param _tokenAddress the token to add or remove
    /// @param _isApproved true to add to the registry, false to remove
    function managePermittedTokens(address _tokenAddress, bool _isApproved) external onlyOwner {
        _isApproved
            ? i_tokenRegistry.addTokenToRegistry(_tokenAddress)
            : i_tokenRegistry.removeTokenFromRegistry(_tokenAddress);
        if (_isApproved) {
            IERC20(_tokenAddress).approve(address(i_aavePool), type(uint256).max);
        }
    }

    /// @notice deposits tokens into aave and mints yield shares
    /// @param _token the token to deposit
    /// @param _amount the amount of tokens to deposit
    /// @return returns amount deposited
    function depositToVault(address _token, uint256 _amount) public returns (uint256) {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();
        if (IERC20(_token).allowance(msg.sender, address(this)) < _amount) revert ALLOWANCE_NOT_ENOUGH();
        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) revert DEPOSIT_FAILED();

        i_aavePool.supply(_token, _amount, address(this), 0);

        uint256 rayAmount = _toRay(_amount);
        uint256 currentIndex = _getCurrentLiquidityIndex(_token);
        uint256 sharesClaimed = rayAmount.rayDiv(currentIndex);

        s_yieldShares[msg.sender][_token] += sharesClaimed;
        s_totalYieldShares += sharesClaimed;

        emit Deposit_To_Pool(_token, _amount);
        return _amount;
    }

    /// @notice redeems yield shares and withdraws tokens
    /// @param _token the token to withdraw
    /// @param _amount the amount of tokens to withdraw
    /// @return returns amount withdrawn
    function withdrawFromVault(address _token, uint256 _amount) external nonReentrant returns (uint256) {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();

        uint256 rayAmount = _toRay(_amount);
        uint256 currentIndex = _getCurrentLiquidityIndex(_token);
        uint256 accountCurrentShares = s_yieldShares[msg.sender][_token];
        if (rayAmount > accountCurrentShares.rayMul(currentIndex)) revert INSUFFICIENT_AVAILABLE_FUNDS();

        uint256 sharesRedeemed = rayAmount.rayDiv(currentIndex);
        if (accountCurrentShares < sharesRedeemed || s_totalYieldShares < sharesRedeemed) {
            revert UNDERFLOW();
        }

        s_yieldShares[msg.sender][_token] -= sharesRedeemed;
        s_totalYieldShares -= sharesRedeemed;

        uint256 withdrawAmount = i_aavePool.withdraw(_token, _amount, msg.sender);
        emit Withdraw_From_Pool(_token, _amount, msg.sender);
        return withdrawAmount;
    }

    /// @notice allows a user to take an advance on future yield by pledging existing yield shares as collateral
    /// @param _token the token to use for collateral and to receive as advance
    /// @param _collateral the amount of token to offer as collateral
    /// @param _advanceAmount the amount of token the user wants to receive as an advance
    /// @return returns advance amount minus fee
    function getYieldAdvance(address _token, uint256 _collateral, uint256 _advanceAmount)
        external
        nonReentrant
        returns (uint256)
    {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();
        address account = msg.sender;
        uint256 currentIndex = _getCurrentLiquidityIndex(_token);

        // total advances can not be > than total deposits
        if (i_yieldAdvance.getTotalDebt(_token) >= s_totalYieldShares.rayMul(currentIndex)) {
            revert ADVANCES_AT_MAX_CAPACITY();
        }

        uint256 accountCurrentShares = s_yieldShares[account][_token];
        if (_toRay(_collateral) > accountCurrentShares.rayMul(currentIndex)) revert INSUFFICIENT_AVAILABLE_FUNDS();

        uint256 sharesOffered = _toRay(_collateral).rayDiv(currentIndex);
        s_yieldShares[account][_token] -= sharesOffered;
        s_totalYieldShares -= sharesOffered;

        uint256 advanceMinusFee = i_yieldAdvance.getAdvance(account, _token, _collateral, _advanceAmount);
        uint256 revenueShares = i_yieldAdvance.claimRevenue(_token);

        uint256 newRevShareValue = revenueShares.rayMul(currentIndex);
        uint256 newRevShares = newRevShareValue.rayDiv(currentIndex);
        s_totalRevenueShares += newRevShares;

        i_aavePool.withdraw(_token, _fromRay(advanceMinusFee), account);
        emit Advance_Taken(account, _token, _collateral, _fromRay(advanceMinusFee));
        return _fromRay(advanceMinusFee);
    }

    /// @notice repays an outstanding yield advance using token deposit
    /// @param _token the token being used to repay
    /// @param _amount the amount to repay
    function repayYieldAdvanceWithDeposit(address _token, uint256 _amount) external {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();

        address account = msg.sender;
        uint256 currentDebt = i_yieldAdvance.getDebt(account, _token);
        if (currentDebt == 0) revert ACCOUNT_HAS_NO_DEBT();
        if (_toRay(_amount) > currentDebt) revert AMOUNT_IS_GREATER_THAN_TOTAL_DEBT();

        uint256 updatedDebt = i_yieldAdvance.repayAdvanceWithDeposit(account, _token, _amount);

        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) revert DEPOSIT_FAILED();
        i_aavePool.supply(_token, _amount, address(this), 0);

        emit Advance_Repayment_Deposit(account, _token, _amount, _fromRay(updatedDebt));
    }

    /// @notice withdraws user's collateral after full debt repayment and remints yield shares
    /// @param _token the token for which collateral is being withdrawn
    function withdrawYieldAdvanceCollateral(address _token) external {
        if (!_isTokenPermitted(_token)) revert TOKEN_NOT_PERMITTED();

        address account = msg.sender;
        uint256 collateralWithdrawn = i_yieldAdvance.withdrawCollateral(account, _token);
        uint256 shares = collateralWithdrawn.rayDiv(_getCurrentLiquidityIndex(_token));

        s_yieldShares[account][_token] += shares;
        s_totalYieldShares += shares;

        emit Withdraw_Collateral(account, _token, _fromRay(collateralWithdrawn));
    }

    // reads current aave liquidity index
    function _getCurrentLiquidityIndex(address _token) private view returns (uint256) {
        uint256 currentIndex = uint256(i_aavePool.getReserveData(_token).liquidityIndex);
        if (currentIndex < 1e27) revert INVALID_LIQUIDITY_INDEX();
        return currentIndex;
    }

    // checks if token is allowed
    function _isTokenPermitted(address _token) private view returns (bool) {
        return i_tokenRegistry.checkIfTokenIsApproved(_token);
    }

    // converts number to ray (1e27)
    function _toRay(uint256 _num) private view returns (uint256) {
        return _num * RAY;
    }

    // converts number from ray (1e27)
    function _fromRay(uint256 _num) private view returns (uint256) {
        return _num / RAY;
    }

    // returns user’s share balance for token
    function getAccountNumOfShares(address _account, address _token) external view returns (uint256) {
        return s_yieldShares[_account][_token];
    }

    // returns token value of a user’s shares
    function getAccountShareValue(address _account, address _token) external view returns (uint256) {
        return s_yieldShares[_account][_token].rayMul(_getCurrentLiquidityIndex(_token));
    }

    // returns value of all collected revenue shares
    function getValueOfTotalRevenueShares(address _token) external view returns (uint256) {
        return s_totalRevenueShares.rayMul(_getCurrentLiquidityIndex(_token));
    }

    // address of this vault
    function getVaultAddress() external view returns (address) {
        return address(this);
    }

    // returns aave pool address in use
    function getActivePoolAddress() external view returns (address) {
        return address(i_aavePool);
    }
}
