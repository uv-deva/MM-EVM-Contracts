import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MMNFT721, MMNFT721__factory } from "../../types";
import { writeContractAddress } from "./addresses/utils";
import mArguments from "./arguments/nft721";

task("deploy:MMNFT721")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    console.log("--- start deploying the MM NFT Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const nftFactory: MMNFT721__factory = <MMNFT721__factory>(
      await ethers.getContractFactory("MMNFT721", accounts[index])
    );

    const MMNFT721Proxy: MMNFT721 = <MMNFT721>(
      await nftFactory.deploy(mArguments.MARKETPLACE_ADDRESS, mArguments.CONTRACTURI, mArguments.TOKENURIPREFIX)
    );
    await MMNFT721Proxy.deployed();
    writeContractAddress("nft721", MMNFT721Proxy.address);
    console.log("MM NFT  deployed to: ", MMNFT721Proxy.address);
  });

task("verify:MMNFT721")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [mArguments.MARKETPLACE_ADDRESS, mArguments.CONTRACTURI, mArguments.TOKENURIPREFIX],
    });
  });
