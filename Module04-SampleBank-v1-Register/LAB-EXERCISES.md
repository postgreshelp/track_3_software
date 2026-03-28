# SampleBank Lab Exercises

## Introduction

This lab guide provides hands-on exercises to help you understand the SampleBank registration system. Each exercise builds upon previous knowledge and includes learning objectives, step-by-step instructions, and verification steps.

**Prerequisites:**
- Completed setup from [SETUP-GUIDE.md](SETUP-GUIDE.md)
- Application running successfully
- PostgreSQL database accessible
- Basic understanding of HTTP requests and SQL

**Recommended Tools:**
- curl or Postman for API testing
- psql or pgAdmin for database queries
- Text editor for code modifications

---

## Lab 1: Testing the Registration API

**Objective:** Understand the registration endpoint and test various scenarios

**Duration:** 20 minutes

**Learning Outcomes:**
- Master REST API testing with curl/Postman
- Understand HTTP status codes
- Identify validation rules
- Verify database persistence

### Exercise 1.1: Successful Registration

**Task:** Register a new user and verify the account was created.

**Steps:**

1. **Start the application** (if not running):
   ```bash
   # Windows
   run.bat

   # Linux/Mac
   java -jar target/samplebank-1.0.0.jar
   ```

2. **Send registration request:**
   ```bash
   curl -X POST http://localhost:8080/register \
     -H "Content-Type: application/json" \
     -d '{"username":"student1","email":"student1@example.com","password":"mypass123"}'
   ```

3. **Expected Response:**
   ```
   Registered successfully! Account created with $1000.00
   ```

4. **Verify in database:**
   ```sql
   psql -U postgres -d samplebank1

   SELECT * FROM users WHERE username = 'student1';
   ```

**Expected Database Record:**
```
user_id | username | email                  | password_hash | balance  | created_at
--------|----------|------------------------|--------------|---------|--------------------------
1       | student1 | student1@example.com   | mypass123    | 1000.00 | 2025-01-23 15:00:00
```

**Questions:**
1. What HTTP status code did you receive? (Answer: 200)
2. What is the default balance for new users? (Answer: $1000.00)
3. Is the password hashed in the database? (Answer: No, plain text - demo only)

### Exercise 1.2: Duplicate Username Error

**Task:** Attempt to register with an existing username.

**Steps:**

1. **Register first user** (if not already done):
   ```bash
   curl -X POST http://localhost:8080/register \
     -H "Content-Type: application/json" \
     -d '{"username":"student2","email":"student2a@example.com","password":"pass1"}'
   ```

2. **Attempt duplicate registration:**
   ```bash
   curl -X POST http://localhost:8080/register \
     -H "Content-Type: application/json" \
     -d '{"username":"student2","email":"student2b@example.com","password":"pass2"}'
   ```

3. **Expected Response:**
   ```
   ERROR: Username already exists
   ```

**Questions:**
1. What HTTP status code did you receive? (Answer: 400 Bad Request)
2. Why doesn't the application create a second account with the same username?
3. How does the system know the username exists? (Hint: Check UserController.java)

### Exercise 1.3: Missing Field Validation

**Task:** Test all three missing field scenarios.

**Test Case 1: Missing Username**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"","email":"test@example.com","password":"pass123"}'
```
**Expected:** `ERROR: Username is required`

**Test Case 2: Missing Email**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"","password":"pass123"}'
```
**Expected:** `ERROR: Email is required`

**Test Case 3: Missing Password**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":""}'
```
**Expected:** `ERROR: Password is required`

**Challenge Question:**
What happens if you completely omit a field from the JSON (e.g., `{"username":"test","email":"test@example.com"}`)? Try it and explain the result.

---

## Lab 2: Database Exploration

**Objective:** Master SQL queries for user data analysis

**Duration:** 30 minutes

**Learning Outcomes:**
- Write effective SQL queries
- Understand database constraints
- Analyze user data
- Manipulate balances (preparation for future modules)

### Exercise 2.1: Basic Queries

**Task:** Query user data in various ways.

**Connect to database:**
```bash
psql -U postgres -d samplebank1
```

**Query 1: View All Users**
```sql
SELECT * FROM users;
```

**Query 2: Count Total Users**
```sql
SELECT COUNT(*) as total_users FROM users;
```

**Query 3: Find Specific User**
```sql
SELECT username, email, balance, created_at
FROM users
WHERE username = 'student1';
```

**Query 4: List Users Alphabetically**
```sql
SELECT user_id, username, email
FROM users
ORDER BY username ASC;
```

**Query 5: Find Recent Registrations**
```sql
SELECT username, created_at
FROM users
ORDER BY created_at DESC
LIMIT 5;
```

### Exercise 2.2: Aggregate Functions

**Task:** Calculate statistics across all users.

**Total Balance Across All Accounts:**
```sql
SELECT SUM(balance) as total_deposits FROM users;
```

**Average Balance:**
```sql
SELECT AVG(balance) as average_balance FROM users;
```

**Min and Max Balances:**
```sql
SELECT
    MIN(balance) as lowest_balance,
    MAX(balance) as highest_balance
FROM users;
```

**Registration Count by Date:**
```sql
SELECT
    DATE(created_at) as registration_date,
    COUNT(*) as registrations
FROM users
GROUP BY DATE(created_at)
ORDER BY registration_date DESC;
```

### Exercise 2.3: Testing Constraints

**Task:** Understand database constraints by testing violations.

**Test 1: Negative Balance (Should Fail)**
```sql
-- First, create a test user or use existing
INSERT INTO users (username, email, password_hash, balance)
VALUES ('constrainttest', 'test@example.com', 'pass123', -500.00);
```
**Expected Error:** `ERROR: new row for relation "users" violates check constraint "users_balance_check"`

**Test 2: Duplicate Username (Should Fail)**
```sql
-- Assuming 'student1' already exists
INSERT INTO users (username, email, password_hash)
VALUES ('student1', 'duplicate@example.com', 'pass456');
```
**Expected Error:** `ERROR: duplicate key value violates unique constraint "users_username_key"`

**Test 3: NULL Username (Should Fail)**
```sql
INSERT INTO users (username, email, password_hash)
VALUES (NULL, 'null@example.com', 'pass789');
```
**Expected Error:** `ERROR: null value in column "username" violates not-null constraint`

**Questions:**
1. Why is it important to have a CHECK constraint on balance?
2. What would happen without the UNIQUE constraint on username?
3. How does the database enforce NOT NULL constraints?

### Exercise 2.4: Data Modification

**Task:** Practice UPDATE and DELETE operations (preparation for future modules).

**Update Email:**
```sql
UPDATE users
SET email = 'newemail@example.com'
WHERE username = 'student1';

-- Verify update
SELECT username, email FROM users WHERE username = 'student1';
```

**Simulate Balance Change (Future: Transactions):**
```sql
-- Increase balance (simulating deposit)
UPDATE users
SET balance = balance + 250.00
WHERE username = 'student1';

-- Verify new balance
SELECT username, balance FROM users WHERE username = 'student1';
```

**Delete Test User:**
```sql
-- Create temporary test user
INSERT INTO users (username, email, password_hash)
VALUES ('tempuser', 'temp@example.com', 'temp123');

-- Delete it
DELETE FROM users WHERE username = 'tempuser';

-- Verify deletion
SELECT * FROM users WHERE username = 'tempuser';
-- Should return 0 rows
```

---

## Lab 3: Code Exploration and Modification

**Objective:** Understand the codebase and make simple modifications

**Duration:** 45 minutes

**Learning Outcomes:**
- Navigate Spring Boot project structure
- Understand JPA entity mappings
- Modify and rebuild the application
- Test changes end-to-end

### Exercise 3.1: Understanding the Entity

**Task:** Analyze the User entity and its JPA annotations.

**Open File:** `src/main/java/com/samplebank/entity/User.java`

**Study Questions:**

1. **What does `@Entity` annotation do?**
   - Answer: Marks the class as a JPA entity (database table)

2. **What does `@GeneratedValue(strategy = GenerationType.IDENTITY)` mean?**
   - Answer: Database auto-generates the ID value

3. **What is the purpose of `@PrePersist`?**
   - Answer: Lifecycle callback that runs before entity is persisted (saved)

4. **Why use `BigDecimal` instead of `double` for balance?**
   - Answer: Exact decimal precision (no floating-point errors)

**Code Reading Task:**
Trace the code flow when a new User object is created:
1. Constructor is called with username, email, password
2. Balance is set to 1000.00
3. createdAt is set to current time
4. When saved, @PrePersist runs as a safety check
5. Hibernate generates INSERT SQL
6. Database stores the record

### Exercise 3.2: Understanding the Repository

**Task:** Analyze the UserRepository interface.

**Open File:** `src/main/java/com/samplebank/repository/UserRepository.java`

**Study Questions:**

1. **What does `extends JpaRepository<User, Long>` provide?**
   - Answer: Inherits CRUD methods (save, findById, findAll, delete, etc.)

2. **How does `findByUsername(String username)` work without implementation?**
   - Answer: Spring Data JPA generates SQL from method name

3. **What SQL does `existsByUsername(String username)` generate?**
   - Answer: `SELECT COUNT(*) > 0 FROM users WHERE username = ?`

**Challenge:**
Add a new method signature to find users by email (don't implement, just declare):
```java
Optional<User> findByEmail(String email);
```

### Exercise 3.3: Understanding the Controller

**Task:** Analyze request handling in UserController.

**Open File:** `src/main/java/com/samplebank/controller/UserController.java`

**Study Questions:**

1. **What does `@RestController` annotation do?**
   - Answer: Combines @Controller + @ResponseBody (returns data, not views)

2. **What does `@PostMapping("/register")` specify?**
   - Answer: Maps HTTP POST requests to /register to this method

3. **What is `@RequestBody Map<String, String>`?**
   - Answer: Parses JSON request body into a Map

**Flow Tracing:**
Trace a registration request through the code:
1. POST request arrives at /register
2. JSON parsed into Map
3. Extract username, email, password from Map
4. Validate each field (empty check)
5. Check if username exists using repository
6. Create new User entity
7. Save to database via repository
8. Return success message

### Exercise 3.4: Modification - Add Phone Number Field

**Task:** Extend the User entity with a phone number field.

**Step 1: Modify User Entity**

Edit `src/main/java/com/samplebank/entity/User.java`:

Add field after email:
```java
@Column(name = "phone", length = 20)
private String phone;
```

Add to constructor:
```java
public User(String username, String email, String passwordHash, String phone) {
    this.username = username;
    this.email = email;
    this.passwordHash = passwordHash;
    this.phone = phone;
    this.balance = new BigDecimal("1000.00");
    this.createdAt = LocalDateTime.now();
}
```

Add getter and setter:
```java
public String getPhone() {
    return phone;
}

public void setPhone(String phone) {
    this.phone = phone;
}
```

**Step 2: Update Database Schema**

Connect to database and add column:
```sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
```

**Step 3: Modify Controller**

Edit `src/main/java/com/samplebank/controller/UserController.java`:

Extract phone from request:
```java
String phone = request.get("phone");
```

Add validation (optional):
```java
if (phone == null || phone.trim().isEmpty()) {
    return ResponseEntity.badRequest().body("ERROR: Phone is required");
}
```

Update User creation:
```java
User user = new User(username, email, password, phone);
```

**Step 4: Rebuild and Test**

```bash
# Rebuild application
mvn clean package

# Restart application
java -jar target/samplebank-1.0.0.jar

# Test with phone number
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"phonetest","email":"phone@example.com","password":"pass123","phone":"555-1234"}'
```

**Step 5: Verify in Database**

```sql
SELECT username, email, phone FROM users WHERE username = 'phonetest';
```

**Expected Result:**
```
username  | email              | phone
----------|--------------------|---------
phonetest | phone@example.com  | 555-1234
```

---

## Lab 4: Advanced Testing and Debugging

**Objective:** Master debugging techniques and advanced testing scenarios

**Duration:** 30 minutes

**Learning Outcomes:**
- Enable SQL logging
- Test edge cases
- Debug application errors
- Analyze logs

### Exercise 4.1: Enable SQL Logging

**Task:** View generated SQL statements in console.

**Verification:**
Check `src/main/resources/application.properties`:
```properties
spring.jpa.show-sql=true
```

**Restart Application and Register User:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"sqltest","email":"sql@example.com","password":"test"}'
```

**Observe Console Output:**
```sql
Hibernate: select user0_.user_id as user_id1_0_, ... from users user0_ where user0_.username=?
Hibernate: insert into users (balance, created_at, email, password_hash, username) values (?, ?, ?, ?, ?)
```

**Questions:**
1. Why does Hibernate execute a SELECT before INSERT?
2. What are the question marks (?) in the SQL?
3. How does Hibernate know which table to use?

### Exercise 4.2: Test Edge Cases

**Task:** Test unusual but valid inputs.

**Test 1: Very Long Username (Near Limit)**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"this_is_a_very_long_username_with_exactly_50ch","email":"long@example.com","password":"pass"}'
```

**Test 2: Very Long Username (Exceeds Limit)**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"this_is_a_very_long_username_that_exceeds_the_fifty_character_limit","email":"toolong@example.com","password":"pass"}'
```
**Expected:** Database error (exceeds VARCHAR(50))

**Test 3: Special Characters in Username**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"user@#$%","email":"special@example.com","password":"pass"}'
```
**Expected:** Accepts (no character validation implemented)

**Test 4: SQL Injection Attempt**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin' OR '1'='1\",\"email\":\"hack@example.com\",\"password\":\"pass\"}"
```
**Expected:** Treated as literal string (JPA protects against SQL injection)

### Exercise 4.3: Concurrent Registrations

**Task:** Test what happens with simultaneous registrations of the same username.

**Open Two Terminals and Run Simultaneously:**

Terminal 1:
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"concurrent","email":"c1@example.com","password":"pass"}'
```

Terminal 2 (immediately after):
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"concurrent","email":"c2@example.com","password":"pass"}'
```

**Expected Behavior:**
- One succeeds: `Registered successfully!`
- One fails: `ERROR: Username already exists`

**Questions:**
1. Which one succeeded? (First to reach database)
2. How does the database prevent both from succeeding? (UNIQUE constraint + transaction isolation)

---

## Lab 5: Integration and Extension

**Objective:** Prepare for future modules by understanding integration points

**Duration:** 25 minutes

**Learning Outcomes:**
- Identify extension points in the code
- Understand modular design
- Prepare for authentication module
- Design future features

### Exercise 5.1: Design User Login Endpoint

**Task:** Plan the structure for a login endpoint (don't implement).

**Requirements:**
- POST /login
- Accept username and password
- Return success/failure message

**Pseudocode:**
```java
@PostMapping("/login")
public ResponseEntity<String> login(@RequestBody Map<String, String> request) {
    // 1. Extract username and password from request
    // 2. Find user by username using repository
    // 3. If user not found, return error
    // 4. Compare password with stored password
    // 5. If match, return success (future: create session/token)
    // 6. If no match, return error
}
```

**Questions:**
1. What repository method would you use to find the user?
2. How would you compare passwords?
3. What should the response contain for successful login?

### Exercise 5.2: Design Balance View Endpoint

**Task:** Plan an endpoint to view user balance.

**Requirements:**
- GET /balance/{username}
- Return user's current balance

**Pseudocode:**
```java
@GetMapping("/balance/{username}")
public ResponseEntity<?> getBalance(@PathVariable String username) {
    // 1. Find user by username
    // 2. If not found, return 404 error
    // 3. Return balance as JSON: {"username":"...", "balance":1000.00}
}
```

**Sample Response:**
```json
{
  "username": "student1",
  "balance": 1000.00
}
```

### Exercise 5.3: Design Money Transfer Endpoint

**Task:** Plan a money transfer endpoint structure.

**Requirements:**
- POST /transfer
- Accept: from_username, to_username, amount
- Validate sufficient balance
- Update both accounts

**Pseudocode:**
```java
@PostMapping("/transfer")
public ResponseEntity<String> transfer(@RequestBody Map<String, Object> request) {
    // 1. Extract from_username, to_username, amount
    // 2. Find both users
    // 3. Validate both exist
    // 4. Check from_user has sufficient balance
    // 5. Deduct amount from sender
    // 6. Add amount to receiver
    // 7. Save both users (transaction required!)
    // 8. Return success message
}
```

**Challenge Questions:**
1. What happens if the application crashes after deducting but before adding?
2. How can database transactions prevent this problem?
3. What additional validations would you add?

---

## Conclusion and Next Steps

### Skills Acquired

After completing these labs, you should be able to:
- Test REST APIs using curl and Postman
- Write SQL queries for data analysis
- Navigate and understand Spring Boot project structure
- Modify entities, repositories, and controllers
- Debug application issues using logs
- Design new API endpoints

### Recommended Practice

1. **Create 10 test users** with varied data
2. **Write 20 different SQL queries** to analyze user data
3. **Modify the code** to add a "full_name" field
4. **Design on paper** a complete banking API with 10 endpoints

### Prepare for Module 05

Study these concepts for the next module:
- Session management and authentication
- Password hashing (BCrypt)
- JWT tokens
- Spring Security basics

### Additional Challenges

**Challenge 1: Email Uniqueness**
Modify the system to prevent duplicate email addresses.

**Challenge 2: Username Format Validation**
Add validation to only allow alphanumeric usernames with underscores.

**Challenge 3: Minimum Balance**
Change the default balance from $1000 to a configurable value in application.properties.

**Challenge 4: Audit Logging**
Log all registration attempts (successful and failed) to a separate table.

---

**Lab Version:** 1.0
**Last Updated:** January 2025
**Module:** 04 - User Registration System
**Estimated Total Time:** 2.5 - 3 hours
