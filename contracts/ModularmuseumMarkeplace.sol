// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./utils/MarketplaceValidator.sol";
import "./interfaces/INFT.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IModernMusuemMarketplace.sol";

/**
 * @title ModernMusuemMarketplace contract
 * @notice NFT marketplace contract for Digital and Physical NFTs ModernMusuem.
 */
contract ModernMusuemMarketplaceV1 is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    ERC721HolderUpgradeable,
    IModernMusuemMarketplace
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    //validator Contract Interface
    MarketplaceValidator internal validator;

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

    function initialize(address _validator, FeeSplit[] calldata _feeSplits, address _wethAddress) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        validator = MarketplaceValidator(_validator);
        _setFeeSplit(_feeSplits, false);
        wETHAddress = _wethAddress;
        updateClosingTime = 600;
    }

    function updateParam(address _validator, FeeSplit[] calldata _feeSplits, address _wethAddress) external onlyOwner {
        validator = MarketplaceValidator(_validator);
        _setFeeSplit(_feeSplits, true);
        wETHAddress = _wethAddress;
    }

    modifier adminOrOwnerOnly(address contractAddress, uint256 tokenId) {
        bool isAdmin = validator.admins(msg.sender);
        require(
            isAdmin || (msg.sender == IERC721Upgradeable(contractAddress).ownerOf(tokenId)),
            "AdminManager: admin and owner only."
        );
        _;
    }

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

    function setClosingTime(uint256 _second) external onlyOwner {
        updateClosingTime = _second;
    }

    function getCurrentOrderNonce(address _owner) public view returns (uint256) {
        return _orderNonces[_owner].current();
    }

    function getCurrentBidderNonce(address _owner) public view returns (uint256) {
        return _bidderNonces[_owner].current();
    }

    function admins(address _admin) external view whenNotPaused returns (bool) {
        return validator.admins(_admin);
    }

    function hashOrder(Order memory _order) external view whenNotPaused returns (bytes32 hash) {
        return validator.hashOrder(_order);
    }

    function hashBid(Bid memory _bid) external view whenNotPaused returns (bytes32 hash) {
        return validator.hashBid(_bid);
    }

    function _isLazyMint(uint256 _tokenId, address _contractAddress) internal view returns (bool) {
        return (
            (_tokenId == 0 &&
                (validator.mmNFT721Address() == _contractAddress || validator.mmNFT1155Address() == _contractAddress))
        );
    }

    function isValidTransfer(address buyer, address seller) private pure {
        require(buyer != seller, "invalid token transfer");
    }

    function _setFeeSplit(FeeSplit[] calldata _feeSplits, bool isUpdate) internal {
        uint256 len = _feeSplits.length;
        for (uint256 i; i < len; i++) {
            if (_feeSplits[i].payee != address(0) && _feeSplits[i].share > 0) {
                if (isUpdate) {
                    feeSplits[i] = _feeSplits[i];
                } else {
                    feeSplits.push(_feeSplits[i]);
                }
            }
        }
    }

    function resetFeeSplit(FeeSplit[] calldata _feeSplits) external onlyOwner {
        delete feeSplits;
        _setFeeSplit(_feeSplits, false);
    }

    // =================== Owner operations ===================

    /**
     * @dev Pause trading
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause trading
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function buy(
        address contractAddress,
        uint256 tokenId,
        uint256 amount,
        Order calldata order
    ) public payable whenNotPaused nonReentrant isAllowedToken(order.paymentToken) isNotBlacklisted(msg.sender) {
        require(!validator.onAuction(order.expirationTime), "item on auction");
        (, uint256 paid) = _validate(order, amount);
        Order calldata _order = order;
        INFT nftContract = INFT(contractAddress);
        uint256 _tokenId = tokenId;
        if (_isLazyMint(_tokenId, _order.contractAddress)) {
            // mint if not Minted
            _tokenId = _order.nftType == NftType.ERC721
                ? nftContract.safeMint(msg.sender, _order.uri, _order.royaltyReceiver, _order.royaltyFee)
                : nftContract.safeMint(
                    order.seller,
                    _order.uri,
                    order.supply,
                    _order.royaltyReceiver,
                    _order.royaltyFee
                );
        } else {
            isValidTransfer(msg.sender, order.seller);
        }

        _settlement(nftContract, _tokenId, paid, msg.sender, _order, false);

        emit Buy(
            msg.sender,
            _order.seller,
            _order.contractAddress,
            order.nftType,
            _tokenId,
            order.value,
            paid,
            block.timestamp,
            _order.paymentToken,
            _order.objId
        );
    }

    function acceptOffer(
        Order calldata order,
        Bid calldata bid,
        address buyer,
        uint256 _amount
    )
        external
        whenNotPaused
        nonReentrant
        onlySeller(order)
        isAllowedToken(order.paymentToken)
        isNotBlacklisted(msg.sender)
    {
        (, uint256 amt) = _validateOffer(bid, order, _amount);
        Order calldata _order = order;
        Bid calldata _bid = bid;
        address taker = buyer;
        require(validator.validateBid(_bid, taker, amt), "invalid bid");
        INFT nftContract = INFT(_order.contractAddress);
        uint256 _tokenId = _order.tokenId;

        if (_isLazyMint(_tokenId, _order.contractAddress)) {
            // mint if not Minted
            _tokenId = _order.nftType == NftType.ERC721
                ? nftContract.safeMint(taker, _order.uri, _order.royaltyReceiver, _order.royaltyFee)
                : nftContract.safeMint(
                    _order.seller,
                    _order.uri,
                    _order.supply,
                    _order.royaltyReceiver,
                    _order.royaltyFee
                );
        } else {
            isValidTransfer(taker, order.seller);
        }

        _settlement(nftContract, _tokenId, amt, taker, _order, false);

        emit AcceptOffer(
            taker,
            msg.sender,
            _order.contractAddress,
            _order.nftType,
            _tokenId,
            _order.value,
            amt,
            block.timestamp,
            _order.paymentToken,
            _order.objId
        );
    }

    function bidding(
        Order calldata order,
        uint256 amount
    ) public payable whenNotPaused nonReentrant isAllowedToken(order.paymentToken) isNotBlacklisted(msg.sender) {
        (, uint256 amt) = _validate(order, amount);

        IToken Token = IToken(order.contractAddress);

        Auction memory _auction = auctionsMap[order.objId];
        Order calldata _order = order;

        require(amt > _auction.currentBid, "Insufficient bidding amount.");
        if (order.paymentToken == address(0)) {
            if (_auction.buyer) {
                payable(_auction.highestBidder).transfer(_auction.currentBid);
            }
        } else {
            IERC20Upgradeable erc20Token = IERC20Upgradeable(_order.paymentToken);
            require(
                erc20Token.allowance(msg.sender, address(this)) >= amt,
                "Allowance is less than amount sent for bidding."
            );

            erc20Token.safeTransferFrom(msg.sender, address(this), amt);

            if (_auction.buyer == true) {
                erc20Token.safeTransfer(_auction.highestBidder, _auction.currentBid);
            }
        }

        _auction.closingTime = _auction.currentBid == 0
            ? _order.expirationTime + updateClosingTime
            : _auction.closingTime + updateClosingTime;
        _auction.currentBid = _order.paymentToken == address(0) ? msg.value : amount;
        uint256 _tokenId = order.tokenId;
        if (_tokenId > 0) {
            if (Token.ownerOf(_tokenId) != address(this) && order.nftType == NftType.ERC721) {
                Token.safeTransferFrom(Token.ownerOf(_tokenId), address(this), _tokenId);
            } else if (Token.balanceOf(address(this), _tokenId) >= order.value && order.nftType == NftType.ERC1155) {
                Token.safeTransferFrom(order.seller, address(this), _tokenId, order.value, "");
            }
        }

        _auction.buyer = true;
        _auction.highestBidder = msg.sender;
        _auction.currentBid = amt;
        auctionsMap[_order.objId] = _auction;
        bidsMap[_order.objId] = true;
        // Bid event
        // Bid event
        emit Bidding(
            _order.contractAddress,
            order.nftType,
            _tokenId,
            order.value,
            _order.seller,
            _auction.highestBidder,
            _auction.currentBid,
            block.timestamp,
            _auction.closingTime,
            _order.paymentToken,
            _order.objId
        );
    }

    function claim(Order calldata order) external whenNotPaused nonReentrant isNotBlacklisted(msg.sender) {
        require(block.timestamp > order.expirationTime, "auction not Ended");

        Auction memory auction = auctionsMap[order.objId];
        require(validator.verifySeller(order, msg.sender) || msg.sender == auction.highestBidder, "not a valid caller");
        Order calldata _order = order;
        uint256 _tokenId = order.tokenId;
        INFT nftContract = INFT(_order.contractAddress);
        if (_isLazyMint(_tokenId, _order.contractAddress)) {
            // mint if not Minted
            _tokenId = _order.nftType == NftType.ERC721
                ? nftContract.safeMint(auction.highestBidder, _order.uri, _order.royaltyReceiver, _order.royaltyFee)
                : nftContract.safeMint(
                    order.seller,
                    _order.uri,
                    order.supply,
                    _order.royaltyReceiver,
                    _order.royaltyFee
                );
        } else {
            isValidTransfer(auction.highestBidder, order.seller);
        }
        _settlement(nftContract, _tokenId, auction.currentBid, auction.highestBidder, _order, true);
        delete auctionsMap[order.objId];
        bidsMap[_order.objId] = false;
        emit Claimed(
            _order.contractAddress,
            order.nftType,
            _tokenId,
            order.value,
            nftContract.ownerOf(_tokenId),
            auction.highestBidder,
            auction.currentBid,
            _order.paymentToken,
            _order.objId
        );
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

    function _settlement(
        INFT nftContract,
        uint256 _tokenId,
        uint256 amt,
        address taker,
        Order calldata _order,
        bool isClaim
    ) internal returns (uint256) {
        (address creator, uint256 royaltyAmt) = _getRoyalties(nftContract, _tokenId, amt);
        require(royaltyAmt < amt, "invalid royalty fee");
        uint256 sellerEarning = _chargeAndSplit(amt, taker, _order.paymentToken, royaltyAmt, creator, isClaim);
        _executeExchange(_order, _order.seller, taker, sellerEarning, _tokenId, isClaim);
        return sellerEarning;
    }

    //Platform Fee Split
    function _splitFee(address user, uint256 _amount, address _erc20Token, bool isClaim) internal returns (uint256) {
        bool isToken = _erc20Token != address(0);
        uint256 _platformFee;
        uint256 len = feeSplits.length;
        for (uint256 i; i < len; i++) {
            uint256 commission = (feeSplits[i].share * _amount) / FEE_DENOMINATOR;
            address payee = feeSplits[i].payee;
            if (isToken) {
                if (isClaim) {
                    IERC20Upgradeable(_erc20Token).safeTransfer(payee, commission);
                } else {
                    IERC20Upgradeable(_erc20Token).safeTransferFrom(user, payee, commission);
                }
            } else {
                payable(payee).transfer(commission);
            }
            _platformFee += commission;
        }
        return _platformFee;
    }

    //Internal function to distribute commission and royalties
    function _chargeAndSplit(
        uint256 _amount,
        address user,
        address _erc20Token,
        uint256 royaltyValue,
        address royaltyReceiver,
        bool isClaim
    ) internal returns (uint256) {
        uint256 amt = _amount;
        address _token = _erc20Token;
        bool isEth = _checkEth(_token);
        address _user = user;
        address sender = _getTransferUser(_token, isClaim, _user);
        IERC20Upgradeable ptoken = IERC20Upgradeable(isEth ? wETHAddress : _token);

        uint256 platformFee;
        uint256 _royaltyValue = royaltyValue;
        address _royaltyReceiver = royaltyReceiver;
        bool _isClaim = isClaim;
        if (isEth) {
            payable(_royaltyReceiver).transfer(_royaltyValue);
            platformFee = _splitFee(sender, amt, _token, _isClaim);
        } else {
            if (_isClaim) {
                if (_royaltyReceiver != address(this)) {
                    ptoken.safeTransfer(_royaltyReceiver, _royaltyValue);
                }
            } else {
                ptoken.safeTransferFrom(sender, _royaltyReceiver, _royaltyValue);
            }
            platformFee = _splitFee(sender, amt, _token, _isClaim);
        }

        emit Reckon(platformFee, _token, _royaltyValue, _royaltyReceiver);
        return amt - (platformFee + _royaltyValue);
    }

    function _getTransferUser(address _token, bool isClaim, address user) private view returns (address) {
        return _token == address(0) || isClaim ? address(this) : user;
    }

    function _checkEth(address _token) private pure returns (bool) {
        return _token == address(0) ? true : false;
    }

    function invalidateSignedOrder(Order calldata order) external whenNotPaused nonReentrant {
        (bytes32 digest, address signer) = validator._verifyOrderSig(order);
        require(!bidsMap[order.objId], "bid exit on item");
        require(!cancelledOrFinalized[digest], "signature already invalidated");
        require(msg.sender == signer, "Not a signer");
        cancelledOrFinalized[digest] = true;
        _orderNonces[signer].increment();
        emit CancelOrder(
            order.seller,
            order.contractAddress,
            order.tokenId,
            order.basePrice,
            block.timestamp,
            order.paymentToken,
            order.objId
        );
    }

    //Bulk cancel Order
    function invalidateSignedBulkOrder(Order[] calldata _order) external whenNotPaused nonReentrant {
        address _signer;
        uint256 len = _order.length;
        for (uint256 i; i < len; i++) {
            Order calldata order = _order[i];
            (bytes32 digest, address signer) = validator._verifyOrderSig(order);
            require(msg.sender == signer, "Not a signer");
            _signer = signer;
            cancelledOrFinalized[digest] = true;
            emit CancelOrder(
                order.seller,
                order.contractAddress,
                order.tokenId,
                order.basePrice,
                block.timestamp,
                order.paymentToken,
                order.objId
            );
        }
        _orderNonces[_signer].increment();
    }

    function invalidateSignedBid(Bid calldata bid) external whenNotPaused nonReentrant {
        (bytes32 digest, address signer) = validator._verifyBidSig(bid);
        require(msg.sender == signer, "Not a signer");
        cancelledOrFinalized[digest] = true;
        _bidderNonces[signer].increment();
        emit CancelOffer(
            bid.bidder,
            bid.seller,
            bid.contractAddress,
            bid.tokenId,
            bid.bidAmount,
            block.timestamp,
            bid.paymentToken,
            bid.objId,
            bid.bidId
        );
    }

    function withdrawETH(address admin) external onlyOwner {
        payable(admin).transfer(address(this).balance);
    }

    function withdrawToken(address admin, address _paymentToken) external onlyOwner isAllowedToken(_paymentToken) {
        IERC20Upgradeable token = IERC20Upgradeable(_paymentToken);
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(admin, amount);
    }

    function _executeExchange(
        Order calldata order,
        address seller,
        address buyer,
        uint256 _amount,
        uint256 _tokenId,
        bool isClaim
    ) internal {
        _invalidateSignedOrder(order);

        bool isToken = order.paymentToken == address(0) ? false : true; // if native currency or not
        // LazyMinting conditions
        // for admin we have to transfer
        // for user we don't have to transfer because its aleady minted direct to buyer
        if (!_isLazyMint(order.tokenId, order.contractAddress) || seller == address(this)) {
            if (order.nftType == NftType.ERC721) {
                IERC721Upgradeable token = IERC721Upgradeable(order.contractAddress);
                token.safeTransferFrom(token.ownerOf(_tokenId), buyer, _tokenId);
            } else {
                IERC1155Upgradeable token = IERC1155Upgradeable(order.contractAddress);
                token.safeTransferFrom(order.seller, buyer, _tokenId, order.value, "");
            }
        } else if (_isLazyMint(order.tokenId, order.contractAddress)) {
            IERC1155Upgradeable token = IERC1155Upgradeable(order.contractAddress);
            token.safeTransferFrom(order.seller, buyer, _tokenId, order.value, "");
        }
        if (isToken) {
            if (isClaim) {
                // this condition only valid if item sell through auction
                //For admin auction no need to transfer payment as is already in contract
                if (address(this) != seller) {
                    IERC20Upgradeable(order.paymentToken).safeTransfer(seller, _amount);
                }
            } else {
                IERC20Upgradeable(order.paymentToken).safeTransferFrom(buyer, seller, _amount);
            }
        } else {
            payable(seller).transfer(_amount);
        }
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

    function _getRoyalties(INFT nft, uint256 tokenId, uint256 amount) internal view returns (address, uint256) {
        try nft.royaltyInfo(tokenId, amount) returns (address royaltyReceiver, uint256 royaltyAmt) {
            return (royaltyReceiver, royaltyAmt);
        } catch {
            return (address(0), 0);
        }
    }

    function _isMinted(address contractAddress, uint256 tokenId) internal view returns (bool) {
        try IERC721Upgradeable(contractAddress).ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @notice This function is used to burn the apporved NFTToken to
     * certain admin address which was allowed by super admin the owner of Admin Manager
     * @dev This Fuction is take two arguments address of contract and tokenId of NFT
     * @param collection tokenId The contract address of NFT contract and tokenId of NFT
     */
    function burnNFT(address collection, uint256 tokenId) public adminOrOwnerOnly(collection, tokenId) {
        INFT nftContract = INFT(collection);

        string memory tokenURI = nftContract.tokenURI(tokenId);
        require(nftContract.getApproved(tokenId) == address(this), "Token not approve for burn");
        nftContract.burn(tokenId);
        emit NFTBurned(collection, tokenId, msg.sender, block.timestamp, tokenURI);
    }

    receive() external payable {}
}
