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
    const EALREADY_CLAIMED: u64 = 3;

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
        total_rewards_distributed: u64
    }

    struct UserRewards has key {
        pending_rewards: u64,
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
        _creator: address
    ) acquires IncentiveData {
        let incentive_data = borrow_global_mut<IncentiveData>(@message_board_addr);
        
        // Only add if not already present
        if (!table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
            table::add(&mut incentive_data.market_to_creator_rewards, market_id, false);
        };
        
        // Track eligible markets for creator
        if (!table::contains(&incentive_data.user_to_eligible_markets, _creator)) {
            table::add(&mut incentive_data.user_to_eligible_markets, _creator, vector::empty());
        };
        let eligible_markets = table::borrow_mut(&mut incentive_data.user_to_eligible_markets, _creator);
        
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
                pending_rewards: 0,
                total_earned: 0
            });
        };
        let user_rewards = borrow_global_mut<UserRewards>(user_addr);
        let total_reward = 0u64;
        let reward_type: u8 = 255; // 0: early, 1: creator, 2: winning, 255: none

        // Check early participant reward
        if (table::contains(&incentive_data.market_to_early_participants, market_id)) {
            let early_participants = table::borrow(&incentive_data.market_to_early_participants, market_id);
            let i = 0;
            let len = vector::length(early_participants);
            while (i < len) {
                if (*vector::borrow(early_participants, i) == user_addr) {
                    total_reward = total_reward + EARLY_PARTICIPANT_REWARD;
                    reward_type = 0;
                    break;
                };
                i = i + 1;
            };
        };

        // Check market creator reward
        if (table::contains(&incentive_data.market_to_creator_rewards, market_id)) {
            let claimed = table::borrow(&incentive_data.market_to_creator_rewards, market_id);
            if (!*claimed && user_addr != @message_board_addr) { // Only allow non-admin creators
                total_reward = total_reward + MARKET_CREATOR_REWARD;
                reward_type = if (reward_type == 255) 1 else reward_type; // If not already set by early
                *table::borrow_mut(&mut incentive_data.market_to_creator_rewards, market_id) = true;
            }
        };

        // Check winning prediction reward
        if (table::contains(&incentive_data.user_to_eligible_markets, user_addr)) {
            let eligible_markets = table::borrow(&incentive_data.user_to_eligible_markets, user_addr);
            let i = 0;
            let len = vector::length(eligible_markets);
            while (i < len) {
                if (*vector::borrow(eligible_markets, i) == market_id) {
                    total_reward = total_reward + WINNING_PREDICTION_BONUS;
                    reward_type = if (reward_type == 255) 2 else reward_type; // If not already set by early/creator
                    break;
                };
                i = i + 1;
            };
        };

        // Transfer rewards if any
        if (total_reward > 0) {
            usdc::transfer(&object::generate_signer_for_extending(&borrow_global<ObjectController>(@message_board_addr).extend_ref), user_addr, total_reward);
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
            return;
        };
        let eligible_markets_ref = table::borrow(&incentive_data.user_to_eligible_markets, user_addr);
        let n = vector::length(eligible_markets_ref);
        let market_ids = vector::empty<u64>();
        let i = 0;
        while (i < n) {
            let market_id = *vector::borrow(eligible_markets_ref, i);
            vector::push_back(&mut market_ids, market_id);
            i = i + 1;
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

    // View functions
    #[view]
    public fun get_user_rewards(user: address): (u64, u64) acquires UserRewards {
        if (!exists<UserRewards>(user)) {
            return (0, 0)
        };
        let user_rewards = borrow_global<UserRewards>(user);
        (user_rewards.pending_rewards, user_rewards.total_earned)
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
} 