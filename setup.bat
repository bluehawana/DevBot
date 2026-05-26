@echo off
setlocal enabledelayedexpansion
title DevBot Setup

echo ============================================================
echo   DevBot - AI Developer Assistant Setup
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
:: Step 3: Check .env exists (pre-configured from OneDrive)
:: -----------------------------------------------------------
set "ENV_FILE=%~dp0.env"

if exist "!ENV_FILE!" (
    echo [OK] Configuration found.
    echo.
    :: Check if PAT is already set
    findstr /C:"AZURE_DEVOPS_PAT=" "!ENV_FILE!" >nul 2>&1
    if %errorlevel% equ 0 (
        set /p REUSE="Existing config with PAT found. Use it? (Y/n): "
        if /i "!REUSE!" neq "n" goto :run
    ) else (
        echo   .env found but no PAT yet. You need to add your personal token.
        goto :addpat
    )
)

if not exist "!ENV_FILE!" (
    echo.
    echo [ERROR] .env not found in this folder.
    echo.
    echo   Download from OneDrive (open in browser - requires corporate login):
    echo   Save as ".env" in this folder, then run setup.bat again.
    echo.
    echo   The .env file contains Ollama server URLs and model config.
    echo   You will then be prompted for your personal Azure DevOps PAT.
    echo.
    pause
    exit /b 1
)

:: -----------------------------------------------------------
:: Step 4: Add personal PAT to .env
:: -----------------------------------------------------------
:addpat

echo.
echo -----------------------------------------------------------
echo   Add your Azure DevOps PAT
echo -----------------------------------------------------------
echo.
echo   HOW TO CREATE:
echo     a) Go to your Azure DevOps org settings: _usersSettings/tokens
echo     b) Click "New Token"
echo     c) Name: DevBot
echo     d) Expiration: 90 days
echo     e) Scopes:
echo          Code:                 Read
echo          Pull Request Threads: Read ^& Write
echo     f) Click "Create" and COPY immediately
echo.

set /p ADO_PAT="Azure DevOps PAT: "
if "!ADO_PAT!"=="" (
    echo [ERROR] PAT is required.
    pause
    exit /b 1
)

:: Append PAT to .env
echo AZURE_DEVOPS_PAT=!ADO_PAT!>> "!ENV_FILE!"
echo.
echo [OK] PAT saved to .env (local only, never shared).

:: -----------------------------------------------------------
:: Step 5: Run the container
:: -----------------------------------------------------------
:run

echo.
echo ============================================================
echo   Starting DevBot...
echo ============================================================

:: Stop existing container
docker stop devbot >nul 2>&1
docker rm devbot >nul 2>&1

:: Run with env file
docker run -d --name devbot ^
    -p 3978:3978 ^
    --memory 512m ^
    --cpus 2 ^
    --restart unless-stopped ^
    --env-file "%~dp0.env" ^
    hongzhili40526/devbot:latest

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
