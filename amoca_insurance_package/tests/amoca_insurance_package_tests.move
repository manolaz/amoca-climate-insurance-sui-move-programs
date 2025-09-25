#[test_only]
module amoca_insurance_package::amoca_insurance_package_tests;

use amoca_insurance_package::amoca_insurance_package::{Self, GlobalState, ClimatePolicy};
use sui::test_scenario::{Self as ts, next_tx, end};

const AUTHORITY: address = @0xa;
const OWNER: address = @0xb;

#[test]
fun test_policy_activation_and_payout_flow() {
    let mut scenario = ts::begin(AUTHORITY);

    // Initialize state
    next_tx(&mut scenario, AUTHORITY);
    {
        let ctx = ts::ctx(&mut scenario);
        let state = amoca_insurance_package::testing_new_state(AUTHORITY, ctx);
        ts::return_to_sender(&scenario, state);
    };

    // Create policy
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            300,
            300,
            1_000,
            150,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_sender(&scenario, state);
    };

    // Deposit premium
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 300, ctx);
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Check status
    next_tx(&mut scenario, OWNER);
    {
        let state = ts::take_from_sender<GlobalState>(&scenario);
        let policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        assert!(amoca_insurance_package::testing_policy_status(&policy) == 1, 0);
        assert!(amoca_insurance_package::testing_state_total_premiums(&state) == 300, 1);
        assert!(amoca_insurance_package::testing_state_risk_pool(&state) == 300, 2);
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Submit climate data
    next_tx(&mut scenario, AUTHORITY);
    {
        let state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::submit_climate_data(&state, &mut policy, 180, 10, 80, ctx);
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Evaluate trigger
    next_tx(&mut scenario, AUTHORITY);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::evaluate_climate_trigger(
            &mut state,
            &mut policy,
            180,
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
        assert!(amoca_insurance_package::testing_policy_pending_payout(&policy) == 300, 4);
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
        assert!(amoca_insurance_package::testing_state_total_payouts(&state) == 300, 8);
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
        ts::return_to_sender(&scenario, state);
    };

    // Create policy
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::create_climate_policy(
            &mut state,
            OWNER,
            300,
            200,
            1_000,
            150,
            0,
            24,
            12,
            ctx,
        );
        ts::return_to_sender(&scenario, state);
    };

    // Deposit premium
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 200, ctx);
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    // Try to deposit more
    next_tx(&mut scenario, OWNER);
    {
        let mut state = ts::take_from_sender<GlobalState>(&scenario);
        let mut policy = ts::take_from_sender<ClimatePolicy>(&scenario);
        let ctx = ts::ctx(&mut scenario);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 50, ctx); // This should fail
        ts::return_to_sender(&scenario, state);
        ts::return_to_sender(&scenario, policy);
    };

    end(scenario);
}
