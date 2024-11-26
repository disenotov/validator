// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title License Contract
/// @dev This contract represents an ERC721 token where only the owner can mint new licenses.
/// It is designed to be used for issuing licenses as NFTs.
contract License is ERC721, Ownable {
    uint256 private _nextTokenId = 1;

    constructor(address owner, string memory name, string memory symbol) ERC721(name, symbol) Ownable(owner) {}

    /// @notice Mints a new license (NFT) to the specified user.
    /// Can only be called by the owner of the contract.
    /// @param user The address that will receive the newly minted license.
    /// @return The token ID of the minted license.
    function mint(address user) public onlyOwner() returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(user, tokenId);
        return tokenId;
    }

}