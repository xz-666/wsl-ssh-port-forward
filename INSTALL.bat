@echo off
chcp 65001 > nul 2>&1
echo ==============================================
echo  WSL SSH Port Forward - Quick Installer
echo ==============================================
echo.

:: Check admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [Error] Please run as Administrator!
    pause
    exit /b 1
)

:: Check if config exists
if not exist "wsl-ssh-config.ini" (
    echo [Info] Creating default configuration file...
    copy wsl-ssh-config.example.ini wsl-ssh-config.ini >nul
    echo [OK] Created wsl-ssh-config.ini
    echo.
    echo Please edit wsl-ssh-config.ini with your settings,
    echo then run WSL-SSH-PortForward.bat as Administrator.
) else (
    echo [OK] Configuration file already exists.
)

echo.
echo ==============================================
echo  Installation Complete!
echo ==============================================
echo.
echo Next steps:
echo 1. Edit wsl-ssh-config.ini with your settings
echo 2. Run WSL-SSH-PortForward.bat as Administrator
echo.
echo Would you like to start the script now? (Y/N)
set /p choice=
if /i "%choice%"=="Y" (
    start WSL-SSH-PortForward.bat
)
exit /b 0
