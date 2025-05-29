// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title StablecoinRegistry
 * @notice Maintains a list of approved stablecoin addresses for the SAYV protocol
 * @dev Only the contract owner can add or remove stablecoins
 * @custom:author https://github.com/X-O1
 * @custom:version v1.0
 */

contract StablecoinRegistry {
    error NOT_OWNER(address caller, address owner);
    error TOKEN_ALREADY_APPROVED(address tokenAddress);

    address immutable i_owner;
    address[] private listOfApprovedTokens;

    struct TokenDetails {
        address tokenAddress;
        uint256 chainId;
        address priceFeed;
        bool approved;
    }

    mapping(address tokenAddress => TokenDetails) public approvedTokenDetails;

    constructor() {
        i_owner = msg.sender;
    }

    modifier ownerOnly() {
        if (msg.sender != i_owner) {
            revert NOT_OWNER(msg.sender, i_owner);
        }
        _;
    }

    function addStablecoinToRegistry(address _tokenAddress, uint256 _chainId, address _priceFeed) external ownerOnly {
        // uint256 numOfApprovedTokens = listOfApprovedTokens.length;
        // for (uint256 i = 0; i < numOfApprovedTokens; i++) {
        //     if (listOfApprovedTokens[i] == _tokenAddress) {
        //         revert TOKEN_ALREADY_APPROVED(_tokenAddress);
        //     }
        // }

        if (_checkIfTokenIsApproved(_tokenAddress)) {
            revert TOKEN_ALREADY_APPROVED(_tokenAddress);
        } else {
            TokenDetails memory token = TokenDetails({tokenAddress: _tokenAddress, chainId: _chainId, priceFeed: _priceFeed, approved: true});
            listOfApprovedTokens.push(_tokenAddress);
            approvedTokenDetails[_tokenAddress] = token;
        }
    }

    function _checkIfTokenIsApproved(address _tokenAddress) internal view returns (bool) {
        TokenDetails storage tokenDetails = approvedTokenDetails[_tokenAddress];
        bool tokenApproved;

        if (tokenDetails.approved == true) {
            tokenApproved = true;
            return tokenApproved;
        } else {
            return tokenApproved;
        }
    }
}
