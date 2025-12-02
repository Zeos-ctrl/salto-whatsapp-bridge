@echo off
echo Installing Salto-WhatsApp Bridge as Windows Service...
echo.

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click and select "Run as Administrator"
    pause
    exit /b 1
)

REM Install node-windows globally
echo Installing node-windows...
call npm install -g node-windows

REM Install the service
echo Installing service...
node "%~dp0install-service-script.js"

echo.
echo Installation complete!
echo Access the web interface at: http://localhost:3000
echo.
pause
