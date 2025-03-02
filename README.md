# TruthOracle
TruthOracle is a cutting-edge decentralized prediction market platform built on the Aptos blockchain. Our mission is to provide a secure, transparent, and low-cost environment for users to create, participate in, and resolve prediction markets on a variety of topics, including politics, climate change, and sports.

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

## Our deployments
Testnet: [0x5b8a641ee62188ada65e594147d05d3dff597e6402d2359286512d71a1ffc491](https://explorer.aptoslabs.com/account/0x5b8a641ee62188ada65e594147d05d3dff597e6402d2359286512d71a1ffc491?network=testnet)

Front-end: [https://truth-oracle.vercel.app/](https://truth-oracle.vercel.app/)
