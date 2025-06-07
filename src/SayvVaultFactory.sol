// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {SayvVault} from "./SayvVault.sol";

contract SayvVaultFactory {
    address immutable i_owner;
    address[] public s_allActiveVaults; // To start USDC and aUSDC

    mapping(address vault => bool isActive) public s_activeVaults;

    event Vault_Created(address indexed token, address indexed activeYieldPool);

    constructor() {
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function createVault(address _token, address activeYieldPool) external onlyOwner returns (SayvVault) {
        if (s_activeVaults[_token]) {
            revert VAULT_ALREADY_EXIST();
        }
        s_activeVaults[_token] = true;
        s_allActiveVaults.push(_token);

        SayvVault sayvVault = new SayvVault(_token, activeYieldPool);
        emit Vault_Created(_token, activeYieldPool);
        return sayvVault;
    }
}
