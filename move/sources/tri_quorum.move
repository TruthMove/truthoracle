module message_board_addr::tri_quorum{
  use aptos_std::table::{Self, Table};
  use aptos_framework::object::{Self, ExtendRef};
  use std::vector;
  use std::signer;
  use message_board_addr::truthoracle;

  // Constants
  const ONGOING: u8 = 0;
  const APPROVED: u8 = 1;
  const REJECTED: u8 = 2;
  // errors 
  const EINVALID_NO_SIGNERS: u64 = 0;
  const ESIGNER_UNAUTHORIZED: u64 = 1;
  const ENOT_VALID_OPTION: u64 = 2;
  const EMARKET_RESULT_INVALID: u64 = 3;
  const EDUPLICATE_SIGNATURE: u64 = 4;
  const EMARKET_RESULT_INVALID_STATE: u64 = 5;

  // structs
  #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
  struct ObjectController has key {
    extend_ref: ExtendRef
  }

  struct SignerData has key {
    signers: vector<address>,
    is_signer_whitelisted: Table<address, bool>,
    market_id_to_signer: Table<u64, address>
  }

  struct MarketResult has key {
    market_id: u64,
    result: u8,
    signers_signed: vector<address>, 
    is_signer_approved: Table<address, bool>,
    status: u8
  }

  #[view]
  public fun create_seed(market_id: u64, option: u8): u64 {
    let u64_max: u64 = 18446744073709551615;
    let seed = market_id + u64_max/5;
    if(option == 1){
      seed = seed + u64_max/5;
    };

    seed
  }

  #[view]
  public fun get_market_address(signer_address: address, market_id: u64, option: u8): address {
    let seed = create_seed(market_id, option);

    // Create seed from market_id
    object::create_object_address(&signer_address, u64_to_vec_u8(seed))
  }

  // Init Fn
  fun init_signers(admin: &signer, signers: vector<address>) {
    // Initialize is_signer_whitelisted table
    let is_signer_whitelisted = table::new<address, bool>();
    let i = 0;
    let len = vector::length(&signers);
    while (i < len) {
      let signer_address = *vector::borrow(&signers, i);
      table::add(&mut is_signer_whitelisted, signer_address, true);
      i = i + 1;
    };

    // Move SignerData struct to the object
    move_to(admin, SignerData {
      signers: signers,
      is_signer_whitelisted: is_signer_whitelisted,
      market_id_to_signer: table::new<u64, address>()
    });
  }

  public entry fun initiate_market_result(
    signer: &signer,
    market_id: u64,
    result: u8,
  ) acquires SignerData {
    // Check option provided
    assert!(result < 2, ENOT_VALID_OPTION);

    // signer address
    let signer_address = signer::address_of(signer);

    // Check if the user is whitelisted
    let signer_data = borrow_global_mut<SignerData>(@message_board_addr);
    assert!(table::contains(&signer_data.is_signer_whitelisted, signer_address), ESIGNER_UNAUTHORIZED);

    // The onject shouldn't already exist
    let object_address = get_market_address(signer_address, market_id, result);
    assert!(!object::object_exists<MarketResult>(object_address), EMARKET_RESULT_INVALID);

    // Creates a non-deletable object with counter as the seed
    let constructor_ref = object::create_named_object(signer, u64_to_vec_u8(create_seed(market_id, result)));

    // Create an extend ref for the object and move it to the object
    let object_signer = object::generate_signer(&constructor_ref);
    let extend_ref = object::generate_extend_ref(&constructor_ref);

    let is_signer_approved = table::new<address, bool>();
    table::add(&mut is_signer_approved, signer_address, true);

    let signers_signed = vector::empty<address>();
    vector::push_back(&mut signers_signed, signer_address);

    let status = ONGOING;

    // Move ExtendRef and MarketResult struct to the object
    move_to(&object_signer, ObjectController { extend_ref });
    move_to(&object_signer, MarketResult {
      market_id,
      result,
      signers_signed,
      is_signer_approved,
      status
    });
  }

  public entry fun sign_a_result(signer: &signer, market_id: u64, option: u8) acquires SignerData, MarketResult {
    // Check option provided
    assert!(option < 2, ENOT_VALID_OPTION);

    // signer address
    let signer_address = signer::address_of(signer);

    // Check if the user is whitelisted
    let signer_data = borrow_global<SignerData>(@message_board_addr);
    assert!(table::contains(&signer_data.is_signer_whitelisted, signer_address), ESIGNER_UNAUTHORIZED);

    let creator_address = table::borrow(&signer_data.market_id_to_signer, market_id);

    let object_address = get_market_address(*creator_address, market_id, option);
    assert!(object::object_exists<MarketResult>(object_address), EMARKET_RESULT_INVALID);

    let market_result = borrow_global_mut<MarketResult>(object_address);
    assert!(market_result.status == ONGOING, EMARKET_RESULT_INVALID_STATE);
    assert!(*table::borrow(&market_result.is_signer_approved, signer_address), EDUPLICATE_SIGNATURE);

    vector::push_back(&mut market_result.signers_signed, signer_address);
    table::add(&mut market_result.is_signer_approved, signer_address, true);

    if(vector::length<address>(&market_result.signers_signed) > 2){
      truthoracle::record_result(signer, market_id, option);
      market_result.status = APPROVED;
    }
  }

  // Internal Fn
  fun u64_to_vec_u8(value: u64): vector<u8> {
    let bytes = vector::empty<u8>();
    let i = 8;
    while (i > 0) {
      i = i - 1;
      vector::push_back(&mut bytes, (((value >> (i * 8)) & 0xFF) as u8));
    };

    // Remove leading zeros
    while (vector::length(&bytes) > 1 && *vector::borrow(&bytes, 0) == 0) {
      vector::remove(&mut bytes, 0);
    };

    bytes
  }
}
