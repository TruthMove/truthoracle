import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";

export const aptos = new Aptos(new AptosConfig({ network: Network.MAINNET }));

// Reuse same Aptos instance to utilize cookie based sticky routing
export function aptosClient() {
  return aptos;
}
