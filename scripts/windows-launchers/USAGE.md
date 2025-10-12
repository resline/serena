# Quick Start Guide - Serena Portable for Windows

## Installation

1. **Extract the portable package** to any directory (e.g., `C:\Serena`)
2. **Run first-time setup:**
   ```cmd
   first-run.bat
   ```
   or
   ```powershell
   .\first-run.ps1
   ```
3. **Restart your terminal** if you added Serena to PATH

## Quick Reference

### Basic Commands

```cmd
# Show version
serena.bat --version

# Show help
serena.bat --help

# List available tools
serena.bat tools list

# List projects
serena.bat project list

# Edit configuration
serena.bat config edit

# Index a project
serena.bat project index C:\MyProjects\MyApp
```

### MCP Server

```cmd
# Start MCP server with stdio transport
serena-mcp-server.bat --transport stdio

# Start MCP server with SSE transport
serena-mcp-server.bat --transport sse --port 8001
```

### Health Check

```cmd
# Quick verification
verify-installation.bat

# Detailed diagnostics
verify-installation.bat --verbose

# Attempt to fix issues
verify-installation.bat --fix
```

## PowerShell Users

Replace `.bat` with `.ps1`:

```powershell
.\serena.ps1 --help
.\serena-mcp-server.ps1 --transport stdio
.\verify-installation.ps1 -Verbose
```

## Common Issues

### PowerShell Execution Policy

If you get "cannot be loaded because running scripts is disabled":

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Serena Not Found

After first-run, close and reopen your terminal to use `serena` from anywhere.

Or use the full path:
```cmd
C:\Serena\serena.bat --help
```

### Missing Runtimes

Some language servers require runtimes:
- **TypeScript, JavaScript, Bash**: Node.js
- **C#**: .NET
- **Java, Kotlin**: Java

Install system-wide or use bundled runtimes in `runtimes/` directory.

## Directory Locations

| Purpose | Location |
|---------|----------|
| Executables | `C:\Serena\` (installation directory) |
| Configuration | `C:\Serena\.serena-portable\` |
| Logs | `C:\Serena\.serena-portable\logs\` |
| Cache | `C:\Serena\.serena-portable\cache\` |
| Language Servers | `C:\Serena\language_servers\` |

## Getting Help

```cmd
# Command-specific help
serena.bat project --help
serena.bat tools --help
serena.bat config --help

# Full documentation
See README.md in the installation directory
```

## Next Steps

1. Configure your API keys (if using AI features)
2. Index your first project: `serena.bat project index [path]`
3. Explore available tools: `serena.bat tools list`
4. Customize configuration: `serena.bat config edit`

For detailed documentation, see `README.md`.
