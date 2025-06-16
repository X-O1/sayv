// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./SayvErrors.sol";
import {Sayv} from "./Sayv.sol";

contract YieldAdapterFactory {
    address immutable i_owner;
    address[] public s_allActiveVaults;

    mapping(address vault => bool isActive) public s_activeVaults;

    event Vault_Created(address indexed token, address indexed activePool);

    constructor() {
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    function createVault(address _token, address _addressProvider, address _yieldBarringToken)
        external
        onlyOwner
        returns (Sayv)
    {
        if (s_activeVaults[_token]) {
            revert VAULT_ALREADY_EXIST();
        }
        s_activeVaults[_token] = true;
        s_allActiveVaults.push(_token);

        Sayv yieldAdapter = new Sayv(_token, _addressProvider, _yieldBarringToken);
        emit Vault_Created(_token, _addressProvider);
        return yieldAdapter;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
