import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address.js";
import { assert, expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("Unit Tests", function () {
  let collectionFactory721: any,
    collectionFactory1155: any,
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

    const CollectionFactory721 = await ethers.getContractFactory("CollectionFactory721");
    collectionFactory721 = await upgrades.deployProxy(CollectionFactory721, { initializer: "initialize" });
    await collectionFactory721.deployed();

    const CollectionFactory1155 = await ethers.getContractFactory("CollectionFactory1155");
    collectionFactory1155 = await upgrades.deployProxy(CollectionFactory1155, { initializer: "initialize" });
    await collectionFactory1155.deployed();
  });

  it("createCollection721", async () => {
    var tx = await collectionFactory721
      .connect(john)
      .createCollection("Collection1", "Collection1", "ipfs.io", "ipfs.io");
    var txn = await tx.wait();
    var events = await txn.events?.filter((e: any) => e.event === "CollectionCreated");
    let collectionAddress = events[0].args[1];

    const Collection721 = await ethers.getContractFactory("Collection721");
    const collection721 = Collection721.attach(collectionAddress);
    console.log(await collection721.name());
    var tx = await collection721.connect(john).safeMint(chris.address, "ipfs/io", john.address, 100);
    var txn = await tx.wait();
    var events = await txn.events?.filter((e: any) => e.event === "Transfer");
    console.log(events[0].args["tokenId"]);
  });

  it("createCollection1155", async () => {
    var tx = await collectionFactory1155
      .connect(john)
      .createCollection("Collection1", "Collection1", "ipfs.io", "ipfs.io");
    var txn = await tx.wait();
    var events = await txn.events?.filter((e: any) => e.event === "CollectionCreated");
    let collectionAddress = events[0].args[1];

    const Collection1155 = await ethers.getContractFactory("Collection1155");
    const collection1155 = Collection1155.attach(collectionAddress);
    var tx = await collection1155.connect(john).safeMint(chris.address, 10, "ipfs/io", john.address, 100);
    var txn = await tx.wait();
    var events = await txn.events?.filter((e: any) => e.event === "Transfer");
    console.log(events[0].args["tokenId"]);
  });
});
