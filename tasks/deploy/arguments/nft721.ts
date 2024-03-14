import { readContractAddress } from "../addresses/utils";

const MARKETPLACE_ADDRESS = readContractAddress("ModernMusuemMarketplace");
const TOKENURIPREFIX = "https://gateway.pinata.cloud/ipfs/";
const CONTRACTURI = "https://ipfs.io/ipfs/";

const values = {
  MARKETPLACE_ADDRESS,
  TOKENURIPREFIX,
  CONTRACTURI,
};

export default values;
