// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";
import {IYieldWield} from "@yieldwield/interfaces/IYieldWield.sol";

contract Sayv {
    IYieldWield public immutable i_yieldWield;
    IPool public immutable i_aavePool;
    IPoolAddressesProvider public immutable i_addressesProvider;
    IERC20 public immutable i_vaultToken;
    IERC20 public immutable i_yieldBarringToken;
    address public immutable i_vaultTokenAddress;
    address public immutable i_yieldBarringTokenAddress;
    address public immutable i_owner;

    mapping(address account => uint256 amount) public s_yieldShares;
    uint256 private s_totalYieldShares;
    uint256 private s_totalRevenueShares;

    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    event Advance_Taken(address indexed account, address indexed token, uint256 collateral, uint256 advanceMinusFee);
    event Withdraw_Collateral(address indexed account, address indexed token, uint256 collateralWithdrawn);
    event Advance_Repayment_Deposit(
        address indexed account, address indexed token, uint256 repaidAmount, uint256 currentDebt
    );

    constructor(address _token, address _yieldBarringToken, address _addressProvider, address _yieldWieldAddress) {
        i_vaultToken = IERC20(_token);
        i_vaultTokenAddress = _token;
        i_yieldBarringToken = IERC20(_yieldBarringToken);
        i_yieldBarringTokenAddress = _yieldBarringToken;
        i_addressesProvider = IPoolAddressesProvider(_addressProvider);
        i_aavePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender;
        i_yieldWield = IYieldWield(_yieldWieldAddress);
        i_vaultToken.approve(address(i_aavePool), type(uint256).max);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function depositToVault(uint256 _amount) public {
        if (!i_vaultToken.approve(address(this), type(uint256).max)) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }

        if (i_vaultToken.allowance(msg.sender, address(this)) < _amount) {
            revert ALLOWANCE_NOT_ENOUGH();
        }

        if (!i_vaultToken.transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        i_aavePool.supply(i_vaultTokenAddress, _amount, address(this), 0);

        uint256 sharesClaimed = _claimYieldShares(_amount);

        s_yieldShares[msg.sender] += sharesClaimed;
        s_totalYieldShares += sharesClaimed;

        emit Deposit_To_Pool(i_vaultTokenAddress, _amount);
    }

    function withdrawFromVault(uint256 _amount) external {
        if (_amount > getAccountShareValue(msg.sender)) {
            revert INSUFFICIENT_AVAILABLE_FUNDS();
        }

        uint256 sharesRedeemed = _redeemYieldShares(_amount);

        if (s_yieldShares[msg.sender] < sharesRedeemed || s_totalYieldShares < sharesRedeemed) {
            revert UNDERFLOW();
        }
        s_yieldShares[msg.sender] -= sharesRedeemed;
        s_totalYieldShares -= sharesRedeemed;

        i_aavePool.withdraw(i_vaultTokenAddress, _amount, msg.sender);

        emit Withdraw_From_Pool(i_vaultTokenAddress, _amount, msg.sender);
    }

    function getYieldAdvance(address _token, uint256 _collateral, uint256 _advanceAmount) external {
        if (i_yieldWield.getTotalDebt(_token) >= getShareValue(s_totalYieldShares)) {
            revert ADVANCES_AT_MAX_CAPACITY();
        }
        address account = msg.sender;
        if (_collateral > getAccountShareValue(account)) {
            revert INSUFFICIENT_AVAILABLE_FUNDS();
        }

        uint256 sharesOfferedForCollateral = _redeemYieldShares(_collateral);

        s_yieldShares[account] -= sharesOfferedForCollateral;
        s_totalYieldShares -= sharesOfferedForCollateral;

        uint256 advanceMinusFee = i_yieldWield.getAdvance(account, _token, _collateral, _advanceAmount);

        uint256 newRevenueShares = i_yieldWield.claimRevenue(account);
        s_totalRevenueShares += newRevenueShares;

        i_aavePool.withdraw(_token, advanceMinusFee, account);

        emit Advance_Taken(account, _token, _collateral, advanceMinusFee);
    }

    function repayYieldAdvanceWithDeposit(address _token, uint256 _amount) external {
        address account = msg.sender;
        uint256 accountCurrentDebt = i_yieldWield.getAndupdateAccountDebtFromYield(account, _token);
        if (accountCurrentDebt == 0) {
            revert ACCOUNT_HAS_NO_DEBT();
        }
        if (_amount > accountCurrentDebt) {
            revert AMOUNT_IS_GREATER_THAN_TOTAL_DEBT();
        }
        uint256 newCurrentDebt = i_yieldWield.repayAdvanceWithDeposit(account, _token, _amount);

        emit Advance_Repayment_Deposit(account, _token, _amount, newCurrentDebt);
    }

    function withdrawYieldAdvanceCollateral(address _token) external {
        address account = msg.sender;
        uint256 collateralWithdrawn = i_yieldWield.withdrawCollateral(account, _token);
        uint256 yieldSharesAddedToAccount = _claimYieldShares(collateralWithdrawn);

        s_yieldShares[account] += yieldSharesAddedToAccount;
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
    function _getCurrentLiquidityIndex() internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = i_aavePool.getReserveData(i_vaultTokenAddress);
        return uint256(reserve.liquidityIndex) / 1e21; // WAD (1e27)
    }

    /// @notice for deposits
    ///@notice use these shares to track users balance throughout the protocol. tracks yield gain.
    function _claimYieldShares(uint256 _usdcAmount) private view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex();
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 sharesToMint = ((_usdcAmount * 1e27) / currentLiquidityIndex);
        return sharesToMint;
    }

    /// @notice for withdrawls
    ///@notice use these shares to track users balance throughout the protocol. tracks yield gain.
    function _redeemYieldShares(uint256 _usdcAmount) private view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex();
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 sharesToBurn = ((_usdcAmount * 1e27) / currentLiquidityIndex);
        return sharesToBurn;
    }

    function getAccountNumOfShares(address _account) public view returns (uint256) {
        return (s_yieldShares[_account]);
    }

    function getAccountShareValue(address _account) public view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex();
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 shareValue = (s_yieldShares[_account] * currentLiquidityIndex + 1e27 - 1) / 1e27;
        return shareValue;
    }

    function getShareValue(uint256 _shares) public view returns (uint256) {
        uint256 currentLiquidityIndex = _getCurrentLiquidityIndex();
        if (currentLiquidityIndex < 1) {
            revert INVALID_LIQUIDITY_INDEX();
        }
        uint256 shareValue = (_shares * currentLiquidityIndex + 1e27 - 1) / 1e27;
        return shareValue;
    }

    function getValueOfTotalRevenueShares() internal view returns (uint256) {
        return getShareValue(s_totalRevenueShares);
    }
}
