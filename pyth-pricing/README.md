# Aptos-Pyth Oracle Integration

Using Pyth oracle prices in Aptos smart contracts.

## Project Structure

```
aptos-pyth-pricing/
├── move/                 # Core implementation
│   ├── staking/         # Oracle and commission contracts
│   │   ├── Move.toml
│   │   ├── sources/     # Contract source files
│   │   └── tests/       # Contract test files
│   ├── pyth/            # Pyth Network integration
│   │   ├── Move.toml
│   │   └── sources/     # Pyth interface implementations
│   └── test.sh          # Automated test script for all modules
├── .gitignore
├── LICENSE
└── README.md
```

## Core Components

1. **Pyth Integration (`move/pyth/`)**
   - Price feed data structures
   - Price feed ID handling
   - Core Pyth Network interface

2. **Staking Module (`move/staking/`)**
   - Price oracle implementation
   - Commission contract logic
   - Unit and integration tests


## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/aptos-pyth-pricing.git
   cd aptos-pyth-pricing
   ```

2. Install dependencies:
   ```bash
   # Install Aptos CLI
   brew install aptos
   
   # Verify installation
   aptos --version
   ```

3. Set up your development environment:
   ```bash
   # Generate a new key
   aptos key generate --output-file ~/.aptos/key.json
   
   # Create a profile for testnet
   aptos init --profile testnet --network testnet
   ```

4. Build and test:
   ```bash
   # Compile the modules
   aptos move compile --package-dir move/staking/
   aptos move compile --package-dir move/pyth/

   # Run tests (Option 1: Individual modules)
   aptos move test --package-dir move/staking/
   aptos move test --package-dir move/pyth/

   # Run tests (Option 2: All modules using test script)
   cd move && ./test.sh
   ```
