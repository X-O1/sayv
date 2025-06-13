// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {YieldAdapter} from "./YieldAdapter.sol";
import "./SayvErrors.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract YieldLeasing {
    YieldAdapter immutable i_yieldAdapter;
    address immutable i_vaultToken;
    IERC20 public immutable i_yieldBarringToken;

    event Advance_Requested(
        address indexed account, uint256 indexed requestedAmount, uint256 indexed advanceAmountTransfered
    );
    event Advance_Repayment(address indexed account, uint256 indexed repaidAmount);
    event Liquidity_Deposited(address indexed account, uint256 indexed amount);
    event Yield_Withdrawn(address indexed account, uint256 indexed amount);

    mapping(address account => mapping(address token => uint256 amount)) public s_advanceCollateralDeposited;
    mapping(address account => mapping(address token => uint256 amount)) public s_liquidityDeposited;
    mapping(address account => mapping(address token => uint256 amount)) public s_advanceOwed;

    mapping(address vault => mapping(address token => uint256 amount)) public s_totalAdvancesOwed;
    mapping(address vault => mapping(address token => uint256 amount)) public s_totalLiquidityDeposited;
    mapping(address vault => mapping(address token => uint256 amount)) public s_totalAdvanceCollateralDeposited;

    constructor(address _yieldAdapter, address _vaultToken, address _yieldBarringToken) {
        i_yieldAdapter = YieldAdapter(_yieldAdapter);
        i_vaultToken = _vaultToken;
        i_yieldBarringToken = IERC20(_yieldBarringToken);
    }

    function supplyLiquidity(address _token, uint256 _amount) external {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        address account = msg.sender;

        if (s_advanceOwed[account][_token] != 0) {
            revert MUST_REPAY_ADVANCE_OWED();
        }
        if (_amount > i_yieldAdapter._getAmountApprovedForWithdrawl(account, _token)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }
        if (_amount > i_yieldBarringToken.allowance(address(i_yieldAdapter), address(this))) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }
        i_yieldAdapter._removeDeposit(account, _token, _amount);

        if (!i_yieldBarringToken.transferFrom((address(i_yieldAdapter)), address(this), _amount)) {
            revert TRANSFER_FAILED();
        }

        s_liquidityDeposited[account][_token] += _amount;
        s_totalLiquidityDeposited[address(this)][_token] += _amount;

        emit Liquidity_Deposited(account, _amount);
    }

    function _withdrawYield(address _account) public {
        if (msg.sender != _account) {
            revert ACCOUNT_OWNER_ONLY();
        }
        uint256 availableYield = _approveWithdrawlAmountForLPs(_account, i_vaultToken);

        if (!i_yieldBarringToken.transfer((address(i_yieldAdapter)), availableYield)) {
            revert TRANSFER_FAILED();
        }
        i_yieldAdapter._addDeposit(_account, i_vaultToken, availableYield);

        emit Yield_Withdrawn(_account, availableYield);
    }

    function _approveWithdrawlAmountForLPs(address _account, address _token) internal view returns (uint256) {
        // uint256 totalAdvanceCollateralDeposited = s_totalAdvanceCollateralDeposited[address(this)][_token];
        uint256 totalLiquidityDeposited = s_totalLiquidityDeposited[address(this)][_token];
        uint256 totalYieldBarringTokenBalanceIncludingYield = _getVaultYieldTokenBalance() - totalLiquidityDeposited;
        uint256 liquidityDeposited = s_liquidityDeposited[_account][_token];

        uint256 accountEquityPercentage = _getPercentage(liquidityDeposited, totalLiquidityDeposited);
        uint256 totalAccountVaultEquity =
            _getPercentageAmount(totalYieldBarringTokenBalanceIncludingYield, accountEquityPercentage);

        uint256 availableForWithdraw = totalAccountVaultEquity;
        return availableForWithdraw;
    }

    function _approveWithdrawlAmountForAdvancers(address _account, address _token) internal returns (uint256) {}

    function requestAdvance(address _token, uint256 _advanceCollateral, uint256 _requestedAmount) external {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        address account = msg.sender;

        if (s_liquidityDeposited[account][_token] != 0) {
            revert CANNOT_REQUEST_ADVANCE_AND_PROVIDE_LIQUIDITY();
        }

        if (_requestedAmount > _getAvailableLiquidity(_token)) {
            revert NOT_ENOUGH_LIQUIDITY();
        }

        if (!_isTotalAdvancesLessThanTotalDeposits(_token)) {
            revert ADVANCES_NOT_AVAILABLE();
        }
        if (_advanceCollateral > i_yieldAdapter._getAmountApprovedForWithdrawl(account, _token)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }

        if (
            _getAdvanceToCollateralPercentage(account, _token, _requestedAmount)
                > _getMaxAdvancePercentageOfCoverage(_token)
        ) {
            revert ADVANCE_MAX_REACHED();
        }
        uint256 advanceFee = _getFeeForAdvance(_token, _advanceCollateral, _requestedAmount);
        uint256 requestedAdvancePlusFee = _requestedAmount + advanceFee;
        uint256 advanceMinusFee = _requestedAmount - advanceFee;

        s_advanceCollateralDeposited[account][_token] += _advanceCollateral;
        s_advanceOwed[account][_token] += requestedAdvancePlusFee;

        if (!i_yieldBarringToken.transferFrom(address(i_yieldAdapter), account, advanceMinusFee)) {
            revert TRANSFER_FAILED();
        }

        emit Advance_Requested(msg.sender, _requestedAmount, advanceMinusFee);
    }

    function _repayAdvance(address _token, uint256 _amount) internal {
        if (_token != address(i_vaultToken)) {
            revert TOKEN_NOT_ALLOWED();
        }
        // address account = msg.sender;
        uint256 advanceOwed = s_advanceOwed[msg.sender][_token];

        if (_amount >= advanceOwed) {
            s_advanceOwed[msg.sender][_token] = 0;
            s_advanceCollateralDeposited[msg.sender][_token] = 0;
            s_totalAdvanceCollateralDeposited[address(this)][_token] -= _amount;
            s_totalAdvancesOwed[address(this)][_token] -= _amount;

            i_yieldBarringToken.transfer(
                (address(i_yieldAdapter)), s_totalAdvanceCollateralDeposited[msg.sender][_token]
            );
            // i_yieldAdapter.updateDeposits(account, i_vaultToken, s_totalAdvanceCollateralDeposited[msg.sender][_token], true);
        }

        s_advanceOwed[msg.sender][_token] -= _amount;
        s_totalLiquidityDeposited[address(this)][_token] += _amount;
        s_totalAdvancesOwed[address(this)][_token] -= _amount;

        emit Advance_Repayment(msg.sender, _amount);
    }

    function _getFeeForAdvance(address _token, uint256 _advanceCollateral, uint256 _requestedAmount)
        internal
        view
        returns (uint256)
    {
        uint256 baseFeePercentage = _getAdvanceFeePercentage(_token);
        uint256 advancePercentageOfBacking = _getPercentage(_requestedAmount, _advanceCollateral);
        uint256 baseFee = _getPercentageAmount(_requestedAmount, baseFeePercentage);
        uint256 bonusFee = _getPercentageAmount(baseFee, advancePercentageOfBacking);
        return baseFee + bonusFee;
    }

    function _getAvailableLiquidity(address _token) public view returns (uint256) {
        return _getTotalSuppliedLiquidity(_token) - _getTotalAdvances(_token);
    }

    /// @notice Checks if there is room for more advances (advances < deposits)
    function _isTotalAdvancesLessThanTotalDeposits(address _token) internal view returns (bool) {
        bool isLessThan;
        _getTotalAdvances(_token) < i_yieldAdapter._getVaultYieldTokenBalance() ? isLessThan = true : isLessThan = false;
        return isLessThan;
    }

    function _getTotalAdvances(address _token) public view returns (uint256) {
        return s_totalAdvancesOwed[address(this)][_token];
    }

    function _getTotalSuppliedLiquidity(address _token) public view returns (uint256) {
        return s_totalLiquidityDeposited[address(this)][_token];
    }

    function _getAdvanceToCollateralPercentage(address _account, address _token, uint256 _requestedAmount)
        internal
        view
        returns (uint256)
    {
        return _getPercentage(_requestedAmount, s_advanceCollateralDeposited[_account][_token]);
    }

    function _getAdvanceFeePercentage(address _token) internal view returns (uint256) {
        return _getPercentage(s_totalLiquidityDeposited[address(this)][_token], _getAvailableLiquidity(_token));
    }

    function _getMaxAdvancePercentageOfCoverage(address _token) internal view returns (uint256) {
        return 100 - _getAdvanceFeePercentage(_token);
    }

    function _getPercentage(uint256 _partNumber, uint256 _wholeNumber) internal pure returns (uint256) {
        return (_partNumber * 100) / _wholeNumber;
    }

    function _getPercentageAmount(uint256 _wholeNumber, uint256 _percent) internal pure returns (uint256) {
        return (_wholeNumber * _percent) / 100;
    }

    function _getSuppliedLiquidity(address _account, address _token) external view returns (uint256) {
        return s_liquidityDeposited[_account][_token];
    }

    function _getAdvanceCollateral(address _account, address _token) external view returns (uint256) {
        return s_advanceCollateralDeposited[_account][_token];
    }

    function _getVaultYieldTokenBalance() public view returns (uint256) {
        return i_yieldBarringToken.balanceOf(address(this));
    }

    function getVaultAddress() external view returns (address) {
        return address(this);
    }

    /// TESTING FUNCTIONS

    function getAdvanceCollateralDeposited(address _account, address _token) external view returns (uint256) {
        return s_advanceCollateralDeposited[_account][_token];
    }

    function getLiquidityDeposited(address _account, address _token) external view returns (uint256) {
        return s_liquidityDeposited[_account][_token];
    }

    function getAdvanceOwed(address _account, address _token) external view returns (uint256) {
        return s_advanceOwed[_account][_token];
    }

    function getTotalAdvancesOwed(address _vault, address _token) external view returns (uint256) {
        return s_totalAdvancesOwed[_vault][_token];
    }

    function getTotalLiquidityDeposited(address _vault, address _token) external view returns (uint256) {
        return s_totalLiquidityDeposited[_vault][_token];
    }

    function getTotalAdvanceCollateralDeposited(address _vault, address _token) external view returns (uint256) {
        return s_totalAdvanceCollateralDeposited[_vault][_token];
    }
}
