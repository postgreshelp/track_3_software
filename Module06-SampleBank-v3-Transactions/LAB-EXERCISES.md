# SampleBank v3 - Lab Exercises

## Table of Contents
1. [Exercise Overview](#exercise-overview)
2. [Lab Setup](#lab-setup)
3. [Basic Transaction Exercises](#basic-transaction-exercises)
4. [Concurrency Testing](#concurrency-testing)
5. [Transaction Testing](#transaction-testing)
6. [Performance Testing](#performance-testing)
7. [Error Handling Exercises](#error-handling-exercises)
8. [Advanced Challenges](#advanced-challenges)
9. [Assessment Criteria](#assessment-criteria)

## Exercise Overview

These hands-on exercises focus on testing banking transactions, understanding ACID properties, handling concurrency issues, and exploring database transaction behavior.

**Learning Objectives:**
- Test money transfer functionality
- Understand transaction atomicity
- Handle concurrent transactions
- Identify and resolve race conditions
- Test error scenarios
- Analyze transaction performance

**Prerequisites:**
- Completed SampleBank v3 setup
- PostgreSQL running with sample data
- Application running on localhost:8080
- Basic knowledge of SQL and REST APIs

**Time Required:**
- Basic Exercises: 1-2 hours
- Concurrency Testing: 1-2 hours
- Advanced Challenges: 2-3 hours
- Total: 4-7 hours

## Lab Setup

### Step 1: Create Test Database

```bash
psql -U postgres
```

```sql
-- Create fresh database
DROP DATABASE IF EXISTS samplebank_lab;
CREATE DATABASE samplebank_lab;

\c samplebank_lab

-- Run schema scripts
\i database/schema.sql
\i database/transactions-schema.sql
\i database/transfer-procedure.sql
```

### Step 2: Seed Test Data

```sql
-- Create test users with various balances
INSERT INTO users (username, email, password, balance) VALUES
('alice', 'alice@test.com', 'pass123', 1000.00),
('bob', 'bob@test.com', 'pass456', 1500.00),
('charlie', 'charlie@test.com', 'pass789', 500.00),
('david', 'david@test.com', 'pass000', 2000.00),
('eve', 'eve@test.com', 'pass111', 250.00);

-- Verify insertion
SELECT user_id, username, balance FROM users ORDER BY user_id;
```

### Step 3: Configure Application

Update `application.properties`:
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank_lab
```

Restart application:
```bash
mvn spring-boot:run
```

### Step 4: Verify Setup

```bash
# Test API endpoint
curl http://localhost:8080/balance/alice
# Expected: Balance for alice: $1000.00
```

## Basic Transaction Exercises

### Exercise 1: Simple Money Transfer

**Objective:** Test basic money transfer functionality.

**Steps:**

1. Check initial balances:
```bash
curl http://localhost:8080/balance/alice
curl http://localhost:8080/balance/bob
```

2. Perform transfer:
```bash
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"250.00"}'
```

3. Verify updated balances:
```bash
curl http://localhost:8080/balance/alice  # Expected: $750.00
curl http://localhost:8080/balance/bob    # Expected: $1750.00
```

4. Verify transaction record:
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
LIMIT 1;
```

**Questions:**
1. What HTTP status code is returned on success?
2. How is the timestamp determined in the transaction record?
3. What happens to the response if the transfer fails?

### Exercise 2: Multiple Sequential Transfers

**Objective:** Test sequential transfers and balance accumulation.

**Steps:**

1. Record Alice's starting balance
2. Perform 5 sequential transfers:
```bash
# Transfer 1: Alice -> Bob ($100)
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"100.00"}'

# Transfer 2: Alice -> Charlie ($50)
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"charlie","amount":"50.00"}'

# Transfer 3: Alice -> David ($75)
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"david","amount":"75.00"}'

# Transfer 4: Bob -> Alice ($25)
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"bob","toUsername":"alice","amount":"25.00"}'

# Transfer 5: Charlie -> Alice ($10)
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"charlie","toUsername":"alice","amount":"10.00"}'
```

3. Calculate expected balance manually
4. Verify actual balance matches:
```bash
curl http://localhost:8080/balance/alice
```

5. Query transaction history:
```sql
SELECT COUNT(*) FROM transactions WHERE from_user_id = 1 OR to_user_id = 1;
```

**Questions:**
1. What is Alice's final balance?
2. How many transactions involve Alice?
3. Does the order of transfers matter?

### Exercise 3: Insufficient Balance Test

**Objective:** Test balance validation.

**Steps:**

1. Check Eve's balance (should be $250.00):
```bash
curl http://localhost:8080/balance/eve
```

2. Try to transfer more than available:
```bash
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"eve","toUsername":"alice","amount":"500.00"}'
```

3. Verify balance unchanged:
```bash
curl http://localhost:8080/balance/eve
```

4. Check no transaction was recorded:
```sql
SELECT COUNT(*) FROM transactions WHERE from_user_id = 5;
```

**Questions:**
1. What error message is returned?
2. What HTTP status code is returned?
3. Was any transaction record created?
4. Can you transfer exactly your entire balance?

### Exercise 4: Invalid User Tests

**Objective:** Test user validation.

**Test Cases:**

```bash
# Case 1: Non-existent sender
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"nonexistent","toUsername":"alice","amount":"100.00"}'

# Case 2: Non-existent receiver
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"nonexistent","amount":"100.00"}'

# Case 3: Empty username
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"","toUsername":"bob","amount":"100.00"}'

# Case 4: Null username
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"toUsername":"bob","amount":"100.00"}'
```

**Questions:**
1. What error message is returned for each case?
2. Are the error messages clear and helpful?
3. Which validation happens first: sender or receiver?

## Concurrency Testing

### Exercise 5: Concurrent Transfers (Basic)

**Objective:** Observe behavior with simultaneous transfers.

**Setup:**
```sql
-- Reset Alice's balance
UPDATE users SET balance = 1000.00 WHERE username = 'alice';
```

**Test Scenario:** Two transfers from Alice executed simultaneously.

**Method 1: Using Shell Scripts**

Create `concurrent_test.sh`:
```bash
#!/bin/bash

# Start both transfers at the same time
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"300.00"}' &

curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"charlie","amount":"400.00"}' &

# Wait for both to complete
wait
echo "Both transfers completed"
```

Run:
```bash
chmod +x concurrent_test.sh
./concurrent_test.sh
```

**Method 2: Using GNU Parallel**

```bash
# Install parallel (if not installed)
sudo apt-get install parallel  # Ubuntu/Debian
brew install parallel          # Mac

# Run concurrent transfers
parallel -j2 curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d ::: \
  '{"fromUsername":"alice","toUsername":"bob","amount":"300.00"}' \
  '{"fromUsername":"alice","toUsername":"charlie","amount":"400.00"}'
```

**Verification:**
```bash
# Check Alice's balance
curl http://localhost:8080/balance/alice

# Expected: $300.00 (both should succeed)
# Possible: $700.00 or $600.00 (one failed due to timing)
```

```sql
-- Check transaction records
SELECT
    u1.username AS sender,
    u2.username AS receiver,
    t.amount,
    t.created_at
FROM transactions t
JOIN users u1 ON t.from_user_id = u1.user_id
JOIN users u2 ON t.to_user_id = u2.user_id
WHERE u1.username = 'alice'
ORDER BY t.created_at DESC
LIMIT 5;
```

**Questions:**
1. Did both transfers succeed?
2. What is the final balance?
3. How does PostgreSQL handle concurrent updates?
4. Are there any race conditions?

### Exercise 6: High Concurrency Stress Test

**Objective:** Test system behavior under high concurrent load.

**Setup:**
```sql
UPDATE users SET balance = 10000.00 WHERE username = 'alice';
```

**Test Script** (`stress_test.sh`):
```bash
#!/bin/bash

# Run 20 concurrent transfers
for i in {1..20}; do
    curl -X POST http://localhost:8080/transfer \
      -H "Content-Type: application/json" \
      -d '{"fromUsername":"alice","toUsername":"bob","amount":"100.00"}' &
done

wait
echo "All transfers completed"

# Check final balance
curl http://localhost:8080/balance/alice
```

**Verification:**
```sql
-- Count successful transfers
SELECT COUNT(*) FROM transactions WHERE from_user_id = 1;

-- Calculate expected balance
SELECT 10000.00 - (COUNT(*) * 100.00) AS expected_balance
FROM transactions WHERE from_user_id = 1;

-- Compare with actual balance
SELECT balance FROM users WHERE username = 'alice';
```

**Questions:**
1. How many transfers succeeded?
2. Does the balance match the transaction count?
3. Were any transfers rejected due to insufficient balance?
4. How long did the entire operation take?

### Exercise 7: Deadlock Simulation

**Objective:** Create and observe a deadlock scenario.

**Scenario:** Alice and Bob send money to each other simultaneously.

**Setup:**
```sql
UPDATE users SET balance = 1000.00 WHERE username IN ('alice', 'bob');
```

**Test Script** (`deadlock_test.sh`):
```bash
#!/bin/bash

# Start two opposite transfers simultaneously
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"100.00"}' &

curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"bob","toUsername":"alice","amount":"150.00"}' &

wait
```

**Run multiple times:**
```bash
for i in {1..10}; do
    echo "Test run $i"
    ./deadlock_test.sh
    sleep 1
done
```

**Monitor for deadlocks:**
```sql
-- Check PostgreSQL logs
SELECT * FROM pg_stat_database_conflicts WHERE datname = 'samplebank_lab';
```

**Questions:**
1. Do you observe any deadlocks?
2. How does PostgreSQL resolve deadlocks?
3. What error message is returned if a deadlock occurs?
4. How can deadlocks be prevented?

## Transaction Testing

### Exercise 8: Transaction Atomicity Test

**Objective:** Verify all-or-nothing behavior.

**Test Case:** Modify stored procedure to fail after deducting but before adding.

**Modified Procedure:**
```sql
CREATE OR REPLACE FUNCTION transfer_money_test(
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

    -- Deduct from sender
    UPDATE users SET balance = balance - p_amount
    WHERE user_id = v_from_user_id;

    -- INTENTIONAL ERROR: Force divide by zero
    PERFORM 1 / 0;

    -- This should never execute
    UPDATE users SET balance = balance + p_amount
    WHERE user_id = v_to_user_id;

    INSERT INTO transactions (from_user_id, to_user_id, amount)
    VALUES (v_from_user_id, v_to_user_id, p_amount);

    RETURN 'SUCCESS: Transferred $' || p_amount;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'ERROR: Transaction failed';
END;
$$ LANGUAGE plpgsql;
```

**Test:**
```sql
-- Record balances before
SELECT username, balance FROM users WHERE username IN ('alice', 'bob');

-- Execute failing transfer
SELECT transfer_money_test('alice', 'bob', 100.00);

-- Check balances after (should be unchanged)
SELECT username, balance FROM users WHERE username IN ('alice', 'bob');

-- Verify no transaction record
SELECT COUNT(*) FROM transactions WHERE from_user_id = 1 AND to_user_id = 2;
```

**Questions:**
1. Was Alice's balance deducted?
2. Was Bob's balance increased?
3. Was a transaction record created?
4. What ensures atomicity here?

### Exercise 9: Isolation Level Testing

**Objective:** Understand PostgreSQL isolation levels.

**Test READ COMMITTED (default):**

Terminal 1:
```sql
BEGIN;
UPDATE users SET balance = 500.00 WHERE username = 'alice';
-- Don't commit yet
SELECT pg_sleep(10);  -- Wait 10 seconds
COMMIT;
```

Terminal 2 (within 10 seconds):
```sql
-- This will wait for Terminal 1 to commit
SELECT balance FROM users WHERE username = 'alice';
```

**Test REPEATABLE READ:**

Terminal 1:
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM users WHERE username = 'alice';
-- Note the balance
SELECT pg_sleep(10);
SELECT balance FROM users WHERE username = 'alice';
-- Should be same as first SELECT
COMMIT;
```

Terminal 2 (during Terminal 1's sleep):
```sql
UPDATE users SET balance = 999.00 WHERE username = 'alice';
```

**Questions:**
1. What happens in READ COMMITTED?
2. What happens in REPEATABLE READ?
3. Which isolation level is better for banking?

### Exercise 10: Rollback Testing

**Objective:** Test explicit rollback behavior.

**Manual Rollback:**
```sql
BEGIN;

-- Perform transfer
UPDATE users SET balance = balance - 100 WHERE username = 'alice';
UPDATE users SET balance = balance + 100 WHERE username = 'bob';
INSERT INTO transactions (from_user_id, to_user_id, amount) VALUES (1, 2, 100.00);

-- Check changes (not visible to other sessions)
SELECT username, balance FROM users WHERE username IN ('alice', 'bob');

-- Rollback everything
ROLLBACK;

-- Verify no changes persisted
SELECT username, balance FROM users WHERE username IN ('alice', 'bob');
SELECT COUNT(*) FROM transactions WHERE from_user_id = 1 AND to_user_id = 2;
```

**Questions:**
1. Are changes visible before commit?
2. What happens to auto-increment IDs after rollback?
3. Can you rollback after commit?

## Performance Testing

### Exercise 11: Query Performance Analysis

**Objective:** Measure query performance with and without indexes.

**Test Without Indexes:**
```sql
-- Drop indexes temporarily
DROP INDEX IF EXISTS idx_users_username;
DROP INDEX IF EXISTS idx_transactions_from;
DROP INDEX IF EXISTS idx_transactions_to;

-- Measure query time
\timing on

-- Query by username (full table scan)
SELECT user_id, balance FROM users WHERE username = 'alice';

-- Query transactions (full table scan)
SELECT * FROM transactions WHERE from_user_id = 1;
```

**Test With Indexes:**
```sql
-- Recreate indexes
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_transactions_from ON transactions(from_user_id);
CREATE INDEX idx_transactions_to ON transactions(to_user_id);

-- Measure query time again
SELECT user_id, balance FROM users WHERE username = 'alice';
SELECT * FROM transactions WHERE from_user_id = 1;
```

**Analyze Query Plans:**
```sql
EXPLAIN ANALYZE SELECT user_id, balance FROM users WHERE username = 'alice';
EXPLAIN ANALYZE SELECT * FROM transactions WHERE from_user_id = 1;
```

**Questions:**
1. What is the performance difference?
2. What does the query plan show?
3. When should indexes be used?

### Exercise 12: Bulk Transfer Performance

**Objective:** Measure throughput for bulk operations.

**Test Script:**
```bash
#!/bin/bash

echo "Starting bulk transfer test..."
START=$(date +%s)

# Perform 100 transfers
for i in {1..100}; do
    curl -s -X POST http://localhost:8080/transfer \
      -H "Content-Type: application/json" \
      -d '{"fromUsername":"david","toUsername":"eve","amount":"1.00"}' > /dev/null
done

END=$(date +%s)
DURATION=$((END - START))

echo "Completed 100 transfers in $DURATION seconds"
echo "Throughput: $((100 / DURATION)) transfers/second"
```

**Questions:**
1. What is the average transfer time?
2. What is the throughput (transfers/second)?
3. Where are the bottlenecks?

## Error Handling Exercises

### Exercise 13: Invalid Input Testing

**Test Cases:**

```bash
# Negative amount
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"-50.00"}'

# Zero amount
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"0.00"}'

# Non-numeric amount
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"abc"}'

# Missing amount
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob"}'

# Very large amount
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"99999999999.99"}'
```

**Questions:**
1. What error is returned for each case?
2. Are the errors handled gracefully?
3. Do any cases cause server errors?

### Exercise 14: Database Connection Failure

**Objective:** Test behavior when database is unavailable.

**Steps:**

1. Stop PostgreSQL:
```bash
sudo systemctl stop postgresql
```

2. Try transfer:
```bash
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"100.00"}'
```

3. Restart PostgreSQL:
```bash
sudo systemctl start postgresql
```

**Questions:**
1. What error is returned?
2. Does the application crash?
3. Does it recover automatically?

## Advanced Challenges

### Challenge 1: Transaction History API

**Task:** Implement a new endpoint to retrieve transaction history.

**Requirements:**
- Endpoint: GET /transactions/{username}
- Return both sent and received transactions
- Include other party's username
- Sort by date (newest first)
- Limit to 50 transactions

**Test:**
```bash
curl http://localhost:8080/transactions/alice
```

### Challenge 2: Daily Transaction Limit

**Task:** Modify stored procedure to enforce a $1000 daily transfer limit.

**Requirements:**
- Check total transfers in past 24 hours
- Return error if limit exceeded
- Implement in transfer_money() function

**Test:**
```sql
-- Should fail after $1000 in transfers
SELECT transfer_money('alice', 'bob', 500.00);
SELECT transfer_money('alice', 'charlie', 600.00);  -- Should fail
```

### Challenge 3: Transaction Audit Report

**Task:** Create SQL query for audit report.

**Requirements:**
- Total transactions per user
- Total sent and received amounts
- Average transaction size
- Date of last transaction
- Format as readable report

**Expected Output:**
```
Username | Total Sent | Total Received | Transactions | Avg Amount | Last Transaction
---------|-----------|----------------|--------------|------------|------------------
alice    | $1250.00  | $350.00        | 15           | $106.67    | 2024-01-26 14:30
```

### Challenge 4: Concurrent Transfer Simulation

**Task:** Create script to simulate 10 users making random transfers.

**Requirements:**
- 10 users with $1000 each
- Random transfer amounts ($1-$100)
- Random sender/receiver pairs
- 100 concurrent transfers
- Report final balances
- Verify total balance unchanged

## Assessment Criteria

### Basic Level (60%)
- Complete Exercises 1-4
- Understand basic transfer flow
- Test error conditions
- Verify data integrity

### Intermediate Level (80%)
- Complete Exercises 5-10
- Test concurrent transfers
- Understand ACID properties
- Analyze transaction behavior

### Advanced Level (100%)
- Complete all exercises
- Complete at least 2 challenges
- Demonstrate deep understanding
- Identify performance bottlenecks
- Propose improvements

### Bonus Points
- Create additional test scenarios
- Write automated test scripts
- Implement new features
- Optimize performance
- Document findings comprehensively

## Lab Report Template

```markdown
# SampleBank v3 Lab Report

## Student Information
- Name:
- Date:
- Module: SampleBank v3 Transactions

## Exercises Completed
- [ ] Exercise 1: Simple Money Transfer
- [ ] Exercise 2: Multiple Sequential Transfers
- [ ] Exercise 3: Insufficient Balance Test
- [ ] Exercise 4: Invalid User Tests
- [ ] Exercise 5: Concurrent Transfers
- [ ] Exercise 6: High Concurrency Stress Test
- [ ] Exercise 7: Deadlock Simulation
- [ ] Exercise 8: Transaction Atomicity Test
- [ ] Exercise 9: Isolation Level Testing
- [ ] Exercise 10: Rollback Testing
- [ ] Exercise 11: Query Performance Analysis
- [ ] Exercise 12: Bulk Transfer Performance
- [ ] Exercise 13: Invalid Input Testing
- [ ] Exercise 14: Database Connection Failure

## Key Findings
1. Transaction behavior observations:
2. Concurrency issues encountered:
3. Performance measurements:
4. Error handling effectiveness:

## Challenges Attempted
- [ ] Challenge 1: Transaction History API
- [ ] Challenge 2: Daily Transaction Limit
- [ ] Challenge 3: Transaction Audit Report
- [ ] Challenge 4: Concurrent Transfer Simulation

## Lessons Learned
1.
2.
3.

## Recommendations
1.
2.
3.
```

Complete these exercises to master SampleBank v3 transaction functionality!
