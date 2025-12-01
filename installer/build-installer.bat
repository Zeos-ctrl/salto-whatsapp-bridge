@echo off
echo Building Salto-WhatsApp Bridge Installer...
echo.

cd ..

echo Step 1: Installing dependencies...
call npm install

echo.
echo Step 2: Creating executable with pkg...
if not exist "dist" mkdir dist
call pkg src\server.js --target node18-win-x64 --output dist\salto-whatsapp-bridge.exe

echo.
echo Step 3: Building installer with Inno Setup...
cd installer
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

echo.
echo Build complete! Installer is in installer\output folder.
pause
