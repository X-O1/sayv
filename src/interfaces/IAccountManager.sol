// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAccountManager {
    event New_Token_Registry_Set(address indexed caller, address indexed newRegistry);
    event Address_Permitted(address indexed account, address indexed userAddress);
    event Address_Removed_From_Permitted_Addresses(address indexed account, address indexed userAddress);

    /**
     *
     * @param _poolFactory address of the only contract authorized to make updates to account balances.
     * @notice Can only be set one time.
     */
    function lockAuthority(address _poolFactory) external;

    /**
     *
     * @param _account address of account owner.
     * @param _newPermittedAddress address being added to the permitted list.
     * @notice This address will now be able to withdraw from the SAYV LP.
     */
    function addPermittedAddress(address _account, address _newPermittedAddress) external;

    /**
     *
     * @param _account address of account owner.
     * @param _permittedAddress permitted address that is being removed from permitted list.
     * @notice This address will no longer be able to withdraw from the SAYV LP.
     */
    function removePermittedAddress(address _account, address _permittedAddress) external;
    /**
     * @notice Updates both the token and debt balances for a user's account.
     * @dev Callable by authorized external contracts to sync account state.
     * @param _account The address of the user's account.
     * @param _token The token address for which the balances are being updated.
     * @param _tokenBalance The new token balance for the account.
     * @param _debtBalance The new debt balance for the account.
     */
    function updateAccountBalances(address _account, address _token, uint256 _tokenBalance, uint256 _debtBalance)
        external;

    /**
     * @notice Returns the current debt balance of a user for a specific token.
     * @param _account The address of the user's account.
     * @param _token The token address to query debt for.
     * @return The amount of debt the user owes in the specified token.
     */
    function getAccountDebtBalance(address _account, address _token) external view returns (uint256);

    /**
     * @notice Returns the token balance of a user for a specific token.
     * @param _account The address of the user's account.
     * @param _token The token address to query balance for.
     * @return The amount of tokens the user has in their account.
     */
    function getAccountTokenBalance(address _account, address _token) external view returns (uint256);

    function _isAddressPermitted(address _account, address _permittedAddress) external view returns (bool);

    function _isTokenApprovedOnRegistry(address _token) external view returns (bool);
}
