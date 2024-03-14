import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MMToken, MMToken__factory } from "../../types";
import { readContractAddress } from "../deploy/addresses/utils";

task("interaction:MMToken-init").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const accounts: Signer[] = await ethers.getSigners();
  const mmTokenAddress = readContractAddress("mmToken");

  const mmTokenFactory: MMToken__factory = <MMToken__factory>await ethers.getContractFactory("MMToken", accounts[0]);

  const mmToken: MMToken = <MMToken>await mmTokenFactory.attach(mmTokenAddress);

  try {
    const res = await mmToken.initialize();

    console.log(`MM Token: init`);
    console.log("tx hash: ", res.hash);
  } catch (e) {
    console.error("MM Token error", e);
  }
});

task("interaction:MMToken-transfer")
  .addParam("to", "Address to receive MM token")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const accounts: Signer[] = await ethers.getSigners();
    const mmTokenAddress = readContractAddress("mmToken");
    const { to } = taskArguments;
    const amount = ethers.utils.parseEther("180");

    const mmTokenFactory: MMToken__factory = <MMToken__factory>await ethers.getContractFactory("MMToken", accounts[0]);
    const mmToken: MMToken = <MMToken>await mmTokenFactory.attach(mmTokenAddress);

    try {
      const res = await mmToken.transfer(to, amount);
      console.log(`MM Token: send ${amount} to ${to} `);
      console.log("tx hash: ", res.hash);
    } catch (e) {
      console.error("MM Token error", e);
    }
  });
