// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITokenRegistry {
    event Token_Added_To_Registry(address indexed tokenAddress, uint256 indexed chainId);
    event Token_Removed_From_Registry(address indexed tokenAddress, uint256 indexed chainId);

    function addTokenToRegistry(address, uint256) external;

    function removeTokenFromRegistry(address _tokenAddress, uint256 _chainId) external;

    function checkIfTokenIsApproved(address _tokenAddress) external view returns (bool);

    function getTokenDetails(address _tokenAddress) external view;

    function getRegistryContractOwnerAddress() external view returns (address);

    function getRegistryContractAddress() external view returns (address);
}
