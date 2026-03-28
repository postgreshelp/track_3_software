# Architecture Documentation: SampleBank v2 Login System

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Component Design](#component-design)
4. [Authentication Flow](#authentication-flow)
5. [Data Layer Architecture](#data-layer-architecture)
6. [API Design](#api-design)
7. [Session Management](#session-management)
8. [Security Architecture](#security-architecture)
9. [Performance Optimization](#performance-optimization)
10. [Scalability Considerations](#scalability-considerations)

## System Overview

### High-Level Architecture

SampleBank v2 implements a three-tier web application architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  index.html  │  │  login.html  │  │   Static     │      │
│  │ (Register)   │  │   (Login)    │  │    CSS/JS    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                    HTTP/JSON Requests
                            │
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  ┌──────────────────────┐  ┌─────────────────────────┐     │
│  │   UserController     │  │    AuthController       │     │
│  │   (Registration)     │  │      (Login)            │     │
│  └──────────────────────┘  └─────────────────────────┘     │
│                            │                                 │
│  ┌──────────────────────────────────────────────────┐      │
│  │          UserRepository (JPA)                     │      │
│  │    findByUsername(), existsByUsername()          │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                      JDBC Connection
                            │
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                            │
│  ┌──────────────────────────────────────────────────┐      │
│  │              PostgreSQL Database                  │      │
│  │                                                    │      │
│  │  ┌──────────────────────────────────────┐        │      │
│  │  │         users table                  │        │      │
│  │  │  - user_id (PK)                      │        │      │
│  │  │  - username (UNIQUE, INDEXED)        │        │      │
│  │  │  - email                             │        │      │
│  │  │  - password_hash                     │        │      │
│  │  │  - balance                           │        │      │
│  │  │  - created_at                        │        │      │
│  │  └──────────────────────────────────────┘        │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Component | Technology | Purpose |
|-------|-----------|-----------|---------|
| Presentation | Frontend | HTML5/CSS3/JavaScript | User interface |
| Application | Framework | Spring Boot 2.7.18 | REST API server |
| Application | Language | Java 11 | Business logic |
| Persistence | ORM | Hibernate/JPA | Object-relational mapping |
| Persistence | Database Driver | PostgreSQL JDBC | Database connectivity |
| Data | RDBMS | PostgreSQL 13+ | Data persistence |

## Architecture Patterns

### 1. MVC (Model-View-Controller) Pattern

**Implementation:**

- **Model:** `User.java` - JPA entity representing user data
- **View:** `login.html`, `index.html` - HTML templates with JavaScript
- **Controller:** `AuthController.java`, `UserController.java` - REST endpoints

**Benefits:**
- Separation of concerns
- Independent development of components
- Easier testing and maintenance
- Clear responsibility boundaries

### 2. Repository Pattern

**Implementation:**

```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    boolean existsByUsername(String username);
}
```

**Benefits:**
- Abstraction over data access logic
- Simplified database operations
- Easy to mock for unit testing
- Centralized query management

**Query Generation:**

Spring Data JPA automatically generates queries from method names:

```java
// Method name: findByUsername
// Generated SQL: SELECT * FROM users WHERE username = ?

// Method name: existsByUsername
// Generated SQL: SELECT CASE WHEN COUNT(*) > 0 THEN true ELSE false END
//                FROM users WHERE username = ?
```

### 3. Dependency Injection

**Implementation:**

```java
@RestController
public class AuthController {
    @Autowired
    private UserRepository userRepository;  // DI via @Autowired
}
```

**Benefits:**
- Loose coupling between components
- Easy to swap implementations
- Supports unit testing with mocks
- Centralized dependency management

### 4. RESTful API Design

**Implementation:**

- **POST /register** - Creates a new resource (user)
- **POST /login** - Validates credentials (non-standard REST, discussed below)

**REST Principles:**
- Stateless communication
- JSON request/response format
- HTTP status codes for results
- Resource-oriented URLs

## Component Design

### 1. AuthController

**Responsibility:** Handle authentication requests

**Class Diagram:**

```
┌─────────────────────────────────────────┐
│         AuthController                  │
├─────────────────────────────────────────┤
│ - userRepository: UserRepository        │
├─────────────────────────────────────────┤
│ + login(request: Map): ResponseEntity   │
└─────────────────────────────────────────┘
           │
           │ @Autowired
           ▼
┌─────────────────────────────────────────┐
│         UserRepository                  │
├─────────────────────────────────────────┤
│ + findByUsername(String): Optional<User>│
│ + existsByUsername(String): boolean     │
└─────────────────────────────────────────┘
```

**Method Flow:**

```java
public ResponseEntity<String> login(Map<String, String> request) {
    // 1. Input Validation
    validate(username, password);

    // 2. User Lookup (optimized with index)
    Optional<User> userOpt = userRepository.findByUsername(username);

    // 3. User Existence Check
    if (userOpt.isEmpty()) return error("User not found");

    // 4. Password Verification
    User user = userOpt.get();
    if (!user.getPasswordHash().equals(password)) {
        return error("Invalid password");
    }

    // 5. Success Response
    return success("Login successful! Balance: $" + user.getBalance());
}
```

### 2. User Entity

**Responsibility:** Represent user data and map to database table

**Entity Mapping:**

```java
@Entity                                    // JPA entity marker
@Table(name = "users")                     // Maps to 'users' table
public class User {
    @Id                                    // Primary key
    @GeneratedValue(strategy = IDENTITY)   // Auto-increment
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "username", unique = true, nullable = false, length = 50)
    private String username;

    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Column(name = "balance", precision = 12, scale = 2)
    private BigDecimal balance;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
```

**JPA Annotations:**

| Annotation | Purpose | Impact |
|-----------|---------|--------|
| `@Entity` | Marks class as JPA entity | Hibernate manages lifecycle |
| `@Table` | Maps to database table | Defines table name |
| `@Id` | Marks primary key | Unique identifier |
| `@GeneratedValue` | Auto-generate values | Database handles ID generation |
| `@Column` | Maps to table column | Defines constraints and metadata |

### 3. UserRepository

**Responsibility:** Data access abstraction for User entity

**Interface Design:**

```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    // Custom query methods
    Optional<User> findByUsername(String username);
    boolean existsByUsername(String username);
}
```

**Inherited Methods from JpaRepository:**

```java
// CRUD Operations
save(User entity)           // INSERT or UPDATE
findById(Long id)           // SELECT by ID
findAll()                   // SELECT all
deleteById(Long id)         // DELETE by ID
count()                     // SELECT COUNT(*)

// Batch Operations
saveAll(Iterable<User>)     // Batch INSERT
deleteAll()                 // Delete all records
```

## Authentication Flow

### Sequence Diagram: Successful Login

```
User          Browser        AuthController    UserRepository    Database
 │               │                  │                 │              │
 │──Enter creds─>│                  │                 │              │
 │               │                  │                 │              │
 │               │──POST /login────>│                 │              │
 │               │   {username,pwd} │                 │              │
 │               │                  │                 │              │
 │               │                  │──Validate input─┤              │
 │               │                  │                 │              │
 │               │                  │──findByUsername─>              │
 │               │                  │                 │              │
 │               │                  │                 │──SQL Query──>│
 │               │                  │                 │              │
 │               │                  │                 │<─User data──│
 │               │                  │                 │              │
 │               │                  │<─Optional<User>─│              │
 │               │                  │                 │              │
 │               │                  │──Check user────┤              │
 │               │                  │   exists?       │              │
 │               │                  │                 │              │
 │               │                  │──Verify pwd────┤              │
 │               │                  │                 │              │
 │               │                  │──Get balance───┤              │
 │               │                  │                 │              │
 │               │<─200 OK─────────│                 │              │
 │               │  "Login success" │                 │              │
 │               │  Balance: $1000  │                 │              │
 │               │                  │                 │              │
 │<─Display msg──│                  │                 │              │
```

### Sequence Diagram: Failed Login (Invalid Password)

```
User          Browser        AuthController    UserRepository    Database
 │               │                  │                 │              │
 │──Enter creds─>│                  │                 │              │
 │  (wrong pwd)  │                  │                 │              │
 │               │──POST /login────>│                 │              │
 │               │                  │                 │              │
 │               │                  │──Validate input─┤              │
 │               │                  │                 │              │
 │               │                  │──findByUsername─>              │
 │               │                  │                 │──SQL Query──>│
 │               │                  │                 │<─User data──│
 │               │                  │<─Optional<User>─│              │
 │               │                  │                 │              │
 │               │                  │──Compare pwd───┤              │
 │               │                  │  (MISMATCH)     │              │
 │               │                  │                 │              │
 │               │<─400 Bad Request─│                 │              │
 │               │  "Invalid pwd"   │                 │              │
 │               │                  │                 │              │
 │<─Show error───│                  │                 │              │
```

### State Diagram: Login Process

```
                ┌─────────────┐
                │   Initial   │
                └──────┬──────┘
                       │
                       ▼
                ┌─────────────┐
                │   Validate  │
                │    Input    │
                └──────┬──────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
   [Invalid]      [Valid]             │
        │              │              │
        ▼              ▼              │
  ┌─────────┐   ┌─────────────┐      │
  │  Return │   │   Lookup    │      │
  │  Error  │   │    User     │      │
  └─────────┘   └──────┬──────┘      │
                       │              │
        ┌──────────────┼──────────────┤
        │              │              │
   [Not Found]    [Found]             │
        │              │              │
        ▼              ▼              │
  ┌─────────┐   ┌─────────────┐      │
  │  Return │   │   Verify    │      │
  │  Error  │   │  Password   │      │
  └─────────┘   └──────┬──────┘      │
                       │              │
        ┌──────────────┼──────────────┤
        │              │              │
   [Invalid]      [Valid]             │
        │              │              │
        ▼              ▼              │
  ┌─────────┐   ┌─────────────┐      │
  │  Return │   │   Return    │      │
  │  Error  │   │   Success   │      │
  └─────────┘   └─────────────┘      │
```

## Data Layer Architecture

### Database Schema

```sql
-- Users table structure
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Performance optimization index
CREATE INDEX idx_users_username ON users(username);
```

### Index Architecture

**B-Tree Index Structure:**

```
                    [M]
                   /   \
                 /       \
              [G]         [S]
             /   \       /   \
           [C]   [J]   [P]   [W]
          /  \   /  \   / \   / \
        [A] [E][H][L][N][R][T][Z]
         │   │  │  │  │  │  │  │
         ▼   ▼  ▼  ▼  ▼  ▼  ▼  ▼
      Users with usernames starting with each letter
```

**Index Benefits:**

| Operation | Without Index | With Index | Improvement |
|-----------|--------------|------------|-------------|
| Login lookup | O(n) full scan | O(log n) tree traversal | 1000x faster with 1M users |
| Query time (1K users) | ~50ms | ~0.5ms | 100x faster |
| Query time (1M users) | ~50s | ~5ms | 10,000x faster |

**Index Storage:**

```
Index size calculation:
- Username length: avg 20 bytes
- Pointer size: 8 bytes
- Entry size: ~28 bytes
- 1M users: ~28 MB index size
- Fits in memory for fast access
```

### Connection Pooling

**HikariCP Configuration (Spring Boot default):**

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10        # Max connections
      minimum-idle: 5               # Min idle connections
      connection-timeout: 30000     # 30 seconds
      idle-timeout: 600000          # 10 minutes
      max-lifetime: 1800000         # 30 minutes
```

**Connection Pool Architecture:**

```
┌────────────────────────────────────────────┐
│         HikariCP Connection Pool           │
│                                            │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐     │
│  │ C1   │ │ C2   │ │ C3   │ │ ...  │     │
│  │ACTIVE│ │IDLE  │ │IDLE  │ │ C10  │     │
│  └──────┘ └──────┘ └──────┘ └──────┘     │
│                                            │
│  Pool Metrics:                             │
│  - Active: 1/10                            │
│  - Idle: 9/10                              │
│  - Waiting: 0                              │
└────────────────────────────────────────────┘
           │        │        │
           ▼        ▼        ▼
     ┌─────────────────────────┐
     │   PostgreSQL Database   │
     └─────────────────────────┘
```

## API Design

### REST Endpoint Specification

#### POST /login

**Request:**

```http
POST /login HTTP/1.1
Host: localhost:8080
Content-Type: application/json

{
  "username": "johndoe",
  "password": "securepass123"
}
```

**Response (Success - 200 OK):**

```http
HTTP/1.1 200 OK
Content-Type: text/plain

Login successful! Balance: $1000.00
```

**Response (User Not Found - 400 Bad Request):**

```http
HTTP/1.1 400 Bad Request
Content-Type: text/plain

ERROR: User not found
```

**Response (Invalid Password - 400 Bad Request):**

```http
HTTP/1.1 400 Bad Request
Content-Type: text/plain

ERROR: Invalid password
```

**Response (Empty Username - 400 Bad Request):**

```http
HTTP/1.1 400 Bad Request
Content-Type: text/plain

ERROR: Username is required
```

### HTTP Status Code Strategy

| Status Code | Scenario | Response Body |
|-------------|----------|---------------|
| 200 OK | Successful login | Success message with balance |
| 400 Bad Request | Invalid credentials | Error message |
| 400 Bad Request | Missing parameters | Error message |
| 500 Internal Server Error | Database error | Error message |

### Error Handling Architecture

**Exception Flow:**

```
┌─────────────────────────────────────────────────────┐
│               AuthController                        │
│                                                     │
│  try {                                              │
│      // Validation logic                            │
│  } catch (DataAccessException e) {                  │
│      // Database errors                             │
│  } catch (Exception e) {                            │
│      // Generic errors                              │
│  }                                                  │
└─────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────┐
│      Spring Boot Exception Handler                  │
│  @ControllerAdvice                                  │
│                                                     │
│  - Logs exception details                           │
│  - Returns user-friendly error                      │
│  - Sends 500 status code                            │
└─────────────────────────────────────────────────────┘
```

## Session Management

### Current Implementation (Stateless)

**Request-Response Lifecycle:**

```
Request 1: Login
  │
  ├─> Validate credentials
  ├─> Return success
  └─> No session created

Request 2: Another login
  │
  ├─> Validate credentials (again)
  ├─> No knowledge of previous request
  └─> Completely independent
```

**Characteristics:**
- No server-side session storage
- Each request is independent
- No persistent authentication state
- Balance retrieved fresh each time

### Future Session Architectures

#### 1. JWT Token-Based (Recommended for Production)

```
Login Request
     │
     ▼
Generate JWT Token
     │
     │  { "sub": "johndoe",
     │    "userId": 123,
     │    "exp": 1704067200,
     │    "iat": 1704063600 }
     │
     ▼
Sign with Secret Key
     │
     ▼
Return Token to Client
     │
     ▼
Client Stores in localStorage/Cookie
     │
     ▼
Subsequent Requests Include Token
     │
     │  Authorization: Bearer <token>
     │
     ▼
Server Validates Token
     │
     ├─> Valid: Process request
     └─> Invalid: Return 401
```

**JWT Structure:**

```
Header:
{
  "alg": "HS256",
  "typ": "JWT"
}

Payload:
{
  "sub": "johndoe",
  "userId": 123,
  "balance": 1000.00,
  "exp": 1704067200,
  "iat": 1704063600
}

Signature:
HMACSHA256(
  base64UrlEncode(header) + "." +
  base64UrlEncode(payload),
  secret_key
)
```

#### 2. Server-Side Session (Traditional)

```
Login Request
     │
     ▼
Create Session in Database/Redis
     │
     │  session_id: abc123
     │  user_id: 123
     │  username: johndoe
     │  created: 2024-01-01 10:00:00
     │  expires: 2024-01-01 11:00:00
     │
     ▼
Return Session ID in Cookie
     │
     │  Set-Cookie: SESSIONID=abc123; HttpOnly; Secure
     │
     ▼
Client Sends Cookie with Requests
     │
     ▼
Server Looks Up Session
     │
     ├─> Found & Valid: Process request
     └─> Not Found/Expired: Redirect to login
```

## Security Architecture

### Current Security Implementation

**WARNING:** This implementation is for **educational purposes only** and has significant security vulnerabilities.

#### Vulnerabilities in Current Design

1. **Plain-text Password Storage**

```java
// INSECURE: Direct password comparison
if (!user.getPasswordHash().equals(password)) {
    return ResponseEntity.badRequest().body("ERROR: Invalid password");
}

// passwordHash field actually stores plain text!
// Database contains: password_hash = "mypassword123"
```

2. **No Password Hashing**

```sql
-- INSECURE: Passwords visible in database
SELECT username, password_hash FROM users;

username  | password_hash
----------|---------------
johndoe   | securepass123
alice     | password456
bob       | qwerty789
```

3. **Username Enumeration**

```java
// INSECURE: Reveals whether username exists
if (userOpt.isEmpty()) {
    return ResponseEntity.badRequest().body("ERROR: User not found");
}
if (!user.getPasswordHash().equals(password)) {
    return ResponseEntity.badRequest().body("ERROR: Invalid password");
}

// Attacker can determine valid usernames by error messages
```

4. **No Rate Limiting**

```
Attacker can make unlimited login attempts:
  POST /login {username: "admin", password: "pass1"}
  POST /login {username: "admin", password: "pass2"}
  POST /login {username: "admin", password: "pass3"}
  ... (thousands of attempts)
```

5. **Unencrypted HTTP Traffic**

```
Plain HTTP transmission:
  POST http://localhost:8080/login
  {"username": "johndoe", "password": "secret123"}

  Anyone on the network can intercept credentials!
```

### Production Security Architecture

**Multi-Layer Security Model:**

```
┌─────────────────────────────────────────────────────┐
│              Transport Layer (HTTPS)                │
│  - TLS 1.3 encryption                               │
│  - Certificate validation                           │
│  - Prevents man-in-the-middle attacks               │
└─────────────────────────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────────┐
│           Application Layer (JWT)                   │
│  - Token-based authentication                       │
│  - Signed with HS256/RS256                          │
│  - Includes expiration                              │
└─────────────────────────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────────┐
│         Business Logic Layer (Validation)           │
│  - Input sanitization                               │
│  - Rate limiting (Redis)                            │
│  - Account lockout after failures                   │
└─────────────────────────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────────┐
│          Data Layer (bcrypt Hashing)                │
│  - BCrypt password hashing                          │
│  - Salt generation (random per user)                │
│  - Work factor: 12 rounds                           │
└─────────────────────────────────────────────────────┘
```

**BCrypt Implementation (Future Module):**

```java
// Secure password hashing
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

// Registration
String hashedPassword = encoder.encode(plainPassword);
user.setPasswordHash(hashedPassword);

// Login
if (encoder.matches(plainPassword, user.getPasswordHash())) {
    // Password correct
}

// Database stores:
// $2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW
//  │   │  │                      Actual hash
//  │   │  └─ Salt
//  │   └─ Work factor (2^12 iterations)
//  └─ Algorithm identifier
```

## Performance Optimization

### Database Query Optimization

#### 1. Username Index Performance

**Without Index:**

```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'johndoe';

Seq Scan on users  (cost=0.00..1000.00 rows=1 width=100) (actual time=45.234..50.123 rows=1 loops=1)
  Filter: (username = 'johndoe'::text)
  Rows Removed by Filter: 99999
Planning Time: 0.123 ms
Execution Time: 50.234 ms
```

**With Index:**

```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE username = 'johndoe';

Index Scan using idx_users_username on users  (cost=0.29..8.31 rows=1 width=100) (actual time=0.012..0.015 rows=1 loops=1)
  Index Cond: (username = 'johndoe'::text)
Planning Time: 0.089 ms
Execution Time: 0.023 ms
```

**Performance Comparison:**

| Metric | Without Index | With Index | Improvement |
|--------|--------------|------------|-------------|
| Execution Time | 50.234 ms | 0.023 ms | 2184x faster |
| Rows Scanned | 100,000 | 1 | 100,000x reduction |
| I/O Operations | 1,000+ pages | ~3 pages | 333x reduction |

### JPA Query Caching

**Hibernate Second-Level Cache (Future Enhancement):**

```yaml
spring:
  jpa:
    properties:
      hibernate:
        cache:
          use_second_level_cache: true
          region:
            factory_class: org.hibernate.cache.jcache.JCacheRegionFactory
```

### Application-Level Optimizations

**Connection Pool Tuning:**

```
Optimal pool size = ((core_count * 2) + effective_spindle_count)

For 4-core CPU with 1 SSD:
  Pool size = (4 * 2) + 1 = 9 connections

Spring Boot default: 10 (slightly above optimal)
```

## Scalability Considerations

### Horizontal Scaling

**Load Balancer Architecture:**

```
                  ┌──────────────┐
                  │Load Balancer │
                  │   (Nginx)    │
                  └──────┬───────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
   ┌─────────┐    ┌─────────┐    ┌─────────┐
   │Spring   │    │Spring   │    │Spring   │
   │Boot #1  │    │Boot #2  │    │Boot #3  │
   └────┬────┘    └────┬────┘    └────┬────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   PostgreSQL    │
              │   (Primary)     │
              └─────────────────┘
```

### Database Scaling

**Read Replicas for High Traffic:**

```
                   ┌──────────────┐
                   │  Primary DB  │
                   │ (Writes only)│
                   └──────┬───────┘
                          │
                  Streaming Replication
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
  ┌──────────┐      ┌──────────┐      ┌──────────┐
  │Replica #1│      │Replica #2│      │Replica #3│
  │ (Reads)  │      │ (Reads)  │      │ (Reads)  │
  └──────────┘      └──────────┘      └──────────┘
```

**Login Request Distribution:**

```java
// Write operations → Primary
@Transactional
public void register(User user) {
    userRepository.save(user);  // Goes to primary
}

// Read operations → Replicas
@Transactional(readOnly = true)
public Optional<User> login(String username) {
    return userRepository.findByUsername(username);  // Can use replica
}
```

### Caching Strategy

**Redis-Based Session Cache:**

```
┌─────────────────────────────────────────────┐
│          Application Tier                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ App #1   │  │ App #2   │  │ App #3   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
└───────┼─────────────┼─────────────┼─────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │     Redis Cluster      │
         │   (Session Storage)    │
         │                        │
         │  session:abc123 →      │
         │    {userId: 123,       │
         │     username: "john",  │
         │     loginTime: ...}    │
         └────────────────────────┘
```

## Deployment Architecture

### Development Environment

```
localhost:8080
    │
    ├── /login.html (frontend)
    ├── /index.html (frontend)
    ├── /login (API endpoint)
    └── /register (API endpoint)

Database: localhost:5432/samplebank1
```

### Production Environment (Future)

```
https://api.samplebank.com
    │
    ├── WAF (Web Application Firewall)
    ├── Rate Limiting (API Gateway)
    ├── Load Balancer
    ├── SSL Termination
    └── Application Servers (3+ instances)
        │
        ├── Database Connection Pool
        ├── Redis Session Store
        └── Monitoring/Logging
```

## Conclusion

This architecture document details the current implementation of SampleBank v2's login system, including its design patterns, component interactions, and data flow. While the current implementation serves educational purposes, it establishes the foundation for implementing production-grade security features in future modules.

**Next Steps:**
- Module 06: Add transaction processing
- Module 13: Implement bcrypt password hashing
- Module 16: Add JWT authentication and HTTPS
- Module 30: Complete security audit and compliance

---

**Document Version:** 1.0
**Last Updated:** January 2024
**Module:** 05 - SampleBank v2 Login System
