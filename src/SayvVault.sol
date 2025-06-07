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

    struct AccountBalance {
        uint256 accountBalance;
        uint256 locked;
        uint256 advanced;
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
            s_accountBalances[msg.sender].accountBalance += _amount;
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
        if (_amount > getAccountAvailableBalance(msg.sender)) {
            revert INSUFFICIENT_FUNDS_AVAILABLE();
        }
        if (!_repayYieldAdvance) {
            s_accountBalances[msg.sender].accountBalance -= _amount;
            s_vaultBalances[address(this)].totalDeposits -= _amount;
        }
        _withdrawFromPool(_amount, msg.sender);

        emit Withdraw_From_Vault(i_vaultTokenAddress, _amount, msg.sender);
    }

    function takeAdvance() external {}

    function _repayAdvance(uint256 _amount) internal {
        uint256 advanceBalance = getAccountAdvanceBalance(msg.sender);

        if (_amount >= advanceBalance) {
            s_accountBalances[msg.sender].accountBalance += (_amount - advanceBalance);
            s_accountBalances[msg.sender].advanced = 0;
            s_accountBalances[msg.sender].locked = 0;
            s_vaultBalances[address(this)].totalDeposits += _amount;
            s_vaultBalances[address(this)].totalAdvances -= _amount;
        }
        if (_amount < advanceBalance) {
            s_accountBalances[msg.sender].advanced -= _amount;
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

    function getAccountAvailableBalance(address _account) public view returns (uint256) {
        uint256 availableBalance = s_accountBalances[_account].accountBalance - s_accountBalances[_account].locked;
        return availableBalance;
    }

    function getAccountAdvanceBalance(address _account) public view returns (uint256) {
        return s_accountBalances[_account].advanced;
    }

    function getAccountLockedBalance(address _account) public view returns (uint256) {
        return s_accountBalances[_account].locked;
    }

    function _isAddressPermitted(address _account, address _permittedAddress) public view returns (bool) {
        return s_accountPermittedAddresses[_account][_permittedAddress];
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
