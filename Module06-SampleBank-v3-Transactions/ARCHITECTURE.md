# SampleBank v3 - Architecture Documentation

## Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Application Layers](#application-layers)
3. [Transaction Processing Architecture](#transaction-processing-architecture)
4. [ACID Properties Implementation](#acid-properties-implementation)
5. [Data Flow](#data-flow)
6. [Component Details](#component-details)
7. [Security Architecture](#security-architecture)
8. [Concurrency Control](#concurrency-control)
9. [Error Handling Strategy](#error-handling-strategy)
10. [Design Patterns](#design-patterns)

## System Architecture Overview

SampleBank v3 follows a **three-tier architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                  Presentation Layer                      │
│  (HTML/CSS/JavaScript - dashboard.html, login.html)     │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP/REST API
┌────────────────────┼────────────────────────────────────┐
│                    │   Application Layer                 │
│  ┌─────────────────▼──────────────┐                     │
│  │   TransferController            │                     │
│  │   - POST /transfer              │                     │
│  │   - GET /balance/{username}     │                     │
│  └─────────────────┬───────────────┘                     │
│                    │                                      │
│  ┌─────────────────▼──────────────┐                     │
│  │   TransactionRepository         │                     │
│  │   UserRepository                │                     │
│  └─────────────────┬───────────────┘                     │
│                    │ JPA/Hibernate                       │
└────────────────────┼────────────────────────────────────┘
                     │ JDBC
┌────────────────────▼────────────────────────────────────┐
│                  Data Layer                              │
│  PostgreSQL Database                                     │
│  - users table                                           │
│  - transactions table                                    │
│  - transfer_money() stored procedure                     │
└─────────────────────────────────────────────────────────┘
```

### Architecture Principles

1. **Separation of Concerns**: Each layer has a specific responsibility
2. **Loose Coupling**: Layers interact through well-defined interfaces
3. **High Cohesion**: Related functionality is grouped together
4. **Database-Centric Logic**: Critical business logic in stored procedures
5. **RESTful Design**: Stateless API following REST principles

## Application Layers

### 1. Presentation Layer

**Components:**
- dashboard.html - User interface for transfers and balance viewing
- login.html - Authentication interface

**Responsibilities:**
- User interaction and input collection
- Client-side validation (first line of defense)
- Display formatting and error messages
- Session management (SessionStorage)
- AJAX requests to backend API

**Key Technologies:**
- HTML5 for structure
- CSS3 for styling (gradient backgrounds, responsive design)
- Vanilla JavaScript for interactivity
- Fetch API for HTTP requests

### 2. Application Layer

#### Controllers

**TransferController.java**
```
Responsibilities:
- Request parsing and validation
- Input sanitization
- Business logic orchestration
- Response formatting
- Error handling and messaging

Endpoints:
- POST /transfer: Initiates money transfer
- GET /balance/{username}: Retrieves account balance
```

**Design Characteristics:**
- Stateless: No server-side session management
- Validation: Multiple validation layers
- Delegation: Delegates database operations to stored procedures
- Error Messages: Standardized error format with "ERROR:" prefix

#### Repositories

**TransactionRepository.java**
```java
public interface TransactionRepository extends JpaRepository<Transaction, Long> {
    List<Transaction> findByFromUserId(Long fromUserId);
    List<Transaction> findByToUserId(Long toUserId);
}
```

**Features:**
- Spring Data JPA magic methods
- Automatic query generation
- Type-safe query methods
- Transaction management integration

**UserRepository.java** (from previous modules)
```java
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
}
```

#### Entities

**Transaction.java**
```
Fields:
- transactionId: Primary key (auto-generated)
- fromUserId: Sender reference
- toUserId: Receiver reference
- amount: Transfer amount (BigDecimal for precision)
- createdAt: Timestamp (auto-generated)

Annotations:
- @Entity: JPA entity marker
- @Table: Maps to "transactions" table
- @PrePersist: Lifecycle callback for timestamp
```

**Design Decisions:**
- BigDecimal for monetary values (no floating-point errors)
- Foreign key references (not @ManyToOne to avoid lazy loading issues)
- Immutable after creation (no setters for critical fields)
- Audit timestamp with @PrePersist

### 3. Data Layer

**PostgreSQL Database Components:**

1. **Tables**: users, transactions
2. **Stored Procedures**: transfer_money()
3. **Constraints**: Foreign keys, CHECK constraints
4. **Indexes**: Performance optimization

## Transaction Processing Architecture

### Money Transfer Flow

```
┌──────────────┐
│  Client      │
│  (Browser)   │
└──────┬───────┘
       │ 1. POST /transfer
       │    {fromUsername, toUsername, amount}
       ▼
┌──────────────────────────────────────────┐
│  TransferController                       │
│  ┌────────────────────────────────────┐  │
│  │ Input Validation                   │  │
│  │ - Non-empty usernames              │  │
│  │ - Valid amount format              │  │
│  │ - Positive amount                  │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ Call Stored Procedure              │  │
│  │ transfer_money(from, to, amount)   │  │
│  └────────────┬───────────────────────┘  │
└───────────────┼──────────────────────────┘
                │ JDBC Call
                ▼
┌──────────────────────────────────────────┐
│  PostgreSQL: transfer_money() Function   │
│  ┌────────────────────────────────────┐  │
│  │ BEGIN TRANSACTION (Implicit)       │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ 1. Validate Sender Exists          │  │
│  │    SELECT user_id, balance         │  │
│  │    FROM users                      │  │
│  │    WHERE username = p_from         │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ 2. Check Sufficient Balance        │  │
│  │    IF balance < amount THEN        │  │
│  │       RETURN 'ERROR: Insufficient' │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ 3. Validate Receiver Exists        │  │
│  │    SELECT user_id                  │  │
│  │    FROM users                      │  │
│  │    WHERE username = p_to           │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ 4. Update Sender Balance           │  │
│  │    UPDATE users                    │  │
│  │    SET balance = balance - amount  │  │
│  │    WHERE user_id = from_id         │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ 5. Update Receiver Balance         │  │
│  │    UPDATE users                    │  │
│  │    SET balance = balance + amount  │  │
│  │    WHERE user_id = to_id           │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ 6. Record Transaction              │  │
│  │    INSERT INTO transactions        │  │
│  │    (from_user_id, to_user_id, amt) │  │
│  └────────────┬───────────────────────┘  │
│               ▼                           │
│  ┌────────────────────────────────────┐  │
│  │ COMMIT TRANSACTION (Implicit)      │  │
│  │ RETURN 'SUCCESS: Transferred...'   │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### Why Stored Procedures?

**Advantages:**
1. **Atomicity**: All operations in single transaction
2. **Performance**: Reduced network round-trips
3. **Security**: SQL injection prevention
4. **Consistency**: Business logic centralized
5. **Database-Level Locking**: Better concurrency control

**Trade-offs:**
- Database-specific (not portable)
- Harder to test
- Version control complexity
- Requires database deployment

## ACID Properties Implementation

### Atomicity

**Definition**: All operations succeed or all fail together.

**Implementation in SampleBank:**
```sql
CREATE OR REPLACE FUNCTION transfer_money(...) RETURNS TEXT AS $$
DECLARE
    -- Variables
BEGIN
    -- All operations within BEGIN...END are atomic
    -- If ANY operation fails, ALL changes are rolled back

    UPDATE users SET balance = balance - p_amount
    WHERE user_id = v_from_user_id;

    UPDATE users SET balance = balance + p_amount
    WHERE user_id = v_to_user_id;

    INSERT INTO transactions (from_user_id, to_user_id, amount)
    VALUES (v_from_user_id, v_to_user_id, p_amount);

    -- All three succeed together or fail together
    RETURN 'SUCCESS: Transferred...';
EXCEPTION
    WHEN OTHERS THEN
        -- Automatic rollback on any error
        RETURN 'ERROR: Transaction failed';
END;
$$ LANGUAGE plpgsql;
```

**Guarantees:**
- If sender update fails, receiver is not updated
- If transaction insert fails, balance updates are rolled back
- Network failures during execution trigger rollback
- Database crashes preserve consistency

### Consistency

**Definition**: Database moves from one valid state to another valid state.

**Implementation Mechanisms:**

1. **CHECK Constraints:**
```sql
-- Prevent negative balances
balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0)

-- Prevent zero or negative transfers
amount DECIMAL(12,2) NOT NULL CHECK (amount > 0)

-- Prevent self-transfers
CHECK (from_user_id != to_user_id)
```

2. **Foreign Key Constraints:**
```sql
from_user_id INT NOT NULL REFERENCES users(user_id)
to_user_id INT NOT NULL REFERENCES users(user_id)
```

3. **NOT NULL Constraints:**
```sql
from_user_id INT NOT NULL
to_user_id INT NOT NULL
amount DECIMAL(12,2) NOT NULL
```

4. **Application-Level Validation:**
```java
if (amount.compareTo(BigDecimal.ZERO) <= 0) {
    return ResponseEntity.badRequest().body("ERROR: Amount must be greater than 0");
}
```

**Validation Layers:**
1. Client-side JavaScript validation
2. Controller-level validation
3. Database CHECK constraints
4. Stored procedure business logic

### Isolation

**Definition**: Concurrent transactions don't interfere with each other.

**PostgreSQL Default Isolation Level**: READ COMMITTED

**Isolation in SampleBank:**

```sql
-- Each transaction sees a consistent snapshot
BEGIN;
    -- User A's balance at start of transaction
    SELECT balance FROM users WHERE user_id = 1;  -- $1000

    -- Another transaction updates the balance
    -- (User A's view doesn't change until commit)

    UPDATE users SET balance = balance - 100 WHERE user_id = 1;
    -- Still operating on $1000 snapshot
COMMIT;
```

**Concurrency Scenarios:**

**Scenario 1: Sequential Transfers**
```
Transaction 1: Alice -> Bob ($100)
Transaction 2: Alice -> Charlie ($50) [starts after T1 commits]
Result: Safe, sequential execution
```

**Scenario 2: Concurrent Transfers from Same Account**
```
Transaction 1: Alice -> Bob ($100)    [START]
Transaction 2: Alice -> Charlie ($50) [START]
Result: Both see Alice's initial balance
        One commits first, other sees updated balance
        Second transaction may fail if insufficient balance
```

**Scenario 3: Parallel Transfers from Different Accounts**
```
Transaction 1: Alice -> Bob ($100)
Transaction 2: Charlie -> David ($200)
Result: Fully parallel, no interference
```

### Durability

**Definition**: Committed transactions survive system failures.

**PostgreSQL Mechanisms:**
1. **Write-Ahead Logging (WAL)**: Changes written to log before data files
2. **fsync**: Forces disk writes
3. **Checkpoints**: Periodic synchronization to disk
4. **Crash Recovery**: Replay WAL on restart

**SampleBank Durability:**
```
User makes transfer ->
    Stored procedure executes ->
        Changes written to WAL ->
            WAL flushed to disk ->
                Changes applied to data files ->
                    Success message returned to user

Even if server crashes after "Success" message,
the transaction is guaranteed to be in the database.
```

## Data Flow

### Transfer Request Flow

1. **Client Input**: User fills transfer form
2. **Client Validation**: JavaScript checks format
3. **HTTP POST**: Fetch API sends JSON to /transfer
4. **Controller Receives**: TransferController.transfer()
5. **Parameter Extraction**: Parse fromUsername, toUsername, amount
6. **Server Validation**:
   - Check non-null values
   - Validate amount format
   - Check positive amount
7. **Create Native Query**: EntityManager.createNativeQuery()
8. **Execute Stored Procedure**: SELECT transfer_money(...)
9. **Database Processing**:
   - Validate sender
   - Check balance
   - Validate receiver
   - Update balances
   - Insert transaction record
10. **Return Result**: SUCCESS or ERROR message
11. **Controller Response**: HTTP 200 or 400 with message
12. **Client Updates UI**: Display message, refresh balance

### Balance Inquiry Flow

1. **Client Request**: GET /balance/{username}
2. **Controller Receives**: TransferController.getBalance()
3. **Path Variable Extraction**: username from URL
4. **Repository Query**: userRepository.findByUsername()
5. **JPA Query Execution**: SELECT * FROM users WHERE username = ?
6. **Result Processing**: Optional<User>
7. **Validation**: Check if user exists
8. **Format Response**: "Balance for {username}: ${balance}"
9. **HTTP Response**: 200 OK or 400 Bad Request
10. **Client Display**: Update balance card

## Component Details

### TransferController

**Annotations:**
- `@RestController`: Combines @Controller and @ResponseBody
- `@Autowired`: Dependency injection for UserRepository
- `@PersistenceContext`: EntityManager injection
- `@PostMapping`: Maps POST /transfer
- `@GetMapping`: Maps GET /balance/{username}
- `@RequestBody`: Parses JSON request body
- `@PathVariable`: Extracts URL path variable

**Key Methods:**

```java
public ResponseEntity<String> transfer(@RequestBody Map<String, String> request)
```
- Purpose: Process money transfer
- Input: JSON with fromUsername, toUsername, amount
- Output: Success or error message
- Validation: Non-empty fields, valid amount
- Delegation: Calls transfer_money() stored procedure

```java
public ResponseEntity<String> getBalance(@PathVariable String username)
```
- Purpose: Retrieve account balance
- Input: Username in URL path
- Output: Formatted balance string
- Validation: User existence check
- Data Access: Uses UserRepository

### Transaction Entity

**JPA Annotations:**
- `@Entity`: Marks as JPA entity
- `@Table(name = "transactions")`: Table mapping
- `@Id`: Primary key marker
- `@GeneratedValue(strategy = GenerationType.IDENTITY)`: Auto-increment
- `@Column`: Column mapping with constraints
- `@PrePersist`: Lifecycle callback

**Design Patterns:**
- **Value Object**: BigDecimal for amount
- **Factory Method**: Constructor with parameters
- **Template Method**: @PrePersist callback

### TransactionRepository

**Interface Design:**
- Extends JpaRepository<Transaction, Long>
- Inherits CRUD methods: save(), findById(), findAll(), delete()
- Custom query methods: findByFromUserId(), findByToUserId()

**Spring Data Magic:**
```java
List<Transaction> findByFromUserId(Long fromUserId);
```
Automatically generates SQL:
```sql
SELECT * FROM transactions WHERE from_user_id = ?
```

## Security Architecture

### Input Validation

**Multi-Layer Validation:**
1. Client-side: HTML5 required, min, step attributes
2. JavaScript: Format and range validation
3. Controller: Null checks, BigDecimal parsing
4. Database: CHECK constraints

### SQL Injection Prevention

**Parameterized Queries:**
```java
entityManager.createNativeQuery("SELECT transfer_money(:from, :to, :amount)")
    .setParameter("from", fromUsername)
    .setParameter("to", toUsername)
    .setParameter("amount", amount)
```

**Benefits:**
- Parameters escaped automatically
- No string concatenation
- Database driver handles encoding

### Session Management

**Client-Side Sessions:**
```javascript
sessionStorage.setItem('username', username);
```

**Security Considerations:**
- SessionStorage cleared on tab close
- Not shared across tabs
- Protected by Same-Origin Policy
- Should be replaced with server-side sessions in production

**Production Recommendations:**
- Use Spring Security
- Implement JWT tokens
- Add CSRF protection
- Enforce HTTPS

## Concurrency Control

### Database-Level Locking

**Row-Level Locking:**
```sql
UPDATE users SET balance = balance - 100 WHERE user_id = 1;
```
- PostgreSQL automatically acquires row lock
- Other transactions wait for lock release
- Prevents lost updates

### Optimistic vs Pessimistic Locking

**Current Implementation: Pessimistic (Implicit)**
- UPDATE statements lock rows
- Other transactions block until commit
- Simple, reliable, but less concurrent

**Alternative: Optimistic Locking**
```sql
-- Add version column
ALTER TABLE users ADD COLUMN version INT DEFAULT 0;

-- Update with version check
UPDATE users
SET balance = balance - 100, version = version + 1
WHERE user_id = 1 AND version = 5;

-- Check rows affected, retry if 0
```

### Deadlock Prevention

**Potential Deadlock Scenario:**
```
T1: Lock Alice's row, wait for Bob's row
T2: Lock Bob's row, wait for Alice's row
Result: Deadlock!
```

**PostgreSQL Detection:**
- Automatic deadlock detection
- One transaction aborted
- Error returned to application

**Prevention Strategies:**
1. Always lock in same order (alphabetical by user_id)
2. Keep transactions short
3. Use SELECT FOR UPDATE to explicitly lock

## Error Handling Strategy

### Error Categories

1. **Validation Errors**: Bad input from client
2. **Business Logic Errors**: Insufficient balance, user not found
3. **System Errors**: Database connection, network failures
4. **Concurrency Errors**: Deadlocks, timeouts

### Error Response Format

**Standard Format:**
```
ERROR: <specific message>
SUCCESS: <specific message>
```

**Examples:**
```
ERROR: Sender not found
ERROR: Insufficient balance
SUCCESS: Transferred $250.00 from alice to bob
```

### Exception Handling

**Controller Level:**
```java
try {
    amount = new BigDecimal(amountStr);
} catch (NumberFormatException e) {
    return ResponseEntity.badRequest().body("ERROR: Invalid amount format");
}
```

**Database Level:**
```sql
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'ERROR: User not found';
    WHEN OTHERS THEN
        RETURN 'ERROR: Transaction failed';
```

## Design Patterns

### 1. Repository Pattern
- Abstraction over data access
- Centralized query management
- Testability through mocking

### 2. Data Transfer Object (DTO)
- Map<String, String> for request body
- Loose coupling between API and domain

### 3. Service Layer (Implicit)
- Stored procedure acts as service layer
- Encapsulates business logic
- Transaction management

### 4. Dependency Injection
- Spring autowires dependencies
- Loose coupling, testability
- Inversion of Control

### 5. Template Method
- @PrePersist for timestamp initialization
- Consistent behavior across entities

### 6. Factory Method
- Entity constructors
- Centralized object creation logic

## Performance Considerations

### Indexing Strategy
```sql
CREATE INDEX idx_transactions_from ON transactions(from_user_id);
CREATE INDEX idx_transactions_to ON transactions(to_user_id);
CREATE INDEX idx_users_username ON users(username);
```

### Query Optimization
- Stored procedures reduce network overhead
- Indexed columns for fast lookups
- Prepared statements via JPA

### Connection Pooling
- HikariCP (Spring Boot default)
- Reuses database connections
- Configurable pool size

### Caching Opportunities
- User balances (short TTL)
- Recent transactions
- User profile data

## Scalability Considerations

### Horizontal Scaling
- Stateless API enables load balancing
- Multiple application servers
- Shared PostgreSQL database

### Database Scaling
- Read replicas for balance queries
- Master for writes (transfers)
- Connection pooling

### Future Enhancements
- Event sourcing for audit trail
- CQRS for read/write separation
- Message queue for async processing
- Microservices decomposition

## Conclusion

The SampleBank v3 architecture demonstrates solid principles for building financial applications:

- **Reliability**: ACID transactions ensure data consistency
- **Security**: Multi-layer validation prevents errors
- **Maintainability**: Clear separation of concerns
- **Performance**: Indexed queries and connection pooling
- **Scalability**: Stateless design enables horizontal scaling

The database-centric approach with stored procedures provides strong guarantees for financial operations while maintaining simplicity and reliability.
