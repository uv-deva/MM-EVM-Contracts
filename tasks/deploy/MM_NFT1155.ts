import { Signer } from "@ethersproject/abstract-signer";
import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MMNFT1155, MMNFT1155__factory } from "../../types";
import { writeContractAddress } from "./addresses/utils";
import mArguments from "./arguments/nft1155";

task("deploy:MMNFT1155")
  .addParam("signer", "Index of the signer in the metamask address list")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    console.log("--- start deploying the MM NFT Contract ---");
    const accounts: Signer[] = await ethers.getSigners();
    const index = Number(taskArguments.signer);

    // Use accounts[1] as the signer for the real roll
    const nftFactory: MMNFT1155__factory = <MMNFT1155__factory>(
      await ethers.getContractFactory("MMNFT1155", accounts[index])
    );

    const MMNFT1155Proxy: MMNFT1155 = <MMNFT1155>(
      await nftFactory.deploy( mArguments.NAME, mArguments.SYMBOL, mArguments.MARKETPLACE_ADDRESS, mArguments.CONTRACTURI, mArguments.TOKENURIPREFIX)
    );
    await MMNFT1155Proxy.deployed();
    writeContractAddress("nft1155", MMNFT1155Proxy.address);
    console.log("MM NFT  deployed to: ", MMNFT1155Proxy.address);
  });

task("verify:MMNFT1155")
  .addParam("contractAddress", "Input the deployed contract address")
  .setAction(async function (taskArguments: TaskArguments, { run }) {
    await run("verify:verify", {
      address: taskArguments.contractAddress,
      constructorArguments: [mArguments.NAME, mArguments.SYMBOL, mArguments.MARKETPLACE_ADDRESS, mArguments.CONTRACTURI, mArguments.TOKENURIPREFIX],
    });
  });
