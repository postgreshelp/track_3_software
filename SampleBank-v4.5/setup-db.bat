@echo off
REM Setup SampleBank v4.5 Database
REM PostgreSQL 18 on OEL 9

echo ========================================
echo SampleBank v4.5 Database Setup
echo ========================================
echo.

REM Create database
echo Creating database samplebank_v45...
psql -U postgres -c "DROP DATABASE IF EXISTS samplebank_v45"
psql -U postgres -c "CREATE DATABASE samplebank_v45"

REM Create schema
echo Creating tables...
psql -U postgres -d samplebank_v45 -f database\schema.sql

REM Create stored procedures
echo Creating stored procedures...
psql -U postgres -d samplebank_v45 -f database\procedures.sql

echo.
echo ========================================
echo Database setup complete!
echo ========================================
echo Database: samplebank_v45
echo Tables: users, accounts, transactions
echo.

pause
