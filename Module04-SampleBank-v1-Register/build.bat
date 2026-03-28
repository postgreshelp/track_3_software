@echo off
echo ========================================
echo Building SampleBank...
echo ========================================
call mvn clean package -DskipTests
if exist target\samplebank-*.jar (
    echo.
    echo BUILD SUCCESS!
    echo JAR: target\samplebank-*.jar
) else (
    echo BUILD FAILED!
)
pause
