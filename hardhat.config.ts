import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import { config as dotenvConfig } from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";
import { resolve } from "path";

import "./tasks/accounts";
import "./tasks/deploy";
import "./tasks/interaction";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

// Ensure that we have all the environment variables we need.
const mnemonic: string | undefined = process.env.MNEMONIC;
if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey: string | undefined =
  process.env.DEPLOY_NETWORK === "polygon-mumbai" ? process.env.ALCHEMY_API_KEY : process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your INFURA_API_KEY in a .env file");
}

const chainIds = {
  "arbitrum-mainnet": 42161,
  avalanche: 43114,
  bsc: 56,
  goerli: 5,
  hardhat: 31337,
  mainnet: 1,
  "optimism-mainnet": 10,
  "polygon-mainnet": 137,
  "polygon-mumbai": 80001,
};

function getChainConfig(chain: keyof typeof chainIds): NetworkUserConfig {
  let jsonRpcUrl: string = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  let privateKey = process.env.GOERLI_PRIVATE_KEY || "";

  switch (chain) {
    case "goerli":
      privateKey = process.env.GOERLI_PRIVATE_KEY || "";
      break;
    case "avalanche":
      jsonRpcUrl = "https://api.avax.network/ext/bc/C/rpc";
      break;
    case "bsc":
      jsonRpcUrl = "https://bsc-dataseed1.binance.org";
      break;
    case "polygon-mumbai":
      privateKey = process.env.MUMBAI_PRIVATE_KEY || "";
      jsonRpcUrl = "https://polygon-mumbai.g.alchemy.com/v2/" + infuraApiKey;
      break;
    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  }
  return {
    accounts: [privateKey],
    chainId: chainIds[chain],
    url: jsonRpcUrl,
  };
}

const network = process.env.TESTING === "true" ? "hardhat" : process.env.DEPLOY_NETWORK || "rinkeby";

const config: HardhatUserConfig = {
  defaultNetwork: network,
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      avalanche: process.env.SNOWTRACE_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic,
      },
      chainId: chainIds.hardhat,
    },
    // arbitrum: getChainConfig("arbitrum-mainnet"),
    // avalanche: getChainConfig("avalanche"),
    // bsc: getChainConfig("bsc"),
    goerli: getChainConfig("goerli"),
    // mainnet: getChainConfig("mainnet"),
    // optimism: getChainConfig("optimism-mainnet"),
    // "polygon-mainnet": getChainConfig("polygon-mainnet"),
    "polygon-mumbai": getChainConfig("polygon-mumbai"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.15",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/hardhat-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
};

export default config;
