// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Custom errors for SAYV Protocol

// SayvVaultFactory.sol
error VAULT_ALREADY_EXIST();

// SayvVault.sol
error APPROVING_TOKEN_ALLOWANCE_FAILED();

error NOT_OWNER();
error DEPOSIT_FAILED();
error INSUFFICIENT_AVAILABLE_FUNDS();
error ALLOWANCE_NOT_ENOUGH();
error INVALID_LIQUIDITY_INDEX();
error UNDERFLOW();
error ADVANCES_AT_MAX_CAPACITY();
error ACCOUNT_HAS_NO_DEBT();
error AMOUNT_IS_GREATER_THAN_TOTAL_DEBT();
error NOT_ACCOUNT_OWNER();
