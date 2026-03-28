-- Migration Script: SampleBank v4 → v4.5
-- Purpose: Evolve from 2-table to 3-table architecture
-- Zero-downtime migration strategy

-- =====================================================
-- PHASE 1: Create new accounts table
-- =====================================================

BEGIN;

-- Create accounts table (without dropping existing tables)
CREATE TABLE IF NOT EXISTS accounts (
    account_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_type VARCHAR(20) DEFAULT 'checking',
    balance DECIMAL(15,2) DEFAULT 0.00 CHECK (balance >= 0),
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE accounts IS 'Migrated from v4: Balance extracted from users table';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_account_number ON accounts(account_number);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON accounts(status);

COMMIT;

-- =====================================================
-- PHASE 2: Migrate data from users to accounts
-- =====================================================

BEGIN;

-- For each user in v4, create a checking account with their balance
INSERT INTO accounts (user_id, account_number, account_type, balance, created_at)
SELECT
    user_id,
    'ACC-MIGRATED-' || lpad(user_id::text, 6, '0') AS account_number,
    'checking' AS account_type,
    COALESCE(balance, 1000.00) AS balance,  -- v4 default was 1000.00
    created_at
FROM users
WHERE NOT EXISTS (
    SELECT 1 FROM accounts a WHERE a.user_id = users.user_id
);

COMMIT;

-- =====================================================
-- PHASE 3: Backup old transactions table
-- =====================================================

BEGIN;

-- Rename old transactions to backup
ALTER TABLE IF EXISTS transactions RENAME TO transactions_v4_backup;

-- Create new transactions table
CREATE TABLE transactions (
    txn_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    txn_type VARCHAR(20) NOT NULL DEFAULT 'transfer',
    status VARCHAR(20) DEFAULT 'completed',
    description TEXT,
    reference_number VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),
    CHECK (from_account_id != to_account_id)
);

COMMIT;

-- =====================================================
-- PHASE 4: Migrate transactions data
-- =====================================================

BEGIN;

-- Migrate old transactions to new structure
-- Map user_id to account_id
INSERT INTO transactions (
    from_account_id,
    to_account_id,
    amount,
    txn_type,
    status,
    created_at,
    reference_number
)
SELECT
    fa.account_id AS from_account_id,
    ta.account_id AS to_account_id,
    t_old.amount,
    'transfer' AS txn_type,
    'completed' AS status,
    t_old.created_at,
    'MIGRATED-' || t_old.transaction_id::text AS reference_number
FROM transactions_v4_backup t_old
JOIN accounts fa ON t_old.from_user_id = fa.user_id
JOIN accounts ta ON t_old.to_user_id = ta.user_id
WHERE fa.account_type = 'checking'  -- Use checking account by default
  AND ta.account_type = 'checking';

COMMIT;

-- =====================================================
-- PHASE 5: Add indexes to new transactions table
-- =====================================================

BEGIN;

CREATE INDEX idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_reference ON transactions(reference_number);

COMMIT;

-- =====================================================
-- PHASE 6: Remove balance column from users (optional)
-- =====================================================

-- IMPORTANT: Only run this after verifying migration success!
-- Uncomment after verification:

-- BEGIN;
-- ALTER TABLE users DROP COLUMN IF EXISTS balance;
-- COMMIT;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check accounts created
SELECT
    'Accounts migrated' AS check_type,
    COUNT(*) AS count,
    SUM(balance) AS total_balance
FROM accounts;

-- Check transactions migrated
SELECT
    'Transactions migrated' AS check_type,
    COUNT(*) AS count,
    SUM(amount) AS total_amount
FROM transactions;

-- Compare old vs new transaction counts
SELECT
    'OLD transactions (v4)' AS source,
    COUNT(*) AS count
FROM transactions_v4_backup
UNION ALL
SELECT
    'NEW transactions (v4.5)' AS source,
    COUNT(*) AS count
FROM transactions;

-- Verify one account per user (for basic migration)
SELECT
    u.username,
    COUNT(a.account_id) AS account_count,
    SUM(a.balance) AS total_balance
FROM users u
LEFT JOIN accounts a ON u.user_id = a.user_id
GROUP BY u.username
ORDER BY account_count DESC;

-- =====================================================
-- ROLLBACK PROCEDURE (if needed)
-- =====================================================

/*
-- If migration fails, rollback with these commands:

BEGIN;

-- Drop new tables
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

-- Restore old transactions table
ALTER TABLE transactions_v4_backup RENAME TO transactions;

COMMIT;

-- Then investigate the issue and retry
*/

-- =====================================================
-- CLEANUP (after successful migration and verification)
-- =====================================================

/*
-- After 30 days of running v4.5 successfully:

BEGIN;

-- Drop backup table
DROP TABLE IF EXISTS transactions_v4_backup CASCADE;

-- Remove balance column from users
ALTER TABLE users DROP COLUMN IF EXISTS balance;

COMMIT;
*/

-- =====================================================
-- Migration complete!
-- =====================================================

SELECT
    '✅ Migration from v4 to v4.5 completed!' AS status,
    NOW() AS migration_timestamp;
