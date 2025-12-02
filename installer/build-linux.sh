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
echo -e "${YELLOW}Step 3: Creating Windows executable with pkg...${NC}"
mkdir -p dist
pkg src/server.js --target node18-win-x64 --output dist/salto-whatsapp-bridge.exe

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create executable${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 4: Creating package directory...${NC}"
rm -rf dist/package
mkdir -p dist/package/salto-whatsapp-bridge
PACKAGE_DIR="dist/package/salto-whatsapp-bridge"

# Copy necessary files
echo "  - Copying executable..."
cp dist/salto-whatsapp-bridge.exe "$PACKAGE_DIR/"

echo "  - Copying public directory..."
cp -r src/public "$PACKAGE_DIR/"

echo "  - Copying package files..."
cp package.json "$PACKAGE_DIR/"

# Copy .env.example (check if it exists first)
if [ -f ".env.example" ]; then
    cp .env.example "$PACKAGE_DIR/"
else
    echo -e "${YELLOW}Warning: .env.example not found, creating default${NC}"
    cat > "$PACKAGE_DIR/.env.example" << 'ENVEOF'
PORT=3000
WHATSAPP_TARGETS=
ENVEOF
fi

# Copy installer files (check if they exist)
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

# Copy service installation scripts
echo "  - Copying service scripts..."
cp installer/install-service.bat "$PACKAGE_DIR/" 2>/dev/null || echo "    Warning: install-service.bat not found"
cp installer/install-service-script.js "$PACKAGE_DIR/" 2>/dev/null || echo "    Warning: install-service-script.js not found"
cp installer/uninstall-service.bat "$PACKAGE_DIR/" 2>/dev/null || echo "    Warning: uninstall-service.bat not found"
cp installer/uninstall-service-script.js "$PACKAGE_DIR/" 2>/dev/null || echo "    Warning: uninstall-service-script.js not found"

# Copy node_modules (needed for dependencies)
echo ""
echo -e "${YELLOW}Step 5: Copying node_modules...${NC}"
cp -r node_modules "$PACKAGE_DIR/"

# Create installation instructions
cat > "$PACKAGE_DIR/INSTALL.txt" << 'EOF'
INSTALLATION INSTRUCTIONS
=========================

Prerequisites:
- Windows Server 2016 or later
- Node.js v18 or higher (download from https://nodejs.org/)

Installation Steps:
1. Extract this ZIP file to a permanent location (e.g., C:\salto-whatsapp-bridge)
2. Right-click install-service.bat and select "Run as Administrator"
3. Open your browser to http://localhost:3000
4. Scan the QR code with WhatsApp
5. Add your target groups/contacts
6. Configure Salto Space to send webhooks to: http://YOUR_SERVER_IP:3000/webhook/alarm

The service will now run automatically on startup.

Manual Start (without service):
1. Open Command Prompt in this directory
2. Run: node salto-whatsapp-bridge.exe

Uninstall:
Right-click uninstall-service.bat and select "Run as Administrator"

For more information, see README.md
EOF

echo ""
echo -e "${YELLOW}Step 6: Creating ZIP archive...${NC}"
cd dist/package
zip -r ../salto-whatsapp-bridge-v1.0.0-win64.zip salto-whatsapp-bridge/

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Build successful!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Package location: dist/salto-whatsapp-bridge-v1.0.0-win64.zip"
    echo "Package size: $(du -h ../salto-whatsapp-bridge-v1.0.0-win64.zip | cut -f1)"
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
