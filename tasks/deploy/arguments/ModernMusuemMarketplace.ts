import { readContractAddress } from "../addresses/utils";

const DEV_FUND_WALLET = "0x9D9546Df4a37b3B988D67e97b7f2B709faE25f67";
const VALIDATOR = readContractAddress("marketplaceValidator");
const FEE_SPLIT = [[DEV_FUND_WALLET, 200]];

const WETH_ADDRESS = readContractAddress("weth");

const values = {
  VALIDATOR,
  FEE_SPLIT,
  WETH_ADDRESS,
};

export default values;
