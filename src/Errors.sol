// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
/// @notice Custom errors for Sayv Protocol
/// @dev Explain to a developer any extra details

/// @notice Errors for Sayv.sol / TokenRegistry.sol
error NOT_OWNER(address caller, address owner);
error TOKEN_NOT_APPROVED(address token);
error REGISTRY_ADDRESS_ALREADY_SET(address attemptedRegistry, address activeRegistry);
error ADDRESS_NOT_VALID(address invalidAddress);
error TOKEN_ALREADY_APPROVED(address tokenAddress);
error NOT_ACTIVE_CHAIN_ID(uint256 chainId, uint256 activeChainId);
error ADDRESS_ALREADY_IN_ADDRESS_BOOK(bytes32 accountId, address userAddress);
error ADDRESS_NOT_IN_ADDRESS_BOOK(bytes32 accountId, address userAddress);
error INVALID_ADDRESS(bytes32 accountId, address userAddress);
