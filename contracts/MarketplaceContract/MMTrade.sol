// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Global/MMMarketplaceGlobal.sol";
import "../utils/MarketplaceValidator.sol";
import "../interfaces/IModernMusuemMarketplace.sol";
import "../interfaces/IMarketplacePayment.sol";
import "../interfaces/ITrade.sol";

contract MMTrade is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IModernMusuemMarketplace,
    MMMarketplaceGlobal,
    ITrade
{
    address public marketplace;

    function initialize(address _marketplace, address _validator) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        validator = MarketplaceValidator(_validator);
        marketplace = _marketplace;
    }

    function updateValidator(address _validator) external onlyOwner {
        validator = MarketplaceValidator(_validator);
    }

    function buy(
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        Order calldata order,
        address sender
    ) external payable returns (uint256 _tokenId, uint256 paid) {
        address _marketplace = marketplace;
        require(msg.sender == _marketplace, "Invalid Caller");
        Order calldata _order = order;
        require(!validator.onAuction(_order.expirationTime), "item on auction");
        address taker = sender;
        (, paid) = _validate(_order, amount);
        INFT nftContract = INFT(contractAddress);
        _tokenId = tokenId;
        if (_isLazyMint(_tokenId, _order.contractAddress)) {
            address to = _order.nftType == NftType.ERC721 ? taker : _order.seller;
            // mint if not Minted
            _tokenId = IMarketplacePayment(_marketplace).safeMint(
                nftContract,
                uint8(_order.nftType),
                to,
                _order.uri,
                _order.supply,
                _order.royaltyReceiver,
                _order.royaltyFee
            );
        } else {
            isValidTransfer(msg.sender, order.seller);
        }
        IMarketplacePayment(_marketplace).settlement{ value: msg.value }(
            nftContract,
            _tokenId,
            paid,
            taker,
            _order,
            false
        );
    }

    function acceptOffer(
        Order calldata order,
        Bid calldata bid,
        address buyer,
        uint256 _amount
    ) external returns (uint256 _tokenId, uint256 amt) {
        address _marketplace = marketplace;
        require(msg.sender == _marketplace, "Invalid Caller");
        Order calldata _order = order;
        Bid calldata _bid = bid;
        address taker = buyer;
        _tokenId = _order.tokenId;
        (, amt) = _validateOffer(_bid, _order, _amount);
        require(validator.validateBid(_bid, taker, amt), "invalid bid");
        INFT nftContract = INFT(_order.contractAddress);
        if (_isLazyMint(_tokenId, _order.contractAddress)) {
            address to = _order.nftType == NftType.ERC721 ? taker : _order.seller;
            // mint if not Minted
            _tokenId = IMarketplacePayment(_marketplace).safeMint(
                nftContract,
                uint8(_order.nftType),
                to,
                _order.uri,
                _order.supply,
                _order.royaltyReceiver,
                _order.royaltyFee
            );
        } else {
            isValidTransfer(taker, order.seller);
        }

        IMarketplacePayment(_marketplace).settlement(nftContract, _tokenId, amt, taker, _order, false);
        return (_tokenId, amt);
    }
}
