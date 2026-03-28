# Troubleshooting Guide: SampleBank v2 Login System

## Table of Contents

1. [Authentication Issues](#authentication-issues)
2. [Database Connection Problems](#database-connection-problems)
3. [JWT and Token Issues](#jwt-and-token-issues)
4. [Application Startup Errors](#application-startup-errors)
5. [Performance Issues](#performance-issues)
6. [Browser and Frontend Issues](#browser-and-frontend-issues)
7. [Password and Security Issues](#password-and-security-issues)
8. [Common Error Messages](#common-error-messages)
9. [Development Environment Issues](#development-environment-issues)
10. [Debugging Tips](#debugging-tips)

---

## Authentication Issues

### Issue 1: Login Always Returns "Invalid password"

**Symptoms:**
- Every login attempt fails with "ERROR: Invalid password"
- Even with correct credentials
- Registration works fine

**Possible Causes:**

1. **Password stored with different casing or whitespace**

**Diagnosis:**
```bash
# Check stored password
psql -U postgres -d samplebank1 -c \
  "SELECT username, password_hash FROM users WHERE username = 'testuser';"
```

**Solution 1: Password has extra whitespace**
```sql
-- Update password, removing whitespace
UPDATE users SET password_hash = TRIM(password_hash)
WHERE user_id = 1;
```

**Solution 2: Password case mismatch**
```sql
-- Check if case-insensitive match works
SELECT username, password_hash FROM users
WHERE username = 'testuser'
AND LOWER(password_hash) = LOWER('testpass');

-- If this returns a row, the password has different casing
-- Update to match exactly:
UPDATE users SET password_hash = 'testpass'
WHERE username = 'testuser';
```

2. **User created with different password**

**Solution:**
```sql
-- Reset password for testing
UPDATE users SET password_hash = 'testpass'
WHERE username = 'testuser';
```

3. **Password field contains hashed value from different module**

**Diagnosis:**
```sql
SELECT username, password_hash FROM users;

-- If password_hash looks like: $2a$12$... (bcrypt hash)
-- You're using Module 13 code with Module 05 database
```

**Solution:**
```sql
-- Reset to plain-text for Module 05
UPDATE users SET password_hash = 'testpass'
WHERE username = 'testuser';
```

### Issue 2: "ERROR: User not found" for Existing User

**Symptoms:**
- User exists in database
- Login returns "User not found"
- Registration shows "Username already exists"

**Diagnosis:**
```bash
# Verify user exists
psql -U postgres -d samplebank1 -c \
  "SELECT * FROM users WHERE username = 'testuser';"

# Check exact username (case-sensitive)
psql -U postgres -d samplebank1 -c \
  "SELECT username FROM users WHERE username = 'testuser';"
```

**Possible Causes:**

1. **Case sensitivity**

```sql
-- PostgreSQL is case-sensitive by default
-- 'TestUser' ≠ 'testuser'

-- Check for case mismatch
SELECT username FROM users WHERE LOWER(username) = LOWER('testuser');
```

**Solution:**
```java
// Update AuthController to use case-insensitive search
Optional<User> userOpt = userRepository.findByUsernameIgnoreCase(username);
```

```java
// Add to UserRepository.java
Optional<User> findByUsernameIgnoreCase(String username);
```

2. **Whitespace in username**

```sql
-- Check for hidden whitespace
SELECT username, LENGTH(username), TRIM(username)
FROM users
WHERE username LIKE '%testuser%';

-- Clean whitespace
UPDATE users SET username = TRIM(username);
```

### Issue 3: Login Endpoint Returns 404 Not Found

**Symptoms:**
```
POST http://localhost:8080/login
Response: 404 Not Found
```

**Diagnosis:**
```bash
# Check if AuthController is loaded
curl http://localhost:8080/actuator/mappings 2>/dev/null | grep login

# Or check application logs
grep "Mapped.*login" application.log
```

**Possible Causes:**

1. **AuthController.java not in correct package**

**Verify package structure:**
```
src/main/java/com/samplebank/controller/AuthController.java
                 ^^^^^^^^^^ Must match @SpringBootApplication package
```

**Solution:**
```bash
# Check package declaration
head -n 5 src/main/java/com/samplebank/controller/AuthController.java

# Should show:
# package com.samplebank.controller;
```

2. **Component scanning not configured**

**Solution:**
```java
// Verify @SpringBootApplication includes controller package
@SpringBootApplication
public class SampleBankApplication {
    // Spring Boot automatically scans com.samplebank and sub-packages
}
```

3. **AuthController missing @RestController annotation**

**Solution:**
```java
// Ensure annotation is present
@RestController  // ← Must be present
public class AuthController {
    // ...
}
```

### Issue 4: Empty Response Body

**Symptoms:**
- Login returns HTTP 200
- Response body is empty
- No error messages

**Diagnosis:**
```bash
# Test with verbose output
curl -v -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'
```

**Solution:**
```java
// Ensure ResponseEntity includes body
return ResponseEntity.ok(String.format("Login successful! Balance: $%.2f", user.getBalance()));
//                       ^^^ Must pass response body
```

---

## Database Connection Problems

### Issue 5: "Connection refused" Error

**Symptoms:**
```
org.postgresql.util.PSQLException: Connection to localhost:5432 refused
```

**Diagnosis:**
```bash
# Check if PostgreSQL is running
# Windows:
sc query postgresql-x64-15

# Linux:
sudo systemctl status postgresql

# Mac:
brew services list | grep postgresql
```

**Solution 1: Start PostgreSQL service**

```bash
# Windows:
net start postgresql-x64-15

# Linux:
sudo systemctl start postgresql
sudo systemctl enable postgresql  # Auto-start on boot

# Mac:
brew services start postgresql@15
```

**Solution 2: Verify port**

```bash
# Check PostgreSQL port
psql -U postgres -c "SHOW port;"

# Update application.properties if different
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
                                                    ^^^^ Update port
```

### Issue 6: "password authentication failed for user"

**Symptoms:**
```
PSQLException: FATAL: password authentication failed for user "postgres"
```

**Solution 1: Update application.properties**

```properties
# Verify credentials
spring.datasource.username=postgres
spring.datasource.password=YOUR_ACTUAL_PASSWORD
```

**Solution 2: Reset PostgreSQL password**

```bash
# Windows (as admin):
psql -U postgres
\password postgres
# Enter new password

# Linux:
sudo -u postgres psql
\password postgres
```

**Solution 3: Check pg_hba.conf authentication method**

```bash
# Find pg_hba.conf location
psql -U postgres -c "SHOW hba_file;"

# Edit file (as admin/root)
# Change from 'peer' or 'ident' to 'md5'
# host    all    all    127.0.0.1/32    md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Issue 7: Database "samplebank1" does not exist

**Symptoms:**
```
PSQLException: FATAL: database "samplebank1" does not exist
```

**Solution:**
```bash
# Create database
psql -U postgres -c "CREATE DATABASE samplebank1;"

# Verify creation
psql -U postgres -c "\l" | grep samplebank1

# Create schema
psql -U postgres -d samplebank1 -f database/schema.sql
```

### Issue 8: Table "users" doesn't exist

**Symptoms:**
```
PSQLException: ERROR: relation "users" does not exist
```

**Diagnosis:**
```bash
# Check if table exists
psql -U postgres -d samplebank1 -c "\dt"
```

**Solution:**
```bash
# Create table manually
psql -U postgres -d samplebank1 << EOF
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

# Or use JPA auto-creation
# In application.properties:
# spring.jpa.hibernate.ddl-auto=create
```

---

## JWT and Token Issues

**Note:** Module 05 does NOT implement JWT tokens. JWT will be introduced in Module 16.

### Issue 9: "No JWT found in request"

**Diagnosis:**
This error indicates you're running Module 16 code with Module 05 setup.

**Solution:**
```bash
# Verify you're using Module 05 code
grep -r "JWT" src/main/java/
# Should return nothing for Module 05

# If JWT code exists, you need Module 16 documentation
```

**Module 05 Authentication:**
- No tokens
- No sessions
- Stateless authentication
- Each request is independent

---

## Application Startup Errors

### Issue 10: "Error: Could not find or load main class"

**Symptoms:**
```
Error: Could not find or load main class com.samplebank.SampleBankApplication
```

**Solution 1: Clean and rebuild**
```bash
mvn clean install
mvn spring-boot:run
```

**Solution 2: Verify main class exists**
```bash
# Check file exists
ls -l src/main/java/com/samplebank/SampleBankApplication.java

# Verify package declaration
head -n 1 src/main/java/com/samplebank/SampleBankApplication.java
# Should be: package com.samplebank;
```

**Solution 3: IDE refresh**
```bash
# IntelliJ IDEA:
File → Invalidate Caches / Restart

# Eclipse:
Project → Clean → Clean all projects
```

### Issue 11: Port 8080 Already in Use

**Symptoms:**
```
Web server failed to start. Port 8080 was already in use.
```

**Solution 1: Change port**

```properties
# application.properties
server.port=8081
```

**Solution 2: Kill existing process**

```bash
# Windows:
netstat -ano | findstr :8080
taskkill /PID <PID> /F

# Linux/Mac:
lsof -i :8080
kill -9 <PID>

# Or use alternative:
sudo fuser -k 8080/tcp
```

### Issue 12: Maven Dependency Errors

**Symptoms:**
```
Could not resolve dependencies for project com.samplebank:samplebank:jar:1.0.0
```

**Solution:**
```bash
# Clear Maven cache
rm -rf ~/.m2/repository

# Re-download dependencies
mvn clean install -U

# If behind corporate proxy, configure ~/.m2/settings.xml:
<proxies>
  <proxy>
    <host>proxy.company.com</host>
    <port>8080</port>
  </proxy>
</proxies>
```

---

## Performance Issues

### Issue 13: Login Takes Several Seconds

**Symptoms:**
- Login request takes 5-10 seconds
- Database has many users (10,000+)

**Diagnosis:**
```sql
-- Check if index exists
\di idx_users_username

-- Check query plan
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'testuser';

-- Look for "Seq Scan" (bad) vs "Index Scan" (good)
```

**Solution 1: Create missing index**
```sql
CREATE INDEX idx_users_username ON users(username);
ANALYZE users;
```

**Solution 2: Remove duplicate index**
```sql
-- If you have both users_username_key and idx_users_username
-- Keep only the unique constraint index
DROP INDEX idx_users_username;
```

**Solution 3: Update table statistics**
```sql
ANALYZE users;
```

### Issue 14: High CPU Usage During Login

**Diagnosis:**
```bash
# Monitor PostgreSQL processes
ps aux | grep postgres

# Check slow queries
psql -U postgres -d samplebank1 -c "
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
WHERE query LIKE '%users%'
ORDER BY mean_exec_time DESC
LIMIT 10;
"
```

**Solution:**
Enable connection pooling and tune pool size:

```properties
# application.properties
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
```

---

## Browser and Frontend Issues

### Issue 15: CORS Error in Browser Console

**Symptoms:**
```
Access to XMLHttpRequest at 'http://localhost:8080/login' from origin
'null' has been blocked by CORS policy
```

**Cause:**
Opening HTML files directly (file:// protocol) instead of through server.

**Solution:**
```bash
# Always access via http://localhost:8080
# NOT file:///path/to/login.html

# Verify correct URL
curl http://localhost:8080/login.html
```

**If CORS is needed for different domain:**

```java
@RestController
@CrossOrigin(origins = "http://localhost:3000")  // Add CORS
public class AuthController {
    // ...
}
```

### Issue 16: JavaScript Error: "Unexpected token"

**Symptoms:**
```
Uncaught SyntaxError: Unexpected token < in JSON at position 0
```

**Cause:**
Server returning HTML error page instead of JSON.

**Diagnosis:**
```bash
# Test API directly
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"pass"}'

# If response starts with "<!DOCTYPE", server is returning HTML
```

**Solution:**
```java
// Ensure controller returns proper content type
@PostMapping(value = "/login", produces = "application/json")
public ResponseEntity<String> login(...) {
    // Return JSON or plain text, not HTML
}
```

### Issue 17: Login Form Submits but Nothing Happens

**Diagnosis:**
```javascript
// Check browser console (F12)
// Look for JavaScript errors

// Verify fetch API is working
fetch('/login', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({username: 'test', password: 'pass'})
})
.then(r => r.text())
.then(console.log)
.catch(console.error);
```

**Solution:**
Check login.html JavaScript for errors:

```javascript
// Ensure event listener is attached
document.getElementById('loginForm').addEventListener('submit', async function(e) {
    e.preventDefault();  // Prevent default form submission
    // ... rest of code
});
```

---

## Password and Security Issues

### Issue 18: Passwords Not Hashing (Module 05 Expected)

**Note:** Module 05 intentionally does NOT hash passwords for educational purposes.

**Expected Behavior:**
```sql
-- Plain-text storage (Module 05)
SELECT username, password_hash FROM users;
-- password_hash will show: "testpass" (plain text)
```

**If you need password hashing:**
- See Module 13 documentation
- Implement BCrypt hashing
- Migrate existing passwords

### Issue 19: Session Not Persisting Between Requests

**Expected Behavior:**
Module 05 is STATELESS. Each request is independent.

```bash
# Request 1: Login
curl -X POST http://localhost:8080/login -d '...'
# Returns balance

# Request 2: Another request
curl -X POST http://localhost:8080/login -d '...'
# Must login again - no session maintained
```

**If you need sessions:**
- See Module 16 for JWT implementation
- Or implement server-side sessions with Spring Security

---

## Common Error Messages

### Error: "Username is required"

**Cause:** Empty or null username in request

**Solution:**
```bash
# Ensure username is provided
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'
  #             ^^^^^^^^^ Must not be empty
```

### Error: "Invalid password"

**Cause:** Password mismatch

**Diagnosis:**
```sql
SELECT username, password_hash FROM users WHERE username = 'testuser';
-- Compare password_hash with what you're sending
```

**Solution:**
Ensure exact match (case-sensitive, no whitespace).

### Error: "User not found"

**Cause:** Username doesn't exist in database

**Diagnosis:**
```sql
SELECT username FROM users WHERE username = 'testuser';
-- If returns 0 rows, user doesn't exist
```

**Solution:**
Register the user first at http://localhost:8080/

---

## Development Environment Issues

### Issue 20: IntelliJ IDEA Not Recognizing @Autowired

**Symptoms:**
- Red underline on `@Autowired`
- "Cannot resolve symbol 'Autowired'"

**Solution:**
```bash
# Re-import Maven project
Right-click pom.xml → Maven → Reload Project

# Verify Spring dependency exists
grep "spring-boot-starter" pom.xml
```

### Issue 21: Hot Reload Not Working

**Solution:**
Add Spring Boot DevTools:

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
    <optional>true</optional>
</dependency>
```

Enable in IntelliJ:
```
Settings → Build → Compiler → Build project automatically (check)
Settings → Advanced Settings → Allow auto-make to start (check)
```

---

## Debugging Tips

### Enable SQL Logging

```properties
# application.properties
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

### Enable Request Logging

```properties
logging.level.org.springframework.web=DEBUG
logging.level.com.samplebank=DEBUG
```

### Test with curl Verbose Mode

```bash
curl -v -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'

# Shows full HTTP headers and response
```

### PostgreSQL Query Logging

```bash
# Edit postgresql.conf
log_statement = 'all'
log_duration = on

# Restart PostgreSQL
sudo systemctl restart postgresql

# View logs
tail -f /var/log/postgresql/postgresql-15-main.log
```

### Remote Debugging (IntelliJ)

```bash
# Start application in debug mode
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005"

# IntelliJ: Run → Edit Configurations → + → Remote JVM Debug
# Port: 5005
# Click Debug
```

---

## Getting Help

### Information to Provide

When seeking help, include:

1. **Error message** (full stack trace)
2. **Application logs** (last 50 lines)
3. **Database logs** (if relevant)
4. **Steps to reproduce**
5. **Environment details**:
   - OS and version
   - Java version (`java -version`)
   - PostgreSQL version (`psql --version`)
   - Maven version (`mvn -version`)

### Useful Commands for Diagnostics

```bash
# Application info
mvn dependency:tree         # Show all dependencies
mvn spring-boot:run -X      # Debug mode

# Database info
psql -U postgres -d samplebank1 -c "\d users"      # Table structure
psql -U postgres -d samplebank1 -c "\di"           # Indexes
psql -U postgres -d samplebank1 -c "SELECT version();"  # PostgreSQL version

# System info
java -version
mvn -version
psql --version
netstat -an | grep 8080    # Check if port is in use
```

---

**Troubleshooting Guide Version:** 1.0
**Last Updated:** January 2024
**Module:** 05 - SampleBank v2 Login System
