import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { CollectionFactory721__factory } from "../../src/types/factories/contracts/CollectionFactory721__factory";
import { readContractAddress, writeContractAddress } from "./addresses/utils";

task("deploy:CollectionFactory721")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start deploying the CollectionFactory721 Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const nftFactory: CollectionFactory721__factory = <CollectionFactory721__factory>(
      await ethers.getContractFactory("CollectionFactory721", accounts[index])
    );

    const cbrNFTProxy = await upgrades.deployProxy(nftFactory, []);
    await cbrNFTProxy.deployed();
    writeContractAddress("collectionFactory721", cbrNFTProxy.address);
    console.log("CollectionFactory721 proxy deployed to: ", cbrNFTProxy.address);

    const impl = await upgrades.erc1967.getImplementationAddress(cbrNFTProxy.address);
    console.log("Implementation :", impl);
  });

task("upgrade:CollectionFactory721")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start upgrading the  CollectionFactory721 Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const nftFactory: CollectionFactory721__factory = <CollectionFactory721__factory>(
      await ethers.getContractFactory("CollectionFactory721", accounts[index])
    );

    const proxyNFTAddress = readContractAddress("collectionFactory721");

    const upgraded = await upgrades.upgradeProxy(proxyNFTAddress, nftFactory);

    console.log("CollectionFactory721 upgraded to: ", upgraded.address);

    const impl = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Implementation :", impl);
  });

task("verify:CollectionFactory721")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [],
    });
  });
