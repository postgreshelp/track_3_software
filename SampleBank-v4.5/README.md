# SampleBank v4.5 - Architecture Evolution

**Evolved from:** SampleBank v4 (2-table schema)
**New in v4.5:** Separate accounts table + improved architecture
**Purpose:** Preparation for Module 24 Multi-Tenant Conversion

---

## 🎯 What Changed from v4 to v4.5

### **Architecture Evolution**

**v4 (Old - Monolithic):**
```
users
├── user_id
├── username
├── balance ← Balance in users table (wrong!)
└── ...

transactions
├── from_user_id ← Direct user-to-user
├── to_user_id
└── ...
```

**v4.5 (New - Proper Banking Architecture):**
```
users
├── user_id
├── username
└── ... (NO balance here!)

accounts ← NEW: Separate accounts table
├── account_id
├── user_id
├── account_number
├── balance ← Balance belongs here!
└── ...

transactions
├── from_account_id ← Account-to-account transfers
├── to_account_id
└── ...
```

---

## 📊 Why This Change?

### **Problems with v4:**
1. ❌ One user = One balance (can't have checking + savings)
2. ❌ Balance mixed with authentication data
3. ❌ Can't implement real banking features (multiple accounts)
4. ❌ Not prepared for multi-tenancy

### **Benefits of v4.5:**
1. ✅ One user can have multiple accounts (checking, savings, credit)
2. ✅ Separation of concerns (users vs accounts)
3. ✅ Ready for multi-tenant conversion (Module 24)
4. ✅ More realistic banking model

---

## 🗄️ New Database Schema

### **users** table
```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
```

### **accounts** table (NEW!)
```sql
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_type VARCHAR(20) DEFAULT 'checking',
    balance DECIMAL(15,2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);
```

### **transactions** table
```sql
CREATE TABLE transactions (
    txn_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount DECIMAL(15,2) NOT NULL,
    txn_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 🚀 Quick Start

### 1. Setup Database
```bash
setup-db.bat
```

Or manually:
```bash
psql -U postgres -c "CREATE DATABASE samplebank_v45"
psql -U postgres -d samplebank_v45 -f database/schema.sql
psql -U postgres -d samplebank_v45 -f database/procedures.sql
```

### 2. Insert Test Data
```bash
test-data.bat
```

### 3. Build Application
```bash
build.bat
```

Or: `mvn clean package -DskipTests`

### 4. Run Application
```bash
run.bat
```

Or: `java -jar target/samplebank-4.5.0.jar`

### 5. Access Application
Open browser: http://localhost:8080

---

## 🔄 Migration from v4 to v4.5

If you have existing v4 data, see `migration/migrate-v4-to-v45.sql`

**Migration steps:**
1. Create accounts table
2. Create one account per user
3. Migrate balance from users to accounts
4. Update transactions to reference accounts
5. Remove balance column from users

**Zero-downtime migration:** See `migration/zero-downtime-migration.md`

---

## 🌐 API Endpoints (Updated)

### Register User
```bash
POST /register
Content-Type: application/json

{
    "username": "alice",
    "email": "alice@example.com",
    "password": "secret123"
}

Response: "User registered! Account ACC-001 created with $1000.00"
```

### Login
```bash
POST /login
Content-Type: application/json

{
    "username": "alice",
    "password": "secret123"
}

Response: {
  "userId": 1,
  "username": "alice",
  "accounts": [
    { "accountNumber": "ACC-001", "type": "checking", "balance": 1000.00 }
  ]
}
```

### Get Accounts
```bash
GET /accounts/{username}

Response: [
  { "accountNumber": "ACC-001", "type": "checking", "balance": 1234.56 },
  { "accountNumber": "ACC-002", "type": "savings", "balance": 5678.90 }
]
```

### Transfer Money
```bash
POST /transfer
Content-Type: application/json

{
    "fromAccount": "ACC-001",
    "toAccount": "ACC-002",
    "amount": 100.00
}

Response: "SUCCESS: Transferred $100.00 from ACC-001 to ACC-002"
```

### Create New Account
```bash
POST /accounts/create
Content-Type: application/json

{
    "username": "alice",
    "accountType": "savings"
}

Response: "Account ACC-002 created successfully"
```

---

## 💻 Frontend Changes

### **dashboard.html** - Updated
```html
<!-- v4: Single balance -->
<div>Balance: $1,234.56</div>

<!-- v4.5: Multiple accounts -->
<div id="accounts">
  <div class="account">
    <span>Checking (ACC-001)</span>
    <span>$1,234.56</span>
  </div>
  <div class="account">
    <span>Savings (ACC-002)</span>
    <span>$5,678.90</span>
  </div>
</div>
```

### **transfer.html** - Updated
```html
<!-- v4: Transfer between users -->
<input name="fromUsername" placeholder="From User">
<input name="toUsername" placeholder="To User">

<!-- v4.5: Transfer between accounts -->
<select name="fromAccount">
  <option value="ACC-001">My Checking (ACC-001)</option>
  <option value="ACC-002">My Savings (ACC-002)</option>
</select>
<input name="toAccount" placeholder="To Account Number">
```

---

## 🧪 Test with cURL

```bash
# 1. Register
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@test.com","password":"test123"}'

# 2. Login
curl -X POST http://localhost:8080/login \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"test123"}'

# 3. Get accounts
curl http://localhost:8080/accounts/alice

# 4. Create savings account
curl -X POST http://localhost:8080/accounts/create \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","accountType":"savings"}'

# 5. Transfer money
curl -X POST http://localhost:8080/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromAccount":"ACC-001","toAccount":"ACC-002","amount":"250.00"}'
```

---

## 📦 Tech Stack

- **Framework:** Spring Boot 2.7.18
- **Java:** 11
- **Database:** PostgreSQL 18
- **Build:** Maven
- **Frontend:** Vanilla HTML/JS (minimal, no frameworks)

---

## 📂 Project Structure

```
SampleBank-v4.5/
├── pom.xml
├── build.bat
├── run.bat
├── setup-db.bat
├── test-data.bat
├── README.md
│
├── database/
│   ├── schema.sql (3-table schema)
│   ├── procedures.sql (transfer_money function)
│   └── test-data.sql
│
├── migration/
│   ├── migrate-v4-to-v45.sql
│   └── zero-downtime-migration.md
│
└── src/main/
    ├── java/com/samplebank/
    │   ├── SampleBankApplication.java
    │   ├── entity/
    │   │   ├── User.java
    │   │   ├── Account.java (NEW!)
    │   │   └── Transaction.java
    │   ├── repository/
    │   │   ├── UserRepository.java
    │   │   ├── AccountRepository.java (NEW!)
    │   │   └── TransactionRepository.java
    │   ├── service/
    │   │   ├── UserService.java
    │   │   └── AccountService.java (NEW!)
    │   └── controller/
    │       ├── AuthController.java
    │       ├── AccountController.java (NEW!)
    │       └── TransferController.java
    └── resources/
        ├── application.properties
        └── static/
            ├── index.html (register)
            ├── login.html
            ├── dashboard.html (updated)
            ├── transfer.html (updated)
            └── js/
                └── api.js (updated)
```

---

## 🎓 Learning Objectives

By studying v4.5, you will understand:

1. ✅ **Schema evolution** - How to refactor database design
2. ✅ **Separation of concerns** - Users vs Accounts vs Transactions
3. ✅ **Data migration** - Moving data between tables
4. ✅ **Zero-downtime migration** - Evolving production systems safely
5. ✅ **Preparation for multi-tenancy** - Clean architecture makes tenant_id addition easier

---

## ➡️ Next Steps

**After mastering v4.5:**
→ **Module 24:** Multi-Tenant SaaS Architecture
- Add tenant_id to all tables
- Implement tenant isolation
- Support multiple banks in one database

---

## 📝 Key Differences Summary

| Feature | v4 | v4.5 |
|---------|-----|-------|
| **Users table** | Has balance column | No balance (clean) |
| **Accounts table** | Doesn't exist | ✅ Separate table |
| **Balance storage** | In users | In accounts |
| **One user can have** | 1 balance | Multiple accounts |
| **Transfers** | User-to-user | Account-to-account |
| **Account types** | N/A | Checking, savings, credit |
| **Account status** | N/A | Active, suspended, closed |
| **Realistic banking** | ❌ No | ✅ Yes |
| **Ready for multi-tenant** | ❌ No | ✅ Yes |

---

**SampleBank v4.5 - Better Architecture for Modern Banking SaaS**

**Version:** 4.5.0
**Status:** ✅ Production-Ready
**Next:** Module 24 Multi-Tenant Conversion
