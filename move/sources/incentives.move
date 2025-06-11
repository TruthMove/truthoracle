module message_board_addr::incentives {
    use aptos_std::table::{Self, Table};
    use std::vector;
    use std::signer;
    use message_board_addr::usdc;
    use aptos_framework::object::{Self, ExtendRef};
    use aptos_framework::event;

    // Constants
    const EARLY_PARTICIPANT_THRESHOLD: u64 = 100000000; // 1 USDC in base units
    const EARLY_PARTICIPANT_REWARD: u64 = 5000000; // 0.05 USDC in base units
    const MARKET_CREATOR_REWARD: u64 = 10000000; // 0.1 USDC in base units
    const WINNING_PREDICTION_BONUS: u64 = 20000000; // 0.2 USDC in base units

    // Errors
    const ENOT_INITIALIZED: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;
    const EALREADY_CLAIMED: u64 = 7;
    const ENO_UNCLAIMED_CLOSED_MARKETS: u64 = 8;

    // Structs
    struct ObjectController has key {
        extend_ref: ExtendRef
    }

    struct IncentiveData has key {
        market_to_early_participants: Table<u64, vector<address>>,
        market_to_creator_rewards: Table<u64, bool>,
        user_to_claimed_rewards: Table<address, Table<u64, bool>>,
        user_to_eligible_markets: Table<address, vector<u64>>,
        user_to_claimed_market_ids: Table<address, vector<u64>>,
        market_to_winning_predictors: Table<u64, vector<address>>,
        market_to_creator: Table<u64, address>,
        closed_markets: vector<u64>,
        total_rewards_distributed: u64
    }

    struct UserRewards has key {
        total_earned: u64
    }

    // Events
    #[event]
    struct RewardClaimed has drop, store {
        user: address,
        amount: u64,
        market_id: u64,
        reward_type: u8 // 0: early participant, 1: creator, 2: winning prediction
    }

    // Initialize the incentives module
    public entry fun initialize(admin: &signer) {
        let constructor_ref = object::create_object(signer::address_of(admin));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        move_to(admin, ObjectController {
            extend_ref
        });
        move_to(admin, IncentiveData {
            market_to_early_participants: table::new(),
            market_to_creator_rewards: table::new(),
            user_to_claimed_rewards: table::new(),
            user_to_eligible_markets: table::new(),
            user_to_claimed_market_ids: table::new(),
            market_to_winning_predictors: table::new(),
            market_to_creator: table::new(),
            closed_markets: vector::empty(),
            total_rewards_distributed: 0
        });
    }

    // Record early participant
    public entry fun record_early_participant(
        market_id: u64,
        participant: address,
        amount: u64
    ) acquires IncentiveData {
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        if (amount >= EARLY_PARTICIPANT_THRESHOLD) {
            // Initialize early participants table if needed
            if (!table::contains(&incentive_data.market_to_early_participants, market_id)) {
                table::add(&mut incentive_data.market_to_early_participants, market_id, vector::empty());
            };
            let early_participants = table::borrow_mut(&mut incentive_data.market_to_early_participants, market_id);
            
            // Check for duplicate participant
            let i = 0;
            let len = vector::length(early_participants);
            while (i < len) {
                if (*vector::borrow(early_participants, i) == participant) {
                    return // Exit if already added
                };
                i = i + 1;
            };
            
            // Add participant if not found
            vector::push_back(early_participants, participant);

            // Track eligible markets for user
            if (!table::contains(&incentive_data.user_to_eligible_markets, participant)) {
                table::add(&mut incentive_data.user_to_eligible_markets, participant, vector::empty());
            };
            let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, participant);
            
            // Check for duplicate market
            let j = 0;
            let n = vector::length(eligible_markets);
            while (j < n) {
                if (*vector::borrow(eligible_markets, j) == market_id) {
                    return // Exit if already eligible
                };
                j = j + 1;
            };
            
            // Add market if not found
            vector::push_back(eligible_markets, market_id);
        };
    }

    // Record market creator reward
    public entry fun record_market_creator(
        market_id: u64,
        creator: address
    ) acquires IncentiveData {
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Only add if not already present
        if (!table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
            table::add(&mut incentive_data.market_to_creator_rewards, market_id, false);
        };
        
        // Record the market creator
        if (!table::contains(&incentive_data.market_to_creator, market_id)) {
            table::add(&mut incentive_data.market_to_creator, market_id, creator);
        };
        
        // Track eligible markets for creator
        if (!table::contains(&incentive_data.user_to_eligible_markets, creator)) {
            table::add(&mut incentive_data.user_to_eligible_markets, creator, vector::empty());
        };
        let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, creator);
        
        // Check for duplicate market
        let j = 0;
        let n = vector::length(eligible_markets);
        while (j < n) {
            if (*vector::borrow(eligible_markets, j) == market_id) {
                return // Exit if already eligible
            };
            j = j + 1;
        };
        
        // Add market if not found
        vector::push_back(eligible_markets, market_id);
    }

    // Record winning prediction
    public entry fun record_winning_prediction(
        market_id: u64,
        user: address
    ) acquires IncentiveData {
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Initialize winning predictors table for the market
        if (!table::contains(&incentive_data.market_to_winning_predictors, market_id)) {
            table::add(&mut incentive_data.market_to_winning_predictors, market_id, vector::empty());
        };
        
        // Add user to winning predictors if not already present
        let winning_predictors = table::borrow_mut(&mut incentive_data.market_to_winning_predictors, market_id);
        let j = 0;
        let n = vector::length(winning_predictors);
        while (j < n) {
            if (*vector::borrow(winning_predictors, j) == user) {
                return // Exit if already a winning predictor
            };
            j = j + 1;
        };
        
        // Add user to winning predictors
        vector::push_back(winning_predictors, user);
        
        // Track eligible markets for user
        if (!table::contains(&incentive_data.user_to_eligible_markets, user)) {
            table::add(&mut incentive_data.user_to_eligible_markets, user, vector::empty());
        };
        let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, user);
        
        // Check for duplicate market
        let j = 0;
        let n = vector::length(eligible_markets);
        while (j < n) {
            if (*vector::borrow(eligible_markets, j) == market_id) {
                return // Exit if already eligible
            };
            j = j + 1;
        };
        
        // Add market if not found
        vector::push_back(eligible_markets, market_id);
    }

    // Helper method to calculate pending rewards for a user and market
    fun calculate_pending_rewards(
        incentive_data: &IncentiveData,
        user: address,
        market_id: u64,
        claimed_markets: &vector<u64>
    ): u64 {
        let pending = 0u64;
        
        // Skip if market already claimed
        let claimed = false;
        let j = 0;
        let n = vector::length(claimed_markets);
        while (j < n) {
            if (*vector::borrow(claimed_markets, j) == market_id) {
                claimed = true;
                break;
            };
            j = j + 1;
        };
        if (claimed) {
            return pending;
        };
        
        // Check each type of reward
        // Early participant
        if (table::contains(&incentive_data.market_to_early_participants, market_id)) {
            let early_participants = table::borrow(&incentive_data.market_to_early_participants, market_id);
            let j = 0;
            let n = vector::length(early_participants);
            while (j < n) {
                if (*vector::borrow(early_participants, j) == user) {
                    pending = pending + EARLY_PARTICIPANT_REWARD;
                    break;
                };
                j = j + 1;
            };
        };
        
        // Market creator
        if (table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
            let claimed_creator = table::borrow(&incentive_data.market_to_creator_rewards, market_id);
            if (!*claimed_creator && user != @message_board_addr) {
                // Check if user is the market creator
                if (table::contains(&incentive_data.market_to_creator, market_id)) {
                    let creator = table::borrow(&incentive_data.market_to_creator, market_id);
                    if (*creator == user) {
                        pending = pending + MARKET_CREATOR_REWARD;
                    }
                }
            }
        };
        
        // Winning prediction - only add if user is a winning predictor
        if (table::contains(&incentive_data.market_to_winning_predictors, market_id)) {
            let winning_predictors = table::borrow(&incentive_data.market_to_winning_predictors, market_id);
            let j = 0;
            let n = vector::length(winning_predictors);
            while (j < n) {
                if (*vector::borrow(winning_predictors, j) == user) {
                    pending = pending + WINNING_PREDICTION_BONUS;
                    break;
                };
                j = j + 1;
            };
        };
        
        pending
    }

    // Calculate rewards on-the-fly
    #[view]
    public fun get_user_rewards(user: address): (u64, u64) acquires IncentiveData, UserRewards {
        let incentive_data = borrow_global<IncentiveData>(@message_board_addr);
        let pending = 0u64;
        let total_earned = if (exists<UserRewards>(user)) {
            borrow_global<UserRewards>(user).total_earned
        } else {
            0
        };
        
        // Get claimed markets for user
        let claimed_markets = if (table::contains(&incentive_data.user_to_claimed_market_ids, user)) {
            table::borrow(&incentive_data.user_to_claimed_market_ids, user)
        } else {
            &vector::empty<u64>()
        };
        
        // Check eligible markets
        if (table::contains(&incentive_data.user_to_eligible_markets, user)) {
            let eligible_markets = table::borrow(&incentive_data.user_to_eligible_markets, user);
            let i = 0;
            let len = vector::length(eligible_markets);
            while (i < len) {
                let market_id = *vector::borrow(eligible_markets, i);
                // Check if market is closed by looking at the closed_markets vector
                let is_closed = false;
                let closed_markets = &incentive_data.closed_markets;
                let j = 0;
                let closed_len = vector::length(closed_markets);
                while (j < closed_len) {
                    if (*vector::borrow(closed_markets, j) == market_id) {
                        is_closed = true;
                        break
                    };
                    j = j + 1;
                };
                // Only calculate rewards for closed markets
                if (is_closed) {
                    pending = pending + calculate_pending_rewards(incentive_data, user, market_id, claimed_markets);
                };
                i = i + 1;
            };
        };
        
        (pending, total_earned)
    }

    // Claim rewards for a market
    public entry fun claim_rewards(
        user: &signer,
        market_id: u64
    ) acquires IncentiveData, UserRewards, ObjectController {
        let user_addr = signer::address_of(user);
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Check if already claimed
        if (table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
            let claimed_markets = table::borrow(&incentive_data.user_to_claimed_market_ids, user_addr);
            let i = 0;
            let len = vector::length(claimed_markets);
            while (i < len) {
                if (*vector::borrow(claimed_markets, i) == market_id) {
                    abort EALREADY_CLAIMED
                };
                i = i + 1;
            };
        };

        // Initialize user rewards if not exists
        if (!exists<UserRewards>(user_addr)) {
            move_to(user, UserRewards {
                total_earned: 0
            });
        };
        let user_rewards = borrow_global_mut<UserRewards>(user_addr);

        // Get claimed markets for user
        let claimed_markets = if (table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
            table::borrow(&incentive_data.user_to_claimed_market_ids, user_addr)
        } else {
            &vector::empty<u64>()
        };

        // Calculate total reward using helper method
        let total_reward = calculate_pending_rewards(incentive_data, user_addr, market_id, claimed_markets);
        let reward_type: u8 = 255; // 0: early, 1: creator, 2: winning, 255: none

        // Determine reward type for event emission
        if (table::contains(&incentive_data.market_to_early_participants, market_id)) {
            let early_participants = table::borrow(&incentive_data.market_to_early_participants, market_id);
            let i = 0;
            let len = vector::length(early_participants);
            while (i < len) {
                if (*vector::borrow(early_participants, i) == user_addr) {
                    reward_type = 0;
                    break;
                };
                i = i + 1;
            };
        };

        if (table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
            let claimed_creator = table::borrow(&incentive_data.market_to_creator_rewards, market_id);
            if (!*claimed_creator && user_addr != @message_board_addr) {
                if (table::contains(&incentive_data.market_to_creator, market_id)) {
                    let creator = table::borrow(&incentive_data.market_to_creator, market_id);
                    if (*creator == user_addr) {
                        reward_type = if (reward_type == 255) 1 else reward_type;
                        *table::borrow_mut(&mut incentive_data.market_to_creator_rewards, market_id) = true;
                    }
                }
            }
        };

        if (table::contains(&incentive_data.market_to_winning_predictors, market_id)) {
            let winning_predictors = table::borrow(&incentive_data.market_to_winning_predictors, market_id);
            let i = 0;
            let len = vector::length(winning_predictors);
            while (i < len) {
                if (*vector::borrow(winning_predictors, i) == user_addr) {
                    reward_type = if (reward_type == 255) 2 else reward_type;
                    break;
                };
                i = i + 1;
            };
        };

        // Transfer rewards if any
        if (total_reward > 0) {
            // Get the admin signer for USDC transfers
            let admin_signer = &object::generate_signer_for_extending(&borrow_global<ObjectController>(@message_board_addr).extend_ref);
            usdc::mint(admin_signer, user_addr, total_reward);
            
            user_rewards.total_earned = user_rewards.total_earned + total_reward;
            incentive_data.total_rewards_distributed = incentive_data.total_rewards_distributed + total_reward;
            
            event::emit(RewardClaimed {
                user: user_addr,
                amount: total_reward,
                market_id,
                reward_type: reward_type
            });

            // Track claimed market after successful claim
            if (!table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
                table::add(&mut incentive_data.user_to_claimed_market_ids, user_addr, vector::empty());
            };
            let claimed_markets = table::borrow_mut(&mut incentive_data.user_to_claimed_market_ids, user_addr);
            vector::push_back(claimed_markets, market_id);
        };
    }

    // Claim all rewards for a user
    public entry fun claim_all_rewards(user: &signer) acquires IncentiveData, UserRewards, ObjectController {
        let user_addr = signer::address_of(user);
        let incentive_data = borrow_global<IncentiveData>(@message_board_addr);
        if (!table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
            abort ENO_UNCLAIMED_CLOSED_MARKETS
        };
        let eligible_markets_ref = table::borrow(&incentive_data.user_to_eligible_markets, user_addr);
        let n = vector::length(eligible_markets_ref);
        let market_ids = vector::empty<u64>();
        let i = 0;
        while (i < n) {
            let market_id = *vector::borrow(eligible_markets_ref, i);
            // Check if market is closed by looking at the closed_markets vector
            let is_closed = false;
            let closed_markets = &incentive_data.closed_markets;
            let j = 0;
            let closed_len = vector::length(closed_markets);
            while (j < closed_len) {
                if (*vector::borrow(closed_markets, j) == market_id) {
                    is_closed = true;
                    break
                };
                j = j + 1;
            };
            // Only add market if it's closed
            if (is_closed) {
                vector::push_back(&mut market_ids, market_id);
            };
            i = i + 1;
        };
        
        // Check if there are any markets to claim
        if (vector::is_empty(&market_ids)) {
            abort ENO_UNCLAIMED_CLOSED_MARKETS
        };
        
        // Now, no more outstanding references to incentive_data
        let m = vector::length(&market_ids);
        let j = 0;
        while (j < m) {
            let market_id = *vector::borrow(&market_ids, j);
            claim_rewards(user, market_id);
            j = j + 1;
        };
    }

    #[view]
    public fun get_total_rewards_distributed(): u64 acquires IncentiveData {
        borrow_global<IncentiveData>(@message_board_addr).total_rewards_distributed
    }

    // View claimed markets for a user
    #[view]
    public fun get_reward_markets(user: address): vector<u64> acquires IncentiveData {
        let incentive_data = borrow_global<IncentiveData>(@message_board_addr);
        if (!table::contains(&incentive_data.user_to_eligible_markets, user)) {
            return vector::empty<u64>();
        };
        *table::borrow(&incentive_data.user_to_eligible_markets, user)
    }

    // View claimed markets for a user
    #[view]
    public fun get_claimed_markets(user: address): vector<u64> acquires IncentiveData {
        let incentive_data = borrow_global<IncentiveData>(@message_board_addr);
        if (!table::contains(&incentive_data.user_to_claimed_market_ids, user)) {
            return vector::empty<u64>();
        };
        *table::borrow(&incentive_data.user_to_claimed_market_ids, user)
    }

    // Record that a market has been closed
    public entry fun record_market_closed(market_id: u64) acquires IncentiveData {
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        let closed_markets = &mut incentive_data.closed_markets;
        
        // Check if market is already in the list
        let i = 0;
        let len = vector::length(closed_markets);
        while (i < len) {
            if (*vector::borrow(closed_markets, i) == market_id) {
                return // Market already closed
            };
            i = i + 1;
        };
        
        // Add market to closed list
        vector::push_back(closed_markets, market_id);
    }

    // View function to check if a market is closed
    #[view]
    public fun is_market_closed(market_id: u64): bool acquires IncentiveData {
        let incentive_data = borrow_global<IncentiveData>(@message_board_addr);
        let closed_markets = &incentive_data.closed_markets;
        
        let i = 0;
        let len = vector::length(closed_markets);
        while (i < len) {
            if (*vector::borrow(closed_markets, i) == market_id) {
                return true
            };
            i = i + 1;
        };
        false
    }

    #[test_only]
    public fun setup_incentives_test_env(admin: &signer, user: &signer) acquires IncentiveData {
        // Initialize incentives and mint USDC to the object address
        initialize(admin);
        
        // Initialize USDC for testing
        usdc::initialize_for_test(admin);
        
        // Get the USDC object address
        let object_address = object::create_object_address(&@message_board_addr, b"USDC");
        
        // Mint 10000 USDC to the object address for rewards (increased from 1000)
        usdc::mint(admin, object_address, 1000000000000);
        
        // Mint 100 USDC to user for other operations
        usdc::mint(admin, signer::address_of(user), 10000000000);
        
        // Initialize UserRewards for the user
        if (!exists<UserRewards>(signer::address_of(user))) {
            move_to(user, UserRewards {
                total_earned: 0
            });
        };
        
        // Initialize user's claimed markets table
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        if (!table::contains(&incentive_data.user_to_claimed_market_ids, signer::address_of(user))) {
            table::add(&mut incentive_data.user_to_claimed_market_ids, signer::address_of(user), vector::empty());
        };
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_claim_early_participant_reward(admin: &signer, user: &signer) acquires IncentiveData, UserRewards, ObjectController {
        setup_incentives_test_env(admin, user);
        let market_id = 1;
        let user_addr = signer::address_of(user);
        
        // Initialize incentive data
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Initialize early participants table for the market
        if (!table::contains(&incentive_data.market_to_early_participants, market_id)) {
            table::add(&mut incentive_data.market_to_early_participants, market_id, vector::empty());
        };
        
        // Simulate early participant with amount >= EARLY_PARTICIPANT_THRESHOLD
        // This will also add the market to user's eligible markets
        record_early_participant(market_id, user_addr, EARLY_PARTICIPANT_THRESHOLD);

        // Mark market as closed
        record_market_closed(market_id);
        
        // User should have pending reward
        let (pending, _total_earned) = get_user_rewards(user_addr);
        assert!(pending == EARLY_PARTICIPANT_REWARD, 101);
        
        // Claim reward
        claim_rewards(user, market_id);
        let (pending2, total_earned2) = get_user_rewards(user_addr);
        assert!(pending2 == 0, 103);
        assert!(total_earned2 == EARLY_PARTICIPANT_REWARD, 104);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    #[expected_failure(abort_code = 7, location = message_board_addr::incentives)] // EADUPLICATE_REQUEST
    public fun test_double_claim_prevention(admin: &signer, user: &signer) acquires IncentiveData, UserRewards, ObjectController {
        setup_incentives_test_env(admin, user);
        let market_id = 2;
        record_early_participant(market_id, signer::address_of(user), 100000000);
        claim_rewards(user, market_id);
        // Second claim should abort
        claim_rewards(user, market_id);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_no_reward_if_not_eligible(admin: &signer, user: &signer) acquires IncentiveData, UserRewards, ObjectController {
        setup_incentives_test_env(admin, user);
        let market_id = 3;
        // User is not an early participant, creator, or winner
        let (pending, _total_earned) = get_user_rewards(signer::address_of(user));
        assert!(pending == 0, 301);
        // Claim should not transfer any reward
        claim_rewards(user, market_id);
        let (pending2, _total_earned2) = get_user_rewards(signer::address_of(user));
        assert!(pending2 == 0, 303);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_market_creator_reward(admin: &signer, user: &signer) acquires IncentiveData, UserRewards, ObjectController {
        setup_incentives_test_env(admin, user);
        let market_id = 4;
        let user_addr = signer::address_of(user);
        
        // Initialize incentive data
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Initialize market creator rewards table
        if (!table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
            table::add(&mut incentive_data.market_to_creator_rewards, market_id, false);
        };
        
        // Initialize eligible markets for user
        if (!table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
            table::add(&mut incentive_data.user_to_eligible_markets, user_addr, vector::empty());
        };
        
        // Add market to user's eligible markets
        let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, user_addr);
        vector::push_back(eligible_markets, market_id);
        
        // Record market creator
        record_market_creator(market_id, user_addr);

        // Mark market as closed
        record_market_closed(market_id);
        
        // Ensure the USDC vault is funded with enough USDC for the reward
        let vault_address = object::create_object_address(&@message_board_addr, b"USDC");
        usdc::mint(admin, vault_address, MARKET_CREATOR_REWARD);
        
        // User should have pending reward
        let (pending, _total_earned) = get_user_rewards(user_addr);
        assert!(pending == MARKET_CREATOR_REWARD, 401);
        
        // Claim reward
        claim_rewards(user, market_id);
        let (pending2, total_earned2) = get_user_rewards(user_addr);
        assert!(pending2 == 0, 402);
        assert!(total_earned2 == MARKET_CREATOR_REWARD, 403);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_winning_prediction_reward(admin: &signer, user: &signer) acquires IncentiveData, UserRewards, ObjectController {
        setup_incentives_test_env(admin, user);
        let market_id = 5;
        let user_addr = signer::address_of(user);
        
        // Initialize incentive data
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Initialize eligible markets for user
        if (!table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
            table::add(&mut incentive_data.user_to_eligible_markets, user_addr, vector::empty());
        };
        
        // Record winning prediction
        record_winning_prediction(market_id, user_addr);

        // Mark market as closed
        record_market_closed(market_id);
        
        // User should have pending reward
        let (pending, _total_earned) = get_user_rewards(user_addr);
        assert!(pending == WINNING_PREDICTION_BONUS, 501);
        
        // Claim reward
        claim_rewards(user, market_id);
        let (pending2, total_earned2) = get_user_rewards(user_addr);
        assert!(pending2 == 0, 502);
        assert!(total_earned2 == WINNING_PREDICTION_BONUS, 503);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_early_participant_reward_amount(admin: &signer, user: &signer) acquires IncentiveData, UserRewards {
        setup_incentives_test_env(admin, user);
        let market_id = 6;
        let user_addr = signer::address_of(user);
        
        // Initialize early participants table for the market
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.market_to_early_participants, market_id)) {
                table::add(&mut incentive_data.market_to_early_participants, market_id, vector::empty());
            };
        };
        
        // Record early participant with amount below threshold
        record_early_participant(market_id, user_addr, EARLY_PARTICIPANT_THRESHOLD - 1);
        
        // Should have no reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == 0, 601);
        assert!(total_earned == 0, 602);
        
        // Record early participant with amount at threshold
        record_early_participant(market_id, user_addr, EARLY_PARTICIPANT_THRESHOLD);

        // Mark market as closed
        record_market_closed(market_id);
        
        // Should have early participant reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == EARLY_PARTICIPANT_REWARD, 603);
        assert!(total_earned == 0, 604);
        
        // Mark reward as claimed
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
                table::add(&mut incentive_data.user_to_claimed_market_ids, user_addr, vector::empty());
            };
            let claimed_markets = table::borrow_mut(&mut incentive_data.user_to_claimed_market_ids, user_addr);
            vector::push_back(claimed_markets, market_id);
        };
        
        // Should have no pending reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == 0, 605);
        assert!(total_earned == 0, 606);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_market_creator_reward_amount(admin: &signer, user: &signer) acquires IncentiveData, UserRewards {
        setup_incentives_test_env(admin, user);
        let market_id = 7;
        let user_addr = signer::address_of(user);
        
        // Initialize market creator rewards table and eligible markets
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
                table::add(&mut incentive_data.market_to_creator_rewards, market_id, false);
            };
            
            if (!table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
                table::add(&mut incentive_data.user_to_eligible_markets, user_addr, vector::empty());
            };
            
            let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, user_addr);
            vector::push_back(eligible_markets, market_id);
        };
        
        // Record market creator
        record_market_creator(market_id, user_addr);

        // Mark market as closed
        record_market_closed(market_id);
        
        // Should have market creator reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == MARKET_CREATOR_REWARD, 701);
        assert!(total_earned == 0, 702);
        
        // Mark reward as claimed
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
                table::add(&mut incentive_data.user_to_claimed_market_ids, user_addr, vector::empty());
            };
            let claimed_markets = table::borrow_mut(&mut incentive_data.user_to_claimed_market_ids, user_addr);
            vector::push_back(claimed_markets, market_id);
        };
        
        // Should have no pending reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == 0, 703);
        assert!(total_earned == 0, 704);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_winning_prediction_reward_amount(admin: &signer, user: &signer) acquires IncentiveData, UserRewards {
        setup_incentives_test_env(admin, user);
        let market_id = 8;
        let user_addr = signer::address_of(user);
        
        // Initialize eligible markets for user
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
                table::add(&mut incentive_data.user_to_eligible_markets, user_addr, vector::empty());
            };
        };
        
        // Record winning prediction
        record_winning_prediction(market_id, user_addr);

        // Mark market as closed
        record_market_closed(market_id);
        
        // Should have winning prediction reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == WINNING_PREDICTION_BONUS, 801);
        assert!(total_earned == 0, 802);
        
        // Mark reward as claimed
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
                table::add(&mut incentive_data.user_to_claimed_market_ids, user_addr, vector::empty());
            };
            let claimed_markets = table::borrow_mut(&mut incentive_data.user_to_claimed_market_ids, user_addr);
            vector::push_back(claimed_markets, market_id);
        };
        
        // Should have no pending reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == 0, 803);
        assert!(total_earned == 0, 804);
    }

    #[test(admin = @message_board_addr, user = @0xBEEF)]
    public fun test_multiple_rewards_amount(admin: &signer, user: &signer) acquires IncentiveData, UserRewards {
        setup_incentives_test_env(admin, user);
        let market_id = 9;
        let user_addr = signer::address_of(user);
        
        // Initialize all required tables
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            
            // Initialize early participants table
            if (!table::contains(&incentive_data.market_to_early_participants, market_id)) {
                table::add(&mut incentive_data.market_to_early_participants, market_id, vector::empty());
            };
            
            // Initialize market creator rewards table
            if (!table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
                table::add(&mut incentive_data.market_to_creator_rewards, market_id, false);
            };
            
            // Initialize eligible markets for user
            if (!table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
                table::add(&mut incentive_data.user_to_eligible_markets, user_addr, vector::empty());
            };
            
            let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, user_addr);
            vector::push_back(eligible_markets, market_id);
        };
        
        // Record all types of rewards
        record_early_participant(market_id, user_addr, EARLY_PARTICIPANT_THRESHOLD);
        record_market_creator(market_id, user_addr);
        record_winning_prediction(market_id, user_addr);

        // Mark market as closed
        record_market_closed(market_id);
        
        // Should have all rewards combined
        let (pending, total_earned) = get_user_rewards(user_addr);
        let expected_total = EARLY_PARTICIPANT_REWARD + MARKET_CREATOR_REWARD + WINNING_PREDICTION_BONUS;
        assert!(pending == expected_total, 901);
        assert!(total_earned == 0, 902);
        
        // Mark reward as claimed
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            if (!table::contains(&incentive_data.user_to_claimed_market_ids, user_addr)) {
                table::add(&mut incentive_data.user_to_claimed_market_ids, user_addr, vector::empty());
            };
            let claimed_markets = table::borrow_mut(&mut incentive_data.user_to_claimed_market_ids, user_addr);
            vector::push_back(claimed_markets, market_id);
        };
        
        // Should have no pending reward
        let (pending, total_earned) = get_user_rewards(user_addr);
        assert!(pending == 0, 903);
        assert!(total_earned == 0, 904);
    }

    #[test(admin = @message_board_addr, user1 = @0xBEEF, user2 = @0xCAFE, user3 = @0xDEAD)]
    public fun test_multiple_markets_rewards(
        admin: &signer,
        user1: &signer,
        user2: &signer,
        user3: &signer
    ) acquires IncentiveData, UserRewards, ObjectController {
        // Setup test environment once for all users
        setup_incentives_test_env(admin, user1);
        
        // Initialize UserRewards for other users
        if (!exists<UserRewards>(signer::address_of(user2))) {
            move_to(user2, UserRewards {
                total_earned: 0
            });
        };
        if (!exists<UserRewards>(signer::address_of(user3))) {
            move_to(user3, UserRewards {
                total_earned: 0
            });
        };
        
        // Initialize claimed markets tables for other users
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        if (!table::contains(&incentive_data.user_to_claimed_market_ids, signer::address_of(user2))) {
            table::add(&mut incentive_data.user_to_claimed_market_ids, signer::address_of(user2), vector::empty());
        };
        if (!table::contains(&incentive_data.user_to_claimed_market_ids, signer::address_of(user3))) {
            table::add(&mut incentive_data.user_to_claimed_market_ids, signer::address_of(user3), vector::empty());
        };
        
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        let user3_addr = signer::address_of(user3);
        
        // First market
        let market1_id = 10;
        
        // Initialize first market
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            
            // Initialize early participants table
            if (!table::contains(&incentive_data.market_to_early_participants, market1_id)) {
                table::add(&mut incentive_data.market_to_early_participants, market1_id, vector::empty());
            };
            
            // Initialize market creator rewards table
            if (!table::contains(&incentive_data.market_to_creator_rewards, market1_id)) {
                table::add(&mut incentive_data.market_to_creator_rewards, market1_id, false);
            };
            
            // Initialize winning predictors table
            if (!table::contains(&incentive_data.market_to_winning_predictors, market1_id)) {
                table::add(&mut incentive_data.market_to_winning_predictors, market1_id, vector::empty());
            };
        };
        
        // Record market creator (user1)
        record_market_creator(market1_id, user1_addr);
        
        // Record early participants
        record_early_participant(market1_id, user1_addr, EARLY_PARTICIPANT_THRESHOLD);
        record_early_participant(market1_id, user2_addr, EARLY_PARTICIPANT_THRESHOLD);
        
        // Record winning predictions
        record_winning_prediction(market1_id, user1_addr);
        record_winning_prediction(market1_id, user2_addr);

        // Mark first market as closed
        record_market_closed(market1_id);
        
        // Claim rewards for first market
        claim_rewards(user1, market1_id);
        claim_rewards(user2, market1_id);
        
        // Verify rewards after first market
        let (pending1, total_earned1) = get_user_rewards(user1_addr);
        let (pending2, total_earned2) = get_user_rewards(user2_addr);
        
        // user1 should have earned: creator reward + early participant reward + winning prediction
        let expected_user1_total = MARKET_CREATOR_REWARD + EARLY_PARTICIPANT_REWARD + WINNING_PREDICTION_BONUS;
        assert!(pending1 == 0, 1001);
        assert!(total_earned1 == expected_user1_total, 1002);
        
        // user2 should have earned: early participant reward + winning prediction
        let expected_user2_total = EARLY_PARTICIPANT_REWARD + WINNING_PREDICTION_BONUS;
        assert!(pending2 == 0, 1003);
        assert!(total_earned2 == expected_user2_total, 1004);
        
        // Second market
        let market2_id = 11;
        
        // Initialize second market
        {
            let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
            
            // Initialize early participants table
            if (!table::contains(&incentive_data.market_to_early_participants, market2_id)) {
                table::add(&mut incentive_data.market_to_early_participants, market2_id, vector::empty());
            };
            
            // Initialize market creator rewards table
            if (!table::contains(&incentive_data.market_to_creator_rewards, market2_id)) {
                table::add(&mut incentive_data.market_to_creator_rewards, market2_id, false);
            };
            
            // Initialize winning predictors table
            if (!table::contains(&incentive_data.market_to_winning_predictors, market2_id)) {
                table::add(&mut incentive_data.market_to_winning_predictors, market2_id, vector::empty());
            };
            
            // Initialize eligible markets for user3
            if (!table::contains(&incentive_data.user_to_eligible_markets, user3_addr)) {
                table::add(&mut incentive_data.user_to_eligible_markets, user3_addr, vector::empty());
            };
            let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, user3_addr);
            vector::push_back(eligible_markets, market2_id);
        };
        
        // Record market creator (user2)
        record_market_creator(market2_id, user2_addr);
        
        // Record early participants
        record_early_participant(market2_id, user2_addr, EARLY_PARTICIPANT_THRESHOLD);
        record_early_participant(market2_id, user3_addr, EARLY_PARTICIPANT_THRESHOLD);
        
        // Record winning predictions
        record_winning_prediction(market2_id, user2_addr);
        record_winning_prediction(market2_id, user3_addr);

        // Mark second market as closed
        record_market_closed(market2_id);
        
        // Calculate expected rewards
        let expected_user2_pending = MARKET_CREATOR_REWARD + EARLY_PARTICIPANT_REWARD + WINNING_PREDICTION_BONUS;
        let expected_user3_pending = EARLY_PARTICIPANT_REWARD + WINNING_PREDICTION_BONUS;
        
        // Check pending rewards before claiming
        let (pending1, total_earned1) = get_user_rewards(user1_addr);
        let (pending2, total_earned2) = get_user_rewards(user2_addr);
        let (pending3, total_earned3) = get_user_rewards(user3_addr);
        
        // user1 should have no pending rewards (already claimed from first market)
        assert!(pending1 == 0, 1005);
        assert!(total_earned1 == expected_user1_total, 1006);
        
        // user2 should have pending rewards from second market
        assert!(pending2 == expected_user2_pending, 1007);
        assert!(total_earned2 == expected_user2_total, 1008);
        
        // user3 should have pending rewards from second market
        assert!(pending3 == expected_user3_pending, 1009);
        assert!(total_earned3 == 0, 1010);
        
        // Claim rewards for second market
        claim_rewards(user2, market2_id);
        claim_rewards(user3, market2_id);
        
        // Verify final rewards
        let (pending1, total_earned1) = get_user_rewards(user1_addr);
        let (pending2, total_earned2) = get_user_rewards(user2_addr);
        let (pending3, total_earned3) = get_user_rewards(user3_addr);
        
        // user1's rewards should be unchanged
        assert!(pending1 == 0, 1011);
        assert!(total_earned1 == expected_user1_total, 1012);
        
        // user2 should have earned rewards from both markets
        let expected_user2_final_total = expected_user2_total + expected_user2_pending;
        assert!(pending2 == 0, 1013);
        assert!(total_earned2 == expected_user2_final_total, 1014);
        
        // user3 should have earned rewards from second market
        assert!(pending3 == 0, 1015);
        assert!(total_earned3 == expected_user3_pending, 1016);
    }

    #[test(admin = @message_board_addr, user1 = @0x123)]
    fun test_two_markets_claim_rewards(
        admin: &signer,
        user1: &signer
    ) acquires IncentiveData, UserRewards, ObjectController {
        // Setup test environment
        setup_incentives_test_env(admin, user1);
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Create two markets
        let market1_id = 1;
        let market2_id = 2;
        
        // Initialize market creator rewards
        table::add(&mut incentive_data.market_to_creator_rewards, market1_id, false);
        table::add(&mut incentive_data.market_to_creator_rewards, market2_id, false);
        
        // Initialize early participant rewards
        table::add(&mut incentive_data.market_to_early_participants, market1_id, vector::empty());
        table::add(&mut incentive_data.market_to_early_participants, market2_id, vector::empty());
        
        // Initialize winning predictors
        table::add(&mut incentive_data.market_to_winning_predictors, market1_id, vector::empty());
        table::add(&mut incentive_data.market_to_winning_predictors, market2_id, vector::empty());
        
        // Initialize eligible markets for user
        if (!table::contains(&incentive_data.user_to_eligible_markets, @0x123)) {
            table::add(&mut incentive_data.user_to_eligible_markets, @0x123, vector::empty());
        };
        let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, @0x123);
        vector::push_back(eligible_markets, market1_id);
        vector::push_back(eligible_markets, market2_id);
        
        // Record early participants for market1
        record_early_participant(market1_id, @0x123, EARLY_PARTICIPANT_THRESHOLD);
        
        // Record early participants for market2
        record_early_participant(market2_id, @0x123, EARLY_PARTICIPANT_THRESHOLD);
        
        // Record winning predictors for market1
        record_winning_prediction(market1_id, @0x123);
        
        // Record winning predictors for market2
        record_winning_prediction(market2_id, @0x123);
        
        // Record market creator for market1
        record_market_creator(market1_id, @0x123);
        
        // Record market creator for market2
        record_market_creator(market2_id, @0x123);
        
        // Ensure the USDC vault is funded with enough USDC for the rewards
        let vault_address = object::create_object_address(&@message_board_addr, b"USDC");
        usdc::mint(admin, vault_address, 1000000000); // Mint enough USDC for all rewards
        
        // Get initial rewards for market2
        let (_initial_total, _initial_pending) = get_user_rewards(@0x123);
        
        // Claim rewards for market1
        claim_rewards(user1, market1_id);
        
        // Get rewards for market2
        let (_total_earned, pending_rewards) = get_user_rewards(@0x123);
        
        // Calculate expected rewards for market2
        let expected_rewards = EARLY_PARTICIPANT_REWARD + WINNING_PREDICTION_BONUS + MARKET_CREATOR_REWARD;
        
        // Verify rewards for market2
        assert!(pending_rewards == expected_rewards, 1); // Early participant + winning predictor + market creator
    }
} 