module message_board_addr::truthoracle{
  use aptos_framework::timestamp;
  use aptos_std::math128::{log2_64};
  use aptos_std::math_fixed64::{exp, mul_div};
  use aptos_std::table::{Self, Table};
  use aptos_std::fixed_point64::{FixedPoint64, create_from_rational, get_raw_value, add, sub};
  use aptos_framework::object::{Self, ExtendRef};
  #[test_only]
  use std::vector;
  use std::signer;
  use std::option::{Self, Option};
  use std::event;
  use message_board_addr::usdc;
  use message_board_addr::incentives;

  // Constants
  // status 
  const IN_PROGRESS: u8 = 0;
  const FINISHED: u8 = 1;

  // result
  const OPTION1: u8 = 0;
  const OPTION2: u8 = 1;
  const DRAW: u8 = 2;

  // errors
  const ENOT_ADMIN: u64 = 0;
  const ENOT_INITIALIZED: u64 = 1;
  const ENOT_VALID_OPTION: u64 = 2;
  const ENOT_FINISHED: u64 = 3;
  const ENOT_IN_PROGRESS: u64 = 4;
  const ENO_USERDATA: u64 = 5;
  const ENO_MARKETDATA: u64 = 6;
  const EADUPLICATE_REQUEST: u64 = 7;
  const ENO_WINNING_SHARES: u64 = 8;
  const EINVALID_NO_SHARES: u64 = 9;
  const EINVALID_LIQUIDITY_PARAM: u64 = 9;

  // Structs
  #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
  struct ObjectController has key {
    extend_ref: ExtendRef
  }

  struct Status has copy, drop, store{
    value: u8
  }

  struct Result has copy, drop, store{
    value: u8
  }

  // market Related
  struct MarketCounter has key, copy, drop {
		value: u64,
	}

  // stores market to creator address
  struct MarketToCreator has key {
    market_to_creator: Table<u64, address>
  }

  struct PredictionMarketMetaData has key, copy, drop {
		id: u64,
		question: vector<u8>,
    image_url: vector<u8>,
    description: vector<u8>,
		option_1: vector<u8>,
		option_2: vector<u8>,
		created_at: u64,
		status: u8,
		result: Option<u8>,
    payout_per_share: Option<u64>,
	}

  struct LMSR has key, copy, drop {
		option_shares_1: u64,
    option_shares_2: u64,
    liquidity_param: u64,
	}

  // user shares
  struct UserData has key {
    market_to_data: Table<u64, UserMarketData>,
    market_to_participants: Table<u64, vector<address>>,
  }

  struct UserMarketData has store, copy, drop {
    option_shares_1: u64,
    option_shares_2: u64,
    amount_invested: u64,
    profit_made: u64
  }

  #[event]
  struct MarketCreated has drop, store {
    creator: address,
    object_address: address,
    counter: u64
  }
  
  // Init Fn
  fun init_module(admin: &signer) {
		let counter = MarketCounter { value: 0 };
    move_to(admin, counter);
    move_to(admin, MarketToCreator{
      market_to_creator: table::new<u64, address>()
    });
    // Initialize incentives module
    incentives::initialize(admin);
  }

  // View Fn
  #[view]
  public fun get_user_market_data(user_address: address): vector<UserMarketData> acquires UserData, MarketCounter{
    // Number of markets
    let market_count = get_market_count();

    // Get user data struct
    if(!exists<UserData>(user_address)){
      return vector::empty<UserMarketData>()
    };

    let user_data = borrow_global_mut<UserData>(user_address);

    let result = vector::empty<UserMarketData>();
    let iterator = 0;

    while(iterator < market_count) {
      if (table::contains(&user_data.market_to_data, iterator)) {
        let user_market_data = table::borrow(&mut user_data.market_to_data, iterator);
        vector::push_back(&mut result, *user_market_data);
      } else {
        vector::push_back(&mut result, UserMarketData{
          option_shares_1: 0,
          option_shares_2: 0,
          amount_invested: 0,
          profit_made: 0,
        });
      };
      iterator = iterator + 1;
    };

    result
  }

  #[view]
  public fun get_market_metadata(market_id: u64): (PredictionMarketMetaData, LMSR) acquires MarketCounter, PredictionMarketMetaData, LMSR, MarketToCreator {
    // Get counter and check if the market with the market_id is initialized
    let market_count = get_market_count();
    assert!(market_count > market_id, ENOT_INITIALIZED);

    let market_address = get_market_address(market_id);

    // Get the metadata
    (*borrow_global<PredictionMarketMetaData>(market_address), *borrow_global<LMSR>(market_address))
  }

  #[view]
  public fun get_market_address(market_id: u64): address acquires MarketToCreator {
    let market_to_creator = borrow_global<MarketToCreator>(@message_board_addr);
    let creator = table::borrow(&market_to_creator.market_to_creator, market_id);
    // Create seed from market_id
    object::create_object_address(creator, u64_to_vec_u8(market_id))
  }

  #[view]
  public fun get_market_count(): u64 acquires MarketCounter {
    // get market count
    borrow_global<MarketCounter>(@message_board_addr).value
  }

  // Public Fn
  public entry fun buy_shares(
    user: &signer,
    market_id: u64,
    option: u8,
    shares: u64,
  ) acquires MarketCounter, PredictionMarketMetaData, LMSR, UserData, MarketToCreator, ObjectController {
    // Check shares provided
    assert!(shares != 0, EINVALID_NO_SHARES);

    // Check option provided
    assert!(option < 2, ENOT_VALID_OPTION);

    // Get market data
    let (prediction_market_metadata, _lmsr) = get_market_metadata(market_id);
    
    // Market should be in progress
    assert!(prediction_market_metadata.status == IN_PROGRESS, ENOT_IN_PROGRESS);

    // Get object
    let market_address = get_market_address(market_id);

    // Get Price
    let price = update_shares(user, market_id, option, shares);
    usdc::transfer(user, market_address, price);    

    // Record early participant for incentives
    incentives::record_early_participant(market_id, signer::address_of(user), price);

    // Track participant in market
    if (!exists<UserData>(market_address)) {
        move_to(&object::generate_signer_for_extending(&borrow_global<ObjectController>(market_address).extend_ref), UserData {
            market_to_data: table::new(),
            market_to_participants: table::new(),
        });
    };
    let user_data = borrow_global_mut<UserData>(market_address);
    
    // Add user to participants list if not already present
    if (!table::contains(&user_data.market_to_participants, market_id)) {
        table::add(&mut user_data.market_to_participants, market_id, vector::empty());
    };
    let participants = table::borrow_mut(&mut user_data.market_to_participants, market_id);
    let user_addr = signer::address_of(user);
    
    // Check if user is already in participants list
    let i = 0;
    let len = vector::length(participants);
    while (i < len) {
        if (*vector::borrow(participants, i) == user_addr) {
            return // Exit if already added
        };
        i = i + 1;
    };
    
    // Add user to participants list
    vector::push_back(participants, user_addr);
  }

  public entry fun record_result(
    _admin: &signer,
    market_id: u64,
    result: u8
  ) acquires PredictionMarketMetaData, MarketCounter, LMSR, MarketToCreator, UserData {
    // -> Removed auth for demo

    // Check option provided
    assert!(result < 2, ENOT_VALID_OPTION);

    // Get metadata of the market
    let prediction_market_metadata = get_market_metadata_mut(market_id);
    let lsmr = get_lmsr(market_id);

    // Cannot set result for a market more than once
    assert!(prediction_market_metadata.status == IN_PROGRESS, ENOT_IN_PROGRESS);

    // Find the payout per share
    let vault_balance = usdc::get_balance(get_market_address(market_id));
    let no_of_shares = if (result == 0) lsmr.option_shares_1 else lsmr.option_shares_2;
    let payout_per_share = if (no_of_shares == 0) 0 else vault_balance/no_of_shares;

    // update the result
    prediction_market_metadata.status = FINISHED;
    prediction_market_metadata.result = option::some<u8>(result);
    prediction_market_metadata.payout_per_share = option::some<u64>(payout_per_share);

    // Record winning predictions for incentives
    let market_to_creator = borrow_global<MarketToCreator>(@message_board_addr);
    let _creator = table::borrow(&market_to_creator.market_to_creator, market_id);
    
    // Get market address
    let market_address = get_market_address(market_id);
    
    // Get all participants for this market
    if (exists<UserData>(market_address)) {
        let market_user_data = borrow_global<UserData>(market_address);
        if (table::contains(&market_user_data.market_to_participants, market_id)) {
            let participants = table::borrow(&market_user_data.market_to_participants, market_id);
            let i = 0;
            let len = vector::length(participants);
            
            while (i < len) {
                let user_addr = *vector::borrow(participants, i);
                // Check if user has data and winning shares
                if (exists<UserData>(user_addr)) {
                    let user_data = borrow_global<UserData>(user_addr);
                    if (table::contains(&user_data.market_to_data, market_id)) {
                        let user_market_data = table::borrow(&user_data.market_to_data, market_id);
                        // Check if user has shares in the winning option
                        let winning_shares = if (result == 0) user_market_data.option_shares_1 else user_market_data.option_shares_2;
                        if (winning_shares > 0) {
                            // Record winning prediction for incentives
                            incentives::record_winning_prediction(market_id, user_addr);
                        };
                    };
                };
                i = i + 1;
            }
        };
    };
  }

  public entry fun withdraw_payout(
    user: &signer,
    market_id: u64
  ) acquires PredictionMarketMetaData, MarketCounter, LMSR, UserData, ObjectController, MarketToCreator {
    let signer_address = signer::address_of(user);

    // Get market metadata
    let (prediction_market_metadata, _) = get_market_metadata(market_id);
    let market_address = get_market_address(market_id);

    // Market should be in finished state
    assert!(prediction_market_metadata.status == FINISHED, ENOT_FINISHED);

    // Get user data
    // User does not have userdata resource
    assert!(exists<UserData>(signer_address), ENO_USERDATA);
    let user_data = borrow_global_mut<UserData>(signer_address);

    // User has not invested in the market
    assert!(table::contains(&user_data.market_to_data, market_id), ENO_MARKETDATA);
    let user_market_data = table::borrow_mut(&mut user_data.market_to_data, market_id);

    let winning_shares = if (prediction_market_metadata.result == option::some<u8>(0)) user_market_data.option_shares_1 else user_market_data.option_shares_2;
    // User has no winning shares
    assert!(winning_shares != 0, ENO_WINNING_SHARES);

    // User already cashed out
    assert!(user_market_data.profit_made == 0, EADUPLICATE_REQUEST);

    // User's payout
    let profit_made = winning_shares * (*option::borrow(&prediction_market_metadata.payout_per_share));

    // Make the payment
    let extend_ref = &borrow_global<ObjectController>(market_address).extend_ref;
    let object_signer = object::generate_signer_for_extending(extend_ref);

    // Perform transfer
    usdc::transfer(&object_signer, signer_address, profit_made);    

    // Update user's data
    user_market_data.profit_made = profit_made;
  }

  public entry fun init_market(
    signer: &signer, 
    question: vector<u8>,
    image_url: vector<u8>,
    description: vector<u8>, 
    option_1: vector<u8>, 
    option_2: vector<u8>, 
    liquidity_param: u64,
  ) acquires MarketCounter, MarketToCreator {
    // -> Removed auth for demo 
    // let admin_address = signer::address_of(admin);
    // assert!(admin_address == @message_board_addr, ENOT_ADMIN);
    let signer_address = signer::address_of(signer);

    // liquidity param cannot be 0
    assert!(liquidity_param != 0, EINVALID_LIQUIDITY_PARAM);

    // Get the market counter
    let counter = &mut borrow_global_mut<MarketCounter>(@message_board_addr).value;

    // Creates a non-deletable object with counter as the seed
    let constructor_ref = &object::create_named_object(signer, u64_to_vec_u8(*counter));

    // Create an extend ref for the object and move it to the object
    let object_signer = object::generate_signer(constructor_ref);
    let extend_ref = object::generate_extend_ref(constructor_ref);

    // Move ExtendRef and LMSR struct to the object
    move_to(&object_signer, ObjectController { extend_ref });
    move_to(&object_signer, LMSR {option_shares_1: 0, option_shares_2: 0, liquidity_param: liquidity_param});
    move_to(&object_signer, PredictionMarketMetaData{
      id: *counter,
      question: question,
      image_url: image_url,
      description: description,
      option_1: option_1,
      option_2: option_2,
      created_at: timestamp::now_seconds(),
      status: IN_PROGRESS,
      result: option::none<u8>(),
      payout_per_share: option::none<u64>(),
    });
    let market_to_creator = &mut borrow_global_mut<MarketToCreator>(@message_board_addr).market_to_creator;
    table::add(market_to_creator, *counter, signer_address);

    let object_address = object::address_from_constructor_ref(constructor_ref);

    event::emit(MarketCreated {
      creator: signer_address,
      object_address: object_address,
      counter: *counter
    });

    // Increment the counter
    *counter = *counter + 1;

    // Record market creator for incentives
    incentives::record_market_creator(*counter - 1, signer_address);
  } 

  // Internal Fn
  fun u64_to_vec_u8(value: u64): vector<u8> {
    let bytes = vector::empty<u8>();
    let i = 8;
    while (i > 0) {
      i = i - 1;
      vector::push_back(&mut bytes, (((value >> (i * 8)) & 0xFF) as u8));
    };
    bytes
  }

  inline fun get_lmsr_mut(market_id: u64): &mut LMSR acquires LMSR, MarketCounter {
     // Get counter and check if the market with the market_id is initialized
      let market_count = get_market_count();
      assert!(market_count > market_id, ENOT_INITIALIZED);

      let market_address = get_market_address(market_id);

      // Get the metadata
      borrow_global_mut<LMSR>(market_address)
  }

  inline fun get_lmsr(market_id: u64): LMSR acquires LMSR, MarketCounter {
     // Get counter and check if the market with the market_id is initialized
      let market_count = get_market_count();
      assert!(market_count > market_id, ENOT_INITIALIZED);

      let market_address = get_market_address(market_id);

      // Get the metadata
      *borrow_global<LMSR>(market_address)
  }

  inline fun get_market_metadata_mut(market_id: u64): &mut PredictionMarketMetaData acquires PredictionMarketMetaData, MarketCounter {
     // Get counter and check if the market with the market_id is initialized
      let market_count = get_market_count();
      assert!(market_count > market_id, ENOT_INITIALIZED);

      let market_address = get_market_address(market_id);

      // Get the metadata
      borrow_global_mut<PredictionMarketMetaData>(market_address)
  }

  fun update_shares(user: &signer, market_id: u64, option: u8, shares: u64): u64 acquires MarketCounter, LMSR, UserData, MarketToCreator {
    // Get the current pricing
    let lmsr = get_lmsr_mut(market_id);
    let current_pricing = pricing_function((lmsr.option_shares_1 as u128), (lmsr.option_shares_2 as u128), (lmsr.liquidity_param as u128));

    // Update the shares
    if(option == 0){
      lmsr.option_shares_1 = lmsr.option_shares_1 + shares;
    } else {
      lmsr.option_shares_2 = lmsr.option_shares_2 + shares;
    };

    // Get the new pricing
    let new_pricing = pricing_function((lmsr.option_shares_1 as u128), (lmsr.option_shares_2 as u128), (lmsr.liquidity_param as u128));

    // Net price is the difference
    let net_diff = sub(new_pricing, current_pricing);

    let signer_address = signer::address_of(user);

    // Update user's resource
    if(!exists<UserData>(signer_address)) {
      move_to(user, UserData {
        market_to_data: table::new<u64, UserMarketData>(),
        market_to_participants: table::new(),
      });
    };

    let user_data = borrow_global_mut<UserData>(signer_address);
    let amount_invested = round_to_8_decimals(net_diff);

    if (table::contains(&user_data.market_to_data, market_id)) {
      let user_market_data = table::borrow_mut(&mut user_data.market_to_data, market_id);
      if (option == 0) {
        user_market_data.option_shares_1 = user_market_data.option_shares_1 + shares;
      } else {
        user_market_data.option_shares_2 = user_market_data.option_shares_2 + shares;
      };
      user_market_data.amount_invested = user_market_data.amount_invested + amount_invested;
    } else {
      let new_user_market_data = UserMarketData {
        option_shares_1: if (option == 0) shares else 0,
        option_shares_2: if (option == 0) 0 else shares,
        amount_invested: amount_invested,
        profit_made: 0,
      };
      table::add(&mut user_data.market_to_data, market_id, new_user_market_data);
    };

    amount_invested
  }

  fun pricing_function(q1: u128, q2: u128, b:u128): FixedPoint64{
    let b_fixed = create_from_rational(b, 1);
    let q1_fixed = create_from_rational(q1, 1);
    let q2_fixed = create_from_rational(q2, 1);
    let one = create_from_rational(1, 1);
  
    let exp_1 = exp(mul_div(q1_fixed, one, b_fixed));
    let exp_2 = exp(mul_div(q2_fixed, one, b_fixed));

    let sum = add(exp_1, exp_2);
    let ln_sum = ln(sum);

    let result = mul_div(b_fixed, ln_sum, one);
    result
  }

  fun round_to_8_decimals(x: FixedPoint64): u64{
    let eight_decimals = 100000000;
    let raw_value = get_raw_value(x);
    let scaled_part = (raw_value * eight_decimals) >> 64;
    if (scaled_part > 0) {
      (scaled_part as u64)
    } else {
      0
    }
  }

  fun ln(x: FixedPoint64):FixedPoint64 {
    let ln2 = create_from_rational(693147, 1000000);
    let one = create_from_rational(1, 1);
    let raw_value = get_raw_value(x);

    // fixed_point64::create_from_raw_value(result);
    let logx = sub(log2_64(raw_value), create_from_rational(64, 1));
    let lnx = mul_div(logx, ln2, one);
    lnx
  }

  #[test_only]
  fun setup_market(creator: &signer, user_1: &signer, user_2: &signer) acquires MarketCounter, MarketToCreator{
    usdc::initialize_for_test(creator);

    let question_1: vector<u8> = b"Who will win the US elections?";
    let image_url: vector<u8> = b"https://tinyurl.com/rickroll1232421";
    let description: vector<u8> = b"This market will resolve to `Yes` if Donald J. Trump wins the 2024 US Presidential Election";
    let option_1_1: vector<u8> = b"Donald J Trump";
    let option_2_1: vector<u8> = b"Kamala Harris";
    let liquidity_param_1 = 250;

    init_market(creator, question_1, image_url, description, option_1_1, option_2_1, liquidity_param_1);

    // Mint tokens for user accounts
    let amount = 10000000000;
    usdc::mint(creator, signer::address_of(user_1), amount);
    usdc::mint(creator, signer::address_of(user_2), amount);
  }   

  #[test_only]
  fun setup_env(framework: &signer, creator: &signer){
    // set up global time for testing purpose
    timestamp::set_time_has_started_for_testing(framework); 

    init_module(creator);
  }   

  #[test(framework = @0x1, creator = @message_board_addr, user_1 = @0xBEEF, user_2 = @0xDEAD)]
  fun test_creating_new_market(framework: &signer, creator: &signer, user_1: &signer) acquires MarketCounter, LMSR, PredictionMarketMetaData, MarketToCreator, UserData {
    setup_env(framework, creator);
    
    let question_1: vector<u8> = b"Who will win the US elections?";
    let image_url_1: vector<u8> = b"https://tinyurl.com/rickroll1232421";
    let description_1: vector<u8> = b"This market will resolve to `Yes` if Donald J. Trump wins the 2024 US Presidential Election.";
    let option_1_1: vector<u8> = b"Donald J Trump";
    let option_2_1: vector<u8> = b"Kamala Harris";
    let liquidity_param_1 = 250;

    // Before any markets
    let user_market_data = get_user_market_data(signer::address_of(user_1));
    assert!(vector::length(&user_market_data) == 0, 125);

    init_market(creator, question_1, image_url_1, description_1, option_1_1, option_2_1, liquidity_param_1);

    // After one market
    let user_market_data = get_user_market_data(signer::address_of(user_1));
    assert!(vector::length(&user_market_data) == 0, 126);

    // Creator address
    let creator_address = signer::address_of(creator);

    // Check if counter is updated
    let counter = borrow_global<MarketCounter>(creator_address);
    assert!(counter.value == 1, 101);

    // Get object address
    let market_address = get_market_address(0);

    // Check if LMSR object is created
    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 0, 102);
    assert!(lmsr.option_shares_2== 0, 103);
    assert!(lmsr.liquidity_param == liquidity_param_1, 104);

    let prediction_metadata = borrow_global<PredictionMarketMetaData>(market_address);
    assert!(prediction_metadata.id == 0, 105);
    assert!(prediction_metadata.question == question_1, 106);
    assert!(prediction_metadata.option_1 == option_1_1, 107);
    assert!(prediction_metadata.option_2 == option_2_1, 108);
    assert!(prediction_metadata.status == IN_PROGRESS, 109);
    assert!(prediction_metadata.result == option::none<u8>(), 110);
    assert!(prediction_metadata.image_url == image_url_1, 123);
    assert!(prediction_metadata.description == description_1, 124);

    //////////

    let question_2: vector<u8> = b"Will Osimhen join Chelsea in 24/25 season?";
    let image_url_2: vector<u8> = b"https://tinyurl.com/osimhent12ochelsea";
    let description_2: vector<u8> = b"This is a market on whether Victor Osimhen will sign for Chelsea F.C.";
    let option_1_2: vector<u8> = b"Yes";
    let option_2_2: vector<u8> = b"No";
    let liquidity_param_2 = 200;

    init_market(creator, question_2, image_url_2, description_2, option_1_2, option_2_2, liquidity_param_2);

    // After two markets
    let user_market_data = get_user_market_data(signer::address_of(user_1));
    assert!(vector::length(&user_market_data) == 0, 126);

    // Check if counter is updated
    let counter = borrow_global<MarketCounter>(creator_address);
    assert!(counter.value == 2, 111);

    // Get object address
    let market_address = get_market_address(1);

    // Check if LMSR object is created
    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 0, 112);
    assert!(lmsr.option_shares_2== 0, 113);
    assert!(lmsr.liquidity_param == liquidity_param_2, 114);

    let prediction_metadata = borrow_global<PredictionMarketMetaData>(market_address);
    assert!(prediction_metadata.id == 1, 115);
    assert!(prediction_metadata.question == question_2, 116);
    assert!(prediction_metadata.option_1 == option_1_2, 117);
    assert!(prediction_metadata.option_2 == option_2_2, 118);
    assert!(prediction_metadata.status == IN_PROGRESS, 119);
    assert!(prediction_metadata.result == option::none<u8>(), 120);
    assert!(prediction_metadata.image_url == image_url_2, 121);
    assert!(prediction_metadata.description == description_2, 122);
  }

  #[test(framework = @0x1, creator = @message_board_addr, user_1 = @0xBEEF, user_2 = @0xDEAD)]
  fun test_buying_shares(framework: &signer, creator: &signer, user_1: &signer, user_2: &signer) acquires MarketCounter, LMSR, UserData, PredictionMarketMetaData, ObjectController, MarketToCreator {
    setup_env(framework, creator);
    setup_market(creator, user_1, user_2);

    let market_id = 0;
    let option_1 = 0;
    let shares_1 = 5;
    let liquidity_param_1 = 250;

    // Get object address
    let market_address = get_market_address(0);

    // User 1
    let user_address = signer::address_of(user_1);

    let user_balance_before = usdc::get_balance(user_address);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 0, 201);
    assert!(lmsr.option_shares_2== 0, 202);
    assert!(lmsr.liquidity_param == liquidity_param_1, 203);

    let net_diff = sub(pricing_function(5, 0, 250), pricing_function(0, 0, 250));
    let amount_invested_1 = round_to_8_decimals(net_diff);

    // check buying shares
    buy_shares(user_1, market_id, option_1, shares_1);

    // After two markets
    let user_market_data = get_user_market_data(user_address);
    assert!(vector::length(&user_market_data) == 1, 280);
    let first_data = vector::borrow(&user_market_data, 0);
    assert!(first_data.option_shares_1 == 5, 281);
    assert!(first_data.option_shares_2 == 0, 282);
    assert!(first_data.amount_invested == amount_invested_1, 283);
    assert!(first_data.profit_made == 0, 284);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 5, 204);
    assert!(lmsr.option_shares_2== 0, 205);
    assert!(lmsr.liquidity_param == liquidity_param_1, 206);

    let user_balance_after = usdc::get_balance(user_address);

    // Check user data
    let user_data = borrow_global<UserData>(signer::address_of(user_1));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    assert!(user_market_data.option_shares_1 == 5, 207);
    assert!(user_market_data.option_shares_2 == 0, 208);
    assert!(user_market_data.profit_made == 0, 209);

    // Balance check
    assert!(user_market_data.amount_invested == amount_invested_1, 210);
    assert!(user_balance_after == user_balance_before - amount_invested_1, 211);

    // User 2 => 1st buy
    let user_address = signer::address_of(user_2);
    let shares_2 = 10;
    let option_2 = 1;

    let user_balance_before = usdc::get_balance(user_address);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 5, 212);
    assert!(lmsr.option_shares_2== 0, 213);
    assert!(lmsr.liquidity_param == liquidity_param_1, 214);

    let net_diff = sub(pricing_function(5, 10, 250), pricing_function(5, 0, 250));
    let amount_invested_2 = round_to_8_decimals(net_diff);

    // check buying shares
    buy_shares(user_2, market_id, option_2, shares_2);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 5, 216);
    assert!(lmsr.option_shares_2 == 10, 217);
    assert!(lmsr.liquidity_param == liquidity_param_1, 218);

    let user_balance_after = usdc::get_balance(user_address);

    // Check user data
    let user_data = borrow_global<UserData>(signer::address_of(user_2));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    assert!(user_market_data.option_shares_1 == 0, 219);
    assert!(user_market_data.option_shares_2 == 10, 220);
    assert!(user_market_data.profit_made == 0, 221);

    // Balance check
    assert!(user_market_data.amount_invested == amount_invested_2, 222);
    assert!(user_balance_after == user_balance_before - amount_invested_2, 223);

    // User 2 => 2nd buy
    let user_address = signer::address_of(user_2);
    let shares_3 = 26;
    let option_3 = 0;

    let user_balance_before = usdc::get_balance(user_address);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 5, 224);
    assert!(lmsr.option_shares_2== 10, 225);
    assert!(lmsr.liquidity_param == liquidity_param_1, 226);

    let net_diff = sub(pricing_function(31, 10, 250), pricing_function(5, 10, 250));
    let amount_invested_3 = round_to_8_decimals(net_diff);

    // check buying shares
    buy_shares(user_2, market_id, option_3, shares_3);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 31, 227);
    assert!(lmsr.option_shares_2 == 10, 228);
    assert!(lmsr.liquidity_param == liquidity_param_1, 229);

    let user_balance_after = usdc::get_balance(user_address);

    // Check user data
    let user_data = borrow_global<UserData>(signer::address_of(user_2));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    assert!(user_market_data.option_shares_1 == 26, 230);
    assert!(user_market_data.option_shares_2 == 10, 231);
    assert!(user_market_data.profit_made == 0, 232);

    // Balance check
    assert!(user_market_data.amount_invested == (amount_invested_3 + amount_invested_2), 235);
    assert!(user_balance_after == user_balance_before - amount_invested_3, 236);
    
    ///////////////////////
    // User 1 => 2nd buy //
    ///////////////////////
    let user_address = signer::address_of(user_1);
    let shares_4 = 37;
    let option_4 = 1;

    let user_balance_before = usdc::get_balance(user_address);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 31, 237);
    assert!(lmsr.option_shares_2== 10, 238);
    assert!(lmsr.liquidity_param == liquidity_param_1, 239);

    let net_diff = sub(pricing_function(31, 47, 250), pricing_function(31, 10, 250));
    let amount_invested_4 = round_to_8_decimals(net_diff);

    // check buying shares
    buy_shares(user_1, market_id, option_4, shares_4);

    let lmsr = borrow_global<LMSR>(market_address);
    assert!(lmsr.option_shares_1 == 31, 241);
    assert!(lmsr.option_shares_2 == 47, 242);
    assert!(lmsr.liquidity_param == liquidity_param_1, 243);

    let user_balance_after = usdc::get_balance(user_address);
    // Check user data
    let user_data = borrow_global<UserData>(signer::address_of(user_1));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    assert!(user_market_data.option_shares_1 == 5, 244);
    assert!(user_market_data.option_shares_2 == 37, 245);
    assert!(user_market_data.profit_made == 0, 246);

    // Balance check
    assert!(user_market_data.amount_invested == (amount_invested_4 + amount_invested_1), 247);
    assert!(user_balance_after == user_balance_before - amount_invested_4, 248);

    // Get market balance
    let market_address = get_market_address(market_id);
    let market_balance_before = usdc::get_balance(market_address);
    assert!(market_balance_before == amount_invested_1 + amount_invested_2 + amount_invested_3 + amount_invested_4, 249);
    
    ////////////////////
    // Set the result //
    ////////////////////
    record_result(creator, market_id, 0);

    // Get the LSMR data
    let lmsr = borrow_global<LMSR>(market_address);
    let payout_per_share = market_balance_before/lmsr.option_shares_1;

    // Check the Market Metadata
    let prediction_metadata = borrow_global<PredictionMarketMetaData>(market_address);
    assert!(prediction_metadata.status == FINISHED, 250);
    assert!(prediction_metadata.result == option::some<u8>(0), 250);
    assert!(prediction_metadata.payout_per_share == option::some<u64>(payout_per_share), 250);

    // cashin out -> user1
    let user_address = signer::address_of(user_1);

    // User balance before
    let user_balance_before = usdc::get_balance(user_address);

    // User's userdata
    let user_data = borrow_global<UserData>(signer::address_of(user_1));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    let no_of_winning_shares = user_market_data.option_shares_1;

    // cash out
    withdraw_payout(user_1, market_id);

    // User balance after
    let expected_earnings = no_of_winning_shares * payout_per_share;
    let user_balance_after = usdc::get_balance(user_address);

    // Check market balance
    let market_balance_after_1 = usdc::get_balance(market_address);

    assert!(user_balance_after == user_balance_before + expected_earnings, 251);
    assert!(market_balance_after_1 == market_balance_before - expected_earnings, 252);

    // Check user's data
    let user_data = borrow_global<UserData>(signer::address_of(user_1));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    assert!(user_market_data.profit_made == expected_earnings, 253);

    // cashin out -> user2
    let user_address = signer::address_of(user_2);

    // User balance before
    let user_balance_before = usdc::get_balance(user_address);

    // User's userdata
    let user_data = borrow_global<UserData>(signer::address_of(user_2));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    let no_of_winning_shares = user_market_data.option_shares_1;

    // cash out
    withdraw_payout(user_2, market_id);

    // User balance after
    let expected_earnings = no_of_winning_shares * payout_per_share;
    let user_balance_after = usdc::get_balance(user_address);

    // Check market balance
    let market_balance_after_2 = usdc::get_balance(market_address);

    assert!(user_balance_after == user_balance_before + expected_earnings, 254);
    assert!(market_balance_after_2 == market_balance_after_1 - expected_earnings, 255);

    // Check user's data
    let user_data = borrow_global<UserData>(signer::address_of(user_2));
    let user_market_data = table::borrow(&user_data.market_to_data, market_id);
    assert!(user_market_data.profit_made == expected_earnings, 256);
  } 

  #[test(framework = @0x1, creator = @message_board_addr, user_1 = @0xBEEF, user_2 = @0xDEAD)]
  fun test_market_lifecycle(framework: &signer, creator: &signer, user_1: &signer, user_2: &signer) acquires MarketCounter, LMSR, UserData, PredictionMarketMetaData, ObjectController, MarketToCreator {
    setup_env(framework, creator);
    setup_market(creator, user_1, user_2);

    // Create first market (this will be market_id 1 since setup_market created market_id 0)
    let question_1: vector<u8> = b"Will Bitcoin reach $100k in 2024?";
    let image_url_1: vector<u8> = b"https://example.com/bitcoin";
    let description_1: vector<u8> = b"Market on Bitcoin's price reaching $100k in 2024";
    let option_1_1: vector<u8> = b"Yes";
    let option_2_1: vector<u8> = b"No";
    let liquidity_param_1 = 250;

    init_market(creator, question_1, image_url_1, description_1, option_1_1, option_2_1, liquidity_param_1);

    // Verify first market creation
    let market_id_1 = 1; // Changed from 0 to 1
    let market_address_1 = get_market_address(market_id_1);
    let prediction_metadata_1 = borrow_global<PredictionMarketMetaData>(market_address_1);
    assert!(prediction_metadata_1.id == market_id_1, 301);
    assert!(prediction_metadata_1.status == IN_PROGRESS, 302);

    // Buy some shares in first market
    buy_shares(user_1, market_id_1, 0, 10); // Buy 10 shares of option 1
    buy_shares(user_2, market_id_1, 1, 15); // Buy 15 shares of option 2

    // Resolve first market
    record_result(creator, market_id_1, 0); // Option 1 wins

    // Verify first market resolution
    let prediction_metadata_1 = borrow_global<PredictionMarketMetaData>(market_address_1);
    assert!(prediction_metadata_1.status == FINISHED, 303);
    assert!(prediction_metadata_1.result == option::some<u8>(0), 304);

    // Create second market
    let question_2: vector<u8> = b"Will Ethereum reach $10k in 2024?";
    let image_url_2: vector<u8> = b"https://example.com/ethereum";
    let description_2: vector<u8> = b"Market on Ethereum's price reaching $10k in 2024";
    let option_1_2: vector<u8> = b"Yes";
    let option_2_2: vector<u8> = b"No";
    let liquidity_param_2 = 300;

    init_market(creator, question_2, image_url_2, description_2, option_1_2, option_2_2, liquidity_param_2);

    // Verify second market creation
    let market_id_2 = 2; // Changed from 1 to 2
    let market_address_2 = get_market_address(market_id_2);
    let prediction_metadata_2 = borrow_global<PredictionMarketMetaData>(market_address_2);
    assert!(prediction_metadata_2.id == market_id_2, 305);
    assert!(prediction_metadata_2.status == IN_PROGRESS, 306);
    assert!(prediction_metadata_2.question == question_2, 307);
    assert!(prediction_metadata_2.option_1 == option_1_2, 308);
    assert!(prediction_metadata_2.option_2 == option_2_2, 309);

    // Verify market counter
    let counter = borrow_global<MarketCounter>(@message_board_addr);
    assert!(counter.value == 3, 310); // Changed from 2 to 3

    // Verify both markets exist and have correct data
    let lmsr_1 = borrow_global<LMSR>(market_address_1);
    let lmsr_2 = borrow_global<LMSR>(market_address_2);
    assert!(lmsr_1.option_shares_1 == 10, 311);
    assert!(lmsr_1.option_shares_2 == 15, 312);
    assert!(lmsr_2.option_shares_1 == 0, 313);
    assert!(lmsr_2.option_shares_2 == 0, 314);
  }
}