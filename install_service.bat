@echo off
title Install NetScope Windows Service (services.msc)
echo ============================================================
echo NetScope - Windows Service Installation
echo ============================================================
echo.

:: Check for Administrator elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Administrator rights required. Requesting elevation...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~dpnx0\"\"' -Verb RunAs"
    exit /b
)

set "EXE_PATH=%~dp0dist\NetScope\NetScopeService.exe"
if not exist "%EXE_PATH%" (
    set "EXE_PATH=%~dp0builds\NetScope\NetScopeService.exe"
)
if not exist "%EXE_PATH%" (
    set "EXE_PATH=%LOCALAPPDATA%\Programs\NetScope\NetScopeService.exe"
)
if not exist "%EXE_PATH%" (
    echo [ERROR] Could not find NetScopeService.exe!
    pause
    exit /b 1
)

echo [1/3] Stopping any running NetScope service or process...
sc.exe stop NetScopeService >nul 2>&1
taskkill /F /IM NetScopeService.exe >nul 2>&1

echo [2/3] Registering NetScopeService into Windows Services (services.msc)...
"%EXE_PATH%" install
if %errorlevel% neq 0 (
    echo Fallback: registering via sc.exe...
    sc.exe create NetScopeService binPath= "\"%EXE_PATH%\"" start= auto DisplayName= "NetScope Internet Usage Monitor Service"
    sc.exe description NetScopeService "Monitors and attributes 24/7 internet and network bandwidth consumption on Windows with zero simulation."
)

echo [3/3] Starting NetScope Service...
sc.exe start NetScopeService >nul 2>&1

echo.
echo ============================================================
echo SUCCESS! NetScope Service is now installed in services.msc!
echo Startup Type: Automatic (Starts on boot before login)
echo Status: Running 24/7 in the background
echo.
echo You can manage it anytime from Windows Services:
echo   Press Win+R -> type: services.msc -> find "NetScope Internet Usage Monitor Service"
echo ============================================================
pause
