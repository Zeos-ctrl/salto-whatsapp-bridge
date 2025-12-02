#!/bin/bash

echo "Building Salto-WhatsApp Bridge Package on Linux..."
echo ""

# Go to project root
cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for required tools
if ! command -v zip &> /dev/null; then
    echo -e "${RED}Error: 'zip' command not found${NC}"
    echo "Install with: sudo apt install zip"
    exit 1
fi

echo -e "${YELLOW}Step 1: Installing dependencies...${NC}"
npm install

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install dependencies${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Installing pkg globally...${NC}"
npm install -g pkg

echo ""
echo -e "${YELLOW}Step 3: Downloading NSSM...${NC}"
if [ ! -d "nssm-temp" ]; then
    wget https://nssm.cc/release/nssm-2.24.zip -O nssm.zip
    unzip -q nssm.zip -d nssm-temp
    echo "  NSSM downloaded and extracted"
else
    echo "  Using existing NSSM download"
fi

echo ""
echo -e "${YELLOW}Step 4: Creating Windows executable with pkg...${NC}"
mkdir -p dist
pkg src/server.js --target node18-win-x64 --output dist/salto-whatsapp-bridge.exe

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create executable${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 5: Creating package directory...${NC}"
rm -rf dist/package
mkdir -p dist/package/salto-whatsapp-bridge
PACKAGE_DIR="dist/package/salto-whatsapp-bridge"

# Copy necessary files
echo "  - Copying executable..."
cp dist/salto-whatsapp-bridge.exe "$PACKAGE_DIR/"

echo "  - Copying source files..."
cp src/server.js "$PACKAGE_DIR/"

echo "  - Copying public directory..."
cp -r src/public "$PACKAGE_DIR/"

echo "  - Copying package files..."
cp package.json "$PACKAGE_DIR/"

# Copy .env.example
if [ -f ".env.example" ]; then
    cp .env.example "$PACKAGE_DIR/"
else
    echo -e "${YELLOW}Warning: .env.example not found, creating default${NC}"
    cat > "$PACKAGE_DIR/.env.example" << 'ENVEOF'
PORT=3000
WHATSAPP_TARGETS=
ENVEOF
fi

# Copy installer files
if [ -f "installer/README.md" ]; then
    cp installer/README.md "$PACKAGE_DIR/"
else
    echo -e "${YELLOW}Warning: installer/README.md not found${NC}"
fi

if [ -f "installer/LICENSE.txt" ]; then
    cp installer/LICENSE.txt "$PACKAGE_DIR/"
else
    echo -e "${YELLOW}Warning: installer/LICENSE.txt not found${NC}"
fi

if [ -f "installer/INSTALL_REQUIREMENTS.txt" ]; then
    cp installer/INSTALL_REQUIREMENTS.txt "$PACKAGE_DIR/"
fi

# Copy service installation scripts
echo "  - Copying service scripts..."
cp installer/install-service.bat "$PACKAGE_DIR/" 2>/dev/null || echo "    Warning: install-service.bat not found"
cp installer/uninstall-service.bat "$PACKAGE_DIR/" 2>/dev/null || echo "    Warning: uninstall-service.bat not found"

# Copy NSSM
echo "  - Copying NSSM..."
cp -r nssm-temp/nssm-2.24 "$PACKAGE_DIR/nssm"

# Update install-service.bat to look for local NSSM first
cat > "$PACKAGE_DIR/install-service.bat" << 'BATEOF'
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
set ROOT_DIR=%INSTALLER_DIR%

REM Check for NSSM in local directory first, then C:\nssm
if exist "%ROOT_DIR%nssm\win64\nssm.exe" (
    set NSSM_PATH=%ROOT_DIR%nssm\win64\nssm.exe
    echo Using bundled NSSM
) else if exist "C:\nssm\win64\nssm.exe" (
    set NSSM_PATH=C:\nssm\win64\nssm.exe
    echo Using system NSSM from C:\nssm
) else (
    echo [ERROR] NSSM not found!
    echo.
    echo NSSM should be included in this package at: nssm\win64\nssm.exe
    echo If missing, download from: https://nssm.cc/download
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
    echo Download from: https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo [1/5] Node.js found
for /f "tokens=*" %%i in ('where node') do set NODE_PATH=%%i
echo       Location: %NODE_PATH%
echo.

REM Check if server.js exists
if not exist "%ROOT_DIR%src\server.js" (
    echo [ERROR] server.js not found at: %ROOT_DIR%src\server.js
    echo.
    pause
    exit /b 1
)

echo [2/5] Server files found
echo.

REM Install npm dependencies
echo [3/5] Installing dependencies...
cd /d "%ROOT_DIR%"
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
if not exist "%ROOT_DIR%logs" mkdir "%ROOT_DIR%logs"

REM Install service
echo [4/5] Installing Windows Service...
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
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppStdout "%ROOT_DIR%logs\service-output.log"
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppStderr "%ROOT_DIR%logs\service-error.log"
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateFiles 1
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateOnline 1
"%NSSM_PATH%" set "Salto WhatsApp Bridge" AppRotateBytes 10485760

REM Start service
echo [5/5] Starting service...
"%NSSM_PATH%" start "Salto WhatsApp Bridge"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to start service
    echo Check logs in: %ROOT_DIR%logs
    pause
    exit /b 1
)

timeout /t 3 >nul

"%NSSM_PATH%" status "Salto WhatsApp Bridge" | find "SERVICE_RUNNING" >nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ================================================
    echo Installation Complete!
    echo ================================================
    echo.
    echo Service Status: RUNNING
    echo Web Interface: http://localhost:3000
    echo Logs Location: %ROOT_DIR%logs
    echo.
    echo Next Steps:
    echo 1. Open http://localhost:3000 in your browser
    echo 2. Scan the QR code with WhatsApp
    echo 3. Add target groups/contacts
    echo 4. Configure Salto webhook
    echo.
) else (
    echo [WARNING] Service installed but not running
    echo Check logs in: %ROOT_DIR%logs
    echo.
)

pause
BATEOF

# Copy node_modules
echo ""
echo -e "${YELLOW}Step 6: Copying node_modules...${NC}"
cp -r node_modules "$PACKAGE_DIR/"

# Create installation instructions
cat > "$PACKAGE_DIR/INSTALL.txt" << 'EOF'
INSTALLATION INSTRUCTIONS
=========================

Prerequisites:
- Windows Server 2016 or later
- Node.js v18 or higher (download from https://nodejs.org/)

NSSM is included in this package! No separate download needed.

Installation Steps:
1. Extract this ZIP to a permanent location (e.g., C:\salto-whatsapp-bridge)
2. Right-click install-service.bat and select "Run as Administrator"
3. Open your browser to http://localhost:3000
4. Scan the QR code with WhatsApp
5. Add your target groups/contacts
6. Configure Salto Space to send webhooks to: http://YOUR_SERVER_IP:3000/webhook/alarm

The service will now run automatically on startup.

For more information, see README.md
EOF

echo ""
echo -e "${YELLOW}Step 7: Creating ZIP archive...${NC}"
cd dist/package
zip -r ../salto-whatsapp-bridge-v1.0.0-win64.zip salto-whatsapp-bridge/ -q

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Package location: dist/salto-whatsapp-bridge-v1.0.0-win64.zip"
    echo "Package size: $(du -h ../salto-whatsapp-bridge-v1.0.0-win64.zip | cut -f1)"
    echo ""
    echo "Package includes:"
    echo "  ✓ Application files"
    echo "  ✓ NSSM service manager (bundled)"
    echo "  ✓ Service installers"
    echo "  ✓ Documentation"
    echo ""
    echo "To install on Windows:"
    echo "1. Transfer the ZIP file to Windows server"
    echo "2. Extract the ZIP file"
    echo "3. Run install-service.bat as Administrator"
else
    echo -e "${RED}Failed to create ZIP archive${NC}"
    exit 1
fi

cd ../..
