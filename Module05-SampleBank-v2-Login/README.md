# Module 05: SampleBank v2 - Login Functionality

## Overview

**Module 05** extends the SampleBank application by implementing login functionality. Building upon the user registration system from Module 04, this module introduces authentication endpoints, login forms, and database optimizations for secure user authentication.

This module demonstrates fundamental authentication concepts in Spring Boot applications, including password validation, user lookup optimization, and session management basics. While this implementation uses plain-text password comparison for educational purposes, it serves as a foundation for understanding authentication flows before implementing production-grade security features like JWT tokens and password hashing.

## Learning Objectives

By completing this module, you will:

1. **Implement Authentication Endpoints** - Create REST API endpoints for user login
2. **Build Login User Interfaces** - Develop HTML/JavaScript forms for authentication
3. **Optimize Database Queries** - Create indexes for faster username lookups
4. **Understand Authentication Flow** - Learn how login requests are processed and validated
5. **Handle Authentication Errors** - Implement proper error handling and user feedback
6. **Test Authentication Systems** - Use curl, Postman, and browser testing for validation

## What's New in Version 2

### New Features

- **Login Endpoint** (`POST /login`) - Authenticates users with username and password
- **Login Web Interface** - Modern, responsive login form with error handling
- **Database Indexing** - Performance optimization for username lookups
- **Enhanced Error Messages** - Detailed feedback for authentication failures
- **Navigation Links** - Seamless flow between registration and login pages

### Updated Components

- `index.html` - Added link to login page
- `AuthController.java` - New controller for authentication logic
- `login.html` - Complete login interface with JavaScript validation
- `login-index.sql` - Database index creation for performance

## Project Structure

```
Module05-SampleBank-v2-Login/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── samplebank/
│   │   │           ├── controller/
│   │   │           │   └── AuthController.java      # Login endpoint
│   │   │           ├── entity/
│   │   │           │   └── User.java                # (from Module 04)
│   │   │           ├── repository/
│   │   │           │   └── UserRepository.java      # (from Module 04)
│   │   │           └── SampleBankApplication.java   # (from Module 04)
│   │   └── resources/
│   │       ├── static/
│   │       │   ├── index.html                       # Registration page (updated)
│   │       │   └── login.html                       # NEW: Login page
│   │       └── application.properties               # (from Module 04)
├── database/
│   └── login-index.sql                              # Database index creation
├── pom.xml                                          # (from Module 04)
└── README.md
```

## Prerequisites

Before starting this module, ensure you have completed:

1. **Module 04: SampleBank v1 - Register** - User registration functionality
2. **PostgreSQL Installation** - PostgreSQL 13+ installed and running
3. **Java Development Kit** - JDK 11 or higher
4. **Maven** - Apache Maven 3.6+
5. **Database Setup** - `samplebank1` database created and populated

### Verify Prerequisites

```bash
# Check PostgreSQL is running
psql --version

# Check Java version
java -version

# Check Maven version
mvn -version

# Verify database exists
psql -U postgres -d samplebank1 -c "\dt"
```

## Quick Start

### 1. Add New Files

Copy the following files to your Module 04 project:

```bash
# Copy AuthController.java
cp src/main/java/com/samplebank/controller/AuthController.java \
   ../Module04-SampleBank-v1-Register/src/main/java/com/samplebank/controller/

# Copy login.html
cp src/main/resources/static/login.html \
   ../Module04-SampleBank-v1-Register/src/main/resources/static/

# Update index.html (overwrite)
cp src/main/resources/static/index.html \
   ../Module04-SampleBank-v1-Register/src/main/resources/static/
```

### 2. Create Database Index

Run the SQL script to optimize login performance:

```bash
# Complete the login-index.sql file first (student exercise)
# Then execute:
psql -U postgres -d samplebank1 -f database/login-index.sql
```

### 3. Start the Application

```bash
# Navigate to project directory
cd ../Module04-SampleBank-v1-Register

# Run Spring Boot application
mvn spring-boot:run
```

### 4. Test Login Functionality

**Option A: Browser Testing**

1. Open http://localhost:8080/login.html
2. Enter credentials from a registered user
3. Click "Login"
4. Verify success message with balance display

**Option B: curl Testing**

```bash
# Test successful login
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'

# Expected: Login successful! Balance: $1000.00

# Test with invalid password
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"wrongpass"}'

# Expected: ERROR: Invalid password
```

## API Endpoints

### POST /register (from Module 04)

Registers a new user account.

**Request:**
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "securepass123"
}
```

**Response (Success):**
```
Registered successfully! Account created with $1000.00
```

### POST /login (NEW)

Authenticates an existing user.

**Request:**
```json
{
  "username": "johndoe",
  "password": "securepass123"
}
```

**Response (Success):**
```
Login successful! Balance: $1000.00
```

**Response (Failure - User Not Found):**
```
ERROR: User not found
```

**Response (Failure - Invalid Password):**
```
ERROR: Invalid password
```

## Key Features

### 1. Authentication Logic

The `AuthController` implements the following validation flow:

1. **Input Validation** - Ensures username and password are provided
2. **User Lookup** - Queries database for username (optimized with index)
3. **Password Verification** - Compares provided password with stored hash
4. **Balance Retrieval** - Returns user's current balance on success

### 2. Database Optimization

The `login-index.sql` script creates an index on the username column:

```sql
CREATE INDEX idx_users_username ON users(username);
```

This index provides:
- **Faster Lookups** - O(log n) instead of O(n) for username searches
- **Reduced Query Time** - Significant improvement with large user bases
- **Better Scalability** - Supports high login request volumes

### 3. User Interface

The login form includes:
- **Responsive Design** - Works on desktop and mobile devices
- **Real-time Validation** - JavaScript form validation before submission
- **Error Handling** - Clear error messages for authentication failures
- **Success Feedback** - Displays user balance upon successful login
- **Navigation** - Link to registration page for new users

## Security Considerations (Educational)

**IMPORTANT SECURITY NOTICE:**

This module uses **plain-text password comparison** for educational purposes. This implementation demonstrates authentication flow but is **NOT SECURE** for production use.

### Current Implementation Issues:

1. **Plain-text Password Storage** - Passwords stored without hashing
2. **No Session Management** - No persistent login sessions
3. **Missing HTTPS** - Credentials transmitted over unencrypted HTTP
4. **No Rate Limiting** - Vulnerable to brute-force attacks
5. **Detailed Error Messages** - Reveals whether usernames exist

### Future Improvements:

- **Module 13: Security & Access Control** - Implements bcrypt password hashing
- **Module 16: Production Deployment** - Adds JWT authentication tokens
- **Module 30: Compliance & Auditing** - Implements comprehensive security controls

## Testing

### Test Scenarios

| Test Case | Username | Password | Expected Result |
|-----------|----------|----------|-----------------|
| Valid Login | testuser | testpass | Success with balance |
| Invalid Password | testuser | wrongpass | ERROR: Invalid password |
| Non-existent User | fakeuser | anypass | ERROR: User not found |
| Empty Username | (empty) | testpass | ERROR: Username is required |
| Empty Password | testuser | (empty) | ERROR: Password is required |

### Manual Testing Steps

1. **Register a Test User**
   - Navigate to http://localhost:8080/
   - Register with username: `testuser`, password: `testpass`

2. **Test Valid Login**
   - Navigate to http://localhost:8080/login.html
   - Enter `testuser` / `testpass`
   - Verify success message displays balance

3. **Test Invalid Password**
   - Enter `testuser` / `wrongpassword`
   - Verify error message: "ERROR: Invalid password"

4. **Test Non-existent User**
   - Enter `nonexistent` / `anypassword`
   - Verify error message: "ERROR: User not found"

## Common Issues

### Issue: Login Always Fails

**Symptoms:** Every login attempt returns "Invalid password"

**Causes:**
- Password stored with different casing
- Extra whitespace in stored password
- User created in Module 04 with different password

**Solution:**
```sql
-- Check stored password
SELECT username, password_hash FROM users WHERE username = 'testuser';

-- Update password if needed
UPDATE users SET password_hash = 'testpass' WHERE username = 'testuser';
```

### Issue: Slow Login Performance

**Symptoms:** Login takes several seconds with many users

**Cause:** Missing database index on username column

**Solution:**
```bash
# Verify index exists
psql -U postgres -d samplebank1 -c "\d users"

# Create index if missing
psql -U postgres -d samplebank1 -f database/login-index.sql
```

### Issue: CORS Errors in Browser

**Symptoms:** "Access-Control-Allow-Origin" errors in browser console

**Cause:** Browser same-origin policy restrictions

**Solution:** Ensure you access the application at http://localhost:8080 (not file://)

## Next Steps

After completing Module 05, you can proceed to:

1. **Module 06: SampleBank v3 - Transactions** - Implement deposit, withdrawal, and transfer operations
2. **Module 13: Security & Access Control** - Add password hashing and JWT authentication
3. **Module 16: Production Deployment** - Deploy with proper security controls

## Student Exercises

### Exercise 1: Complete Database Index

**File:** `database/login-index.sql`

**Task:** Write the CREATE INDEX statement to optimize username lookups

**Hint:** Index the `username` column of the `users` table

### Exercise 2: Test Performance

**Task:** Compare login performance with and without the index

**Steps:**
1. Insert 10,000 test users
2. Measure login query time without index
3. Create index
4. Measure login query time with index
5. Document performance improvement

### Exercise 3: Enhance Error Messages

**Task:** Modify `AuthController.java` to use generic error messages

**Goal:** Prevent username enumeration attacks

**Change:** Return "Invalid username or password" for both cases

## Learning Resources

### Spring Boot Authentication
- [Spring Boot Documentation - REST APIs](https://spring.io/guides/tutorials/rest/)
- [Building REST Services with Spring](https://spring.io/guides/gs/rest-service/)

### Database Indexing
- [PostgreSQL Index Types](https://www.postgresql.org/docs/current/indexes-types.html)
- [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)

### Web Security Basics
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Authentication Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Backend Framework | Spring Boot | 2.7.18 |
| Language | Java | 11+ |
| Database | PostgreSQL | 13+ |
| ORM | Hibernate/JPA | 5.6+ |
| Build Tool | Maven | 3.6+ |
| Frontend | HTML/CSS/JavaScript | ES6 |

## Support

### Getting Help

- Review the `TROUBLESHOOTING.md` for common issues
- Check the `SETUP-GUIDE.md` for detailed installation steps
- Refer to `ARCHITECTURE.md` for system design details
- Complete `LAB-EXERCISES.md` for hands-on practice

### Reporting Issues

If you encounter problems:

1. Check application logs: `mvn spring-boot:run` output
2. Verify database connectivity: `psql -U postgres -d samplebank1`
3. Review browser console for JavaScript errors
4. Test API endpoints with curl for debugging

## License

This educational project is part of the PostgreSQL Production DBA course material.

## Acknowledgments

This module builds upon concepts from:
- Module 03: Spring Boot & PostgreSQL Integration
- Module 04: SampleBank v1 - User Registration

---

**Next Module:** Module 06 - SampleBank v3: Transactions (Deposit/Withdrawal/Transfer)

**Previous Module:** Module 04 - SampleBank v1: User Registration
