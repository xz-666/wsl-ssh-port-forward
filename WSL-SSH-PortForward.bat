@echo off
chcp 65001 > nul 2>&1
setlocal EnableDelayedExpansion

:: ==============================================
:: WSL SSH Port Forwarding + Keep-Alive Script
:: https://github.com/xingzhan/wsl-ssh-port-forward
:: ==============================================

:: Default configuration (can be overridden by config file or command line)
set "DEFAULT_CONFIG_FILE=%~dp0wsl-ssh-config.ini"
set "WSL_DISTRO="
set "LISTEN_PORT=2222"
set "CONNECT_PORT=22"
set "LISTEN_ADDRESS=0.0.0.0"
set "USE_ZEROTIER=0"
set "ZEROTIER_IP="
set "LOG_FILE=%~dp0wsl-ssh-portforward.log"
set "CHECK_INTERVAL=2"
set "RESTART_SSH=1"
set "SHOW_HELP=0"

:: ==============================================
:: Step 1: Parse Command Line Arguments
:: ==============================================
:PARSE_ARGS
if "%~1"=="" goto :ARGS_DONE
if /i "%~1"=="-h" set "SHOW_HELP=1" & goto :ARGS_DONE
if /i "%~1"=="--help" set "SHOW_HELP=1" & goto :ARGS_DONE
if /i "%~1"=="-d" set "WSL_DISTRO=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--distro" set "WSL_DISTRO=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-p" set "LISTEN_PORT=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--port" set "LISTEN_PORT=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-c" set "CONNECT_PORT=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--connect-port" set "CONNECT_PORT=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-z" set "USE_ZEROTIER=1" & set "ZEROTIER_IP=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--zerotier" set "USE_ZEROTIER=1" & set "ZEROTIER_IP=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-f" set "DEFAULT_CONFIG_FILE=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--config" set "DEFAULT_CONFIG_FILE=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-l" set "LOG_FILE=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--log" set "LOG_FILE=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="-i" set "CHECK_INTERVAL=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--interval" set "CHECK_INTERVAL=%~2" & shift & shift & goto :PARSE_ARGS
if /i "%~1"=="--no-ssh-restart" set "RESTART_SSH=0" & shift & goto :PARSE_ARGS
echo Unknown parameter: %~1
shift
goto :PARSE_ARGS
:ARGS_DONE

:: ==============================================
:: Show Help Information
:: ==============================================
if "%SHOW_HELP%"=="1" (
    echo ==============================================
    echo WSL SSH Port Forwarding Script
    echo ==============================================
    echo.
    echo Usage: %~nx0 [options]
    echo.
    echo Options:
    echo   -h, --help              Show this help message
    echo   -d, --distro ^<name^>     Specify WSL distro ^(auto-detect if not set^)
    echo   -p, --port ^<port^>       Listen port ^(default: 2222^)
    echo   -c, --connect-port ^<port^>  Connect port ^(default: 22^)
    echo   -z, --zerotier ^<IP^>    Enable ZeroTier IP display
    echo   -f, --config ^<file^>     Specify config file path
    echo   -l, --log ^<file^>        Specify log file path
    echo   -i, --interval ^<seconds^>  Check interval ^(default: 2^)
    echo   --no-ssh-restart        Don't restart SSH service in WSL
    echo.
    echo Examples:
    echo   %~nx0                           Use default configuration
    echo   %~nx0 -d Ubuntu-22.04           Specify distro
    echo   %~nx0 -p 2222 -c 22             Specify port mapping
    echo   %~nx0 -z YOUR_ZEROTIER_IP       Enable ZeroTier IP display
    echo   %~nx0 -f myconfig.ini           Use custom config file
    echo.
    pause
    exit /b 0
)

:: ==============================================
:: Step 2: Load Configuration File (if exists)
:: ==============================================
if exist "%DEFAULT_CONFIG_FILE%" (
    call :LOAD_CONFIG "%DEFAULT_CONFIG_FILE%"
)

:: ==============================================
:: Step 3: Set Window Title and Display Info
:: ==============================================
title WSL SSH Port Forward - Port %LISTEN_PORT%-^>%CONNECT_PORT%
cls
echo ==============================================
echo      WSL SSH Port Forward + Keep-Alive
echo              [Generic Version]
echo ==============================================
echo Config: %DEFAULT_CONFIG_FILE%
echo Log:    %LOG_FILE%
echo ==============================================
echo.

:: ==============================================
:: Step 4: Check Administrator Privileges
:: ==============================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [Error] Please run as Administrator!
    call :LOG "ERROR" "Script not run as administrator"
    pause
    exit /b 1
)

:: ==============================================
:: Step 5: Detect/Validate WSL Distro
:: ==============================================
call :LOG "INFO" "Starting WSL SSH port forwarding script"

if "%WSL_DISTRO%"=="" (
    echo [Detect] Finding available WSL distro...
    call :DETECT_WSL_DISTRO
    if "!WSL_DISTRO!"=="" (
        echo [Error] No WSL distro found!
        call :LOG "ERROR" "No WSL distro found"
        pause
        exit /b 1
    )
    echo [Detect] Auto-selected: !WSL_DISTRO!
    call :LOG "INFO" "Auto-detected WSL distro: !WSL_DISTRO!"
) else (
    wsl -l -q 2>nul | findstr /i /x "%WSL_DISTRO%" >nul 2>&1
    if %errorLevel% neq 0 (
        echo [Error] WSL distro '%WSL_DISTRO%' not found!
        echo [Available distros]
        wsl -l -q 2>nul
        call :LOG "ERROR" "Specified WSL distro not found: %WSL_DISTRO%"
        pause
        exit /b 1
    )
    echo [Config] Using: %WSL_DISTRO%
    call :LOG "INFO" "Using specified WSL distro: %WSL_DISTRO%"
)

:: ==============================================
:: Step 6: Check if WSL is Running
:: ==============================================
echo [Check] Checking WSL status...
wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
if %errorLevel% neq 0 (
    echo [Start] WSL not running, starting...
    call :LOG "INFO" "Starting WSL distro: %WSL_DISTRO%"
    wsl -d "%WSL_DISTRO%" -e echo "WSL started" >nul 2>&1
    timeout /t 3 /nobreak >nul
)

:: ==============================================
:: Step 7: Initialize Port Forwarding
:: ==============================================
:INIT_SETUP
echo.
echo ==============================================
echo [Init] Configuring port forwarding...
echo ==============================================
echo.

echo [Step 1/4] Getting WSL IP...
call :GET_WSL_IP
if "%WSL_IP%"=="" (
    echo [Error] Failed to get WSL IP!
    call :LOG "ERROR" "Failed to get WSL IP"
    pause
    exit /b 1
)
echo [OK] WSL IP: %WSL_IP%
call :LOG "INFO" "WSL IP: %WSL_IP%"
echo.

echo [Step 2/4] Cleaning old rules...
netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% > nul 2>&1
echo [OK] Old rules cleaned
call :LOG "INFO" "Old rules cleaned"
echo.

echo [Step 3/4] Creating port forward (%LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%)...
netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% > nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Port forward created
    call :LOG "INFO" "Port forward: %LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%"
) else (
    echo [Error] Failed to create port forward!
    call :LOG "ERROR" "Failed to create port forward"
    pause
    exit /b 1
)
echo.

echo [Step 4/4] Configuring firewall...
set "FIREWALL_RULE_NAME=WSL SSH Port %LISTEN_PORT%"
netsh advfirewall firewall show rule name="!FIREWALL_RULE_NAME!" > nul 2>&1
if %errorLevel% neq 0 (
    netsh advfirewall firewall add rule name="!FIREWALL_RULE_NAME!" dir=in action=allow protocol=TCP localport=%LISTEN_PORT% > nul 2>&1
    echo [OK] Firewall rule created
    call :LOG "INFO" "Firewall rule created"
) else (
    netsh advfirewall firewall set rule name="!FIREWALL_RULE_NAME!" new enable=yes > nul 2>&1
    echo [OK] Firewall rule enabled
    call :LOG "INFO" "Firewall rule enabled"
)
echo.

:: ==============================================
:: Step 8: Display Connection Info
:: ==============================================
echo ==============================================
echo        Initialization Complete!
echo ==============================================
echo.
echo Available IP addresses on this machine:
for /f "tokens=*" %%a in ('powershell -Command "Get-NetIPAddress -AddressFamily IPv4 ^| Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } ^| Select-Object -ExpandProperty IPAddress"') do (
    echo   - %%a
)
echo.
echo Port Forward: %LISTEN_ADDRESS%:%LISTEN_PORT% -> WSL %WSL_IP%:%CONNECT_PORT%

if "%USE_ZEROTIER%"=="1" if not "%ZEROTIER_IP%"=="" (
    echo.
    echo ZeroTier Connection:
    echo   ssh user@%ZEROTIER_IP% -p %LISTEN_PORT%
)

echo.
echo Connection command (replace 'user' with your username):
echo   ssh user@^<IP^> -p %LISTEN_PORT%
echo ==============================================
echo.

:: ==============================================
:: Step 9: Keep-Alive Loop
:: ==============================================
echo [Keep-Alive] Keep this window open
echo [Interval] Check every %CHECK_INTERVAL% seconds
echo ==============================================
call :LOG "INFO" "Entering keep-alive loop"
echo.

:KEEP_ALIVE_LOOP
netstat -ano | findstr ":%LISTEN_PORT%" > nul 2>&1
if %errorLevel% neq 0 (
    echo [%date% %time%] Port %LISTEN_PORT% lost, rebuilding...
    call :LOG "WARN" "Port %LISTEN_PORT% lost, rebuilding..."

    call :GET_WSL_IP

    if not "!WSL_IP!"=="" (
        echo   -> New IP: %WSL_IP%
        call :LOG "INFO" "New WSL IP: %WSL_IP%"

        netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% > nul 2>&1
        netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% > nul 2>&1

        if "%RESTART_SSH%"=="1" (
            wsl -d "%WSL_DISTRO%" -e sudo systemctl restart ssh > nul 2>&1
            if !errorLevel! equ 0 (
                echo   -> SSH restarted
                call :LOG "INFO" "SSH restarted"
            )
        )

        echo [%date% %time%] [OK] Rebuilt: %LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%
        call :LOG "INFO" "Rebuild complete"
    ) else (
        echo [%date% %time%] [!] Cannot get WSL IP, retry next time
        call :LOG "ERROR" "Failed to get WSL IP during rebuild"
    )
    echo.
)

timeout /t %CHECK_INTERVAL% /nobreak > nul
goto :KEEP_ALIVE_LOOP

:: ==============================================
:: Subroutine: Load Config
:: ==============================================
:LOAD_CONFIG
if not exist "%~1" goto :EOF
for /f "usebackq tokens=1,2 delims==" %%a in ("%~1") do (
    set "key=%%a"
    set "val=%%b"
    for /f "tokens=*" %%k in ("!key!") do set "key=%%k"
    for /f "tokens=*" %%v in ("!val!") do set "val=%%v"

    if /i "!key!"=="WSL_DISTRO" set "WSL_DISTRO=!val!"
    if /i "!key!"=="LISTEN_PORT" set "LISTEN_PORT=!val!"
    if /i "!key!"=="CONNECT_PORT" set "CONNECT_PORT=!val!"
    if /i "!key!"=="LISTEN_ADDRESS" set "LISTEN_ADDRESS=!val!"
    if /i "!key!"=="USE_ZEROTIER" set "USE_ZEROTIER=!val!"
    if /i "!key!"=="ZEROTIER_IP" set "ZEROTIER_IP=!val!"
    if /i "!key!"=="LOG_FILE" set "LOG_FILE=!val!"
    if /i "!key!"=="CHECK_INTERVAL" set "CHECK_INTERVAL=!val!"
    if /i "!key!"=="RESTART_SSH" set "RESTART_SSH=!val!"
)
call :LOG "INFO" "Config loaded: %~1"
goto :EOF

:: ==============================================
:: Subroutine: Detect WSL Distro
:: ==============================================
:DETECT_WSL_DISTRO
for /f "tokens=*" %%i in ('wsl -l -q 2^>nul ^| findstr /v /c:" " ^| head -1') do (
    set "WSL_DISTRO=%%i"
    set "WSL_DISTRO=!WSL_DISTRO: =!"
)
for /f "tokens=*" %%i in ('wsl -l 2^>nul ^| findstr "(Default)"') do (
    for /f "tokens=1" %%j in ("%%i") do (
        set "WSL_DISTRO=%%j"
    )
)
goto :EOF

:: ==============================================
:: Subroutine: Get WSL IP
:: ==============================================
:GET_WSL_IP
set "WSL_IP="
for /f "tokens=1 delims= " %%i in ('wsl -d "%WSL_DISTRO%" -e hostname -I 2^>nul') do (
    set "WSL_IP=%%i"
    if not "!WSL_IP!"=="" goto :GOT_IP
)
if "%WSL_IP%"=="" (
    for /f "tokens=*" %%i in ('wsl -d "%WSL_DISTRO%" -e sh -c "ip addr show eth0 2>/dev/null ^| grep 'inet ' ^| head -1 ^| awk '{print \$2}' ^| cut -d/ -f1" 2^>nul') do (
        set "WSL_IP=%%i"
    )
)
:GOT_IP
goto :EOF

:: ==============================================
:: Subroutine: Log
:: ==============================================
:LOG
set "LOG_LEVEL=%~1"
set "LOG_MSG=%~2"
set "LOG_TIMESTAMP=%date:~0,10% %time:~0,8%"
echo [%LOG_TIMESTAMP%] [%LOG_LEVEL%] %LOG_MSG% >> "%LOG_FILE%" 2>nul
goto :EOF

exit /b 0
