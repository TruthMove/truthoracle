// aptosService.js

import { aptosClient } from "@/utils/aptosClient";
import { Aptos, AptosConfig } from "@aptos-labs/ts-sdk";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { Network } from "aptos";

export const config = new AptosConfig({ network: "mainnet" });
export const aptos = new Aptos(config);

const moduleAddress = "0x2a6c6b97583161fa7f130c062dd2216b882e35546a4b648f0e9769745397405e";

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

export async function getUserRewards(userAddress) {
    try {
        const payload = {
            function: `${moduleAddress}::incentives::get_user_rewards`,
            functionArguments: [userAddress],
        };

        const rewards = await aptos.view({ payload });
        return rewards;
    } catch (e) {
        console.error(e);
        return [0, 0];
    }
}

export async function claimRewards(account, marketId) {
    try {
        const payload = {
            type: "entry_function_payload",
            function: `${moduleAddress}::incentives::claim_rewards`,
            type_arguments: [],
            arguments: [marketId],
        };

        const transaction = await aptosClient.generateTransaction(account.address, payload);
        const signedTransaction = await account.signTransaction(transaction);
        const response = await aptosClient.submitTransaction(signedTransaction);

        return response;
    } catch (e) {
        console.error(e);
        throw e;
    }
}

export async function claimAllRewards(account) {
    try {
        const payload = {
            type: "entry_function_payload",
            function: `${moduleAddress}::incentives::claim_all_rewards`,
            type_arguments: [],
            arguments: [],
        };

        const transaction = await aptosClient.generateTransaction(account.address, payload);
        const signedTransaction = await account.signTransaction(transaction);
        const response = await aptosClient.submitTransaction(signedTransaction);

        return response;
    } catch (e) {
        console.error(e);
        throw e;
    }
}

export async function getClaimedMarkets(userAddress) {
    try {
        const payload = {
            function: `${moduleAddress}::incentives::get_claimed_markets`,
            functionArguments: [userAddress],
        };
        const claimedMarkets = await aptos.view({ payload });
        return claimedMarkets;
    } catch (e) {
        console.error(e);
        return [];
    }
}

export async function getPlatformUSDCBalance(accountAddress) {
    try {
        const payload = {
            function: `${moduleAddress}::usdc::get_balance`,
            functionArguments: [accountAddress],
        };
        const [balance] = await aptos.view({ payload });
        return parseInt(balance, 10);
    } catch (e) {
        console.error("Error fetching platform USDC balance:", e);
        return 0;
    }
}
