import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MMToken } from "../../types";
import { MMToken__factory } from "../../types/factories/contracts/Tokens/MMToken__factory";
import { readContractAddress, writeContractAddress } from "./addresses/utils";

task("deploy:MMToken")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    console.log("--- start deploying the MMToken Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const mmTokenFactory: MMToken__factory = <MMToken__factory>(
      await ethers.getContractFactory("MMToken", accounts[index])
    );
    const mmToken: MMToken = <MMToken>await mmTokenFactory.deploy();

    await mmToken.deployed();

    writeContractAddress("mmToken", mmToken.address);
    console.log("MMToken deployed to: ", mmToken.address);
  });

task("verify:MMToken").setAction(async function (taskArguments: TaskArguments, { run }) {
  const address = readContractAddress("mmToken");
  await run("verify:verify", {
    address,
    constructorArguments: [],
  });
});
