// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {IPool} from "@aave-v3-core/IPool.sol";
import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract SayvVault {
    IERC20 immutable i_vaultToken;
    address immutable i_owner;
    address immutable i_vaultTokenAddress;
    address immutable i_activeYieldPool;
    uint256 private s_totalVaultDeposits = s_vaultBalances[address(this)].totalDeposits;
    uint256 private s_totalVaultAdvances = s_vaultBalances[address(this)].totalAdvances;

    struct AccountBalance {
        uint256 accountEquity;
        uint256 lockedEquity;
        uint256 advancedEquity;
    }

    struct VaultBalance {
        uint256 totalDeposits;
        uint256 totalAdvances;
    }

    mapping(address account => AccountBalance) public s_accountBalances;
    mapping(address vault => VaultBalance) public s_vaultBalances;

    mapping(address account => mapping(address permittedAddress => bool isPermitted)) public s_accountPermittedAddresses;

    event Address_Permitted(address indexed account, address indexed userAddress);
    event Address_Removed_From_Permitted_Addresses(address indexed account, address indexed userAddress);
    event Deposit_To_Vault(address indexed account, address indexed token, uint256 indexed amount);
    event Withdraw_From_Vault(address indexed token, uint256 indexed amount, address indexed to);
    event Deposit_To_Pool(address indexed token, uint256 indexed amount);
    event Withdraw_From_Pool(address indexed token, uint256 indexed amount, address indexed to);
    event Yield_Advance_Repayment(address indexed account, uint256 indexed advanceBalance);

    constructor(address _token, address _activeYieldPool) {
        i_vaultToken = IERC20(_token);
        i_owner = msg.sender;
        i_activeYieldPool = _activeYieldPool;
        i_vaultTokenAddress = _token;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function depositToVault(uint256 _amount, bool _repayYieldAdvance) public {
        if (!i_vaultToken.approve(address(this), _amount)) {
            revert APPROVING_TOKEN_ALLOWANCE_FAILED();
        }

        if (_repayYieldAdvance) {
            _repayAdvance(_amount);
        }
        if (!_repayYieldAdvance) {
            s_accountBalances[msg.sender].accountEquity += _amount;
            s_vaultBalances[address(this)].totalDeposits += _amount;
        }

        if (!i_vaultToken.transferFrom(msg.sender, address(this), _amount)) {
            revert DEPOSIT_FAILED();
        }

        _depositToPool(_amount, address(this), 0);

        emit Deposit_To_Vault(msg.sender, i_vaultTokenAddress, _amount);
    }

    function withdrawFromVault(uint256 _amount, bool _repayYieldAdvance) external {
        if (_repayYieldAdvance) {
            _repayAdvance(_amount);
        }
        if (_amount > getAccountAvailableEquity(msg.sender)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }
        if (!_repayYieldAdvance) {
            s_accountBalances[msg.sender].accountEquity -= _amount;
            s_vaultBalances[address(this)].totalDeposits -= _amount;
        }
        _withdrawFromPool(_amount, msg.sender);

        emit Withdraw_From_Vault(i_vaultTokenAddress, _amount, msg.sender);
    }

    function takeAdvance(uint256 _requestedAdvance) external view {
        // checks that the vault has enough for all withdrawls before advancing more equity.
        if (!_isTotalAdvancesLessThanTotalDeposits()) {
            revert ADVANCES_NOT_AVAILABLE();
        }

        //checking if requested advance is more than available equity
        if (_requestedAdvance > getAccountAvailableEquity(msg.sender)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }

        //checking that the advance is less percent of total equtiy than the max percentage allowed.
        if (
            _calculatePercentageOfEquityAdvanced(_requestedAdvance, getAccountAvailableEquity(msg.sender))
                > _calculateAdvancePercentageMax()
        ) {
            revert ADVANCE_MAX_REACHED();
        }

        // Build notes - ignore
        // REQUIRE THAT TOTAL ADVANCES < TOTAL DEPOSITS
        // Lock that equity.
        // Take the advance fee upfront by sending the user 10% less than the amount they requested (assuming a 10% fee).
        // This way, the vault profits immediately and fee revenue is easier to track.
        // Advance fees are not a loan against future yield. They are a loan against accounts vault equity. ***
        // ??? How to determine the length of the advance based on something *other than time*.
        // Advances can be taken based on available liquidity.
        // user should take adavance based onn how long they are not going to touch thier savings amount so it could pay itself back.
    }

    // get fee for individial adnvacnes. get base vault fee and adds aditional fee based on how much of thier equity they are taking out.
    function _caluculateFeeForAdvance(address _account, uint256 _totalEquity, uint256 _percentageOfEquityAdvanced)
        internal
        view
        returns (uint256)
    {
        uint256 baseFee = (getAccountAdvancedEquity(_account) * _caluculateVaultAdvanceFee()) / 100;
        uint256 scaledFee =
            (baseFee * _calculatePercentageOfEquityAdvanced(_percentageOfEquityAdvanced, _totalEquity)) / 100;

        return scaledFee;
        // uses their locked ammount to determine how much the fee is applied to
        // fee goes up the higher % of equity they take an advance on. ie if the advance is 30% of total equity, then the fee is the current fee plus 30% of the current fee charge.
    }

    // gets the vaults fee for all advances
    function _caluculateVaultAdvanceFee() internal view returns (uint256) {
        // fee capped at 25
        if (_calculateAdvancePercentageOfDeposits() > 25) {
            return 25;
        } else {
            return _calculateAdvancePercentageOfDeposits();
        }
        // Build notes - ignore
        //WORK ON. Needs to be dailed in.
        // Fee Determined by the number of advances vs total deposits ratio.
        // lower the ratio lowe the fee. higher the ration higher the fee
        // maybe if advances are 10% of all deposits the fee is 10% etc. Easy way to cap both.
    }

    // get the max percentage of thier equity they can take an advance on
    function _calculateAdvancePercentageMax() internal view returns (uint256) {
        // Require that percentage of equity advanced is < the current AdvancePercentageOfDeposits left over.
        // Example: If _calculateAdvancePercentageOfDeposits returns 20%, then the max advance is 80% of the account’s total available equity.
        // This way, the more advances are taken, the less users are allowed to take available liquidity for advances.
        return 100 - _calculateAdvancePercentageOfDeposits();
    }

    //checks how much of the advance is the total equity
    function _calculatePercentageOfEquityAdvanced(uint256 _advanceAmount, uint256 _totalEquity)
        internal
        pure
        returns (uint256)
    {
        return (_advanceAmount * 100) / _totalEquity;
    }

    // check how much advacnes are out compared to totoal deposits
    function _calculateAdvancePercentageOfDeposits() internal view returns (uint256) {
        return (s_totalVaultAdvances * 100) / s_totalVaultDeposits;
    }

    //checks how much equity an account has in the vault
    function _calculateVaultEquity(address _account) internal view returns (uint256) {
        return (getAccountTotalEquity(_account) * 100) / s_totalVaultDeposits;
    }

    function _repayAdvance(uint256 _amount) internal {
        uint256 advanceBalance = getAccountAdvancedEquity(msg.sender);

        if (_amount >= advanceBalance) {
            s_accountBalances[msg.sender].accountEquity += (_amount - advanceBalance);
            s_accountBalances[msg.sender].advancedEquity = 0;
            s_accountBalances[msg.sender].lockedEquity = 0;
            s_vaultBalances[address(this)].totalDeposits += _amount;
            s_vaultBalances[address(this)].totalAdvances -= _amount;
        }
        if (_amount < advanceBalance) {
            s_accountBalances[msg.sender].advancedEquity -= _amount;
            s_vaultBalances[address(this)].totalDeposits += _amount;
            s_vaultBalances[address(this)].totalAdvances -= _amount;
        }

        emit Yield_Advance_Repayment(msg.sender, advanceBalance);
    }

    function _depositToPool(uint256 _amount, address _onBehalfOf, uint16 _referralCode) private {
        IPool(i_activeYieldPool).supply(i_vaultTokenAddress, _amount, _onBehalfOf, _referralCode);
        emit Deposit_To_Pool(i_vaultTokenAddress, _amount);
    }

    function _withdrawFromPool(uint256 _amount, address _to) private {
        IPool(i_activeYieldPool).withdraw(i_vaultTokenAddress, _amount, _to);
        emit Withdraw_From_Pool(i_vaultTokenAddress, _amount, _to);
    }

    function getAccountTotalEquity(address _account) public view returns (uint256) {
        return s_accountBalances[_account].accountEquity;
    }

    function getAccountAvailableEquity(address _account) public view returns (uint256) {
        // acounts only earn on / can withdraw available equity.
        return s_accountBalances[_account].accountEquity - s_accountBalances[_account].lockedEquity;
    }

    function getAccountAdvancedEquity(address _account) public view returns (uint256) {
        return s_accountBalances[_account].advancedEquity;
    }

    function getAccountLockedEquity(address _account) public view returns (uint256) {
        return s_accountBalances[_account].lockedEquity;
    }

    function _isAddressPermitted(address _account, address _permittedAddress) public view returns (bool) {
        return s_accountPermittedAddresses[_account][_permittedAddress];
    }

    function _isTotalAdvancesLessThanTotalDeposits() internal view returns (bool) {
        bool isLessThan;
        if (s_totalVaultAdvances < s_totalVaultDeposits) {
            isLessThan = true;
        }
        if (s_totalVaultAdvances >= s_totalVaultDeposits) {
            isLessThan = false;
        }
        return isLessThan;
    }

    // permitted addresses need their own withdraw system.*************************************************
    // function addPermittedAddress(address _account, address _newPermittedAddress) external {
    //     if (msg.sender != _account) {
    //         revert NOT_ACCOUNT_OWNER();
    //     }
    //     if (_newPermittedAddress == address(0)) {
    //         revert INVALID_ADDRESS();
    //     }
    //     if (_isAddressPermitted(_account, _newPermittedAddress)) {
    //         revert ADDRESS_ALREADY_PERMITTED();
    //     }

    //     s_accountPermittedAddresses[_account][_newPermittedAddress] = true;
    //     emit Address_Permitted(_account, _newPermittedAddress);
    // }

    // function removePermittedAddress(address _account, address _permittedAddress) external {
    //     if (msg.sender != _account) {
    //         revert NOT_ACCOUNT_OWNER();
    //     }
    //     if (_permittedAddress == address(0)) {
    //         revert INVALID_ADDRESS();
    //     }
    //     if (!_isAddressPermitted(_account, _permittedAddress)) {
    //         revert ADDRESS_NOT_PERMITTED();
    //     }

    //     s_accountPermittedAddresses[_account][_permittedAddress] = false;
    //     emit Address_Removed_From_Permitted_Addresses(_account, _permittedAddress);
    // }
}
