// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../Royalties.sol";
import "../utils/Roles.sol";

contract MMNFT1155Default is
    ERC1155,
    ERC1155URIStorage,
    Pausable,
    AccessControl,
    ERC1155Burnable,
    ERC1155Supply,
    Royalties,
    Role
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    string public baseURI;
    string public contractURI;

    string _name;
    string _symbol;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        string memory _contractURI,
        string memory tokenURIPrefix,
        address _admin
    ) ERC1155(tokenURIPrefix) {
        _tokenIdCounter.increment();
        baseURI = tokenURIPrefix;
        contractURI = _contractURI;
        _name = _tokenName;
        _symbol = _tokenSymbol;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(MINTER_ROLE, _admin);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // function safeMint(
    //     address to,
    //     uint256 supply,
    //     string memory _uri,
    //     address creator,
    //     uint256 value
    // ) public virtual onlyRole(MINTER_ROLE) returns (uint256) {
    //     uint256 tokenId = _tokenIdCounter.current();
    //     _tokenIdCounter.increment();
    //     _mint(to, tokenId, supply, "");
    //     _setURI(tokenId, _uri);
    //     if (value > 0) {
    //         _setTokenRoyalty(tokenId, creator, value);
    //     }
    //     return tokenId;
    // }

    function safeMint(
        address to,
        uint256 tokenId,
        string memory _uri,
        uint256 supply,
        address creator,
        uint256 value
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        _mint(to, tokenId, supply, "");
        _setURI(tokenId, _uri);
        if (value > 0) {
            _setTokenRoyalty(tokenId, creator, value);
        }
        return tokenId;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function setBaseURI(string memory _baseURI) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _baseURI;
    }

    function setContractURI(string memory _contractURI) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        contractURI = _contractURI;
    }

    function uri(uint256 tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return ERC1155URIStorage.uri(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl, Royalties) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
