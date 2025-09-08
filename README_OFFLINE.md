# Serena Agent - Offline Installation Guide for Windows

<p align="center" style="text-align:center">
  <img src="resources/serena-logo.svg#gh-light-mode-only" style="width:400px">
  <img src="resources/serena-logo-dark-mode.svg#gh-dark-mode-only" style="width:400px">
</p>

## Overview

### What is Serena Agent Offline Package

The Serena Agent Offline Package is a complete, self-contained installation bundle that enables you to run Serena's powerful coding agent toolkit on Windows systems without requiring internet connectivity. This package includes all necessary language servers, runtime dependencies, and tools needed for full offline operation.

Serena Agent transforms large language models (LLMs) into fully-featured coding agents that work directly on your codebase through semantic code understanding and IDE-like capabilities.

### Supported Systems

- **Operating Systems**: Windows 10 (version 1903+), Windows 11, Windows Server 2019+
- **Architectures**: x64 (Intel/AMD 64-bit), ARM64 (Windows on ARM)
- **Total Package Size**: ~2.5GB compressed, ~8GB when fully installed
- **Installation Size**: ~10GB free disk space required

### Included Language Servers (25+)

The offline package includes pre-configured language servers for:

**Production Languages**:
- Python (Pyright v1.1.396+)
- TypeScript/JavaScript (TypeScript Language Server v4.3.3)
- C# (Microsoft.CodeAnalysis.LanguageServer v5.0.0)
- Java (Eclipse JDT Language Server via VS Code Java Extension v1.42.0)
- Rust (rust-analyzer - uses system toolchain)
- Go (gopls - uses system installation)
- C/C++ (clangd)
- PHP (Intelephense)
- Ruby (ruby-lsp)
- Swift (SourceKit-LSP)
- Kotlin (Kotlin Language Server)

**Specialized Languages**:
- AL (Microsoft Dynamics 365 Business Central)
- Dart (Dart Language Server)
- Clojure (clojure-lsp)
- Elixir (ElixirLS/NextLS)
- Erlang (erlang_ls)
- Terraform (terraform-ls)
- Bash (bash-language-server)
- Zig (ZLS)
- Lua (lua-language-server)
- Nix (nixd)
- R (R Language Server)

**Experimental/Alternative**:
- Python Jedi (alternative to Pyright)
- C# OmniSharp (legacy alternative)
- TypeScript VTS (native VSCode integration)
- Ruby Solargraph (legacy alternative)

## Pre-Installation Requirements

### System Requirements

- **Operating System**: Windows 10 (version 1903 or later) or Windows 11
- **Memory**: 8GB RAM minimum, 16GB recommended for large projects
- **Disk Space**: 10GB free space for installation
- **Processor**: x64 or ARM64 architecture
- **Administrator Privileges**: Required for system-wide installation

### Prerequisites

Before installation, ensure you have:

1. **Windows PowerShell 5.1** or **PowerShell 7+** (included in Windows 10/11)
2. **Administrator access** to the system
3. **Windows Defender** or antivirus configured to allow the installation
4. **Network access** for initial setup verification (can be disabled afterward)

### Optional Runtime Dependencies

Some language servers require additional runtimes (can be installed offline):

- **Node.js 18+**: For TypeScript/JavaScript (included in package)
- **.NET 6.0+**: For C# development (included in package)
- **Java 17+**: For Java development (included in package)
- **Python 3.8+**: System Python for certain tools
- **Git**: For version control integration

## Package Contents

### Directory Structure

```
serena-offline-windows-{version}/
├── install.ps1                    # PowerShell installer script
├── install.bat                    # Batch installer wrapper
├── uninstall.ps1                 # Uninstaller script
├── README_OFFLINE.md             # This file
├── LICENSE                       # MIT License
├── bin/                          # Main executables
│   ├── serena.exe               # Main Serena executable
│   ├── serena-mcp-server.exe    # MCP server executable
│   └── index-project.exe        # Project indexer
├── lib/                          # Core libraries
│   ├── python/                  # Python runtime and packages
│   ├── solidlsp/                # Language server integrations
│   └── serena/                  # Core Serena modules
├── language-servers/             # Language server binaries
│   ├── java/                    # Eclipse JDT LS + JRE 21
│   │   ├── jre/                # Java Runtime Environment
│   │   └── server/             # Eclipse JDT Language Server
│   ├── csharp/                  # C# Language Server + .NET Runtime
│   │   ├── dotnet/             # .NET Runtime
│   │   └── server/             # Microsoft.CodeAnalysis.LanguageServer
│   ├── typescript/              # TypeScript/JavaScript support
│   │   ├── node/               # Node.js runtime
│   │   └── server/             # TypeScript Language Server
│   ├── al/                      # AL Language Server
│   ├── python/                  # Pyright language server
│   ├── rust/                    # rust-analyzer (requires rustup)
│   ├── go/                      # gopls (requires Go toolchain)
│   ├── php/                     # Intelephense
│   ├── ruby/                    # ruby-lsp
│   ├── swift/                   # SourceKit-LSP
│   ├── kotlin/                  # Kotlin Language Server
│   ├── dart/                    # Dart Language Server
│   ├── clojure/                 # clojure-lsp
│   ├── elixir/                  # ElixirLS
│   ├── erlang/                  # erlang_ls
│   ├── terraform/               # terraform-ls
│   ├── bash/                    # bash-language-server
│   ├── zig/                     # ZLS
│   ├── lua/                     # lua-language-server
│   ├── nix/                     # nixd
│   └── r/                       # R Language Server
├── config/                       # Configuration files
│   ├── contexts/                # Context definitions
│   ├── modes/                   # Mode definitions
│   └── templates/               # Project templates
├── docs/                        # Documentation
└── examples/                    # Example configurations
    ├── claude-desktop/          # Claude Desktop integration
    ├── vscode/                  # VS Code integration
    └── cursor/                  # Cursor integration
```

### Component Versions

| Component | Version | Description |
|-----------|---------|-------------|
| Serena Agent | v0.1.4 | Core Serena toolkit |
| Python Runtime | 3.11.x | Embedded Python interpreter |
| Pyright | 1.1.396+ | Python language server |
| TypeScript | 5.5.4 | TypeScript compiler |
| TypeScript Language Server | 4.3.3 | TypeScript/JavaScript LSP |
| Node.js | 20.18.2 | JavaScript runtime |
| .NET Runtime | 9.0.6 | .NET runtime for C# |
| C# Language Server | 5.0.0-1.25329.6 | Microsoft Roslyn LSP |
| Java Extension | 1.42.0-561 | VS Code Java extension |
| JRE | 21.0.x | Java Runtime Environment |
| Eclipse JDT LS | Latest | Java language server |
| Gradle | 8.14.2 | Java build tool |
| AL Extension | Latest | Microsoft Dynamics 365 BC |

## Installation Instructions

### Method 1: GUI Installation (Recommended)

1. **Extract the Package**
   ```cmd
   # Extract serena-offline-windows-{version}.zip to desired location
   # Example: C:\Tools\serena-offline\
   ```

2. **Run PowerShell Installer**
   ```powershell
   # Open PowerShell as Administrator
   # Navigate to extracted directory
   cd C:\Tools\serena-offline
   
   # Run installer with GUI prompts
   .\install.ps1
   ```

3. **Follow Installation Prompts**
   - Choose installation directory (default: `C:\Program Files\Serena`)
   - Select language servers to install
   - Configure system PATH integration
   - Set up user configuration directory

### Method 2: Command-Line Installation

1. **Basic Installation**
   ```powershell
   # Run with default settings
   .\install.ps1 -InstallPath "C:\Program Files\Serena" -AddToPath -CreateDesktopShortcut
   ```

2. **Custom Installation**
   ```powershell
   # Customize installation options
   .\install.ps1 `
       -InstallPath "D:\Development\Serena" `
       -ConfigPath "C:\Users\%USERNAME%\.serena" `
       -AddToPath `
       -SkipLanguageServers @("java", "csharp") `
       -Silent
   ```

3. **Batch File Installation**
   ```cmd
   :: Alternative batch wrapper
   install.bat
   ```

### Method 3: Silent/Unattended Installation

For deployment or automated setup:

```powershell
# Complete silent installation
.\install.ps1 `
    -InstallPath "C:\Program Files\Serena" `
    -ConfigPath "%USERPROFILE%\.serena" `
    -AddToPath `
    -CreateDesktopShortcut `
    -SkipInteractive `
    -Silent
```

### Installation Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-InstallPath` | Installation directory | `C:\Program Files\Serena` |
| `-ConfigPath` | User configuration directory | `%USERPROFILE%\.serena` |
| `-AddToPath` | Add to system PATH | `true` |
| `-CreateDesktopShortcut` | Create desktop shortcut | `true` |
| `-SkipLanguageServers` | Skip specific language servers | `@()` |
| `-Silent` | No prompts or dialogs | `false` |
| `-SkipInteractive` | Skip interactive setup | `false` |

## Post-Installation Configuration

### Environment Variables

The installer automatically configures:

```cmd
# System-wide environment variables
SERENA_HOME=C:\Program Files\Serena
SERENA_CONFIG=%USERPROFILE%\.serena
PATH=%PATH%;%SERENA_HOME%\bin

# Language server specific
JAVA_HOME=%SERENA_HOME%\language-servers\java\jre
DOTNET_ROOT=%SERENA_HOME%\language-servers\csharp\dotnet
NODE_HOME=%SERENA_HOME%\language-servers\typescript\node
```

### Language Server Activation

Verify language servers are working:

```powershell
# Test core installation
serena --version

# Test MCP server
serena-mcp-server --help

# Check language server status
serena tools list --show-language-servers

# Test specific language server
serena test-language-server python
serena test-language-server typescript
serena test-language-server csharp
```

### Project Configuration

1. **Initialize Your First Project**
   ```powershell
   # Navigate to your project
   cd C:\Projects\MyProject
   
   # Generate project configuration
   serena project generate-yml
   
   # Edit configuration if needed
   serena config edit
   ```

2. **Global Configuration**
   ```powershell
   # Edit global config
   serena config edit --global
   
   # Add project paths
   serena config add-project "C:\Projects\MyProject"
   ```

### MCP Server Setup

Configure for different clients:

1. **Claude Desktop Integration**
   ```json
   {
       "mcpServers": {
           "serena": {
               "command": "C:\\Program Files\\Serena\\bin\\serena-mcp-server.exe",
               "args": ["--context", "desktop-app", "--transport", "stdio"]
           }
       }
   }
   ```

2. **VS Code Integration**
   ```json
   {
       "mcp.servers": {
           "serena": {
               "command": "serena-mcp-server",
               "args": ["--context", "ide-assistant"]
           }
       }
   }
   ```

## Usage Guide

### Starting Serena MCP Server

1. **Standalone Mode**
   ```powershell
   # Start MCP server in SSE mode
   serena-mcp-server --transport sse --port 9121
   
   # Start with specific project
   serena-mcp-server --project "C:\Projects\MyProject" --context desktop-app
   ```

2. **With Claude Desktop**
   - Configured automatically after installation
   - Restart Claude Desktop to load Serena
   - Look for hammer icon in chat interface

3. **Command-Line Usage**
   ```powershell
   # Activate a project
   serena activate-project "C:\Projects\MyProject"
   
   # Index project for better performance
   serena index-project
   
   # List available tools
   serena tools list
   ```

### Using with Claude.ai

1. **Configure Claude Desktop** (included in package examples)
2. **Activate project** in Claude chat: "Activate project C:\Projects\MyProject"
3. **Use Serena tools**: Claude will have access to all symbolic code tools

### Language Server Management

```powershell
# Check language server status
serena ls status

# Restart specific language server
serena ls restart python

# Configure language server paths
serena ls config typescript --node-path "C:\Tools\nodejs"

# Test language server
serena ls test csharp --project "C:\Projects\CSharpProject"
```

### Memory and Knowledge Base

```powershell
# View project memories
serena memory list

# Create new memory
serena memory create "project-overview" "This project implements..."

# Onboard new project
serena onboard --project "C:\Projects\NewProject"
```

## Troubleshooting

### Common Installation Issues

#### Issue: PowerShell Execution Policy Error
```powershell
# Solution: Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for this session only
powershell -ExecutionPolicy Bypass -File install.ps1
```

#### Issue: Administrator Rights Required
```
# Solution: Run as Administrator
# Right-click PowerShell → "Run as Administrator"
# Or use elevated command prompt
```

#### Issue: Windows Defender Blocking Installation
```
# Solution: Add exclusions
# Windows Security → Virus & threat protection
# → Exclusions → Add folder → Select installation directory
```

### Language Server Problems

#### Python Language Server Not Working
```powershell
# Check Python installation
python --version

# Verify Pyright installation  
serena ls test python

# Reset language server
serena ls reset python
```

#### TypeScript Language Server Issues
```powershell
# Check Node.js
node --version
npm --version

# Verify TypeScript installation
tsc --version

# Test TypeScript language server
serena ls test typescript --project "C:\Projects\TSProject"
```

#### Java Language Server Problems  
```powershell
# Check Java installation
java -version

# Verify JAVA_HOME
echo $env:JAVA_HOME

# Test with specific project
serena ls test java --project "C:\Projects\JavaProject"
```

#### C# Language Server Issues
```powershell
# Check .NET installation
dotnet --version

# Verify .NET runtime
dotnet --list-runtimes

# Test C# language server
serena ls test csharp
```

### Permission Errors

#### Access Denied During Installation
```powershell
# Solution 1: Run as Administrator
# Solution 2: Install to user directory
.\install.ps1 -InstallPath "%LOCALAPPDATA%\Serena" -UserInstall

# Solution 3: Fix permissions
icacls "C:\Program Files\Serena" /grant "%USERNAME%":F /T
```

#### Language Server Process Cannot Start
```powershell
# Check process permissions
Get-Process | Where-Object {$_.Name -like "*serena*"}

# Reset process permissions
serena ls restart --all

# Check Windows firewall
# Windows Security → Firewall → Allow app → Add serena.exe
```

### Path and Environment Issues

#### 'serena' Command Not Found
```cmd
:: Check PATH
echo %PATH%

:: Add manually if needed
set PATH=%PATH%;C:\Program Files\Serena\bin

:: Make permanent
setx PATH "%PATH%;C:\Program Files\Serena\bin"
```

#### Environment Variables Not Set
```powershell
# Check current environment
Get-ChildItem Env: | Where-Object {$_.Name -like "*SERENA*"}

# Reset environment variables
.\install.ps1 -RepairEnvironment

# Manual setup
[Environment]::SetEnvironmentVariable("SERENA_HOME", "C:\Program Files\Serena", "Machine")
```

### Network and Connectivity Issues

#### Language Server Download Failures (Offline Mode)
```
# All dependencies are included offline
# If issues persist:
# 1. Check antivirus quarantine
# 2. Verify file integrity
# 3. Re-extract package
# 4. Run repair installation
.\install.ps1 -Repair
```

#### MCP Server Connection Issues
```powershell
# Test MCP server directly
serena-mcp-server --transport sse --port 9121 --debug

# Check port availability
netstat -an | findstr :9121

# Test connectivity
curl http://localhost:9121/health
```

## Language Server Details

### Fully Offline Languages

These languages work completely offline without external dependencies:

| Language | Server | Version | Runtime Included |
|----------|---------|---------|------------------|
| Python | Pyright | 1.1.396+ | ✅ |
| TypeScript/JavaScript | typescript-language-server | 4.3.3 | ✅ (Node.js 20.18.2) |
| C# | Microsoft.CodeAnalysis.LanguageServer | 5.0.0 | ✅ (.NET 9.0.6) |
| Java | Eclipse JDT LS | Latest | ✅ (JRE 21) |
| AL | AL Language Server | Latest | ✅ |
| PHP | Intelephense | Latest | ✅ |
| Bash | bash-language-server | Latest | ✅ |
| Lua | lua-language-server | Latest | ✅ |

### System-Dependent Languages

These require system installations but work offline once configured:

| Language | Server | System Requirement |
|----------|--------|--------------------|
| Rust | rust-analyzer | rustup toolchain |
| Go | gopls | Go toolchain |
| Ruby | ruby-lsp | Ruby runtime |
| Swift | SourceKit-LSP | Swift toolchain |
| C/C++ | clangd | LLVM/Clang |
| Kotlin | Kotlin Language Server | JVM (included) |
| Dart | Dart Language Server | Dart SDK |
| Clojure | clojure-lsp | JVM (included) |
| Elixir | ElixirLS | Elixir/Erlang |
| Erlang | erlang_ls | Erlang/OTP |
| Terraform | terraform-ls | - |
| Zig | ZLS | Zig compiler |
| Nix | nixd | Nix package manager |
| R | R Language Server | R runtime |

### Feature Comparison: Offline vs Online

| Feature | Offline Package | Online Installation |
|---------|----------------|-------------------|
| Language Server Updates | Manual update required | Automatic updates |
| New Language Support | Package update needed | Install on-demand |
| Package Management | Included in package | Download as needed |
| Internet Requirement | None after installation | Required for updates |
| Storage Space | ~10GB | ~2GB + downloads |
| Installation Speed | Fast (local files) | Depends on network |
| Security | Air-gapped operation | Network dependencies |

## Uninstallation

### Complete Removal

1. **Using Uninstaller Script**
   ```powershell
   # Navigate to installation directory
   cd "C:\Program Files\Serena"
   
   # Run uninstaller
   .\uninstall.ps1
   
   # Remove user data (optional)
   .\uninstall.ps1 -RemoveUserData
   ```

2. **Manual Uninstallation**
   ```powershell
   # Stop all Serena processes
   Get-Process | Where-Object {$_.Name -like "*serena*"} | Stop-Process -Force
   
   # Remove installation directory
   Remove-Item "C:\Program Files\Serena" -Recurse -Force
   
   # Remove from PATH
   $path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
   $newPath = $path -replace ";C:\\Program Files\\Serena\\bin", ""
   [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
   
   # Remove environment variables
   [Environment]::SetEnvironmentVariable("SERENA_HOME", $null, "Machine")
   [Environment]::SetEnvironmentVariable("SERENA_CONFIG", $null, "User")
   ```

### Preserving User Data

To keep project configurations and memories:

```powershell
# Uninstall but keep user data
.\uninstall.ps1 -KeepUserData

# Backup user data before uninstall
Copy-Item "%USERPROFILE%\.serena" "%USERPROFILE%\.serena.backup" -Recurse

# Restore after reinstallation
Copy-Item "%USERPROFILE%\.serena.backup" "%USERPROFILE%\.serena" -Recurse
```

### Registry Cleanup

```cmd
:: Remove Windows registry entries (if created)
reg delete "HKEY_CURRENT_USER\Software\Serena" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Serena" /f

:: Remove file associations
reg delete "HKEY_CLASSES_ROOT\.serena" /f
```

## Technical Details

### Network Isolation Verification

Verify completely offline operation:

```powershell
# Disconnect from internet
# Disable-NetAdapter -Name "Ethernet" -Confirm:$false

# Test Serena functionality
serena --version
serena-mcp-server --transport sse --port 9121 &
serena activate-project "C:\Projects\TestProject"
serena tools list

# Test language servers
serena ls test python --offline
serena ls test typescript --offline
serena ls test csharp --offline
```

### Offline Mode Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Serena Offline Architecture             │
├─────────────────────────────────────────────────────────────┤
│  Client (Claude Desktop, VS Code, etc.)                    │
│                         ↓ MCP Protocol                      │
│  Serena MCP Server                                          │
│                         ↓ LSP                              │
│  SolidLSP (Language Server Abstraction)                    │
│                         ↓                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Language Servers (Local Processes)                      │ │
│  │ ├── Pyright (Python)                                   │ │
│  │ ├── TypeScript LS (Node.js runtime)                    │ │
│  │ ├── C# LS (.NET runtime)                               │ │
│  │ ├── Eclipse JDT LS (JRE runtime)                       │ │
│  │ └── Other language servers...                          │ │
│  └─────────────────────────────────────────────────────────┘ │
│                         ↓                                   │
│  Project Files & Configuration                              │
│  ├── .serena/project.yml                                    │
│  ├── .serena/memories/                                      │
│  └── Source code                                           │
└─────────────────────────────────────────────────────────────┘
```

### Local Cache Structure

```
%USERPROFILE%\.serena/
├── config/
│   ├── serena_config.yml        # Global configuration
│   ├── contexts/                # Custom contexts
│   └── modes/                   # Custom modes
├── cache/
│   ├── language_servers/        # LS runtime cache
│   ├── project_indexes/         # Indexed project data
│   └── symbols/                 # Symbol cache
├── logs/
│   ├── serena.log              # Main application log
│   ├── mcp_server.log          # MCP server log
│   └── language_servers/       # Individual LS logs
└── projects/
    └── {project_name}/
        ├── project.yml         # Project configuration
        ├── memories/           # Project-specific memories
        └── .serena_index       # Project symbol index
```

### Security Considerations

- **Air-gapped Operation**: Completely offline after installation
- **Process Isolation**: Language servers run in separate processes
- **File System Permissions**: Respects Windows file permissions
- **Code Execution**: Only executes code through configured interpreters
- **Memory Safety**: No persistent sensitive data storage
- **Network Isolation**: No outbound connections in offline mode

---

## Support and Resources

### Documentation
- **Main README**: [README.md](README.md)
- **Contributing Guide**: [CONTRIBUTING.md](CONTRIBUTING.md)
- **Change Log**: [CHANGELOG.md](CHANGELOG.md)
- **API Documentation**: Available at `http://localhost:24282/docs` when running

### Getting Help

1. **Check Logs**: `%USERPROFILE%\.serena\logs\`
2. **Run Diagnostics**: `serena diagnose --full`
3. **GitHub Issues**: [https://github.com/oraios/serena/issues](https://github.com/oraios/serena/issues)
4. **Community Forum**: Available through GitHub Discussions

### Version Information

- **Package Version**: v0.1.4-offline-windows
- **Build Date**: Generated during packaging
- **Included Components**: See [Component Versions](#component-versions)
- **Compatibility**: Windows 10 (1903+), Windows 11, Windows Server 2019+

---

**MIT License** | **Copyright © 2024 Oraios AI** | **Built with ❤️ for the developer community**