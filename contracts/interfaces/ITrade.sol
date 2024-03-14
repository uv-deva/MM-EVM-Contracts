// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./IModernMusuemMarketplace.sol";

interface ITrade is IModernMusuemMarketplace {
    function buy(
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        Order calldata order,
        address sender
    ) external payable returns (uint256, uint256);

    function acceptOffer(
        Order calldata order,
        Bid calldata bid,
        address buyer,
        uint256 _amount
    ) external returns (uint256, uint256);
}
