@echo off
chcp 65001 > nul 2>&1
setlocal EnableDelayedExpansion

:: ==============================================
:: WSL SSH Port Forward + Keep-Alive
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
set "RESTART_SSH=1"

:: Parse arguments
:PARSE_ARGS
if "%~1"=="" goto :ARGS_DONE
if /i "%~1"=="-h" goto :SHOW_HELP
if /i "%~1"=="--help" goto :SHOW_HELP
if /i "%~1"=="-d" set "WSL_DISTRO=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-p" set "LISTEN_PORT=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-z" set "ZEROTIER_IP=%~2" & shift & shift & goto :PARSE_ARGS
shift
goto :PARSE_ARGS
:ARGS_DONE

:: Check admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Please run as Administrator
    echo Right-click the batch file and select "Run as administrator"
    pause
    exit /b 1
)

:: Load config
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

:: Detect WSL distro if not set
if "%WSL_DISTRO%"=="" (
    for /f "tokens=1" %%i in ('wsl -l -q 2^>nul') do (
        set "WSL_DISTRO=%%i"
        goto :FOUND_DISTRO
    )
)
:FOUND_DISTRO

if "%WSL_DISTRO%"=="" (
    echo [ERROR] No WSL distro found
    echo Please install WSL: wsl --install
    pause
    exit /b 1
)

echo ==============================================
echo WSL SSH Port Forward
echo ==============================================
echo Distro: %WSL_DISTRO%
echo.

:: Check WSL running
wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Starting WSL...
    wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: Get WSL IP
if "%WSL_IP%"=="" (
    for /f "tokens=1" %%i in ('wsl -d "%WSL_DISTRO%" hostname -I 2^>nul') do (
        set "WSL_IP=%%i"
    )
)

if "%WSL_IP%"=="" (
    echo [ERROR] Failed to get WSL IP
    echo Please check: wsl -d %WSL_DISTRO% hostname -I
    echo Or set WSL_IP manually in %CONFIG_FILE%
    pause
    exit /b 1
)

echo [OK] WSL IP: %WSL_IP%

:: Delete old rules
netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% >nul 2>&1

:: Create port forward
netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Failed to create port forward
    echo Check: netsh interface portproxy show all
    pause
    exit /b 1
)

echo [OK] Port forward: %LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%

:: Firewall
netsh advfirewall firewall add rule name="WSL SSH %LISTEN_PORT%" dir=in action=allow protocol=TCP localport=%LISTEN_PORT% >nul 2>&1
echo [OK] Firewall rule added

:: Show info
echo ==============================================
echo Connection info:
echo ==============================================
if not "%ZEROTIER_IP%"=="" (
    echo ZeroTier: ssh xingzhan@%ZEROTIER_IP% -p %LISTEN_PORT%
)
echo Local:    ssh xingzhan@<Windows-IP> -p %LISTEN_PORT%
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
goto :LOOP

:SHOW_HELP
echo Usage: %~nx0 [-d distro] [-p port] [-z zerotier_ip]
echo.
echo Options:
echo   -d    WSL distro name (default: auto-detect)
echo   -p    Listen port (default: 2222)
echo   -z    ZeroTier IP for display
echo.
pause
exit /b 0
