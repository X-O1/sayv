// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title SAYV Protocol Custom Errors
/// @notice Defines all custom errors used throughout the SAYV protocol for efficient and clear reverts.

/// @notice Thrown when a function caller is not the contract owner.
/// @param caller The address attempting the call.
/// @param owner The expected contract owner.
error NOT_OWNER(address caller, address owner);

/// @notice Thrown when a token is not approved in the Token Registry.
/// @param token The unapproved token address.
error TOKEN_NOT_APPROVED(address token);

/// @notice Thrown when attempting to overwrite the registry address after it's already set.
/// @param attemptedRegistry The new registry address being set.
/// @param activeRegistry The currently active registry address.
error REGISTRY_ADDRESS_ALREADY_SET(address attemptedRegistry, address activeRegistry);

/// @notice Thrown when an address provided is zero or invalid.
/// @param invalidAddress The address deemed invalid.
error ADDRESS_NOT_VALID(address invalidAddress);

/// @notice Thrown when trying to approve a token that is already approved.
/// @param tokenAddress The token that is already approved.
error TOKEN_ALREADY_APPROVED(address tokenAddress);

/// @notice Thrown when a function is called with a chain ID that doesn't match the current chain.
/// @param chainId The invalid chain ID.
/// @param activeChainId The expected chain ID.
error NOT_ACTIVE_CHAIN_ID(uint256 chainId, uint256 activeChainId);

/// @notice Thrown when attempting to add an address that is already permitted.
/// @param userAddress The address already listed as permitted.
error ADDRESS_ALREADY_PERMITTED(address userAddress);

/// @notice Thrown when attempting to remove or access an address not on the permitted list.
/// @param userAddress The address not found in the permitted list.
error ADDRESS_NOT_PERMITTED(address userAddress);

/// @notice Thrown when a function receives a zero address or invalid input.
/// @param userAddress The invalid or zero address.
error INVALID_ADDRESS(address userAddress);

/// @notice Thrown when a caller attempts to act on an account they do not own.
/// @param accountOwner The account owner address expected.
error NOT_ACCOUNT_OWNER(address accountOwner);

/// @notice Thrown when a caller lacks the necessary authority to perform an action.
error NOT_AUTHORIZED();

/// @notice Thrown when the pool factory authority has already been locked in.
/// @param poolFactory The pool factory address that attempted the change.
error AUTHORIZATION_ALREADY_SET(address poolFactory);
