// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract License is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("GameItem", "ITM") Ownable(msg.sender) {}

    function mint(address user, string memory tokenURI) public returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(user, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}