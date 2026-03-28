# Setup Guide: SampleBank v2 Login System

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Database Configuration](#database-configuration)
4. [Application Installation](#application-installation)
5. [Database Index Creation](#database-index-creation)
6. [Running the Application](#running-the-application)
7. [Testing the Setup](#testing-the-setup)
8. [Troubleshooting](#troubleshooting)
9. [Development Tools](#development-tools)

## Prerequisites

### Required Software

| Software | Minimum Version | Recommended Version | Download Link |
|----------|----------------|---------------------|---------------|
| Java JDK | 11 | 11 or 17 | https://adoptium.net/ |
| PostgreSQL | 13 | 15+ | https://www.postgresql.org/download/ |
| Maven | 3.6 | 3.8+ | https://maven.apache.org/download.cgi |
| Git | 2.30 | Latest | https://git-scm.com/downloads |

### Optional Tools

- **curl** - Command-line API testing (comes with Git Bash on Windows)
- **Postman** - GUI-based API testing
- **pgAdmin** - PostgreSQL database management GUI
- **IntelliJ IDEA** or **VS Code** - IDE for Java development

### Verify Installations

Run these commands to verify software installations:

```bash
# Check Java version
java -version
# Expected output: openjdk version "11.0.x" or higher

# Check Maven version
mvn -version
# Expected output: Apache Maven 3.6.x or higher

# Check PostgreSQL version
psql --version
# Expected output: psql (PostgreSQL) 13.x or higher

# Check Git version
git --version
# Expected output: git version 2.30.x or higher
```

## Environment Setup

### 1. Set Environment Variables

#### Windows

```cmd
# Set JAVA_HOME
setx JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-11.0.xx-hotspot"

# Add Java to PATH
setx PATH "%PATH%;%JAVA_HOME%\bin"

# Set MAVEN_HOME
setx MAVEN_HOME "C:\Program Files\Apache\maven\apache-maven-3.8.x"

# Add Maven to PATH
setx PATH "%PATH%;%MAVEN_HOME%\bin"
```

#### Linux/Mac

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Java
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
export PATH=$JAVA_HOME/bin:$PATH

# Maven
export MAVEN_HOME=/opt/apache-maven-3.8.x
export PATH=$MAVEN_HOME/bin:$PATH
```

Apply changes:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

### 2. Create Project Directory

```bash
# Create workspace directory
mkdir -p ~/workspace/samplebank
cd ~/workspace/samplebank

# Verify you're in the correct directory
pwd
```

## Database Configuration

### 1. Start PostgreSQL Service

#### Windows

```cmd
# Start PostgreSQL service
net start postgresql-x64-15

# Or use Services GUI: services.msc
```

#### Linux (systemd)

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql  # Auto-start on boot
```

#### Mac (Homebrew)

```bash
brew services start postgresql@15
```

### 2. Verify PostgreSQL is Running

```bash
# Check PostgreSQL status
psql --version

# Test connection
psql -U postgres -c "SELECT version();"
```

### 3. Create Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Inside psql:
CREATE DATABASE samplebank1;

# Verify database creation
\l

# Connect to the new database
\c samplebank1

# Exit psql
\q
```

### 4. Create Database Schema

**Option A: Manual SQL Execution**

```bash
# Create schema.sql file
cat > schema.sql << 'EOF'
-- Drop existing table
DROP TABLE IF EXISTS users CASCADE;

-- Create users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for login performance
CREATE INDEX idx_users_username ON users(username);

-- Display table structure
\d users
EOF

# Execute schema
psql -U postgres -d samplebank1 -f schema.sql
```

**Option B: Using Module 04 Schema**

```bash
# If you have Module 04 installed
cd ../Module04-SampleBank-v1-Register
psql -U postgres -d samplebank1 -f database/schema.sql
```

### 5. Verify Schema Creation

```bash
# Connect to database
psql -U postgres -d samplebank1

# List tables
\dt

# Expected output:
#          List of relations
#  Schema |  Name  | Type  |  Owner
# --------+--------+-------+----------
#  public | users  | table | postgres

# Describe users table
\d users

# Expected output shows all columns and the index

# Verify index exists
\di

# Expected output includes idx_users_username

# Exit
\q
```

## Application Installation

### Method 1: Copy from Module 04 (Incremental Update)

If you have completed Module 04:

```bash
# Navigate to Module 04 directory
cd ~/workspace/samplebank/Module04-SampleBank-v1-Register

# Create backup
cp -r . ../Module05-SampleBank-v2-Login-backup

# Copy new AuthController
# (Assuming you have Module 05 files in a downloads folder)
cp ~/Downloads/Module05/AuthController.java \
   src/main/java/com/samplebank/controller/

# Copy login.html
cp ~/Downloads/Module05/login.html \
   src/main/resources/static/

# Update index.html
cp ~/Downloads/Module05/index.html \
   src/main/resources/static/
```

### Method 2: Clone from Repository

If starting fresh:

```bash
# Clone the project repository
git clone https://github.com/your-org/samplebank-v2-login.git
cd samplebank-v2-login
```

### Method 3: Manual File Creation

Create project structure manually:

```bash
# Create project directory
mkdir -p Module05-SampleBank-v2-Login
cd Module05-SampleBank-v2-Login

# Create directory structure
mkdir -p src/main/java/com/samplebank/controller
mkdir -p src/main/java/com/samplebank/entity
mkdir -p src/main/java/com/samplebank/repository
mkdir -p src/main/resources/static
mkdir -p database

# Copy files from Module 04 (entity, repository, main application)
# Then add AuthController.java and login.html manually
```

## Database Index Creation

### 1. Complete the Exercise File

The file `database/login-index.sql` contains a student exercise:

```bash
# View the file
cat database/login-index.sql
```

Content:
```sql
-- Student TODO: Create index for faster login lookups
-- Write: CREATE INDEX idx_users_username ON users(username);
```

### 2. Solution

Edit `database/login-index.sql`:

```sql
-- Create index for faster login lookups
CREATE INDEX idx_users_username ON users(username);

-- Verify index creation
\di idx_users_username
```

### 3. Execute the Index Creation

```bash
# Run the SQL file
psql -U postgres -d samplebank1 -f database/login-index.sql
```

### 4. Verify Index Performance

```bash
# Connect to database
psql -U postgres -d samplebank1

# Run EXPLAIN ANALYZE to see index usage
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'testuser';

# Expected output should show "Index Scan using idx_users_username"

# Exit
\q
```

## Running the Application

### 1. Configure Application Properties

Verify `src/main/resources/application.properties`:

```properties
# Application name
spring.application.name=samplebank

# Database connection
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
spring.datasource.username=postgres
spring.datasource.password=postgres

# JPA/Hibernate settings
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true

# Server port (optional)
server.port=8080
```

**Important Configuration Notes:**

- `ddl-auto=update` - Hibernate auto-creates/updates tables
- `show-sql=true` - Logs SQL queries to console
- Update `password` to match your PostgreSQL password

### 2. Build the Application

```bash
# Clean previous builds
mvn clean

# Compile and package
mvn package

# Expected output: BUILD SUCCESS
```

### 3. Run the Application

**Option A: Using Maven**

```bash
# Run with Maven
mvn spring-boot:run

# Expected output:
# Started SampleBankApplication in X.XXX seconds
```

**Option B: Using Java JAR**

```bash
# Build JAR file
mvn clean package

# Run JAR
java -jar target/samplebank-1.0.0.jar
```

**Option C: Using IDE**

- Open project in IntelliJ IDEA or Eclipse
- Locate `SampleBankApplication.java`
- Right-click → Run 'SampleBankApplication'

### 4. Verify Application Started

Look for these log messages:

```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::       (v2.7.18)

2024-01-XX XX:XX:XX.XXX  INFO --- [main] com.samplebank.SampleBankApplication
Started SampleBankApplication in 3.456 seconds
```

## Testing the Setup

### 1. Register a Test User

**Using Browser:**

1. Open http://localhost:8080/
2. Fill in registration form:
   - Username: `testuser`
   - Email: `test@example.com`
   - Password: `testpass`
3. Click "Register"
4. Verify success message

**Using curl:**

```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"testpass"}'

# Expected: Registered successfully! Account created with $1000.00
```

### 2. Test Login Functionality

**Using Browser:**

1. Navigate to http://localhost:8080/login.html
2. Enter credentials:
   - Username: `testuser`
   - Password: `testpass`
3. Click "Login"
4. Verify success message displays balance

**Using curl:**

```bash
# Test successful login
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'

# Expected: Login successful! Balance: $1000.00

# Test invalid password
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"wrongpass"}'

# Expected: ERROR: Invalid password

# Test non-existent user
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"fakeuser","password":"anypass"}'

# Expected: ERROR: User not found
```

### 3. Verify Database Records

```bash
# Connect to database
psql -U postgres -d samplebank1

# Query users table
SELECT user_id, username, email, balance, created_at FROM users;

# Expected output:
#  user_id | username | email            | balance  | created_at
# ---------+----------+------------------+----------+-------------------------
#        1 | testuser | test@example.com | 1000.00  | 2024-01-XX XX:XX:XX

# Exit
\q
```

### 4. Test All Endpoints

Create a test script `test-api.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:8080"

echo "=== Testing Registration ==="
curl -X POST $BASE_URL/register \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","email":"user1@test.com","password":"pass1"}'
echo -e "\n"

echo "=== Testing Login (Success) ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"pass1"}'
echo -e "\n"

echo "=== Testing Login (Invalid Password) ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user1","password":"wrongpass"}'
echo -e "\n"

echo "=== Testing Login (User Not Found) ==="
curl -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nonexistent","password":"anypass"}'
echo -e "\n"
```

Run the script:

```bash
chmod +x test-api.sh
./test-api.sh
```

## Troubleshooting

### Issue: Application Fails to Start

**Symptoms:**
```
Error: Could not find or load main class com.samplebank.SampleBankApplication
```

**Solutions:**

1. Verify package structure:
```bash
find src/main/java -name "*.java"
# Should show all Java files in correct packages
```

2. Clean and rebuild:
```bash
mvn clean install
```

3. Check pom.xml has correct main class:
```xml
<properties>
    <start-class>com.samplebank.SampleBankApplication</start-class>
</properties>
```

### Issue: Database Connection Refused

**Symptoms:**
```
org.postgresql.util.PSQLException: Connection refused
```

**Solutions:**

1. Verify PostgreSQL is running:
```bash
# Windows
sc query postgresql-x64-15

# Linux
sudo systemctl status postgresql

# Mac
brew services list | grep postgresql
```

2. Check connection details in `application.properties`:
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
spring.datasource.username=postgres
spring.datasource.password=YOUR_PASSWORD_HERE
```

3. Test direct connection:
```bash
psql -U postgres -d samplebank1 -h localhost -p 5432
```

### Issue: Port 8080 Already in Use

**Symptoms:**
```
Web server failed to start. Port 8080 was already in use.
```

**Solutions:**

1. Change port in `application.properties`:
```properties
server.port=8081
```

2. Or kill the process using port 8080:
```bash
# Windows
netstat -ano | findstr :8080
taskkill /PID <PID> /F

# Linux/Mac
lsof -i :8080
kill -9 <PID>
```

### Issue: Index Not Being Used

**Symptoms:**
```
EXPLAIN ANALYZE shows "Seq Scan" instead of "Index Scan"
```

**Solutions:**

1. Verify index exists:
```sql
\di idx_users_username
```

2. Recreate index:
```sql
DROP INDEX IF EXISTS idx_users_username;
CREATE INDEX idx_users_username ON users(username);
```

3. Analyze table statistics:
```sql
ANALYZE users;
```

## Development Tools

### 1. pgAdmin Setup

**Install pgAdmin:**
- Download from: https://www.pgadmin.org/download/

**Connect to Database:**
1. Open pgAdmin
2. Right-click "Servers" → Create → Server
3. General tab: Name = "SampleBank"
4. Connection tab:
   - Host: localhost
   - Port: 5432
   - Database: samplebank1
   - Username: postgres
   - Password: [your password]
5. Click "Save"

### 2. Postman Collection

Create a Postman collection for API testing:

**Collection Name:** SampleBank v2 API

**Requests:**

1. **Register User**
   - Method: POST
   - URL: http://localhost:8080/register
   - Body (JSON):
   ```json
   {
     "username": "{{username}}",
     "email": "{{email}}",
     "password": "{{password}}"
   }
   ```

2. **Login User**
   - Method: POST
   - URL: http://localhost:8080/login
   - Body (JSON):
   ```json
   {
     "username": "{{username}}",
     "password": "{{password}}"
   }
   ```

**Environment Variables:**
- username: testuser
- email: test@example.com
- password: testpass

### 3. IntelliJ IDEA Configuration

**Import Project:**
1. File → Open
2. Select project directory
3. Import as Maven project

**Configure Run Configuration:**
1. Run → Edit Configurations
2. Add New Configuration → Application
3. Main class: `com.samplebank.SampleBankApplication`
4. Use classpath of module: samplebank
5. JRE: Java 11

**Enable Hot Reload:**

Add to pom.xml:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-devtools</artifactId>
    <scope>runtime</scope>
</dependency>
```

## Next Steps

After successful setup:

1. **Complete Lab Exercises** - See `LAB-EXERCISES.md`
2. **Review Architecture** - See `ARCHITECTURE.md`
3. **Learn Database Schema** - See `DATABASE-SCHEMA.md`
4. **Prepare for Module 06** - Transaction processing functionality

## Support Resources

- **Spring Boot Docs:** https://spring.io/projects/spring-boot
- **PostgreSQL Docs:** https://www.postgresql.org/docs/
- **Maven Guide:** https://maven.apache.org/guides/

---

**Setup Guide Version:** 1.0
**Last Updated:** January 2024
**Module:** 05 - SampleBank v2 Login System
