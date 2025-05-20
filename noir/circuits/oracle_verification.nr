use dep::std;

// Input structure for the oracle verification circuit
struct OracleInputs {
    price_feed_id: [u8; 32],
    price: u128,
    confidence: u64,
    timestamp: u64,
    merkle_root: [u8; 32],
    merkle_proof: [[u8; 32]; 32],
    merkle_index: u32
}

// Output structure
struct OracleOutputs {
    is_valid: bool
}

// Main circuit function
fn main(inputs: OracleInputs) -> OracleOutputs {
    // Check if timestamp is recent (within last 2 minutes)
    let current_time = std::time::now();
    let is_recent = current_time - inputs.timestamp <= 120;

    // Verify Merkle proof for price feed ID
    let is_valid_proof = verify_merkle_proof(
        inputs.price_feed_id,
        inputs.merkle_root,
        inputs.merkle_proof,
        inputs.merkle_index
    );

    // Combine all checks
    let is_valid = is_recent && is_valid_proof;

    OracleOutputs { is_valid }
}

// Helper function to verify Merkle proof
fn verify_merkle_proof(
    leaf: [u8; 32],
    root: [u8; 32],
    proof: [[u8; 32]; 32],
    index: u32
) -> bool {
    let mut current = leaf;
    let mut current_index = index;

    for i in 0..32 {
        if current_index & 1 == 1 {
            current = std::hash::sha256([proof[i], current].concat());
        } else {
            current = std::hash::sha256([current, proof[i]].concat());
        }
        current_index = current_index >> 1;
    }

    current == root
} 