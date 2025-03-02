// aptosService.js

import { aptosClient } from "@/utils/aptosClient";
import { Aptos, AptosConfig } from "@aptos-labs/ts-sdk";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Network } from "aptos";

export const config = new AptosConfig({ network: "testnet" });
export const aptos = new Aptos(config);

const moduleAddress = "0xf57ffdaa57e13bc27ac9b46663749a5d03a846ada4007dfdf1483d482b48dace";
export async function initMarket(adminAccount, question, option1, option2, sharesPerOption) {
  const adminAddress = adminAccount;
  const payload = {
    type: "entry_function_payload",
    function: `${adminAddress}::message_board_addr::truthoracle::init_market`,
    type_arguments: [],
    arguments: [question, option1, option2, sharesPerOption],
  };

  const transaction = await aptosClient.generateTransaction(adminAddress, payload);
  const signedTransaction = await adminAccount.signTransaction(transaction);
  const response = await aptosClient.submitTransaction(signedTransaction);

  return response;
}

export async function getMarketCount() {
  try {
    const payload = {
      function: `${moduleAddress}::truthoracle::get_market_count`,
      functionArguments: [],
    };

    const marketCount = await aptos.view({ payload });
    return marketCount;
    console.log("marketCount: ", marketCount);
  } catch (e) {
    console.error(e);
  }
}

export async function getMarketMetadata(marketId) {
  try {
    const payload = {
      function: `${moduleAddress}::truthoracle::get_market_metadata`,
      functionArguments: [marketId],
    };

    const marketMetadata = await aptos.view({ payload });
    return marketMetadata;
  } catch (e) {
    console.error(e);
  }
}

export async function getUserMarketData(userAddress) {
  try {
    const payload = {
      function: `${moduleAddress}::truthoracle::get_user_market_data`,
      functionArguments: [userAddress],
    };

    const marketMetadata = await aptos.view({ payload });
    return marketMetadata;
  } catch (e) {
    console.error(e);
  }
}
