# SampleBank Setup Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Database Installation](#database-installation)
4. [Project Configuration](#project-configuration)
5. [Building the Application](#building-the-application)
6. [Running the Application](#running-the-application)
7. [Verification and Testing](#verification-and-testing)
8. [IDE Setup (Optional)](#ide-setup-optional)
9. [Deployment Options](#deployment-options)

## Prerequisites

### Required Software

| Software    | Minimum Version | Recommended | Purpose                          |
|-------------|-----------------|-------------|----------------------------------|
| Java JDK    | 11              | 11 or 17    | Application runtime              |
| PostgreSQL  | 12              | 14+         | Database server                  |
| Maven       | 3.6             | 3.8+        | Build tool (or use wrapper)      |
| Git         | 2.x             | Latest      | Version control (optional)       |

### Operating System Support

- **Windows**: 10/11 (scripts provided: `.bat` files)
- **Linux**: Ubuntu 20.04+, Debian, RHEL, CentOS
- **macOS**: 11+ (Big Sur or later)

### Hardware Requirements

**Minimum:**
- CPU: Dual-core processor
- RAM: 4GB
- Disk: 500MB free space

**Recommended:**
- CPU: Quad-core processor
- RAM: 8GB or more
- Disk: 2GB free space (for dependencies and build artifacts)

### Network Requirements

- Internet connection for downloading Maven dependencies (first build only)
- Port 8080 available for Spring Boot application
- Port 5432 available for PostgreSQL (default)

## Environment Setup

### Step 1: Install Java JDK

#### Windows

**Option A: Download from Oracle**
1. Visit https://www.oracle.com/java/technologies/downloads/#java11
2. Download Windows x64 installer
3. Run installer and follow prompts
4. Add to PATH if not automatic:
   - System Properties → Environment Variables
   - Add `JAVA_HOME`: `C:\Program Files\Java\jdk-11`
   - Add to `PATH`: `%JAVA_HOME%\bin`

**Option B: Using Chocolatey**
```powershell
choco install openjdk11
```

**Verify Installation:**
```cmd
java -version
# Expected: java version "11.x.x"

javac -version
# Expected: javac 11.x.x
```

#### Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt update

# Install OpenJDK 11
sudo apt install openjdk-11-jdk -y

# Verify installation
java -version
javac -version

# Set JAVA_HOME (add to ~/.bashrc or ~/.profile)
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

#### macOS

**Using Homebrew:**
```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install OpenJDK 11
brew install openjdk@11

# Link Java
sudo ln -sfn $(brew --prefix)/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk

# Verify
java -version
```

### Step 2: Install Maven

#### Windows

**Download and Install:**
1. Visit https://maven.apache.org/download.cgi
2. Download Binary zip archive (apache-maven-3.x.x-bin.zip)
3. Extract to `C:\Program Files\Apache\Maven`
4. Add to PATH:
   - Environment Variables → System Variables → PATH
   - Add: `C:\Program Files\Apache\Maven\bin`

**Verify:**
```cmd
mvn -version
# Expected: Apache Maven 3.x.x
```

#### Linux

```bash
# Ubuntu/Debian
sudo apt install maven -y

# Verify
mvn -version
```

#### macOS

```bash
brew install maven
mvn -version
```

**Alternative: Use Maven Wrapper (No Installation Required)**
The project can use Maven Wrapper (if included):
```bash
# Linux/Mac
./mvnw clean package

# Windows
mvnw.cmd clean package
```

## Database Installation

### PostgreSQL Installation

#### Windows

1. **Download Installer**
   - Visit https://www.postgresql.org/download/windows/
   - Download latest version installer

2. **Run Installer**
   - Choose installation directory
   - Select components: PostgreSQL Server, pgAdmin, Command Line Tools
   - Set port: 5432 (default)
   - Set superuser password (remember this!)
   - Set locale: Default

3. **Verify Installation**
   ```cmd
   psql --version
   # Expected: psql (PostgreSQL) 14.x or higher
   ```

4. **Add to PATH** (if not automatic)
   - Add `C:\Program Files\PostgreSQL\14\bin` to PATH

#### Linux (Ubuntu/Debian)

```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib -y

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify
sudo systemctl status postgresql
psql --version
```

#### macOS

```bash
# Install PostgreSQL
brew install postgresql@14

# Start service
brew services start postgresql@14

# Verify
psql --version
```

### PostgreSQL Configuration

#### Set PostgreSQL Password

**Windows/Linux/Mac:**
```bash
# Switch to postgres user (Linux)
sudo -u postgres psql

# Or connect directly (Windows/Mac)
psql -U postgres

# Set password
ALTER USER postgres PASSWORD 'postgres';

# Exit
\q
```

#### Enable Network Access (Optional)

Edit `postgresql.conf`:
```bash
# Linux: /etc/postgresql/14/main/postgresql.conf
# Windows: C:\Program Files\PostgreSQL\14\data\postgresql.conf

# Change:
listen_addresses = 'localhost'  # or '*' for all interfaces
```

Edit `pg_hba.conf` to allow password authentication:
```bash
# Add/modify line:
host    all             all             127.0.0.1/32            md5
```

Restart PostgreSQL:
```bash
# Linux
sudo systemctl restart postgresql

# Windows (as Administrator)
net stop postgresql-x64-14
net start postgresql-x64-14

# macOS
brew services restart postgresql@14
```

## Project Configuration

### Step 1: Extract/Clone Project

**Option A: From ZIP Archive**
```bash
# Extract to desired location
cd C:\Users\YourName\Projects
unzip Module04-SampleBank-v1-Register.zip
cd Module04-SampleBank-v1-Register
```

**Option B: From Git Repository** (if applicable)
```bash
git clone <repository-url>
cd Module04-SampleBank-v1-Register
```

### Step 2: Configure Database Connection

Edit `src/main/resources/application.properties`:

```properties
spring.application.name=samplebank

# Update these values to match your PostgreSQL setup
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
spring.datasource.username=postgres
spring.datasource.password=YOUR_PASSWORD_HERE

# JPA Configuration (usually no changes needed)
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
```

**Configuration Notes:**
- Replace `YOUR_PASSWORD_HERE` with your PostgreSQL password
- If PostgreSQL is on a different host, change `localhost` to the hostname/IP
- If using a different port, change `5432` to your port number

### Step 3: Create Database

**Windows:**
```cmd
setup-db.bat
```

**Linux/macOS:**
```bash
# Create database
psql -U postgres -c "DROP DATABASE IF EXISTS samplebank1;"
psql -U postgres -c "CREATE DATABASE samplebank1;"

# Run schema
psql -U postgres -d samplebank1 -f database/schema.sql

# Verify
psql -U postgres -d samplebank1 -c "\dt"
```

**Manual SQL Approach:**
```sql
-- Connect to PostgreSQL
psql -U postgres

-- Create database
DROP DATABASE IF EXISTS samplebank1;
CREATE DATABASE samplebank1;

-- Connect to new database
\c samplebank1

-- Run schema manually or via file
\i database/schema.sql

-- Verify table creation
\dt

-- View table structure
\d users

-- Exit
\q
```

## Building the Application

### Using Build Script (Windows)

```cmd
build.bat
```

This script runs:
- `mvn clean package -DskipTests`
- Cleans previous builds
- Compiles source code
- Packages as JAR file
- Skips tests for faster builds

### Using Maven Directly

**Windows:**
```cmd
mvn clean package
```

**Linux/macOS:**
```bash
mvn clean package
```

**Build Output:**
```
[INFO] BUILD SUCCESS
[INFO] Total time: 15.234 s
[INFO] Finished at: 2025-01-23T10:30:00+00:00
[INFO] Final Memory: 45M/180M
```

**Generated Artifacts:**
- JAR file: `target/samplebank-1.0.0.jar`
- Compiled classes: `target/classes/`
- Test classes: `target/test-classes/` (if tests exist)

### Build Options

**Clean build (remove old artifacts):**
```bash
mvn clean package
```

**Build without tests:**
```bash
mvn clean package -DskipTests
```

**Build with verbose output:**
```bash
mvn clean package -X
```

**Build offline (use cached dependencies):**
```bash
mvn clean package -o
```

## Running the Application

### Using Run Script (Windows)

```cmd
run.bat
```

### Using Java Directly

**Windows/Linux/macOS:**
```bash
java -jar target/samplebank-1.0.0.jar
```

### Using Maven Spring Boot Plugin

```bash
mvn spring-boot:run
```

### Expected Console Output

```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::       (v2.7.18)

2025-01-23 10:35:00.123  INFO 12345 --- [main] c.s.SampleBankApplication : Starting SampleBankApplication
2025-01-23 10:35:01.456  INFO 12345 --- [main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2025-01-23 10:35:02.789  INFO 12345 --- [main] c.s.SampleBankApplication : Started SampleBankApplication in 3.456 seconds
```

**Key Indicators Application Started Successfully:**
- `Started SampleBankApplication in X seconds`
- `Tomcat started on port(s): 8080`
- No error messages or stack traces

### Application Lifecycle

**To Stop the Application:**
- Press `Ctrl+C` in the terminal
- Application will shutdown gracefully

**To Restart:**
- Stop application (Ctrl+C)
- Run again: `run.bat` or `java -jar target/samplebank-1.0.0.jar`

## Verification and Testing

### Step 1: Check Application Health

**Open browser:**
```
http://localhost:8080
```

**Expected Response:**
```json
{"timestamp":"2025-01-23T10:40:00.000+00:00","status":404,"error":"Not Found","path":"/"}
```

This is normal! The application has no root endpoint. The 404 confirms the server is running.

### Step 2: Test Registration Endpoint

**Using curl (Command Line):**

```bash
# Test successful registration
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testuser\",\"email\":\"test@example.com\",\"password\":\"testpass\"}"

# Expected: Registered successfully! Account created with $1000.00
```

**Using PowerShell (Windows):**
```powershell
Invoke-WebRequest -Uri http://localhost:8080/register `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{"username":"testuser","email":"test@example.com","password":"testpass"}'
```

**Using Postman:**
1. Create new POST request
2. URL: `http://localhost:8080/register`
3. Headers: `Content-Type: application/json`
4. Body (raw JSON):
   ```json
   {
     "username": "alice",
     "email": "alice@example.com",
     "password": "secret123"
   }
   ```
5. Send request
6. Verify response: `Registered successfully! Account created with $1000.00`

### Step 3: Verify Database Records

```bash
# Connect to database
psql -U postgres -d samplebank1

# Query users table
SELECT * FROM users;

# Expected output:
# user_id | username | email              | password_hash | balance  | created_at
# --------|----------|--------------------|--------------|---------|--------------------------
# 1       | testuser | test@example.com   | testpass     | 1000.00 | 2025-01-23 10:45:00
```

### Step 4: Test Error Cases

**Test duplicate username:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"testuser\",\"email\":\"test2@example.com\",\"password\":\"pass\"}"

# Expected: ERROR: Username already exists
```

**Test missing field:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"\",\"email\":\"test@example.com\",\"password\":\"pass\"}"

# Expected: ERROR: Username is required
```

## IDE Setup (Optional)

### IntelliJ IDEA

1. **Import Project**
   - File → Open → Select project folder
   - Choose "Import as Maven project"
   - Wait for dependency download

2. **Configure JDK**
   - File → Project Structure → Project
   - Set SDK to Java 11

3. **Run Application**
   - Open `SampleBankApplication.java`
   - Right-click → Run 'SampleBankApplication'

### Eclipse

1. **Import Project**
   - File → Import → Existing Maven Projects
   - Select project root directory
   - Finish

2. **Run Application**
   - Right-click project → Run As → Spring Boot App

### Visual Studio Code

1. **Install Extensions**
   - Java Extension Pack
   - Spring Boot Extension Pack

2. **Open Project**
   - File → Open Folder → Select project

3. **Run Application**
   - Press F5 or use Run/Debug button

## Deployment Options

### Development Mode

**Embedded Tomcat (Current Setup):**
- Run JAR directly: `java -jar target/samplebank-1.0.0.jar`
- Quick start, easy debugging
- Suitable for development and testing

### Production-Like Deployment

**As a Service (Linux - systemd):**

Create `/etc/systemd/system/samplebank.service`:
```ini
[Unit]
Description=SampleBank Application
After=postgresql.service

[Service]
Type=simple
User=samplebank
ExecStart=/usr/bin/java -jar /opt/samplebank/samplebank-1.0.0.jar
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable samplebank
sudo systemctl start samplebank
sudo systemctl status samplebank
```

**As Windows Service:**
Use tools like NSSM (Non-Sucking Service Manager):
```cmd
nssm install SampleBank "C:\Program Files\Java\jdk-11\bin\java.exe" "-jar C:\Apps\samplebank\samplebank-1.0.0.jar"
nssm start SampleBank
```

### Environment-Specific Configuration

**Using Profiles:**

Create `application-prod.properties`:
```properties
spring.datasource.url=jdbc:postgresql://prod-db-server:5432/samplebank_prod
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=false
```

Run with profile:
```bash
java -jar target/samplebank-1.0.0.jar --spring.profiles.active=prod
```

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Next Steps:** See [LAB-EXERCISES.md](LAB-EXERCISES.md) for hands-on practice
