# SampleBank v3 - Setup Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Database Configuration](#database-configuration)
4. [Application Installation](#application-installation)
5. [Building the Project](#building-the-project)
6. [Running the Application](#running-the-application)
7. [Verification Steps](#verification-steps)
8. [Configuration Options](#configuration-options)
9. [Troubleshooting Setup Issues](#troubleshooting-setup-issues)

## Prerequisites

### Required Software

#### 1. Java Development Kit (JDK)
- **Version**: JDK 11 or higher (JDK 17 recommended)
- **Download**: https://adoptium.net/

**Verify Installation:**
```bash
java -version
# Expected output: java version "11.0.x" or higher

javac -version
# Expected output: javac 11.0.x or higher
```

#### 2. PostgreSQL Database
- **Version**: PostgreSQL 12 or higher (PostgreSQL 14+ recommended)
- **Download**: https://www.postgresql.org/download/

**Verify Installation:**
```bash
psql --version
# Expected output: psql (PostgreSQL) 12.x or higher
```

#### 3. Apache Maven
- **Version**: Maven 3.6 or higher
- **Download**: https://maven.apache.org/download.cgi

**Verify Installation:**
```bash
mvn -version
# Expected output: Apache Maven 3.6.x or higher
```

#### 4. Git (Optional, for cloning)
- **Version**: Any recent version
- **Download**: https://git-scm.com/downloads

**Verify Installation:**
```bash
git --version
# Expected output: git version 2.x.x
```

### Optional Tools

#### cURL (for API testing)
- Usually pre-installed on Linux/Mac
- Windows: Download from https://curl.se/windows/

#### Postman (for API testing)
- Download from https://www.postman.com/downloads/

#### pgAdmin (for database management)
- Download from https://www.pgadmin.org/download/

## Environment Setup

### 1. Set JAVA_HOME Environment Variable

**Windows:**
```batch
# Open Command Prompt as Administrator
setx JAVA_HOME "C:\Program Files\Java\jdk-11.0.x"
setx PATH "%PATH%;%JAVA_HOME%\bin"

# Restart Command Prompt and verify
echo %JAVA_HOME%
```

**Linux/Mac:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export PATH=$JAVA_HOME/bin:$PATH

# Reload configuration
source ~/.bashrc

# Verify
echo $JAVA_HOME
```

### 2. Configure Maven (Optional)

**Increase Memory (if needed):**

Create/edit `~/.mavenrc` (Linux/Mac) or `%USERPROFILE%\.mavenrc` (Windows):
```bash
export MAVEN_OPTS="-Xmx1024m -XX:MaxPermSize=256m"
```

## Database Configuration

### Step 1: Start PostgreSQL Service

**Windows:**
```batch
# Start PostgreSQL service
net start postgresql-x64-14

# Or use Services GUI: services.msc
```

**Linux:**
```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql  # Start on boot
```

**Mac:**
```bash
brew services start postgresql
```

### Step 2: Create Database

**Connect to PostgreSQL:**
```bash
# Default superuser connection
psql -U postgres

# Or specify host and port
psql -h localhost -p 5432 -U postgres
```

**Create SampleBank Database:**
```sql
-- Create database
CREATE DATABASE samplebank;

-- List databases to verify
\l

-- Connect to the new database
\c samplebank

-- Verify connection
SELECT current_database();
```

### Step 3: Create Users Table

**Create the schema from previous modules:**
```sql
-- Create users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on username for fast lookups
CREATE INDEX idx_users_username ON users(username);

-- Verify table creation
\dt

-- Describe the table structure
\d users
```

### Step 4: Create Transactions Table

**Run the transactions schema:**
```sql
-- Create transactions table
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_user_id INT NOT NULL REFERENCES users(user_id),
    to_user_id INT NOT NULL REFERENCES users(user_id),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_user_id != to_user_id)
);

-- Create indexes for performance
CREATE INDEX idx_transactions_from ON transactions(from_user_id);
CREATE INDEX idx_transactions_to ON transactions(to_user_id);

-- Verify table creation
\d transactions
```

**Or run from SQL file:**
```bash
# Navigate to the database directory
cd Module06-SampleBank-v3-Transactions/database

# Run the schema script
psql -U postgres -d samplebank -f transactions-schema.sql
```

### Step 5: Create transfer_money() Stored Procedure

**Complete the stored procedure:**
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
    -- 1. Look up sender and get balance
    SELECT user_id, balance INTO v_from_user_id, v_from_balance
    FROM users
    WHERE username = p_from_username;

    -- 2. Check if sender exists
    IF v_from_user_id IS NULL THEN
        RETURN 'ERROR: Sender not found';
    END IF;

    -- 3. Check if sender has sufficient balance
    IF v_from_balance < p_amount THEN
        RETURN 'ERROR: Insufficient balance';
    END IF;

    -- 4. Look up receiver
    SELECT user_id INTO v_to_user_id
    FROM users
    WHERE username = p_to_username;

    -- 5. Check if receiver exists
    IF v_to_user_id IS NULL THEN
        RETURN 'ERROR: Receiver not found';
    END IF;

    -- 6. Deduct amount from sender
    UPDATE users
    SET balance = balance - p_amount
    WHERE user_id = v_from_user_id;

    -- 7. Add amount to receiver
    UPDATE users
    SET balance = balance + p_amount
    WHERE user_id = v_to_user_id;

    -- 8. Record transaction
    INSERT INTO transactions (from_user_id, to_user_id, amount)
    VALUES (v_from_user_id, v_to_user_id, p_amount);

    -- 9. Return success message
    RETURN 'SUCCESS: Transferred $' || p_amount || ' from ' ||
           p_from_username || ' to ' || p_to_username;
END;
$$ LANGUAGE plpgsql;
```

**Or run from SQL file:**
```bash
psql -U postgres -d samplebank -f transfer-procedure.sql
```

**Verify the function:**
```sql
-- List functions
\df transfer_money

-- Test the function (will fail until users exist)
SELECT transfer_money('alice', 'bob', 100.00);
```

### Step 6: Create Test Data (Optional)

```sql
-- Insert test users
INSERT INTO users (username, email, password, balance)
VALUES
    ('alice', 'alice@test.com', 'password123', 1000.00),
    ('bob', 'bob@test.com', 'password456', 1000.00),
    ('charlie', 'charlie@test.com', 'password789', 1500.00);

-- Verify inserted users
SELECT user_id, username, email, balance FROM users;

-- Test transfer function
SELECT transfer_money('alice', 'bob', 250.00);

-- Verify balances changed
SELECT username, balance FROM users WHERE username IN ('alice', 'bob');

-- Verify transaction recorded
SELECT * FROM transactions ORDER BY created_at DESC;
```

## Application Installation

### Step 1: Download/Clone the Project

**If using Git:**
```bash
git clone <repository-url>
cd Module06-SampleBank-v3-Transactions
```

**Or extract from ZIP:**
```bash
unzip Module06-SampleBank-v3-Transactions.zip
cd Module06-SampleBank-v3-Transactions
```

### Step 2: Project Structure Verification

Verify the following structure exists:
```
Module06-SampleBank-v3-Transactions/
├── src/
│   └── main/
│       ├── java/com/samplebank/
│       │   ├── SampleBankApplication.java (from previous modules)
│       │   ├── controller/
│       │   │   ├── UserController.java (from Module 04)
│       │   │   ├── AuthController.java (from Module 05)
│       │   │   └── TransferController.java (NEW)
│       │   ├── entity/
│       │   │   ├── User.java (from Module 04)
│       │   │   └── Transaction.java (NEW)
│       │   └── repository/
│       │       ├── UserRepository.java (from Module 04)
│       │       └── TransactionRepository.java (NEW)
│       └── resources/
│           ├── application.properties
│           └── static/
│               ├── index.html (from Module 04)
│               ├── login.html (updated in Module 05)
│               └── dashboard.html (NEW)
├── database/
│   ├── schema.sql (from Module 04)
│   ├── transactions-schema.sql (NEW)
│   └── transfer-procedure.sql (NEW)
└── pom.xml
```

### Step 3: Configure Application Properties

**Create/Edit:** `src/main/resources/application.properties`

```properties
# Server Configuration
server.port=8080

# Database Configuration
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank
spring.datasource.username=postgres
spring.datasource.password=your_password_here
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA/Hibernate Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.properties.hibernate.format_sql=true

# Logging
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

**Security Note:** Never commit passwords to version control. Use environment variables:
```properties
spring.datasource.password=${DB_PASSWORD}
```

Then set environment variable:
```bash
export DB_PASSWORD=your_password_here
```

### Step 4: Verify Dependencies (pom.xml)

If `pom.xml` doesn't exist, create it with these essential dependencies:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.14</version>
        <relativePath/>
    </parent>

    <groupId>com.samplebank</groupId>
    <artifactId>samplebank-v3</artifactId>
    <version>3.0.0</version>
    <name>SampleBank-v3-Transactions</name>

    <properties>
        <java.version>11</java.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Data JPA -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <!-- PostgreSQL Driver -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>

        <!-- Spring Boot Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

## Building the Project

### Step 1: Clean Previous Builds
```bash
mvn clean
```

### Step 2: Download Dependencies
```bash
mvn dependency:resolve
```

### Step 3: Compile the Project
```bash
mvn compile
```

**Expected Output:**
```
[INFO] BUILD SUCCESS
[INFO] Total time: 5.432 s
```

### Step 4: Package the Application
```bash
mvn package
```

This creates: `target/samplebank-v3-3.0.0.jar`

### Common Build Issues

**Issue: Maven not found**
```bash
# Add Maven to PATH or use Maven wrapper
./mvnw clean install  # Unix/Mac
mvnw.cmd clean install  # Windows
```

**Issue: Dependency download failures**
```bash
# Clear Maven cache and retry
rm -rf ~/.m2/repository
mvn clean install
```

## Running the Application

### Method 1: Using Maven (Development)
```bash
mvn spring-boot:run
```

### Method 2: Using JAR (Production)
```bash
java -jar target/samplebank-v3-3.0.0.jar
```

### Method 3: Using IDE
- **IntelliJ IDEA**: Right-click SampleBankApplication.java → Run
- **Eclipse**: Right-click project → Run As → Spring Boot App
- **VS Code**: Use Spring Boot Dashboard extension

### Expected Startup Output
```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::        (v2.7.14)

2024-01-26 10:30:45.123  INFO --- [main] c.s.SampleBankApplication: Starting SampleBankApplication
2024-01-26 10:30:47.456  INFO --- [main] o.s.b.w.embedded.tomcat.TomcatWebServer: Tomcat started on port(s): 8080 (http)
2024-01-26 10:30:47.789  INFO --- [main] c.s.SampleBankApplication: Started SampleBankApplication in 3.456 seconds
```

### Stopping the Application
- **Maven/JAR**: Press `Ctrl+C`
- **IDE**: Click Stop button

## Verification Steps

### Step 1: Check Application Health

**Open browser:** http://localhost:8080

You should see the registration page (index.html) or a Whitelabel Error Page (indicating the app is running).

### Step 2: Test API Endpoints

**Register Two Users:**
```bash
# Register Alice
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@test.com","password":"pass123"}'

# Expected: User registered successfully

# Register Bob
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","email":"bob@test.com","password":"pass456"}'

# Expected: User registered successfully
```

**Check Balances:**
```bash
curl http://localhost:8080/balance/alice
# Expected: Balance for alice: $1000.00

curl http://localhost:8080/balance/bob
# Expected: Balance for bob: $1000.00
```

**Perform Transfer:**
```bash
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"250.00"}'

# Expected: SUCCESS: Transferred $250.00 from alice to bob
```

**Verify Updated Balances:**
```bash
curl http://localhost:8080/balance/alice
# Expected: Balance for alice: $750.00

curl http://localhost:8080/balance/bob
# Expected: Balance for bob: $1250.00
```

### Step 3: Verify Database Records

```bash
psql -U postgres -d samplebank
```

```sql
-- Check user balances
SELECT user_id, username, balance FROM users;

-- Check transaction history
SELECT
    transaction_id,
    from_user_id,
    to_user_id,
    amount,
    created_at
FROM transactions
ORDER BY created_at DESC
LIMIT 10;

-- Verify transaction with user details
SELECT
    t.transaction_id,
    u1.username AS sender,
    u2.username AS receiver,
    t.amount,
    t.created_at
FROM transactions t
JOIN users u1 ON t.from_user_id = u1.user_id
JOIN users u2 ON t.to_user_id = u2.user_id
ORDER BY t.created_at DESC;
```

### Step 4: Test Web Interface

1. **Open:** http://localhost:8080
2. **Register** a new user
3. **Login** with credentials
4. **Dashboard** should display with $1000.00 balance
5. **Transfer** money to another user
6. **Balance** should update automatically

## Configuration Options

### Custom Port
```properties
# Change default port from 8080
server.port=9090
```

### Database Connection Pool
```properties
# HikariCP (default in Spring Boot)
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000
```

### Logging Levels
```properties
# Application logging
logging.level.com.samplebank=DEBUG

# SQL logging
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE

# Spring Framework logging
logging.level.org.springframework.web=INFO
```

### Production Profile

**Create:** `application-prod.properties`
```properties
server.port=8080
spring.jpa.show-sql=false
logging.level.root=WARN
spring.datasource.url=${DATABASE_URL}
```

**Run with profile:**
```bash
mvn spring-boot:run -Dspring-boot.run.profiles=prod
```

## Troubleshooting Setup Issues

### Issue: Port Already in Use
```
Error: Port 8080 is already in use
```

**Solution 1:** Change port in application.properties
```properties
server.port=8081
```

**Solution 2:** Kill process using port 8080
```bash
# Windows
netstat -ano | findstr :8080
taskkill /PID <PID> /F

# Linux/Mac
lsof -ti:8080 | xargs kill -9
```

### Issue: Database Connection Failed
```
Error: Connection refused - connect(2) for "localhost" port 5432
```

**Solutions:**
1. Verify PostgreSQL is running: `systemctl status postgresql`
2. Check connection parameters in application.properties
3. Test manual connection: `psql -U postgres -d samplebank`
4. Verify PostgreSQL is listening on correct port:
   ```bash
   netstat -an | grep 5432
   ```

### Issue: Maven Build Failures
```
Error: Failed to execute goal
```

**Solutions:**
1. Clear Maven cache: `rm -rf ~/.m2/repository`
2. Update Maven: `mvn --version` (upgrade if < 3.6)
3. Check Java version: `java -version` (must be 11+)
4. Validate pom.xml syntax

### Issue: JPA Entity Not Found
```
Error: Table "transactions" doesn't exist
```

**Solutions:**
1. Run database schema scripts
2. Set `spring.jpa.hibernate.ddl-auto=create` (development only)
3. Verify database connection
4. Check entity annotations

## Next Steps

After successful setup:
1. Review [DATABASE-SCHEMA.md](DATABASE-SCHEMA.md) for schema details
2. Follow [LAB-EXERCISES.md](LAB-EXERCISES.md) for hands-on practice
3. Consult [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
4. Read [ARCHITECTURE.md](ARCHITECTURE.md) for design details

## Quick Reference

### Start Everything
```bash
# Start PostgreSQL
sudo systemctl start postgresql

# Start Application
cd Module06-SampleBank-v3-Transactions
mvn spring-boot:run
```

### Stop Everything
```bash
# Stop Application
Ctrl+C

# Stop PostgreSQL
sudo systemctl stop postgresql
```

### Reset Database
```bash
psql -U postgres -d samplebank -c "DROP TABLE IF EXISTS transactions CASCADE;"
psql -U postgres -d samplebank -c "DROP TABLE IF EXISTS users CASCADE;"
psql -U postgres -d samplebank -f database/schema.sql
psql -U postgres -d samplebank -f database/transactions-schema.sql
psql -U postgres -d samplebank -f database/transfer-procedure.sql
```

You're now ready to use SampleBank v3!
