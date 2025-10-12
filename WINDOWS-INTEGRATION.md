# Serena MCP Portable - Windows Integration Guide

Comprehensive integration guide for Windows environments.

## Table of Contents

- [Claude Code Integration](#claude-code-integration)
- [Claude Desktop Integration](#claude-desktop-integration)
- [VS Code Integration](#vs-code-integration)
- [JetBrains IDE Integration](#jetbrains-ide-integration)
- [PowerShell Profile Integration](#powershell-profile-integration)
- [Windows Terminal Integration](#windows-terminal-integration)
- [WSL Integration](#wsl-integration)
- [Cursor IDE Integration](#cursor-ide-integration)
- [Windsurf Integration](#windsurf-integration)
- [Other MCP Clients](#other-mcp-clients)
- [Automation and Scripting](#automation-and-scripting)
- [Enterprise Deployment](#enterprise-deployment)

## Claude Code Integration

Claude Code is a command-line AI coding assistant with MCP support.

### Installation

**Install Claude Code:**
```cmd
npm install -g @anthropic-ai/claude-code
```

Or visit: https://claude.ai/code

### Basic Setup

**Add Serena to Claude Code** (from your project directory):

```cmd
cd C:\Users\YourName\Projects\MyProject
claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd%
```

This creates an MCP configuration for the current project.

### Configuration Details

Claude Code stores MCP configuration in `.claude\mcp.json` in your project root:

```json
{
  "mcpServers": {
    "serena": {
      "command": "serena",
      "args": ["start-mcp-server", "--context", "ide-assistant", "--project", "C:\\Users\\YourName\\Projects\\MyProject"]
    }
  }
}
```

### Advanced Configuration

**Custom context and modes:**
```cmd
claude mcp add serena -- serena start-mcp-server --context ide-assistant --mode interactive --mode planning --project %cd%
```

**Specific language server bundle:**
```cmd
claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd% --log-level INFO
```

**With custom port (if default conflicts):**
```cmd
claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd% --port 9000
```

### Using Serena in Claude Code

**Start Claude Code:**
```cmd
cd C:\Users\YourName\Projects\MyProject
claude
```

**Initial prompt (recommended):**
```
Read Serena's initial instructions and give me an overview of this codebase.
```

**Example interactions:**

```
# Symbol-aware operations
Find the class definition for UserAuthentication

Show me all functions that call send_email

Get an overview of the symbols in src/main.py

# Editing operations
Insert a new method "validate_input" after the "process_request" method in handlers.py

Replace the body of the "calculate_tax" function with [new implementation]

# Analysis
Find all files that import the "database" module

Show me what references the "User" class
```

### Troubleshooting Claude Code

**Issue: MCP server not starting**

Check configuration:
```cmd
type .claude\mcp.json
```

View logs:
```cmd
type "%USERPROFILE%\.claude\logs\mcp-serena.log"
```

**Issue: Tools not available**

Remove and re-add:
```cmd
claude mcp remove serena
claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd%
```

**Issue: Serena instructions not loading**

Manually trigger:
```
/mcp__serena__initial_instructions
```

Or ask:
```
Read Serena's initial instructions
```

### Per-Project vs Global Configuration

**Per-project** (recommended):
- Configuration in `.claude\mcp.json` in project root
- Each project can have different Serena settings
- Use `--project %cd%` to auto-activate

**Global** (not recommended):
- Configuration in `%USERPROFILE%\.claude\config.json`
- Same Serena settings for all projects
- Must manually activate project each session

## Claude Desktop Integration

Claude Desktop is a desktop application for chatting with Claude AI.

### Prerequisites

**Install Claude Desktop:**
- Download: https://claude.ai/download
- Install normally (requires admin rights)
- Available for Windows 10/11

### Configuration Location

Claude Desktop MCP configuration:
```
%APPDATA%\Claude\claude_desktop_config.json
```

Or access via:
1. Open Claude Desktop
2. File > Settings > Developer
3. MCP Servers > Edit Config

### Basic Configuration

**Minimal setup:**

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server"]
        }
    }
}
```

**Recommended setup:**

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": [
                "start-mcp-server",
                "--context", "desktop-app",
                "--mode", "interactive"
            ]
        }
    }
}
```

**With auto-project activation:**

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": [
                "start-mcp-server",
                "--context", "desktop-app",
                "--project", "C:\\Users\\YourName\\Projects\\MainProject"
            ]
        }
    }
}
```

### Multiple Projects Configuration

If you work with multiple projects, DON'T auto-activate in config:

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "desktop-app"]
        }
    }
}
```

Then activate projects as needed in conversations:
```
Activate the project C:\Users\YourName\Projects\Project1
```

### Advanced Configuration

**Full path to serena.exe (if PATH issues):**

```json
{
    "mcpServers": {
        "serena": {
            "command": "C:\\Users\\YourName\\Documents\\serena-portable\\serena.exe",
            "args": ["start-mcp-server", "--context", "desktop-app"]
        }
    }
}
```

**With debug logging:**

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": [
                "start-mcp-server",
                "--context", "desktop-app",
                "--log-level", "DEBUG"
            ],
            "env": {
                "SERENA_DEBUG": "1"
            }
        }
    }
}
```

**With multiple MCP servers:**

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "desktop-app"]
        },
        "filesystem": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:\\Users\\YourName\\Projects"]
        },
        "brave-search": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-brave-search"],
            "env": {
                "BRAVE_API_KEY": "your-key-here"
            }
        }
    }
}
```

### Using Serena in Claude Desktop

**Activate a project:**
```
Activate the project C:\Users\YourName\Projects\MyProject
```

**Index for performance:**
```
Index the current project
```

**Use Serena's tools:**
```
Find the class UserService in this project

Show me the structure of main.py

Find all references to the authenticate function
```

### Troubleshooting Claude Desktop

**Issue: Changes not taking effect**

1. **Fully quit Claude Desktop** (don't just close window!)
   - Right-click system tray icon
   - Click "Quit"
   - Or: Task Manager > End Task on Claude.exe

2. **Verify config is valid JSON:**
   - Use JSON validator: https://jsonlint.com/
   - Check for missing commas, quotes, brackets

3. **Check paths use double backslashes:**
   ```json
   "C:\\Users\\YourName\\Documents\\serena-portable"
   ```
   NOT:
   ```json
   "C:\Users\YourName\Documents\serena-portable"
   ```

**Issue: Tools not appearing**

1. Look for hammer/tool icon in chat interface
2. Or ask: "List available tools"
3. Check Claude Desktop logs:
   ```
   %APPDATA%\Claude\logs\
   ```

**Issue: Serena starts but tools fail**

Check Serena logs:
```cmd
type "%USERPROFILE%\.serena\logs\mcp_server.log"
```

Enable debug mode in config:
```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "desktop-app", "--log-level", "DEBUG"]
        }
    }
}
```

## VS Code Integration

Visual Studio Code can integrate with Serena through extensions supporting MCP.

### Supported Extensions

1. **Cline** (formerly Claude-Dev)
2. **Roo-Code**
3. **Continue**

### Cline Integration

**Install Cline:**
1. Open VS Code
2. Extensions (Ctrl+Shift+X)
3. Search "Cline"
4. Install

**Configure Cline:**

1. Open Command Palette (Ctrl+Shift+P)
2. Type "Cline: Open Settings"
3. Or: Settings (Ctrl+,) > Search "Cline"

**Add Serena to Cline settings.json:**

```json
{
    "cline.mcpServers": {
        "serena": {
            "command": "serena",
            "args": [
                "start-mcp-server",
                "--context", "ide-assistant",
                "--project", "${workspaceFolder}"
            ]
        }
    }
}
```

**Using variable expansion:**
- `${workspaceFolder}` - Current workspace root
- `${workspaceFolderBasename}` - Workspace folder name
- `${file}` - Currently open file
- `${fileWorkspaceFolder}` - Workspace of current file

### Roo-Code Integration

**Install Roo-Code:**
1. Extensions > Search "Roo-Code"
2. Install

**Configure:**

Settings > Roo-Code > MCP Servers:

```json
{
    "roo-code.mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "ide-assistant"]
        }
    }
}
```

### Continue Integration

**Install Continue:**
1. Extensions > Search "Continue"
2. Install

**Configure:**

Create/edit `%USERPROFILE%\.continue\config.json`:

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "ide-assistant"]
        }
    }
}
```

### General VS Code Tips

**Workspace-specific configuration:**

Create `.vscode/settings.json` in your project:

```json
{
    "cline.mcpServers": {
        "serena": {
            "command": "serena",
            "args": [
                "start-mcp-server",
                "--context", "ide-assistant",
                "--project", "${workspaceFolder}"
            ]
        }
    }
}
```

This applies only to this workspace.

**Opening Serena logs from VS Code:**

Add to tasks.json:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "View Serena Logs",
            "type": "shell",
            "command": "type",
            "args": [
                "${env:USERPROFILE}\\.serena\\logs\\mcp_server.log"
            ],
            "problemMatcher": []
        }
    ]
}
```

Run: Terminal > Run Task > View Serena Logs

## JetBrains IDE Integration

JetBrains IDEs (IntelliJ IDEA, PyCharm, WebStorm, etc.) have experimental MCP support.

### Prerequisites

- JetBrains IDE 2024.1 or later
- MCP Plugin (check JetBrains Marketplace)

### Installation

1. **Install MCP Plugin:**
   - File > Settings > Plugins
   - Search "Model Context Protocol" or "MCP"
   - Install and restart

2. **Configure Serena:**
   - File > Settings > Tools > MCP Servers
   - Add new server:
     - Name: `serena`
     - Command: `serena`
     - Arguments: `start-mcp-server --context ide-assistant`

### Configuration File

JetBrains stores MCP config in:
```
%APPDATA%\JetBrains\[IDE][Version]\mcp.json
```

Example:
```json
{
    "servers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "ide-assistant"]
        }
    }
}
```

### Using Serena in JetBrains

**Access through AI Assistant:**
1. Open AI Assistant panel
2. Type prompts like:
   ```
   Find the class UserService using Serena

   Show me the structure of this file using Serena's tools
   ```

### Troubleshooting JetBrains

**Issue: MCP plugin not available**

JetBrains MCP support is experimental. Check:
- IDE version is 2024.1+
- Plugin marketplace for availability
- JetBrains blog for announcements

**Alternative: Use External Tools**

Configure Serena as an external tool:
1. File > Settings > Tools > External Tools
2. Add tool:
   - Name: `Serena Activate Project`
   - Program: `serena`
   - Arguments: `project activate $ProjectFileDir$`
   - Working directory: `$ProjectFileDir$`

## PowerShell Profile Integration

Enhance PowerShell with Serena shortcuts.

### Edit PowerShell Profile

```powershell
# Open profile in Notepad
notepad $PROFILE

# Or in VS Code
code $PROFILE
```

If file doesn't exist:
```powershell
New-Item -Path $PROFILE -Type File -Force
```

### Useful Additions

**Serena aliases:**

```powershell
# Aliases for common operations
Set-Alias -Name serena-start -Value "serena start-mcp-server"
Set-Alias -Name serena-logs -Value "Get-Content $env:USERPROFILE\.serena\logs\mcp_server.log -Tail 50 -Wait"

# Function to quickly activate project
function Serena-Activate {
    param([string]$Path = $PWD.Path)
    serena project activate $Path
}

# Function to index current project
function Serena-Index {
    param([string]$Path = $PWD.Path)
    serena project index $Path
}

# Function to open Serena dashboard
function Serena-Dashboard {
    Start-Process "http://localhost:24282/dashboard/index.html"
}

# Function to view Serena logs
function Serena-Logs {
    param(
        [string]$Type = "mcp",
        [int]$Lines = 50
    )

    $logPath = "$env:USERPROFILE\.serena\logs\"

    switch ($Type) {
        "mcp" { Get-Content "$logPath\mcp_server.log" -Tail $Lines -Wait }
        "lsp" { Get-Content "$logPath\lsp\*.log" -Tail $Lines }
        "all" { Get-ChildItem "$logPath" -Recurse -Filter "*.log" | Get-Content -Tail $Lines }
    }
}

# Quick project activation in current directory
function Here {
    Serena-Activate $PWD.Path
}
```

**Auto-completion for Serena:**

```powershell
# Register argument completer for serena commands
Register-ArgumentCompleter -CommandName serena -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $subcommands = @(
        'start-mcp-server',
        'project',
        'config',
        'tools',
        'context',
        'mode'
    )

    $subcommands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
```

**Environment variables:**

```powershell
# Set Serena environment
$env:SERENA_LOG_LEVEL = "INFO"
$env:SERENA_PORT = "24282"
```

### Reload Profile

```powershell
. $PROFILE
```

### Usage After Profile Setup

```powershell
# Activate current directory
Here

# View logs
Serena-Logs
Serena-Logs -Type lsp
Serena-Logs -Type all -Lines 100

# Open dashboard
Serena-Dashboard

# Index project
Serena-Index C:\Projects\MyProject
```

## Windows Terminal Integration

Configure Windows Terminal for optimal Serena usage.

### Install Windows Terminal

```cmd
winget install Microsoft.WindowsTerminal
```

Or from Microsoft Store: "Windows Terminal"

### Configuration Location

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json
```

Or: Settings (Ctrl+,) in Windows Terminal

### Add Serena Profile

Add to `profiles` > `list`:

```json
{
    "guid": "{serena-guid-here}",
    "name": "Serena Development",
    "commandline": "powershell.exe -NoExit -Command \"cd C:\\Users\\YourName\\Projects; Write-Host 'Serena Development Environment' -ForegroundColor Green\"",
    "startingDirectory": "C:\\Users\\YourName\\Projects",
    "icon": "C:\\Users\\YourName\\Documents\\serena-portable\\icon.png",
    "colorScheme": "Serena Dark"
}
```

Generate unique GUID:
```powershell
[guid]::NewGuid().ToString()
```

### Custom Color Scheme

Add to `schemes`:

```json
{
    "name": "Serena Dark",
    "background": "#1e1e1e",
    "foreground": "#d4d4d4",
    "black": "#000000",
    "blue": "#569cd6",
    "cyan": "#4ec9b0",
    "green": "#6a9955",
    "purple": "#c586c0",
    "red": "#f44747",
    "white": "#d4d4d4",
    "yellow": "#dcdcaa",
    "brightBlack": "#666666",
    "brightBlue": "#569cd6",
    "brightCyan": "#4ec9b0",
    "brightGreen": "#6a9955",
    "brightPurple": "#c586c0",
    "brightRed": "#f44747",
    "brightWhite": "#ffffff",
    "brightYellow": "#dcdcaa"
}
```

### Keyboard Shortcuts

Add to `actions`:

```json
{
    "command": {
        "action": "newTab",
        "commandline": "serena start-mcp-server",
        "startingDirectory": "%USERPROFILE%\\Projects"
    },
    "keys": "ctrl+shift+s"
}
```

## WSL Integration

Use Serena with Windows Subsystem for Linux.

### Prerequisites

**Install WSL:**
```cmd
wsl --install
```

**Install Ubuntu (or preferred distro):**
```cmd
wsl --install -d Ubuntu
```

### Approach 1: Use Windows Serena from WSL

**Access Windows executables from WSL:**

```bash
# Create alias in ~/.bashrc or ~/.zshrc
alias serena='/mnt/c/Users/YourName/Documents/serena-portable/serena.exe'

# Use with Windows paths
serena project activate /mnt/c/Users/YourName/Projects/MyProject
```

**Convert WSL paths:**

```bash
# Helper function
wslpath-to-win() {
    wslpath -w "$1"
}

# Use it
serena project activate "$(wslpath-to-win ~/myproject)"
```

### Approach 2: Install Serena in WSL

**Clone and build Serena in WSL:**

```bash
# Install prerequisites
sudo apt update
sudo apt install python3.11 python3.11-venv python3-pip git

# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh

# Clone Serena
git clone https://github.com/oraios/serena.git
cd serena

# Setup
uv venv --python 3.11
source .venv/bin/activate
uv pip install -e ".[dev]"

# Use Serena
uv run serena start-mcp-server
```

### Integration with WSL2

**Configure Claude Desktop to use WSL Serena:**

```json
{
    "mcpServers": {
        "serena-wsl": {
            "command": "wsl",
            "args": [
                "-d", "Ubuntu",
                "-e", "/home/username/serena/.venv/bin/python",
                "-m", "serena.cli",
                "start-mcp-server"
            ]
        }
    }
}
```

### Networking Considerations

**WSL2 has separate network:**

- Windows: `localhost` or `127.0.0.1`
- WSL2: Separate IP (check with `ip addr`)

**Access WSL2 services from Windows:**
```bash
# In WSL, get IP
ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

Use this IP in Windows: `http://[WSL-IP]:24282`

**Access Windows services from WSL:**
```bash
# Use Windows host IP
cat /etc/resolv.conf | grep nameserver | awk '{print $2}'
```

## Cursor IDE Integration

Cursor is an AI-first IDE based on VS Code.

### Installation

Download: https://cursor.sh/

### Configuration

Cursor has built-in MCP support.

**Add Serena:**
1. Settings (Ctrl+,)
2. Search "MCP"
3. Edit MCP configuration:

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": [
                "start-mcp-server",
                "--context", "ide-assistant",
                "--project", "${workspaceFolder}"
            ]
        }
    }
}
```

### Using Serena in Cursor

**Cursor's AI chat:**
- Press Ctrl+L to open AI chat
- Use Serena tools through natural language:

```
Find the UserService class definition

Show me an overview of main.py's structure

Find all references to the authenticate function
```

## Windsurf Integration

Windsurf is another AI-powered IDE.

### Configuration

Similar to Cursor, Windsurf supports MCP.

**Settings > MCP Servers:**

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "ide-assistant"]
        }
    }
}
```

## Other MCP Clients

### Jan.ai

Jan is a local AI application supporting MCP.

**Configuration:**

Create/edit `%USERPROFILE%\.jan\config.json`:

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "agent"]
        }
    }
}
```

### OpenWebUI

OpenWebUI is a self-hosted AI interface.

**Configuration through UI:**
1. Settings > MCP Servers
2. Add new server:
   - Name: Serena
   - Command: `serena start-mcp-server --transport streamable-http --port 9000`
   - URL: `http://localhost:9000/mcp`

### Codex CLI

OpenAI's Codex CLI.

**Configuration:**

Edit `%USERPROFILE%\.codex\config.toml`:

```toml
[mcp_servers.serena]
command = "serena"
args = ["start-mcp-server", "--context", "codex"]
```

**Usage:**
```
Activate the current dir as project using serena
```

## Automation and Scripting

### Batch Scripts

**Create `serena-activate.bat`:**

```batch
@echo off
REM Activate current directory as Serena project

echo Activating project in: %CD%
serena project activate "%CD%"

if %ERRORLEVEL% EQU 0 (
    echo ✓ Project activated successfully
    serena project index "%CD%"
) else (
    echo ✗ Project activation failed
    exit /b 1
)
```

**Create `serena-start.bat`:**

```batch
@echo off
REM Start Serena MCP server with project

set PROJECT_DIR=%1
if "%PROJECT_DIR%"=="" set PROJECT_DIR=%CD%

echo Starting Serena for: %PROJECT_DIR%
start "Serena MCP Server" serena start-mcp-server --project "%PROJECT_DIR%" --context desktop-app

echo Serena MCP Server started
echo Dashboard: http://localhost:24282/dashboard/index.html
```

### PowerShell Scripts

**Create `Serena-DevSession.ps1`:**

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

# Activate project
Write-Host "Activating project: $ProjectPath" -ForegroundColor Green
serena project activate $ProjectPath

# Index project
Write-Host "Indexing project for performance..." -ForegroundColor Yellow
serena project index $ProjectPath

# Start dashboard
Write-Host "Opening Serena dashboard..." -ForegroundColor Cyan
Start-Process "http://localhost:24282/dashboard/index.html"

# Start VS Code
Write-Host "Opening project in VS Code..." -ForegroundColor Magenta
code $ProjectPath

Write-Host "`n✓ Development session ready!" -ForegroundColor Green
```

**Usage:**
```powershell
.\Serena-DevSession.ps1 -ProjectPath "C:\Projects\MyProject"
```

### Task Scheduler Integration

Automate Serena tasks with Windows Task Scheduler.

**Create task to index projects nightly:**

```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\Scripts\index-projects.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "Serena Project Indexing" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
```

**Script: `index-projects.ps1`:**

```powershell
$projects = @(
    "C:\Users\$env:USERNAME\Projects\Project1",
    "C:\Users\$env:USERNAME\Projects\Project2"
)

foreach ($project in $projects) {
    Write-Output "Indexing $project"
    serena project index $project
}
```

## Enterprise Deployment

### Group Policy Deployment

**Create GPO for Serena installation:**

1. **Package Serena:**
   - Create MSI installer or use portable ZIP
   - Store on network share: `\\server\software\serena\`

2. **Create deployment script:**

`install-serena.ps1`:
```powershell
# Copy Serena to user profile
$sourceDir = "\\server\software\serena\serena-portable"
$targetDir = "$env:LOCALAPPDATA\Serena"

if (!(Test-Path $targetDir)) {
    Copy-Item -Path $sourceDir -Destination $targetDir -Recurse
}

# Add to PATH
$path = [Environment]::GetEnvironmentVariable("Path", "User")
if ($path -notlike "*$targetDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$path;$targetDir", "User")
}

# Create start menu shortcut
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Serena.lnk")
$shortcut.TargetPath = "$targetDir\serena.exe"
$shortcut.Save()
```

3. **Deploy via GPO:**
   - Group Policy Management
   - Create new GPO: "Deploy Serena"
   - Computer/User Configuration > Policies > Windows Settings > Scripts > Logon
   - Add `install-serena.ps1`

### SCCM/Intune Deployment

**Create application package:**

1. **Package details:**
   - Name: Serena MCP Portable
   - Version: 1.0
   - Publisher: Oraios AI
   - Install command: `powershell -ExecutionPolicy Bypass -File install-serena.ps1`
   - Uninstall command: `powershell -ExecutionPolicy Bypass -File uninstall-serena.ps1`

2. **Detection method:**
   - File exists: `%LOCALAPPDATA%\Serena\serena.exe`
   - Version: Check file version

3. **Requirements:**
   - OS: Windows 10 1809+
   - Architecture: x64 or ARM64

### Centralized Configuration Management

**Deploy standard configuration:**

Create `%USERPROFILE%\.serena\serena_config.yml` via GPO:

```yaml
# Standard enterprise configuration
enable_web_dashboard: false  # Disable for security
log_level: WARNING
auto_download_language_servers: false  # Pre-bundle instead

# Security settings
security:
  restrict_file_access: true
  allowed_directories:
    - "C:\\Projects"
    - "%USERPROFILE%\\Documents\\Code"
  blocked_directories:
    - "C:\\Windows"
    - "C:\\Program Files"

# Logging
logging:
  central_logging: true
  log_server: "logs.company.com:514"
  log_format: "json"
```

### License Compliance

For enterprise use, ensure compliance with:
- Serena's open-source license
- Individual language server licenses
- Dependencies licenses

**Generate compliance report:**

```powershell
# Create license report
serena tools list > licenses.txt
# Add language server licenses
# Add dependency licenses
```

---

## Summary

Serena MCP Portable integrates seamlessly with major Windows development tools:

**CLI Tools:**
- ✓ Claude Code - Full integration with per-project config
- ✓ Codex CLI - Global configuration with context
- ✓ PowerShell - Enhanced with profile customizations

**Desktop Applications:**
- ✓ Claude Desktop - JSON configuration, multiple projects
- ✓ Jan.ai - Local AI with MCP support

**IDEs:**
- ✓ VS Code - Via Cline, Roo-Code, Continue extensions
- ✓ Cursor - Built-in MCP support
- ✓ Windsurf - Native MCP integration
- ⚠️ JetBrains - Experimental MCP plugin

**Advanced:**
- ✓ WSL - Use Windows Serena or native Linux build
- ✓ Windows Terminal - Custom profiles and shortcuts
- ✓ Task Scheduler - Automated project indexing
- ✓ Enterprise - GPO/SCCM deployment

Choose the integration that best fits your workflow!

---

**Serena MCP Portable - Windows Integration Guide**
Version: 1.0 | Last Updated: 2025-01-16
For more information: https://github.com/oraios/serena
