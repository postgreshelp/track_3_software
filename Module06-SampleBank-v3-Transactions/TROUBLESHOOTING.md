# SampleBank v3 - Troubleshooting Guide

## Table of Contents
1. [Transaction Failures](#transaction-failures)
2. [Database Deadlocks](#database-deadlocks)
3. [Rollback Issues](#rollback-issues)
4. [Concurrency Problems](#concurrency-problems)
5. [Balance Inconsistencies](#balance-inconsistencies)
6. [Connection Issues](#connection-issues)
7. [Performance Problems](#performance-problems)
8. [API Errors](#api-errors)
9. [Common Error Messages](#common-error-messages)
10. [Diagnostic Queries](#diagnostic-queries)

## Transaction Failures

### Problem: Transfer Returns "ERROR: Transaction failed"

**Symptoms:**
- Generic error message without specific details
- Balance unchanged
- No transaction record created

**Possible Causes:**

1. **Database constraint violation**
2. **Network interruption during transfer**
3. **Stored procedure exception**

**Diagnosis:**

```sql
-- Check PostgreSQL logs
SELECT * FROM pg_stat_activity WHERE datname = 'samplebank';

-- Review error logs
SHOW log_directory;
SHOW log_filename;
```

**Solutions:**

1. **Check constraint violations:**
```sql
-- Verify CHECK constraints
SELECT conname, contype, consrc
FROM pg_constraint
WHERE conrelid = 'transactions'::regclass;

-- Test constraints
SELECT transfer_money('alice', 'bob', 0.00);  -- Should fail: amount > 0
SELECT transfer_money('alice', 'alice', 100.00);  -- Should fail: self-transfer
```

2. **Review stored procedure code:**
```sql
-- Check for bugs in transfer_money()
\df+ transfer_money

-- Add debugging with RAISE NOTICE
CREATE OR REPLACE FUNCTION transfer_money(...) RETURNS TEXT AS $$
BEGIN
    RAISE NOTICE 'Sender: %, Receiver: %, Amount: %', p_from_username, p_to_username, p_amount;
    -- ... rest of function
END;
$$ LANGUAGE plpgsql;
```

3. **Enable detailed error logging:**
```properties
# application.properties
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

### Problem: Transfer Succeeds But Balance Unchanged

**Symptoms:**
- API returns "SUCCESS" message
- Transaction record created
- User balance remains the same

**Diagnosis:**

```sql
-- Check if update happened
SELECT balance FROM users WHERE username = 'alice';

-- Check transaction record
SELECT * FROM transactions ORDER BY created_at DESC LIMIT 1;

-- Compare transaction amounts with balance changes
WITH user_balance_check AS (
    SELECT
        u.user_id,
        u.username,
        u.balance AS current_balance,
        1000.00 + COALESCE(SUM(tr.amount), 0) - COALESCE(SUM(ts.amount), 0) AS calculated_balance
    FROM users u
    LEFT JOIN transactions tr ON u.user_id = tr.to_user_id
    LEFT JOIN transactions ts ON u.user_id = ts.from_user_id
    GROUP BY u.user_id, u.username, u.balance
)
SELECT * FROM user_balance_check WHERE current_balance != calculated_balance;
```

**Solutions:**

1. **Verify stored procedure logic:**
```sql
-- Recreate transfer_money() with correct logic
-- Ensure UPDATE statements execute
-- Check for missing COMMIT
```

2. **Test manually:**
```sql
BEGIN;
UPDATE users SET balance = balance - 100 WHERE username = 'alice';
UPDATE users SET balance = balance + 100 WHERE username = 'bob';
COMMIT;

-- Verify changes
SELECT username, balance FROM users WHERE username IN ('alice', 'bob');
```

3. **Check transaction isolation:**
```sql
-- Verify isolation level
SHOW transaction_isolation;

-- Should be 'read committed' (default)
```

### Problem: Duplicate Transactions Created

**Symptoms:**
- Single transfer creates multiple transaction records
- Balance deducted multiple times
- API called once but multiple records appear

**Diagnosis:**

```sql
-- Check for duplicates
SELECT
    from_user_id,
    to_user_id,
    amount,
    created_at,
    COUNT(*) as duplicate_count
FROM transactions
GROUP BY from_user_id, to_user_id, amount, created_at
HAVING COUNT(*) > 1;
```

**Solutions:**

1. **Add idempotency key:**
```sql
-- Add unique constraint for deduplication
ALTER TABLE transactions ADD COLUMN idempotency_key VARCHAR(100) UNIQUE;
```

2. **Check for double-submit:**
```javascript
// In dashboard.html, prevent double-submit
let isSubmitting = false;

document.getElementById('transferForm').addEventListener('submit', async function(e) {
    e.preventDefault();

    if (isSubmitting) {
        return;  // Prevent double submission
    }

    isSubmitting = true;
    try {
        // ... perform transfer
    } finally {
        isSubmitting = false;
    }
});
```

3. **Review retry logic:**
```java
// Ensure no automatic retries in controller
// Check for duplicate EntityManager calls
```

## Database Deadlocks

### Problem: Deadlock Detected Error

**Symptoms:**
- Error: "deadlock detected"
- Transaction aborted
- Intermittent failures under concurrent load

**Example Deadlock Scenario:**
```
Transaction 1: Locks Alice, waits for Bob
Transaction 2: Locks Bob, waits for Alice
Result: Deadlock!
```

**Diagnosis:**

```sql
-- Enable deadlock logging
ALTER SYSTEM SET deadlock_timeout = '1s';
ALTER SYSTEM SET log_lock_waits = on;
SELECT pg_reload_conf();

-- Check for deadlocks in logs
SELECT query, state, wait_event_type, wait_event
FROM pg_stat_activity
WHERE wait_event IS NOT NULL;

-- View lock information
SELECT
    locktype,
    relation::regclass,
    mode,
    granted,
    pid
FROM pg_locks
WHERE NOT granted;
```

**Solutions:**

1. **Lock resources in consistent order:**
```sql
-- Always lock lower user_id first
CREATE OR REPLACE FUNCTION transfer_money(...) RETURNS TEXT AS $$
DECLARE
    v_first_user_id INT;
    v_second_user_id INT;
BEGIN
    -- Determine lock order
    IF v_from_user_id < v_to_user_id THEN
        v_first_user_id := v_from_user_id;
        v_second_user_id := v_to_user_id;
    ELSE
        v_first_user_id := v_to_user_id;
        v_second_user_id := v_from_user_id;
    END IF;

    -- Lock in order using SELECT FOR UPDATE
    PERFORM * FROM users WHERE user_id = v_first_user_id FOR UPDATE;
    PERFORM * FROM users WHERE user_id = v_second_user_id FOR UPDATE;

    -- Now perform updates safely
    -- ... rest of function
END;
$$ LANGUAGE plpgsql;
```

2. **Use explicit locking:**
```sql
-- Lock both rows before updates
SELECT * FROM users WHERE user_id IN (v_from_user_id, v_to_user_id) FOR UPDATE;
```

3. **Reduce transaction duration:**
```sql
-- Keep transactions short
-- Avoid long-running queries within transactions
-- Commit as soon as possible
```

4. **Implement retry logic:**
```java
// In TransferController.java
@Transactional
public ResponseEntity<String> transfer(...) {
    int maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
        try {
            // Attempt transfer
            return executeTransfer(...);
        } catch (DeadlockLoserDataAccessException e) {
            if (i == maxRetries - 1) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body("ERROR: Transaction conflict, please retry");
            }
            // Wait before retry
            Thread.sleep(100);
        }
    }
}
```

### Problem: Long Lock Wait Times

**Symptoms:**
- Transfers hang for several seconds
- Some transfers timeout
- Poor performance under load

**Diagnosis:**

```sql
-- Check current locks
SELECT
    pl.pid,
    pl.locktype,
    pl.mode,
    pl.granted,
    a.query,
    a.state,
    age(now(), a.query_start) AS query_age
FROM pg_locks pl
JOIN pg_stat_activity a ON pl.pid = a.pid
WHERE NOT pl.granted;

-- Find blocking queries
SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';
```

**Solutions:**

1. **Terminate blocking queries:**
```sql
-- View blocking processes
SELECT pg_cancel_backend(pid);  -- Gentle termination
SELECT pg_terminate_backend(pid);  -- Forceful termination
```

2. **Reduce lock duration:**
```sql
-- Set statement timeout
SET statement_timeout = '5s';

-- Or in application.properties
spring.datasource.hikari.connection-timeout=5000
```

3. **Optimize queries:**
```sql
-- Use indexes to speed up queries
-- Avoid full table scans within transactions
```

## Rollback Issues

### Problem: Changes Not Rolled Back on Error

**Symptoms:**
- Error occurs but partial changes persist
- Sender balance deducted, receiver not credited
- Transaction record created without balance changes

**Diagnosis:**

```sql
-- Check if autocommit is on
SHOW autocommit;  -- Should be 'off' for transactions

-- Test rollback behavior
BEGIN;
UPDATE users SET balance = balance - 100 WHERE username = 'alice';
SELECT balance FROM users WHERE username = 'alice';  -- Should show reduced balance
ROLLBACK;
SELECT balance FROM users WHERE username = 'alice';  -- Should show original balance
```

**Solutions:**

1. **Ensure proper transaction boundaries:**
```sql
CREATE OR REPLACE FUNCTION transfer_money(...) RETURNS TEXT AS $$
BEGIN
    -- All operations within function are atomic
    -- If any fails, all rollback automatically
    -- No explicit BEGIN/COMMIT needed in PL/pgSQL function
    ...
EXCEPTION
    WHEN OTHERS THEN
        -- Automatic rollback on exception
        RETURN 'ERROR: Transaction failed';
END;
$$ LANGUAGE plpgsql;
```

2. **Verify stored procedure exception handling:**
```sql
-- Test explicit error
CREATE OR REPLACE FUNCTION transfer_money_test(...) RETURNS TEXT AS $$
BEGIN
    UPDATE users SET balance = balance - p_amount WHERE user_id = v_from_user_id;
    RAISE EXCEPTION 'Intentional error';  -- Force rollback
    UPDATE users SET balance = balance + p_amount WHERE user_id = v_to_user_id;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: Transaction failed';
END;
$$ LANGUAGE plpgsql;

-- Execute and verify no changes persisted
SELECT transfer_money_test('alice', 'bob', 100.00);
SELECT balance FROM users WHERE username IN ('alice', 'bob');
```

3. **Check application-level transactions:**
```java
// Ensure @Transactional annotation is present
@Transactional
public ResponseEntity<String> transfer(...) {
    // All database operations rollback on exception
}
```

### Problem: Cannot Rollback After Commit

**Symptoms:**
- Error occurs after commit
- Want to undo transaction
- Changes already persisted

**Solution:**

```sql
-- Cannot rollback after commit!
-- Must create compensating transaction

-- If $100 was transferred incorrectly:
-- Create reverse transfer
SELECT transfer_money('bob', 'alice', 100.00);

-- Or manually correct
BEGIN;
UPDATE users SET balance = balance + 100 WHERE username = 'alice';
UPDATE users SET balance = balance - 100 WHERE username = 'bob';
INSERT INTO transactions (from_user_id, to_user_id, amount, note)
VALUES (2, 1, 100.00, 'Reversal of incorrect transaction');
COMMIT;
```

## Concurrency Problems

### Problem: Lost Updates

**Symptoms:**
- Two transfers from same account succeed
- Balance lower than expected
- Sum of transfers exceeds original balance

**Example:**
```
Initial balance: $1000
T1: Transfer $700 (reads $1000, writes $300)
T2: Transfer $600 (reads $1000, writes $400)
Result: Balance is $400, but should be -$300 (error)
```

**Diagnosis:**

```sql
-- Simulate lost update
BEGIN;
SELECT balance FROM users WHERE username = 'alice';  -- $1000
-- [Another transaction updates balance to $300]
UPDATE users SET balance = 400 WHERE username = 'alice';  -- Lost update!
COMMIT;
```

**Solutions:**

1. **Use SELECT FOR UPDATE:**
```sql
-- Lock the row for update
SELECT balance FROM users WHERE username = 'alice' FOR UPDATE;
-- Other transactions will wait for lock release
```

2. **Optimistic locking with version column:**
```sql
-- Add version column
ALTER TABLE users ADD COLUMN version INT DEFAULT 0;

-- Update with version check
UPDATE users
SET balance = balance - 100, version = version + 1
WHERE username = 'alice' AND version = 5;

-- Check rows affected
GET DIAGNOSTICS rows_affected = ROW_COUNT;
IF rows_affected = 0 THEN
    RAISE EXCEPTION 'Concurrent modification detected';
END IF;
```

3. **Use atomic operations:**
```sql
-- Atomic decrement (safe)
UPDATE users SET balance = balance - 100 WHERE username = 'alice';

-- vs. Non-atomic read-modify-write (unsafe)
-- balance = SELECT balance; -- Read
-- balance = balance - 100;   -- Modify
-- UPDATE users SET balance = balance; -- Write (lost update risk)
```

### Problem: Race Conditions

**Symptoms:**
- Inconsistent results with concurrent transfers
- Sometimes succeeds, sometimes fails
- Balance occasionally goes negative (violates CHECK)

**Diagnosis:**

```bash
# Test race condition
for i in {1..10}; do
    ./concurrent_test.sh
    curl http://localhost:8080/balance/alice
    sleep 1
done
```

**Solutions:**

1. **Proper isolation level:**
```sql
-- Use appropriate isolation level
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Or in Spring Boot
@Transactional(isolation = Isolation.SERIALIZABLE)
```

2. **Application-level locks:**
```java
// Synchronized method (not ideal for distributed systems)
private synchronized void executeTransfer(...) {
    // Only one thread at a time
}

// Better: Database-level locking via SELECT FOR UPDATE
```

## Balance Inconsistencies

### Problem: Balance Doesn't Match Transaction History

**Symptoms:**
- User balance incorrect
- Sum of transactions doesn't match balance
- Negative balance despite CHECK constraint

**Diagnosis:**

```sql
-- Audit balance calculation
WITH balance_audit AS (
    SELECT
        u.user_id,
        u.username,
        u.balance AS stored_balance,
        1000.00 AS starting_balance,
        COALESCE(SUM(tr.amount), 0) AS total_received,
        COALESCE(SUM(ts.amount), 0) AS total_sent,
        1000.00 + COALESCE(SUM(tr.amount), 0) - COALESCE(SUM(ts.amount), 0) AS calculated_balance
    FROM users u
    LEFT JOIN transactions tr ON u.user_id = tr.to_user_id
    LEFT JOIN transactions ts ON u.user_id = ts.from_user_id
    GROUP BY u.user_id, u.username, u.balance
)
SELECT
    *,
    stored_balance - calculated_balance AS discrepancy
FROM balance_audit
WHERE stored_balance != calculated_balance;
```

**Solutions:**

1. **Recalculate and fix balances:**
```sql
-- Backup first!
CREATE TABLE users_backup AS SELECT * FROM users;

-- Recalculate correct balances
UPDATE users u
SET balance = (
    1000.00 +
    COALESCE((SELECT SUM(amount) FROM transactions WHERE to_user_id = u.user_id), 0) -
    COALESCE((SELECT SUM(amount) FROM transactions WHERE from_user_id = u.user_id), 0)
);

-- Verify
SELECT * FROM balance_audit WHERE stored_balance != calculated_balance;
```

2. **Prevent future inconsistencies:**
```sql
-- Add balance validation trigger
CREATE OR REPLACE FUNCTION validate_balance() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.balance < 0 THEN
        RAISE EXCEPTION 'Balance cannot be negative';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_balance_trigger
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION validate_balance();
```

### Problem: Negative Balance Despite CHECK Constraint

**Symptoms:**
- User has negative balance
- CHECK constraint should prevent this
- Transaction succeeded anyway

**Possible Causes:**
1. CHECK constraint disabled
2. Direct UPDATE bypassing constraint
3. Constraint removed/altered

**Diagnosis:**

```sql
-- Verify CHECK constraint exists
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'users'::regclass AND contype = 'c';

-- Check if constraint is valid
SELECT conname, convalidated
FROM pg_constraint
WHERE conrelid = 'users'::regclass;
```

**Solutions:**

```sql
-- Recreate CHECK constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_balance_check;
ALTER TABLE users ADD CONSTRAINT users_balance_check CHECK (balance >= 0);

-- Validate existing data
ALTER TABLE users VALIDATE CONSTRAINT users_balance_check;

-- Fix negative balances
UPDATE users SET balance = 0 WHERE balance < 0;
```

## Connection Issues

### Problem: Database Connection Refused

**Symptoms:**
- Error: "Connection refused"
- Cannot connect to PostgreSQL
- Application fails to start

**Solutions:**

1. **Check PostgreSQL is running:**
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
```

2. **Verify connection parameters:**
```properties
# application.properties
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank
spring.datasource.username=postgres
spring.datasource.password=correct_password
```

3. **Test manual connection:**
```bash
psql -h localhost -p 5432 -U postgres -d samplebank
```

4. **Check PostgreSQL configuration:**
```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Add/verify line:
host    all             all             127.0.0.1/32            md5
```

### Problem: Too Many Connections

**Symptoms:**
- Error: "FATAL: sorry, too many clients already"
- Cannot create new connections
- Application hangs

**Diagnosis:**

```sql
-- Check current connections
SELECT count(*) FROM pg_stat_activity;

-- View connection limit
SHOW max_connections;

-- Identify idle connections
SELECT pid, usename, application_name, state, state_change
FROM pg_stat_activity
WHERE state = 'idle'
ORDER BY state_change;
```

**Solutions:**

1. **Close idle connections:**
```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle' AND state_change < now() - interval '5 minutes';
```

2. **Increase connection limit:**
```sql
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();
```

3. **Configure connection pooling:**
```properties
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000
```

## Performance Problems

### Problem: Slow Transfer Operations

**Symptoms:**
- Transfers take several seconds
- UI freezes during transfer
- High database CPU usage

**Diagnosis:**

```sql
-- Enable query timing
\timing on

-- Test transfer speed
SELECT transfer_money('alice', 'bob', 100.00);

-- Check slow queries
SELECT
    query,
    mean_exec_time,
    calls,
    total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Analyze query plan
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'alice';
```

**Solutions:**

1. **Add missing indexes:**
```sql
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_transactions_from ON transactions(from_user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_to ON transactions(to_user_id);
```

2. **Optimize stored procedure:**
```sql
-- Use exists instead of counting
IF EXISTS(SELECT 1 FROM users WHERE username = p_from_username) THEN
    -- More efficient than COUNT(*)
END IF;
```

3. **Analyze and vacuum:**
```sql
ANALYZE users;
ANALYZE transactions;
VACUUM ANALYZE;
```

## API Errors

### Problem: 400 Bad Request with No Details

**Symptoms:**
- HTTP 400 returned
- No error message in response body
- Unclear what went wrong

**Solutions:**

1. **Check request format:**
```bash
# Correct format
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"100.00"}'

# Add verbose output to see details
curl -v -X POST ...
```

2. **Validate JSON:**
```bash
# Use jq to validate JSON
echo '{"fromUsername":"alice","toUsername":"bob","amount":"100.00"}' | jq .
```

3. **Enable debug logging:**
```properties
logging.level.org.springframework.web=DEBUG
```

### Problem: 500 Internal Server Error

**Symptoms:**
- HTTP 500 returned
- Server error
- Check application logs

**Solutions:**

1. **Review application logs:**
```bash
# Spring Boot logs
tail -f /var/log/samplebank/application.log

# Or console output
```

2. **Add exception handling:**
```java
@ExceptionHandler(Exception.class)
public ResponseEntity<String> handleException(Exception e) {
    logger.error("Transfer failed", e);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body("ERROR: " + e.getMessage());
}
```

## Common Error Messages

| Error Message | Cause | Solution |
|--------------|-------|----------|
| ERROR: Sender not found | Username doesn't exist | Verify sender username, check users table |
| ERROR: Receiver not found | Recipient doesn't exist | Verify receiver username, create user if needed |
| ERROR: Insufficient balance | Not enough funds | Check balance, reduce transfer amount |
| ERROR: Amount must be greater than 0 | Zero or negative amount | Use positive amount |
| ERROR: Invalid amount format | Non-numeric amount | Use numeric format: "100.00" |
| deadlock detected | Concurrent lock conflict | Implement retry logic, lock in consistent order |
| Connection refused | PostgreSQL not running | Start PostgreSQL service |
| too many clients | Connection pool exhausted | Close idle connections, increase max_connections |

## Diagnostic Queries

**System Health:**
```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('samplebank'));

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE datname = 'samplebank';

-- Cache hit ratio (should be >99%)
SELECT
    sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100 AS cache_hit_ratio
FROM pg_statio_user_tables;
```

**Transaction Statistics:**
```sql
-- Transaction count
SELECT COUNT(*) FROM transactions;

-- Transactions per user
SELECT
    u.username,
    COUNT(t.transaction_id) as transaction_count
FROM users u
LEFT JOIN transactions t ON u.user_id = t.from_user_id
GROUP BY u.username
ORDER BY transaction_count DESC;

-- Average transaction amount
SELECT AVG(amount), MIN(amount), MAX(amount) FROM transactions;
```

Use this guide to diagnose and resolve issues in SampleBank v3!
