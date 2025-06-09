// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/ERC20/IERC20.sol";

contract MockAToken is IERC20 {
    string public name = "Mock aToken";
    string public symbol = "aMOCK";
    uint8 public decimals = 6;

    address public pool;
    address public underlying;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(address _pool, address _underlying) {
        pool = _pool;
        underlying = _underlying;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "Not pool");
        _;
    }

    function mint(address onBehalfOf, uint256 amount, uint256) external onlyPool returns (bool) {
        _balances[onBehalfOf] += amount;
        emit Transfer(address(0), onBehalfOf, amount);
        return true;
    }

    function burn(address from, address to, uint256 amount, uint256) external onlyPool {
        _balances[from] -= amount;
        IERC20(underlying).transfer(to, amount);
        emit Transfer(from, address(0), amount);
    }

    function totalSupply() public pure override returns (uint256) {
        // Fake supply
        return 1_000_000e6;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");
        _allowances[from][msg.sender] -= amount;

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
