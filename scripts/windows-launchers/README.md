# Windows Launcher Scripts for Serena MCP Portable

This directory contains production-grade Windows launcher scripts for the Serena MCP Portable distribution.

## Overview

These scripts provide a seamless way to launch Serena executables on Windows with automatic environment setup, bundled runtime detection, and comprehensive error handling.

## Script Inventory

### Core Launcher Scripts

| Script | Purpose | Entry Point |
|--------|---------|-------------|
| `serena.bat` | CLI launcher (Command Prompt) | `serena.cli:main` |
| `serena.ps1` | CLI launcher (PowerShell) | `serena.cli:main` |
| `serena-mcp-server.bat` | MCP server launcher (Command Prompt) | `serena.cli:start_mcp_server` |
| `serena-mcp-server.ps1` | MCP server launcher (PowerShell) | `serena.cli:start_mcp_server` |
| `index-project.bat` | Indexing tool launcher (Command Prompt) | `serena.cli:index_project` |
| `index-project.ps1` | Indexing tool launcher (PowerShell) | `serena.cli:index_project` |

### Setup and Verification Scripts

| Script | Purpose |
|--------|---------|
| `first-run.bat` | First-time setup (Command Prompt) |
| `first-run.ps1` | First-time setup (PowerShell) |
| `verify-installation.bat` | Health check (Command Prompt) |
| `verify-installation.ps1` | Health check (PowerShell) |

## Features

All launcher scripts provide:

- **Automatic Directory Detection**: Finds portable installation directory automatically
- **Environment Setup**: Sets `SERENA_PORTABLE=1`, `SERENA_HOME`, and PATH variables
- **Bundled Runtime Support**: Detects and adds Node.js, Java, .NET runtimes to PATH
- **Argument Pass-through**: All command-line arguments are forwarded to executables
- **Error Handling**: Graceful error messages for missing files or permissions
- **Path Handling**: Correctly handles spaces in paths
- **Working Directory Independence**: Can be run from any directory

## Usage

### First-Time Setup

Run the first-run script to initialize your portable installation:

**Command Prompt:**
```cmd
first-run.bat
```

**PowerShell:**
```powershell
.\first-run.ps1
```

This will:
1. Create `.serena-portable` directory structure
2. Copy default configuration files
3. Add Serena to user PATH (optional)
4. Verify installation integrity

**Options:**
- `--no-path` / `-NoPath`: Skip adding to PATH
- `--silent` / `-Silent`: Minimal output

### Using Serena CLI

**Command Prompt:**
```cmd
serena.bat --help
serena.bat project list
serena.bat tools list
serena.bat config edit
serena.bat project index C:\MyProjects\MyApp
```

**PowerShell:**
```powershell
.\serena.ps1 --help
.\serena.ps1 project list
.\serena.ps1 tools list
.\serena.ps1 config edit
.\serena.ps1 project index C:\MyProjects\MyApp
```

### Using MCP Server

**Command Prompt:**
```cmd
serena-mcp-server.bat --transport stdio
serena-mcp-server.bat --transport sse --port 8001
```

**PowerShell:**
```powershell
.\serena-mcp-server.ps1 --transport stdio
.\serena-mcp-server.ps1 --transport sse --port 8001
```

### Using Index Project Tool (Deprecated)

**Command Prompt:**
```cmd
index-project.bat C:\MyProjects\MyApp
```

**PowerShell:**
```powershell
.\index-project.ps1 C:\MyProjects\MyApp
```

**Note:** This tool is deprecated. Use `serena project index` instead.

### Verifying Installation

Run the verification script to check installation health:

**Command Prompt:**
```cmd
verify-installation.bat
verify-installation.bat --verbose
verify-installation.bat --fix
```

**PowerShell:**
```powershell
.\verify-installation.ps1
.\verify-installation.ps1 -Verbose
.\verify-installation.ps1 -Fix
```

This checks:
- Core executables (serena.exe, serena-mcp-server.exe)
- Directory structure (`.serena-portable`, cache, logs, temp)
- Configuration files (serena_config.yml)
- Bundled runtimes (Node.js, .NET, Java)
- Language servers directory
- Disk space availability
- PATH configuration
- Basic functionality tests

## Environment Variables

The launcher scripts set the following environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `SERENA_PORTABLE` | Indicates portable mode | `1` |
| `SERENA_HOME` | User data directory | `C:\Serena\.serena-portable` |
| `SERENA_CONFIG_DIR` | Configuration directory | `C:\Serena\.serena-portable` |
| `SERENA_CACHE_DIR` | Cache directory | `C:\Serena\.serena-portable\cache` |
| `SERENA_LOG_DIR` | Logs directory | `C:\Serena\.serena-portable\logs` |
| `SERENA_TEMP_DIR` | Temporary files directory | `C:\Serena\.serena-portable\temp` |
| `NODE_PATH` | Node.js runtime (if bundled) | `C:\Serena\runtimes\nodejs` |
| `DOTNET_ROOT` | .NET runtime (if bundled) | `C:\Serena\runtimes\dotnet` |
| `JAVA_HOME` | Java runtime (if bundled) | `C:\Serena\runtimes\java` |

## Directory Structure

Expected portable installation structure:

```
SerenaPortable/
├── serena.exe                      # Main CLI executable
├── serena-mcp-server.exe           # MCP server executable
├── index-project.exe               # Indexing tool (deprecated)
├── serena.bat                      # CLI launcher (batch)
├── serena.ps1                      # CLI launcher (PowerShell)
├── serena-mcp-server.bat           # MCP server launcher (batch)
├── serena-mcp-server.ps1           # MCP server launcher (PowerShell)
├── index-project.bat               # Indexing launcher (batch)
├── index-project.ps1               # Indexing launcher (PowerShell)
├── first-run.bat                   # First-time setup (batch)
├── first-run.ps1                   # First-time setup (PowerShell)
├── verify-installation.bat         # Health check (batch)
├── verify-installation.ps1         # Health check (PowerShell)
├── .serena-portable/               # User data directory
│   ├── serena_config.yml           # Main configuration
│   ├── cache/                      # Cache directory
│   ├── logs/                       # Log files
│   ├── temp/                       # Temporary files
│   ├── contexts/                   # Context definitions
│   ├── modes/                      # Mode definitions
│   ├── prompt_templates/           # Prompt templates
│   └── memories/                   # Project memories
├── language_servers/               # Language server installations
│   ├── pyright/
│   ├── gopls/
│   ├── typescript-language-server/
│   └── ...
├── runtimes/                       # Bundled runtimes (optional)
│   ├── nodejs/
│   │   └── node.exe
│   ├── dotnet/
│   │   └── dotnet.exe
│   └── java/
│       └── bin/
│           └── java.exe
└── _internal/                      # PyInstaller internal files
    └── serena/
        └── resources/              # Default configs and templates
```

## Windows-Specific Considerations

### Path Handling

All scripts correctly handle:
- Spaces in paths (using quotes)
- Drive letters (C:, D:, etc.)
- UNC paths (\\\\server\\share)
- Relative paths converted to absolute paths

### Permissions

- **User PATH modification**: Requires no admin privileges
- **System PATH modification**: Requires admin privileges (not used)
- **File creation**: Uses user-writable directories only

### PowerShell Execution Policy

If you encounter execution policy errors with `.ps1` scripts:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (no admin required)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run once with bypass (not recommended for regular use)
powershell -ExecutionPolicy Bypass -File serena.ps1 --help
```

### Command Prompt vs PowerShell

| Feature | Command Prompt (.bat) | PowerShell (.ps1) |
|---------|----------------------|-------------------|
| Error Handling | Basic | Advanced |
| Colored Output | Limited | Full support |
| Version Detection | Via PowerShell calls | Native |
| Array Operations | Limited | Native |
| Error Messages | Basic | Detailed |
| Performance | Faster startup | Slightly slower startup |

**Recommendation:** Use PowerShell scripts for better error messages and diagnostics. Use batch scripts for maximum compatibility or when PowerShell is not available.

## Troubleshooting

### "Cannot locate serena.exe"

**Cause:** Script cannot find the executable.

**Solution:**
1. Ensure the script is in the same directory as `serena.exe`
2. Or place the script in a `scripts/` subdirectory
3. Check that the executable name is exactly `serena.exe`

### "serena.exe cannot execute"

**Cause:** Executable is corrupted or missing dependencies.

**Solution:**
1. Re-download the portable package
2. Run `verify-installation.bat` to check for issues
3. Check antivirus software hasn't quarantined files
4. Verify the executable isn't blocked (right-click → Properties → Unblock)

### Language Server Not Found

**Cause:** Required runtime not bundled or in PATH.

**Solution:**
1. Check if runtime is bundled in `runtimes/` directory
2. Install runtime system-wide (Node.js, .NET, Java)
3. Language servers will be downloaded on first use if runtimes are available

### "Access Denied" or Permission Errors

**Cause:** Installation in protected directory.

**Solution:**
1. Move portable installation to a user-writable directory (e.g., `C:\Users\YourName\Serena`)
2. Avoid `C:\Program Files` or `C:\Windows`
3. Run from a directory where you have write permissions

### PATH Not Updated After first-run

**Cause:** Environment variables only apply to new terminals.

**Solution:**
1. Close and reopen Command Prompt/PowerShell
2. Or use full path to executables: `C:\Serena\serena.exe --help`
3. Verify PATH with: `echo %PATH%` (CMD) or `$env:PATH` (PowerShell)

## Integration with Build System

To integrate these scripts into your build pipeline:

1. **Copy scripts to build output:**
   ```bash
   cp scripts/windows-launchers/*.bat dist/
   cp scripts/windows-launchers/*.ps1 dist/
   ```

2. **Include in portable package:**
   - Place launcher scripts in root of portable distribution
   - Ensure executables (`.exe`) are in the same directory
   - Include `README.md` for user reference

3. **Automated testing:**
   ```powershell
   # Run verification script
   .\verify-installation.ps1 -Verbose

   # Test basic functionality
   .\serena.ps1 --version
   .\serena.ps1 --help
   ```

## Development Notes

### Modifying the Scripts

When modifying launcher scripts:

1. **Test both .bat and .ps1 versions** - Keep functionality consistent
2. **Handle edge cases:**
   - Installation in root directory (C:\Serena)
   - Installation in deep subdirectory (C:\Users\Name\Documents\Projects\Serena)
   - Paths with spaces (C:\Program Files\Serena)
   - Network drives (\\\\server\\share\\Serena)
3. **Preserve exit codes** - Always exit with the same code as the executable
4. **Add comments** - Explain non-obvious logic
5. **Test on clean Windows systems** - Verify no external dependencies

### Adding New Runtimes

To add support for a new runtime (e.g., Rust, Go):

1. Add detection in the "Set Up Bundled Runtimes" section
2. Set appropriate environment variables (`CARGO_HOME`, `GOROOT`, etc.)
3. Add to PATH
4. Update verification script to check for the new runtime
5. Update this README

## License

These scripts are part of the Serena project and are licensed under the MIT License.

## Support

For issues or questions:
- Check the verification script output: `verify-installation.ps1 -Verbose`
- Review logs in `.serena-portable/logs/`
- Consult the main Serena documentation
- Open an issue on the Serena GitHub repository

## Credits

Developed for the Serena MCP Portable Windows distribution.
