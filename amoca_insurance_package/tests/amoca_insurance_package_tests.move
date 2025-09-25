#[test_only]
module amoca_insurance_package::amoca_insurance_package_tests {
    use amoca_insurance_package::amoca_insurance_package;
    use sui::tx_context;

    const AUTHORITY: address = @0xa;
    const OWNER: address = @0xb;

    #[test]
    fun test_policy_activation_and_payout_flow() {
        let mut state_ctx = tx_context::new_for_testing(AUTHORITY);
        let mut state = amoca_insurance_package::testing_new_state(AUTHORITY, &mut state_ctx);

        let mut policy_ctx = tx_context::new_for_testing(OWNER);
        let mut policy = amoca_insurance_package::testing_new_policy(
            OWNER,
            300,
            300,
            1_000,
            150,
            0,
            24,
            12,
            &mut policy_ctx,
        );

        let mut deposit_ctx = tx_context::new_for_testing(OWNER);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 300, &mut deposit_ctx);

        assert!(policy.status == 1, 0);
        assert!(state.total_premiums_collected == 300, 1);
        assert!(state.risk_pool_balance == 300, 2);

        let mut oracle_ctx = tx_context::new_for_testing(AUTHORITY);
        amoca_insurance_package::submit_climate_data(&state, &mut policy, 180, 10, 80, &mut oracle_ctx);

        let mut eval_ctx = tx_context::new_for_testing(AUTHORITY);
        amoca_insurance_package::evaluate_climate_trigger(&mut state, &mut policy, 180, 0, 12, 20, &mut eval_ctx);

        assert!(policy.status == 2, 3);
        assert!(policy.pending_payout == 300, 4);

        let mut payout_ctx = tx_context::new_for_testing(AUTHORITY);
        amoca_insurance_package::execute_climate_payout(&mut state, &mut policy, &mut payout_ctx);

        assert!(policy.status == 3, 5);
        assert!(policy.pending_payout == 0, 6);
        assert!(state.risk_pool_balance == 0, 7);
        assert!(state.total_payouts_released == 300, 8);
    }

    #[test, expected_failure(abort_code = 6005)]
    fun test_deposit_premium_exceeds_requirement_fails() {
        let mut state_ctx = tx_context::new_for_testing(AUTHORITY);
        let mut state = amoca_insurance_package::testing_new_state(AUTHORITY, &mut state_ctx);

        let mut policy_ctx = tx_context::new_for_testing(OWNER);
        let mut policy = amoca_insurance_package::testing_new_policy(
            OWNER,
            300,
            200,
            1_000,
            150,
            0,
            24,
            12,
            &mut policy_ctx,
        );

        let mut deposit_ctx = tx_context::new_for_testing(OWNER);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 200, &mut deposit_ctx);

        let mut deposit_ctx_again = tx_context::new_for_testing(OWNER);
        amoca_insurance_package::deposit_premium(&mut state, &mut policy, 50, &mut deposit_ctx_again);
    }
}
