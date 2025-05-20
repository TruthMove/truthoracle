# Pyth Price Verification

A Move module for verifying Pyth Network price feeds on Aptos. This module provides a simple interface to fetch and validate price data from Pyth's oracle network.

## Quick Start

```move
use pyth::price_verification;

// Fetch and verify a price feed
let verified_price = price_verification::verify_price(price_feed_id, 120); // 120 seconds max age
let price = price_verification::get_verified_price(&verified_price);
```

## Features

- **Price Freshness**: Ensures price data is recent (default: 2 minutes)
- **Confidence Checks**: Validates price confidence levels
- **Custom Thresholds**: Configure max age and confidence requirements
- **Type Safety**: Strongly typed price data structures

## Usage

### Basic Price Verification

```move
// Verify price with default settings
let verified = price_verification::verify_price(price_feed_id, 120);
```

### Custom Confidence Threshold

```move
// Verify with custom confidence level
let verified = price_verification::verify_price_with_confidence(
    price_feed_id,
    120,  // max age in seconds
    200   // min confidence (2%)
);
```

### Accessing Price Data

```move
let price = price_verification::get_verified_price(&verified);
let confidence = price_verification::get_verified_confidence(&verified);
let timestamp = price_verification::get_verified_timestamp(&verified);
```

## Error Codes

- `EPRICE_TOO_OLD`: Price data exceeds maximum age
- `EPRICE_INVALID`: Invalid price data
- `ECONFIDENCE_TOO_LOW`: Price confidence below threshold

## Integration with Prediction Markets

This module is designed to work seamlessly with prediction markets. Example:

```move
// In your market creation function
let verified_price = price_verification::verify_price(price_feed_id, 120);
let price = price_verification::get_verified_price(&verified_price);

// Use price for market initialization
init_market(question, price, ...);
```

## Development

### Building

```bash
aptos move compile
```

### Testing

```bash
aptos move test
```
