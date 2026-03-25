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
set "WSL_IP="
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
:: Step 2: Check and Load Configuration File
:: ==============================================
if not exist "%DEFAULT_CONFIG_FILE%" (
    echo.
    echo ==============================================
    echo  [警告] 配置文件未找到
    echo ==============================================
    echo.
    echo 配置文件路径: %DEFAULT_CONFIG_FILE%
    echo.
    echo 解决方法：
    echo   1. 复制示例配置文件：
    echo      copy wsl-ssh-config.example.ini wsl-ssh-config.ini
    echo   2. 编辑 wsl-ssh-config.ini 填入你的配置
    echo.
    echo 或者使用命令行参数运行：
    echo   WSL-SSH-PortForward.bat -d Ubuntu-22.04 -z YOUR_ZEROTIER_IP
    echo.
    echo ==============================================
    echo.
    call :LOG "WARN" "Config file not found: %DEFAULT_CONFIG_FILE%"
    echo [Info] 将使用默认配置继续...
    echo.
    timeout /t 3 >nul
) else (
    call :LOAD_CONFIG "%DEFAULT_CONFIG_FILE%"
)

:: ==============================================
:: Step 3: Set Window Title and Display Info
:: ==============================================
title WSL SSH Port Forward - Port %LISTEN_PORT%-^>%CONNECT_PORT%
cls
echo ==============================================
echo      WSL SSH 端口转发 + 智能保活
echo              [通用版本]
echo ==============================================
echo 配置: %DEFAULT_CONFIG_FILE%
echo 日志: %LOG_FILE%
echo ==============================================
echo.

:: ==============================================
:: Step 4: Check Administrator Privileges
:: ==============================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ==============================================
    echo  [错误] 权限不足 - 请以管理员身份运行
    echo ==============================================
    echo.
    echo 当前操作需要管理员权限才能：
    echo   - 创建端口转发规则 (netsh)
    echo   - 配置 Windows 防火墙
    echo.
    echo 解决方法：
    echo   1. 右键点击 WSL-SSH-PortForward.bat
    echo   2. 选择 "以管理员身份运行"
    echo.
    echo ==============================================
    echo.
    call :LOG "ERROR" "Script not run as administrator"
    pause
    exit /b 1
)

:: ==============================================
:: Step 5: Detect/Validate WSL Distro
:: ==============================================
call :LOG "INFO" "Starting WSL SSH port forwarding script"

:: ==============================================
:: Step 5: Detect/Validate WSL Distro
:: ==============================================
call :LOG "INFO" "Starting WSL SSH port forwarding script"

if "%WSL_DISTRO%"=="" (
    echo [检测] 正在查找可用的 WSL 发行版...
    call :DETECT_WSL_DISTRO
    if "!WSL_DISTRO!"=="" (
        echo.
        echo ==============================================
        echo  [错误] 未找到 WSL 发行版
        echo ==============================================
        echo.
        echo 可能的原因：
        echo   - WSL 尚未安装
        echo   - 所有 WSL 发行版已被卸载
        echo.
        echo 解决方法：
        echo   1. 安装 WSL：
        echo      wsl --install
        echo   2. 或手动指定发行版：
        echo      WSL-SSH-PortForward.bat -d Ubuntu-22.04
        echo.
        echo ==============================================
        echo.
        call :LOG "ERROR" "No WSL distro found"
        pause
        exit /b 1
    )
    echo [OK] 自动检测到发行版: !WSL_DISTRO!
    call :LOG "INFO" "Auto-detected WSL distro: !WSL_DISTRO!"
) else (
    wsl -l -q 2>nul | findstr /i /x "%WSL_DISTRO%" >nul 2>&1
    if %errorLevel% neq 0 (
        echo.
        echo ==============================================
        echo  [错误] WSL 发行版不存在
        echo ==============================================
        echo.
        echo 指定的发行版: %WSL_DISTRO%
        echo.
        echo 可能的原因：
        echo   - 发行版名称拼写错误
        echo   - 该发行版未安装
        echo.
        echo 可用的 WSL 发行版：
        wsl -l -q 2>nul | findstr /v /c:" "
        echo.
        echo 解决方法：
        echo   1. 检查发行版名称拼写
        echo   2. 从上面的列表中选择正确的名称
        echo   3. 或重新安装该发行版
        echo.
        echo ==============================================
        echo.
        call :LOG "ERROR" "Specified WSL distro not found: %WSL_DISTRO%"
        pause
        exit /b 1
    )
    echo [配置] 使用指定发行版: %WSL_DISTRO%
    call :LOG "INFO" "Using specified WSL distro: %WSL_DISTRO%"
)

:: ==============================================
:: Step 6: Check if WSL is Running
:: ==============================================
echo [检查] 正在检查 WSL 状态...
wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
if %errorLevel% neq 0 (
    echo [启动] WSL 未运行，正在启动...
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
echo 【初始化】正在配置端口转发...
echo ==============================================
echo.

echo [步骤 1/4] 正在获取 WSL IP 地址...
call :GET_WSL_IP
if "%WSL_IP%"=="" (
    echo.
    echo ==============================================
    echo  [错误] 获取 WSL IP 地址失败
    echo ==============================================
    echo.
    echo 可能的原因：
    echo   - WSL 未正常启动
    echo   - WSL 网络配置异常
    echo   - 字符编码问题导致 IP 解析失败
    echo.
    echo 解决方法：
    echo   1. 检查 WSL 状态：
    echo      wsl -d %WSL_DISTRO% -e hostname -I
    echo   2. 如果上述命令返回 IP，请在配置文件中手动指定：
    echo      WSL_IP=xxx.xxx.xxx.xxx
    echo   3. 重启 WSL：
    echo      wsl --shutdown
    echo      wsl -d %WSL_DISTRO%
    echo.
    call :LOG "ERROR" "Failed to get WSL IP"
    pause
    exit /b 1
)
echo [OK] WSL IP 地址: %WSL_IP%
call :LOG "INFO" "WSL IP: %WSL_IP%"
echo.

echo [步骤 2/4] 正在清理旧的端口转发规则...
netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% > nul 2>&1
echo [OK] 旧规则已清理
call :LOG "INFO" "Old rules cleaned"
echo.

echo [步骤 3/4] 正在创建端口转发 (%LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%)...
netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% > nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] 端口转发创建成功
    call :LOG "INFO" "Port forward: %LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%"
) else (
    echo.
    echo ==============================================
    echo  [错误] 端口转发创建失败
    echo ==============================================
    echo.
    echo 可能的原因：
    echo   - 端口 %LISTEN_PORT% 已被其他程序占用
    echo   - 端口转发规则冲突
    echo   - 网络适配器异常
    echo.
    echo 解决方法：
    echo   1. 检查端口占用情况：
    echo      netstat -ano | findstr :%LISTEN_PORT%
    echo   2. 清理现有端口转发规则：
    echo      netsh interface portproxy show all
    echo      netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT%
    echo   3. 更换其他监听端口：
    echo      WSL-SSH-PortForward.bat -p 2223
    echo.
    echo ==============================================
    echo.
    call :LOG "ERROR" "Failed to create port forward"
    pause
    exit /b 1
)
echo.

echo [步骤 4/4] 正在配置防火墙规则...
set "FIREWALL_RULE_NAME=WSL SSH Port %LISTEN_PORT%"
netsh advfirewall firewall show rule name="!FIREWALL_RULE_NAME!" > nul 2>&1
if %errorLevel% neq 0 (
    netsh advfirewall firewall add rule name="!FIREWALL_RULE_NAME!" dir=in action=allow protocol=TCP localport=%LISTEN_PORT% > nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] 防火墙规则已创建
        call :LOG "INFO" "Firewall rule created"
    ) else (
        echo.
        echo ==============================================
        echo  [警告] 防火墙规则创建失败
        echo ==============================================
        echo.
        echo 端口 %LISTEN_PORT% 的防火墙规则创建失败，
        echo 但这可能不会完全阻止连接。
        echo.
        echo 如果无法连接，请手动添加规则：
        echo   netsh advfirewall firewall add rule name="WSL SSH Port %LISTEN_PORT%" dir=in action=allow protocol=TCP localport=%LISTEN_PORT%
        echo.
        echo ==============================================
        echo.
    )
) else (
    netsh advfirewall firewall set rule name="!FIREWALL_RULE_NAME!" new enable=yes > nul 2>&1
    echo [OK] 防火墙规则已启用
    call :LOG "INFO" "Firewall rule enabled"
)
echo.

:: ==============================================
:: Step 8: Display Connection Info
:: ==============================================
echo ==============================================
echo           初始化完成！连接信息：
echo ==============================================
echo.
echo 本机可用 IP 地址：
powershell -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -ExpandProperty IPAddress | ForEach-Object { '  - ' + $_ }"
echo.
echo 端口转发: %LISTEN_ADDRESS%:%LISTEN_PORT% -> WSL %WSL_IP%:%CONNECT_PORT%

if "%USE_ZEROTIER%"=="1" if not "%ZEROTIER_IP%"=="" (
    echo.
    echo ZeroTier 专用连接：
    echo   ssh xingzhan@%ZEROTIER_IP% -p %LISTEN_PORT%
)

echo.
echo 通用连接命令（将 'xingzhan' 替换为你的用户名）：
echo   ssh xingzhan@^<IP^> -p %LISTEN_PORT%
echo ==============================================
echo.

:: ==============================================
:: Step 9: Keep-Alive Loop
:: ==============================================
echo 【保活模式】请保持此窗口运行
echo 【检查间隔】每 %CHECK_INTERVAL% 秒检查一次
echo 【提示】关闭此窗口将停止端口转发
echo ==============================================
call :LOG "INFO" "Entering keep-alive loop"
echo.

:KEEP_ALIVE_LOOP
netstat -ano | findstr ":%LISTEN_PORT%" > nul 2>&1
if %errorLevel% neq 0 (
    echo [%date% %time%] 端口 %LISTEN_PORT% 丢失，正在重建...
    call :LOG "WARN" "Port %LISTEN_PORT% lost, rebuilding..."

    call :GET_WSL_IP

    if not "!WSL_IP!"=="" (
        echo   -> 新 IP: %WSL_IP%
        call :LOG "INFO" "New WSL IP: %WSL_IP%"

        netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% > nul 2>&1
        netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% > nul 2>&1

        if "%RESTART_SSH%"=="1" (
            wsl -d "%WSL_DISTRO%" -e sudo systemctl restart ssh > nul 2>&1
            if !errorLevel! equ 0 (
                echo   -> SSH 服务已重启
                call :LOG "INFO" "SSH restarted"
            )
        )

        echo [%date% %time%] [OK] 重建完成: %LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%
        call :LOG "INFO" "Rebuild complete"
    ) else (
        echo [%date% %time%] [!] 无法获取 WSL IP，下次检查时重试
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
    if /i "!key!"=="WSL_IP" set "WSL_IP=!val!"
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
:: If WSL_IP is already set from config file, use it directly
if not "%WSL_IP%"=="" (
    echo [Config] Using configured WSL IP: %WSL_IP%
    call :LOG "INFO" "Using configured WSL IP: %WSL_IP%"
    goto :GOT_IP
)
:: Otherwise, try to auto-detect
:: Method 1: Use PowerShell to execute WSL command (avoids encoding issues)
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "$ip = (wsl -d '%WSL_DISTRO%' hostname -I).Trim().Split(' ')[0]; if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { Write-Output $ip }" 2^>nul`) do (
    set "WSL_IP=%%i"
    if not "!WSL_IP!"=="" goto :GOT_IP
)
:: Method 2: Direct WSL with ip command
if "%WSL_IP%"=="" (
    for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "$ip = (wsl -d '%WSL_DISTRO%' sh -c 'ip route get 1.1.1.1 2>/dev/null' | Select-String -Pattern 'src\s+(\d+\.\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches.Groups[1].Value }).Trim(); if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { Write-Output $ip }" 2^>nul`) do (
        set "WSL_IP=%%i"
        if not "!WSL_IP!"=="" goto :GOT_IP
    )
)
:: Method 3: Fallback to WSL2 default gateway pattern
if "%WSL_IP%"=="" (
    for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "$ip = (wsl -d '%WSL_DISTRO%' cat /etc/resolv.conf 2>$null | Select-String -Pattern 'nameserver\s+(\d+\.\d+\.\d+\.\d+)' | Select-Object -First 1 | ForEach-Object { $_.Matches.Groups[1].Value }).Trim(); $ip -replace '172\.\d+\.\d+\.1', ($ip -replace '\.1$', '.2'); if ($ip -match '^\d+\.\d+\.\d+\.\d+$') { Write-Output $ip }" 2^>nul`) do (
        set "WSL_IP=%%i"
    )
)
:GOT_IP
:: Clean up any spaces
for /f "tokens=*" %%a in ("!WSL_IP!") do set "WSL_IP=%%a"
:: Validate IP format
powershell -NoProfile -Command "if ('%WSL_IP%' -notmatch '^\d+\.\d+\.\d+\.\d+$') { exit 1 }" 2>nul
if %errorLevel% neq 0 (
    set "WSL_IP="
)
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
