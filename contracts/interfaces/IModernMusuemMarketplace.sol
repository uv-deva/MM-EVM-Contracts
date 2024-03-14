// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IModernMusuemMarketplace {
    struct Order {
        /* Order maker address. */
        address seller;
        /* contract Address */
        address contractAddress;
        /* Collection Royalty Fee. */
        uint256 royaltyFee;
        /* Royalty receiver once order is completed */
        address royaltyReceiver;
        /* Token used to pay for the order. Only WETH for now */
        address paymentToken;
        /* Base price of the order (in paymentTokens). */
        uint256 basePrice;
        /* Listing timestamp. */
        uint256 listingTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint256 expirationTime;
        /* Order nonce, used to prevent duplicate. */
        uint256 nonce;
        /* Token Id */
        uint256 tokenId;
        /* Token supply */
        uint256 supply;
        /* Token buy Value */
        uint256 value;
        /* NFT Type ERC721 or ERC1155 */
        NftType nftType;
        /* Order type Physical or Digital */
        Type orderType;
        /* Signature */
        bytes signature;
        /* metadata URI for Minting*/
        string uri;
        /* Obj Id for internal mapping */
        string objId;
    }

    struct Bid {
        /* Order Seller address. */
        address seller;
        /* Order Buyer address. */
        address bidder;
        /* contract Address */
        address contractAddress;
        /* Token used to pay for the order. Only WETH for now */
        address paymentToken;
        /* Base price of the order (in paymentTokens). */
        uint256 bidAmount;
        /* Listing timestamp. */
        uint256 bidTime;
        /* Expiration timestamp - 0 for no expiry. */
        uint256 expirationTime;
        /* Order nonce, used to prevent duplicate. */
        uint256 nonce;
        /* Token Id */
        uint256 tokenId;
        /* Token supply */
        uint256 supply;
        /* Token buy Value */
        uint256 value;
        /* NFT Type ERC721 or ERC1155 */
        NftType nftType;
        /*signature*/
        bytes signature;
        /* Obj Id for internal mapping */
        string objId;
        /* Bid Id for internal mapping */
        string bidId;
    }

    struct FeeSplit {
        /* address of fee receive*/
        address payee;
        /*percentage of fee spilt*/
        uint256 share;
    }

    struct Auction {
        address highestBidder;
        address lastOwner;
        uint256 currentBid;
        uint256 closingTime;
        bool buyer;
    }

    /**
     * Type: Digital or Physical.
     */
    enum Type {
        Digital,
        Physical
    }

    /**
     * Type: ERC721 or ERC1155.
     */
    enum NftType {
        ERC721,
        ERC1155
    }

    event Buy(
        address buyer,
        address seller,
        address contractAddress,
        NftType,
        uint256 tokenId,
        uint256 value,
        uint256 amount,
        uint256 time,
        address paymentToken,
        string objId
    );
    event AcceptOffer(
        address buyer,
        address seller,
        address contractAddress,
        NftType,
        uint256 tokenId,
        uint256 value,
        uint256 amount,
        uint256 time,
        address paymentToken,
        string objId
    );

    event CancelOrder(
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 time,
        address paymentToken,
        string objId
    );

    event CancelOffer(
        address bidder,
        address seller,
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 time,
        address paymentToken,
        string objId,
        string bidId
    );

    event Reckon(uint256 platformFee, address _erc20Token, uint256 royaltyValue, address royaltyReceiver);

    event AdminRemoved(address admin, uint256 time);
    event AdminAdded(address admin, uint256 time);

    event NFTBurned(
        address indexed collection,
        uint256 indexed tokenId,
        address indexed admin,
        uint256 time,
        string tokenURI
    );
    event Bidding(
        address indexed collection,
        NftType,
        uint256 indexed tokenId,
        uint256 value,
        address indexed seller,
        address bidder,
        uint256 amount,
        uint256 time,
        uint256 closingTime,
        address paymentToken,
        string objId
    );

    event Claimed(
        address indexed collection,
        NftType,
        uint256 indexed tokenId,
        uint256 value,
        address indexed seller,
        address bidder,
        uint256 amount,
        address paymentToken,
        string objId
    );

    event SetTradeFee(uint256 tradeFee);
    event BlacklistUser(address user);
    event AllowedPaymentToken(address token);
}
