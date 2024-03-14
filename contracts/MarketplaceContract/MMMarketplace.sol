// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Global/MMMarketplaceGlobal.sol";
import "../interfaces/IMarketplacePayment.sol";
import "../interfaces/ITrade.sol";

/**
 * @title Modern Musuem Marketplace contract
 * @notice NFT marketplace contract for Digital and Physical NFTs Modern Musuem.
 */
contract ModernMusuemMarketplace is Initializable, MMMarketplaceGlobal, IMarketplacePayment {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

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

    function setTradeAddress(address _tradeAddress) external onlyOwner {
        tradeAddress = _tradeAddress;
    }

    function setClosingTime(uint256 _second) external onlyOwner {
        updateClosingTime = _second;
    }

    function getCurrentOrderNonce(address owner) external view returns (uint256) {
        return _orderNonces[owner].current();
    }

    function getCurrentBidderNonce(address owner) external view returns (uint256) {
        return _bidderNonces[owner].current();
    }

    function admins(address _admin) external view whenNotPaused returns (bool) {
        return validator.admins(_admin);
    }

    function hashOrder(Order calldata _order) external view whenNotPaused returns (bytes32 hash) {
        return validator.hashOrder(_order);
    }

    function hashBid(Bid calldata _bid) external view whenNotPaused returns (bytes32 hash) {
        return validator.hashBid(_bid);
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
    ) external payable whenNotPaused nonReentrant isAllowedToken(order.paymentToken) isNotBlacklisted(msg.sender) {
        (uint256 _tokenId, uint256 paid) = ITrade(tradeAddress).buy{ value: msg.value }(
            contractAddress,
            tokenId,
            amount,
            order,
            msg.sender
        );
        emit Buy(
            msg.sender,
            order.seller,
            order.contractAddress,
            order.nftType,
            _tokenId,
            order.value,
            paid,
            block.timestamp,
            order.paymentToken,
            order.objId
        );
    }

    function bidding(
        Order calldata order,
        uint256 amount
    ) external payable whenNotPaused nonReentrant isAllowedToken(order.paymentToken) isNotBlacklisted(msg.sender) {
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
        address _owner;
        if (_tokenId > 0) {
            _owner = Token.ownerOf(_tokenId);
            if (_owner != address(this)) {
                Token.safeTransferFrom(_owner, address(this), _tokenId);
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
            _order.nftType,
            _tokenId,
            _order.value,
            _order.seller,
            _auction.highestBidder,
            _auction.currentBid,
            block.timestamp,
            _auction.closingTime,
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
        (uint256 _tokenId, uint256 amt) = ITrade(tradeAddress).acceptOffer(order, bid, buyer, _amount);
        Order calldata _order = order;
        emit AcceptOffer(
            buyer,
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
        emit Claimed(
            _order.contractAddress,
            order.nftType,
            _tokenId,
            order.value,
            _order.seller,
            auction.highestBidder,
            auction.currentBid,
            _order.paymentToken,
            _order.objId
        );
        delete auctionsMap[order.objId];
        bidsMap[_order.objId] = false;
    }

    function settlement(
        INFT nftContract,
        uint256 _tokenId,
        uint256 amount,
        address taker,
        Order calldata _order,
        bool isClaim
    ) external payable returns (uint256) {
        require(msg.sender == tradeAddress, "Invalid Caller");
        uint256 sellerEarning = _settlement(nftContract, _tokenId, amount, taker, _order, isClaim);
        return sellerEarning;
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
        } else if (_isLazyMint(order.tokenId, order.contractAddress) && order.nftType == NftType.ERC1155) {
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

    function tokenTransfer(address erc20Address, address from, address to, uint256 amount) external {
        require(msg.sender == tradeAddress, "Invalid Caller");
        IERC20Upgradeable(erc20Address).safeTransferFrom(from, to, amount);
    }

    function nftTransfer(address contractAddress, address from, address to, uint256 tokenId) external {
        INFT nftContract = INFT(contractAddress);
        require(msg.sender == tradeAddress, "Invalid Caller");
        nftContract.safeTransferFrom(from, to, tokenId);
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
    function burnNFT(address collection, uint256 tokenId) external adminOrOwnerOnly(collection, tokenId) {
        INFT nftContract = INFT(collection);

        string memory tokenURI = nftContract.tokenURI(tokenId);
        require(nftContract.getApproved(tokenId) == address(this), "Token not approve for burn");
        nftContract.burn(tokenId);
        emit NFTBurned(collection, tokenId, msg.sender, block.timestamp, tokenURI);
    }

    function safeMint(
        INFT nftContract,
        uint8 nftType,
        address to,
        string memory uri,
        uint256 supply,
        address royaltyReceiver,
        uint256 royaltyFee
    ) external returns (uint256 _tokenId) {
        require(msg.sender == tradeAddress, "Invalid Caller");
        _tokenId = NftType(nftType) == NftType.ERC721
            ? nftContract.safeMint(to, uri, royaltyReceiver, royaltyFee)
            : nftContract.safeMint(to, uri, supply, royaltyReceiver, royaltyFee);
    }

    receive() external payable {}
}
