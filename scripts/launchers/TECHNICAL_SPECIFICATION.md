# Windows Portable Launcher Scripts - Technical Specification

## Overview

This directory contains 12 production-ready launcher scripts for the Serena Windows portable package. Each script automatically detects the installation directory and configures the environment for portable operation.

## Architecture

### Directory Structure
```
<install_dir>/
├── bin/
│   ├── serena.exe
│   ├── serena-mcp-server.exe
│   └── index-project.exe
├── scripts/
│   └── launchers/          ← This directory
│       ├── serena.bat
│       ├── serena.ps1
│       ├── ... (10 more scripts)
│       ├── README.txt
│       ├── VALIDATION_CHECKLIST.txt
│       └── TECHNICAL_SPECIFICATION.md
├── runtimes/
│   ├── nodejs/
│   ├── dotnet/
│   └── java/
└── language_servers/
```

### Path Resolution Algorithm

**Batch Files (.bat):**
```batch
set "SCRIPT_DIR=%~dp0"                                  # Get script directory
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"                    # Remove trailing backslash
for %%A in ("%SCRIPT_DIR%\..\..") do set "INSTALL_DIR=%%~fA"  # Navigate up 2 levels
```

**PowerShell Files (.ps1):**
```powershell
$ScriptDir = $PSScriptRoot                              # Get script directory
$InstallDir = (Get-Item (Join-Path $ScriptDir "..\..")).FullName  # Navigate up 2 levels
```

## Script Categories

### Category 1: Basic Launchers (3 pairs)

#### serena.bat / serena.ps1
- **Purpose**: Launch main Serena CLI
- **Executable**: `bin/serena.exe`
- **Arguments**: Pass-through all user arguments
- **Exit Code**: Propagates exit code from serena.exe

#### serena-mcp-server.bat / serena-mcp-server.ps1
- **Purpose**: Launch MCP server for Claude Desktop integration
- **Executable**: `bin/serena-mcp-server.exe`
- **Arguments**: Pass-through all user arguments
- **Exit Code**: Propagates exit code from serena-mcp-server.exe

#### index-project.bat / index-project.ps1
- **Purpose**: Launch project indexing tool
- **Executable**: `bin/index-project.exe`
- **Arguments**: Pass-through all user arguments
- **Exit Code**: Propagates exit code from index-project.exe

### Category 2: Setup & Utility Scripts (3 pairs)

#### first-run.bat / first-run.ps1
- **Purpose**: First-time installation setup
- **Operations**:
  1. Create `%USERPROFILE%\.serena\` directory
  2. Create subdirectories: memories, projects, logs, cache
  3. Copy default configuration files
  4. Optionally add to system PATH
  5. Run verification script
- **Arguments**:
  - Batch: `--add-to-path`
  - PowerShell: `-AddToPath`
- **Exit Code**: 0 = success, non-zero = failure

#### verify-installation.bat / verify-installation.ps1
- **Purpose**: Installation health check
- **Checks**:
  1. Verify all executables exist
  2. Check runtime directories (nodejs, dotnet, java)
  3. Count and list language servers
  4. Test `serena.exe --version`
  5. Check disk space
- **Output**: Formatted report with error/warning counts
- **Exit Code**: 0 = healthy, 1 = errors detected

#### activate-serena.bat / activate-serena.ps1
- **Purpose**: Environment activation (no program launch)
- **Usage**:
  - Batch: `call activate-serena.bat`
  - PowerShell: `. .\activate-serena.ps1`
- **Effect**: Sets environment variables in current session
- **Note**: Must be called/dot-sourced, not executed directly

## Environment Variables

All launchers set the following environment variables:

### Core Variables
| Variable | Value | Purpose |
|----------|-------|---------|
| `SERENA_PORTABLE` | `1` | Enable portable mode |
| `SERENA_HOME` | `<install_dir>` | Installation root directory |

### PATH Additions
The following directories are prepended to PATH:
- `<install_dir>\bin`
- `<install_dir>\runtimes\nodejs`
- `<install_dir>\runtimes\dotnet`
- `<install_dir>\runtimes\java\bin`

### Language-Specific Variables
| Variable | Value | Purpose |
|----------|-------|---------|
| `JAVA_HOME` | `<install_dir>\runtimes\java` | Java SDK location |
| `DOTNET_ROOT` | `<install_dir>\runtimes\dotnet` | .NET runtime location |
| `NODE_PATH` | `<install_dir>\runtimes\nodejs\node_modules` | Node.js modules |

## Error Handling

### Executable Existence Check
All basic launchers verify the executable exists before attempting to run:

**Batch:**
```batch
if not exist "%SERENA_EXE%" (
    echo ERROR: serena.exe not found at: %SERENA_EXE%
    exit /b 1
)
```

**PowerShell:**
```powershell
if (-not (Test-Path $SerenaExe)) {
    Write-Error "ERROR: serena.exe not found at: $SerenaExe"
    exit 1
}
```

### Exit Code Propagation

**Batch:**
```batch
"%SERENA_EXE%" %*
exit /b %ERRORLEVEL%
```

**PowerShell:**
```powershell
& $SerenaExe @args
$exitCode = $LASTEXITCODE
exit $exitCode
```

## Path Quoting

All file paths are properly quoted to handle spaces:

**Batch:**
- Variables: `"%INSTALL_DIR%"`
- Commands: `"%SERENA_EXE%" %*`

**PowerShell:**
- Strings: `"$InstallDir\bin"`
- Execution: `& $SerenaExe @args` (PowerShell handles quoting)

## Compatibility

### Batch Files (.bat)
- **OS**: Windows 7, 8, 8.1, 10, 11
- **Shell**: Command Prompt (cmd.exe)
- **Features Used**:
  - `setlocal enabledelayedexpansion`
  - `%~dp0` (script directory)
  - `for %%A in (...) do` (path resolution)
  - `%ERRORLEVEL%` (exit codes)

### PowerShell Files (.ps1)
- **OS**: Windows 10, 11 (with PowerShell 5.0+)
- **Shell**: PowerShell, PowerShell Core
- **Features Used**:
  - `Set-StrictMode -Version Latest`
  - `$PSScriptRoot` (script directory)
  - `$LASTEXITCODE` (exit codes)
  - `@args` (argument splatting)

## Testing Checklist

- [x] Path detection works from any working directory
- [x] Spaces in installation path handled correctly
- [x] All environment variables set properly
- [x] Arguments passed through correctly
- [x] Exit codes propagated correctly
- [x] Error messages clear and helpful
- [x] Scripts work when installation moved to different location
- [x] No hardcoded paths present
- [x] Batch and PowerShell versions have identical functionality

## Integration with Build System

These scripts should be included in the Windows portable package by the build system:

1. Copy all `.bat` files to `<package>/scripts/launchers/`
2. Copy all `.ps1` files to `<package>/scripts/launchers/`
3. Copy all `.txt` and `.md` files to `<package>/scripts/launchers/`
4. Ensure execute permissions are set (not required on Windows)
5. Include in distribution archive

## User Documentation

### Quick Start
```batch
# Extract portable package to C:\Serena
cd C:\Serena\scripts\launchers

# First-time setup
first-run.bat --add-to-path

# Verify installation
verify-installation.bat

# Use Serena
serena.bat --version
serena.bat --help
```

### Common Issues

**Issue**: "serena.exe not found"
- **Cause**: Script running from wrong location or incomplete installation
- **Solution**: Ensure scripts are in `<install_dir>/scripts/launchers/`

**Issue**: "Cannot run because execution of scripts is disabled"
- **Cause**: PowerShell execution policy
- **Solution**: Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Issue**: Language servers not working
- **Cause**: Runtime directories missing or PATH not set
- **Solution**: Run `verify-installation.bat` to diagnose

## Maintenance

### Adding New Executables
To add a new launcher for `new-tool.exe`:

1. Copy `serena.bat` to `new-tool.bat`
2. Update header comments
3. Change `SERENA_EXE` to `NEW_TOOL_EXE`
4. Update executable path: `bin\new-tool.exe`
5. Repeat for PowerShell version
6. Test from different directories

### Modifying Environment Variables
To add new environment variables:

1. Add to all 6 basic launcher scripts (3 .bat + 3 .ps1)
2. Add to both activate scripts
3. Update documentation (README.txt and this file)
4. Test with verify script

## File Sizes

| File | Lines | Size |
|------|-------|------|
| serena.bat | 49 | 1.7 KB |
| serena.ps1 | 50 | 1.8 KB |
| serena-mcp-server.bat | 49 | 1.8 KB |
| serena-mcp-server.ps1 | 50 | 1.9 KB |
| index-project.bat | 49 | 1.8 KB |
| index-project.ps1 | 50 | 1.9 KB |
| first-run.bat | 126 | 4.1 KB |
| first-run.ps1 | 146 | 5.2 KB |
| verify-installation.bat | 159 | 4.9 KB |
| verify-installation.ps1 | 181 | 5.9 KB |
| activate-serena.bat | 62 | 2.3 KB |
| activate-serena.ps1 | 60 | 2.5 KB |
| **Total** | **1,081** | **~42 KB** |

## Version History

- **2025-10-12**: Initial creation
  - Created all 12 launcher scripts
  - Added comprehensive documentation
  - Validated syntax and functionality

## License

These scripts are part of the Serena project and follow the same license as the main project.

## Contact

For issues with these launcher scripts, please report to the Serena issue tracker.
