module pyth::price_verification {
    use pyth::price::{Self, Price};
    use pyth::price_identifier::{Self, PriceIdentifier};
    use pyth::pyth;
    use std::option::{Self, Option};

    /// Error codes
    const EPRICE_TOO_OLD: u64 = 1;
    const EPRICE_INVALID: u64 = 2;
    const ECONFIDENCE_TOO_LOW: u64 = 3;

    /// Maximum allowed age for price data (in seconds)
    const MAX_PRICE_AGE: u64 = 120; // 2 minutes

    /// Minimum required confidence level (in basis points)
    const MIN_CONFIDENCE: u64 = 100; // 1%

    /// Structure to hold verified price data
    struct VerifiedPrice has copy, drop, store {
        price: u128,
        confidence: u64,
        timestamp: u64,
        price_feed_id: vector<u8>
    }

    /// Verify price data from Pyth
    public fun verify_price(
        price_feed_id: vector<u8>,
        max_age_secs: u64
    ): VerifiedPrice {
        let price_id = price_identifier::from_byte_vec(price_feed_id);
        let price_data = pyth::get_price_no_older_than(price_id, max_age_secs);
        
        // Get current timestamp
        let current_time = std::time::now_seconds();
        let price_timestamp = price::get_timestamp(&price_data);
        
        // Verify price is not too old
        assert!(current_time - price_timestamp <= max_age_secs, EPRICE_TOO_OLD);
        
        // Get price and confidence
        let price = price::get_price(&price_data);
        let confidence = price::get_conf(&price_data);
        
        // Verify confidence level
        assert!(confidence >= MIN_CONFIDENCE, ECONFIDENCE_TOO_LOW);
        
        // Convert price to u128 for easier handling
        let price_u128 = (price as u128);
        
        VerifiedPrice {
            price: price_u128,
            confidence,
            timestamp: price_timestamp,
            price_feed_id
        }
    }

    /// Get verified price with custom confidence threshold
    public fun verify_price_with_confidence(
        price_feed_id: vector<u8>,
        max_age_secs: u64,
        min_confidence: u64
    ): VerifiedPrice {
        let price_id = price_identifier::from_byte_vec(price_feed_id);
        let price_data = pyth::get_price_no_older_than(price_id, max_age_secs);
        
        let current_time = std::time::now_seconds();
        let price_timestamp = price::get_timestamp(&price_data);
        
        assert!(current_time - price_timestamp <= max_age_secs, EPRICE_TOO_OLD);
        
        let price = price::get_price(&price_data);
        let confidence = price::get_conf(&price_data);
        
        assert!(confidence >= min_confidence, ECONFIDENCE_TOO_LOW);
        
        let price_u128 = (price as u128);
        
        VerifiedPrice {
            price: price_u128,
            confidence,
            timestamp: price_timestamp,
            price_feed_id
        }
    }

    /// Get price from verified price data
    public fun get_verified_price(verified: &VerifiedPrice): u128 {
        verified.price
    }

    /// Get confidence from verified price data
    public fun get_verified_confidence(verified: &VerifiedPrice): u64 {
        verified.confidence
    }

    /// Get timestamp from verified price data
    public fun get_verified_timestamp(verified: &VerifiedPrice): u64 {
        verified.timestamp
    }

    /// Get price feed ID from verified price data
    public fun get_verified_price_feed_id(verified: &VerifiedPrice): vector<u8> {
        verified.price_feed_id
    }
} 