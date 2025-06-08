import { aptosClient } from "@/utils/aptosClient";

export type AccountAPTBalanceArguments = {
  accountAddress: string;
};

export const getAccountAPTBalance = async (args: AccountAPTBalanceArguments): Promise<number> => {
  const { accountAddress } = args;
  try {
    console.log("Fetching balance for address:", accountAddress);

    type Coin = { coin: { value: string } };

    const resource = await aptosClient().getAccountResource<Coin>({
      accountAddress,
      resourceType: "0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>",
    });
    
    console.log({ resource });

    return Number(resource.coin.value);
  } catch (error) {
    console.error("Error fetching balance:", error);
    return 0;
  }
};

export const getPrimaryFungibleAssetBalance = async ({
  accountAddress,
  faMetadataAddress,
}: {
  accountAddress: string;
  faMetadataAddress: string;
}): Promise<number> => {
  try {
    const response = await aptosClient().view<[string]>({
      payload: {
        function: "0x1::primary_fungible_store::balance",
        typeArguments: ["0x1::object::ObjectCore"],
        functionArguments: [accountAddress, faMetadataAddress],
      },
    });
    console.log("Balance:", response);
    return parseInt(response[0], 10);
  } catch (error) {
    console.error("Error fetching primary fungible asset balance:", error);
    return 0;
  }
};
