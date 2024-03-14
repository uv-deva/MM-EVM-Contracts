// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IModernMusuemMarketplace.sol";
import "./INFT.sol";

interface IMarketplacePayment is IModernMusuemMarketplace {
    function tokenTransfer(address erc20Address, address from, address to, uint256 amount) external;

    function nftTransfer(address contractAddress, address from, address to, uint256 tokenId) external;

    function safeMint(
        INFT nftContract,
        uint8 nftType,
        address to,
        string memory uri,
        uint256 supply,
        address royaltyReceiver,
        uint256 royaltyFee
    ) external returns (uint256);

    function settlement(
        INFT nftContract,
        uint256 _tokenId,
        uint256 amount,
        address taker,
        Order calldata _order,
        bool isClaim
    ) external payable returns (uint256);
}
