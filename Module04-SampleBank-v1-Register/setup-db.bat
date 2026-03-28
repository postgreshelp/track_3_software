@echo off
echo Creating samplebank1 database...
psql -U postgres -c "DROP DATABASE IF EXISTS samplebank1;"
psql -U postgres -c "CREATE DATABASE samplebank1;"
echo Running schema...
psql -U postgres -d samplebank1 -f database/schema.sql
echo.
echo Database setup complete!
pause
