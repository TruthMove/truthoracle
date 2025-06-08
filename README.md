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
aptos move run --function-id 0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d::usdc::mint --profile default --args address:0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d u64:50000000000
```

6. Initialize the truthoracle Module

To initialize the truthoracle module, run:
```sh
aptos move run --function-id 0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d::truthoracle::init_module --profile default
```

7. Initialize the incentives Module

To initialize the incentives module, run:
```sh
aptos move run \
  --function-id 0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d::incentives::initialize \
  --profile default
```

## Resolving a Market (Single-Admin Method)

To resolve a market directly as the admin, use the following command:

**Generic Command:**
```sh
aptos move run \
  --function-id 0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d::truthoracle::record_result \
  --profile <admin-profile> \
  --args u64:<market_id> u8:<result>
```
- Replace `<admin-profile>` with your Aptos CLI profile name (e.g., `default`).
- Replace `<market_id>` with the market ID you want to resolve.
- Replace `<result>` with the result value (e.g., `0` for option 1, `1` for option 2).

**Example Command:**
```sh
aptos move run \
  --function-id 0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d::truthoracle::record_result \
  --profile default \
  --args u64:5 u8:0
```
This resolves market ID 5 with result 0 (option 1) using the `default` profile.

## Our deployments

Mainnet: [0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d](https://explorer.aptoslabs.com/account/0x5a650d6c0cc0327b3379cb91a2b3fa858c66a272c770a7c784734bfc3cc2999d?network=mainnet)

Testnet: [0xf57ffdaa57e13bc27ac9b46663749a5d03a846ada4007dfdf1483d482b48dace](https://explorer.aptoslabs.com/account/0xf57ffdaa57e13bc27ac9b46663749a5d03a846ada4007dfdf1483d482b48dace?network=testnet)

Front-end: [https://truth-oracle.vercel.app/](https://truth-oracle.vercel.app/)
