-- SampleBank v4.5 Database Schema
-- PostgreSQL DBRE Course
-- Architecture Evolution: Separate accounts table

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- =====================================================
-- Users table (authentication & profile only)
-- =====================================================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    full_name VARCHAR(100),
    phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',  -- active, suspended, deleted
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE users IS 'User authentication and profile information';
COMMENT ON COLUMN users.status IS 'User account status: active, suspended, deleted';

-- =====================================================
-- Accounts table (financial accounts)
-- =====================================================
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_type VARCHAR(20) DEFAULT 'checking',  -- checking, savings, credit
    balance DECIMAL(15,2) DEFAULT 0.00 CHECK (balance >= 0),
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'active',  -- active, suspended, closed
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE accounts IS 'Financial accounts belonging to users';
COMMENT ON COLUMN accounts.account_type IS 'Account type: checking, savings, credit';
COMMENT ON COLUMN accounts.balance IS 'Current account balance (non-negative)';
COMMENT ON COLUMN accounts.status IS 'Account status: active, suspended, closed';

-- =====================================================
-- Transactions table (financial transactions)
-- =====================================================
CREATE TABLE transactions (
    txn_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    txn_type VARCHAR(20) NOT NULL,  -- transfer, deposit, withdrawal, fee
    status VARCHAR(20) DEFAULT 'completed',  -- pending, completed, failed, reversed
    description TEXT,
    reference_number VARCHAR(50) UNIQUE,
    created_at TIMESTAMP DEFAULT NOW(),

    -- Constraint: Cannot transfer to the same account
    CHECK (from_account_id != to_account_id)
);

COMMENT ON TABLE transactions IS 'Financial transactions between accounts';
COMMENT ON COLUMN transactions.txn_type IS 'Transaction type: transfer, deposit, withdrawal, fee';
COMMENT ON COLUMN transactions.status IS 'Transaction status: pending, completed, failed, reversed';
COMMENT ON COLUMN transactions.reference_number IS 'Unique reference for transaction tracking';

-- =====================================================
-- Indexes for performance
-- =====================================================

-- Users indexes
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);

-- Accounts indexes
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_account_number ON accounts(account_number);
CREATE INDEX idx_accounts_status ON accounts(status);
CREATE INDEX idx_accounts_type ON accounts(account_type);

-- Transactions indexes
CREATE INDEX idx_transactions_from_account ON transactions(from_account_id);
CREATE INDEX idx_transactions_to_account ON transactions(to_account_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_reference ON transactions(reference_number);

-- Composite indexes for common queries
CREATE INDEX idx_accounts_user_status ON accounts(user_id, status);
CREATE INDEX idx_transactions_accounts_created ON transactions(from_account_id, to_account_id, created_at);

-- =====================================================
-- Functions for automatic timestamp updates
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to automatically update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Verification query
-- =====================================================
SELECT
    'schema.sql executed successfully!' AS status,
    (SELECT COUNT(*) FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name IN ('users', 'accounts', 'transactions')) AS tables_created;
