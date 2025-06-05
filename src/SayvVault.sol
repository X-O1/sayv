// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract SayvVault {
    IAccountManager internal iAccountManager;
    IPool internal iPoolAave;
    address immutable i_owner;
    address[] public s_allVaults; // To start USDC and aUSDC

    mapping(address vault => bool isActive) public s_activeVaults;
    mapping(address vault => uint256 balance) public s_VaultBalance;
    mapping(address vault => uint256 balance) public s_advances;
    mapping(address vault => uint256 balance) public s_advanceFeesEarned;

    event Vault_Created(address indexed token);

    constructor(address _accountManager, address _iPoolAave) {
        i_owner = msg.sender;
        iAccountManager = IAccountManager(_accountManager);
        iPoolAave = IPool(_iPoolAave);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    function createVault(address _token) public onlyOwner {
        if (!iAccountManager._isTokenApprovedOnRegistry(_token)) {
            revert TOKEN_NOT_APPROVED(_token);
        }
        if (s_activeVaults[_token]) {
            revert POOL_ALREADY_EXIST(_token);
        }
        s_activeVaults[_token] = true;
        s_allVaults.push(_token);

        emit Vault_Created(_token);
    }

    // Deposit into sayv auto sends to aave.
}
