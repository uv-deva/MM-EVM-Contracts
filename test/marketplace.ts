import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address.js";
import { assert, expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";

function getSignPayloadFromListingData(order: any) {
  const [
    collectibleOwner,
    contractAddress,
    royalty,
    creatorAddress,
    paymentTokenType,
    price,
    startTime,
    endTime,
    nonce,
    tokenId,
    supply,
    value,
    nftType,
    orderType,
    signature,
    uri,
    objId,
  ] = order;
  return {
    basePrice: price,
    contractAddress: contractAddress,
    expirationTime: endTime,
    listingTime: startTime,
    nonce,
    objId: objId,
    paymentToken: paymentTokenType,
    royaltyFee: royalty,
    royaltyReceiver: creatorAddress,
    seller: collectibleOwner,
    tokenId: tokenId,
    supply: supply,
    value: value,
    nftType: nftType,
    orderType: orderType,
    uri: uri,
  };
}

function getSignPayloadForBidData(bid: any) {
  const [
    seller,
    bidder,
    contractAddress,
    paymentToken,
    bidAmount,
    bidTime,
    expirationTime,
    nonce,
    tokenId,
    supply,
    value,
    nftType,
    signature,
    objId,
    bidId,
  ] = bid;
  return {
    seller: seller,
    bidder: bidder,
    contractAddress: contractAddress,
    paymentToken: paymentToken,
    bidAmount: bidAmount,
    bidTime: bidTime,
    expirationTime: expirationTime,
    nonce,
    tokenId: tokenId,
    supply: supply,
    value: value,
    nftType: nftType,
    objId: objId,
  };
}

describe("Unit Tests", function () {
  let validator: any,
    marketPlace: any,
    trade: any,
    admin: SignerWithAddress,
    chris: SignerWithAddress,
    john: SignerWithAddress,
    token: any,
    nft721: any,
    nft1155: any,
    weth: any;

  beforeEach(async () => {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    admin = signers[0];
    chris = signers[1];
    john = signers[2];

    const Validator = await ethers.getContractFactory("MarketplaceValidator");
    validator = await upgrades.deployProxy(Validator, { initializer: "initialize" });
    await validator.deployed();

    const WETH = await ethers.getContractFactory("MMToken");
    weth = await WETH.deploy();
    await weth.deployed();
    await weth.initialize();

    const market = await ethers.getContractFactory("ModernMusuemMarketplace");
    let feeSplit = [[admin.address, 1000]];
    marketPlace = await upgrades.deployProxy(market, [validator.address, feeSplit, weth.address], {
      initializer: "initialize",
    });
    await marketPlace.deployed();

    const Trade = await ethers.getContractFactory("MMTrade");
    trade = await upgrades.deployProxy(Trade, [marketPlace.address, validator.address], {
      initializer: "initialize",
    });
    await trade.deployed();

    const NFT721 = await ethers.getContractFactory("MMNFT721");
    nft721 = await NFT721.deploy(marketPlace.address, "contractURI", "BaseURI/");
    await nft721.deployed();

    const NFT1155 = await ethers.getContractFactory("MMNFT1155");
    nft1155 = await NFT1155.deploy("ModernMuseum", "MM", marketPlace.address, "contractURI", "BaseURI/");
    await nft1155.deployed();

    const Token = await ethers.getContractFactory("MMToken");
    token = await Token.deploy();
    await token.deployed();
    await token.initialize();

    await marketPlace.setTradeAddress(trade.address);
    await validator.setMarketplaceAddress(marketPlace.address);
    await validator.setNFT721Address(nft721.address);
    await validator.setNFT1155Address(nft1155.address);
  });
  it("it should update closing time", async () => {
    var tx = await marketPlace.setClosingTime(600);
    tx.wait();
  });

  it("buy", async () => {
    await nft1155.connect(john).safeMint(john.address, "image1", 10, john.address, 10);
    let objId = "objId";
    objId = objId.toString();
    let order = [
      john.address,
      nft1155.address,
      10,
      john.address,
      "0x0000000000000000000000000000000000000000",
      "10000000000000000000",
      0,
      0,
      0,
      1,
      10,
      5,
      1,
      1,
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "image1",
      objId,
    ];

    const typedDataMessage = {
      types: {
        Order: [
          { name: "seller", type: "address" },
          { name: "contractAddress", type: "address" },
          { name: "royaltyFee", type: "uint256" },
          { name: "royaltyReceiver", type: "address" },
          { name: "paymentToken", type: "address" },
          { name: "basePrice", type: "uint256" },
          { name: "listingTime", type: "uint256" },
          { name: "expirationTime", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "tokenId", type: "uint256" },
          { name: "supply", type: "uint256" },
          { name: "value", type: "uint256" },
          { name: "nftType", type: "uint8" },
          { name: "orderType", type: "uint8" },
          { name: "uri", type: "string" },
          { name: "objId", type: "string" },
        ],
      },
      domain: {
        name: "ModernMusuem Marketplace",
        version: "1.0.1",
        chainId: 31337,
        verifyingContract: validator.address,
      },
      primaryType: "Order",
      message: getSignPayloadFromListingData(order),
    };
    const signature = await john._signTypedData(
      typedDataMessage.domain,
      typedDataMessage.types,
      typedDataMessage.message,
    );
    order = [
      john.address,
      nft1155.address,
      10,
      john.address,
      "0x0000000000000000000000000000000000000000",
      "10000000000000000000",
      0,
      0,
      0,
      1,
      10,
      5,
      1,
      1,
      signature,
      "image1",
      objId,
    ];

    console.log("sample", john.address, await validator._verifyOrderSig(order));

    let nftPrice = order[5];

    const royaltyFeeCalculations = ((nftPrice * 10) / 10000).toString(); // royaltyAmount = (value (10 ETH) * royalties.amount ( % of royality)) / 10000
    const platformFeeCalculations = ((1000 * nftPrice) / 10000).toString(); // (feeSplits[i].share(/*percentage of fee spilt*/) * _amount (10 ETH)) / FEE_DENOMINATOR (10000)

    await validator.addPaymentTokens(["0x0000000000000000000000000000000000000000"]);
    await token.transfer(chris.address, 100);
    await token.connect(chris).approve(marketPlace.address, 100);
    const balanceBefore = await ethers.provider.getBalance(john.address);
    var tx = await marketPlace.connect(chris).buy(nft1155.address, 1, "10000000000000000000", order, {
      value: "10000000000000000000",
    });
    var tx1 = await marketPlace.connect(chris).buy(nft1155.address, 1, "10000000000000000000", order, {
      value: "10000000000000000000",
    });
    console.log(balanceBefore);
    var txn = await tx.wait();

    // Retrieve Reckon event
    var events = await txn.events?.filter((e: any) => e.event === "Reckon");
    var event = events[0];

    let tokenId = 1;

    const nftBalanceAfterJohn = await nft1155.balanceOf(john.address, tokenId);
    const nftBalanceAfterChris = await nft1155.balanceOf(chris.address, tokenId);
    const balanceAfter = await ethers.provider.getBalance(john.address);
    const differenceOfBalance = balanceAfter.sub(balanceBefore);

    console.log("nftBalanceAfterJohn", nftBalanceAfterJohn);
    console.log("nftBalanceAfterChris", nftBalanceAfterChris);

    var royaltyFee = parseInt(await event.args?.royaltyValue);
    var platformFee = await event.args?.platformFee;

    expect(royaltyFeeCalculations).to.equal(royaltyFee.toString());
    expect(platformFeeCalculations).to.equal(platformFee.toString());
    expect((Number(differenceOfBalance) + Number(platformFee)).toString()).to.equal(nftPrice);
  });

  // it("WithDraw eth", async () => {
  //   // Send ETH to the contract
  //   const amountToSend = ethers.utils.parseEther("1"); // Sending 1 ETH
  //   await john.sendTransaction({
  //     to: marketPlace.address,
  //     value: amountToSend,
  //   });

  //   const contractBalanceBefore = await ethers.provider.getBalance(marketPlace.address);
  //   const tx = await marketPlace.withdrawETH(admin.address);
  //   const txn = await tx.wait();
  //   const contractBalanceAfter = await ethers.provider.getBalance(marketPlace.address);

  //   expect(contractBalanceBefore).to.equal(amountToSend);
  //   expect(contractBalanceAfter).to.equal(0);
  // });
  // it("WithDraw token ", async () => {
  //   await token.transfer(marketPlace.address, 100);
  //   await validator.addPaymentTokens([token.address]);
  //   const contractBalanceBefore = await token.balanceOf(marketPlace.address);
  //   await marketPlace.withdrawToken(john.address, token.address);
  //   const adminBalance = await token.balanceOf(john.address);
  //   expect(contractBalanceBefore).to.equal(adminBalance);
  // });

  // it("lazy minting", async () => {
  //   let objId = "objId";
  //   objId = objId.toString();
  //   let order = [
  //     john.address,
  //     nft1155.address,
  //     10,
  //     john.address,
  //     "0x0000000000000000000000000000000000000000",
  //     "10000000000000000000",
  //     0,
  //     0,
  //     0,
  //     0,
  //     10,
  //     3,
  //     1,
  //     1,
  //     "0x0000000000000000000000000000000000000000000000000000000000000000",
  //     "image1",
  //     objId,
  //   ];

  //   const typedDataMessage = {
  //     types: {
  //       Order: [
  //         { name: "seller", type: "address" },
  //         { name: "contractAddress", type: "address" },
  //         { name: "royaltyFee", type: "uint256" },
  //         { name: "royaltyReceiver", type: "address" },
  //         { name: "paymentToken", type: "address" },
  //         { name: "basePrice", type: "uint256" },
  //         { name: "listingTime", type: "uint256" },
  //         { name: "expirationTime", type: "uint256" },
  //         { name: "nonce", type: "uint256" },
  //         { name: "tokenId", type: "uint256" },
  //         { name: "supply", type: "uint256" },
  //         { name: "value", type: "uint256" },
  //         { name: "nftType", type: "uint8" },
  //         { name: "orderType", type: "uint8" },
  //         { name: "uri", type: "string" },
  //         { name: "objId", type: "string" },
  //       ],
  //     },
  //     domain: {
  //       name: "ModernMusuem Marketplace",
  //       version: "1.0.1",
  //       chainId: 31337,
  //       verifyingContract: validator.address,
  //     },
  //     primaryType: "Order",
  //     message: getSignPayloadFromListingData(order),
  //   };

  //   const signature = await john._signTypedData(
  //     typedDataMessage.domain,
  //     typedDataMessage.types,
  //     typedDataMessage.message,
  //   );
  //   //  console.log("signature ---- >", signature);
  //   order = [
  //     john.address,
  //     nft1155.address,
  //     10,
  //     john.address,
  //     "0x0000000000000000000000000000000000000000",
  //     "10000000000000000000",
  //     0,
  //     0,
  //     0,
  //     0,
  //     10,
  //     3,
  //     1,
  //     1,
  //     signature,
  //     "image1",
  //     objId,
  //   ];

  //   let nftPrice = order[5];
  //   let tokenId = order[9];
  //   const royaltyFeeCalculations = ((nftPrice * 10) / 10000).toString(); // royaltyAmount = (value (10 ETH) * royalties.amount ( % of royality)) / 10000
  //   const platformFeeCalculations = ((1000 * nftPrice) / 10000).toString(); // (feeSplits[i].share(/*percentage of fee spilt*/) * _amount (10 ETH)) / FEE_DENOMINATOR (10000)
  //   const nftBalanceBeforeJohn = await nft1155.balanceOf(john.address, tokenId);
  //   const nftBalanceBeforeChris = await nft1155.balanceOf(chris.address, tokenId);

  //   console.log("nftBalanceBeforeJohn", nftBalanceBeforeJohn);
  //   console.log("nftBalanceBeforeChris", nftBalanceBeforeChris);

  //   await validator.addPaymentTokens(["0x0000000000000000000000000000000000000000"]);
  //   await token.transfer(chris.address, "10000000000000000000");
  //   await token.connect(chris).approve(marketPlace.address, "10000000000000000000");
  //   const balanceBefore = await ethers.provider.getBalance(john.address);
  //   var tx = await marketPlace
  //     .connect(chris)
  //     .buy(nft1155.address, 0, "10000000000000000000", order, { value: "10000000000000000000" });
  //   var txn = await tx.wait();
  //   // Retrieve Reckon event
  //   var events = await txn.events?.filter((e: any) => e.event === "Reckon");
  //   var event = events[0];

  //   tokenId = parseInt(txn.events[4].args["tokenId"]);
  //   const nftBalanceAfterJohn = await nft1155.balanceOf(john.address, tokenId);
  //   const nftBalanceAfterChris = await nft1155.balanceOf(chris.address, tokenId);
  //   const balanceAfter = await ethers.provider.getBalance(john.address);
  //   const differenceOfBalance = balanceAfter.sub(balanceBefore);

  //   console.log("nftBalanceAfterJohn", nftBalanceAfterJohn);
  //   console.log("nftBalanceAfterChris", nftBalanceAfterChris);

  //   var royaltyFee = await event.args?.royaltyValue;
  //   var platformFee = await event.args?.platformFee;
  //   expect(royaltyFeeCalculations).to.equal(royaltyFee);
  //   expect(platformFeeCalculations).to.equal(platformFee);
  //   expect((Number(differenceOfBalance) + Number(platformFee)).toString()).to.equal(nftPrice);
  // });

  // it("acceptOffer", async () => {
  //   await nft721.connect(john).safeMint(john.address, "image1", john.address, 10);
  //   let objId = "objId";
  //   objId = objId.toString();

  //   let order = [
  //     john.address,
  //     nft721.address,
  //     10,
  //     john.address,
  //     token.address,
  //     "1000",
  //     0,
  //     0,
  //     0,
  //     1,
  //     0,
  //     0,
  //     0,
  //     1,
  //     "0x0000000000000000000000000000000000000000000000000000000000000000",
  //     "image1",
  //     objId,
  //   ];

  //   const typedDataMessage = {
  //     types: {
  //       Order: [
  //         { name: "seller", type: "address" },
  //         { name: "contractAddress", type: "address" },
  //         { name: "royaltyFee", type: "uint256" },
  //         { name: "royaltyReceiver", type: "address" },
  //         { name: "paymentToken", type: "address" },
  //         { name: "basePrice", type: "uint256" },
  //         { name: "listingTime", type: "uint256" },
  //         { name: "expirationTime", type: "uint256" },
  //         { name: "nonce", type: "uint256" },
  //         { name: "tokenId", type: "uint256" },
  //         { name: "supply", type: "uint256" },
  //         { name: "value", type: "uint256" },
  //         { name: "nftType", type: "uint8" },
  //         { name: "orderType", type: "uint8" },
  //         { name: "uri", type: "string" },
  //         { name: "objId", type: "string" },
  //       ],
  //     },
  //     domain: {
  //       name: "ModernMusuem Marketplace",
  //       version: "1.0.1",
  //       chainId: 31337,
  //       verifyingContract: validator.address,
  //     },
  //     primaryType: "Order",
  //     message: getSignPayloadFromListingData(order),
  //   };

  //   const signature = await john._signTypedData(
  //     typedDataMessage.domain,
  //     typedDataMessage.types,
  //     typedDataMessage.message,
  //   );

  //   order = [
  //     john.address,
  //     nft721.address,
  //     10,
  //     john.address,
  //     token.address,
  //     "1000",
  //     0,
  //     0,
  //     0,
  //     1,
  //     0,
  //     0,
  //     0,
  //     1,
  //     signature,
  //     "image1",
  //     objId,
  //   ];

  //   let bid = [
  //     john.address,
  //     chris.address,
  //     nft721.address,
  //     token.address,
  //     "2000",
  //     0,
  //     0,
  //     0,
  //     1,
  //     0,
  //     0,
  //     1,
  //     "0x0000000000000000000000000000000000000000000000000000000000000000",
  //     "objId",
  //     "bidId",
  //   ];
  //   const typedDataMessageBid = {
  //     types: {
  //       Bid: [
  //         { name: "seller", type: "address" },
  //         { name: "bidder", type: "address" },
  //         { name: "contractAddress", type: "address" },
  //         { name: "paymentToken", type: "address" },
  //         { name: "bidAmount", type: "uint256" },
  //         { name: "bidTime", type: "uint256" },
  //         { name: "expirationTime", type: "uint256" },
  //         { name: "nonce", type: "uint256" },
  //         { name: "tokenId", type: "uint256" },
  //         { name: "supply", type: "uint256" },
  //         { name: "value", type: "uint256" },
  //         { name: "nftType", type: "uint8" },
  //         { name: "objId", type: "string" },
  //       ],
  //     },
  //     domain: {
  //       name: "ModernMusuem Marketplace",
  //       version: "1.0.1",
  //       chainId: 31337,
  //       verifyingContract: validator.address,
  //     },
  //     message: getSignPayloadForBidData(bid),
  //   };
  //   const signatureBid = await chris._signTypedData(
  //     typedDataMessageBid.domain,
  //     typedDataMessageBid.types,
  //     typedDataMessageBid.message,
  //   );
  //   bid = [
  //     john.address,
  //     chris.address,
  //     nft721.address,
  //     token.address,
  //     "2000",
  //     0,
  //     0,
  //     0,
  //     1,
  //     0,
  //     0,
  //     1,
  //     signatureBid,
  //     "objId",
  //     "bidId",
  //   ];
  //   console.log("sample", chris.address, await validator._verifyBidSig(bid));

  //   let nftPrice = bid[4];

  //   const royaltyFeeCalculations = ((nftPrice * 10) / 10000).toString(); // royaltyAmount = (value (10 ETH) * royalties.amount ( % of royality)) / 10000
  //   const platformFeeCalculations = ((1000 * nftPrice) / 10000).toString(); // (feeSplits[i].share(/*percentage of fee spilt*/) * _amount (10 ETH)) / FEE_DENOMINATOR (10000)

  //   await validator.addPaymentTokens(["0x0000000000000000000000000000000000000000", token.address]);
  //   await token.transfer(chris.address, "2000");
  //   await token.connect(chris).approve(marketPlace.address, "2000");
  //   const balanceBefore = await token.balanceOf(john.address);
  //   const nftBalanceAfterJohn = await nft721.ownerOf(1);
  //   var tx = await marketPlace.connect(john).acceptOffer(order, bid, chris.address, "2000");

  //   var txn = await tx.wait();

  //   // Retrieve Reckon event
  //   var events = await txn.events?.filter((e: any) => e.event === "Reckon");
  //   var event = events[0];

  //   const nftBalanceAfterChris = await nft721.ownerOf(1);
  //   const balanceAfter = await token.balanceOf(john.address);
  //   const differenceOfBalance = balanceAfter.sub(balanceBefore);
  //   console.log("balanceBefore", balanceBefore);
  //   console.log("balanceAfter", balanceAfter);
  //   console.log("nftBalanceAfterJohn", nftBalanceAfterJohn);
  //   console.log("nftBalanceAfterChris", nftBalanceAfterChris);

  //   var royaltyFee = parseInt(await event.args?.royaltyValue);
  //   var platformFee = await event.args?.platformFee;

  //   expect(royaltyFeeCalculations).to.equal(royaltyFee.toString());
  //   expect(platformFeeCalculations).to.equal(platformFee.toString());
  //   expect((Number(differenceOfBalance) + Number(platformFee)).toString()).to.equal(nftPrice);
  // });
});
