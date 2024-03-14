import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { ModernMusuemMarketplace, ModernMusuemMarketplace__factory } from "../../types";
import { readContractAddress } from "../deploy/addresses/utils";
import mArguments from "../deploy/arguments/ModernMusuemMarketplace";

task("interaction:Marketplace-setTradeAddress").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const accounts: Signer[] = await ethers.getSigners();
  const marketplaceAddress = readContractAddress("ModernMusuemMarketplace");
  const tradeAddress = readContractAddress("MMtrade");

  const marketplaceFactory: ModernMusuemMarketplace__factory = <ModernMusuemMarketplace__factory>(
    await ethers.getContractFactory("ModernMusuemMarketplace", accounts[0])
  );

  const marketPlace: ModernMusuemMarketplace = <ModernMusuemMarketplace>(
    await marketplaceFactory.attach(marketplaceAddress)
  );

  try {
    const res = await marketPlace.setTradeAddress(tradeAddress);

    console.log(`marketPlace: setTradeAddress`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("Validator error", e);
  }
});

task("interaction:Marketplace-updateParam").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const accounts: Signer[] = await ethers.getSigners();
  const marketplaceAddress = readContractAddress("ModernMusuemMarketplace");

  const marketplaceFactory: ModernMusuemMarketplace__factory = <ModernMusuemMarketplace__factory>(
    await ethers.getContractFactory("ModernMusuemMarketplace", accounts[0])
  );

  const marketPlace: ModernMusuemMarketplace = <ModernMusuemMarketplace>(
    await marketplaceFactory.attach(marketplaceAddress)
  );

  try {
    const res = await marketPlace.updateParam(mArguments.VALIDATOR, mArguments.FEE_SPLIT, mArguments.WETH_ADDRESS);

    console.log(`marketPlace: setTradeAddress`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("Validator error", e);
  }
});
