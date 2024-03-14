// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "./MMNFT1155Default.sol";

/**
 * @title Collection
 * @notice This NFT collection contract for user to create the own ERC721 collection
 * @dev Upgradable NFT contract to create  collection
 */

contract Collection1155 is ReentrancyGuard, Ownable, Pausable, MMNFT1155Default {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor(
        string memory name,
        string memory symbol,
        string memory _contractURI,
        string memory tokenURIPrefix,
        address _admin
    ) MMNFT1155Default(name, symbol, _contractURI, tokenURIPrefix, _admin) {
        _tokenIdCounter.increment();
        transferOwnership(_admin);
    }

    function safeMint(
        address to,
        uint256 _supply,
        string memory tokenURI,
        address creator,
        uint256 value
    ) public returns (uint256) {
        uint256 _tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        MMNFT1155Default.safeMint(to, _tokenId, tokenURI, _supply, creator, value);
        return _tokenId;
    }
}
