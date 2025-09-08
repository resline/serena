# Serena Agent - Windows Installation Guide

This directory contains comprehensive Windows installation scripts for Serena Agent, designed to provide a seamless offline installation experience.

## Installation Scripts Overview

### 1. `install.bat` - Main Batch Installer
The primary Windows batch installer that handles the basic installation process.

**Features:**
- Checks for administrator privileges
- Verifies system requirements (Windows version, architecture)
- Extracts Python embeddable package
- Creates virtual environment using embedded Python
- Installs all wheels from local directory
- Extracts language servers to `%USERPROFILE%\.solidlsp\`
- Sets up environment variables (SERENA_HOME, SOLIDLSP_HOME)
- Creates desktop shortcuts for MCP server
- Registers Serena in system PATH
- Comprehensive logging and progress display

**Usage:**
```batch
# Run as Administrator
install.bat
```

**Requirements:**
- Windows 10/11 (x64 or ARM64)
- Administrator privileges
- `python-embeddable.zip` in the same directory
- `wheels\` directory containing all required .whl files
- Optional: `language_servers\` directory

### 2. `install.ps1` - Advanced PowerShell Installer
Enhanced PowerShell installer with advanced features and comprehensive error handling.

**Features:**
- Enhanced error handling and logging with multiple log levels
- Progress bars for all operations
- Comprehensive installation verification
- System requirements check (Windows version, architecture, disk space)
- Rollback capability on installation failure
- Support for silent/unattended installation
- Creates Start Menu entries with uninstaller
- Configurable installation path
- Automatic dependency resolution

**Usage:**
```powershell
# Interactive installation
.\install.ps1

# Silent installation
.\install.ps1 -Silent

# Custom installation path
.\install.ps1 -InstallPath "C:\Tools\Serena"

# Silent with warning-level logging
.\install.ps1 -Silent -LogLevel Warning
```

**Parameters:**
- `-Silent`: Run without user interaction
- `-SkipDependencies`: Skip installation of runtime dependencies
- `-InstallPath`: Custom installation path (default: `$env:USERPROFILE\Serena`)
- `-LogLevel`: Logging level - Info, Warning, Error (default: Info)

### 3. `setup_environment.ps1` - Environment Configuration
Comprehensive environment setup script that configures Windows for optimal Serena Agent usage.

**Features:**
- Configures core PATH variables
- Sets SERENA_HOME, SOLIDLSP_HOME environment variables
- Auto-detects and configures language-specific variables (JAVA_HOME, NODE_HOME, etc.)
- Creates file associations for .serena files
- Sets up Windows Terminal integration with custom profile
- Configures Windows Firewall rules for MCP server
- Updates PowerShell profile with Serena aliases and functions
- Comprehensive environment verification

**Usage:**
```powershell
# Basic environment setup
.\setup_environment.ps1

# Full setup with all optional features
.\setup_environment.ps1 -ConfigureFirewall -SetupFileAssociations -SetupTerminalIntegration

# Custom paths
.\setup_environment.ps1 -SerenaHome "C:\Tools\Serena" -SolidLspHome "C:\Tools\.solidlsp"

# Silent setup
.\setup_environment.ps1 -Silent
```

**Parameters:**
- `-SerenaHome`: Path to Serena installation directory
- `-SolidLspHome`: Path to SolidLSP directory (default: `$env:USERPROFILE\.solidlsp`)
- `-ConfigureFirewall`: Configure Windows Firewall rules for MCP server
- `-SetupFileAssociations`: Create file associations for supported languages
- `-SetupTerminalIntegration`: Configure Windows Terminal integration
- `-Silent`: Run without user interaction

### 4. `uninstall.ps1` - Complete Uninstaller
Comprehensive uninstaller that completely removes Serena Agent from Windows.

**Features:**
- Stops all running Serena processes
- Removes installation directories
- Cleans up environment variables
- Removes registry entries and file associations
- Removes shortcuts and Start Menu entries
- Removes Windows Firewall rules
- Cleans up PATH variable
- Updates PowerShell profile
- Removes Windows Terminal integration
- Optional backup of user data
- Verification of complete removal

**Usage:**
```powershell
# Interactive uninstallation
.\uninstall.ps1

# Keep user configuration and cache data
.\uninstall.ps1 -KeepUserData

# Silent uninstallation
.\uninstall.ps1 -Silent
```

**Parameters:**
- `-KeepUserData`: Keep user configuration and cache data
- `-Silent`: Run without user interaction
- `-LogLevel`: Logging level - Info, Warning, Error (default: Info)

## Installation Package Structure

For a complete offline installation, your package should contain:

```
SerenaAgent-Windows/
├── install.bat                    # Main batch installer
├── install.ps1                    # Advanced PowerShell installer
├── setup_environment.ps1          # Environment configuration
├── uninstall.ps1                  # Complete uninstaller
├── python-embeddable.zip          # Python 3.11 embeddable package
├── wheels/                        # Python wheels directory
│   ├── serena_agent-0.1.4-py3-none-any.whl
│   ├── requests-2.32.3-py3-none-any.whl
│   ├── mcp-1.12.3-py3-none-any.whl
│   └── ... (all dependencies)
├── language_servers/              # Optional: Pre-downloaded language servers
│   ├── python/
│   ├── typescript/
│   ├── java/
│   └── ...
└── README.md                      # This file
```

## System Requirements

### Minimum Requirements
- **OS**: Windows 10 (1909) or Windows 11
- **Architecture**: x64 or ARM64
- **RAM**: 4 GB (8 GB recommended)
- **Disk Space**: 2 GB free space
- **PowerShell**: Version 5.1 or later
- **Privileges**: Administrator access required for installation

### Recommended Requirements
- **OS**: Windows 11 (latest)
- **Architecture**: x64
- **RAM**: 8 GB or more
- **Disk Space**: 4 GB free space
- **PowerShell**: Version 7.x
- **Network**: Internet connection for language server downloads (if not included)

## Installation Process

### Quick Installation (Recommended)
1. **Download** the complete installation package
2. **Extract** to a temporary directory
3. **Right-click** on `install.ps1` → "Run with PowerShell"
4. **Follow** the interactive prompts
5. **Restart** your PowerShell/Command Prompt session

### Advanced Installation
1. **Open PowerShell as Administrator**
2. **Navigate** to the installation directory
3. **Run** with custom parameters:
   ```powershell
   .\install.ps1 -InstallPath "C:\Tools\Serena" -ConfigureFirewall -SetupFileAssociations
   ```
4. **Configure environment** (optional):
   ```powershell
   .\setup_environment.ps1 -SetupTerminalIntegration -ConfigureFirewall
   ```

### Silent Installation
For automated deployment:
```powershell
.\install.ps1 -Silent -InstallPath "C:\Program Files\Serena"
.\setup_environment.ps1 -Silent -ConfigureFirewall -SetupFileAssociations
```

## Post-Installation

### Verify Installation
```powershell
# Check Serena command
serena --version

# Check MCP server
serena-mcp-server --help

# Check environment variables
$env:SERENA_HOME
$env:SOLIDLSP_HOME
```

### Available Commands
After installation, the following commands are available:
- `serena` - Main Serena CLI interface
- `serena-mcp-server` - Start the MCP server
- `index-project` - Index project for faster performance

### PowerShell Integration
The installation adds these aliases to your PowerShell profile:
- `smcp` - Alias for `Start-SerenaMCP`
- `serena` - Direct access to Serena executable

### Windows Terminal Integration
A custom Serena Agent profile is added to Windows Terminal with:
- Pre-activated virtual environment
- Custom icon and color scheme
- Proper working directory

## Troubleshooting

### Common Issues

**1. "Execution Policy" Error**
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

**2. "Administrator Privileges Required"**
- Right-click PowerShell → "Run as Administrator"
- Or use `Start-Process powershell -Verb RunAs`

**3. Python Embeddable Package Not Found**
- Ensure `python-embeddable.zip` is in the same directory as installation scripts
- Download Python 3.11 embeddable package from python.org

**4. Wheels Directory Empty**
- Ensure the `wheels/` directory contains all required .whl files
- Rebuild the wheel packages using: `pip wheel serena-agent`

**5. Language Servers Not Working**
- Run the environment setup: `.\setup_environment.ps1`
- Check language-specific environment variables
- Ensure language runtimes are installed (Java, Node.js, etc.)

### Log Files
All operations create detailed log files:
- `install.log` - Installation log
- `environment_setup.log` - Environment configuration log
- `uninstall.log` - Uninstallation log

### Getting Help
1. **Check log files** for detailed error information
2. **Run with verbose logging**: `-LogLevel Info`
3. **Verify system requirements** are met
4. **Check Windows Event Viewer** for system-level issues

## Security Considerations

### Firewall Configuration
The scripts can configure Windows Firewall rules for the MCP server:
- **Inbound rule**: Allows connections to the MCP server
- **Outbound rule**: Allows MCP server to make external connections
- **Profiles**: Domain and Private networks only (not Public)

### File Associations
File associations are created only for:
- `.serena` files → Serena Agent
- Registry entries in `HKEY_CLASSES_ROOT`

### Environment Variables
The installation sets these environment variables:
- **System**: `SERENA_HOME`, `SOLIDLSP_HOME`, `PATH`
- **User**: `SERENA_CONFIG_DIR`, `SERENA_LOG_LEVEL`, `SERENA_CACHE_DIR`

## Uninstallation

### Complete Removal
```powershell
.\uninstall.ps1
```

### Preserve User Data
```powershell
.\uninstall.ps1 -KeepUserData
```

### Silent Removal
```powershell
.\uninstall.ps1 -Silent
```

The uninstaller removes:
- Installation directories
- Environment variables
- Registry entries
- Shortcuts and Start Menu entries
- Firewall rules
- PowerShell profile modifications
- Windows Terminal integration

## Support

For issues with the Windows installation scripts:
1. Check the log files in the installation directory
2. Ensure all system requirements are met
3. Try running the installation with administrator privileges
4. For language server issues, verify the specific language runtime is installed

## License

These installation scripts are part of the Serena Agent project and are subject to the same MIT license terms.