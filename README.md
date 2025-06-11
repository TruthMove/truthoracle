# TruthOracle
TruthOracle is a cutting-edge decentralized prediction market platform built on the Aptos blockchain. Our mission is to provide a secure, transparent, and low-cost environment for users to create, participate in, and resolve prediction markets on a variety of topics, including politics, climate change, and sports.

The platform can be seen at - https://truth-oracle.vercel.app/

## Features
- Decentralized Market Creation: Easily create and participate in prediction markets without intermediaries.
- Low Transaction Fees: Enjoy minimal fees thanks to the efficiency of the Aptos blockchain.
- Automated Outcomes: Smart contracts handle the resolution of markets using reliable oracles.
- User-Friendly Interface: Designed for ease of use with an intuitive interface.
- Multi-Category Predictions: Engage in predictions across diverse categories.

## Tools & Technologies
- React: For building the user interface.
- Vite: A modern development tool for fast builds.
- shadcn/ui & Tailwind CSS: For stylish and responsive design.
- Aptos TS SDK: For interacting with the Aptos blockchain.
- Aptos Wallet Adapter: To handle wallet connections.
- Node-based Move Commands: For smart contract development and management.

## Getting Started
1. Install Dependencies

- `npm install`

2. Start the Development Server
- `npm run dev`
3. Deploy the Application

- `npm run deploy`

## Move Commands
1. Change directory to /move
```
cd move
```
2. Compile the code
```
aptos move compile
```
3. Run the tests
```
aptos move test
```
4. Create Account (if doesn't exist)
```
aptos init
```
Replace the address in files
4. Publish it on tesnet
```
aptos move publish
```

5. Mint Mock USDC

To mint 500 mock USDC (500 * 10^8 = 50000000000) to your address, run:
```sh
aptos move run --function-id 0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49::usdc::mint --profile default --args address:0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49 u64:100000000000
```

6. **Mint USDC to the object address**

   To mint USDC for contract rewards, you need the USDC object address. You can get this by calling the `get_metadata` view function from the USDC module:

   ```sh
   aptos move view --function-id 0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49::usdc::get_metadata
   ```

   The output will look like:
   ```json
   {
     "Result": [
       { "inner": "0x70a4e7793f9d3e7cc45363c9b4682c118bd40b04f4899363f5221ba2e4e91176" }
     ]
   }
   ```
   The value in the `"inner"` field is the object address you should mint USDC to.

   Now mint USDC to this address:
   ```sh
   aptos move run --function-id 0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49::usdc::mint --profile default --args address:<OBJECT_ADDRESS> u64:100000000000
   # Example:
   # aptos move run --function-id 0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49::usdc::mint --profile default --args address:0x70a4e7793f9d3e7cc45363c9b4682c118bd40b04f4899363f5221ba2e4e91176 u64:100000000000
   ```

## Resolving a Market (Single-Admin Method)

To resolve a market directly as the admin, use the following command:

**Generic Command:**
```sh
aptos move run \
  --function-id 0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49::truthoracle::record_result \
  --profile <admin-profile> \
  --args u64:<market_id> u8:<result>
```
- Replace `<admin-profile>` with your Aptos CLI profile name (e.g., `default`).
- Replace `<market_id>` with the market ID you want to resolve.
- Replace `<result>` with the result value (e.g., `0` for option 1, `1` for option 2).

**Example Command:**
```sh
aptos move run \
  --function-id 0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49::truthoracle::record_result \
  --profile default \
  --args u64:5 u8:0
```
This resolves market ID 5 with result 0 (option 1) using the `default` profile.

## Our deployments

Mainnet: [0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49](https://explorer.aptoslabs.com/account/0xbde9b5978954614b28adf8e8c71d919271ccad89a878d4d914249444a31f2b49?network=mainnet)

Testnet: [0xf57ffdaa57e13bc27ac9b46663749a5d03a846ada4007dfdf1483d482b48dace](https://explorer.aptoslabs.com/account/0xf57ffdaa57e13bc27ac9b46663749a5d03a846ada4007dfdf1483d482b48dace?network=testnet)

Front-end: [https://truth-oracle.vercel.app/](https://truth-oracle.vercel.app/)
