# WSL SSH Port Forward | WSL SSH 端口转发

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-brightgreen.svg)]()
[![WSL: Supported](https://img.shields.io/badge/WSL-Supported-orange.svg)]()

**English** | [简体中文](#简体中文)

---

## English

**Problem**: WSL (Windows Subsystem for Linux) uses a dynamic IP address that changes every time it restarts, making it impossible to remotely SSH into your WSL instance directly.

**Solution**: This script creates a stable SSH tunnel from Windows to WSL, allowing you to remotely access your WSL Ubuntu (or any other distro) via your Windows machine's IP address.

**Typical Use Case**: Combine with ZeroTier (or other VPN) to create a secure remote development environment:
```
Your Laptop (Anywhere)
       │
       ▼ (ZeroTier VPN)
Windows PC (Home/Office)
       │
       ▼ (Port Forward)
   WSL Ubuntu
```

A Windows batch script that automatically configures and maintains SSH port forwarding from Windows to WSL, with intelligent keep-alive functionality.

### Features

- **First-Run Auto-Setup**: Automatically detects all available IPs and guides you through selection
- **Interactive IP Selection**: Choose WSL IP and ZeroTier IP from detected addresses
- **Configuration Persistence**: Saves settings to config file for subsequent runs
- **Easy Reconfiguration**: Option to update settings on each run without editing files
- **Automatic WSL Detection**: Auto-detects your WSL distribution
- **Port Forwarding**: Forwards Windows ports to WSL SSH service
- **Keep-Alive**: Monitors and automatically restores connection if WSL restarts
- **ZeroTier Support**: Auto-detects and configures ZeroTier IP for remote access
- **Firewall Management**: Automatically configures Windows Firewall rules
- **Logging**: Detailed operation logs for troubleshooting

### Quick Start

#### 1. Clone or Download

```bash
git clone https://github.com/xz-666/wsl-ssh-port-forward.git
cd wsl-ssh-port-forward
```

#### 2. Run as Administrator

Right-click `WSL-SSH-PortForward.bat` → **Run as administrator**

#### 3. First Run Setup (Auto-Detection)

On first run, the script will automatically:
- Detect your WSL distribution
- Scan available IP addresses
- Let you select the WSL IP (usually 172.x.x.x)
- Let you select the ZeroTier IP (optional, for remote access)
- Save configuration for future runs

```
[INFO] Detecting WSL IP addresses...

Available IP addresses:
  1. 26.83.94.22
  2. 172.28.222.176
  3. 10.80.139.191

Please select the IP for SSH connection: 2

[INFO] ZeroTier IP Setup (Optional)
...
Enter the number of the ZeroTier IP from the list above: 3

[INFO] Saving configuration...
[OK] Configuration saved to: wsl-ssh-config.ini
```

#### 4. Subsequent Runs

After the first run, configuration is saved. The script will:
- Show current settings
- Ask if you want to use existing config or reconfigure
- Use existing config: Press Enter or type `1`
- Reconfigure: Type `2` to detect and select new IPs

#### 5. Connect via SSH

**Local (same machine):**
```bash
ssh xingzhan@127.0.0.1 -p 2222
```

**Remote via ZeroTier:**
```bash
ssh xingzhan@10.80.139.191 -p 2222
```

**Remote via Windows IP:**
```bash
ssh xingzhan@<windows-lan-ip> -p 2222
```

### Configuration

#### Config File (`wsl-ssh-config.ini`)

| Option | Description | Default |
|--------|-------------|---------|
| `WSL_DISTRO` | WSL distribution name | Auto-detect |
| `LISTEN_PORT` | Windows port to listen on | `2222` |
| `CONNECT_PORT` | WSL SSH port | `22` |
| `LISTEN_ADDRESS` | Bind address (`0.0.0.0` or `127.0.0.1`) | `0.0.0.0` |
| `USE_ZEROTIER` | Enable ZeroTier display (`1` or `0`) | `0` |
| `ZEROTIER_IP` | Your ZeroTier IP address | - |
| `CHECK_INTERVAL` | Health check interval in seconds | `2` |
| `RESTART_SSH` | Restart SSH on WSL when needed (`1` or `0`) | `1` |
| `LOG_FILE` | Path to log file | `wsl-ssh-portforward.log` |

#### Command Line Options

```
WSL-SSH-PortForward.bat [options]

Options:
  -h, --help                 Show help message
  -d, --distro <name>        Specify WSL distro
  -p, --port <port>          Listen port (default: 2222)
  -c, --connect-port <port>  Connect port (default: 22)
  -z, --zerotier <IP>        Enable ZeroTier IP display
  -f, --config <file>        Config file path
  -l, --log <file>           Log file path
  -i, --interval <seconds>   Check interval (default: 2)
  --no-ssh-restart           Don't restart SSH service
```

#### Examples

**Use default settings:**
```cmd
WSL-SSH-PortForward.bat
```

**Specify WSL distro:**
```cmd
WSL-SSH-PortForward.bat -d Ubuntu-22.04
```

**Custom port mapping:**
```cmd
WSL-SSH-PortForward.bat -p 2222 -c 22
```

**Enable ZeroTier display:**
```cmd
WSL-SSH-PortForward.bat -z YOUR_ZEROTIER_IP
```

**Use custom config:**
```cmd
WSL-SSH-PortForward.bat -f my-config.ini
```

**Combine options:**
```cmd
WSL-SSH-PortForward.bat -d Debian -p 2222 -z YOUR_ZEROTIER_IP
```

### How It Works

```
┌─────────────────┐      Port Forward       ┌─────────────┐
│   Remote Client │  ════════════════════►  │   Windows   │
│                 │   ssh user@windows-ip   │   :2222     │
└─────────────────┘                         └──────┬──────┘
                                                   │
                                          WSL Port Proxy
                                                   │
                                            ┌──────▼──────┐
                                            │     WSL     │
                                            │   :22(SSH)  │
                                            └─────────────┘
```

1. **Initialization**:
   - Detects or validates WSL distribution
   - Gets WSL internal IP address
   - Creates port proxy rule using `netsh`
   - Configures Windows Firewall

2. **Keep-Alive**:
   - Periodically checks if port is listening
   - If port disappears (WSL restart, IP change):
     - Re-fetches WSL IP
     - Recreates port proxy rule
     - Restarts SSH service if needed

### Prerequisites

- Windows 10/11 with WSL installed
- WSL distribution with SSH server installed and running
- Administrator privileges (for port proxy and firewall configuration)

#### Install SSH Server in WSL

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure SSH (optional)
sudo nano /etc/ssh/sshd_config
# Ensure: Port 22
# Ensure: PasswordAuthentication yes (or use key-based auth)

sudo systemctl restart ssh
```

### Finding Your Windows IP

The script displays all available IPs on startup. Common ways to find your IP:

**From Windows:**
```cmd
ipconfig
```

**From the script output:**
```
Available IP addresses on this machine:
  - 192.168.1.100
  - 10.0.0.50
```

**For ZeroTier users:**
```cmd
zerotier-cli listnetworks
```

### Troubleshooting

#### Script won't start
- **Run as Administrator**: The script requires admin privileges for `netsh` and firewall configuration

#### "No WSL distro found"
- Install WSL: `wsl --install`
- List available distros: `wsl -l -v`

#### "Failed to get WSL IP"
- Ensure WSL is running: `wsl -d <distro>`
- Check network in WSL: `ip addr`

#### Connection refused
- Ensure SSH is running in WSL: `sudo systemctl status ssh`
- Check firewall on WSL: `sudo ufw status`
- Verify port proxy: `netsh interface portproxy show all`

#### Check logs
Review the log file (default: `wsl-ssh-portforward.log`) for detailed operation info.

### Security Considerations

- **Firewall**: The script opens the specified port in Windows Firewall. Ensure your network is secure.
- **SSH Security**: Consider using key-based authentication and disabling password auth in production.
- **Listen Address**: Use `127.0.0.1` instead of `0.0.0.0` if you only need local connections.

---

## 简体中文

**问题**: WSL (Windows Subsystem for Linux) 使用动态 IP 地址，每次重启都会变化，导致无法直接远程 SSH 到 WSL 实例。

**解决方案**: 本脚本创建从 Windows 到 WSL 的稳定 SSH 隧道，让你可以通过 Windows 主机的 IP 地址远程访问 WSL Ubuntu（或其他发行版）。

**典型使用场景**: 配合 ZeroTier（或其他 VPN）创建安全的远程开发环境：
```
你的笔记本（任意地点）
       │
       ▼ (ZeroTier VPN)
Windows 电脑（家里/公司）
       │
       ▼ (端口转发)
   WSL Ubuntu
```

一个 Windows 批处理脚本，用于自动配置和维护从 Windows 到 WSL 的 SSH 端口转发，具备智能保活功能。

### 功能特性

- **首次运行自动配置**: 自动检测所有可用 IP 并引导选择
- **交互式 IP 选择**: 从检测到的地址中选择 WSL IP 和 ZeroTier IP
- **配置持久化**: 将设置保存到配置文件供后续使用
- **轻松重新配置**: 每次运行可选择更新设置，无需手动编辑文件
- **自动检测 WSL**: 自动发现你的 WSL 发行版
- **端口转发**: 将 Windows 端口转发到 WSL SSH 服务
- **智能保活**: 监控连接状态，WSL 重启时自动恢复
- **ZeroTier 支持**: 自动检测并配置 ZeroTier IP 用于远程访问
- **防火墙管理**: 自动配置 Windows 防火墙规则
- **日志记录**: 详细的操作日志，便于故障排查

### 快速开始

#### 1. 克隆或下载

```bash
git clone https://github.com/xz-666/wsl-ssh-port-forward.git
cd wsl-ssh-port-forward
```

#### 2. 以管理员身份运行

右键 `WSL-SSH-PortForward.bat` → **以管理员身份运行**

#### 3. 首次运行设置（自动检测）

首次运行时，脚本会自动：
- 检测你的 WSL 发行版
- 扫描可用 IP 地址
- 让你选择 WSL IP（通常是 172.x.x.x）
- 让你选择 ZeroTier IP（可选，用于远程访问）
- 保存配置供后续使用

```
[INFO] Detecting WSL IP addresses...

Available IP addresses:
  1. 26.83.94.22
  2. 172.28.222.176
  3. 10.80.139.191

Please select the IP for SSH connection: 2

[INFO] ZeroTier IP Setup (Optional)
...
Enter the number of the ZeroTier IP from the list above: 3

[INFO] Saving configuration...
[OK] Configuration saved to: wsl-ssh-config.ini
```

#### 4. 后续运行

首次运行后，配置已保存。脚本会：
- 显示当前设置
- 询问使用现有配置还是重新配置
- 使用现有配置：按回车或输入 `1`
- 重新配置：输入 `2` 检测并选择新 IP

#### 5. 通过 SSH 连接

**本地（同一台机器）：**
```bash
ssh xingzhan@127.0.0.1 -p 2222
```

**通过 ZeroTier 远程连接：**
```bash
ssh xingzhan@10.80.139.191 -p 2222
```

**通过 Windows IP 远程连接：**
```bash
ssh xingzhan@<windows-lan-ip> -p 2222
```

### 配置说明

#### 配置文件 (`wsl-ssh-config.ini`)

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `WSL_DISTRO` | WSL 发行版名称 | 自动检测 |
| `LISTEN_PORT` | Windows 监听端口 | `2222` |
| `CONNECT_PORT` | WSL SSH 端口 | `22` |
| `LISTEN_ADDRESS` | 绑定地址 (`0.0.0.0` 或 `127.0.0.1`) | `0.0.0.0` |
| `USE_ZEROTIER` | 启用 ZeroTier 显示 (`1` 或 `0`) | `0` |
| `ZEROTIER_IP` | 你的 ZeroTier IP 地址 | - |
| `CHECK_INTERVAL` | 健康检查间隔（秒） | `2` |
| `RESTART_SSH` | 需要时重启 WSL SSH (`1` 或 `0`) | `1` |
| `LOG_FILE` | 日志文件路径 | `wsl-ssh-portforward.log` |

#### 命令行参数

```
WSL-SSH-PortForward.bat [选项]

选项:
  -h, --help                 显示帮助信息
  -d, --distro <名称>        指定 WSL 发行版
  -p, --port <端口>          监听端口（默认: 2222）
  -c, --connect-port <端口>  连接端口（默认: 22）
  -z, --zerotier <IP>        启用 ZeroTier IP 显示
  -f, --config <文件>        配置文件路径
  -l, --log <文件>           日志文件路径
  -i, --interval <秒>        检查间隔（默认: 2）
  --no-ssh-restart           不重启 SSH 服务
```

#### 使用示例

**使用默认设置：**
```cmd
WSL-SSH-PortForward.bat
```

**指定 WSL 发行版：**
```cmd
WSL-SSH-PortForward.bat -d Ubuntu-22.04
```

**自定义端口映射：**
```cmd
WSL-SSH-PortForward.bat -p 2222 -c 22
```

**启用 ZeroTier 显示：**
```cmd
WSL-SSH-PortForward.bat -z YOUR_ZEROTIER_IP
```

**使用自定义配置：**
```cmd
WSL-SSH-PortForward.bat -f my-config.ini
```

**组合选项：**
```cmd
WSL-SSH-PortForward.bat -d Debian -p 2222 -z YOUR_ZEROTIER_IP
```

### 工作原理

```
┌─────────────────┐      端口转发       ┌─────────────┐
│   远程客户端    │  ══════════════════► │   Windows   │
│                 │  ssh user@windows-ip │   :2222     │
└─────────────────┘                      └──────┬──────┘
                                                │
                                          WSL 端口代理
                                                │
                                         ┌──────▼──────┐
                                         │     WSL     │
                                         │   :22(SSH)  │
                                         └─────────────┘
```

1. **初始化阶段**：
   - 检测或验证 WSL 发行版
   - 获取 WSL 内部 IP 地址
   - 使用 `netsh` 创建端口代理规则
   - 配置 Windows 防火墙

2. **保活阶段**：
   - 定期检查端口是否在监听
   - 如果端口消失（WSL 重启、IP 变化）：
     - 重新获取 WSL IP
     - 重新创建端口代理规则
     - 如需则重启 SSH 服务

### 系统要求

- Windows 10/11 并已安装 WSL
- WSL 发行版已安装并运行 SSH 服务器
- 管理员权限（用于端口代理和防火墙配置）

#### 在 WSL 中安装 SSH 服务器

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# 配置 SSH（可选）
sudo nano /etc/ssh/sshd_config
# 确保: Port 22
# 确保: PasswordAuthentication yes（或使用密钥认证）

sudo systemctl restart ssh
```

### 查找 Windows IP 地址

脚本启动时会显示所有可用 IP。其他查找方式：

**在 Windows 中：**
```cmd
ipconfig
```

**从脚本输出中：**
```
本机可用 IP 地址:
  - 192.168.1.100
  - 10.0.0.50
```

**ZeroTier 用户：**
```cmd
zerotier-cli listnetworks
```

### 故障排查

#### 脚本无法启动
- **以管理员身份运行**: 脚本需要管理员权限执行 `netsh` 和防火墙配置

#### "未找到 WSL 发行版"
- 安装 WSL: `wsl --install`
- 列出可用发行版: `wsl -l -v`

#### "获取 WSL IP 失败"
- 确保 WSL 正在运行: `wsl -d <发行版名称>`
- 检查 WSL 网络: `ip addr`

#### 连接被拒绝
- 确保 WSL 中 SSH 正在运行: `sudo systemctl status ssh`
- 检查 WSL 防火墙: `sudo ufw status`
- 验证端口代理: `netsh interface portproxy show all`

#### 查看日志
查看日志文件（默认: `wsl-ssh-portforward.log`）获取详细操作信息。

### 安全注意事项

- **防火墙**: 脚本会在 Windows 防火墙中开放指定端口，请确保网络安全。
- **SSH 安全**: 生产环境建议使用密钥认证并禁用密码认证。
- **监听地址**: 如果只需要本地连接，使用 `127.0.0.1` 替代 `0.0.0.0`。

---

## Contributing | 贡献

Contributions are welcome! Please feel free to submit a Pull Request.

欢迎贡献！请随时提交 Pull Request。

## License | 许可证

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

本项目采用 MIT 许可证 - 详情见 [LICENSE](LICENSE) 文件。

## Acknowledgments | 致谢

- Inspired by common WSL networking challenges
- Thanks to the WSL team for making Linux on Windows possible

- 受 WSL 网络挑战启发
- 感谢 WSL 团队让 Windows 上运行 Linux 成为可能
