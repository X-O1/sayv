// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {DataTypes} from "@aave-v3-core/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract Sayv {
    IPool public immutable i_activePool;
    IPoolAddressesProvider public immutable i_addressesProvider;
    IERC20 public immutable i_vaultToken;
    IERC20 public immutable i_yieldBarringToken;
    address public immutable i_vaultTokenAddress;
    address public immutable i_yieldBarringTokenAddress;
    address public immutable i_owner;

    mapping(address account => uint256 amount) public s_yieldShares;
    mapping(address vault => uint256 amount) public s_totalYieldShares;
    mapping(address vault => uint256 amount) public s_totalFeesCollected;

    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);

    constructor(address _token, address _addressProvider, address _yieldBarringToken) {
        i_vaultToken = IERC20(_token);
        i_vaultTokenAddress = _token;
        i_yieldBarringToken = IERC20(_yieldBarringToken);
        i_yieldBarringTokenAddress = _yieldBarringToken;
        i_addressesProvider = IPoolAddressesProvider(_addressProvider);
        i_activePool = IPool(i_addressesProvider.getPool());
        i_owner = msg.sender;
        i_vaultToken.approve(address(i_activePool), type(uint256).max);
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

        i_activePool.supply(i_vaultTokenAddress, _amount, address(this), 0);

        uint256 sharesClaimed = _claimYieldShares(_amount);

        s_yieldShares[msg.sender] += sharesClaimed;
        s_totalYieldShares[address(this)] += sharesClaimed;

        emit Deposit_To_Pool(i_vaultTokenAddress, _amount);
    }

    function withdrawFromVault(uint256 _amount) external {
        if (_amount > getAccountShareValue(msg.sender)) {
            revert INSUFFICIENT_AVAILABLE_FUNDS();
        }

        uint256 sharesRedeemed = _redeemYieldShares(_amount);

        if (s_yieldShares[msg.sender] < sharesRedeemed || s_totalYieldShares[address(this)] < sharesRedeemed) {
            revert UNDERFLOW();
        }
        s_yieldShares[msg.sender] -= sharesRedeemed;
        s_totalYieldShares[address(this)] -= sharesRedeemed;

        i_activePool.withdraw(i_vaultTokenAddress, _amount, msg.sender);

        emit Withdraw_From_Pool(i_vaultTokenAddress, _amount, msg.sender);
    }

    function _depositToPool(address _token, uint256 _amount, address _onBehalfOf, uint16 _referralCode) external {
        i_activePool.supply(_token, _amount, _onBehalfOf, _referralCode);
        emit Deposit_To_Pool(_token, _amount);
    }

    function _withdrawFromPool(address _token, uint256 _amount, address _to) external {
        i_activePool.withdraw(_token, _amount, _to);
        emit Withdraw_From_Pool(_token, _amount, _to);
    }

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
        return address(i_activePool);
    }

    /// @notice Get the current liquidity index for USDC in Aave
    function _getCurrentLiquidityIndex() internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = i_activePool.getReserveData(i_vaultTokenAddress);
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
}
