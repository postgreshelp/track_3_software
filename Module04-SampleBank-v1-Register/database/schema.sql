-- Student TODO: Write CREATE TABLE users statement
-- Fields needed:
-- user_id SERIAL PRIMARY KEY
-- username VARCHAR(50) UNIQUE NOT NULL
-- email VARCHAR(100) NOT NULL
-- password_hash VARCHAR(255) NOT NULL
-- balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0)
-- created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS users CASCADE;

-- Users table
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(12,2) DEFAULT 1000.00 CHECK (balance >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);