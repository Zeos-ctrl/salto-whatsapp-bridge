@echo off
echo Uninstalling Salto-WhatsApp Bridge Windows Service...
echo.

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click and select "Run as Administrator"
    pause
    exit /b 1
)

node "%~dp0uninstall-service-script.js"

echo.
echo Uninstallation complete!
pause
