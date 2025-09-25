module amoca_insurance_package::amoca_insurance_package;

use sui::tx_context::{Self, TxContext};

// ------------------------------------------------------------------------
// Error codes (aligned with README documentation)
// ------------------------------------------------------------------------
const E_INVALID_COVERAGE_AMOUNT: u64 = 6000;
const E_INVALID_POLICY_DURATION: u64 = 6001;
const E_INVALID_PREMIUM_AMOUNT: u64 = 6002;
const E_POLICY_ALREADY_ACTIVE: u64 = 6004;
const E_INSUFFICIENT_PREMIUM: u64 = 6005;
const E_ORACLE_NOT_AUTHORIZED: u64 = 6006;
const E_INVALID_ORACLE_DATA: u64 = 6007;
const E_STALE_ORACLE_DATA: u64 = 6008;
const E_LOW_CONFIDENCE_DATA: u64 = 6009;
const E_POLICY_NOT_ACTIVE: u64 = 6010;
const E_POLICY_EXPIRED: u64 = 6011;
const E_TRIGGER_NOT_MET: u64 = 6012;
const E_INVALID_PAYOUT_AMOUNT: u64 = 6013;
const E_UNAUTHORIZED: u64 = 6015;
const E_PROGRAM_PAUSED: u64 = 6016;

// ------------------------------------------------------------------------
// Policy lifecycle states
// ------------------------------------------------------------------------
const STATUS_PENDING: u8 = 0;
const STATUS_ACTIVE: u8 = 1;
const STATUS_TRIGGERED: u8 = 2;
const STATUS_SETTLED: u8 = 3;
const STATUS_EXPIRED: u8 = 4;

const MIN_CONFIDENCE: u8 = 50;

// ------------------------------------------------------------------------
// Core data structures
// ------------------------------------------------------------------------
public struct GlobalState has key, store {
    id: object::UID,
    authority: address,
    paused: bool,
    total_policies: u64,
    total_premiums_collected: u64,
    total_payouts_released: u64,
    risk_pool_balance: u64,
}

public struct ClimatePolicy has key, store {
    id: object::UID,
    owner: address,
    status: u8,
    coverage_amount: u64,
    premium_amount: u64,
    deposited_premium: u64,
    pending_payout: u64,
    trigger_rainfall: u64,
    trigger_temperature: u64,
    measurement_period: u64,
    minimum_duration: u64,
    end_timestamp: u64,
    last_data_timestamp: u64,
    last_data_value: u64,
    last_data_confidence: u8,
}

// ------------------------------------------------------------------------
// Initialization and administration
// ------------------------------------------------------------------------
public fun initialize(authority: address, ctx: &mut tx_context::TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(sender == authority, E_UNAUTHORIZED);

    let state = GlobalState {
        id: object::new(ctx),
        authority,
        paused: false,
        total_policies: 0,
        total_premiums_collected: 0,
        total_payouts_released: 0,
        risk_pool_balance: 0,
    };

    sui::transfer::transfer(state, authority);
}

public fun pause_program(state: &mut GlobalState, ctx: &mut tx_context::TxContext) {
    assert_authority(state, tx_context::sender(ctx));
    state.paused = true;
}

public fun unpause_program(state: &mut GlobalState, ctx: &mut tx_context::TxContext) {
    assert_authority(state, tx_context::sender(ctx));
    state.paused = false;
}

// ------------------------------------------------------------------------
// Policy lifecycle helpers
// ------------------------------------------------------------------------
public fun create_climate_policy(
    state: &mut GlobalState,
    owner: address,
    coverage_amount: u64,
    premium_amount: u64,
    end_timestamp: u64,
    trigger_rainfall: u64,
    trigger_temperature: u64,
    measurement_period: u64,
    minimum_duration: u64,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);

    let sender = tx_context::sender(ctx);
    assert!(sender == owner, E_UNAUTHORIZED);
    assert!(coverage_amount > 0, E_INVALID_COVERAGE_AMOUNT);
    assert!(premium_amount > 0, E_INVALID_PREMIUM_AMOUNT);
    assert!(end_timestamp > 0, E_INVALID_POLICY_DURATION);

    let policy = ClimatePolicy {
        id: object::new(ctx),
        owner,
        status: STATUS_PENDING,
        coverage_amount,
        premium_amount,
        deposited_premium: 0,
        pending_payout: 0,
        trigger_rainfall,
        trigger_temperature,
        measurement_period,
        minimum_duration,
        end_timestamp,
        last_data_timestamp: 0,
        last_data_value: 0,
        last_data_confidence: 0,
    };

    state.total_policies = state.total_policies + 1;
    sui::transfer::transfer(policy, owner);
}

public fun deposit_premium(
    state: &mut GlobalState,
    policy: &mut ClimatePolicy,
    amount: u64,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);
    assert_owner(policy, tx_context::sender(ctx));
    assert!(amount > 0, E_INVALID_PREMIUM_AMOUNT);
    assert!(
        policy.status == STATUS_PENDING || policy.status == STATUS_ACTIVE,
        E_POLICY_ALREADY_ACTIVE,
    );

    let remaining = policy.premium_amount - policy.deposited_premium;
    assert!(amount <= remaining, E_INSUFFICIENT_PREMIUM);

    policy.deposited_premium = policy.deposited_premium + amount;
    state.total_premiums_collected = state.total_premiums_collected + amount;
    state.risk_pool_balance = state.risk_pool_balance + amount;

    if (policy.deposited_premium == policy.premium_amount) {
        policy.status = STATUS_ACTIVE;
    }
}

public fun submit_climate_data(
    state: &GlobalState,
    policy: &mut ClimatePolicy,
    value: u64,
    timestamp: u64,
    confidence: u8,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);
    assert!(tx_context::sender(ctx) == state.authority, E_ORACLE_NOT_AUTHORIZED);
    assert!(value > 0, E_INVALID_ORACLE_DATA);
    assert!(confidence <= 100, E_INVALID_ORACLE_DATA);
    assert!(confidence >= MIN_CONFIDENCE, E_LOW_CONFIDENCE_DATA);
    assert!(timestamp > policy.last_data_timestamp, E_STALE_ORACLE_DATA);

    policy.last_data_value = value;
    policy.last_data_timestamp = timestamp;
    policy.last_data_confidence = confidence;
}

public fun evaluate_climate_trigger(
    state: &mut GlobalState,
    policy: &mut ClimatePolicy,
    rainfall_value: u64,
    temperature_value: u64,
    measurement_duration: u64,
    timestamp: u64,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);
    assert_owner_or_authority(policy, state, tx_context::sender(ctx));
    assert!(policy.status == STATUS_ACTIVE, E_POLICY_NOT_ACTIVE);
    assert!(timestamp <= policy.end_timestamp, E_POLICY_EXPIRED);

    let rainfall_met = policy.trigger_rainfall > 0 && rainfall_value >= policy.trigger_rainfall;
    let temperature_met =
        policy.trigger_temperature > 0 && temperature_value >= policy.trigger_temperature;
    let duration_met =
        policy.minimum_duration == 0 || measurement_duration >= policy.minimum_duration;

    assert!(duration_met && (rainfall_met || temperature_met), E_TRIGGER_NOT_MET);
    assert!(state.risk_pool_balance >= policy.coverage_amount, E_INVALID_PAYOUT_AMOUNT);

    policy.status = STATUS_TRIGGERED;
    policy.pending_payout = policy.coverage_amount;
    policy.last_data_timestamp = timestamp;
    policy.last_data_value = rainfall_value;
    policy.last_data_confidence = 100;
}

public fun execute_climate_payout(
    state: &mut GlobalState,
    policy: &mut ClimatePolicy,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);
    assert_owner_or_authority(policy, state, tx_context::sender(ctx));
    assert!(policy.status == STATUS_TRIGGERED, E_TRIGGER_NOT_MET);

    let payout = policy.pending_payout;
    assert!(payout > 0, E_INVALID_PAYOUT_AMOUNT);
    assert!(state.risk_pool_balance >= payout, E_INVALID_PAYOUT_AMOUNT);

    state.risk_pool_balance = state.risk_pool_balance - payout;
    state.total_payouts_released = state.total_payouts_released + payout;

    policy.pending_payout = 0;
    policy.status = STATUS_SETTLED;
}

public fun expire_policy(
    state: &GlobalState,
    policy: &mut ClimatePolicy,
    timestamp: u64,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);
    assert_owner_or_authority(policy, state, tx_context::sender(ctx));
    assert!(timestamp >= policy.end_timestamp, E_POLICY_EXPIRED);

    if (policy.status == STATUS_ACTIVE || policy.status == STATUS_PENDING) {
        policy.status = STATUS_EXPIRED;
    }
}

// ------------------------------------------------------------------------
// Internal helpers
// ------------------------------------------------------------------------
fun assert_not_paused(state: &GlobalState) {
    assert!(!state.paused, E_PROGRAM_PAUSED);
}

fun assert_authority(state: &GlobalState, sender: address) {
    assert!(state.authority == sender, E_UNAUTHORIZED);
}

fun assert_owner(policy: &ClimatePolicy, sender: address) {
    assert!(policy.owner == sender, E_UNAUTHORIZED);
}

fun assert_owner_or_authority(policy: &ClimatePolicy, state: &GlobalState, sender: address) {
    assert!(sender == policy.owner || sender == state.authority, E_UNAUTHORIZED);
}

#[test_only]
public fun testing_new_state(authority: address, ctx: &mut tx_context::TxContext): GlobalState {
    GlobalState {
        id: object::new(ctx),
        authority,
        paused: false,
        total_policies: 0,
        total_premiums_collected: 0,
        total_payouts_released: 0,
        risk_pool_balance: 0,
    }
}

#[test_only]
public fun testing_new_policy(
    owner: address,
    coverage_amount: u64,
    premium_amount: u64,
    end_timestamp: u64,
    trigger_rainfall: u64,
    trigger_temperature: u64,
    measurement_period: u64,
    minimum_duration: u64,
    ctx: &mut tx_context::TxContext,
): ClimatePolicy {
    ClimatePolicy {
        id: object::new(ctx),
        owner,
        status: STATUS_PENDING,
        coverage_amount,
        premium_amount,
        deposited_premium: 0,
        pending_payout: 0,
        trigger_rainfall,
        trigger_temperature,
        measurement_period,
        minimum_duration,
        end_timestamp,
        last_data_timestamp: 0,
        last_data_value: 0,
        last_data_confidence: 0,
    }
}

#[test_only]
public fun testing_policy_status(policy: &ClimatePolicy): u8 {
    policy.status
}

#[test_only]
public fun testing_policy_pending_payout(policy: &ClimatePolicy): u64 {
    policy.pending_payout
}

#[test_only]
public fun testing_state_total_premiums(state: &GlobalState): u64 {
    state.total_premiums_collected
}

#[test_only]
public fun testing_state_risk_pool(state: &GlobalState): u64 {
    state.risk_pool_balance
}

#[test_only]
public fun testing_state_total_payouts(state: &GlobalState): u64 {
    state.total_payouts_released
}
