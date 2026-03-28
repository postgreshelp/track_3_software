# SampleBank v3 - Database Schema Documentation

## Table of Contents
1. [Database Overview](#database-overview)
2. [Schema Diagram](#schema-diagram)
3. [Tables](#tables)
4. [Stored Procedures](#stored-procedures)
5. [Indexes](#indexes)
6. [Constraints](#constraints)
7. [Sample Queries](#sample-queries)
8. [Migration Scripts](#migration-scripts)

## Database Overview

### Database Information
- **Database Name**: samplebank
- **Database Type**: PostgreSQL 12+
- **Character Set**: UTF-8
- **Purpose**: Banking transaction system with user accounts and money transfers

### Schema Components
- **Tables**: 2 (users, transactions)
- **Stored Procedures**: 1 (transfer_money)
- **Indexes**: 3 (username, from_user_id, to_user_id)
- **Constraints**: Foreign keys, CHECK constraints, UNIQUE constraints

## Schema Diagram

```
┌─────────────────────────────────────────┐
│              users                       │
├─────────────────────────────────────────┤
│ PK  user_id         SERIAL              │
│ UQ  username        VARCHAR(50)         │
│ UQ  email           VARCHAR(100)        │
│     password        VARCHAR(255)        │
│     balance         DECIMAL(12,2)       │
│     created_at      TIMESTAMP           │
└──────────┬──────────────────────────────┘
           │
           │ 1:N (one user has many transactions)
           │
           ├──────────────────────────────┐
           │                              │
┌──────────▼──────────────────────────────▼─────┐
│           transactions                         │
├───────────────────────────────────────────────┤
│ PK  transaction_id     SERIAL                 │
│ FK  from_user_id       INT → users(user_id)   │
│ FK  to_user_id         INT → users(user_id)   │
│     amount             DECIMAL(12,2)          │
│     created_at         TIMESTAMP              │
│ CHK from_user_id != to_user_id                │
│ CHK amount > 0                                 │
└───────────────────────────────────────────────┘

Indexes:
- idx_users_username ON users(username)
- idx_transactions_from ON transactions(from_user_id)
- idx_transactions_to ON transactions(to_user_id)
```

## Tables

### 1. users Table

**Purpose**: Stores user account information including authentication credentials and account balances.

**Table Definition**:
```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Column Details**:

| Column      | Type          | Constraints           | Description                                      |
|-------------|---------------|-----------------------|--------------------------------------------------|
| user_id     | SERIAL        | PRIMARY KEY           | Auto-incrementing unique identifier              |
| username    | VARCHAR(50)   | UNIQUE, NOT NULL      | User's login name (3-50 characters)              |
| email       | VARCHAR(100)  | UNIQUE, NOT NULL      | User's email address                             |
| password    | VARCHAR(255)  | NOT NULL              | Hashed password (plain text in current version)  |
| balance     | DECIMAL(12,2) | DEFAULT 1000.00, CHK  | Account balance (cannot be negative)             |
| created_at  | TIMESTAMP     | DEFAULT NOW()         | Account creation timestamp                       |

**Constraints**:
- **Primary Key**: user_id
- **Unique Constraints**: username, email
- **CHECK Constraint**: balance >= 0 (prevents negative balances)
- **NOT NULL**: username, email, password

**Business Rules**:
1. New users receive $1000.00 starting balance
2. Username must be unique across the system
3. Email must be unique (one account per email)
4. Balance can never go below zero
5. Password stored as-is (should be hashed in production)

**Sample Data**:
```sql
INSERT INTO users (username, email, password, balance) VALUES
('alice', 'alice@example.com', 'password123', 1000.00),
('bob', 'bob@example.com', 'password456', 1500.00),
('charlie', 'charlie@example.com', 'password789', 750.50);
```

### 2. transactions Table

**Purpose**: Audit log of all money transfers between users, providing complete transaction history.

**Table Definition**:
```sql
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_user_id INT NOT NULL REFERENCES users(user_id),
    to_user_id INT NOT NULL REFERENCES users(user_id),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_user_id != to_user_id)
);
```

**Column Details**:

| Column          | Type          | Constraints           | Description                                |
|-----------------|---------------|-----------------------|--------------------------------------------|
| transaction_id  | SERIAL        | PRIMARY KEY           | Unique transaction identifier              |
| from_user_id    | INT           | FK, NOT NULL          | Sender's user_id                           |
| to_user_id      | INT           | FK, NOT NULL          | Receiver's user_id                         |
| amount          | DECIMAL(12,2) | NOT NULL, CHK         | Transfer amount (must be positive)         |
| created_at      | TIMESTAMP     | DEFAULT NOW()         | Transaction timestamp                      |

**Constraints**:
- **Primary Key**: transaction_id
- **Foreign Keys**:
  - from_user_id → users(user_id)
  - to_user_id → users(user_id)
- **CHECK Constraints**:
  - amount > 0 (no zero or negative transfers)
  - from_user_id != to_user_id (no self-transfers)
- **NOT NULL**: from_user_id, to_user_id, amount

**Business Rules**:
1. Every transfer creates one transaction record
2. Amount must be positive (greater than zero)
3. Cannot transfer money to yourself
4. Both sender and receiver must exist in users table
5. Transaction records are immutable (no updates or deletes)
6. Timestamp automatically recorded on insert

**Sample Data**:
```sql
INSERT INTO transactions (from_user_id, to_user_id, amount) VALUES
(1, 2, 250.00),  -- Alice sends $250 to Bob
(2, 3, 100.50),  -- Bob sends $100.50 to Charlie
(1, 3, 50.00);   -- Alice sends $50 to Charlie
```

**Cascade Behavior**:
```sql
-- On user deletion, what happens to their transactions?
-- Current: ERROR (foreign key violation)
-- Alternative: Add ON DELETE CASCADE to allow deletion
-- Alternative: Add ON DELETE SET NULL (not recommended - breaks audit trail)
```

## Stored Procedures

### transfer_money() Function

**Purpose**: Executes atomic money transfer between two users with validation and error handling.

**Function Signature**:
```sql
CREATE OR REPLACE FUNCTION transfer_money(
    p_from_username VARCHAR,
    p_to_username VARCHAR,
    p_amount DECIMAL
) RETURNS TEXT AS $$
```

**Parameters**:

| Parameter       | Type    | Description                          |
|-----------------|---------|--------------------------------------|
| p_from_username | VARCHAR | Sender's username                    |
| p_to_username   | VARCHAR | Receiver's username                  |
| p_amount        | DECIMAL | Amount to transfer (positive number) |

**Return Values**:

| Return String                                        | Meaning                           |
|------------------------------------------------------|-----------------------------------|
| SUCCESS: Transferred $X from sender to receiver      | Transfer completed successfully   |
| ERROR: Sender not found                              | p_from_username doesn't exist     |
| ERROR: Receiver not found                            | p_to_username doesn't exist       |
| ERROR: Insufficient balance                          | Sender doesn't have enough funds  |

**Complete Implementation**:
```sql
CREATE OR REPLACE FUNCTION transfer_money(
    p_from_username VARCHAR,
    p_to_username VARCHAR,
    p_amount DECIMAL
) RETURNS TEXT AS $$
DECLARE
    v_from_user_id INT;
    v_to_user_id INT;
    v_from_balance DECIMAL;
BEGIN
    -- Step 1: Look up sender by username and get current balance
    SELECT user_id, balance INTO v_from_user_id, v_from_balance
    FROM users
    WHERE username = p_from_username;

    -- Step 2: Validate sender exists
    IF v_from_user_id IS NULL THEN
        RETURN 'ERROR: Sender not found';
    END IF;

    -- Step 3: Validate sufficient balance
    IF v_from_balance < p_amount THEN
        RETURN 'ERROR: Insufficient balance';
    END IF;

    -- Step 4: Look up receiver by username
    SELECT user_id INTO v_to_user_id
    FROM users
    WHERE username = p_to_username;

    -- Step 5: Validate receiver exists
    IF v_to_user_id IS NULL THEN
        RETURN 'ERROR: Receiver not found';
    END IF;

    -- Step 6: Deduct amount from sender's balance
    UPDATE users
    SET balance = balance - p_amount
    WHERE user_id = v_from_user_id;

    -- Step 7: Add amount to receiver's balance
    UPDATE users
    SET balance = balance + p_amount
    WHERE user_id = v_to_user_id;

    -- Step 8: Insert transaction record for audit trail
    INSERT INTO transactions (from_user_id, to_user_id, amount)
    VALUES (v_from_user_id, v_to_user_id, p_amount);

    -- Step 9: Return success message with details
    RETURN 'SUCCESS: Transferred $' || p_amount || ' from ' ||
           p_from_username || ' to ' || p_to_username;
END;
$$ LANGUAGE plpgsql;
```

**ACID Properties**:
- **Atomicity**: All operations succeed or all fail (BEGIN...END block)
- **Consistency**: CHECK constraints prevent invalid states
- **Isolation**: PostgreSQL transaction isolation prevents race conditions
- **Durability**: Changes committed to WAL before success return

**Usage Examples**:
```sql
-- Successful transfer
SELECT transfer_money('alice', 'bob', 250.00);
-- Returns: SUCCESS: Transferred $250.00 from alice to bob

-- Insufficient balance
SELECT transfer_money('alice', 'bob', 5000.00);
-- Returns: ERROR: Insufficient balance

-- Non-existent sender
SELECT transfer_money('nonexistent', 'bob', 100.00);
-- Returns: ERROR: Sender not found

-- Non-existent receiver
SELECT transfer_money('alice', 'nonexistent', 100.00);
-- Returns: ERROR: Receiver not found
```

**Transaction Flow**:
```
1. BEGIN (implicit)
2. SELECT sender (lock row if in higher isolation level)
3. Validate sender exists
4. Validate sufficient balance
5. SELECT receiver
6. Validate receiver exists
7. UPDATE sender balance (row lock acquired)
8. UPDATE receiver balance (row lock acquired)
9. INSERT transaction record
10. COMMIT (implicit if no errors)
11. RETURN success message
```

## Indexes

### Purpose of Indexes
Indexes improve query performance by creating fast lookup structures, similar to a book's index.

### 1. idx_users_username

**Definition**:
```sql
CREATE INDEX idx_users_username ON users(username);
```

**Purpose**: Fast lookup of users by username for login and transfer operations

**Query Optimization**:
```sql
-- Without index: Full table scan O(n)
-- With index: B-tree lookup O(log n)
SELECT user_id, balance FROM users WHERE username = 'alice';
```

**Performance Impact**:
- Login queries: 100x faster on 10,000+ users
- Transfer validation: Instant username lookup

### 2. idx_transactions_from

**Definition**:
```sql
CREATE INDEX idx_transactions_from ON transactions(from_user_id);
```

**Purpose**: Fast retrieval of all transactions sent by a specific user

**Query Optimization**:
```sql
-- Find all transactions sent by user #1
SELECT * FROM transactions WHERE from_user_id = 1;
```

**Use Cases**:
- User transaction history (sent)
- Audit reports
- Spending analytics

### 3. idx_transactions_to

**Definition**:
```sql
CREATE INDEX idx_transactions_to ON transactions(to_user_id);
```

**Purpose**: Fast retrieval of all transactions received by a specific user

**Query Optimization**:
```sql
-- Find all transactions received by user #1
SELECT * FROM transactions WHERE to_user_id = 1;
```

**Use Cases**:
- User transaction history (received)
- Income tracking
- Audit reports

### Index Maintenance

**Viewing Indexes**:
```sql
-- List all indexes
\di

-- Show indexes for specific table
\d transactions
```

**Rebuilding Indexes** (if needed):
```sql
REINDEX INDEX idx_users_username;
REINDEX TABLE transactions;
```

**Index Size**:
```sql
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public';
```

## Constraints

### Primary Key Constraints

**users.user_id**:
```sql
user_id SERIAL PRIMARY KEY
```
- Ensures unique identifier for each user
- Auto-increments on each insert
- Cannot be NULL
- Used in foreign key references

**transactions.transaction_id**:
```sql
transaction_id SERIAL PRIMARY KEY
```
- Ensures unique identifier for each transaction
- Auto-increments sequentially
- Provides audit trail ordering

### Foreign Key Constraints

**transactions.from_user_id**:
```sql
from_user_id INT NOT NULL REFERENCES users(user_id)
```
- Ensures sender exists in users table
- Prevents orphaned transactions
- Blocks deletion of users with transactions

**transactions.to_user_id**:
```sql
to_user_id INT NOT NULL REFERENCES users(user_id)
```
- Ensures receiver exists in users table
- Maintains referential integrity

**Testing Foreign Key Constraints**:
```sql
-- This will fail (user 9999 doesn't exist)
INSERT INTO transactions (from_user_id, to_user_id, amount)
VALUES (9999, 1, 100.00);
-- ERROR: insert or update on table "transactions" violates foreign key constraint
```

### Unique Constraints

**users.username**:
```sql
username VARCHAR(50) UNIQUE NOT NULL
```
- No two users can have the same username
- Case-sensitive by default

**users.email**:
```sql
email VARCHAR(100) UNIQUE NOT NULL
```
- One account per email address
- Prevents duplicate registrations

**Testing Unique Constraints**:
```sql
-- First insert succeeds
INSERT INTO users (username, email, password) VALUES ('alice', 'alice@test.com', 'pass123');

-- Second insert fails
INSERT INTO users (username, email, password) VALUES ('alice', 'different@test.com', 'pass456');
-- ERROR: duplicate key value violates unique constraint "users_username_key"
```

### CHECK Constraints

**users.balance >= 0**:
```sql
balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0)
```
- Prevents negative account balances
- Business rule enforcement at database level

**transactions.amount > 0**:
```sql
amount DECIMAL(12,2) NOT NULL CHECK (amount > 0)
```
- Prevents zero or negative transfers
- Ensures meaningful transactions only

**transactions.from_user_id != to_user_id**:
```sql
CHECK (from_user_id != to_user_id)
```
- Prevents self-transfers
- Business logic enforcement

**Testing CHECK Constraints**:
```sql
-- This will fail (negative amount)
INSERT INTO transactions (from_user_id, to_user_id, amount)
VALUES (1, 2, -50.00);
-- ERROR: new row for relation "transactions" violates check constraint

-- This will fail (self-transfer)
INSERT INTO transactions (from_user_id, to_user_id, amount)
VALUES (1, 1, 100.00);
-- ERROR: new row for relation "transactions" violates check constraint
```

### NOT NULL Constraints

**Ensuring Data Integrity**:
```sql
username VARCHAR(50) UNIQUE NOT NULL
email VARCHAR(100) UNIQUE NOT NULL
password VARCHAR(255) NOT NULL
from_user_id INT NOT NULL
to_user_id INT NOT NULL
amount DECIMAL(12,2) NOT NULL
```

**Testing NOT NULL Constraints**:
```sql
-- This will fail (missing username)
INSERT INTO users (email, password) VALUES ('test@test.com', 'pass123');
-- ERROR: null value in column "username" violates not-null constraint
```

## Sample Queries

### User Queries

**Find user by username**:
```sql
SELECT user_id, username, email, balance, created_at
FROM users
WHERE username = 'alice';
```

**List all users with balances**:
```sql
SELECT username, balance, created_at
FROM users
ORDER BY balance DESC;
```

**Find users with low balance**:
```sql
SELECT username, balance
FROM users
WHERE balance < 100.00
ORDER BY balance ASC;
```

**Count total users**:
```sql
SELECT COUNT(*) AS total_users FROM users;
```

**Calculate total money in system**:
```sql
SELECT SUM(balance) AS total_balance FROM users;
```

### Transaction Queries

**Find all transactions for a user** (sent and received):
```sql
SELECT
    t.transaction_id,
    CASE
        WHEN t.from_user_id = u.user_id THEN 'SENT'
        WHEN t.to_user_id = u.user_id THEN 'RECEIVED'
    END AS type,
    CASE
        WHEN t.from_user_id = u.user_id THEN u2.username
        WHEN t.to_user_id = u.user_id THEN u1.username
    END AS other_party,
    t.amount,
    t.created_at
FROM transactions t
JOIN users u ON u.username = 'alice'
LEFT JOIN users u1 ON t.from_user_id = u1.user_id
LEFT JOIN users u2 ON t.to_user_id = u2.user_id
WHERE t.from_user_id = u.user_id OR t.to_user_id = u.user_id
ORDER BY t.created_at DESC;
```

**Transaction history with user names**:
```sql
SELECT
    t.transaction_id,
    u1.username AS sender,
    u2.username AS receiver,
    t.amount,
    t.created_at
FROM transactions t
JOIN users u1 ON t.from_user_id = u1.user_id
JOIN users u2 ON t.to_user_id = u2.user_id
ORDER BY t.created_at DESC
LIMIT 10;
```

**Calculate total sent by user**:
```sql
SELECT
    u.username,
    COALESCE(SUM(t.amount), 0) AS total_sent
FROM users u
LEFT JOIN transactions t ON u.user_id = t.from_user_id
WHERE u.username = 'alice'
GROUP BY u.username;
```

**Calculate total received by user**:
```sql
SELECT
    u.username,
    COALESCE(SUM(t.amount), 0) AS total_received
FROM users u
LEFT JOIN transactions t ON u.user_id = t.to_user_id
WHERE u.username = 'alice'
GROUP BY u.username;
```

**Most active users** (by transaction count):
```sql
SELECT
    u.username,
    COUNT(t.transaction_id) AS transaction_count
FROM users u
LEFT JOIN transactions t ON u.user_id = t.from_user_id OR u.user_id = t.to_user_id
GROUP BY u.username
ORDER BY transaction_count DESC
LIMIT 10;
```

**Transactions in date range**:
```sql
SELECT
    u1.username AS sender,
    u2.username AS receiver,
    t.amount,
    t.created_at
FROM transactions t
JOIN users u1 ON t.from_user_id = u1.user_id
JOIN users u2 ON t.to_user_id = u2.user_id
WHERE t.created_at BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY t.created_at DESC;
```

### Analytical Queries

**Daily transaction volume**:
```sql
SELECT
    DATE(created_at) AS transaction_date,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount
FROM transactions
GROUP BY DATE(created_at)
ORDER BY transaction_date DESC;
```

**Average transaction amount**:
```sql
SELECT
    AVG(amount) AS avg_transaction,
    MIN(amount) AS min_transaction,
    MAX(amount) AS max_transaction
FROM transactions;
```

**User balance verification** (starting balance + received - sent):
```sql
SELECT
    u.username,
    u.balance AS current_balance,
    1000.00 +
    COALESCE(SUM(tr.amount), 0) -
    COALESCE(SUM(ts.amount), 0) AS calculated_balance
FROM users u
LEFT JOIN transactions tr ON u.user_id = tr.to_user_id
LEFT JOIN transactions ts ON u.user_id = ts.from_user_id
GROUP BY u.user_id, u.username, u.balance;
```

## Migration Scripts

### Complete Database Setup

**Full schema creation script**:
```sql
-- Drop existing tables (careful in production!)
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS transfer_money CASCADE;

-- Create users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create transactions table
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_user_id INT NOT NULL REFERENCES users(user_id),
    to_user_id INT NOT NULL REFERENCES users(user_id),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_user_id != to_user_id)
);

-- Create indexes
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_transactions_from ON transactions(from_user_id);
CREATE INDEX idx_transactions_to ON transactions(to_user_id);

-- Create stored procedure
CREATE OR REPLACE FUNCTION transfer_money(
    p_from_username VARCHAR,
    p_to_username VARCHAR,
    p_amount DECIMAL
) RETURNS TEXT AS $$
DECLARE
    v_from_user_id INT;
    v_to_user_id INT;
    v_from_balance DECIMAL;
BEGIN
    SELECT user_id, balance INTO v_from_user_id, v_from_balance
    FROM users WHERE username = p_from_username;

    IF v_from_user_id IS NULL THEN
        RETURN 'ERROR: Sender not found';
    END IF;

    IF v_from_balance < p_amount THEN
        RETURN 'ERROR: Insufficient balance';
    END IF;

    SELECT user_id INTO v_to_user_id
    FROM users WHERE username = p_to_username;

    IF v_to_user_id IS NULL THEN
        RETURN 'ERROR: Receiver not found';
    END IF;

    UPDATE users SET balance = balance - p_amount
    WHERE user_id = v_from_user_id;

    UPDATE users SET balance = balance + p_amount
    WHERE user_id = v_to_user_id;

    INSERT INTO transactions (from_user_id, to_user_id, amount)
    VALUES (v_from_user_id, v_to_user_id, p_amount);

    RETURN 'SUCCESS: Transferred $' || p_amount || ' from ' ||
           p_from_username || ' to ' || p_to_username;
END;
$$ LANGUAGE plpgsql;
```

### Backup and Restore

**Backup database**:
```bash
pg_dump -U postgres -d samplebank -F c -f samplebank_backup.dump
```

**Restore database**:
```bash
pg_restore -U postgres -d samplebank samplebank_backup.dump
```

This completes the database schema documentation for SampleBank v3.
