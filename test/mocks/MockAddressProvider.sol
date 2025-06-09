// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "@aave-v3-core/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave-v3-core/interfaces/IPoolAddressesProvider.sol";

contract MockAddressesProvider is IPoolAddressesProvider {
    address public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function getPool() external view override returns (address) {
        return pool;
    }

    // You can leave the rest of the interface unimplemented if unused
    function getMarketId() external view override returns (string memory) {}

    function setMarketId(string calldata newMarketId) external override {}

    function getAddress(bytes32 id) external view override returns (address) {}

    function setAddressAsProxy(bytes32 id, address newImplementationAddress) external override {}

    function setAddress(bytes32 id, address newAddress) external override {}

    function setPoolImpl(address newPoolImpl) external override {}

    function getPoolConfigurator() external view override returns (address) {}

    function setPoolConfiguratorImpl(address newPoolConfiguratorImpl) external override {}

    function getPriceOracle() external view override returns (address) {}

    function setPriceOracle(address newPriceOracle) external override {}

    function getACLManager() external view override returns (address) {}

    function setACLManager(address newAclManager) external override {}

    function getACLAdmin() external view override returns (address) {}

    function setACLAdmin(address newAclAdmin) external override {}

    function getPriceOracleSentinel() external view override returns (address) {}

    function setPriceOracleSentinel(address newPriceOracleSentinel) external override {}

    function getPoolDataProvider() external view override returns (address) {}

    function setPoolDataProvider(address newDataProvider) external override {}
}
