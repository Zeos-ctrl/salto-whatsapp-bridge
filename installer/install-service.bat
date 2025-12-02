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

REM Check for NSSM in local directory first, then C:\nssm
if exist "%ROOT_DIR%\nssm\win64\nssm.exe" (
    set NSSM_PATH=%ROOT_DIR%\nssm\win64\nssm.exe
    echo Using bundled NSSM
) else if exist "C:\nssm\win64\nssm.exe" (
    set NSSM_PATH=C:\nssm\win64\nssm.exe
    echo Using system NSSM from C:\nssm
) else (
    echo [ERROR] NSSM not found!
    echo.
    pause
    exit /b 1
)

echo NSSM Location: %NSSM_PATH%
echo.

REM Check if Node.js is installed
where node >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Node.js is not installed or not in PATH
    echo.
    pause
    exit /b 1
)

echo [1/5] Node.js found
for /f "tokens=*" %%i in ('where node') do set NODE_PATH=%%i
echo       Location: %NODE_PATH%
echo.

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
    echo Stopping and removing existing service...
    "%NSSM_PATH%" stop "Salto WhatsApp Bridge" >nul 2>&1
    timeout /t 2 /nobreak >nul
    "%NSSM_PATH%" remove "Salto WhatsApp Bridge" confirm >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo.
)

REM Create logs directory
if not exist "logs" mkdir logs

REM Install service
echo [5/5] Installing Windows Service...
"%NSSM_PATH%" install "Salto WhatsApp Bridge" "%NODE_PATH%" "src\server.js" >nul 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install service
    pause
    exit /b 1
)

REM Configure service
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppDirectory "%ROOT_DIR%" >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" DisplayName "Salto WhatsApp Bridge" >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" Description "Forwards Salto Space alarms to WhatsApp" >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" Start SERVICE_AUTO_START >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppStdout "%ROOT_DIR%\logs\service-output.log" >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppStderr "%ROOT_DIR%\logs\service-error.log" >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateFiles 1 >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateOnline 1 >nul
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateBytes 10485760 >nul

REM Start service
echo       Starting service...
"%NSSM_PATH%" start "Salto WhatsApp Bridge" >nul 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to start service
    echo Check logs in: %ROOT_DIR%\logs
    pause
    exit /b 1
)

REM Wait for service to start
timeout /t 3 /nobreak >nul

REM Check if running
sc query "Salto WhatsApp Bridge" | find "RUNNING" >nul 2>&1
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
    echo 4. Configure Salto Space webhook
    echo.
) else (
    echo.
    echo [WARNING] Service installed but not running
    echo Check logs in: %ROOT_DIR%\logs
    echo Check Event Viewer for details
    echo.
)

pause
