// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Custom errors for SAYV Protocol

// SayvVaultFactory.sol
error VAULT_ALREADY_EXIST();

// SayvVault.sol
error NOT_OWNER();
error NOT_AUTHORIZED();
error TOKEN_NOT_ALLOWED();
error APPROVING_TOKEN_ALLOWANCE_FAILED();
error AMOUNT_NOT_APPROVED();
error DEPOSIT_FAILED();
error INVALID_ADDRESS();
error ADDRESS_ALREADY_PERMITTED();
error NOT_ACCOUNT_OWNER();
error ADDRESS_NOT_PERMITTED();
error INSUFFICIENT_FUNDS_AVAILABLE();
error ADVANCES_NOT_AVAILABLE();
error ADVANCE_MAX_REACHED();
error TOO_MANY_DECIMALS();
