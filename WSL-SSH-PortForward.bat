@echo off
chcp 65001 > nul 2>&1
setlocal EnableDelayedExpansion

:: ==============================================
:: WSL SSH Port Forward + Keep-Alive Script
:: ==============================================

:: Default configuration
set "CONFIG_FILE=%~dp0wsl-ssh-config.ini"
set "WSL_DISTRO="
set "WSL_IP="
set "LISTEN_PORT=2222"
set "CONNECT_PORT=22"
set "LISTEN_ADDRESS=0.0.0.0"
set "ZEROTIER_IP="
set "CHECK_INTERVAL=2"

:: Show title first
title WSL SSH Port Forward
cls
echo ==============================================
echo WSL SSH Port Forward + Keep-Alive
echo ==============================================
echo.

:: Check admin first - CRITICAL
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrator privileges required
    echo.
    echo This script needs admin rights to:
    echo - Create port forwarding rules
    echo - Configure Windows Firewall
    echo.
    echo How to fix:
    echo 1. Close this window
    echo 2. Right-click WSL-SSH-PortForward.bat
    echo 3. Select "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Parse arguments
:PARSE_ARGS
if "%~1"=="" goto ARGS_DONE
if /i "%~1"=="-h" goto SHOW_HELP
if /i "%~1"=="--help" goto SHOW_HELP
if /i "%~1"=="-d" set "WSL_DISTRO=%~2" & shift & shift & goto PARSE_ARGS
if /i "%~1"=="-p" set "LISTEN_PORT=%~2" & shift & shift & goto PARSE_ARGS
if /i "%~1"=="-z" set "ZEROTIER_IP=%~2" & shift & shift & goto PARSE_ARGS
shift
goto PARSE_ARGS
:ARGS_DONE

:: Load config file
if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
        set "key=%%a"
        set "val=%%b"
        for /f "tokens=*" %%k in ("!key!") do set "key=%%k"
        for /f "tokens=*" %%v in ("!val!") do set "val=%%v"
        if /i "!key!"=="WSL_DISTRO" set "WSL_DISTRO=!val!"
        if /i "!key!"=="WSL_IP" set "WSL_IP=!val!"
        if /i "!key!"=="LISTEN_PORT" set "LISTEN_PORT=!val!"
        if /i "!key!"=="ZEROTIER_IP" set "ZEROTIER_IP=!val!"
    )
)

:: Detect WSL distro using PowerShell (avoid encoding issues)
if "%WSL_DISTRO%"=="" (
    for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "(wsl -l -q)[0].Trim()" 2^>nul`) do (
        set "WSL_DISTRO=%%i"
    )
)

if "%WSL_DISTRO%"=="" (
    echo [ERROR] No WSL distro found
    echo.
    echo Please install WSL first:
    echo   wsl --install
    echo.
    echo Then restart this script.
    echo.
    pause
    exit /b 1
)

echo ==============================================
echo Configuration
echo ==============================================
echo WSL Distro: %WSL_DISTRO%
echo.

:: Check WSL running
wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Starting WSL...
    wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: Auto-get WSL IP using PowerShell (avoid encoding issues)
if "%WSL_IP%"=="" (
    echo [INFO] Detecting WSL IP addresses...
    echo.

    set /a IP_COUNT=0
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(wsl -d '%WSL_DISTRO%' hostname -I).Trim() -split '\s+'" 2^>nul`) do (
        set /a IP_COUNT+=1
        set "IP_!IP_COUNT!=%%i"
    )

    if !IP_COUNT! equ 0 (
        echo [ERROR] Failed to detect any IP
        pause
        exit /b 1
    )

    echo Available IPs for %WSL_DISTRO%:
    for /l %%n in (1,1,!IP_COUNT!) do (
        echo   %%n. !IP_%%n!
    )

    if !IP_COUNT! equ 1 (
        set "WSL_IP=!IP_1!"
        echo.
        echo [OK] Auto-selected: !WSL_IP!
    ) else (
        echo.
        echo Multiple IPs found. Please select the correct one:
        echo   - Usually the 172.x.x.x or 192.168.x.x for local network
        set /p IP_SELECT="Enter number (1-!IP_COUNT!): "
        set "WSL_IP=!IP_%IP_SELECT%!"
    )
    echo.
)

if "%WSL_IP%"=="" (
    echo [ERROR] Failed to auto-detect WSL IP
    echo.
    echo Please manually set WSL_IP in: %CONFIG_FILE%
    echo   WSL_IP=172.28.xxx.xxx
    echo.
    echo Or check WSL status: wsl -d %WSL_DISTRO% hostname -I
    pause
    exit /b 1
)

echo [OK] WSL IP: %WSL_IP%

:: Auto-get ZeroTier IP if not configured
if "%ZEROTIER_IP%"=="" (
    echo [INFO] Auto-detecting ZeroTier IP...
    for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "zerotier"') do (
        for /f "tokens=*" %%j in ("%%i") do (
            set "ZEROTIER_IP=%%j"
            set "ZEROTIER_IP=!ZEROTIER_IP: =!"
            goto :ZEROTIER_FOUND
        )
    )
)
:ZEROTIER_FOUND

:: Delete old rules
netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% >nul 2>&1

:: Create port forward
netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Failed to create port forward
    echo.
    echo Common causes:
    echo - Port %LISTEN_PORT% already in use
    echo - Invalid IP address: %WSL_IP%
    echo.
    echo Check existing rules:
    echo   netsh interface portproxy show all
    echo.
    pause
    exit /b 1
)

echo [OK] Port forward: %LISTEN_ADDRESS%:%LISTEN_PORT% -^> %WSL_IP%:%CONNECT_PORT%

:: Firewall
netsh advfirewall firewall add rule name="WSL SSH %LISTEN_PORT%" dir=in action=allow protocol=TCP localport=%LISTEN_PORT% >nul 2>&1
echo [OK] Firewall rule added

:: Show info
echo ==============================================
echo Connection Info
echo ==============================================
if not "%ZEROTIER_IP%"=="" (
    echo ZeroTier: ssh user@%ZEROTIER_IP% -p %LISTEN_PORT%
)
echo Local:    ssh user@^<Windows-IP^> -p %LISTEN_PORT%
echo.
echo [Keep-Alive] Running... Close window to stop
echo ==============================================

:: Keep-alive loop
:LOOP
timeout /t %CHECK_INTERVAL% /nobreak >nul
netstat -ano | findstr ":%LISTEN_PORT%" >nul 2>&1
if %errorLevel% neq 0 (
    echo [%date% %time%] Port lost, rebuilding...
    netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% >nul 2>&1
    netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% >nul 2>&1
    echo [%date% %time%] Rebuilt
)
goto LOOP

:SHOW_HELP
echo Usage: %~nx0 [-d distro] [-p port] [-z zerotier_ip]
echo.
echo Options:
echo   -d    WSL distro name (default: auto-detect)
echo   -p    Listen port (default: 2222)
echo   -z    ZeroTier IP address
echo.
echo Example:
echo   %~nx0 -d Ubuntu-22.04 -p 2222 -z 10.0.0.1
echo.
pause
exit /b 0
