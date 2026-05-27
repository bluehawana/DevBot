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
:: Step 2: Pull latest image from Docker Hub (always pull fresh)
:: -----------------------------------------------------------
echo.
echo [INFO] Cleaning up old images and containers...
docker stop devbot >nul 2>&1
docker rm -f devbot >nul 2>&1
docker rmi -f hongzhili40526/devbot:latest >nul 2>&1
docker image prune -f >nul 2>&1
echo [INFO] Pulling fresh image from Docker Hub...
docker pull hongzhili40526/devbot:latest
if %errorlevel% neq 0 (
    echo [ERROR] Pull failed. Check your internet connection.
    pause
    exit /b 1
)
echo [OK] DevBot image ready (latest version).

:: -----------------------------------------------------------
:: Step 3: Check .env exists
:: -----------------------------------------------------------
set "ENV_FILE=%~dp0.env"

if not exist "!ENV_FILE!" (
    echo.
    echo [ERROR] .env not found in this folder.
    echo.
    echo   Create a file called .env in this folder.
    echo   Copy the content from the Teams chat and paste it.
    echo   Save as UTF-8 in Notepad.
    echo.
    echo   The .env file contains Ollama server URLs and model config.
    echo   You will then be prompted for your personal Azure DevOps PAT.
    echo.
    pause
    exit /b 1
)
echo [OK] Configuration found.

:: -----------------------------------------------------------
:: Step 4: Check PAT in .env or prompt for it
:: -----------------------------------------------------------
findstr /C:"AZURE_DEVOPS_PAT=" "!ENV_FILE!" >nul 2>&1
if %errorlevel% equ 0 (
    set /p REUSE="Existing config with PAT found. Use it? (Y/n): "
    if /i "!REUSE!" neq "n" goto :run
)

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
ping -n 6 127.0.0.1 >nul 2>nul

:: Check health endpoint
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3978/health' -UseBasicParsing -TimeoutSec 5; if ($r.Content -match 'healthy') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Health check passed - DevBot is responding.
) else (
    echo [WARN] Health check inconclusive - app may still be starting.
    echo        Try opening http://localhost:3978/ in your browser.
)

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
