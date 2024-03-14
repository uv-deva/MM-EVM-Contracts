import { readContractAddress } from "../addresses/utils";

const MARKETPLACE_ADDRESS = readContractAddress("ModernMusuemMarketplace");
const TOKENURIPREFIX = "https://gateway.pinata.cloud/ipfs/";
const CONTRACTURI = "https://ipfs.io/ipfs/";

const NAME = "ModernMuseum";
const SYMBOL = "MM";

const values = {
  NAME,
  SYMBOL,
  MARKETPLACE_ADDRESS,
  TOKENURIPREFIX,
  CONTRACTURI,
};

export default values;
