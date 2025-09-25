module amoca_insurance_package::amoca_insurance_package;

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
const E_INVALID_TIMESTAMP: u64 = 6018;
const E_ZERO_ADDRESS: u64 = 6019;

// ------------------------------------------------------------------------
// Policy lifecycle states
// ------------------------------------------------------------------------
const STATUS_PENDING: u8 = 0;
const STATUS_ACTIVE: u8 = 1;
const STATUS_TRIGGERED: u8 = 2;
const STATUS_SETTLED: u8 = 3;
const STATUS_EXPIRED: u8 = 4;

const MIN_CONFIDENCE: u8 = 50;
const MAX_CONFIDENCE: u8 = 100;
const MIN_POLICY_DURATION: u64 = 3600; // 1 hour in seconds
const MAX_POLICY_DURATION: u64 = 31536000; // 1 year in seconds
const MIN_COVERAGE_AMOUNT: u64 = 100;
const MIN_PREMIUM_AMOUNT: u64 = 10;

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
    start_timestamp: u64,
    end_timestamp: u64,
    last_data_timestamp: u64,
    last_data_value: u64,
    last_data_confidence: u8,
    creation_timestamp: u64,
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
    policy_duration: u64,
    trigger_rainfall: u64,
    trigger_temperature: u64,
    measurement_period: u64,
    minimum_duration: u64,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);

    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);

    // Enhanced validation
    assert!(sender == owner, E_UNAUTHORIZED);
    assert!(owner != @0x0, E_ZERO_ADDRESS);
    assert!(coverage_amount >= MIN_COVERAGE_AMOUNT, E_INVALID_COVERAGE_AMOUNT);
    assert!(premium_amount >= MIN_PREMIUM_AMOUNT, E_INVALID_PREMIUM_AMOUNT);
    assert!(
        policy_duration >= MIN_POLICY_DURATION && policy_duration <= MAX_POLICY_DURATION,
        E_INVALID_POLICY_DURATION,
    );
    assert!(trigger_rainfall > 0 || trigger_temperature > 0, E_INVALID_ORACLE_DATA);
    assert!(measurement_period > 0, E_INVALID_POLICY_DURATION);

    let start_timestamp = current_time;
    let end_timestamp = start_timestamp + policy_duration;

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
        start_timestamp,
        end_timestamp,
        last_data_timestamp: 0,
        last_data_value: 0,
        last_data_confidence: 0,
        creation_timestamp: current_time,
    };

    state.total_policies = state.total_policies + 1;

    // Emit policy creation event
    let event = PolicyCreated {
        policy_id: object::uid_to_inner(&policy.id),
        owner,
        coverage_amount,
        premium_amount,
        end_timestamp,
    };
    sui::event::emit(event);

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

    let is_fully_funded = policy.deposited_premium == policy.premium_amount;
    if (is_fully_funded) {
        policy.status = STATUS_ACTIVE;
    };

    // Emit premium deposit event
    let event = PremiumDeposited {
        policy_id: object::uid_to_inner(&policy.id),
        amount,
        total_deposited: policy.deposited_premium,
        is_fully_funded,
    };
    sui::event::emit(event);
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
    assert!(policy.status == STATUS_ACTIVE, E_POLICY_NOT_ACTIVE);
    assert!(value > 0, E_INVALID_ORACLE_DATA);
    assert!(confidence <= MAX_CONFIDENCE, E_INVALID_ORACLE_DATA);
    assert!(confidence >= MIN_CONFIDENCE, E_LOW_CONFIDENCE_DATA);
    assert!(timestamp > policy.last_data_timestamp, E_STALE_ORACLE_DATA);
    assert!(
        timestamp >= policy.start_timestamp && timestamp <= policy.end_timestamp,
        E_INVALID_TIMESTAMP,
    );

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
    assert!(timestamp >= policy.start_timestamp, E_INVALID_TIMESTAMP);
    assert!(rainfall_value > 0 || temperature_value > 0, E_INVALID_ORACLE_DATA);

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
    // Store the triggering value (prioritize rainfall over temperature)
    policy.last_data_value = if (rainfall_met) rainfall_value else temperature_value;
    policy.last_data_confidence = MAX_CONFIDENCE;

    // Emit policy triggered event
    let event = PolicyTriggered {
        policy_id: object::uid_to_inner(&policy.id),
        trigger_value: policy.last_data_value,
        payout_amount: policy.coverage_amount,
        timestamp,
    };
    sui::event::emit(event);
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

    // Emit payout executed event
    let event = PayoutExecuted {
        policy_id: object::uid_to_inner(&policy.id),
        amount: payout,
        recipient: policy.owner,
    };
    sui::event::emit(event);
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

// ------------------------------------------------------------------------
// Gas-optimized batch operations
// ------------------------------------------------------------------------
public fun batch_process_climate_data(
    state: &GlobalState,
    policy: &mut ClimatePolicy,
    values: vector<u64>,
    timestamps: vector<u64>,
    confidences: vector<u8>,
    ctx: &mut tx_context::TxContext,
) {
    assert_not_paused(state);
    assert!(tx_context::sender(ctx) == state.authority, E_ORACLE_NOT_AUTHORIZED);
    assert!(policy.status == STATUS_ACTIVE, E_POLICY_NOT_ACTIVE);

    let len = vector::length(&values);
    assert!(
        len == vector::length(&timestamps) && len == vector::length(&confidences),
        E_INVALID_ORACLE_DATA,
    );
    assert!(len > 0, E_INVALID_ORACLE_DATA);

    let mut i = 0;
    while (i < len) {
        let value = *vector::borrow(&values, i);
        let timestamp = *vector::borrow(&timestamps, i);
        let confidence = *vector::borrow(&confidences, i);

        assert!(value > 0, E_INVALID_ORACLE_DATA);
        assert!(
            confidence <= MAX_CONFIDENCE && confidence >= MIN_CONFIDENCE,
            E_LOW_CONFIDENCE_DATA,
        );
        assert!(timestamp > policy.last_data_timestamp, E_STALE_ORACLE_DATA);
        assert!(
            timestamp >= policy.start_timestamp && timestamp <= policy.end_timestamp,
            E_INVALID_TIMESTAMP,
        );

        policy.last_data_value = value;
        policy.last_data_timestamp = timestamp;
        policy.last_data_confidence = confidence;

        i = i + 1;
    }
}

// ------------------------------------------------------------------------
// Public getter functions for state inspection
// ------------------------------------------------------------------------
public fun get_policy_status(policy: &ClimatePolicy): u8 {
    policy.status
}

public fun get_policy_owner(policy: &ClimatePolicy): address {
    policy.owner
}

public fun get_policy_coverage(policy: &ClimatePolicy): u64 {
    policy.coverage_amount
}

public fun get_policy_premium_info(policy: &ClimatePolicy): (u64, u64) {
    (policy.premium_amount, policy.deposited_premium)
}

public fun get_policy_timestamps(policy: &ClimatePolicy): (u64, u64, u64) {
    (policy.creation_timestamp, policy.start_timestamp, policy.end_timestamp)
}

public fun get_policy_triggers(policy: &ClimatePolicy): (u64, u64) {
    (policy.trigger_rainfall, policy.trigger_temperature)
}

public fun get_policy_last_data(policy: &ClimatePolicy): (u64, u64, u8) {
    (policy.last_data_value, policy.last_data_timestamp, policy.last_data_confidence)
}

public fun get_global_state_info(state: &GlobalState): (address, bool, u64, u64, u64, u64) {
    (
        state.authority,
        state.paused,
        state.total_policies,
        state.total_premiums_collected,
        state.total_payouts_released,
        state.risk_pool_balance,
    )
}

public fun is_policy_expired(policy: &ClimatePolicy, current_timestamp: u64): bool {
    current_timestamp >= policy.end_timestamp
}

public fun is_policy_fully_funded(policy: &ClimatePolicy): bool {
    policy.deposited_premium >= policy.premium_amount
}

public fun calculate_remaining_premium(policy: &ClimatePolicy): u64 {
    if (policy.deposited_premium >= policy.premium_amount) {
        0
    } else {
        policy.premium_amount - policy.deposited_premium
    }
}

// Utility functions for risk management
public fun calculate_policy_utilization_rate(state: &GlobalState): u64 {
    if (state.total_premiums_collected == 0) {
        0
    } else {
        (state.total_payouts_released * 10000) / state.total_premiums_collected // Basis points
    }
}

public fun get_risk_pool_health(state: &GlobalState): bool {
    state.risk_pool_balance > (state.total_premiums_collected / 4) // 25% reserve requirement
}

// ------------------------------------------------------------------------
// Event structs for better tracking
// ------------------------------------------------------------------------
public struct PolicyCreated has copy, drop {
    policy_id: object::ID,
    owner: address,
    coverage_amount: u64,
    premium_amount: u64,
    end_timestamp: u64,
}

public struct PremiumDeposited has copy, drop {
    policy_id: object::ID,
    amount: u64,
    total_deposited: u64,
    is_fully_funded: bool,
}

public struct PolicyTriggered has copy, drop {
    policy_id: object::ID,
    trigger_value: u64,
    payout_amount: u64,
    timestamp: u64,
}

public struct PayoutExecuted has copy, drop {
    policy_id: object::ID,
    amount: u64,
    recipient: address,
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
    let current_time = tx_context::epoch(ctx);
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
        start_timestamp: current_time,
        end_timestamp,
        last_data_timestamp: 0,
        last_data_value: 0,
        last_data_confidence: 0,
        creation_timestamp: current_time,
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
