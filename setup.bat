@echo off
setlocal enabledelayedexpansion
title DevBot Configuration

echo ============================================================
echo   DevBot - Developer Setup
echo ============================================================
echo.

:: -----------------------------------------------------------
:: Step 1: Check Docker is running
:: -----------------------------------------------------------
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not running.
    echo         Start Docker Desktop, then run this script again.
    echo.
    pause
    exit /b 1
)
echo [OK] Docker is running.

:: -----------------------------------------------------------
:: Step 2: Pull image from Docker Hub (no login needed)
:: -----------------------------------------------------------
docker image inspect hongzhili40526/devbot:latest >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [INFO] Pulling DevBot image from Docker Hub...
    docker pull hongzhili40526/devbot:latest
    if %errorlevel% neq 0 (
        echo [ERROR] Pull failed. Check your internet connection.
        pause
        exit /b 1
    )
)
echo [OK] DevBot image found.

:: -----------------------------------------------------------
:: Step 3: Load existing config or prompt for new
:: -----------------------------------------------------------
set "ENV_FILE=%~dp0.env"

if exist "!ENV_FILE!" (
    echo.
    echo Found existing config: !ENV_FILE!
    set /p REUSE="Use existing config? (Y/n): "
    if /i "!REUSE!" neq "n" goto :run
)

echo.
echo -----------------------------------------------------------
echo   Enter your credentials
echo -----------------------------------------------------------
echo.
echo   You need:
echo     1. Azure DevOps PAT (Personal Access Token)
echo.
echo        HOW TO CREATE:
echo        a) Go to: https://dev.azure.com/VolvoGroup-CPA-SWnD/_usersSettings/tokens
echo        b) Click "New Token"
echo        c) Name: DevBot (or anything you like)
echo        d) Expiration: 90 days (or custom)
echo        e) Scopes - select ONLY these:
echo             Code:                 Read
echo             Pull Request Threads: Read ^& Write
echo        f) Click "Create" and COPY the token immediately
echo           (you cannot see it again!)
echo.
echo     2. Azure DevOps Org URL (org only, NOT project!)
echo        Example: https://dev.azure.com/VolvoGroup-CPA-SWnD
echo.
echo     3. Ollama server URL
echo        Default: http://10.222.19.229:11434
echo.

set /p ADO_PAT="Azure DevOps PAT: "
if "!ADO_PAT!"=="" (
    echo [ERROR] PAT is required.
    pause
    exit /b 1
)

set /p ADO_ORG="Azure DevOps Org URL (Enter for default): "
if "!ADO_ORG!"=="" set ADO_ORG=https://dev.azure.com/VolvoGroup-CPA-SWnD

set /p OLLAMA_URL="Ollama server URL (Enter for default): "
if "!OLLAMA_URL!"=="" set OLLAMA_URL=http://10.222.19.229:11434

set /p ADO_PROJECT="Azure DevOps Project (optional, Enter to skip): "

:: Write .env file
echo AZURE_DEVOPS_PAT=!ADO_PAT!> "!ENV_FILE!"
echo AZURE_DEVOPS_ORG_URL=!ADO_ORG!>> "!ENV_FILE!"
echo OLLAMA_PRIMARY_URL=!OLLAMA_URL!>> "!ENV_FILE!"
if not "!ADO_PROJECT!"=="" (
    echo AZURE_DEVOPS_PROJECT=!ADO_PROJECT!>> "!ENV_FILE!"
)
echo.
echo [OK] Config saved to !ENV_FILE!
echo     (This file is git-ignored and stays on your machine only.)

:: -----------------------------------------------------------
:: Step 4: Run the container
:: -----------------------------------------------------------
:run

echo.
echo ============================================================
echo   Starting DevBot...
echo ============================================================

:: Stop existing container
docker stop devbot >nul 2>&1
docker rm devbot >nul 2>&1

:: Determine which image name to use
set IMAGE=hongzhili40526/devbot:latest

:: Run with env file
docker run -d --name devbot ^
    -p 3978:3978 ^
    --memory 512m ^
    --cpus 2 ^
    --restart unless-stopped ^
    --env-file "%~dp0.env" ^
    %IMAGE%

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Failed to start container. Check docker logs.
    pause
    exit /b 1
)

:: Wait and check health
echo Waiting for DevBot...
timeout /t 4 /nobreak >nul

echo.
echo ============================================================
echo   DevBot is running!
echo.
echo   Web chat:     http://localhost:3978/
echo   Health check: http://localhost:3978/health
echo.
echo   View logs:    docker logs -f devbot
echo   Stop:         docker stop devbot
echo   Restart:      docker start devbot
echo   Re-configure: run this script again
echo ============================================================
echo.
pause
