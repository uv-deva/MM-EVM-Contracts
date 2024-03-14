// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "../../utils/MarketplaceValidator.sol";
import "../../interfaces/IModernMusuemMarketplace.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/INFT.sol";
import "../../interfaces/IWETH.sol";

contract MMMarketplaceGlobal is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    ERC721HolderUpgradeable,
    IModernMusuemMarketplace
{
    //Validator Contract Interface
    MarketplaceValidator internal validator;

    using CountersUpgradeable for CountersUpgradeable.Counter;

    // WETH Contract Address
    address public wETHAddress;

    uint256 public updateClosingTime;
    //Order Nonce For Seller
    mapping(address => CountersUpgradeable.Counter) internal _orderNonces;

    //Bid Nonce For Seller
    mapping(address => CountersUpgradeable.Counter) internal _bidderNonces;

    /* Cancelled / finalized orders, by hash. */
    mapping(bytes32 => bool) public cancelledOrFinalized;
    //To delete
    mapping(uint256 => Auction) private auctions;
    //to delete
    mapping(uint256 => bool) private bids;

    /* Fee denomiator that can be used to calculate %. 100% = 10000 */
    uint16 public constant FEE_DENOMINATOR = 10000;

    //fee Spilt array
    FeeSplit[] public feeSplits;

    /* Auction Map */
    mapping(string => Auction) public auctionsMap;
    /* bid map on auctions */
    mapping(string => bool) public bidsMap;

    address public tradeAddress;

    modifier isAllowedToken(address contractAddress) {
        require(validator.allowedPaymenTokens(contractAddress), "Invalid Payment token");
        _;
    }

    modifier isNotBlacklisted(address user) {
        require(!validator.blacklist(user), "Access Denied");
        _;
    }

    modifier onlySeller(Order calldata order) {
        require(validator.verifySeller(order, msg.sender), "Not a seller");
        _;
    }

    function _validate(Order calldata order, uint256 amount) internal returns (address, uint256) {
        (bytes32 digest, address signer) = validator._verifyOrderSig(order);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        bool isToken = order.paymentToken == address(0) ? false : true;
        uint256 paid = isToken ? amount : msg.value;
        require(paid > 0, "invalid amount");
        require(validator.validateOrder(order), "Invalid Order");
        return (signer, paid);
    }

    function _validateOffer(
        Bid calldata bid,
        Order calldata order,
        uint256 amount
    ) internal returns (address, uint256) {
        (bytes32 digest, ) = validator._verifyBidSig(bid);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        return _validate(order, amount);
    }

    function _isLazyMint(uint256 _tokenId, address _contractAddress) internal view returns (bool) {
        return (
            (_tokenId == 0 &&
                (validator.mmNFT721Address() == _contractAddress || validator.mmNFT1155Address() == _contractAddress))
        );
    }

    function isValidTransfer(address buyer, address seller) internal pure {
        require(buyer != seller, "invalid token transfer");
    }

    function _checkEth(address _token) internal pure returns (bool) {
        return _token == address(0) ? true : false;
    }

    function _getRoyalties(INFT nft, uint256 tokenId, uint256 amount) internal view returns (address, uint256) {
        try nft.royaltyInfo(tokenId, amount) returns (address royaltyReceiver, uint256 royaltyAmt) {
            return (royaltyReceiver, royaltyAmt);
        } catch {
            return (address(0), 0);
        }
    }

    function _getTransferUser(address _token, bool isClaim, address user) internal view returns (address) {
        return _token == address(0) || isClaim ? address(this) : user;
    }

    function _invalidateSignedOrder(Order calldata order) internal {
        (bytes32 digest, address signer) = validator._verifyOrderSig(order);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        cancelledOrFinalized[digest] = true;
        _orderNonces[signer].increment();
    }

    function _invalidateSignedBid(address bidder, Bid calldata bid) internal {
        (bytes32 digest, address signer) = validator._verifyBidSig(bid);
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        require(bidder == signer, "not a signer");
        cancelledOrFinalized[digest] = true;
        _bidderNonces[signer].increment();
    }
}
