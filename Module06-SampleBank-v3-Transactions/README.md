# SampleBank v3 - Banking Transactions Module

## Overview

SampleBank v3 is a Spring Boot banking application that implements secure money transfer functionality between user accounts. This module builds upon previous modules by adding transaction tracking, balance management, and real-time fund transfers with proper ACID compliance.

This is **Module 06** in the PostgreSQL Production Labs series, focusing on database transactions, concurrency control, and financial operations.

## Key Features

### Transaction Management
- **Money Transfer System**: Secure peer-to-peer money transfers between users
- **Balance Tracking**: Real-time account balance updates
- **Transaction History**: Complete audit trail of all financial transactions
- **ACID Compliance**: Guaranteed consistency and atomicity for all financial operations

### Security & Validation
- **Input Validation**: Comprehensive validation of transfer amounts and user credentials
- **Insufficient Balance Checks**: Prevents overdrafts and negative balances
- **User Verification**: Validates both sender and receiver before processing transfers
- **Session Management**: Secure user sessions with SessionStorage

### User Interface
- **Dashboard**: Clean, modern interface for viewing balance and making transfers
- **Real-time Balance Updates**: Automatic balance refresh after transactions
- **Responsive Design**: Mobile-friendly interface with gradient styling
- **Error Handling**: Clear, user-friendly error messages

## Architecture

### Technology Stack
- **Backend Framework**: Spring Boot 2.x
- **ORM**: Spring Data JPA with Hibernate
- **Database**: PostgreSQL 12+
- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **API Style**: RESTful JSON endpoints

### Core Components

#### Entities
- **Transaction.java**: Represents money transfer records with sender, receiver, amount, and timestamp
- **User.java** (from previous modules): User accounts with balance information

#### Repositories
- **TransactionRepository**: JPA repository for transaction CRUD operations
- **UserRepository** (from previous modules): User account management

#### Controllers
- **TransferController**: Handles money transfer and balance inquiry endpoints

#### Database Layer
- **transfer_money() Stored Procedure**: PostgreSQL function implementing transactional transfer logic
- **Transactions Table**: Audit log of all money transfers with foreign key constraints

## API Endpoints

### POST /transfer
Transfers money from one user to another.

**Request Body:**
```json
{
    "fromUsername": "alice",
    "toUsername": "bob",
    "amount": "250.00"
}
```

**Success Response:**
```
SUCCESS: Transferred $250.00 from alice to bob
```

**Error Responses:**
```
ERROR: Sender not found
ERROR: Receiver not found
ERROR: Insufficient balance
ERROR: Amount must be greater than 0
ERROR: Invalid amount format
```

### GET /balance/{username}
Retrieves the current balance for a specified user.

**Success Response:**
```
Balance for alice: $750.00
```

**Error Response:**
```
ERROR: User not found
```

## Database Schema

### Transactions Table
```sql
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_user_id INT NOT NULL REFERENCES users(user_id),
    to_user_id INT NOT NULL REFERENCES users(user_id),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_user_id != to_user_id)
);

CREATE INDEX idx_transactions_from ON transactions(from_user_id);
CREATE INDEX idx_transactions_to ON transactions(to_user_id);
```

### Users Table (from previous modules)
```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Quick Start

### Prerequisites
- Java 11 or higher
- PostgreSQL 12 or higher
- Maven 3.6+
- curl or Postman (for API testing)

### Setup Steps

1. **Create Database**
```bash
psql -U postgres
CREATE DATABASE samplebank;
\c samplebank
```

2. **Run Database Scripts**
```bash
psql -U postgres -d samplebank -f database/transactions-schema.sql
psql -U postgres -d samplebank -f database/transfer-procedure.sql
```

3. **Configure Application**
Edit `src/main/resources/application.properties`:
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/samplebank
spring.datasource.username=postgres
spring.datasource.password=your_password
spring.jpa.hibernate.ddl-auto=update
```

4. **Build and Run**
```bash
mvn clean install
mvn spring-boot:run
```

5. **Access Application**
- Open browser: http://localhost:8080
- Register users via index.html
- Login via login.html
- Access dashboard at dashboard.html

## Testing the Application

### Create Test Users
```bash
# Register Alice
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@test.com","password":"pass123"}'

# Register Bob
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","email":"bob@test.com","password":"pass456"}'
```

### Check Initial Balances
```bash
curl http://localhost:8080/balance/alice
# Expected: Balance for alice: $1000.00

curl http://localhost:8080/balance/bob
# Expected: Balance for bob: $1000.00
```

### Perform Transfer
```bash
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromUsername":"alice","toUsername":"bob","amount":"250.00"}'
# Expected: SUCCESS: Transferred $250.00 from alice to bob
```

### Verify Updated Balances
```bash
curl http://localhost:8080/balance/alice
# Expected: Balance for alice: $750.00

curl http://localhost:8080/balance/bob
# Expected: Balance for bob: $1250.00
```

### Verify Transaction Record
```bash
psql -U postgres -d samplebank -c "SELECT * FROM transactions ORDER BY created_at DESC LIMIT 5;"
```

## Project Structure

```
Module06-SampleBank-v3-Transactions/
├── src/
│   └── main/
│       ├── java/com/samplebank/
│       │   ├── controller/
│       │   │   └── TransferController.java
│       │   ├── entity/
│       │   │   └── Transaction.java
│       │   └── repository/
│       │       └── TransactionRepository.java
│       └── resources/
│           └── static/
│               ├── dashboard.html
│               └── login.html
├── database/
│   ├── transactions-schema.sql
│   └── transfer-procedure.sql
├── README.md
├── ARCHITECTURE.md
├── SETUP-GUIDE.md
├── DATABASE-SCHEMA.md
├── LAB-EXERCISES.md
└── TROUBLESHOOTING.md
```

## Key Learning Objectives

1. **Database Transactions**: Understanding ACID properties in practice
2. **Stored Procedures**: Implementing business logic in PostgreSQL
3. **JPA Entity Management**: Working with entity relationships and persistence
4. **RESTful API Design**: Creating clean, predictable API endpoints
5. **Concurrency Control**: Handling simultaneous transfers safely
6. **Financial Applications**: Best practices for monetary calculations

## Common Use Cases

### Scenario 1: Simple Transfer
Alice wants to send $100 to Bob. The system:
1. Validates both users exist
2. Checks Alice has sufficient balance
3. Deducts $100 from Alice's account
4. Adds $100 to Bob's account
5. Records the transaction
6. Returns success message

### Scenario 2: Insufficient Balance
Alice tries to send $1500 but only has $1000:
1. System checks balance
2. Returns "ERROR: Insufficient balance"
3. No changes are made to either account
4. No transaction record is created

### Scenario 3: Invalid Recipient
Alice tries to send money to a non-existent user:
1. System validates recipient
2. Returns "ERROR: Receiver not found"
3. No balance changes occur
4. Maintains data integrity

## Best Practices

1. **Always Use BigDecimal**: Never use float or double for monetary values
2. **Validate on Both Sides**: Client-side AND server-side validation
3. **Use Transactions**: Database transactions ensure ACID compliance
4. **Audit Everything**: Keep complete transaction history
5. **Test Concurrency**: Simulate multiple simultaneous transfers
6. **Handle Edge Cases**: Zero amounts, self-transfers, negative values

## Related Modules

- **Module 04**: User Registration (creates user accounts)
- **Module 05**: Authentication (provides login functionality)
- **Module 06**: Transactions (current module)
- **Module 07**: Advanced Queries (reporting and analytics)

## Contributing

This is an educational project for PostgreSQL Production Labs. Students should:
1. Complete the TODO tasks in database scripts
2. Test all endpoints thoroughly
3. Experiment with edge cases
4. Implement additional features as exercises

## License

Educational use only - PostgreSQL Production Labs

## Support

For issues and questions:
- Review the TROUBLESHOOTING.md guide
- Check DATABASE-SCHEMA.md for schema details
- Follow LAB-EXERCISES.md for hands-on practice
- Consult ARCHITECTURE.md for design patterns

## Version History

- **v3.0** - Transaction tracking and money transfers
- **v2.0** - User authentication and sessions
- **v1.0** - User registration and basic CRUD
