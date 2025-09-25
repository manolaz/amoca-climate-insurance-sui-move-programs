#[test_only]
module amoca_insurance_package::amoca_insurance_package_tests;

use amoca_insurance_package::amoca_insurance_package::{Self, GlobalState, ClimatePolicy};
use sui::test_scenario::{Self as ts, next_tx, end};

const AUTHORITY: address = @0xa;
const OWNER: address = @0xb;
const OTHER_USER: address = @0xc;

// Test constants
const TEST_COVERAGE: u64 = 1000;
const TEST_PREMIUM: u64 = 100;
const TEST_DURATION: u64 = 86400; // 1 day
const TEST_RAINFALL_TRIGGER: u64 = 150;
const TEST_TEMPERATURE_TRIGGER: u64 = 35;

#[test]
fun test_policy_activation_and_payout_flow() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Create policy
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            TEST_COVERAGE,
            TEST_PREMIUM,
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    // Deposit premium
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, TEST_PREMIUM, ctx);
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Check status
    next_tx(&mut scenario, OWNER);
    {
        let state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        assert!(amoca_insurance_package::testing_policy_status(&policy) == 1, 0);
        assert!(amoca_insurance_package::testing_state_total_premiums(&state) == TEST_PREMIUM, 1);
        assert!(amoca_insurance_package::testing_state_risk_pool(&state) == TEST_PREMIUM, 2);
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Submit climate data
    next_tx(&mut scenario, AUTHORITY);
    {
        let state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let mut policy = ts::take_from_address<ClimatePolicy>(&scenario, OWNER);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::submit_climate_data(&state, &mut policy, 180, 10, 80, ctx);
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_address(OWNER, policy);
    };

    // Evaluate trigger
    next_tx(&mut scenario, AUTHORITY);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_address<ClimatePolicy>(&scenario, OWNER);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::evaluate_climate_trigger(
            &mut state,
            &mut policy,
            180, // Rainfall above trigger (150)
            0,
            12,
            20,
            ctx,
        );
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Check triggered
    next_tx(&mut scenario, AUTHORITY);
    {
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        assert!(amoca_insurance_package::testing_policy_status(&policy) == 2, 3);
        assert!(
            amoca_insurance_package::testing_policy_pending_payout(&policy) == TEST_COVERAGE,
            4,
        );
        ts::return_to_sender(&scenario, policy);
    };

    // Execute payout
    next_tx(&mut scenario, AUTHORITY);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::execute_climate_payout(&mut state, &mut policy, ctx);
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Check settled
    next_tx(&mut scenario, AUTHORITY);
    {
        let state = ts::take_from_sender<GlobalState>(&scenario);
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        assert!(amoca_insurance_package::testing_policy_status(&policy) == 3, 5);
        assert!(amoca_insurance_package::testing_policy_pending_payout(&policy) == 0, 6);
        assert!(amoca_insurance_package::testing_state_risk_pool(&state) == 0, 7);
        assert!(amoca_insurance_package::testing_state_total_payouts(&state) == TEST_COVERAGE, 8);
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    end(scenario);
}

#[test, expected_failure(abort_code = amoca_insurance_package::E_INSUFFICIENT_PREMIUM)]
fun test_deposit_premium_exceeds_requirement_fails() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Create policy
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            TEST_COVERAGE,
            200, // Premium less than coverage
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    // Deposit premium
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 200, ctx);
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Try to deposit more
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 50, ctx); // This should fail
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    end(scenario);
}

#[test, expected_failure(abort_code = amoca_insurance_package::E_UNAUTHORIZED)]
fun test_unauthorized_policy_creation_fails() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Try to create policy with wrong sender
    next_tx(&mut scenario, OTHER_USER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER, // Different from sender
            TEST_COVERAGE,
            TEST_PREMIUM,
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    end(scenario);
}

#[test, expected_failure(abort_code = amoca_insurance_package::E_INVALID_COVERAGE_AMOUNT)]
fun test_invalid_coverage_amount_fails() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Try to create policy with invalid coverage amount
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            50, // Below minimum
            TEST_PREMIUM,
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    end(scenario);
}

#[test, expected_failure(abort_code = amoca_insurance_package::E_PROGRAM_PAUSED)]
fun test_paused_program_blocks_operations() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize and pause
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let mut state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        amoca_insurance_package::pause_program(&mut state, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Try to create policy while paused
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            TEST_COVERAGE,
            TEST_PREMIUM,
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    end(scenario);
}

#[test]
fun test_partial_premium_deposit() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Create policy
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            TEST_COVERAGE,
            200, // Higher premium amount
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    // Deposit partial premium
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 100, ctx);
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Check still pending
    next_tx(&mut scenario, OWNER);
    {
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        assert!(amoca_insurance_package::testing_policy_status(&policy) == 0, 0); // Still pending
        ts::return_to_sender(&scenario, policy);
    };

    // Complete premium deposit
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 100, ctx);
        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Check now active
    next_tx(&mut scenario, OWNER);
    {
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        assert!(amoca_insurance_package::testing_policy_status(&policy) == 1, 1); // Now active
        ts::return_to_sender(&scenario, policy);
    };

    end(scenario);
}

#[test]
fun test_getter_functions() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        sui::transfer::public_transfer(state, AUTHORITY);
    };

    // Create policy
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            TEST_COVERAGE,
            TEST_PREMIUM,
            TEST_DURATION,
            TEST_RAINFALL_TRIGGER,
            TEST_TEMPERATURE_TRIGGER,
            24,
            12,
            ctx,
        );
        ts::return_to_address(AUTHORITY, state);
    };

    // Test getter functions
    next_tx(&mut scenario, OWNER);
    {
        let state = ts::take_from_address<GlobalState>(&scenario, AUTHORITY);
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);

        // Test policy getters
        assert!(amoca_insurance_package::get_policy_status(&policy) == 0, 0);
        assert!(amoca_insurance_package::get_policy_owner(&policy) == OWNER, 1);
        assert!(amoca_insurance_package::get_policy_coverage(&policy) == TEST_COVERAGE, 2);

        let (premium, deposited) = amoca_insurance_package::get_policy_premium_info(&policy);
        assert!(premium == TEST_PREMIUM, 3);
        assert!(deposited == 0, 4);

        let (trigger_rain, trigger_temp) = amoca_insurance_package::get_policy_triggers(&policy);
        assert!(trigger_rain == TEST_RAINFALL_TRIGGER, 5);
        assert!(trigger_temp == TEST_TEMPERATURE_TRIGGER, 6);

        // Test utility functions
        assert!(!amoca_insurance_package::is_policy_fully_funded(&policy), 7);
        assert!(amoca_insurance_package::calculate_remaining_premium(&policy) == TEST_PREMIUM, 8);

        ts::return_to_address(AUTHORITY, state);
        ts::return_to_sender(&scenario, policy);
    };

    end(scenario);
}
