# Contributing to WSL SSH Port Forward

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check if the issue already exists in the [Issues](../../issues) section
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Windows version and WSL distro information
   - Script output or log files (if applicable)

### Pull Requests

1. Fork the repository
2. Create a new branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test thoroughly on your system
5. Commit with clear messages
6. Push to your fork and submit a Pull Request

### Code Style

- Use clear, descriptive variable names
- Add comments for complex logic
- Keep batch commands compatible with Windows 10/11
- Test with both Command Prompt and PowerShell execution

### Areas for Contribution

- [ ] Support for multiple WSL distros simultaneously
- [ ] GUI version using PowerShell or C#
- [ ] Windows Service mode
- [ ] Additional VPN integrations (Tailscale, etc.)
- [ ] Multi-port forwarding support
- [ ] IPv6 support

## Development Setup

1. Clone your fork:
   ```bash
   git clone https://github.com/your-username/wsl-ssh-port-forward.git
   ```

2. Create a test config:
   ```bash
   copy wsl-ssh-config.example.ini wsl-ssh-config.ini
   ```

3. Test changes by running as Administrator

## Questions?

Feel free to open an issue for questions or join discussions.
