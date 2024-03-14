import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { ModernMusuemMarketplace__factory } from "../../types";
import { readContractAddress, writeContractAddress } from "./addresses/utils";
import mArguments from "./arguments/ModernMusuemMarketplace";

task("deploy:ModernMusuemMarketplace")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start deploying the ModernMusuem Marketplace Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const marketplace: ModernMusuemMarketplace__factory = <ModernMusuemMarketplace__factory>(
      await ethers.getContractFactory("ModernMusuemMarketplace", accounts[index])
    );

    const marketplaceProxy = await upgrades.deployProxy(marketplace, [
      mArguments.VALIDATOR,
      mArguments.FEE_SPLIT,
      mArguments.WETH_ADDRESS,
    ]);
    await marketplaceProxy.deployed();
    writeContractAddress("ModernMusuemMarketplace", marketplaceProxy.address);
    console.log("ModernMusuem Marketplace proxy deployed to: ", marketplaceProxy.address);

    const impl = await upgrades.erc1967.getImplementationAddress(marketplaceProxy.address);
    console.log("Implementation :", impl);
  });

task("upgrade:ModernMusuemMarketplace")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start upgrading the ModernMusuem Marketplace Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const marketplaceProxy: ModernMusuemMarketplace__factory = <ModernMusuemMarketplace__factory>(
      await ethers.getContractFactory("ModernMusuemMarketplace", accounts[index])
    );

    const proxyMarketPlaceAddress = readContractAddress("ModernMusuemMarketplace");

    const upgraded = await upgrades.upgradeProxy(proxyMarketPlaceAddress, marketplaceProxy);

    console.log("ModernMusuem Marketplace upgraded to: ", upgraded.address);

    const impl = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Implementation :", impl);
  });

task("verify:ModernMusuemMarketplace")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [],
    });
  });
