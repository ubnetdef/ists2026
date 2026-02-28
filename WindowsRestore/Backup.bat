@echo off
REM Automated Windows Restore Point Creator
REM Run as Administrator for proper functionality

setlocal enabledelayedexpansion

REM Check if running as administrator
openfiles >nul 2>&1
if errorlevel 1 (
    echo This script requires Administrator privileges.
    echo Please run Command Prompt as Administrator and try again.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Windows Restore Point Creator
echo ========================================
echo.

REM Get current timestamp for unique restore point name
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

set "RestorePointName=AutoRestore_%mydate%_%mytime%"

echo Creating restore point: %RestorePointName%
echo.

REM Create restore point using PowerShell
powershell -NoProfile -Command "Checkpoint-Computer -Description '%RestorePointName%' -RestorePointType 'MODIFY_SETTINGS'" 2>nul

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Restore point created successfully!
    echo Name: %RestorePointName%
    echo.
) else (
    echo.
    echo [ERROR] Failed to create restore point.
    echo Make sure System Restore is enabled on your system.
    echo.
    pause
    exit /b 1
)

echo Press any key to exit...
pause >nul
exit /b 0
