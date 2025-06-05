// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {ITokenRegistry} from "../src/interfaces/ITokenRegistry.sol";

/// @title AccountManager
/// @notice Core contract for tracking user balances, debts, and access permissions within the SAYV protocol.
/// @dev This contract is intended to be called only by the vault factory for state changes.

contract AccountManager {
    /// @dev Interface for checking approved tokens on the protocol's token registry.
    ITokenRegistry immutable iTokenRegistry;

    /// @dev Owner of the contract, the deployer.
    address immutable i_owner;

    /// @dev Authorized vault factory contract allowed to update account balances.
    address private s_vaultFactory;

    /// @dev Once set, s_vaultFactory cannot be changed.
    bool private s_authorityLocked;

    /// @notice Tracks user's token balances within the protocol.
    mapping(address account => mapping(address token => uint256 amount)) public s_accountTokenBalance;

    /// @notice Tracks user's debt owed to the protocol from advances taken including any accumulated fees.
    mapping(address account => mapping(address token => uint256 amount)) public s_accountDebtBalance;

    /// @notice Tracks additional addresses allowed to withdraw funds on behalf of a user.
    /// @dev Used for inheritance or account recovery. Only the account owner can manage this list.
    mapping(address account => mapping(address permittedAddress => bool isPermitted)) public s_accountPermittedAddresses;

    /// @notice Emitted when a new address is added to the permitted list.
    event Address_Permitted(address indexed account, address indexed userAddress);

    /// @notice Emitted when a permitted address is removed.
    event Address_Removed_From_Permitted_Addresses(address indexed account, address indexed userAddress);

    /// @notice Emitted when the vault factory is locked in and cannot be changed.
    event Authority_Locked(address indexed vaultFactory);

    /// @param _tokenRegistry Address of the deployed token registry contract.
    constructor(address _tokenRegistry) {
        i_owner = msg.sender;
        iTokenRegistry = ITokenRegistry(_tokenRegistry);
    }

    /// @notice Restricts function to only the contract owner.
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    /// @notice Restricts function to only the authorized vault factory.
    modifier onlyAuthorized() {
        if (msg.sender != s_vaultFactory) {
            revert NOT_AUTHORIZED();
        }
        _;
    }

    /**
     * @notice Sets the vault factory address authorized to update balances.
     * @dev This can only be set once by the contract owner.
     * @param _vaultFactory The address of the vault factory contract.
     */
    function lockAuthority(address _vaultFactory) external onlyOwner {
        if (s_authorityLocked) {
            revert AUTHORITY_ALREADY_LOCKED(_vaultFactory);
        }
        s_vaultFactory = _vaultFactory;
        s_authorityLocked = true;
        emit Authority_Locked(_vaultFactory);
    }

    /**
     * @notice Adds a permitted address that can withdraw funds on behalf of the user.
     * @param _account The original account owner.
     * @param _newPermittedAddress The address to grant withdrawal access to.
     */
    function addPermittedAddress(address _account, address _newPermittedAddress) external {
        if (msg.sender != _account) {
            revert NOT_ACCOUNT_OWNER(_account);
        }
        if (_newPermittedAddress == address(0)) {
            revert INVALID_ADDRESS();
        }
        if (_isAddressPermitted(_account, _newPermittedAddress)) {
            revert ADDRESS_ALREADY_PERMITTED(_newPermittedAddress);
        }

        s_accountPermittedAddresses[_account][_newPermittedAddress] = true;
        emit Address_Permitted(_account, _newPermittedAddress);
    }

    /**
     * @notice Removes a permitted address from the user's access list.
     * @param _account The original account owner.
     * @param _permittedAddress The address to remove from withdrawal access.
     */
    function removePermittedAddress(address _account, address _permittedAddress) external {
        if (msg.sender != _account) {
            revert NOT_ACCOUNT_OWNER(_account);
        }
        if (_permittedAddress == address(0)) {
            revert INVALID_ADDRESS();
        }
        if (!_isAddressPermitted(_account, _permittedAddress)) {
            revert ADDRESS_NOT_PERMITTED(_permittedAddress);
        }

        s_accountPermittedAddresses[_account][_permittedAddress] = false;
        emit Address_Removed_From_Permitted_Addresses(_account, _permittedAddress);
    }

    /**
     * @notice Updates the user's internal token and debt balances.
     * @dev Only callable by the authorized vault factory. Validates token is whitelisted.
     * @param _account The user's address.
     * @param _token The token to update balances for.
     * @param _tokenBalance New total token balance.
     * @param _debtBalance New total debt owed for this token.
     */
    function updateAccountBalances(address _account, address _token, uint256 _tokenBalance, uint256 _debtBalance)
        external
        onlyAuthorized
    {
        if (!_isTokenApprovedOnRegistry(_token)) {
            revert TOKEN_NOT_APPROVED(_token);
        }
        s_accountTokenBalance[_account][_token] = _tokenBalance;
        s_accountDebtBalance[_account][_token] = _debtBalance;
    }

    /**
     * @notice Returns the user's debt balance for a given token.
     * @param _account The user's address.
     * @param _token The token to query.
     * @return The amount of debt owed for that token.
     */
    function getAccountDebtBalance(address _account, address _token) external view returns (uint256) {
        return s_accountDebtBalance[_account][_token];
    }

    /**
     * @notice Returns the user's net token balance (after subtracting debt).
     * @param _account The user's address.
     * @param _token The token to query.
     * @return The available token balance.
     */
    function getAccountTokenBalance(address _account, address _token) external view returns (uint256) {
        return s_accountTokenBalance[_account][_token] - s_accountDebtBalance[_account][_token];
    }

    /**
     * @notice Internal helper to check if a token is approved via the token registry.
     * @param _token The token address to verify.
     * @return True if the token is approved.
     */
    function _isTokenApprovedOnRegistry(address _token) public view returns (bool) {
        return iTokenRegistry.checkIfTokenIsApproved(_token);
    }

    /**
     * @notice Internal helper to check if a given address is permitted to access a user's funds.
     * @param _account The user's account.
     * @param _permittedAddress The address to check.
     * @return True if the address is permitted.
     */
    function _isAddressPermitted(address _account, address _permittedAddress) public view returns (bool) {
        return s_accountPermittedAddresses[_account][_permittedAddress];
    }
}
