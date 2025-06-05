// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ITokenRegistry
/// @notice Interface for interacting with the SAYV Token Registry.
/// @dev Defines external functions and events related to token approval tracking.

interface ITokenRegistry {
    /// @notice Emitted when a new token is approved and added to the registry.
    /// @param tokenAddress The address of the token added.
    /// @param chainId The chain ID the token is associated with.
    event Token_Added_To_Registry(address indexed tokenAddress, uint256 indexed chainId);

    /// @notice Emitted when a token is removed from the registry.
    /// @param tokenAddress The address of the token removed.
    /// @param chainId The chain ID the token was associated with.
    event Token_Removed_From_Registry(address indexed tokenAddress, uint256 indexed chainId);

    /**
     * @notice Adds a token to the approved registry.
     * @param _tokenAddress The address of the token to approve.
     * @param _chainId The chain ID the token is deployed on.
     */
    function addTokenToRegistry(address _tokenAddress, uint256 _chainId) external;

    /**
     * @notice Removes a token from the approved registry.
     * @param _tokenAddress The address of the token to remove.
     * @param _chainId The chain ID the token was deployed on.
     */
    function removeTokenFromRegistry(address _tokenAddress, uint256 _chainId) external;

    /**
     * @notice Checks if a token is currently approved in the registry.
     * @param _tokenAddress The address of the token to check.
     * @return True if the token is approved, false otherwise.
     */
    function checkIfTokenIsApproved(address _tokenAddress) external view returns (bool);

    /**
     * @notice Gets the details of a token if approved.
     * @param _tokenAddress The address of the token.
     */
    function getTokenDetails(address _tokenAddress) external view;

    /**
     * @notice Returns the address of the registry's contract owner.
     * @return The address of the owner.
     */
    function getRegistryContractOwnerAddress() external view returns (address);

    /**
     * @notice Returns the address of the deployed registry contract.
     * @return The address of this contract.
     */
    function getRegistryContractAddress() external view returns (address);
}
