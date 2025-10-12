# Serena MCP Portable - Windows Quickstart Guide

Complete setup and usage guide for Windows 10/11 users.

## Table of Contents

- [System Requirements](#system-requirements)
- [Installation](#installation)
- [First-Time Setup](#first-time-setup)
- [Using Serena](#using-serena)
- [Claude Code Integration](#claude-code-integration)
- [Claude Desktop Integration](#claude-desktop-integration)
- [IDE Integration](#ide-integration)
- [Testing Your Installation](#testing-your-installation)
- [Example Usage Scenarios](#example-usage-scenarios)
- [Configuration](#configuration)
- [Command Reference](#command-reference)
- [Next Steps](#next-steps)

## System Requirements

### Minimum Requirements
- **Operating System**: Windows 10 (version 1809 or later) or Windows 11
- **Architecture**: x64 (64-bit Intel/AMD) or ARM64 (Windows on ARM)
- **Processor**: Any modern CPU (2+ cores recommended)
- **Memory**: 2GB RAM minimum, 4GB+ recommended
- **Storage**:
  - Minimal tier: 50MB free space
  - Essential tier: 200MB free space
  - Complete tier: 500MB free space
  - Full tier: 800MB free space

### Recommended Setup
- **Windows 11** with latest updates
- **4GB+ RAM** for smooth operation
- **SSD storage** for faster language server startup
- **Internet connection** for initial setup (if language servers not pre-bundled)

### Optional Dependencies
Some language servers may require additional runtimes:
- **Node.js 20+** - For JavaScript/TypeScript support (if not bundled)
- **Java 17+** - For Java/Kotlin support (if not bundled)
- **.NET 8.0+** - For C# support (if not bundled)
- **Python 3.11+** - For Python analysis (optional, Pyright works without it)

## Installation

### Step 1: Download Serena Portable

Choose the right bundle for your needs:

| Bundle Tier | Size | Languages Included | Best For |
|------------|------|-------------------|----------|
| **minimal** | ~50MB | None | Custom setups, testing |
| **essential** | ~200MB | Python, TypeScript, Rust, Go | Most developers (RECOMMENDED) |
| **complete** | ~500MB | Essential + Java, C#, Lua, Bash | Full-stack development |
| **full** | ~800MB | All 24+ languages | Enterprise, polyglot projects |

Download from: https://github.com/oraios/serena/releases

Choose the file matching your system:
- **x64 systems**: `serena-windows-x64-[tier]-v*.zip`
- **ARM64 systems**: `serena-windows-arm64-[tier]-v*.zip`

> **Note**: Most Windows PCs use x64. ARM64 is for Windows on ARM devices (Surface Pro X, some laptops).

### Step 2: Extract the Archive

Extract the ZIP file to your preferred location:

**Recommended locations:**
- Personal use: `C:\Users\YourName\Documents\serena-portable`
- Portable use: `E:\serena-portable` (USB drive)
- Shared use: `\\server\shared\tools\serena-portable` (network share)

**How to extract:**
1. Right-click the ZIP file
2. Select "Extract All..."
3. Choose your destination folder
4. Click "Extract"

> **Important**: Do not extract to `C:\Program Files` or `C:\Windows` - these require admin rights.

### Step 3: Run First-Time Setup

Double-click `first-run.bat` in the extracted folder.

**What it does:**
1. Adds Serena to your system PATH
2. Creates user configuration directory
3. Tests the installation
4. Downloads language servers (if needed)

**If you see "Windows protected your PC":**

This is Windows SmartScreen warning about unsigned executables.

![SmartScreen warning description: Blue dialog with "Windows protected your PC" title]

To proceed:
1. Click "More info"
2. Click "Run anyway"

**Alternative:** Right-click `first-run.bat` > "Run as administrator"

### Step 4: Verify Installation

Open a **NEW** Command Prompt or PowerShell window and type:

```cmd
serena --version
```

Expected output:
```
Serena MCP Server v0.1.4
Platform: Windows 10/11 (x64)
Bundle: essential
```

If you see this, installation is complete!

If not, see [Troubleshooting](#troubleshooting) below.

## First-Time Setup

### Understanding Serena's File Structure

After installation, Serena uses these locations:

```
Installation Directory (where you extracted)
├── serena.exe              # Main executable
├── first-run.bat           # Setup script
├── README-WINDOWS.txt      # Quick start guide
└── language-servers/       # Bundled language servers (if any)

User Configuration (%USERPROFILE%\.serena\)
├── serena_config.yml       # Global configuration
├── logs/                   # Application logs
│   ├── mcp_server.log
│   └── lsp/                # Language server logs
└── language_servers/       # Downloaded language servers

Project Configuration (per project)
YourProject\.serena\
├── project.yml             # Project settings
├── memories/               # Project knowledge base
└── logs/                   # Project-specific logs
```

### Configuration Basics

Serena works with default settings, but you can customize:

**Global configuration**: `%USERPROFILE%\.serena\serena_config.yml`

To edit:
```cmd
serena config edit
```

**Per-project configuration**: Created automatically when you activate a project.

### Adding to PATH (Manual)

If `first-run.bat` didn't work, add to PATH manually:

**For current user (recommended):**
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Click "Environment Variables"
3. Under "User variables", select "Path"
4. Click "Edit"
5. Click "New"
6. Add the full path where you extracted Serena (e.g., `C:\Users\YourName\Documents\serena-portable`)
7. Click "OK" on all dialogs
8. **Close and reopen** any Command Prompt/PowerShell windows

**For system-wide access (requires admin):**
Same steps, but edit "Path" under "System variables" instead.

## Using Serena

### Starting the MCP Server

The MCP server allows AI assistants to use Serena's tools.

**Basic start:**
```cmd
serena start-mcp-server
```

**With a specific project:**
```cmd
serena start-mcp-server --project "C:\path\to\your\project"
```

**With context and mode:**
```cmd
serena start-mcp-server --context desktop-app --mode interactive
```

> **Note**: Usually, you don't start the MCP server manually. Your AI client (Claude Code, Claude Desktop, etc.) starts it automatically.

### Project Operations

**Activate a project:**
```cmd
serena project activate "C:\Users\YourName\Projects\MyProject"
```

**Index a project (improves performance):**
```cmd
serena project index "C:\Users\YourName\Projects\MyProject"
```

**Generate project configuration:**
```cmd
serena project generate-yml "C:\Users\YourName\Projects\MyProject"
```

**Check project health:**
```cmd
serena project health-check "C:\Users\YourName\Projects\MyProject"
```

### Viewing Logs

**Dashboard** (web interface):

When Serena starts, it opens a web dashboard at:
```
http://localhost:24282/dashboard/index.html
```

Access it in your browser to see logs and usage statistics.

**Log files** (manual inspection):
```cmd
# View main MCP server log
type "%USERPROFILE%\.serena\logs\mcp_server.log"

# View Python language server log
type "%USERPROFILE%\.serena\logs\lsp\python.log"

# View all recent logs
dir "%USERPROFILE%\.serena\logs" /s /b
```

## Claude Code Integration

Claude Code is a command-line AI assistant that works with your codebase.

### Prerequisites

Install Claude Code first:
```cmd
npm install -g claude-code
```

### Add Serena to Claude Code

From your project directory:

```cmd
cd C:\Users\YourName\Projects\MyProject
claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd%
```

**Explanation:**
- `claude mcp add serena` - Adds Serena as an MCP server
- `--context ide-assistant` - Optimizes for IDE-like usage
- `--project %cd%` - Auto-activates current directory as project

### Using Serena in Claude Code

Start Claude Code:
```cmd
claude
```

In Claude Code, you can now:

**Ask it to read instructions:**
```
Read Serena's initial instructions
```

**Use Serena's tools:**
```
Find the symbol "UserAuthentication" in this project
```

```
Show me an overview of main.py's top-level symbols
```

```
Find all references to the function "process_payment"
```

### Recommended First Prompt

After starting Claude Code, say:

```
Read Serena's instructions and activate this project. Then give me an overview of the codebase structure.
```

## Claude Desktop Integration

Claude Desktop is a desktop application for chatting with Claude AI.

### Prerequisites

Download and install Claude Desktop:
- Download: https://claude.ai/download
- Install normally (requires admin rights)

### Add Serena to Claude Desktop

1. **Open Claude Desktop**

2. **Open MCP Settings:**
   - Go to: File > Settings
   - Click "Developer"
   - Under "MCP Servers", click "Edit Config"

3. **Edit Configuration File:**

   This opens `claude_desktop_config.json` in Notepad.

   Add the following (replace the entire content if file is empty):

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

   **Important**: If you have other MCP servers, add Serena alongside them:

   ```json
   {
       "mcpServers": {
           "serena": {
               "command": "serena",
               "args": ["start-mcp-server", "--context", "desktop-app"]
           },
           "other-server": {
               "command": "other-command",
               "args": ["arg1", "arg2"]
           }
       }
   }
   ```

4. **Save and Close** the file

5. **Fully Quit Claude Desktop**
   - Right-click Claude icon in system tray
   - Click "Quit"
   - Do NOT just close the window (it minimizes to tray)

6. **Restart Claude Desktop**

### Verify Serena is Connected

In a new chat:

1. Click the small hammer/tool icon (if available)
2. You should see Serena's tools listed

Or simply say:
```
List available Serena tools
```

### Using Serena in Claude Desktop

**Activate your project:**
```
Activate the project C:\Users\YourName\Projects\MyProject
```

**Index large projects:**
```
Index the current project for better performance
```

**Use Serena's tools:**
```
Find the class definition for "DatabaseConnection"
```

```
Show me all functions that call "send_email"
```

```
Get an overview of src/app.py's structure
```

## IDE Integration

Serena can integrate with IDEs through extensions that support MCP servers.

### Visual Studio Code (with Cline/Roo-Code)

**Prerequisites:**
- Install Visual Studio Code
- Install Cline or Roo-Code extension

**Configuration:**

1. Open VS Code Settings (Ctrl+,)
2. Search for "MCP"
3. Add Serena configuration:

```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "ide-assistant", "--project", "${workspaceFolder}"]
        }
    }
}
```

### Cursor IDE

Cursor has built-in MCP support.

1. Open Cursor Settings
2. Navigate to "Model Context Protocol"
3. Add Serena:

```json
{
    "command": "serena",
    "args": ["start-mcp-server", "--context", "ide-assistant"]
}
```

### Windsurf

Similar to Cursor:

1. Settings > MCP Servers
2. Add Serena configuration

### JetBrains IDEs (IntelliJ, PyCharm, WebStorm)

Support through MCP plugins (experimental):

1. Install MCP plugin from JetBrains Marketplace
2. Configure Serena as MCP server

> **Note**: JetBrains support is experimental. Check plugin documentation.

## Testing Your Installation

### Quick Tests

**Test 1: Version Check**
```cmd
serena --version
```

Expected: Version information displays

**Test 2: Help Command**
```cmd
serena --help
```

Expected: List of available commands

**Test 3: Configuration Test**
```cmd
serena config edit
```

Expected: Opens configuration file in editor

**Test 4: Project Operations**
```cmd
serena project generate-yml "C:\Users\YourName\Documents\test-project"
```

Expected: Creates `.serena/project.yml` in test-project

### Full Functionality Test

Create a test project:

```cmd
# Create test project
mkdir C:\Users\%USERNAME%\Documents\serena-test
cd C:\Users\%USERNAME%\Documents\serena-test

# Create a simple Python file
echo print("Hello, Serena!") > hello.py

# Activate project with Serena
serena project activate .

# Test file search
serena find-file hello.py

# Test symbol search (if Python language server included)
serena find-symbol print
```

If all commands work, Serena is fully functional!

## Example Usage Scenarios

### Scenario 1: Analyzing an Existing Codebase

**Goal**: Understand a new codebase structure

**Steps:**

1. **Activate the project:**
   ```cmd
   serena project activate "C:\Projects\NewCodebase"
   ```

2. **Index for performance:**
   ```cmd
   serena project index "C:\Projects\NewCodebase"
   ```

3. **In Claude Code/Desktop, ask:**
   ```
   Give me an overview of this project's structure. What are the main modules and their purposes?
   ```

4. **Deep dive:**
   ```
   Show me the symbol definitions in src/main.py

   Find all files that import the "database" module

   What functions reference the "User" class?
   ```

### Scenario 2: Debugging a Specific Function

**Goal**: Understand why a function is failing

**In Claude Code/Desktop:**

1. **Find the function:**
   ```
   Find the function "calculate_total" in this project
   ```

2. **Check usage:**
   ```
   Show me all places where "calculate_total" is called
   ```

3. **Analyze context:**
   ```
   Get the symbol overview for the file containing "calculate_total"
   ```

4. **Ask for help:**
   ```
   The calculate_total function is returning wrong values. Can you help me debug it?
   [Serena will use symbol-aware tools to efficiently analyze the code]
   ```

### Scenario 3: Refactoring Code

**Goal**: Rename a class across the entire project

**In Claude Code/Desktop:**

```
I need to rename the class "OldUserService" to "UserServiceV2" throughout the entire project. Can you help?

[Claude will use Serena's tools to:]
1. Find all references to OldUserService
2. Identify import statements
3. Locate subclasses and implementations
4. Suggest a safe refactoring plan
5. Execute the rename with symbol-aware editing
```

### Scenario 4: Adding a New Feature

**Goal**: Add a new API endpoint to an existing web service

**In Claude Code/Desktop:**

```
I want to add a new REST API endpoint for user profile updates.
Can you:
1. Find the existing API route definitions
2. Show me the current user model structure
3. Create a new endpoint following the existing patterns
```

Serena's symbol-aware tools help Claude:
- Find route decorators and patterns
- Understand the existing code structure
- Insert new code in the right places

## Configuration

### Global Configuration

Location: `%USERPROFILE%\.serena\serena_config.yml`

**To edit:**
```cmd
serena config edit
```

**Key settings:**

```yaml
# Web dashboard settings
enable_web_dashboard: true
auto_open_browser: true
dashboard_port: 24282

# Language server settings
language_servers:
  auto_download: true
  cache_directory: "%USERPROFILE%\\.serena\\language_servers"

# Performance settings
max_concurrent_ls: 3
enable_caching: true

# Logging settings
log_level: INFO
log_directory: "%USERPROFILE%\\.serena\\logs"
```

### Project Configuration

Location: `YourProject\.serena\project.yml`

**Generated automatically** when you activate a project, or manually:

```cmd
serena project generate-yml "C:\path\to\project"
```

**Example configuration:**

```yaml
project_name: "MyProject"
language: python
root_directory: "C:\\Users\\YourName\\Projects\\MyProject"

include_patterns:
  - "**/*.py"
  - "**/*.js"
  - "**/*.ts"

exclude_patterns:
  - "**/node_modules/**"
  - "**/__pycache__/**"
  - "**/venv/**"
  - "**/.git/**"

language_servers:
  python:
    enabled: true
    server: "pyright"
  typescript:
    enabled: true

# Performance tuning
indexing:
  enabled: true
  max_file_size: 1000000  # 1MB
```

### Context and Mode Selection

**Contexts** define the environment Serena operates in:
- `desktop-app` - For Claude Desktop (default)
- `ide-assistant` - For IDE integrations (Claude Code, VS Code)
- `agent` - For autonomous agent workflows
- `codex` - For OpenAI Codex CLI

**Modes** define operational patterns:
- `interactive` - Back-and-forth conversation
- `planning` - Planning and analysis
- `editing` - Code modification focus
- `one-shot` - Single-response tasks

**Usage:**
```cmd
serena start-mcp-server --context ide-assistant --mode interactive
```

### Advanced Configuration

**Environment Variables:**

```cmd
# Set log level
set SERENA_LOG_LEVEL=DEBUG

# Set custom cache directory
set SERENA_CACHE_DIR=D:\serena-cache

# Disable web dashboard
set SERENA_DISABLE_DASHBOARD=1

# Use custom port
set SERENA_PORT=9000
```

**Make permanent (PowerShell):**
```powershell
[Environment]::SetEnvironmentVariable("SERENA_LOG_LEVEL", "DEBUG", "User")
```

## Command Reference

### Core Commands

```cmd
# Version information
serena --version

# Help
serena --help
serena start-mcp-server --help
serena project --help

# Start MCP server
serena start-mcp-server [options]
  --project PATH          Activate project at PATH
  --context CONTEXT       Use context (desktop-app, ide-assistant, agent)
  --mode MODE            Set mode (interactive, planning, editing)
  --transport TRANSPORT  Communication protocol (stdio, sse, streamable-http)
  --port PORT            Server port (for HTTP mode)
  --log-level LEVEL      Logging level (DEBUG, INFO, WARNING, ERROR)
```

### Project Commands

```cmd
# Activate a project
serena project activate PATH

# Index a project (improves performance)
serena project index PATH

# Generate project configuration
serena project generate-yml PATH

# Check project health
serena project health-check PATH
```

### Configuration Commands

```cmd
# Edit global configuration
serena config edit

# List available contexts
serena context list

# List available modes
serena mode list

# List all tools
serena tools list

# List optional tools
serena tools list --only-optional
```

### Diagnostic Commands

```cmd
# Check system information
serena --version

# Test language server installations
serena test-language-servers

# View logs
type "%USERPROFILE%\.serena\logs\mcp_server.log"
```

## Troubleshooting

See [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md) for comprehensive troubleshooting.

**Quick fixes:**

**Command not found:**
```cmd
# Re-run setup
first-run.bat

# Or add to PATH manually (see "Adding to PATH" section)
```

**Port already in use:**
```cmd
serena start-mcp-server --port 9001
```

**Language server not starting:**
```cmd
# Check logs
type "%USERPROFILE%\.serena\logs\lsp\python.log"

# Enable debug mode
serena start-mcp-server --log-level DEBUG
```

**SmartScreen warning:**
- Click "More info"
- Click "Run anyway"
- Or run as administrator

## Next Steps

### For Regular Users

1. **Configure your AI client** (Claude Code or Claude Desktop)
2. **Activate your main project**
3. **Try Serena's tools** through your AI assistant
4. **Read about contexts and modes** to optimize for your workflow

### For Developers

1. **Read CLAUDE.md** for development guidelines
2. **Explore the codebase** at: https://github.com/oraios/serena
3. **Contribute** language server support or features
4. **Join discussions** on GitHub

### Learn More

- **README.md** - Full feature documentation
- **WINDOWS-TROUBLESHOOTING.md** - Common issues and solutions
- **WINDOWS-INTEGRATION.md** - Advanced IDE integration
- **GitHub Issues** - Report bugs or request features

---

**Serena MCP Portable for Windows**
Version: 1.0 | Platform: Windows 10/11 (x64/ARM64)
Built with ❤️ by Oraios AI | https://oraios-ai.de/
