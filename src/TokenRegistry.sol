// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title TokenRegistry
 * @notice Maintains a list of approved tokens for the SAYV protocol.
 * @dev Only the contract owner can add or remove tokens in v1.0.
 * @custom:version v1.0 — Future versions will allow DAO-based management.
 */
import "./Errors.sol";

contract TokenRegistry {
    /// @notice The address of the contract owner (immutable).
    address immutable i_owner;

    /// @notice The chain ID this registry is locked to.
    uint256 immutable i_activeChainId;

    /// @notice Struct containing token details.
    struct TokenDetails {
        address tokenAddress;
        uint256 chainId;
    }

    /// @notice Mapping to store metadata for each token.
    mapping(address token => TokenDetails) public tokenDetails;

    /// @notice Tracks which tokens are approved.
    mapping(address token => bool approved) public isApproved;

    /// @notice Emitted when a token is added to the registry.
    event Token_Added_To_Registry(address indexed tokenAddress, uint256 indexed chainId);

    /// @notice Emitted when a token is removed from the registry.
    event Token_Removed_From_Registry(address indexed tokenAddress, uint256 indexed chainId);

    /// @notice Initializes the contract, setting the owner and current chain ID.
    constructor() {
        i_owner = msg.sender;
        i_activeChainId = block.chainid;
    }

    /// @notice Restricts function to only the contract owner.
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER();
        }
        _;
    }

    /**
     * @notice Adds a token to the registry.
     * @dev Token must not already be approved. Chain ID must match the current chain.
     * @param _tokenAddress The token to be added.
     * @param _chainId The chain ID the token is associated with.
     */
    function addTokenToRegistry(address _tokenAddress, uint256 _chainId) external onlyOwner {
        if (_chainId != i_activeChainId) {
            revert NOT_ACTIVE_CHAIN_ID();
        }
        if (isApproved[_tokenAddress]) {
            revert TOKEN_ALREADY_APPROVED();
        }

        isApproved[_tokenAddress] = true;
        tokenDetails[_tokenAddress] = TokenDetails({tokenAddress: _tokenAddress, chainId: _chainId});

        emit Token_Added_To_Registry(_tokenAddress, _chainId);
    }

    /**
     * @notice Removes a token from the registry.
     * @dev Token must already be approved. Chain ID must match the current chain.
     * @param _tokenAddress The token to be removed.
     * @param _chainId The chain ID the token is associated with.
     */
    function removeTokenFromRegistry(address _tokenAddress, uint256 _chainId) external onlyOwner {
        if (_chainId != i_activeChainId) {
            revert NOT_ACTIVE_CHAIN_ID();
        }
        if (!isApproved[_tokenAddress]) {
            revert TOKEN_NOT_ALLOWED();
        }

        isApproved[_tokenAddress] = false;

        emit Token_Removed_From_Registry(_tokenAddress, _chainId);
    }

    /**
     * @notice Returns whether a token is approved.
     * @param _tokenAddress The token address to query.
     * @return True if the token is approved, false otherwise.
     */
    function checkIfTokenIsApproved(address _tokenAddress) external view returns (bool) {
        return isApproved[_tokenAddress];
    }

    /**
     * @notice Returns the full token details for an approved token.
     * @param _tokenAddress The token address to query.
     * @return details The TokenDetails struct containing token metadata.
     */
    function getTokenDetails(address _tokenAddress) external view returns (TokenDetails memory details) {
        if (isApproved[_tokenAddress]) return tokenDetails[_tokenAddress];
    }

    /**
     * @notice Returns the address of the contract owner.
     * @return The owner's address.
     */
    function getRegistryContractOwnerAddress() external view returns (address) {
        return i_owner;
    }

    /**
     * @notice Returns the address of this contract.
     * @return The address of the deployed registry contract.
     */
    function getRegistryContractAddress() external view returns (address) {
        return address(this);
    }
}
