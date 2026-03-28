# Database Schema Documentation: SampleBank v2

## Table of Contents

1. [Schema Overview](#schema-overview)
2. [Users Table](#users-table)
3. [Indexes](#indexes)
4. [Constraints](#constraints)
5. [Data Types](#data-types)
6. [Sample Data](#sample-data)
7. [Query Patterns](#query-patterns)
8. [Performance Analysis](#performance-analysis)
9. [Schema Evolution](#schema-evolution)

## Schema Overview

### Database Information

| Property | Value |
|----------|-------|
| Database Name | `samplebank1` |
| PostgreSQL Version | 13+ |
| Character Encoding | UTF8 |
| Collation | en_US.UTF-8 |
| Schema | `public` |

### Entity-Relationship Diagram

```
┌─────────────────────────────────────────────────────┐
│                    users                            │
├─────────────────────────────────────────────────────┤
│ PK  user_id          SERIAL                         │
│ UK  username         VARCHAR(50)  NOT NULL          │
│     email            VARCHAR(100) NOT NULL          │
│     password_hash    VARCHAR(255) NOT NULL          │
│     balance          DECIMAL(12,2) DEFAULT 1000.00  │
│     created_at       TIMESTAMP DEFAULT CURRENT_TS   │
├─────────────────────────────────────────────────────┤
│ Indexes:                                            │
│   - PRIMARY KEY (user_id)                           │
│   - UNIQUE (username)                               │
│   - idx_users_username (username) -- Performance    │
├─────────────────────────────────────────────────────┤
│ Constraints:                                        │
│   - CHECK (balance >= 0)                            │
│   - username NOT NULL, UNIQUE                       │
│   - email NOT NULL                                  │
│   - password_hash NOT NULL                          │
└─────────────────────────────────────────────────────┘
```

### Current Schema (Module 05)

The database contains a single table in this version:

- **users** - Stores user authentication and account information

Future modules will add:
- **transactions** (Module 06) - Deposit, withdrawal, transfer records
- **audit_logs** (Module 13) - Security and compliance logging
- **sessions** (Module 16) - JWT token management

## Users Table

### Complete Table Definition

```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Column Specifications

#### user_id

| Property | Value |
|----------|-------|
| **Data Type** | `SERIAL` (auto-incrementing integer) |
| **Constraint** | `PRIMARY KEY` |
| **Nullable** | NO |
| **Auto-increment** | YES |
| **Starting Value** | 1 |
| **Purpose** | Unique identifier for each user |

**Technical Details:**
- `SERIAL` is a pseudo-type that creates an `INTEGER` column with a sequence
- Equivalent to: `INTEGER NOT NULL DEFAULT nextval('users_user_id_seq')`
- Sequence automatically created: `users_user_id_seq`

**Usage:**
```sql
-- Automatic generation (INSERT)
INSERT INTO users (username, email, password_hash)
VALUES ('johndoe', 'john@example.com', 'hashedpass123');
-- user_id will be 1, 2, 3, etc. automatically

-- Retrieve current sequence value
SELECT currval('users_user_id_seq');

-- Retrieve next sequence value
SELECT nextval('users_user_id_seq');
```

#### username

| Property | Value |
|----------|-------|
| **Data Type** | `VARCHAR(50)` |
| **Constraint** | `UNIQUE NOT NULL` |
| **Nullable** | NO |
| **Max Length** | 50 characters |
| **Index** | YES (unique index + performance index) |
| **Purpose** | Unique identifier for user login |

**Constraints:**
- Must be unique across all users
- Cannot be null or empty
- Maximum 50 characters
- Case-sensitive in PostgreSQL (default)

**Best Practices:**
```sql
-- Valid usernames
'johndoe'
'alice_smith'
'bob123'
'user.name'

-- Invalid (would violate constraints)
NULL                    -- NOT NULL violation
''                      -- Empty string (application validation)
'averylongusernamethatisgreaterthan50characterslong'  -- Length violation
'johndoe'               -- Duplicate (UNIQUE violation)
```

**Query Performance:**
- Lookup by username: O(log n) with index
- Existence check: O(log n) with index

#### email

| Property | Value |
|----------|-------|
| **Data Type** | `VARCHAR(100)` |
| **Constraint** | `NOT NULL` |
| **Nullable** | NO |
| **Max Length** | 100 characters |
| **Index** | NO (could be added for lookups) |
| **Purpose** | User contact information |

**Notes:**
- NOT enforced as UNIQUE (users can share email in v2)
- Email format validation done at application layer
- Could add `UNIQUE` constraint for "1 email = 1 account" policy

**Future Enhancements:**
```sql
-- Add unique constraint (optional)
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);

-- Add index for email lookups (if needed)
CREATE INDEX idx_users_email ON users(email);

-- Add email validation check (PostgreSQL extension)
ALTER TABLE users ADD CONSTRAINT email_format_check
CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
```

#### password_hash

| Property | Value |
|----------|-------|
| **Data Type** | `VARCHAR(255)` |
| **Constraint** | `NOT NULL` |
| **Nullable** | NO |
| **Max Length** | 255 characters |
| **Index** | NO (never index passwords) |
| **Purpose** | Stores user password (plain-text in v2, bcrypt in future) |

**Current Implementation (Module 05):**
```sql
-- WARNING: Plain-text password storage (EDUCATIONAL ONLY)
INSERT INTO users (username, email, password_hash)
VALUES ('testuser', 'test@example.com', 'mypassword123');

-- Login verification (INSECURE)
SELECT * FROM users
WHERE username = 'testuser' AND password_hash = 'mypassword123';
```

**Future Implementation (Module 13):**
```sql
-- BCrypt hashed password (SECURE)
INSERT INTO users (username, email, password_hash)
VALUES ('testuser', 'test@example.com',
        '$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW');

-- Login verification with bcrypt (application layer)
-- SELECT * FROM users WHERE username = 'testuser';
-- Then compare: BCrypt.checkpw(inputPassword, user.getPasswordHash())
```

**BCrypt Hash Structure:**
```
$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW
│   │  │                      │
│   │  │                      └─ 31-char hash value
│   │  └─ 22-char salt
│   └─ Work factor (2^12 = 4096 iterations)
└─ Algorithm identifier (2a = bcrypt)

Total length: ~60 characters
```

**Security Considerations:**
- Never index password columns
- Never log password values
- Never send passwords in plain text
- Always use parameterized queries

#### balance

| Property | Value |
|----------|-------|
| **Data Type** | `DECIMAL(12,2)` |
| **Constraint** | `CHECK (balance >= 0)` |
| **Nullable** | NO (has default) |
| **Default** | `1000.00` |
| **Precision** | 12 total digits, 2 decimal places |
| **Purpose** | User account balance |

**Precision Details:**

```sql
-- DECIMAL(12,2) allows:
-- Maximum value: 9,999,999,999.99 (12 digits total, 2 after decimal)
-- Minimum value: 0.00 (enforced by CHECK constraint)

-- Valid balances
0.00                    -- Minimum (edge case)
1000.00                 -- Default for new users
9999999999.99           -- Maximum possible

-- Invalid balances (would fail CHECK constraint)
-0.01                   -- Negative values not allowed
-100.00                 -- Negative values not allowed

-- Invalid (precision violation)
99999999999.99          -- 13 digits total (exceeds DECIMAL(12,2))
```

**Why DECIMAL instead of FLOAT:**
- **DECIMAL** - Exact precision (no rounding errors)
- **FLOAT** - Approximate values (can have rounding errors)

```sql
-- Problem with FLOAT
0.1 + 0.2 = 0.30000000000000004 (rounding error)

-- DECIMAL precision
0.1 + 0.2 = 0.30 (exact)

-- Financial calculations require DECIMAL
```

**Balance Constraints:**
```sql
-- Enforce non-negative balance
CHECK (balance >= 0)

-- Prevent withdrawals that would go negative (application logic)
UPDATE users SET balance = balance - 150.00
WHERE user_id = 1 AND balance >= 150.00;
```

#### created_at

| Property | Value |
|----------|-------|
| **Data Type** | `TIMESTAMP` |
| **Constraint** | None |
| **Nullable** | YES (has default) |
| **Default** | `CURRENT_TIMESTAMP` |
| **Timezone** | No timezone (TIMESTAMP, not TIMESTAMPTZ) |
| **Purpose** | Record creation timestamp |

**Timestamp Behavior:**
```sql
-- Automatic timestamp on INSERT
INSERT INTO users (username, email, password_hash)
VALUES ('john', 'john@test.com', 'pass123');
-- created_at automatically set to: 2024-01-15 14:30:45.123456

-- Manual override (not recommended)
INSERT INTO users (username, email, password_hash, created_at)
VALUES ('alice', 'alice@test.com', 'pass456', '2023-01-01 00:00:00');
```

**Timestamp Formats:**
```sql
-- Default format
2024-01-15 14:30:45.123456

-- Format for display
SELECT
    username,
    TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_formatted
FROM users;

-- Extract components
SELECT
    username,
    EXTRACT(YEAR FROM created_at) as year,
    EXTRACT(MONTH FROM created_at) as month,
    EXTRACT(DAY FROM created_at) as day
FROM users;
```

**TIMESTAMP vs TIMESTAMPTZ:**
```sql
-- Current implementation (no timezone)
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- Stores: 2024-01-15 14:30:45

-- Recommended for production (with timezone)
created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
-- Stores: 2024-01-15 14:30:45+00:00
```

## Indexes

### Primary Key Index

```sql
-- Automatically created with PRIMARY KEY constraint
-- Name: users_pkey
CREATE UNIQUE INDEX users_pkey ON users(user_id);
```

**Properties:**
- Type: B-Tree
- Unique: YES
- Columns: user_id
- Purpose: Enforce uniqueness and optimize lookups by ID

### Unique Username Index

```sql
-- Automatically created with UNIQUE constraint
-- Name: users_username_key
CREATE UNIQUE INDEX users_username_key ON users(username);
```

**Properties:**
- Type: B-Tree
- Unique: YES
- Columns: username
- Purpose: Enforce username uniqueness

### Performance Username Index

```sql
-- Manually created for login optimization
-- Name: idx_users_username
CREATE INDEX idx_users_username ON users(username);
```

**Purpose:**
This index is redundant with the unique constraint index (`users_username_key`) but is created as a teaching exercise in Module 05 to demonstrate index creation.

**Note:** In production, this redundant index should be removed:
```sql
DROP INDEX idx_users_username;
-- Use users_username_key for all username lookups
```

### Index Usage Analysis

```sql
-- View all indexes on users table
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'users';

-- Expected output:
-- users_pkey (PRIMARY KEY)
-- users_username_key (UNIQUE)
-- idx_users_username (Performance - redundant)
```

**Index Size:**
```sql
-- Check index sizes
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes
WHERE tablename = 'users';

-- Example output:
-- indexname             | size
-- ----------------------|--------
-- users_pkey           | 16 kB
-- users_username_key   | 16 kB
-- idx_users_username   | 16 kB  (redundant)
```

## Constraints

### Summary Table

| Constraint Type | Column | Definition | Purpose |
|----------------|--------|------------|---------|
| PRIMARY KEY | user_id | SERIAL PRIMARY KEY | Unique identifier |
| UNIQUE | username | UNIQUE NOT NULL | Prevent duplicate usernames |
| NOT NULL | username | NOT NULL | Required field |
| NOT NULL | email | NOT NULL | Required field |
| NOT NULL | password_hash | NOT NULL | Required field |
| CHECK | balance | balance >= 0 | Prevent negative balances |
| DEFAULT | balance | DEFAULT 1000.00 | New user bonus |
| DEFAULT | created_at | DEFAULT CURRENT_TIMESTAMP | Auto-timestamp |

### Detailed Constraint Behavior

#### Primary Key Constraint

```sql
-- Enforces:
-- 1. Uniqueness
-- 2. NOT NULL
-- 3. One per table

-- Valid
INSERT INTO users (username, email, password_hash)
VALUES ('john', 'john@test.com', 'pass');  -- user_id = 1

-- Invalid (duplicate key)
INSERT INTO users (user_id, username, email, password_hash)
VALUES (1, 'alice', 'alice@test.com', 'pass');
-- ERROR: duplicate key value violates unique constraint "users_pkey"

-- Invalid (NULL not allowed)
INSERT INTO users (user_id, username, email, password_hash)
VALUES (NULL, 'bob', 'bob@test.com', 'pass');
-- ERROR: null value in column "user_id" violates not-null constraint
```

#### Check Constraint

```sql
-- Constraint: balance >= 0

-- Valid
UPDATE users SET balance = 0 WHERE user_id = 1;     -- OK
UPDATE users SET balance = 100.50 WHERE user_id = 1; -- OK

-- Invalid
UPDATE users SET balance = -0.01 WHERE user_id = 1;
-- ERROR: new row for relation "users" violates check constraint "users_balance_check"

-- Safe withdrawal pattern (application logic)
UPDATE users
SET balance = balance - 50.00
WHERE user_id = 1 AND balance >= 50.00;
-- Returns 0 rows if balance < 50.00 (prevents negative balance)
```

## Data Types

### PostgreSQL Type Details

| Type | Storage | Min Value | Max Value | Precision |
|------|---------|-----------|-----------|-----------|
| SERIAL | 4 bytes | 1 | 2,147,483,647 | Exact |
| VARCHAR(50) | 1 byte + string | - | 50 chars | N/A |
| VARCHAR(100) | 1 byte + string | - | 100 chars | N/A |
| VARCHAR(255) | 1 byte + string | - | 255 chars | N/A |
| DECIMAL(12,2) | Variable | -10^12 | 10^12 | Exact |
| TIMESTAMP | 8 bytes | 4713 BC | 294276 AD | 1 microsecond |

### Type Conversions

```sql
-- VARCHAR to TEXT (implicit)
SELECT username::TEXT FROM users;

-- DECIMAL to NUMERIC (same type)
SELECT balance::NUMERIC(10,2) FROM users;

-- TIMESTAMP to DATE
SELECT created_at::DATE FROM users;

-- INTEGER to VARCHAR
SELECT user_id::VARCHAR FROM users;
```

## Sample Data

### Minimal Test Dataset

```sql
-- Insert test users
INSERT INTO users (username, email, password_hash, balance) VALUES
    ('alice', 'alice@example.com', 'password123', 1500.00),
    ('bob', 'bob@example.com', 'securepass', 2000.50),
    ('charlie', 'charlie@example.com', 'mypass456', 500.00),
    ('diana', 'diana@example.com', 'pass789', 1000.00),
    ('eve', 'eve@example.com', 'evepass', 750.25);

-- Verify insertion
SELECT user_id, username, email, balance, created_at FROM users;
```

### Expected Output

```
 user_id | username |        email         | balance  |         created_at
---------+----------+----------------------+----------+----------------------------
       1 | alice    | alice@example.com    | 1500.00  | 2024-01-15 10:30:00.123456
       2 | bob      | bob@example.com      | 2000.50  | 2024-01-15 10:30:01.234567
       3 | charlie  | charlie@example.com  |  500.00  | 2024-01-15 10:30:02.345678
       4 | diana    | diana@example.com    | 1000.00  | 2024-01-15 10:30:03.456789
       5 | eve      | eve@example.com      |  750.25  | 2024-01-15 10:30:04.567890
```

## Query Patterns

### Authentication Queries

```sql
-- Login query (used by AuthController)
SELECT * FROM users WHERE username = 'alice';

-- Explain plan (with index)
EXPLAIN ANALYZE
SELECT * FROM users WHERE username = 'alice';
-- Result: Index Scan using users_username_key (cost=0.15..8.17 rows=1)

-- Check if username exists (registration)
SELECT EXISTS(SELECT 1 FROM users WHERE username = 'alice');
-- Returns: true or false
```

### Balance Queries

```sql
-- Get user balance
SELECT balance FROM users WHERE user_id = 1;

-- Get balance with formatting
SELECT
    username,
    TO_CHAR(balance, 'FM$999,999,990.00') as formatted_balance
FROM users;

-- Users with low balance (< $100)
SELECT username, balance
FROM users
WHERE balance < 100.00
ORDER BY balance ASC;
```

### Aggregate Queries

```sql
-- Total balance across all users
SELECT SUM(balance) as total_balance FROM users;

-- Average balance
SELECT AVG(balance) as average_balance FROM users;

-- User count
SELECT COUNT(*) as user_count FROM users;

-- Balance statistics
SELECT
    COUNT(*) as user_count,
    MIN(balance) as min_balance,
    MAX(balance) as max_balance,
    AVG(balance) as avg_balance,
    SUM(balance) as total_balance
FROM users;
```

### Date/Time Queries

```sql
-- Users created today
SELECT * FROM users WHERE created_at::DATE = CURRENT_DATE;

-- Users created in last 7 days
SELECT * FROM users WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days';

-- Group by registration month
SELECT
    TO_CHAR(created_at, 'YYYY-MM') as month,
    COUNT(*) as user_count
FROM users
GROUP BY month
ORDER BY month DESC;
```

## Performance Analysis

### Query Performance Metrics

#### Without Index

```sql
-- Remove index temporarily
DROP INDEX IF EXISTS idx_users_username;

-- Test query
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'alice';

-- Result (100,000 users):
-- Seq Scan on users (cost=0.00..2500.00 rows=1 width=100)
-- (actual time=45.234..50.123 rows=1 loops=1)
-- Planning Time: 0.123 ms
-- Execution Time: 50.234 ms
```

#### With Index

```sql
-- Recreate index
CREATE INDEX idx_users_username ON users(username);

-- Same query
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'alice';

-- Result (100,000 users):
-- Index Scan using users_username_key (cost=0.29..8.31 rows=1 width=100)
-- (actual time=0.012..0.015 rows=1 loops=1)
-- Planning Time: 0.089 ms
-- Execution Time: 0.023 ms
```

**Performance Improvement:** 2,184x faster (50.234ms → 0.023ms)

### Index Effectiveness

```sql
-- Check index usage statistics
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,    -- Number of times index was used
    idx_tup_read, -- Tuples read from index
    idx_tup_fetch -- Tuples fetched from table
FROM pg_stat_user_indexes
WHERE tablename = 'users';
```

## Schema Evolution

### Version History

| Version | Module | Changes | Migration |
|---------|--------|---------|-----------|
| 1.0 | Module 04 | Initial schema | CREATE TABLE users |
| 1.1 | Module 05 | Added username index | CREATE INDEX idx_users_username |
| 2.0 | Module 06 | Add transactions table | CREATE TABLE transactions |
| 2.1 | Module 13 | Enforce bcrypt passwords | Migrate passwords |
| 3.0 | Module 16 | Add sessions table | CREATE TABLE sessions |

### Future Schema Changes

#### Module 06: Transactions Table

```sql
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    balance_before DECIMAL(12,2) NOT NULL,
    balance_after DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Module 13: Password Migration

```sql
-- Add temporary column for bcrypt hash
ALTER TABLE users ADD COLUMN password_bcrypt VARCHAR(255);

-- Migrate passwords (requires application logic)
-- UPDATE users SET password_bcrypt = bcrypt(password_hash, 12);

-- Swap columns
ALTER TABLE users DROP COLUMN password_hash;
ALTER TABLE users RENAME COLUMN password_bcrypt TO password_hash;
ALTER TABLE users ALTER COLUMN password_hash SET NOT NULL;
```

---

**Schema Documentation Version:** 1.0
**Last Updated:** January 2024
**Module:** 05 - SampleBank v2 Login System
