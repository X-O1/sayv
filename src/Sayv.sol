// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

/// @title Sayv
/// @notice Manages user accounts and balances.
/// @notice Manages the active Token Registry (Token Whitelist for SAYV).

contract Sayv {
    ITokenRegistry internal iTokenRegistry;
    address public s_tokenRegistry;
    address immutable i_owner;

    /**
     * @notice s_accountAvailableBalance tracks user's available balance that can be withdrawn without repayment of any debt.
     */
    mapping(address account => mapping(address token => uint256 amount)) public s_accountAvailableBalance;
    /**
     * @notice s_accountDebtBalance tracks how much the user owes the protocol from taking an advance + any fees;
     * To withdraw full balance of collateral this balance must be 0.
     */
    mapping(address account => mapping(address token => uint256 amount)) public s_accountDebtBalance;
    /**
     * @notice s_accountTokenBalance tracks account balance of each token.
     */
    mapping(address account => mapping(address token => uint256 amount)) public s_accountTokenBalance;
    /**
     * @notice s_accountTotalBalance tracks total balance of all tokens combined in account.
     * Calculation to get total amount is in Calculations.sol
     */
    mapping(address account => uint256 amount) public s_accountTotalBalance;
    /**
     * @notice s_accountPermittedAddresses tracks permitted wallet addresses that can withdraw funds from the SAYV LP for each account.
     * This adds the ability for the user to recover their funds if access to original account is lost or for inheritance planning.
     * Accounts can only withdraw funds from the SAYV LP using these accounts or original account address.
     * If user deposits from a self custody wallet the depositing address will be automatically permitted.
     * User can add and remove addresses anytime they want.
     */
    mapping(address account => mapping(address permittedAddress => bool isPermitted)) public s_accountPermittedAddresses;

    event New_Token_Registry_Set(address indexed caller, address indexed newRegistry);
    event Address_Permitted(address indexed account, address indexed userAddress);
    event Address_Removed_From_Permitted_addresses(address indexed account, address indexed userAddress);

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
    /**
     *
     * @param _tokenRegistry is the contract address of the token whitelist manager for the SAYV protocol.
     * @notice Only tokens registered on this registry can be deposited into the SAYV protocol.
     * @notice This function allows owner of SAYV protocol to changed registry contract if the registry ever upgrades.
     */

    function setTokenRegistry(address _tokenRegistry) external onlyOwner {
        if (s_tokenRegistry == _tokenRegistry) {
            revert REGISTRY_ADDRESS_ALREADY_SET(_tokenRegistry, s_tokenRegistry);
        }
        iTokenRegistry = ITokenRegistry(_tokenRegistry);
        s_tokenRegistry = _tokenRegistry;
        emit New_Token_Registry_Set(msg.sender, s_tokenRegistry);
    }

    /**
     *
     * @param _account address of account owner.
     * @param _newPermittedAddress address being added to the permited list.
     * @notice This address will now be able to withdraw from the SAYV LP.
     */
    function addPermittedAddress(address _account, address _newPermittedAddress) public {
        if (msg.sender != _account) {
            revert NOT_ACCOUNT_OWNER(_account);
        }
        if (_newPermittedAddress == address(0)) {
            revert INVALID_ADDRESS(_account);
        }
        if (_isAddressPermitted(_account, _newPermittedAddress)) {
            revert ADDRESS_ALREADY_PERMITTED(_newPermittedAddress);
        }

        s_accountPermittedAddresses[_account][_newPermittedAddress] = true;
        emit Address_Permitted(_account, _newPermittedAddress);
    }

    /**
     *
     * @param _account address of account owner.
     * @param _permittedAddress permitted address that is being removed from permitted list.
     * @notice This address will no longer be able to withdraw from the SAYV LP.
     */
    function removePermittedAddress(address _account, address _permittedAddress) public {
        if (msg.sender != _account) {
            revert NOT_ACCOUNT_OWNER(_account);
        }
        if (_permittedAddress == address(0)) {
            revert INVALID_ADDRESS(_permittedAddress);
        }
        if (!_isAddressPermitted(_account, _permittedAddress)) {
            revert ADDRESS_NOT_PERMITTED(_permittedAddress);
        }

        s_accountPermittedAddresses[_account][_permittedAddress] = false;
        emit Address_Removed_From_Permitted_addresses(_account, _permittedAddress);
    }

    function _isApprovedOnRegistry(address _token) internal view returns (bool) {
        return iTokenRegistry.checkIfTokenIsApproved(_token);
    }

    function _isAddressPermitted(address _account, address _permittedAddress) internal view returns (bool) {
        return s_accountPermittedAddresses[_account][_permittedAddress];
    }

    function getRegistryContractAddress() public view returns (address) {
        return s_tokenRegistry;
    }
}
