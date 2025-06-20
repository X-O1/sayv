// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {IYieldWield} from "@yieldwield/interfaces/IYieldWield.sol";
import {ITokenRegistry} from "@token-registry/Interfaces/ITokenRegistry.sol";

contract Sayv {
    IYieldWield public immutable i_yieldWield;
    ITokenRegistry public immutable i_tokenRegistry;
    IPool public immutable i_aavePool;
    IPoolAddressesProvider public immutable i_addressesProvider;

    address public immutable i_owner;

    mapping(address account => mapping(address token => uint256 amount)) public s_yieldShares;
    uint256 private s_totalYieldShares;
    uint256 private s_totalRevenueShares;

    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    event Advance_Taken(address indexed account, address indexed token, uint256 collateral, uint256 advanceMinusFee);
    event Withdraw_Collateral(address indexed account, address indexed token, uint256 collateralWithdrawn);
    event Advance_Repayment_Deposit(address indexed account, address indexed token, uint256 repaidAmount, uint256 currentDebt);

    constructor(address _addressProviderAddress, address _yieldWieldAddress, address _tokenRegistryAddress) {
        i_addressesProvider = IPoolAddressesProvider(_addressProviderAddress);
        i_aavePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender;
        i_yieldWield = IYieldWield(_yieldWieldAddress);
        i_tokenRegistry = ITokenRegistry(_tokenRegistryAddress);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function managePermittedTokens(address _tokenAddress, bool _isApproved) external onlyOwner {
        _isApproved ? i_tokenRegistry.addTokenToRegistry(_tokenAddress) : i_tokenRegistry.removeTokenFromRegistry(_tokenAddress);

        if (_isApproved) {
            IERC20(_tokenAddress).approve(address(i_aavePool), type(uint256).max);
        }
    }

    function depositToVault(address _token, uint256 _amount) public {
        if (!_isTokenPermitted(_token)) {
            revert TOKEN_NOT_PERMITTED();
        }

        if (!IERC20(_token).approve(address(this), type(uint256).max)) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }

        if (IERC20(_token).allowance(msg.sender, address(this)) < _amount) {
            revert ALLOWANCE_NOT_ENOUGH();
        }

        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        i_aavePool.supply(_token, _amount, address(this), 0);

        uint256 sharesClaimed = _claimYieldShares(_token, _amount);

        s_yieldShares[msg.sender][_token] += sharesClaimed;
        s_totalYieldShares += sharesClaimed;

        emit Deposit_To_Pool(_token, _amount);
    }

    function withdrawFromVault(address _token, uint256 _amount) external {
        if (!_isTokenPermitted(_token)) {
            revert TOKEN_NOT_PERMITTED();
        }

        if (_amount > getAccountShareValue(_token, msg.sender)) {
            revert INSUFFICIENT_AVAILABLE_FUNDS();
        }

        uint256 sharesRedeemed = _redeemYieldShares(_token, _amount);

        if (s_yieldShares[msg.sender][_token] < sharesRedeemed || s_totalYieldShares < sharesRedeemed) {
            revert UNDERFLOW();
        }
        s_yieldShares[msg.sender][_token] -= sharesRedeemed;
        s_totalYieldShares -= sharesRedeemed;

        i_aavePool.withdraw(_token, _amount, msg.sender);

        emit Withdraw_From_Pool(_token, _amount, msg.sender);
    }

    function getYieldAdvance(address _token, uint256 _collateral, uint256 _advanceAmount) external {
        if (!_isTokenPermitted(_token)) {
            revert TOKEN_NOT_PERMITTED();
        }

        if (i_yieldWield.getTotalDebt(_token) >= getShareValue(_token, s_totalYieldShares)) {
            revert ADVANCES_AT_MAX_CAPACITY();
        }
        address account = msg.sender;
        if (_collateral > getAccountShareValue(_token, account)) {
            revert INSUFFICIENT_AVAILABLE_FUNDS();
        }

        uint256 sharesOfferedForCollateral = _redeemYieldShares(_token, _collateral);

        s_yieldShares[account][_token] -= sharesOfferedForCollateral;
        s_totalYieldShares -= sharesOfferedForCollateral;

        uint256 advanceMinusFee = i_yieldWield.getAdvance(account, _token, _collateral, _advanceAmount);

        uint256 newRevenueShares = i_yieldWield.claimRevenue(_token);
        s_totalRevenueShares += newRevenueShares;

        i_aavePool.withdraw(_token, advanceMinusFee, account);

        emit Advance_Taken(account, _token, _collateral, advanceMinusFee);
    }

    function repayYieldAdvanceWithDeposit(address _token, uint256 _amount) external {
        if (!_isTokenPermitted(_token)) {
            revert TOKEN_NOT_PERMITTED();
        }

        address account = msg.sender;
        uint256 accountCurrentDebt = i_yieldWield.getAndupdateAccountDebtFromYield(account, _token);
        if (accountCurrentDebt == 0) {
            revert ACCOUNT_HAS_NO_DEBT();
        }
        if (_amount > accountCurrentDebt) {
            revert AMOUNT_IS_GREATER_THAN_TOTAL_DEBT();
        }

        uint256 newCurrentDebt = i_yieldWield.repayAdvanceWithDeposit(account, _token, _amount);

        if (!IERC20(_token).transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        i_aavePool.supply(_token, _amount, address(this), 0);

        emit Advance_Repayment_Deposit(account, _token, _amount, newCurrentDebt);
    }

    function withdrawYieldAdvanceCollateral(address _token) external {
        if (!_isTokenPermitted(_token)) {
            revert TOKEN_NOT_PERMITTED();
        }

        address account = msg.sender;
        uint256 collateralWithdrawn = i_yieldWield.withdrawCollateral(account, _token);
        uint256 yieldSharesAddedToAccount = _claimYieldShares(_token, collateralWithdrawn);

        s_yieldShares[account][_token] += yieldSharesAddedToAccount;
        s_totalYieldShares += yieldSharesAddedToAccount;

        emit Withdraw_Collateral(account, _token, collateralWithdrawn);
    }

    // MAKE AUTO WITHDRAW COLLATERAL WHEN DEBT HITS 0 somehow

    function _getConvenienceFee(uint256 _amount) internal pure returns (uint256) {
        uint256 convenienceFee = _getPercentageAmount(_amount, 10);
        return convenienceFee;
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
        return address(i_aavePool);
    }

    /// @notice Get the current liquidity index for USDC in Aave
    function _getCurrentLiquidityIndex(address _token) internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = i_aavePool.getReserveData(_token);
        return uint256(reserve.liquidityIndex) / 1e21; // WAD (1e27)
    }

    /// @notice for deposits
    ///@notice use these shares to track users balance throughout the protocol. tracks yield gain.
    function _claimYieldShares(address _token, uint256 _usdcAmount) private view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 sharesToMint = ((_usdcAmount * 1e27) / currentLiquidityIndex);
        return sharesToMint;
    }

    /// @notice for withdrawls
    ///@notice use these shares to track users balance throughout the protocol. tracks yield gain.
    function _redeemYieldShares(address _token, uint256 _usdcAmount) private view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 sharesToBurn = ((_usdcAmount * 1e27) / currentLiquidityIndex);
        return sharesToBurn;
    }

    function getAccountNumOfShares(address _account, address _token) public view returns (uint256) {
        return (s_yieldShares[_account][_token]);
    }

    function getAccountShareValue(address _token, address _account) public view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 shareValue = (s_yieldShares[_account][_token] * currentLiquidityIndex + 1e27 - 1) / 1e27;
        return shareValue;
    }

    function getShareValue(address _token, uint256 _shares) public view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex(_token);
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 shareValue = (_shares * currentLiquidityIndex + 1e27 - 1) / 1e27;
        return shareValue;
    }

    function getValueOfTotalRevenueShares(address _token) external view returns (uint256) {
        return getShareValue(_token, s_totalRevenueShares);
    }

    function _isTokenPermitted(address _token) internal view returns (bool) {
        return i_tokenRegistry.checkIfTokenIsApproved(_token);
    }
}
