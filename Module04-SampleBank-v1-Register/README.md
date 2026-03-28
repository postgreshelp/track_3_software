# SampleBank - Module 04: User Registration System

## Overview

SampleBank is a simplified banking application built with Java Spring Boot and PostgreSQL. This module (v1-Register) focuses exclusively on **user registration functionality**, providing students with hands-on experience in building RESTful APIs, database integration, and modern backend development practices.

**Project Status:** Module 04 - Week 1 (Registration Only)

**Technology Stack:**
- Java 11
- Spring Boot 2.7.18
- Spring Data JPA
- PostgreSQL
- Maven

## What You'll Learn

This module teaches fundamental concepts in enterprise Java development:

- **Spring Boot Fundamentals**: Application structure, configuration, and dependency injection
- **RESTful API Development**: Building HTTP endpoints with proper request/response handling
- **Database Integration**: Using Spring Data JPA with PostgreSQL
- **Entity Management**: JPA entities, repositories, and persistence
- **Data Validation**: Input validation and error handling
- **Maven Build System**: Dependency management and project building

## Key Features

### User Registration
- RESTful API endpoint for new user registration
- Username uniqueness validation
- Email and password requirement checks
- Automatic balance initialization ($1000.00 starting balance)
- Timestamp tracking for account creation

### Database Integration
- PostgreSQL database with JPA/Hibernate ORM
- Automatic schema generation from entity classes
- SQL schema files for manual database setup
- Transaction management for data consistency

### Input Validation
- Required field validation (username, email, password)
- Duplicate username detection
- Proper error messages for invalid requests
- HTTP status code handling (200 OK, 400 Bad Request)

## Project Structure

```
Module04-SampleBank-v1-Register/
├── src/
│   └── main/
│       ├── java/com/samplebank/
│       │   ├── SampleBankApplication.java    # Main application entry point
│       │   ├── entity/
│       │   │   └── User.java                 # User entity (JPA model)
│       │   ├── repository/
│       │   │   └── UserRepository.java       # Data access layer
│       │   └── controller/
│       │       └── UserController.java       # REST API endpoints
│       └── resources/
│           └── application.properties        # Database configuration
├── database/
│   └── schema.sql                            # Database schema definition
├── pom.xml                                   # Maven dependencies
├── build.bat                                 # Build script (Windows)
├── run.bat                                   # Run script (Windows)
└── setup-db.bat                              # Database setup script
```

## Quick Start

### Prerequisites
- Java 11 or higher
- PostgreSQL 12+ installed and running
- Maven 3.6+ (or use Maven Wrapper)
- Command line access

### Installation Steps

1. **Clone or extract the project**
   ```bash
   cd Module04-SampleBank-v1-Register
   ```

2. **Configure database connection**
   Edit `src/main/resources/application.properties`:
   ```properties
   spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
   spring.datasource.username=postgres
   spring.datasource.password=YOUR_PASSWORD
   ```

3. **Create database and schema**
   ```bash
   # Windows
   setup-db.bat

   # Linux/Mac
   psql -U postgres -c "CREATE DATABASE samplebank1;"
   psql -U postgres -d samplebank1 -f database/schema.sql
   ```

4. **Build the application**
   ```bash
   # Windows
   build.bat

   # Linux/Mac
   mvn clean package
   ```

5. **Run the application**
   ```bash
   # Windows
   run.bat

   # Linux/Mac
   java -jar target/samplebank-1.0.0.jar
   ```

6. **Test the API**
   ```bash
   curl -X POST http://localhost:8080/register \
     -H "Content-Type: application/json" \
     -d '{"username":"john_doe","email":"john@example.com","password":"secret123"}'
   ```

## API Endpoints

### POST /register
Registers a new user account.

**Request Body:**
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "secret123"
}
```

**Success Response (200 OK):**
```
Registered successfully! Account created with $1000.00
```

**Error Responses (400 Bad Request):**
- `ERROR: Username is required`
- `ERROR: Email is required`
- `ERROR: Password is required`
- `ERROR: Username already exists`

## Database Schema

The application uses a single `users` table:

| Column        | Type          | Constraints                    |
|---------------|---------------|--------------------------------|
| user_id       | SERIAL        | PRIMARY KEY                    |
| username      | VARCHAR(50)   | UNIQUE, NOT NULL               |
| email         | VARCHAR(100)  | NOT NULL                       |
| password_hash | VARCHAR(255)  | NOT NULL                       |
| balance       | DECIMAL(12,2) | DEFAULT 1000.00, CHECK >= 0    |
| created_at    | TIMESTAMP     | DEFAULT CURRENT_TIMESTAMP      |

**Note:** This demo stores passwords in plain text. Production systems should use proper password hashing (BCrypt, Argon2, etc.).

## Configuration Files

### application.properties
Contains Spring Boot and database configuration:
- Database connection URL, username, password
- JPA/Hibernate settings (DDL auto-generation, SQL logging)
- Application name

### pom.xml
Maven project configuration with dependencies:
- Spring Boot Starter Web (REST API)
- Spring Boot Starter Data JPA (Database access)
- PostgreSQL JDBC Driver

## Development Workflow

1. **Make code changes** in `src/main/java/`
2. **Rebuild** using `build.bat` or `mvn clean package`
3. **Restart** the application with `run.bat`
4. **Test** endpoints using curl, Postman, or browser tools
5. **Check logs** in console for SQL queries and errors

## Testing the Application

### Using curl (Command Line)
```bash
# Successful registration
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com","password":"pass123"}'

# Duplicate username error
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice2@example.com","password":"pass456"}'

# Missing field error
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"","email":"bob@example.com","password":"pass789"}'
```

### Using Postman
1. Create new POST request to `http://localhost:8080/register`
2. Set Headers: `Content-Type: application/json`
3. Set Body (raw JSON):
   ```json
   {
     "username": "testuser",
     "email": "test@example.com",
     "password": "testpass"
   }
   ```
4. Send request and verify response

## Verifying Data in PostgreSQL

```sql
-- Connect to database
psql -U postgres -d samplebank1

-- View all registered users
SELECT * FROM users;

-- Check user count
SELECT COUNT(*) FROM users;

-- Find specific user
SELECT * FROM users WHERE username = 'john_doe';
```

## Next Steps

After completing this module, you will extend the application with:
- **Module 05**: User login/authentication
- **Module 06**: Account balance viewing
- **Module 07**: Money transfer between users
- **Module 08**: Transaction history and auditing

## Learning Resources

- **Spring Boot Documentation**: https://spring.io/projects/spring-boot
- **Spring Data JPA Guide**: https://spring.io/guides/gs/accessing-data-jpa/
- **PostgreSQL Tutorial**: https://www.postgresql.org/docs/
- **RESTful API Best Practices**: https://restfulapi.net/

## Common Issues

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions to common problems:
- Database connection errors
- Port conflicts (8080 already in use)
- Maven build failures
- JPA/Hibernate configuration issues

## Support and Documentation

- **Architecture Details**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Setup Instructions**: See [SETUP-GUIDE.md](SETUP-GUIDE.md)
- **Database Schema**: See [DATABASE-SCHEMA.md](DATABASE-SCHEMA.md)
- **Lab Exercises**: See [LAB-EXERCISES.md](LAB-EXERCISES.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## License

This is an educational project for learning purposes.

## Authors

SampleBank Development Team - Educational Module Series

---

**Version:** 1.0.0
**Last Updated:** January 2025
**Module:** 04 - User Registration System
