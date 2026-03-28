-- SampleBank v4.5 Stored Procedures
-- PostgreSQL DBRE Course
-- Updated for account-to-account transfers

-- =====================================================
-- Function: transfer_money (account-to-account)
-- Purpose: Atomic money transfer between accounts
-- =====================================================

DROP FUNCTION IF EXISTS transfer_money(VARCHAR, VARCHAR, DECIMAL);

CREATE OR REPLACE FUNCTION transfer_money(
    p_from_account_number VARCHAR,
    p_to_account_number VARCHAR,
    p_amount DECIMAL
) RETURNS TEXT AS $$
DECLARE
    v_from_account_id INT;
    v_to_account_id INT;
    v_from_balance DECIMAL;
    v_from_status VARCHAR;
    v_to_status VARCHAR;
    v_ref_number VARCHAR;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN 'ERROR: Amount must be greater than 0';
    END IF;

    -- Get sender account details
    SELECT account_id, balance, status
    INTO v_from_account_id, v_from_balance, v_from_status
    FROM accounts
    WHERE account_number = p_from_account_number;

    IF NOT FOUND THEN
        RETURN 'ERROR: Source account not found';
    END IF;

    -- Check source account status
    IF v_from_status != 'active' THEN
        RETURN 'ERROR: Source account is ' || v_from_status;
    END IF;

    -- Check sufficient balance
    IF v_from_balance < p_amount THEN
        RETURN 'ERROR: Insufficient balance';
    END IF;

    -- Get receiver account details
    SELECT account_id, status
    INTO v_to_account_id, v_to_status
    FROM accounts
    WHERE account_number = p_to_account_number;

    IF NOT FOUND THEN
        RETURN 'ERROR: Destination account not found';
    END IF;

    -- Check destination account status
    IF v_to_status != 'active' THEN
        RETURN 'ERROR: Destination account is ' || v_to_status;
    END IF;

    -- Cannot transfer to same account
    IF v_from_account_id = v_to_account_id THEN
        RETURN 'ERROR: Cannot transfer to the same account';
    END IF;

    -- Generate unique reference number
    v_ref_number := 'TXN-' || to_char(NOW(), 'YYYYMMDD') || '-' ||
                    lpad(nextval('transactions_txn_id_seq')::text, 8, '0');

    -- Perform transfer (atomic)
    UPDATE accounts
    SET balance = balance - p_amount, updated_at = NOW()
    WHERE account_id = v_from_account_id;

    UPDATE accounts
    SET balance = balance + p_amount, updated_at = NOW()
    WHERE account_id = v_to_account_id;

    -- Record transaction
    INSERT INTO transactions (
        from_account_id,
        to_account_id,
        amount,
        txn_type,
        status,
        reference_number,
        description
    ) VALUES (
        v_from_account_id,
        v_to_account_id,
        p_amount,
        'transfer',
        'completed',
        v_ref_number,
        'Transfer from ' || p_from_account_number || ' to ' || p_to_account_number
    );

    RETURN 'SUCCESS: Transferred $' || p_amount ||
           ' from ' || p_from_account_number ||
           ' to ' || p_to_account_number ||
           ' (Ref: ' || v_ref_number || ')';

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: Transaction failed - ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION transfer_money IS 'Atomic money transfer between accounts';

-- =====================================================
-- Function: create_account
-- Purpose: Create a new account for a user
-- =====================================================

CREATE OR REPLACE FUNCTION create_account(
    p_user_id INT,
    p_account_type VARCHAR DEFAULT 'checking',
    p_initial_balance DECIMAL DEFAULT 0.00
) RETURNS TEXT AS $$
DECLARE
    v_account_number VARCHAR;
    v_account_id INT;
    v_user_exists BOOLEAN;
BEGIN
    -- Check if user exists
    SELECT EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id)
    INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN 'ERROR: User not found';
    END IF;

    -- Validate account type
    IF p_account_type NOT IN ('checking', 'savings', 'credit') THEN
        RETURN 'ERROR: Invalid account type';
    END IF;

    -- Generate unique account number
    v_account_number := 'ACC-' ||
                        to_char(NOW(), 'YYYYMMDD') || '-' ||
                        lpad(p_user_id::text, 4, '0') || '-' ||
                        lpad(nextval('accounts_account_id_seq')::text, 4, '0');

    -- Create account
    INSERT INTO accounts (
        user_id,
        account_number,
        account_type,
        balance,
        status
    ) VALUES (
        p_user_id,
        v_account_number,
        p_account_type,
        p_initial_balance,
        'active'
    ) RETURNING account_id INTO v_account_id;

    RETURN 'SUCCESS: Account ' || v_account_number ||
           ' created (ID: ' || v_account_id || ')';

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: Account creation failed - ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_account IS 'Create a new account for a user';

-- =====================================================
-- Function: get_account_balance
-- Purpose: Get balance for an account
-- =====================================================

CREATE OR REPLACE FUNCTION get_account_balance(
    p_account_number VARCHAR
) RETURNS TABLE (
    account_number VARCHAR,
    account_type VARCHAR,
    balance DECIMAL,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.account_number,
        a.account_type,
        a.balance,
        a.status
    FROM accounts a
    WHERE a.account_number = p_account_number;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_account_balance IS 'Get account balance and details';

-- =====================================================
-- Function: get_user_accounts
-- Purpose: Get all accounts for a user
-- =====================================================

CREATE OR REPLACE FUNCTION get_user_accounts(
    p_username VARCHAR
) RETURNS TABLE (
    account_id INT,
    account_number VARCHAR,
    account_type VARCHAR,
    balance DECIMAL,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.account_id,
        a.account_number,
        a.account_type,
        a.balance,
        a.status
    FROM accounts a
    JOIN users u ON a.user_id = u.user_id
    WHERE u.username = p_username
      AND a.status = 'active'
    ORDER BY a.created_at;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_user_accounts IS 'Get all active accounts for a user';

-- =====================================================
-- Function: get_account_transactions
-- Purpose: Get transaction history for an account
-- =====================================================

CREATE OR REPLACE FUNCTION get_account_transactions(
    p_account_number VARCHAR,
    p_limit INT DEFAULT 50
) RETURNS TABLE (
    txn_id INT,
    txn_type VARCHAR,
    amount DECIMAL,
    from_account VARCHAR,
    to_account VARCHAR,
    status VARCHAR,
    reference_number VARCHAR,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.txn_id,
        t.txn_type,
        t.amount,
        fa.account_number AS from_account,
        ta.account_number AS to_account,
        t.status,
        t.reference_number,
        t.created_at
    FROM transactions t
    LEFT JOIN accounts fa ON t.from_account_id = fa.account_id
    LEFT JOIN accounts ta ON t.to_account_id = ta.account_id
    WHERE fa.account_number = p_account_number
       OR ta.account_number = p_account_number
    ORDER BY t.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_account_transactions IS 'Get transaction history for an account';

-- =====================================================
-- Verification query
-- =====================================================
SELECT 'procedures.sql executed successfully!' AS status;

-- Test functions exist
SELECT
    proname AS function_name,
    pg_get_function_arguments(oid) AS arguments
FROM pg_proc
WHERE proname IN ('transfer_money', 'create_account', 'get_account_balance',
                  'get_user_accounts', 'get_account_transactions')
ORDER BY proname;
