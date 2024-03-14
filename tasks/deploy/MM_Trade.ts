import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MMTrade__factory } from "../../types";
import { readContractAddress, writeContractAddress } from "./addresses/utils";
import cArguments from "./arguments/ModernMusuemMarketplace";

task("deploy:Trade")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start deploying the Trade Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const tradeContractFactory: MMTrade__factory = <MMTrade__factory>(
      await ethers.getContractFactory("MMTrade", accounts[index])
    );
    const proxyMarketPlaceAddress = readContractAddress("ModernMusuemMarketplace");

    const tradeProxy = await upgrades.deployProxy(tradeContractFactory, [
      proxyMarketPlaceAddress,
      cArguments.VALIDATOR,
    ]);
    await tradeProxy.deployed();
    writeContractAddress("MMtrade", tradeProxy.address);
    console.log("Trade proxy deployed to: ", tradeProxy.address);

    const impl = await upgrades.erc1967.getImplementationAddress(tradeProxy.address);
    console.log("Implementation :", impl);
  });

task("upgrade:Trade")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers, upgrades }) {
    console.log("--- start upgrading the Trade Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const tradeProxy: MMTrade__factory = <MMTrade__factory>await ethers.getContractFactory("MMTrade", accounts[index]);

    const proxyTradeAddress = readContractAddress("MMtrade");

    const upgraded = await upgrades.upgradeProxy(proxyTradeAddress, tradeProxy);

    console.log("Trade upgraded to: ", upgraded.address);

    const impl = await upgrades.erc1967.getImplementationAddress(upgraded.address);
    console.log("Implementation :", impl);
  });

task("verify:Trade")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [],
    });
  });
