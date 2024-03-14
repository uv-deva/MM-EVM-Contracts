import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { CollectionFactory1155__factory } from "../../src/types/factories/contracts/CollectionFactory1155__factory";
import { readContractAddress, writeContractAddress } from "./addresses/utils";

task("deploy:CollectionFactory1155")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start deploying the CollectionFactory1155 Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const nftFactory: CollectionFactory1155__factory = <CollectionFactory1155__factory>(
      await ethers.getContractFactory("CollectionFactory1155", accounts[index])
    );

    const cbrNFTProxy = await upgrades.deployProxy(nftFactory, []);
    await cbrNFTProxy.deployed();
    writeContractAddress("collectionFactory1155", cbrNFTProxy.address);
    console.log("CollectionFactory1155 proxy deployed to: ", cbrNFTProxy.address);

    const impl = await upgrades.erc1967.getImplementationAddress(cbrNFTProxy.address);
    console.log("Implementation :", impl);
  });

task("upgrade:CollectionFactory1155")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start upgrading the  CollectionFactory1155 Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const nftFactory: CollectionFactory1155__factory = <CollectionFactory1155__factory>(
      await ethers.getContractFactory("CollectionFactory1155", accounts[index])
    );

    const proxyNFTAddress = readContractAddress("collectionFactory1155");

    const upgraded = await upgrades.upgradeProxy(proxyNFTAddress, nftFactory);

    console.log("CollectionFactory1155 upgraded to: ", upgraded.address);

    const impl = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Implementation :", impl);
  });

task("verify:CollectionFactory1155")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [],
    });
  });
