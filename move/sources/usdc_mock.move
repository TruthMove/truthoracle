module message_board_addr::usdc{
  use aptos_framework::fungible_asset::{Self, TransferRef, Metadata, MintRef};
  use aptos_framework::object::{Self, Object};
  use aptos_framework::primary_fungible_store;
  #[test_only]
  use aptos_std::math64;
  #[test_only]
  use std::signer;
  use std::string::utf8;
  use std::option;

  // Errors
  const ENOT_ADMIN: u64 = 0;
  
  // Constants and structs
  const ASSET_NAME: vector<u8> = b"USD Coin";
  const ASSET_SYMBOL: vector<u8> = b"USDC";
  const DECIMALS: u8 = 8;
  const FAVICON: vector<u8> = b"https://res.cloudinary.com/sachinapi/image/upload/v1749376323/wht4tgvghfgm0ibcq1pa.ico";
  const PROJECT: vector<u8> = b"https://truth-oracle.vercel.app";

  // Structs
  #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
  struct ObjectController has key {
    mint_ref: MintRef,
    transfer_ref: TransferRef
  }

  // Init Fn
  fun init_module(admin: &signer) {
    // Creates a non-deletable object with a named address based on our ASSET_SYMBOL
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
    // Create the FA's Metadata with your name, symbol, icon, etc.
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(),
        utf8(ASSET_NAME), /* name */
        utf8(ASSET_SYMBOL), /* symbol */
        DECIMALS, /* decimals */
        utf8(FAVICON), /* icon */
        utf8(PROJECT), /* project */
    );

    let object_signer = object::generate_signer(constructor_ref);

    // Generate the MintRef for this object
    // Used by fungible_asset::mint() and fungible_asset::mint_to()
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

    move_to(&object_signer, ObjectController {
      mint_ref,
      transfer_ref
    });
  }

  // init fn for test
  #[test_only]
  public entry fun initialize_for_test(admin: &signer) {
    // Creates a non-deletable object with a named address based on our ASSET_SYMBOL
    let constructor_ref = &object::create_named_object(admin, ASSET_SYMBOL);
    // Create the FA's Metadata with your name, symbol, icon, etc.
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
      constructor_ref,
      option::none(),
      utf8(ASSET_NAME), /* name */
      utf8(ASSET_SYMBOL), /* symbol */
      DECIMALS, /* decimals */
      utf8(FAVICON), /* icon */
      utf8(PROJECT), /* project */
    );

    let object_signer = object::generate_signer(constructor_ref);

    // Generate the MintRef for this object
    // Used by fungible_asset::mint() and fungible_asset::mint_to()
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

    move_to(&object_signer, ObjectController {
      mint_ref,
      transfer_ref
    });
  }


  // View fns
  #[view]
  public fun get_metadata(): Object<Metadata> {
    let asset_address = object::create_object_address(&@message_board_addr, ASSET_SYMBOL);
    object::address_to_object<Metadata>(asset_address)
  }

  #[view]
  public fun get_balance(address: address): u64 {
    let metadata = get_metadata();
    primary_fungible_store::balance(address, metadata)
  }

  // Public Fns
  public entry fun mint(_admin: &signer, to: address, amount: u64) acquires ObjectController {
    // -> Admin auth removed for demo
    // let admin_address = signer::address_of(admin);
    // assert!(admin_address == @message_board_addr, ENOT_ADMIN);

    // Get mintref
    let object_controller = get_object_controller();

    // Get Primary Store of the destination user
    let metadata = get_metadata();
    let destination_primary_store = primary_fungible_store::ensure_primary_store_exists(to, metadata);

    // // Mint tokens for the given address
    fungible_asset::mint_to(&object_controller.mint_ref, destination_primary_store, amount);
  }

  public entry fun transfer(user: &signer, to: address, amount: u64) {
    // Get user metadata
    let metadata = get_metadata();
    
    // Transfer the amount 
    primary_fungible_store::transfer(user, metadata, to, amount);
  }

  // Internal Fns
  // Todo: check if auth is needed for internal fns
  inline fun get_object_controller(): &ObjectController acquires ObjectController{
    let asset_address = object::create_object_address(&@message_board_addr, ASSET_SYMBOL);
    borrow_global<ObjectController>(asset_address)
  }

  #[test(creator = @message_board_addr, user = @0xDEADBEEF)]
  fun test_mint(creator: &signer, user: &signer) acquires ObjectController{
    init_module(creator);

    // amounts
    let amount_1 = 10 * math64::pow(10, 8);
    let amount_2 = 25 * math64::pow(10, 8);

    let user_address = signer::address_of(user);
    mint(creator, user_address, amount_1);
    assert!(get_balance(user_address) == amount_1, 101);

    mint(creator, user_address, amount_2);
    assert!(get_balance(user_address) == amount_2 + amount_1, 102);
  }

  #[test(creator = @message_board_addr, user_1 = @0xDEAD, user_2 = @0xBEEF)]
  fun test_transfer(creator: &signer, user_1: &signer, user_2: &signer) acquires ObjectController{
    init_module(creator);

    // amounts
    let amount_1 = 99 * math64::pow(10, 7);
    let amount_2 = 25 * math64::pow(10, 7);

    let user_address_1 = signer::address_of(user_1);
    let user_address_2 = signer::address_of(user_2);
    mint(creator, user_address_1, amount_1);
    assert!(get_balance(user_address_1) == amount_1, 201);

    transfer(user_1, user_address_2, amount_2);
    assert!(get_balance(user_address_1) == amount_1 - amount_2, 202);
    assert!(get_balance(user_address_2) == amount_2, 203);
  }
}