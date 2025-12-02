@echo off
echo ================================================
echo Salto-WhatsApp Bridge
echo ================================================
echo.

cd ..

echo Step 1: Installing dependencies...
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo Step 2: Installing pkg globally...
call npm install -g pkg
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install pkg
    pause
    exit /b 1
)

echo.
echo Step 3: Creating executable with pkg...
if not exist "dist" mkdir dist
call pkg src\server.js --target node18-win-x64 --output dist\salto-whatsapp-bridge.exe

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create executable
    pause
    exit /b 1
)

if not exist "dist\salto-whatsapp-bridge.exe" (
    echo [ERROR] Executable was not created!
    pause
    exit /b 1
)

echo [SUCCESS] Executable created at dist\salto-whatsapp-bridge.exe

echo.
echo Step 4: Checking for Inno Setup...
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe

if not exist "%INNO_PATH%" (
    echo [WARNING] Inno Setup not found at: %INNO_PATH%
    echo.
    echo You have two options:
    echo 1. Install Inno Setup from: https://jrsoftware.org/isdl.php
    echo 2. Continue with ZIP package only (press any key)
    echo.
    pause
    goto :CREATE_ZIP
)

echo.
echo Step 5: Building installer with Inno Setup...
cd installer
"%INNO_PATH%" installer.iss

if %ERRORLEVEL% EQ 0 (
    echo [SUCCESS] Installer created!
    echo Location: installer\output\SaltoWhatsAppBridge-Setup-1.0.0.exe
) else (
    echo [WARNING] Inno Setup failed, will create ZIP package instead
)
cd ..

:CREATE_ZIP
echo.
echo Step 6: Creating ZIP package...
if exist "dist\package" rmdir /s /q dist\package
mkdir dist\package\salto-whatsapp-bridge

set PKG=dist\package\salto-whatsapp-bridge

echo   - Copying files...
copy dist\salto-whatsapp-bridge.exe "%PKG%\" >nul
copy src\server.js "%PKG%\" >nul
xcopy /E /I /Y /Q src\public "%PKG%\public" >nul
copy package.json "%PKG%\" >nul
xcopy /E /I /Y /Q node_modules "%PKG%\node_modules" >nul

REM Copy service scripts
copy installer\install-service.bat "%PKG%\" >nul 2>&1
copy installer\install-service-script.js "%PKG%\" >nul 2>&1
copy installer\uninstall-service.bat "%PKG%\" >nul 2>&1
copy installer\uninstall-service-script.js "%PKG%\" >nul 2>&1

REM Create .env.example
(
echo PORT=3000
echo WHATSAPP_TARGETS=
) > "%PKG%\.env.example"

REM Create INSTALL.txt
(
echo INSTALLATION INSTRUCTIONS
echo =========================
echo.
echo Prerequisites:
echo - Windows Server 2016 or later
echo - Node.js v18 or higher from https://nodejs.org/
echo.
echo Installation:
echo 1. Right-click install-service.bat and "Run as Administrator"
echo 2. Open http://localhost:3000 in your browser
echo 3. Scan QR code with WhatsApp
echo 4. Add target groups/contacts
echo 5. Configure Salto: http://YOUR_IP:3000/webhook/alarm
) > "%PKG%\INSTALL.txt"

REM Create README
if exist installer\README.md (
    copy installer\README.md "%PKG%\" >nul
) else (
    echo # Salto-WhatsApp Bridge > "%PKG%\README.md"
    echo See INSTALL.txt for instructions >> "%PKG%\README.md"
)

echo   - Creating ZIP archive...
cd dist\package
powershell -Command "Compress-Archive -Path salto-whatsapp-bridge -DestinationPath ..\salto-whatsapp-bridge-v1.0.0-win64.zip -Force"

if %ERRORLEVEL% EQ 0 (
    echo [SUCCESS] ZIP package created!
) else (
    echo [ERROR] Failed to create ZIP
    cd ..\..
    pause
    exit /b 1
)

cd ..\..

echo.
echo ================================================
echo Build Complete!
echo ================================================
echo.

if exist "installer\output\SaltoWhatsAppBridge-Setup-1.0.0.exe" (
    echo [1] EXE Installer: installer\output\SaltoWhatsAppBridge-Setup-1.0.0.exe
)

if exist "dist\salto-whatsapp-bridge-v1.0.0-win64.zip" (
    echo [2] ZIP Package:   dist\salto-whatsapp-bridge-v1.0.0-win64.zip
)

echo.
echo Distribution options:
echo - Use the .exe installer for easy installation
echo - Use the .zip package for manual deployment
echo.
pause
