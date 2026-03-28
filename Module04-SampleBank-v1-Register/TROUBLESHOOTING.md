# SampleBank Troubleshooting Guide

## Table of Contents
1. [Database Connection Issues](#database-connection-issues)
2. [Application Startup Problems](#application-startup-problems)
3. [Build Failures](#build-failures)
4. [API Request Errors](#api-request-errors)
5. [Database Errors](#database-errors)
6. [Port Conflicts](#port-conflicts)
7. [JPA and Hibernate Issues](#jpa-and-hibernate-issues)
8. [Common Student Mistakes](#common-student-mistakes)
9. [Performance Issues](#performance-issues)
10. [Getting Additional Help](#getting-additional-help)

---

## Database Connection Issues

### Error: "Connection refused" or "Could not connect to PostgreSQL"

**Symptoms:**
```
org.postgresql.util.PSQLException: Connection to localhost:5432 refused.
Check that the hostname and port are correct and that the postmaster is accepting TCP/IP connections.
```

**Causes and Solutions:**

**1. PostgreSQL Not Running**

Check if PostgreSQL is running:

**Windows:**
```cmd
# Check service status
sc query postgresql-x64-14

# Start service if stopped
net start postgresql-x64-14
```

**Linux:**
```bash
# Check status
sudo systemctl status postgresql

# Start if stopped
sudo systemctl start postgresql

# Enable auto-start on boot
sudo systemctl enable postgresql
```

**macOS:**
```bash
# Check if running
brew services list

# Start if stopped
brew services start postgresql@14
```

**2. Wrong Port Number**

Verify PostgreSQL is running on port 5432:
```sql
-- Connect to PostgreSQL
psql -U postgres

-- Check port
SHOW port;
```

If different port, update `application.properties`:
```properties
spring.datasource.url=jdbc:postgresql://localhost:ACTUAL_PORT/samplebank1
```

**3. Wrong Database Name**

Verify database exists:
```bash
psql -U postgres -l
```

Look for `samplebank1` in the list. If missing:
```bash
psql -U postgres -c "CREATE DATABASE samplebank1;"
psql -U postgres -d samplebank1 -f database/schema.sql
```

**4. Authentication Failure**

**Error:**
```
PSQLException: FATAL: password authentication failed for user "postgres"
```

**Solution:**
Update password in `application.properties`:
```properties
spring.datasource.password=YOUR_ACTUAL_PASSWORD
```

Reset PostgreSQL password if forgotten:
```bash
# Linux - edit pg_hba.conf to trust, then:
psql -U postgres
ALTER USER postgres PASSWORD 'newpassword';
\q
# Revert pg_hba.conf changes and restart PostgreSQL
```

---

## Application Startup Problems

### Error: "Port 8080 already in use"

**Symptoms:**
```
Web server failed to start. Port 8080 was already in use.
```

**Solutions:**

**Option 1: Stop the Conflicting Process**

**Windows:**
```cmd
# Find process using port 8080
netstat -ano | findstr :8080

# Kill process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

**Linux/macOS:**
```bash
# Find process using port 8080
lsof -i :8080

# Kill process (replace PID with actual process ID)
kill -9 <PID>
```

**Option 2: Change Application Port**

Add to `application.properties`:
```properties
server.port=8081
```

Then use `http://localhost:8081` for API requests.

### Error: "Failed to configure a DataSource"

**Symptoms:**
```
Failed to configure a DataSource: 'url' attribute is not specified and no embedded datasource could be configured.
```

**Causes:**
- Missing database configuration in `application.properties`
- Configuration file not in correct location

**Solution:**

Verify `src/main/resources/application.properties` exists with:
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
spring.datasource.username=postgres
spring.datasource.password=postgres
```

Rebuild application:
```bash
mvn clean package
```

### Error: "Cannot find main class"

**Symptoms:**
```
Error: Could not find or load main class com.samplebank.SampleBankApplication
```

**Solutions:**

1. **Rebuild application:**
   ```bash
   mvn clean package
   ```

2. **Verify JAR file exists:**
   ```bash
   ls target/samplebank-*.jar
   ```

3. **Check Java version:**
   ```bash
   java -version
   # Must be Java 11 or higher
   ```

---

## Build Failures

### Error: "JAVA_HOME not set"

**Symptoms:**
```
ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
```

**Solution:**

**Windows:**
```cmd
# Set JAVA_HOME
set JAVA_HOME=C:\Program Files\Java\jdk-11
set PATH=%JAVA_HOME%\bin;%PATH%

# Verify
echo %JAVA_HOME%
java -version
```

**Linux/macOS:**
```bash
# Add to ~/.bashrc or ~/.profile
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Reload configuration
source ~/.bashrc

# Verify
echo $JAVA_HOME
java -version
```

### Error: "Cannot download dependencies"

**Symptoms:**
```
Could not resolve dependencies for project com.samplebank:samplebank:jar:1.0.0
Could not transfer artifact...
```

**Causes:**
- No internet connection
- Corporate firewall blocking Maven Central
- Corrupted local Maven repository

**Solutions:**

**1. Check Internet Connection**
```bash
ping repo.maven.apache.org
```

**2. Clear Maven Cache**
```bash
# Windows
rmdir /S /Q %USERPROFILE%\.m2\repository

# Linux/macOS
rm -rf ~/.m2/repository

# Rebuild
mvn clean package
```

**3. Configure Proxy** (if behind corporate firewall)

Edit `~/.m2/settings.xml`:
```xml
<settings>
  <proxies>
    <proxy>
      <id>myproxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>proxy.company.com</host>
      <port>8080</port>
    </proxy>
  </proxies>
</settings>
```

### Error: "Compilation failure - package does not exist"

**Symptoms:**
```
[ERROR] package org.springframework.boot does not exist
```

**Solution:**

Dependencies not downloaded. Force download:
```bash
mvn dependency:resolve
mvn clean package
```

---

## API Request Errors

### Error: 404 Not Found on /register

**Symptom:**
```bash
curl http://localhost:8080/register
# Returns: 404 Not Found
```

**Causes:**
- Using GET instead of POST
- Wrong URL
- Application not started

**Solution:**

Use POST method:
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","password":"pass"}'
```

Verify application is running:
```bash
curl http://localhost:8080
# Should return 404 with JSON error (proves server is running)
```

### Error: 400 Bad Request with No Message

**Symptom:**
```bash
curl -X POST http://localhost:8080/register \
  -d '{"username":"test","email":"test@example.com","password":"pass"}'
# Returns: 400 Bad Request
```

**Cause:** Missing Content-Type header

**Solution:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","password":"pass"}'
```

### Error: "Unsupported Media Type" (415)

**Cause:** Wrong Content-Type header

**Solution:**
Use `Content-Type: application/json` (not `text/plain` or `application/x-www-form-urlencoded`)

### Error: JSON Parsing Error

**Symptoms:**
```
JSON parse error: Unexpected character...
```

**Causes:**
- Invalid JSON syntax
- Missing quotes around keys/values
- Extra commas

**Example Invalid JSON:**
```json
{username:"test", email:"test@example.com"}  // Missing quotes around keys
{"username":"test","email":"test@example.com",}  // Extra comma
```

**Valid JSON:**
```json
{"username":"test","email":"test@example.com","password":"pass"}
```

**Validation Tool:**
Use https://jsonlint.com to validate JSON syntax

---

## Database Errors

### Error: "Relation 'users' does not exist"

**Symptoms:**
```
PSQLException: ERROR: relation "users" does not exist
```

**Cause:** Table not created

**Solution:**

**Option 1: Run Schema Script**
```bash
psql -U postgres -d samplebank1 -f database/schema.sql
```

**Option 2: Let Hibernate Create (Auto-DDL)**

Verify `application.properties`:
```properties
spring.jpa.hibernate.ddl-auto=update
```

Restart application - Hibernate will create table.

**Option 3: Manual Creation**
```sql
psql -U postgres -d samplebank1

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Error: "Column 'password_hash' does not exist"

**Symptoms:**
```
PSQLException: ERROR: column "password_hash" of relation "users" does not exist
```

**Cause:** Schema mismatch between database and entity

**Solution:**

Drop and recreate table:
```sql
DROP TABLE users CASCADE;
```

Then run schema script or restart application with `ddl-auto=update`.

### Error: "Duplicate key value violates unique constraint"

**Symptoms:**
```
PSQLException: ERROR: duplicate key value violates unique constraint "users_username_key"
Detail: Key (username)=(test) already exists.
```

**Cause:** Attempting to register existing username

**Solution:**

This is expected behavior. Use a different username:
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test2","email":"test2@example.com","password":"pass"}'
```

Or delete existing user:
```sql
DELETE FROM users WHERE username = 'test';
```

### Error: "Check constraint violation" (Negative Balance)

**Symptoms:**
```
PSQLException: ERROR: new row violates check constraint "users_balance_check"
```

**Cause:** Attempting to set balance below 0

**Solution:**

This is by design. Balance cannot be negative. Ensure balance >= 0 in all operations.

---

## Port Conflicts

### PostgreSQL Port 5432 Conflict

**Symptom:**
PostgreSQL won't start, complains port in use.

**Solution:**

**Windows:**
```cmd
netstat -ano | findstr :5432
taskkill /PID <PID> /F
```

**Linux:**
```bash
sudo lsof -i :5432
sudo kill <PID>
```

Or change PostgreSQL port in `postgresql.conf` and update `application.properties`.

---

## JPA and Hibernate Issues

### Error: "No identifier specified for entity"

**Symptoms:**
```
No identifier specified for entity: User
```

**Cause:** Missing `@Id` annotation on entity

**Solution:**

Verify `User.java` has:
```java
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
private Long userId;
```

### Error: "Table 'users' doesn't auto-update"

**Cause:** `ddl-auto` setting

**Solutions:**

**Development: Auto-update schema**
```properties
spring.jpa.hibernate.ddl-auto=update
```

**Production: Manual migrations**
```properties
spring.jpa.hibernate.ddl-auto=validate
```

**Create-drop (recreates on each run - loses data!):**
```properties
spring.jpa.hibernate.ddl-auto=create-drop
```

### SQL Logging Not Showing

**Verify in application.properties:**
```properties
spring.jpa.show-sql=true
```

**For formatted SQL:**
```properties
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
```

---

## Common Student Mistakes

### Mistake 1: Wrong Working Directory

**Symptom:** Files not found when running scripts

**Solution:**
```bash
# Navigate to project root
cd Module04-SampleBank-v1-Register

# Verify correct directory
ls pom.xml  # Should exist
```

### Mistake 2: Editing Compiled Class Instead of Source

**Mistake:** Editing `target/classes/com/samplebank/...`

**Correct:** Edit `src/main/java/com/samplebank/...`

**After editing, always rebuild:**
```bash
mvn clean package
```

### Mistake 3: Not Restarting After Code Changes

Code changes require rebuild and restart:
```bash
# Stop application (Ctrl+C)
mvn clean package
java -jar target/samplebank-1.0.0.jar
```

### Mistake 4: Using Wrong HTTP Method

Registration requires POST, not GET:
```bash
# WRONG
curl http://localhost:8080/register

# CORRECT
curl -X POST http://localhost:8080/register ...
```

### Mistake 5: Testing with Browser (GET Requests)

Browsers send GET requests by default. Use curl or Postman for POST requests.

### Mistake 6: Forgetting Content-Type Header

Always include `Content-Type: application/json` for JSON APIs.

### Mistake 7: Wrong Database Name

Database name is `samplebank1` (with "1"), not `samplebank`.

---

## Performance Issues

### Slow Application Startup

**Causes:**
- First startup downloads dependencies (normal)
- Antivirus scanning JAR files
- Slow disk I/O

**Solutions:**
- Wait for first startup (can take 2-3 minutes)
- Add Maven repository to antivirus exclusions
- Use SSD instead of HDD

### Slow Database Queries

For learning purposes, performance should be instant with small datasets.

If slow:
```sql
-- Analyze table statistics
ANALYZE users;

-- Check indexes exist
\d users
```

---

## Getting Additional Help

### Check Application Logs

Review console output for error messages and stack traces.

### Enable Debug Logging

Add to `application.properties`:
```properties
logging.level.org.springframework=DEBUG
logging.level.org.hibernate=DEBUG
```

### Verify Environment

Run diagnostics:
```bash
# Java version
java -version

# Maven version
mvn -version

# PostgreSQL version
psql --version

# PostgreSQL running?
psql -U postgres -c "SELECT version();"

# Database exists?
psql -U postgres -l | grep samplebank1

# Table exists?
psql -U postgres -d samplebank1 -c "\dt"
```

### Common Diagnostic Commands

**Check if application is running:**
```bash
curl http://localhost:8080
# 404 = running, connection refused = not running
```

**Check PostgreSQL connectivity:**
```bash
psql -U postgres -d samplebank1 -c "SELECT 1;"
# Returns "1" if working
```

**Test registration manually:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"diagnostic","email":"diag@example.com","password":"test"}'
```

### Resources

- **Spring Boot Docs:** https://spring.io/projects/spring-boot
- **PostgreSQL Docs:** https://www.postgresql.org/docs/
- **Maven Docs:** https://maven.apache.org/guides/
- **Stack Overflow:** Tag questions with `spring-boot`, `postgresql`, `jpa`

### Contact Support

When asking for help, provide:
1. **Error message** (full stack trace)
2. **Steps to reproduce**
3. **Environment details** (OS, Java version, PostgreSQL version)
4. **Configuration files** (application.properties, pom.xml)
5. **What you've already tried**

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Module:** 04 - User Registration System
