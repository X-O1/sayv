// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockUSDC} from "../mocks/MockUsdc.sol";
import {MockAUSDC} from "../mocks/MockAUSDC.sol";
import {DataTypes} from "../mocks/MockDataTyples.sol";

contract MockPool {
    MockUSDC internal immutable usdc;
    MockAUSDC internal immutable aUSDC;
    uint256 constant RAY = 1e27;
    mapping(address => uint256) public liquidityIndex;
    mapping(address => mapping(address => uint256)) public scaledBalances;

    constructor(address usdcAddress, address ausdcAddress) {
        usdc = MockUSDC(usdcAddress);
        aUSDC = MockAUSDC(ausdcAddress);
        setLiquidityIndex(address(usdc), 1 * RAY);
    }

    function setLiquidityIndex(address asset, uint256 newIndex) public {
        require(newIndex > 0, "Index must be > 0");
        liquidityIndex[asset] = newIndex;
    }

    function getReserveNormalizedIncome(address asset) public view returns (uint256) {
        return liquidityIndex[asset];
    }

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory) {
        return DataTypes.ReserveData({
            configuration: DataTypes.ReserveConfigurationMap(0),
            liquidityIndex: uint128(getReserveNormalizedIncome(asset)),
            currentLiquidityRate: 0,
            variableBorrowIndex: 0,
            currentVariableBorrowRate: 0,
            currentStableBorrowRate: 0,
            lastUpdateTimestamp: uint40(block.timestamp),
            aTokenAddress: address(0),
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            id: 0,
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 /*referralCode*/ ) external {
        uint256 index = liquidityIndex[asset];
        require(index > 0, "Index not set");

        uint256 scaledAmount = (amount * RAY) / index;
        scaledBalances[asset][onBehalfOf] += scaledAmount;

        MockAUSDC(address(aUSDC)).mint(onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        uint256 index = liquidityIndex[asset];
        require(index > 0, "Index not set");

        uint256 scaledAmount = (amount * RAY) / index;
        uint256 aUSDCAmountToBurn = (amount / index) * RAY;
        require(scaledBalances[asset][msg.sender] >= scaledAmount, "Insufficient balance");

        scaledBalances[asset][msg.sender] -= scaledAmount;

        MockAUSDC(address(aUSDC)).burn(msg.sender, aUSDCAmountToBurn);
        MockUSDC(address(usdc)).transfer(to, amount);

        return amount;
    }

    function getUserBalance(address asset, address user) external view returns (uint256 actualBalance) {
        uint256 index = liquidityIndex[asset];
        uint256 scaled = scaledBalances[asset][user];
        actualBalance = (scaled * index) / RAY;
    }

    function getPool() external view returns (address) {
        return address(this);
    }
}
