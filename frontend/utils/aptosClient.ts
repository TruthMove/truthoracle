import { NETWORK } from "@/constants";
import { Aptos, AptosConfig } from "@aptos-labs/ts-sdk";

export const aptos = new Aptos(new AptosConfig({ network: NETWORK }));

// Reuse same Aptos instance to utilize cookie based sticky routing
export function aptosClient() {
 
    
// const fund =  aptos.getAccountInfo({ accountAddress: "0xbe78c3db211c44ff8ab479269bca429472b026751f983abfbb5b716ae12874cc"});

// console.log("fund", fund)

  return aptos;
}
