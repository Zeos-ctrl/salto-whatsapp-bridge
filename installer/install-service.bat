@echo off
echo Installing Salto-WhatsApp Bridge as Windows Service...
npm install -g node-windows
node "%~dp0install-service-script.js"
echo.
echo Service installation complete!
pause
