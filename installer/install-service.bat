@echo off
echo ================================================
echo Salto-WhatsApp Bridge - Service Installation
echo ================================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This script must be run as Administrator
    echo Right-click and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

REM Get directories
set INSTALLER_DIR=%~dp0
set ROOT_DIR=%INSTALLER_DIR%..
set NSSM_PATH=C:\nssm\win64\nssm.exe

echo Installation Directory: %ROOT_DIR%
echo.

REM Check if Node.js is installed
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js is not installed or not in PATH
    echo Download from: https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo [1/5] Node.js found
for /f "tokens=*" %%i in ('where node') do set NODE_PATH=%%i
echo       Location: %NODE_PATH%
echo.

REM Check if NSSM is installed
if not exist "%NSSM_PATH%" (
    echo [ERROR] NSSM not found at: %NSSM_PATH%
    echo.
    echo Please download NSSM from: https://nssm.cc/download
    echo Extract it to C:\nssm\
    echo.
    echo Expected structure:
    echo   C:\nssm\win64\nssm.exe
    echo   C:\nssm\win32\nssm.exe
    echo.
    pause
    exit /b 1
)

echo [2/5] NSSM found
echo.

REM Check if server.js exists
cd /d "%ROOT_DIR%"
if not exist "src\server.js" (
    echo [ERROR] server.js not found at: %ROOT_DIR%\src\server.js
    echo.
    pause
    exit /b 1
)

echo [3/5] Server files found
echo.

REM Install npm dependencies
echo [4/5] Installing dependencies...
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo       Dependencies installed
echo.

REM Check if service already exists
sc query "Salto WhatsApp Bridge" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [WARNING] Service already exists!
    echo Would you like to reinstall? (Y/N)
    choice /C YN /N
    if errorlevel 2 (
        echo Installation cancelled.
        pause
        exit /b 0
    )
    
    echo Stopping existing service...
    "%NSSM_PATH%" stop "Salto WhatsApp Bridge" >nul 2>&1
    timeout /t 2 >nul
    
    echo Removing existing service...
    "%NSSM_PATH%" remove "Salto WhatsApp Bridge" confirm >nul 2>&1
    timeout /t 2 >nul
    echo.
)

REM Create logs directory
if not exist "%ROOT_DIR%\logs" mkdir "%ROOT_DIR%\logs"

REM Install service
echo [5/5] Installing Windows Service...
"%NSSM_PATH%" install "Salto WhatsApp Bridge" "%NODE_PATH%" "src\server.js"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install service
    pause
    exit /b 1
)

REM Configure service
echo       Configuring service...
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppDirectory "%ROOT_DIR%"
"%NSSM_PATH%" set "Salto WhatsApp Bridge" DisplayName "Salto WhatsApp Bridge"
"%NSSM_PATH%" set "Salto WhatsApp Bridge" Description "Forwards Salto Space alarms to WhatsApp"
"%NSSM_PATH%" set "Salto WhatsApp Bridge" Start SERVICE_AUTO_START

REM Set up logging
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppStdout "%ROOT_DIR%\logs\service-output.log"
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppStderr "%ROOT_DIR%\logs\service-error.log"

REM Set log rotation (10MB files, keep 5 rotations)
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateFiles 1
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateOnline 1
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateBytes 10485760
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateSeconds 86400

REM Start service
echo       Starting service...
"%NSSM_PATH%" start "Salto WhatsApp Bridge"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to start service
    echo Check logs in: %ROOT_DIR%\logs
    pause
    exit /b 1
)

REM Wait a moment for service to start
timeout /t 3 >nul

REM Check service status
"%NSSM_PATH%" status "Salto WhatsApp Bridge" | find "SERVICE_RUNNING" >nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ================================================
    echo Installation Complete!
    echo ================================================
    echo.
    echo Service Status: RUNNING
    echo Web Interface: http://localhost:3000
    echo Logs Location: %ROOT_DIR%\logs
    echo.
    echo Next Steps:
    echo 1. Open http://localhost:3000 in your browser
    echo 2. Scan the QR code with WhatsApp
    echo 3. Add target groups/contacts
    echo 4. Configure Salto webhook
    echo.
    echo Service Management:
    echo - View in Services: services.msc
    echo - Stop:    nssm stop "Salto WhatsApp Bridge"
    echo - Start:   nssm start "Salto WhatsApp Bridge"
    echo - Restart: nssm restart "Salto WhatsApp Bridge"
    echo - Remove:  Run uninstall-service.bat
    echo.
) else (
    echo.
    echo [WARNING] Service installed but not running
    echo Check logs in: %ROOT_DIR%\logs
    echo Try: nssm start "Salto WhatsApp Bridge"
    echo.
)

pause
