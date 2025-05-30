// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITokenRegistry {
    error NOT_OWNER(address caller, address owner);
    error TOKEN_ALREADY_APPROVED(address tokenAddress);
    error TOKEN_NOT_APPROVED(address tokenAddress);
    error NOT_ACTIVE_CHAIN_ID(uint256 chainId, uint256 activeChainId);

    struct TokenDetails {
        address tokenAddress;
        uint256 chainId;
    }

    event Token_Added_To_Registry(address indexed tokenAddress, uint256 indexed chainId);
    event Token_Removed_From_Registry(address indexed tokenAddress, uint256 indexed chainId);

    function addTokenToRegistry(address, uint256) external;

    function removeTokenFromRegistry(address _tokenAddress, uint256 _chainId) external;

    function checkIfTokenIsApproved(address _tokenAddress) external view returns (bool);

    function getTokenDetails(address _tokenAddress) external view;

    function getContractOwnerAddress() external view;
}
