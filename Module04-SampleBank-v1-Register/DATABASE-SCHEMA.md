# Database Schema Documentation

## Table of Contents
1. [Database Overview](#database-overview)
2. [Schema Design](#schema-design)
3. [Table Definitions](#table-definitions)
4. [Constraints and Indexes](#constraints-and-indexes)
5. [Data Types Explained](#data-types-explained)
6. [Sample Data](#sample-data)
7. [Database Operations](#database-operations)
8. [Schema Evolution](#schema-evolution)
9. [Performance Considerations](#performance-considerations)
10. [Backup and Maintenance](#backup-and-maintenance)

## Database Overview

### Database Information

**Database Name:** `samplebank1`
**DBMS:** PostgreSQL 12+
**Character Encoding:** UTF-8
**Collation:** Default (en_US.UTF-8 or system default)
**Schema:** `public` (default schema)

### Purpose

This database stores user account information for the SampleBank application, specifically designed for the registration module. It maintains user credentials, email addresses, account balances, and registration timestamps.

### Database Size Estimate

For educational purposes with typical usage:
- Empty database: ~8 MB (PostgreSQL system tables)
- Per user record: ~300 bytes
- 1,000 users: ~8.3 MB
- 10,000 users: ~10 MB
- 100,000 users: ~30 MB

## Schema Design

### Entity-Relationship Model

```
┌────────────────────────────────────────────────────┐
│                      users                         │
├────────────────────────────────────────────────────┤
│ PK  user_id         SERIAL                         │
│ UQ  username        VARCHAR(50)    NOT NULL        │
│     email           VARCHAR(100)   NOT NULL        │
│     password_hash   VARCHAR(255)   NOT NULL        │
│     balance         DECIMAL(12,2)  DEFAULT 1000.00 │
│     created_at      TIMESTAMP      DEFAULT NOW()   │
└────────────────────────────────────────────────────┘

Relationships: None (single table in this module)
Future: Will relate to transactions, accounts, audit_logs
```

### Normalization Level

**Current:** First Normal Form (1NF)
- All fields contain atomic values
- No repeating groups
- Primary key defined

**Future Modules:** Will implement higher normalization
- Separate tables for accounts, transactions, audit logs
- Foreign key relationships
- Junction tables for many-to-many relationships

### Design Decisions

**Why Single Table?**
- Educational simplicity for Module 04
- Focuses on registration fundamentals
- Minimizes complexity for beginners
- Future modules will extend schema

**Why SERIAL for Primary Key?**
- Auto-incrementing integers
- Simple and efficient for small-to-medium databases
- PostgreSQL native type
- Easy to understand for students

**Why VARCHAR for Username?**
- Variable-length saves space
- Max 50 characters is reasonable for usernames
- Fixed-length CHAR would waste space

**Why DECIMAL for Balance?**
- Precise monetary calculations (no floating-point errors)
- DECIMAL(12,2) supports up to $9,999,999,999.99
- Industry standard for financial data

## Table Definitions

### Table: users

**Purpose:** Stores registered user account information

**Full SQL Definition:**

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

### Column Reference

#### user_id

| Property      | Value                              |
|---------------|------------------------------------|
| Data Type     | SERIAL (equivalent to INTEGER)     |
| Constraint    | PRIMARY KEY                        |
| Auto-Increment| Yes (via sequence)                 |
| Nullable      | No (implicit with PRIMARY KEY)     |
| Default       | Auto-generated                     |
| Purpose       | Unique identifier for each user    |

**Usage:**
- Referenced in JPA `@Id` annotation
- Used for foreign key relationships (future modules)
- Efficient for joins and lookups

**Sequence Details:**
```sql
-- PostgreSQL automatically creates sequence
CREATE SEQUENCE users_user_id_seq;

-- View sequence details
SELECT * FROM users_user_id_seq;

-- Reset sequence (use carefully!)
ALTER SEQUENCE users_user_id_seq RESTART WITH 1;
```

#### username

| Property      | Value                                     |
|---------------|-------------------------------------------|
| Data Type     | VARCHAR(50)                               |
| Constraint    | UNIQUE, NOT NULL                          |
| Max Length    | 50 characters                             |
| Nullable      | No                                        |
| Default       | None (must be provided)                   |
| Purpose       | User's login identifier                   |

**Validation Rules:**
- Must be unique across all users
- Cannot be NULL or empty
- Maximum 50 characters
- Case-sensitive in PostgreSQL (use LOWER() for case-insensitive searches)

**Recommended Practices:**
- Allow alphanumeric characters, underscores, hyphens
- Minimum 3 characters
- No spaces
- Example pattern: `^[a-zA-Z0-9_-]{3,50}$`

**Example Queries:**
```sql
-- Check if username exists
SELECT EXISTS(SELECT 1 FROM users WHERE username = 'john_doe');

-- Case-insensitive search
SELECT * FROM users WHERE LOWER(username) = LOWER('John_Doe');

-- Find usernames starting with 'test'
SELECT username FROM users WHERE username LIKE 'test%';
```

#### email

| Property      | Value                                     |
|---------------|-------------------------------------------|
| Data Type     | VARCHAR(100)                              |
| Constraint    | NOT NULL                                  |
| Max Length    | 100 characters                            |
| Nullable      | No                                        |
| Default       | None (must be provided)                   |
| Purpose       | User's email address                      |

**Validation Rules:**
- Cannot be NULL or empty
- Maximum 100 characters
- Should contain valid email format (application-level validation)

**Note on Uniqueness:**
- Currently NOT unique (allows multiple accounts per email)
- Consider adding UNIQUE constraint for production systems
- Future modules may add email verification

**Recommended Practices:**
- Validate email format: `user@domain.tld`
- Convert to lowercase before storage
- Add email verification workflow
- Consider adding unique constraint

**Example Queries:**
```sql
-- Find users by email domain
SELECT * FROM users WHERE email LIKE '%@gmail.com';

-- Count users per domain
SELECT
    SUBSTRING(email FROM '@(.*)$') as domain,
    COUNT(*) as user_count
FROM users
GROUP BY domain;

-- Find duplicate emails
SELECT email, COUNT(*)
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

#### password_hash

| Property      | Value                                     |
|---------------|-------------------------------------------|
| Data Type     | VARCHAR(255)                              |
| Constraint    | NOT NULL                                  |
| Max Length    | 255 characters                            |
| Nullable      | No                                        |
| Default       | None (must be provided)                   |
| Purpose       | User's password storage                   |

**Current Implementation:**
- **WARNING:** Stores plain text passwords (educational demo only)
- Production systems must hash passwords before storage

**Production Requirements:**
- Use BCrypt, Argon2, or PBKDF2
- Store hash only, never plain text
- Include salt (BCrypt includes salt automatically)
- Minimum 8 characters for user passwords
- Example BCrypt hash length: 60 characters

**Future Implementation Example:**
```java
// Using Spring Security BCrypt
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
String hashedPassword = encoder.encode(plainTextPassword);
// Store hashedPassword in database (not plainTextPassword!)
```

**Example Hash:**
```
Plain: mypassword123
BCrypt: $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy
Length: 60 characters
```

#### balance

| Property      | Value                                     |
|---------------|-------------------------------------------|
| Data Type     | DECIMAL(12,2)                             |
| Constraint    | CHECK (balance >= 0), DEFAULT 1000.00     |
| Precision     | 12 digits total, 2 after decimal          |
| Nullable      | Yes (but defaults to 1000.00)             |
| Default       | 1000.00                                   |
| Purpose       | User's account balance in dollars         |

**Precision Explained:**
- DECIMAL(12,2) = 12 total digits, 2 after decimal point
- Integer part: 10 digits (12 - 2)
- Range: -9999999999.99 to +9999999999.99
- With CHECK constraint: 0.00 to +9999999999.99

**Why DECIMAL, Not FLOAT?**
```sql
-- WRONG: Float has precision errors
-- 0.1 + 0.2 = 0.30000000000000004 (in binary float)

-- CORRECT: DECIMAL has exact precision
-- 0.10 + 0.20 = 0.30 (exact)
```

**Default Value Behavior:**
- New users start with $1,000.00
- Set in both database DEFAULT and JPA @PrePersist
- Double safety: database + application level

**Business Rules:**
- Balance cannot be negative (CHECK constraint)
- Enforced at database level
- Transactions will modify this value (future modules)

**Example Queries:**
```sql
-- Find users with low balance
SELECT username, balance FROM users WHERE balance < 100.00;

-- Calculate total deposits across all users
SELECT SUM(balance) as total_deposits FROM users;

-- Find richest users
SELECT username, balance FROM users ORDER BY balance DESC LIMIT 10;

-- Update balance (future: will use transactions)
UPDATE users SET balance = balance + 500.00 WHERE username = 'john_doe';
```

#### created_at

| Property      | Value                                     |
|---------------|-------------------------------------------|
| Data Type     | TIMESTAMP                                 |
| Constraint    | DEFAULT CURRENT_TIMESTAMP                 |
| Nullable      | Yes (but defaults to current time)        |
| Default       | CURRENT_TIMESTAMP                         |
| Purpose       | Timestamp of account registration         |

**Timestamp Format:**
- Format: `YYYY-MM-DD HH:MI:SS.ssssss`
- Example: `2025-01-23 14:30:45.123456`
- Precision: Microseconds (6 decimal places)
- Timezone: No timezone (stores local time)

**Storage Details:**
- Stored as 8-byte integer (microseconds since epoch)
- Date range: 4713 BC to 294276 AD
- Efficient for sorting and filtering

**Default Behavior:**
- Automatically set on INSERT
- Uses database server time (not application server)
- Also set by JPA @PrePersist for consistency

**Example Queries:**
```sql
-- Find recent registrations (last 7 days)
SELECT * FROM users WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '7 days';

-- Count registrations per day
SELECT
    DATE(created_at) as registration_date,
    COUNT(*) as user_count
FROM users
GROUP BY DATE(created_at)
ORDER BY registration_date DESC;

-- Find oldest accounts
SELECT username, created_at FROM users ORDER BY created_at ASC LIMIT 10;

-- Format timestamp for display
SELECT username, TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as registered
FROM users;
```

## Constraints and Indexes

### Primary Key Constraint

**Name:** `users_pkey` (auto-generated by PostgreSQL)

**Definition:**
```sql
ALTER TABLE users ADD PRIMARY KEY (user_id);
```

**Purpose:**
- Ensures each user has a unique identifier
- Creates clustered index for fast lookups
- Prevents duplicate or NULL user_id values

**Performance Impact:**
- Fast lookups by user_id: O(log n)
- Index automatically maintained on INSERT/UPDATE/DELETE

### Unique Constraint

**Name:** `users_username_key` (auto-generated)

**Definition:**
```sql
ALTER TABLE users ADD CONSTRAINT users_username_key UNIQUE (username);
```

**Purpose:**
- Ensures no duplicate usernames
- Creates non-clustered index for fast username lookups
- Prevents registration with existing username

**Performance Impact:**
- Fast lookups by username: O(log n)
- Slight overhead on INSERT (index update)

**View Constraint:**
```sql
-- List all constraints on users table
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'users'::regclass;
```

### Check Constraint

**Name:** `users_balance_check` (auto-generated)

**Definition:**
```sql
ALTER TABLE users ADD CONSTRAINT users_balance_check CHECK (balance >= 0);
```

**Purpose:**
- Enforces business rule: balance cannot be negative
- Database-level validation (defense in depth)
- Prevents invalid data even if application has bugs

**Behavior:**
```sql
-- This will succeed
UPDATE users SET balance = 0 WHERE user_id = 1;

-- This will fail with error
UPDATE users SET balance = -100 WHERE user_id = 1;
-- ERROR: new row for relation "users" violates check constraint "users_balance_check"
```

### Indexes

**Automatically Created Indexes:**

1. **Primary Key Index** on `user_id`
   - Type: B-tree
   - Unique: Yes
   - Purpose: Fast lookups by user_id

2. **Unique Index** on `username`
   - Type: B-tree
   - Unique: Yes
   - Purpose: Fast lookups and uniqueness check

**View Indexes:**
```sql
-- List all indexes on users table
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'users';
```

**Future Index Considerations:**
```sql
-- If frequently searching by email, add index
CREATE INDEX idx_users_email ON users(email);

-- If frequently searching by created_at ranges
CREATE INDEX idx_users_created_at ON users(created_at);

-- For case-insensitive username searches
CREATE INDEX idx_users_username_lower ON users(LOWER(username));
```

## Data Types Explained

### SERIAL

**Definition:** Pseudo-type that creates auto-incrementing integer

**Under the Hood:**
```sql
-- SERIAL is shorthand for:
user_id INTEGER NOT NULL,
CREATE SEQUENCE users_user_id_seq OWNED BY users.user_id,
ALTER TABLE users ALTER COLUMN user_id SET DEFAULT nextval('users_user_id_seq')
```

**Characteristics:**
- Equivalent to INTEGER (4 bytes, -2147483648 to +2147483647)
- BIGSERIAL for larger range (8 bytes, up to 9 quintillion)
- Thread-safe and concurrent
- No gaps guaranteed (sequence may skip numbers)

**Alternatives:**
- `IDENTITY` (SQL standard, newer PostgreSQL versions)
- `UUID` for distributed systems

### VARCHAR(n)

**Definition:** Variable-length character string with maximum length n

**Storage:**
- Actual length + 1 or 4 bytes overhead
- Example: `'hello'` in VARCHAR(50) uses 6 bytes, not 50

**Comparison:**
- `CHAR(n)`: Fixed-length, space-padded
- `TEXT`: Unlimited length (same as VARCHAR without limit)

**Best Practices:**
- Use VARCHAR when maximum length is known
- Use TEXT for unlimited or very long text
- Specify reasonable length for validation

### DECIMAL(p, s)

**Definition:** Exact numeric type with precision (p) and scale (s)

**Parameters:**
- `p` (precision): Total number of digits
- `s` (scale): Number of digits after decimal point
- DECIMAL(12,2): Up to 12 total digits, 2 after decimal

**Storage:**
- Variable (approximately 2 bytes per 4 digits)
- DECIMAL(12,2): About 7 bytes

**Comparison:**
```
DECIMAL(12,2): Exact (1234567890.12)
FLOAT/DOUBLE: Approximate (1234567890.119999885559...)
```

**Alternatives:**
- `NUMERIC`: Exact synonym for DECIMAL
- `REAL`/`DOUBLE PRECISION`: Faster but imprecise
- `MONEY`: PostgreSQL currency type (not portable)

### TIMESTAMP

**Definition:** Date and time without timezone

**Storage:**
- 8 bytes
- Microsecond precision
- Range: 4713 BC to 294276 AD

**Variants:**
- `TIMESTAMP`: No timezone
- `TIMESTAMPTZ`: With timezone (recommended for multi-timezone apps)

**Functions:**
```sql
CURRENT_TIMESTAMP  -- Current date/time with timezone
NOW()              -- Same as CURRENT_TIMESTAMP
CURRENT_DATE       -- Current date only
CURRENT_TIME       -- Current time only
```

**Formatting:**
```sql
TO_CHAR(created_at, 'YYYY-MM-DD')           -- 2025-01-23
TO_CHAR(created_at, 'DD/MM/YYYY HH24:MI')   -- 23/01/2025 14:30
```

## Sample Data

### Initial State (Empty Table)

```sql
SELECT * FROM users;
-- Returns: 0 rows
```

### After Registration (Sample Records)

```sql
INSERT INTO users (username, email, password_hash) VALUES
('john_doe', 'john@example.com', 'pass123'),
('alice_w', 'alice@example.com', 'secret456'),
('bob_smith', 'bob@example.com', 'mypass789');

SELECT * FROM users;
```

**Result:**
```
 user_id | username   | email              | password_hash | balance  | created_at
---------|------------|--------------------|--------------|---------|--------------------------
 1       | john_doe   | john@example.com   | pass123      | 1000.00 | 2025-01-23 14:30:15.123456
 2       | alice_w    | alice@example.com  | secret456    | 1000.00 | 2025-01-23 14:30:20.654321
 3       | bob_smith  | bob@example.com    | mypass789    | 1000.00 | 2025-01-23 14:30:25.987654
```

### Test Data Script

```sql
-- Insert test users
INSERT INTO users (username, email, password_hash) VALUES
('testuser1', 'test1@example.com', 'test1'),
('testuser2', 'test2@example.com', 'test2'),
('testuser3', 'test3@example.com', 'test3'),
('testuser4', 'test4@example.com', 'test4'),
('testuser5', 'test5@example.com', 'test5');

-- Verify insertion
SELECT COUNT(*) as total_users FROM users;

-- View summary
SELECT
    MIN(user_id) as first_user_id,
    MAX(user_id) as last_user_id,
    COUNT(*) as total_users,
    SUM(balance) as total_balance
FROM users;
```

## Database Operations

### Common Queries

**Create (INSERT):**
```sql
INSERT INTO users (username, email, password_hash)
VALUES ('newuser', 'new@example.com', 'password123');
```

**Read (SELECT):**
```sql
-- Get all users
SELECT * FROM users;

-- Get specific user
SELECT * FROM users WHERE username = 'john_doe';

-- Get users with pagination
SELECT * FROM users ORDER BY user_id LIMIT 10 OFFSET 0;
```

**Update:**
```sql
-- Update email
UPDATE users SET email = 'newemail@example.com' WHERE username = 'john_doe';

-- Update balance (future: will use transactions)
UPDATE users SET balance = balance + 100 WHERE username = 'john_doe';
```

**Delete:**
```sql
-- Delete specific user
DELETE FROM users WHERE username = 'testuser';

-- Delete all test users
DELETE FROM users WHERE username LIKE 'test%';
```

### Maintenance Queries

**Table Statistics:**
```sql
-- Table size
SELECT pg_size_pretty(pg_total_relation_size('users')) as total_size;

-- Row count
SELECT COUNT(*) FROM users;

-- Detailed table info
\d+ users
```

**Analyze Table:**
```sql
ANALYZE users;
```

**Vacuum (Cleanup):**
```sql
VACUUM ANALYZE users;
```

## Schema Evolution

### Current Version: 1.0 (Module 04)

**Tables:** users
**Features:** Registration only

### Future Versions

**Version 1.1 (Module 05):**
- Add password reset tokens
- Add email verification flags

**Version 2.0 (Module 06):**
- Add accounts table (separate from users)
- Foreign key: accounts.user_id → users.user_id

**Version 3.0 (Module 07):**
- Add transactions table
- Foreign keys: transactions.from_user_id, transactions.to_user_id

**Version 4.0 (Module 08):**
- Add audit_logs table
- Add user roles and permissions

## Performance Considerations

### Current Performance

**Table Size:** Minimal (< 10 MB for typical student usage)
**Indexes:** Sufficient for current operations
**Query Performance:** Excellent (small dataset)

### Optimization Tips

**For Large-Scale Deployments:**
1. Add index on email if frequently searched
2. Partition table by created_at for time-series data
3. Use connection pooling (HikariCP already configured)
4. Enable query plan caching

## Backup and Maintenance

### Backup Commands

**Full Database Backup:**
```bash
pg_dump -U postgres samplebank1 > backup.sql
```

**Table-Only Backup:**
```bash
pg_dump -U postgres -t users samplebank1 > users_backup.sql
```

**Restore:**
```bash
psql -U postgres -d samplebank1 < backup.sql
```

### Maintenance Schedule

**Daily:** Automatic vacuum (PostgreSQL autovacuum)
**Weekly:** ANALYZE for query planning
**Monthly:** Full backup for educational projects

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Schema Version:** Module 04 - Registration Only
