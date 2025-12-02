@echo off
echo ================================================
echo Salto-WhatsApp Bridge - Service Uninstallation
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

set NSSM_PATH=C:\nssm\win64\nssm.exe

REM Check if NSSM is installed
if not exist "%NSSM_PATH%" (
    echo [ERROR] NSSM not found at: %NSSM_PATH%
    echo.
    echo The service may have been installed with NSSM.
    echo If NSSM is not available, you can remove the service manually:
    echo   sc delete "Salto WhatsApp Bridge"
    echo.
    pause
    exit /b 1
)

REM Check if service exists
sc query "Salto WhatsApp Bridge" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Service "Salto WhatsApp Bridge" is not installed.
    echo Nothing to uninstall.
    echo.
    pause
    exit /b 0
)

echo Are you sure you want to uninstall Salto WhatsApp Bridge? (Y/N)
choice /C YN /N
if errorlevel 2 (
    echo Uninstallation cancelled.
    pause
    exit /b 0
)

echo.
echo [1/3] Stopping service...
"%NSSM_PATH%" stop "Salto WhatsApp Bridge"

REM Wait for service to stop
timeout /t 3 >nul

echo [2/3] Removing service...
"%NSSM_PATH%" remove "Salto WhatsApp Bridge" confirm

if %ERRORLEVEL% EQ 0 (
    echo [3/3] Cleaning up...
    
    REM Note: We don't delete logs or whatsapp-session automatically
    REM in case the user wants to keep them
    
    echo.
    echo ================================================
    echo Uninstallation Complete!
    echo ================================================
    echo.
    echo The service has been removed.
    echo.
    echo Note: The following were kept:
    echo - Application files
    echo - WhatsApp session data
    echo - Log files
    echo.
    echo To completely remove everything:
    echo 1. Delete the application folder
    echo 2. Remove C:\nssm (if no longer needed)
    echo.
) else (
    echo.
    echo [ERROR] Failed to remove service
    echo You can try manually: sc delete "Salto WhatsApp Bridge"
    echo.
)

pause
