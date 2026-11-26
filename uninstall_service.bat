@echo off
title Uninstall NetScope Windows Service
echo ============================================================
echo NetScope - Windows Service Removal
echo ============================================================
echo.

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

echo [1/2] Stopping NetScopeService...
sc.exe stop NetScopeService >nul 2>&1
taskkill /F /IM NetScopeService.exe >nul 2>&1

echo [2/2] Removing NetScopeService from services.msc...
if exist "%EXE_PATH%" (
    "%EXE_PATH%" remove >nul 2>&1
)
sc.exe delete NetScopeService >nul 2>&1

echo.
echo ============================================================
echo SUCCESS! NetScope Service has been removed from services.msc.
echo ============================================================
pause
