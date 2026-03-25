@echo off
chcp 65001 > nul 2>&1
setlocal EnableDelayedExpansion

:: ==============================================
:: WSL SSH Port Forward + Keep-Alive
:: ==============================================

:: Default configuration
set CONFIG_FILE=%~dp0wsl-ssh-config.ini
set WSL_DISTRO=
set WSL_IP=
set LISTEN_PORT=2222
set CONNECT_PORT=22
set LISTEN_ADDRESS=0.0.0.0
set ZEROTIER_IP=
set CHECK_INTERVAL=2

:: Show title first
title WSL SSH Port Forward
cls
echo ==============================================
echo   WSL SSH 端口转发 + 智能保活
echo ==============================================
echo.

:: Check admin first
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 权限不足
    echo.
    echo 本脚本需要管理员权限才能：
    echo   - 创建端口转发规则
    echo   - 配置 Windows 防火墙
    echo.
    echo 解决方法：
    echo   1. 关闭此窗口
    echo   2. 右键点击 WSL-SSH-PortForward.bat
    echo   3. 选择【以管理员身份运行】
    echo.
    pause
    exit /b 1
)

:: Parse arguments
:PARSE_ARGS
if "%~1"=="" goto ARGS_DONE
if /i "%~1"=="-h" goto SHOW_HELP
if /i "%~1"=="--help" goto SHOW_HELP
if /i "%~1"=="-d" set WSL_DISTRO=%~2& shift& shift& goto PARSE_ARGS
if /i "%~1"=="-p" set LISTEN_PORT=%~2& shift& shift& goto PARSE_ARGS
if /i "%~1"=="-z" set ZEROTIER_IP=%~2& shift& shift& goto PARSE_ARGS
shift
goto PARSE_ARGS
:ARGS_DONE

:: Load config file
if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
        set key=%%a
        set val=%%b
        for /f "tokens=*" %%k in ("!key!") do set key=%%k
        for /f "tokens=*" %%v in ("!val!") do set val=%%v
        if /i "!key!"=="WSL_DISTRO" set WSL_DISTRO=!val!
        if /i "!key!"=="WSL_IP" set WSL_IP=!val!
        if /i "!key!"=="LISTEN_PORT" set LISTEN_PORT=!val!
        if /i "!key!"=="ZEROTIER_IP" set ZEROTIER_IP=!val!
    )
)

:: Detect WSL distro
if "%WSL_DISTRO%"=="" (
    for /f "tokens=1" %%i in ('wsl -l -q 2^>nul') do (
        set WSL_DISTRO=%%i
        goto FOUND_DISTRO
    )
)
:FOUND_DISTRO

if "%WSL_DISTRO%"=="" (
    echo [错误] 未找到 WSL 发行版
    echo 请先安装 WSL: wsl --install
    pause
    exit /b 1
)

echo ==============================================
echo WSL SSH 端口转发
echo ==============================================
echo 发行版: %WSL_DISTRO%
echo.

:: Check WSL running
wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
if %errorLevel% neq 0 (
    echo [信息] 正在启动 WSL...
    wsl -d "%WSL_DISTRO%" -e echo test >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: Get WSL IP - use config file first, avoid encoding issues
if "%WSL_IP%"=="" (
    echo [错误] 配置文件中未设置 WSL_IP
    echo.
    echo 请编辑 %CONFIG_FILE% 并添加：
    echo   WSL_IP=你的WSL_IP地址
    echo.
    echo 你可以通过以下命令获取 WSL IP：
    echo   wsl -d %WSL_DISTRO% hostname -I
    echo.
    pause
    exit /b 1
)

echo [成功] WSL IP: %WSL_IP%

:: Delete old rules
netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% >nul 2>&1

:: Create port forward
netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 端口转发创建失败
    pause
    exit /b 1
)

echo [成功] 端口转发: %LISTEN_ADDRESS%:%LISTEN_PORT% -> %WSL_IP%:%CONNECT_PORT%

:: Firewall
netsh advfirewall firewall add rule name="WSL SSH %LISTEN_PORT%" dir=in action=allow protocol=TCP localport=%LISTEN_PORT% >nul 2>&1
echo [成功] 防火墙规则已添加

:: Show info
echo ==============================================
echo 连接信息：
echo ==============================================
if not "%ZEROTIER_IP%"=="" (
    echo ZeroTier: ssh user@%ZEROTIER_IP% -p %LISTEN_PORT%
)
echo 本地连接: ssh user@<Windows-IP> -p %LISTEN_PORT%
echo.
echo 【保活模式】运行中... 关闭此窗口将停止转发
echo ==============================================

:: Keep-alive loop
:LOOP
timeout /t %CHECK_INTERVAL% /nobreak >nul
netstat -ano | findstr ":%LISTEN_PORT%" >nul 2>&1
if %errorLevel% neq 0 (
    echo [%date% %time%] 端口丢失，正在重建...
    netsh interface portproxy delete v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% >nul 2>&1
    netsh interface portproxy add v4tov4 listenaddress=%LISTEN_ADDRESS% listenport=%LISTEN_PORT% connectaddress=%WSL_IP% connectport=%CONNECT_PORT% >nul 2>&1
    echo [%date% %time%] 重建完成
)
goto LOOP

:SHOW_HELP
echo 用法: %~nx0 [-d 发行版] [-p 端口] [-z zerotier_ip]
echo.
echo 选项:
echo   -d    WSL 发行版名称 (默认: 自动检测)
echo   -p    监听端口 (默认: 2222)
echo   -z    ZeroTier IP 地址
echo.
pause
exit /b 0
