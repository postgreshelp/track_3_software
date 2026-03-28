# SampleBank Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Technology Stack](#technology-stack)
4. [Application Layers](#application-layers)
5. [Database Design](#database-design)
6. [API Specification](#api-specification)
7. [Data Flow](#data-flow)
8. [Configuration Management](#configuration-management)
9. [Error Handling Strategy](#error-handling-strategy)
10. [Security Considerations](#security-considerations)

## System Overview

SampleBank is a monolithic Spring Boot application following a layered architecture pattern. The system implements a user registration service with PostgreSQL database persistence. This module serves as the foundation for a banking application that will be extended with authentication, transactions, and account management in subsequent modules.

**Architecture Type:** Monolithic, Layered Architecture
**Deployment Model:** Standalone JAR with embedded Tomcat
**Database:** PostgreSQL relational database
**API Style:** RESTful HTTP/JSON

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Client Layer                         │
│    (curl, Postman, Browser, Mobile App, Web Frontend)      │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP/JSON
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Spring Boot Application                    │
│  ┌───────────────────────────────────────────────────────┐ │
│  │            Controller Layer (REST API)                │ │
│  │         UserController - /register endpoint           │ │
│  └────────────────────────┬──────────────────────────────┘ │
│                           │                                  │
│  ┌────────────────────────▼──────────────────────────────┐ │
│  │              Repository Layer (DAO)                   │ │
│  │    UserRepository - Spring Data JPA Interface         │ │
│  └────────────────────────┬──────────────────────────────┘ │
│                           │                                  │
│  ┌────────────────────────▼──────────────────────────────┐ │
│  │                  Entity Layer (Model)                 │ │
│  │         User Entity - JPA Annotated POJO              │ │
│  └────────────────────────┬──────────────────────────────┘ │
└───────────────────────────┼──────────────────────────────────┘
                            │ JDBC/JPA
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                       │
│                      (samplebank1)                          │
│                      users table                            │
└─────────────────────────────────────────────────────────────┘
```

## Architecture Patterns

### 1. Layered Architecture

The application follows a strict three-tier layered architecture:

**Presentation Layer (Controller)**
- Handles HTTP requests and responses
- Performs input validation
- Converts JSON to Java objects (and vice versa)
- Returns appropriate HTTP status codes

**Data Access Layer (Repository)**
- Abstracts database operations
- Provides CRUD operations through Spring Data JPA
- Manages database transactions
- Implements custom query methods

**Domain Layer (Entity)**
- Represents business domain objects
- Defines data structure and relationships
- Implements JPA persistence mappings
- Contains business logic (lifecycle callbacks)

### 2. Repository Pattern

Spring Data JPA implements the Repository pattern, providing:
- Abstract data access through interfaces
- Automatic implementation of common CRUD operations
- Custom query method generation from method names
- Transaction management

```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    boolean existsByUsername(String username);
}
```

### 3. Dependency Injection

Spring Framework's IoC (Inversion of Control) container manages dependencies:
- `@Autowired` annotation for dependency injection
- `@RestController`, `@Repository` stereotypes for component scanning
- Loose coupling between layers
- Testability through interface-based design

### 4. Convention over Configuration

Spring Boot's opinionated defaults minimize configuration:
- Embedded Tomcat server (port 8080)
- Auto-configuration based on classpath
- Sensible default settings
- Minimal XML configuration

## Technology Stack

### Core Framework
- **Spring Boot 2.7.18**: Application framework and runtime
- **Spring Web**: RESTful web services (spring-boot-starter-web)
- **Spring Data JPA**: Database abstraction layer (spring-boot-starter-data-jpa)

### Persistence
- **Hibernate**: JPA implementation (bundled with Spring Data JPA)
- **PostgreSQL JDBC Driver**: Database connectivity
- **HikariCP**: Connection pooling (default in Spring Boot)

### Build and Dependency Management
- **Maven 3.x**: Build automation and dependency management
- **Spring Boot Maven Plugin**: Packaging as executable JAR

### Java Platform
- **Java 11**: Minimum required version (LTS release)
- **JDBC API**: Database connectivity standard

## Application Layers

### 1. Entry Point Layer

**SampleBankApplication.java**
```java
@SpringBootApplication
public class SampleBankApplication {
    public static void main(String[] args) {
        SpringApplication.run(SampleBankApplication.class, args);
    }
}
```

**Responsibilities:**
- Bootstrap Spring Boot application
- Enable component scanning
- Configure auto-configuration
- Start embedded Tomcat server

**Annotations:**
- `@SpringBootApplication` = `@Configuration` + `@EnableAutoConfiguration` + `@ComponentScan`

### 2. Controller Layer (REST API)

**UserController.java**

**Responsibilities:**
- Accept HTTP POST requests at `/register`
- Parse JSON request body
- Validate input fields (username, email, password)
- Call repository methods for database operations
- Return appropriate HTTP responses

**Key Features:**
- `@RestController`: Combines `@Controller` + `@ResponseBody`
- `@PostMapping("/register")`: Maps POST requests
- `@RequestBody Map<String, String>`: Parses JSON into Map
- `ResponseEntity<String>`: Type-safe HTTP responses

**Validation Logic:**
- Empty string checks with `trim()`
- Username uniqueness check via repository
- Detailed error messages for each validation failure

### 3. Repository Layer (Data Access)

**UserRepository.java**

**Responsibilities:**
- Abstract database CRUD operations
- Provide custom query methods
- Manage database transactions
- Handle entity lifecycle

**Inherited Methods (from JpaRepository):**
- `save(User entity)`: Insert or update user
- `findById(Long id)`: Find user by primary key
- `findAll()`: Retrieve all users
- `delete(User entity)`: Remove user
- `count()`: Count total users

**Custom Methods:**
- `findByUsername(String username)`: Find user by username
- `existsByUsername(String username)`: Check username existence

**Spring Data JPA Magic:**
- Method names parsed to generate SQL
- `findByUsername` → `SELECT * FROM users WHERE username = ?`
- `existsByUsername` → `SELECT COUNT(*) > 0 FROM users WHERE username = ?`

### 4. Entity Layer (Domain Model)

**User.java**

**Responsibilities:**
- Define database table structure
- Map Java objects to database rows
- Implement business logic (default values, timestamps)
- Provide lifecycle callbacks

**JPA Annotations:**
- `@Entity`: Marks class as JPA entity
- `@Table(name = "users")`: Specifies table name
- `@Id`: Designates primary key field
- `@GeneratedValue(strategy = GenerationType.IDENTITY)`: Auto-increment
- `@Column`: Customizes column properties

**Field Mappings:**
```java
@Column(name = "username", unique = true, nullable = false, length = 50)
private String username;

@Column(name = "balance", precision = 12, scale = 2)
private BigDecimal balance = new BigDecimal("1000.00");
```

**Lifecycle Callback:**
```java
@PrePersist
protected void onCreate() {
    if (createdAt == null) {
        createdAt = LocalDateTime.now();
    }
    if (balance == null) {
        balance = new BigDecimal("1000.00");
    }
}
```

## Database Design

### Schema Overview

**Database Name:** `samplebank1`
**Table:** `users`
**Storage Engine:** PostgreSQL default (typically PostgreSQL native storage)
**Character Set:** UTF-8

### Entity-Relationship Diagram

```
┌─────────────────────────────────────┐
│              users                  │
├─────────────────────────────────────┤
│ PK  user_id         SERIAL          │
│ UQ  username        VARCHAR(50)     │
│     email           VARCHAR(100)    │
│     password_hash   VARCHAR(255)    │
│     balance         DECIMAL(12,2)   │
│     created_at      TIMESTAMP       │
└─────────────────────────────────────┘

Constraints:
- PK: Primary Key on user_id
- UQ: Unique constraint on username
- NOT NULL: username, email, password_hash
- CHECK: balance >= 0
- DEFAULT: balance = 1000.00, created_at = CURRENT_TIMESTAMP
```

### Table: users

| Column        | Data Type      | Constraints                    | Description                          |
|---------------|----------------|--------------------------------|--------------------------------------|
| user_id       | SERIAL         | PRIMARY KEY                    | Auto-incrementing unique identifier  |
| username      | VARCHAR(50)    | UNIQUE, NOT NULL               | User's login username                |
| email         | VARCHAR(100)   | NOT NULL                       | User's email address                 |
| password_hash | VARCHAR(255)   | NOT NULL                       | User's password (plain text in demo) |
| balance       | DECIMAL(12,2)  | DEFAULT 1000.00, CHECK >= 0    | User's account balance               |
| created_at    | TIMESTAMP      | DEFAULT CURRENT_TIMESTAMP      | Account creation timestamp           |

### Data Types Explained

**SERIAL:**
- PostgreSQL pseudo-type for auto-incrementing integer
- Internally creates a sequence
- Automatically generates unique IDs

**VARCHAR(n):**
- Variable-length character string
- Maximum length specified in parentheses
- Efficient storage (only uses needed space)

**DECIMAL(12,2):**
- Fixed-point numeric type
- 12 total digits, 2 after decimal point
- Precise for monetary values (no floating-point errors)
- Range: -9999999999.99 to 9999999999.99

**TIMESTAMP:**
- Date and time with microsecond precision
- Stores date/time without timezone
- Format: YYYY-MM-DD HH:MI:SS.ssssss

### Indexes

**Primary Key Index:**
- Automatically created on `user_id`
- B-tree index for fast lookups

**Unique Constraint Index:**
- Automatically created on `username`
- Ensures no duplicate usernames
- Fast lookups for username queries

### Sample Data

```sql
-- Example records after registration
user_id | username  | email              | password_hash | balance  | created_at
--------|-----------|--------------------|--------------|---------|--------------------------
1       | john_doe  | john@example.com   | secret123    | 1000.00 | 2025-01-23 10:15:30
2       | alice_w   | alice@example.com  | pass456      | 1000.00 | 2025-01-23 10:20:45
3       | bob_smith | bob@example.com    | mypass789    | 1000.00 | 2025-01-23 10:25:00
```

## API Specification

### Endpoint: POST /register

**Purpose:** Register a new user account with initial balance

**HTTP Method:** POST

**URL:** `http://localhost:8080/register`

**Request Headers:**
```
Content-Type: application/json
```

**Request Body Schema:**
```json
{
  "username": "string (required, max 50 chars)",
  "email": "string (required, max 100 chars)",
  "password": "string (required, max 255 chars)"
}
```

**Success Response:**
- **Status Code:** 200 OK
- **Content-Type:** text/plain
- **Body:** `Registered successfully! Account created with $1000.00`

**Error Responses:**

| HTTP Status | Error Message                    | Cause                              |
|-------------|----------------------------------|------------------------------------|
| 400         | ERROR: Username is required      | Missing or empty username field    |
| 400         | ERROR: Email is required         | Missing or empty email field       |
| 400         | ERROR: Password is required      | Missing or empty password field    |
| 400         | ERROR: Username already exists   | Username is already registered     |

**Example Requests:**

**Successful Registration:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"john_doe","email":"john@example.com","password":"secret123"}'

# Response: 200 OK
# Registered successfully! Account created with $1000.00
```

**Duplicate Username:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"john_doe","email":"john2@example.com","password":"pass456"}'

# Response: 400 Bad Request
# ERROR: Username already exists
```

**Missing Field:**
```bash
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"","email":"test@example.com","password":"pass789"}'

# Response: 400 Bad Request
# ERROR: Username is required
```

## Data Flow

### Registration Flow Sequence

```
1. Client Request
   ↓
2. Tomcat receives HTTP POST at /register
   ↓
3. DispatcherServlet routes to UserController.register()
   ↓
4. Controller parses JSON to Map<String, String>
   ↓
5. Controller validates input fields (username, email, password)
   ↓
6. Controller checks username uniqueness via UserRepository.existsByUsername()
   ↓
7. Repository executes SQL: SELECT COUNT(*) FROM users WHERE username = ?
   ↓
8. If username exists → Return 400 Bad Request
   ↓
9. Controller creates new User entity
   ↓
10. @PrePersist callback sets createdAt and balance
    ↓
11. Repository.save() called
    ↓
12. Hibernate generates SQL: INSERT INTO users VALUES (...)
    ↓
13. PostgreSQL executes insert and returns generated user_id
    ↓
14. Transaction commits
    ↓
15. Controller returns 200 OK response
    ↓
16. Response sent to client
```

### Component Interaction Diagram

```
┌────────┐      JSON       ┌────────────────┐
│ Client ├────────────────>│ UserController │
└────────┘                 └───────┬────────┘
                                   │
                          1. Parse & Validate
                                   │
                                   ▼
                          ┌─────────────────┐
                          │ UserRepository  │
                          └────────┬────────┘
                                   │
                          2. Check Existence
                          3. Save User
                                   │
                                   ▼
                          ┌─────────────────┐
                          │   Hibernate     │
                          │   (JPA Impl)    │
                          └────────┬────────┘
                                   │
                          4. Execute SQL
                                   │
                                   ▼
                          ┌─────────────────┐
                          │   PostgreSQL    │
                          │     Database    │
                          └─────────────────┘
```

## Configuration Management

### application.properties

**Location:** `src/main/resources/application.properties`

```properties
# Application Identity
spring.application.name=samplebank

# Database Connection
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank1
spring.datasource.username=postgres
spring.datasource.password=postgres

# JPA/Hibernate Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
```

**Configuration Breakdown:**

**spring.application.name**
- Application identifier
- Used in logging and monitoring
- Appears in Spring Boot banner

**spring.datasource.url**
- JDBC connection URL format: `jdbc:postgresql://host:port/database`
- Default PostgreSQL port: 5432
- Database name: samplebank1

**spring.jpa.hibernate.ddl-auto**
- Values: `none`, `validate`, `update`, `create`, `create-drop`
- `update`: Updates schema to match entities (safe for development)
- Production should use `validate` with manual migrations

**spring.jpa.show-sql**
- Logs generated SQL statements to console
- Useful for debugging and learning
- Should be disabled in production

### Maven Configuration (pom.xml)

**Key Dependencies:**

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
```
- Includes Spring MVC, REST support, embedded Tomcat
- Jackson for JSON processing
- Validation API

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
```
- Spring Data JPA repositories
- Hibernate ORM implementation
- Transaction management

```xml
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>
</dependency>
```
- PostgreSQL JDBC driver
- Runtime scope (not needed for compilation)

## Error Handling Strategy

### Validation Errors

**Strategy:** Fail-fast validation in controller
- Check each required field individually
- Return specific error messages
- Use HTTP 400 Bad Request for client errors

**Advantages:**
- Clear error messages for debugging
- Client knows exactly what went wrong
- Prevents unnecessary database queries

### Database Errors

**Unique Constraint Violation:**
- Checked programmatically before insert
- Uses `existsByUsername()` query
- Avoids database exception handling

**Connection Errors:**
- Handled by Spring Boot auto-configuration
- Application fails to start if database unreachable
- Connection pool manages transient errors

### Future Enhancements

Current module has minimal error handling. Future versions should add:
- Global exception handler (`@ControllerAdvice`)
- Custom exception classes
- Structured error responses (JSON format)
- Logging framework integration (SLF4J/Logback)

## Security Considerations

### Current State (Educational Demo)

**WARNING: Not production-ready!**

**Security Gaps:**
1. **No Password Hashing**: Passwords stored in plain text
2. **No Authentication**: No login mechanism
3. **No Authorization**: No access control
4. **No HTTPS**: Data transmitted in clear text
5. **No Rate Limiting**: Vulnerable to brute force
6. **No Input Sanitization**: Potential SQL injection (mitigated by JPA)
7. **No CSRF Protection**: Cross-site request forgery possible

### Production Requirements

For a production system, implement:

**Password Security:**
- BCrypt, Argon2, or PBKDF2 hashing
- Salt generation for each password
- Minimum password complexity requirements

**Authentication:**
- JWT tokens or session management
- Spring Security framework integration
- OAuth2/OpenID Connect for SSO

**Authorization:**
- Role-based access control (RBAC)
- Method-level security annotations
- Resource ownership validation

**Data Protection:**
- HTTPS/TLS for transport encryption
- Database encryption at rest
- Sensitive data masking in logs

**API Security:**
- Rate limiting (e.g., Bucket4j)
- Input validation with Bean Validation
- CORS configuration
- API key or OAuth tokens

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Status:** Educational Module - Not Production Ready
