// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Errors.sol";
import {IAccountManager} from "./interfaces/IAccountManager.sol";
import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract SayvPoolFactory {
    IAccountManager internal iAccountManager;
    IPool internal iPoolAave;
    address immutable i_owner;
    address[] public s_allPools;

    mapping(address pool => uint256 balance) public s_poolBalance;

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
}
