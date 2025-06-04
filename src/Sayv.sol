// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

contract Sayv {
    ITokenRegistry internal iTokenRegistry;
    address public s_tokenRegistry;
    address immutable i_owner;

    /**
     * @notice s_accountAvailableBalance tracks user's available balance that can be withdrawn without repayment of any debt.
     */
    mapping(bytes32 accountId => mapping(address token => uint256 amount)) public s_accountAvailableBalance;
    /**
     * @notice s_accountDebtBalance tracks how much the user owes the protocol from taking an advance + any fees;
     * To withdraw full balance of collateral this balance must be 0.
     */
    mapping(bytes32 accountId => mapping(address token => uint256 amount)) public s_accountDebtBalance;
    /**
     * @notice s_accountBalance tracks account balance of each token.
     */
    mapping(bytes32 accountId => mapping(address token => uint256 amount)) public s_accountTokenBalance;
    /**
     * @notice s_accountTotalBalance tracks total balance of all tokens combined in account.
     * Calculation to get total amount is in Calculations.sol
     */
    mapping(bytes32 accountId => uint256 amount) public s_accountTotalBalance;
    /**
     * @notice s_accountAddressBook tracks permitted wallet addresses for each account.
     * Accounts can only withdraw to these addresses.
     * User can add and remove anytime they want.
     * All balances will be tied to User's account ID not individual addresses. (may change***)
     * If user deposits from bank they will have to add an address to withdraw to self custody and use that address to call withdrawl.
     * If user deposits from a self custody wallet the depositing address will be added automatically.
     */
    mapping(bytes32 accountId => mapping(address userWalletAddress => bool isActive)) public s_accountAddressBook;

    event New_Token_Registry_Set(address indexed caller, address indexed newRegistry);
    event Address_Added_To_Address_Book(bytes32 indexed accountId, address indexed userAddress);
    event Address_Removed_From_Address_Book(bytes32 indexed accountId, address indexed userAddress);

    constructor(address _tokenRegistry) {
        i_owner = msg.sender;
        iTokenRegistry = ITokenRegistry(_tokenRegistry);
        s_tokenRegistry = _tokenRegistry;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    function setTokenRegistry(address _tokenRegistry) external onlyOwner {
        if (s_tokenRegistry == _tokenRegistry) {
            revert REGISTRY_ADDRESS_ALREADY_SET(_tokenRegistry, s_tokenRegistry);
        }
        iTokenRegistry = ITokenRegistry(_tokenRegistry);
        s_tokenRegistry = _tokenRegistry;
        emit New_Token_Registry_Set(msg.sender, s_tokenRegistry);
    }

    function addAddressToAddressBook(bytes32 _accountId, address _address) public {
        if (_address == address(0)) {
            revert INVALID_ADDRESS(_accountId, _address);
        }
        if (_isInAccountAddressBook(_accountId, _address)) {
            revert ADDRESS_ALREADY_IN_ADDRESS_BOOK(_accountId, _address);
        }

        s_accountAddressBook[_accountId][_address] = true;
        emit Address_Added_To_Address_Book(_accountId, _address);
    }

    function removeAddressFromAddressBook(bytes32 _accountId, address _address) public {
        if (_address == address(0)) {
            revert INVALID_ADDRESS(_accountId, _address);
        }
        if (!_isInAccountAddressBook(_accountId, _address)) {
            revert ADDRESS_NOT_IN_ADDRESS_BOOK(_accountId, _address);
        }

        s_accountAddressBook[_accountId][_address] = false;
        emit Address_Removed_From_Address_Book(_accountId, _address);
    }

    function _isApprovedOnRegistry(address _token) internal view returns (bool) {
        return iTokenRegistry.checkIfTokenIsApproved(_token);
    }

    function _isInAccountAddressBook(bytes32 _accountId, address _address) internal view returns (bool) {
        return s_accountAddressBook[_accountId][_address];
    }

    function getRegistryContractAddress() public view returns (address) {
        return s_tokenRegistry;
    }
}
