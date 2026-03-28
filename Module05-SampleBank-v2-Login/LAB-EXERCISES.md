# Lab Exercises: SampleBank v2 Login System

## Table of Contents

1. [Exercise 1: Database Index Creation](#exercise-1-database-index-creation)
2. [Exercise 2: Authentication Testing](#exercise-2-authentication-testing)
3. [Exercise 3: Security Analysis](#exercise-3-security-analysis)
4. [Exercise 4: Performance Benchmarking](#exercise-4-performance-benchmarking)
5. [Exercise 5: Input Validation Enhancement](#exercise-5-input-validation-enhancement)
6. [Exercise 6: SQL Injection Testing](#exercise-6-sql-injection-testing)
7. [Exercise 7: Rate Limiting Simulation](#exercise-7-rate-limiting-simulation)
8. [Exercise 8: Error Message Improvement](#exercise-8-error-message-improvement)
9. [Exercise 9: Database Query Analysis](#exercise-9-database-query-analysis)
10. [Exercise 10: Security Audit Report](#exercise-10-security-audit-report)

---

## Exercise 1: Database Index Creation

### Objective
Complete the `login-index.sql` file to optimize login query performance.

### Background
Database indexes dramatically improve query performance by creating a sorted data structure that allows O(log n) lookups instead of O(n) table scans.

### Task 1.1: Complete the SQL Script

**File:** `database/login-index.sql`

**Current Content:**
```sql
-- Student TODO: Create index for faster login lookups
-- Write: CREATE INDEX idx_users_username ON users(username);
```

**Your Task:**
1. Write the complete `CREATE INDEX` statement
2. Add a comment explaining why this index improves login performance
3. Add a query to verify the index was created

**Hints:**
- Index name: `idx_users_username`
- Table: `users`
- Column: `username`
- Use PostgreSQL's `\di` command to verify

### Task 1.2: Test Index Creation

**Steps:**
```bash
# 1. Execute your SQL file
psql -U postgres -d samplebank1 -f database/login-index.sql

# 2. Verify index exists
psql -U postgres -d samplebank1 -c "\di"

# 3. Check index size
psql -U postgres -d samplebank1 -c "
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes
WHERE tablename = 'users';
"
```

**Expected Output:**
```
       indexname        | size
------------------------+-------
 users_pkey             | 16 kB
 users_username_key     | 16 kB
 idx_users_username     | 16 kB
```

### Task 1.3: Analyze Query Plan

Compare query execution plans before and after index creation.

**Test Query:**
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'testuser';
```

**Questions to Answer:**
1. What type of scan does PostgreSQL use with the index?
2. What is the estimated cost with vs. without the index?
3. How many rows does PostgreSQL examine?

**Deliverable:**
Create a file `exercise1-results.txt` with your findings.

---

## Exercise 2: Authentication Testing

### Objective
Perform comprehensive authentication testing using various methods.

### Task 2.1: Browser-Based Testing

**Test Cases:**

| Test Case | Username | Password | Expected Result |
|-----------|----------|----------|-----------------|
| Valid Login | testuser | testpass | Success + Balance |
| Invalid Password | testuser | wrongpass | ERROR: Invalid password |
| Non-existent User | fakeuser | anypass | ERROR: User not found |
| Empty Username | (empty) | testpass | ERROR: Username is required |
| Empty Password | testuser | (empty) | ERROR: Password is required |
| Both Empty | (empty) | (empty) | ERROR: Username is required |

**Steps:**
1. Navigate to http://localhost:8080/login.html
2. For each test case, enter the credentials
3. Record the actual result
4. Compare with expected result

**Deliverable:**
Create a spreadsheet or table documenting all test results.

### Task 2.2: curl-Based API Testing

**Create a test script** `test-login.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:8080"

echo "=== Test 1: Valid Login ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'
echo -e "\n"

echo "=== Test 2: Invalid Password ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"wrongpass"}'
echo -e "\n"

echo "=== Test 3: Non-existent User ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nonexistent","password":"anypass"}'
echo -e "\n"

echo "=== Test 4: Empty Username ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"","password":"testpass"}'
echo -e "\n"

echo "=== Test 5: Empty Password ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":""}'
echo -e "\n"
```

**Run the script:**
```bash
chmod +x test-login.sh
./test-login.sh > test-results.txt
```

### Task 2.3: Postman Collection

**Create a Postman collection** with the following requests:

1. **Login - Success**
   - Method: POST
   - URL: `{{baseUrl}}/login`
   - Body: `{"username":"{{username}}","password":"{{password}}"}`
   - Tests:
     ```javascript
     pm.test("Status is 200", function() {
         pm.response.to.have.status(200);
     });
     pm.test("Response contains balance", function() {
         pm.expect(pm.response.text()).to.include("Balance");
     });
     ```

2. **Login - Invalid Password**
   - Method: POST
   - Tests:
     ```javascript
     pm.test("Status is 400", function() {
         pm.response.to.have.status(400);
     });
     pm.test("Error message correct", function() {
         pm.expect(pm.response.text()).to.include("Invalid password");
     });
     ```

**Deliverable:**
Export the Postman collection as JSON.

---

## Exercise 3: Security Analysis

### Objective
Identify and document security vulnerabilities in the current implementation.

### Task 3.1: Vulnerability Assessment

**Analyze the code for these vulnerabilities:**

1. **Plain-text Password Storage**
   - Location: `User.java`, `AuthController.java`
   - Risk Level: CRITICAL
   - Impact: Complete credential compromise if database breached

2. **Username Enumeration**
   - Location: `AuthController.java` (lines 32-34)
   - Risk Level: MEDIUM
   - Impact: Attackers can determine valid usernames

3. **No Rate Limiting**
   - Location: All endpoints
   - Risk Level: HIGH
   - Impact: Brute-force attacks possible

4. **Unencrypted HTTP**
   - Location: Application configuration
   - Risk Level: CRITICAL
   - Impact: Man-in-the-middle credential theft

5. **No Session Management**
   - Location: `AuthController.java`
   - Risk Level: MEDIUM
   - Impact: User must re-authenticate every request

**Deliverable:**
Create a document `security-analysis.md` with:
- Vulnerability description
- Code location
- Risk level (LOW/MEDIUM/HIGH/CRITICAL)
- Potential impact
- Recommended mitigation

### Task 3.2: Exploit Simulation

**Username Enumeration Test:**

```bash
# Test with valid username
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"wrongpass"}'
# Response: "ERROR: Invalid password"

# Test with invalid username
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nonexistent","password":"wrongpass"}'
# Response: "ERROR: User not found"

# Conclusion: Attacker can determine valid usernames by observing error messages
```

**Document:**
1. Steps to exploit each vulnerability
2. Information an attacker could gain
3. Potential attack scenarios

### Task 3.3: Security Recommendations

**For each vulnerability, propose:**

1. **Plain-text Passwords** → BCrypt hashing
   ```java
   // Current (INSECURE)
   if (!user.getPasswordHash().equals(password))

   // Recommended (SECURE)
   BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
   if (!encoder.matches(password, user.getPasswordHash()))
   ```

2. **Username Enumeration** → Generic error messages
   ```java
   // Current (REVEALS INFO)
   if (userOpt.isEmpty()) return error("User not found");
   if (!passwordMatches) return error("Invalid password");

   // Recommended (SECURE)
   return error("Invalid username or password");
   ```

3. **Rate Limiting** → Redis-based throttling
   ```java
   @RateLimiter(limit = 5, duration = "1m")
   public ResponseEntity<String> login(...)
   ```

---

## Exercise 4: Performance Benchmarking

### Objective
Measure and compare login performance with and without database indexing.

### Task 4.1: Generate Test Data

**Create bulk test data** (`generate-users.sql`):

```sql
-- Function to generate random users
CREATE OR REPLACE FUNCTION generate_test_users(count INTEGER)
RETURNS VOID AS $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..count LOOP
        INSERT INTO users (username, email, password_hash, balance)
        VALUES (
            'user' || i,
            'user' || i || '@test.com',
            'password' || i,
            1000.00 + (RANDOM() * 9000)::DECIMAL(12,2)
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Generate 10,000 test users
SELECT generate_test_users(10000);

-- Verify count
SELECT COUNT(*) FROM users;
```

**Execute:**
```bash
psql -U postgres -d samplebank1 -f generate-users.sql
```

### Task 4.2: Benchmark Without Index

```bash
# Drop the performance index
psql -U postgres -d samplebank1 -c "DROP INDEX IF EXISTS idx_users_username;"

# Benchmark query
psql -U postgres -d samplebank1 << EOF
\timing on
SELECT * FROM users WHERE username = 'user5000';
SELECT * FROM users WHERE username = 'user7500';
SELECT * FROM users WHERE username = 'user9999';
\timing off
EOF
```

**Record results:**
- Query 1 execution time: _______ ms
- Query 2 execution time: _______ ms
- Query 3 execution time: _______ ms
- Average: _______ ms

### Task 4.3: Benchmark With Index

```bash
# Create index
psql -U postgres -d samplebank1 -c "CREATE INDEX idx_users_username ON users(username);"

# Same benchmark queries
psql -U postgres -d samplebank1 << EOF
\timing on
SELECT * FROM users WHERE username = 'user5000';
SELECT * FROM users WHERE username = 'user7500';
SELECT * FROM users WHERE username = 'user9999';
\timing off
EOF
```

**Record results:**
- Query 1 execution time: _______ ms
- Query 2 execution time: _______ ms
- Query 3 execution time: _______ ms
- Average: _______ ms

### Task 4.4: Analysis

**Calculate:**
1. Performance improvement: (Time_without - Time_with) / Time_without * 100%
2. Speedup factor: Time_without / Time_with

**Create a graph** showing performance comparison.

**Deliverable:**
Document `performance-benchmark.md` with:
- Test methodology
- Raw data
- Calculations
- Performance graph
- Conclusions

---

## Exercise 5: Input Validation Enhancement

### Objective
Improve input validation to prevent invalid data and attacks.

### Task 5.1: Identify Validation Gaps

**Current validation in `AuthController.java`:**

```java
if (username == null || username.trim().isEmpty()) {
    return ResponseEntity.badRequest().body("ERROR: Username is required");
}
if (password == null || password.trim().isEmpty()) {
    return ResponseEntity.badRequest().body("ERROR: Password is required");
}
```

**What's missing?**
- Username length validation (max 50 chars)
- Special character validation
- SQL injection prevention
- XSS prevention

### Task 5.2: Design Validation Rules

**Create validation rules:**

| Field | Rule | Validation Logic |
|-------|------|------------------|
| Username | Length | 3-50 characters |
| Username | Characters | Alphanumeric, underscore, dot only |
| Username | Format | Must start with letter |
| Password | Length | 8+ characters |
| Password | Complexity | (Not enforced in v2) |

### Task 5.3: Implement Enhanced Validation

**Create `ValidationUtils.java`:**

```java
package com.samplebank.util;

import java.util.regex.Pattern;

public class ValidationUtils {

    private static final Pattern USERNAME_PATTERN =
        Pattern.compile("^[a-zA-Z][a-zA-Z0-9_.]{2,49}$");

    public static boolean isValidUsername(String username) {
        return username != null &&
               USERNAME_PATTERN.matcher(username).matches();
    }

    public static boolean isValidPassword(String password) {
        return password != null &&
               password.length() >= 8 &&
               password.length() <= 255;
    }

    public static String sanitizeInput(String input) {
        if (input == null) return null;
        // Remove dangerous characters
        return input.replaceAll("[<>\"'%;()&+]", "");
    }
}
```

**Update `AuthController.java`:**

```java
// Add validation
if (!ValidationUtils.isValidUsername(username)) {
    return ResponseEntity.badRequest()
        .body("ERROR: Invalid username format");
}
```

**Deliverable:**
Complete implementation of `ValidationUtils.java` with test cases.

---

## Exercise 6: SQL Injection Testing

### Objective
Test the application for SQL injection vulnerabilities.

### Task 6.1: Understanding SQL Injection

**Example vulnerable code (NOT in our app):**

```java
// VULNERABLE CODE (Example only)
String query = "SELECT * FROM users WHERE username = '" + username + "'";
// Attacker input: username = "admin' OR '1'='1"
// Resulting query: SELECT * FROM users WHERE username = 'admin' OR '1'='1'
// This returns ALL users!
```

### Task 6.2: Test SQL Injection Attempts

**Our app uses JPA parameterized queries (SAFE):**

```java
// Spring Data JPA (SAFE)
Optional<User> findByUsername(String username);
// Internally uses prepared statements (immune to SQL injection)
```

**Test with malicious inputs:**

```bash
# Test 1: OR condition injection
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin'\'' OR '\''1'\''='\''1","password":"any"}'

# Test 2: Comment injection
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin'\''--","password":"any"}'

# Test 3: UNION injection
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin'\'' UNION SELECT * FROM users--","password":"any"}'
```

**Document:**
1. Each test attempt
2. Actual response
3. Why the attempt failed (JPA protection)
4. What would happen without JPA protection

### Task 6.3: Verify JPA Protection

**Check the generated SQL:**

Enable SQL logging in `application.properties`:
```properties
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

**Attempt login with malicious input and observe logs:**
```
Hibernate: select user0_.user_id as user_id1_0_, ... from users user0_ where user0_.username=?
binding parameter [1] as [VARCHAR] - [admin' OR '1'='1]
```

**Notice:** The entire malicious string is treated as a literal parameter value, not SQL code.

**Deliverable:**
Report `sql-injection-testing.md` documenting:
- Test methodology
- Malicious inputs tested
- Application responses
- JPA protection mechanisms
- Conclusion on SQL injection resistance

---

## Exercise 7: Rate Limiting Simulation

### Objective
Simulate brute-force attacks and understand the need for rate limiting.

### Task 7.1: Brute-Force Script

**Create `brute-force-test.sh`:**

```bash
#!/bin/bash

TARGET="http://localhost:8080/login"
USERNAME="testuser"

echo "Starting brute-force simulation..."
echo "Target: $TARGET"
echo "Username: $USERNAME"
echo ""

# Common passwords list
passwords=("password" "123456" "qwerty" "admin" "letmein" "welcome" "monkey" "dragon" "master" "testpass")

count=0
start_time=$(date +%s)

for pass in "${passwords[@]}"; do
    count=$((count + 1))
    echo "Attempt $count: Testing password '$pass'"

    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST $TARGET \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$USERNAME\",\"password\":\"$pass\"}")

    if [ "$response" == "200" ]; then
        echo "SUCCESS! Password found: $pass"
        break
    else
        echo "Failed (HTTP $response)"
    fi

    # No delay - demonstrating lack of rate limiting
done

end_time=$(date +%s)
elapsed=$((end_time - start_time))

echo ""
echo "Completed $count attempts in $elapsed seconds"
echo "Rate: $(echo "scale=2; $count / $elapsed" | bc) attempts/second"
```

**Run the simulation:**
```bash
chmod +x brute-force-test.sh
./brute-force-test.sh
```

### Task 7.2: Analysis

**Questions:**
1. How many attempts were made per second?
2. How long would it take to try 1,000 passwords?
3. What would be the impact on the server?
4. Why is rate limiting necessary?

### Task 7.3: Design Rate Limiting Strategy

**Propose a rate limiting design:**

```yaml
Rate Limiting Rules:
  - Type: Per-IP throttling
  - Limit: 5 login attempts
  - Window: 1 minute
  - Block Duration: 5 minutes after limit exceeded

Implementation:
  - Technology: Redis
  - Key: login_attempts:{IP_ADDRESS}
  - TTL: 60 seconds
  - Response: HTTP 429 Too Many Requests
```

**Pseudo-code:**

```java
@PostMapping("/login")
public ResponseEntity<String> login(@RequestBody Map<String, String> request,
                                     HttpServletRequest httpRequest) {
    String clientIP = httpRequest.getRemoteAddr();

    // Check rate limit
    int attempts = rateLimiter.getAttempts(clientIP);
    if (attempts >= 5) {
        return ResponseEntity.status(429)
            .body("Too many login attempts. Try again in 5 minutes.");
    }

    // Increment attempt counter
    rateLimiter.incrementAttempts(clientIP);

    // Normal login logic...
}
```

**Deliverable:**
Document `rate-limiting-proposal.md` with:
- Problem statement
- Proposed solution
- Implementation details
- Pseudo-code or code snippets
- Testing strategy

---

## Exercise 8: Error Message Improvement

### Objective
Redesign error messages to prevent information leakage while maintaining usability.

### Task 8.1: Current Error Messages

**Document current responses:**

| Scenario | Current Message | Information Revealed |
|----------|----------------|----------------------|
| User not found | "ERROR: User not found" | Username doesn't exist |
| Invalid password | "ERROR: Invalid password" | Username exists, password wrong |
| Empty username | "ERROR: Username is required" | Input validation |
| Empty password | "ERROR: Password is required" | Input validation |

### Task 8.2: Security Analysis

**Problem:** Username enumeration attack

**Attack scenario:**
```bash
# Step 1: Probe for valid usernames
curl ... -d '{"username":"admin","password":"x"}'
# Response: "Invalid password" → admin exists!

curl ... -d '{"username":"root","password":"x"}'
# Response: "Invalid password" → root exists!

curl ... -d '{"username":"randomuser","password":"x"}'
# Response: "User not found" → randomuser doesn't exist

# Step 2: Brute-force only valid usernames
# This reduces the search space significantly
```

### Task 8.3: Improved Error Messages

**Design secure error messages:**

| Scenario | New Message | Security Benefit |
|----------|-------------|------------------|
| User not found | "Invalid username or password" | No username disclosure |
| Invalid password | "Invalid username or password" | Same as above |
| Empty username | "Username and password required" | Generic validation |
| Empty password | "Username and password required" | Same as above |

**Implementation:**

```java
// Before (INSECURE)
if (userOpt.isEmpty()) {
    return ResponseEntity.badRequest().body("ERROR: User not found");
}
if (!user.getPasswordHash().equals(password)) {
    return ResponseEntity.badRequest().body("ERROR: Invalid password");
}

// After (SECURE)
if (userOpt.isEmpty() || !user.getPasswordHash().equals(password)) {
    return ResponseEntity.badRequest().body("Invalid username or password");
}
```

**Deliverable:**
Modified `AuthController.java` with secure error messages.

---

## Exercise 9: Database Query Analysis

### Objective
Analyze and optimize database queries used in authentication.

### Task 9.1: Query Execution Plans

**Analyze the login query:**

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM users WHERE username = 'testuser';
```

**Document:**
- Query plan type (Seq Scan vs Index Scan)
- Estimated cost
- Actual execution time
- Rows examined
- Buffers used (memory/disk)

### Task 9.2: Alternative Query Strategies

**Test different query approaches:**

**Option 1: Full row retrieval (current)**
```sql
SELECT * FROM users WHERE username = 'testuser';
```

**Option 2: Selective column retrieval**
```sql
SELECT user_id, username, password_hash, balance
FROM users WHERE username = 'testuser';
```

**Option 3: Existence check only**
```sql
SELECT EXISTS(SELECT 1 FROM users WHERE username = 'testuser');
```

**Compare performance:**
```sql
\timing on

-- Test each query 10 times and record average
```

### Task 9.3: Index Coverage Analysis

**Check if index covers the query:**

```sql
-- Current index
CREATE INDEX idx_users_username ON users(username);

-- Covering index (includes all needed columns)
CREATE INDEX idx_users_login_covering ON users(username)
INCLUDE (user_id, password_hash, balance);
```

**Test performance improvement of covering index.**

**Deliverable:**
Report `query-optimization.md` with performance data and recommendations.

---

## Exercise 10: Security Audit Report

### Objective
Compile a comprehensive security audit report for the login system.

### Task 10.1: Executive Summary

**Write a 1-page executive summary covering:**
- System overview
- Audit scope
- Key findings
- Critical vulnerabilities
- Recommendations

### Task 10.2: Detailed Findings

**For each vulnerability, document:**

1. **Title:** Plain-text Password Storage
2. **Severity:** CRITICAL
3. **Description:** Passwords stored without hashing
4. **Evidence:** Database query showing plain-text passwords
5. **Impact:** Full credential compromise if database breached
6. **Recommendation:** Implement BCrypt password hashing
7. **Remediation Steps:**
   - Add BCrypt dependency
   - Create PasswordEncoder bean
   - Migrate existing passwords
   - Update authentication logic

### Task 10.3: Compliance Assessment

**Evaluate against security standards:**

| Standard | Requirement | Compliance | Notes |
|----------|-------------|------------|-------|
| OWASP A2 | Password hashing | ❌ FAIL | Plain-text storage |
| OWASP A3 | Sensitive data encryption | ❌ FAIL | No HTTPS |
| OWASP A5 | Security misconfiguration | ❌ FAIL | No rate limiting |
| OWASP A7 | Authentication | ⚠️ PARTIAL | Basic auth, no session |
| OWASP A10 | Logging & monitoring | ❌ FAIL | No auth logging |

### Task 10.4: Remediation Roadmap

**Create a prioritized remediation plan:**

| Priority | Vulnerability | Effort | Timeline | Owner |
|----------|---------------|--------|----------|-------|
| P0 | Password hashing | Medium | Week 1 | Backend team |
| P0 | HTTPS implementation | Low | Week 1 | DevOps team |
| P1 | Rate limiting | Medium | Week 2 | Backend team |
| P1 | Error message fixes | Low | Week 2 | Backend team |
| P2 | Session management | High | Week 3-4 | Backend team |
| P2 | Audit logging | Medium | Week 4 | Backend team |

**Deliverable:**
Complete security audit report (PDF format) with:
- Executive summary
- Detailed findings
- Compliance assessment
- Remediation roadmap
- Appendices (code snippets, logs, test results)

---

## Submission Guidelines

### Required Deliverables

1. ✅ `exercise1-results.txt` - Index creation results
2. ✅ `test-results.txt` - Authentication test results
3. ✅ `security-analysis.md` - Vulnerability assessment
4. ✅ `performance-benchmark.md` - Performance analysis
5. ✅ `ValidationUtils.java` - Enhanced validation code
6. ✅ `sql-injection-testing.md` - SQL injection tests
7. ✅ `rate-limiting-proposal.md` - Rate limiting design
8. ✅ Modified `AuthController.java` - Improved error messages
9. ✅ `query-optimization.md` - Database query analysis
10. ✅ Security audit report (PDF)

### Submission Format

```
Module05-Labs/
├── exercise1/
│   ├── login-index.sql
│   └── results.txt
├── exercise2/
│   ├── test-login.sh
│   ├── test-results.txt
│   └── SampleBank.postman_collection.json
├── exercise3/
│   └── security-analysis.md
├── exercise4/
│   ├── generate-users.sql
│   └── performance-benchmark.md
├── exercise5/
│   ├── ValidationUtils.java
│   └── ValidationUtilsTest.java
├── exercise6/
│   └── sql-injection-testing.md
├── exercise7/
│   ├── brute-force-test.sh
│   └── rate-limiting-proposal.md
├── exercise8/
│   └── AuthController.java
├── exercise9/
│   └── query-optimization.md
└── exercise10/
    └── security-audit-report.pdf
```

### Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Completeness | 30% | All exercises completed |
| Correctness | 30% | Solutions work as expected |
| Analysis | 20% | Thorough analysis and insights |
| Documentation | 10% | Clear, well-written reports |
| Code Quality | 10% | Clean, commented code |

---

**Lab Exercises Version:** 1.0
**Estimated Time:** 8-10 hours
**Difficulty:** Intermediate
**Module:** 05 - SampleBank v2 Login System
