import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MarketplaceValidator, MarketplaceValidator__factory } from "../../types";
import { readContractAddress } from "../deploy/addresses/utils";

task("interaction:MarketplaceValidator-setMarketplaceAddress").setAction(async function (
  taskArguments: TaskArguments,
  { ethers },
) {
  const accounts: Signer[] = await ethers.getSigners();
  const validatorAddress = readContractAddress("marketplaceValidator");
  const marketplaceAddress = readContractAddress("ModernMusuemMarketplace");

  const validatorFactory: MarketplaceValidator__factory = <MarketplaceValidator__factory>(
    await ethers.getContractFactory("MarketplaceValidator", accounts[0])
  );

  const validator: MarketplaceValidator = <MarketplaceValidator>await validatorFactory.attach(validatorAddress);

  try {
    const res = await validator.setMarketplaceAddress(marketplaceAddress);

    console.log(`Validator: setMarketplaceAddress`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("Validator error", e);
  }
});

task("interaction:MarketplaceValidator-setNFT721Address").setAction(async function (
  taskArguments: TaskArguments,
  { ethers },
) {
  const accounts: Signer[] = await ethers.getSigners();
  const validatorAddress = readContractAddress("marketplaceValidator");
  const nft721Address = readContractAddress("nft721");

  const validatorFactory: MarketplaceValidator__factory = <MarketplaceValidator__factory>(
    await ethers.getContractFactory("MarketplaceValidator", accounts[0])
  );

  const validator: MarketplaceValidator = <MarketplaceValidator>await validatorFactory.attach(validatorAddress);

  try {
    const res = await validator.setNFT721Address(nft721Address);

    console.log(`Validator: setNFT721Address`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("Validator error", e);
  }
});

task("interaction:MarketplaceValidator-setNFT1155Address").setAction(async function (
  taskArguments: TaskArguments,
  { ethers },
) {
  const accounts: Signer[] = await ethers.getSigners();
  const validatorAddress = readContractAddress("marketplaceValidator");
  const nft1155Address = readContractAddress("nft1155");

  const validatorFactory: MarketplaceValidator__factory = <MarketplaceValidator__factory>(
    await ethers.getContractFactory("MarketplaceValidator", accounts[0])
  );

  const validator: MarketplaceValidator = <MarketplaceValidator>await validatorFactory.attach(validatorAddress);

  try {
    const res = await validator.setNFT1155Address(nft1155Address);

    console.log(`Validator: setNFT1155Address`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("Validator error", e);
  }
});

task("interaction:MarketplaceValidator-addPaymentToken").setAction(async function (
  taskArguments: TaskArguments,
  { ethers },
) {
  const accounts: Signer[] = await ethers.getSigners();
  const validatorAddress = readContractAddress("marketplaceValidator");
  const wethAddress = readContractAddress("weth");

  const validatorFactory: MarketplaceValidator__factory = <MarketplaceValidator__factory>(
    await ethers.getContractFactory("MarketplaceValidator", accounts[0])
  );

  const validator: MarketplaceValidator = <MarketplaceValidator>await validatorFactory.attach(validatorAddress);

  try {
    const res = await validator.addPaymentTokens(["0x0000000000000000000000000000000000000000", wethAddress]);

    console.log(`Validator: addPaymentTokens`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("Validator error", e);
  }
});
