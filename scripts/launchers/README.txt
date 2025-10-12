===============================================================================
SERENA PORTABLE LAUNCHER SCRIPTS
===============================================================================

This directory contains 12 launcher scripts for the Windows portable package:
- 6 Batch files (.bat) for traditional Windows Command Prompt
- 6 PowerShell files (.ps1) for modern PowerShell environments

All scripts automatically detect the installation directory and set up the
required environment variables for portable operation.

===============================================================================
BASIC LAUNCHERS (3 pairs)
===============================================================================

1. serena.bat / serena.ps1
   - Launch the main Serena CLI tool
   - Usage: serena.bat [arguments...]
   - Passes all arguments to serena.exe
   - Works from any directory

2. serena-mcp-server.bat / serena-mcp-server.ps1
   - Launch the Serena MCP Server
   - Usage: serena-mcp-server.bat [arguments...]
   - Passes all arguments to serena-mcp-server.exe
   - Used for Claude Desktop integration

3. index-project.bat / index-project.ps1
   - Launch the project indexing tool
   - Usage: index-project.bat [arguments...]
   - Speeds up symbol operations
   - Works from any directory

===============================================================================
SETUP & UTILITY SCRIPTS (3 pairs)
===============================================================================

4. first-run.bat / first-run.ps1
   - First-time setup script
   - Creates ~/.serena/ directory structure
   - Copies default configuration files
   - Optionally adds to Windows PATH
   - Runs installation verification
   - Usage: first-run.bat [--add-to-path]
   - PS Usage: first-run.ps1 [-AddToPath]

5. verify-installation.bat / verify-installation.ps1
   - Installation health check
   - Verifies all executables exist
   - Checks language servers
   - Tests serena --version
   - Reports disk space
   - Exit code: 0 = success, 1 = failure

6. activate-serena.bat / activate-serena.ps1
   - Environment activation (no program launch)
   - Sets all environment variables
   - Batch: Use "call activate-serena.bat"
   - PowerShell: Use ". .\activate-serena.ps1"
   - Allows direct use of serena.exe commands

===============================================================================
ENVIRONMENT VARIABLES SET BY ALL LAUNCHERS
===============================================================================

SERENA_PORTABLE=1          - Enables portable mode
SERENA_HOME=<install_dir>  - Installation directory

PATH additions:
  - <install_dir>\bin
  - <install_dir>\runtimes\nodejs
  - <install_dir>\runtimes\dotnet
  - <install_dir>\runtimes\java\bin

Language-specific:
  - JAVA_HOME=<install_dir>\runtimes\java
  - DOTNET_ROOT=<install_dir>\runtimes\dotnet
  - NODE_PATH=<install_dir>\runtimes\nodejs\node_modules

===============================================================================
USAGE EXAMPLES
===============================================================================

First-time setup:
  cd C:\Serena\scripts\launchers
  first-run.bat --add-to-path

Basic usage:
  serena.bat --version
  serena.bat --help
  serena.bat project index

MCP Server:
  serena-mcp-server.bat --transport stdio

Environment activation (Batch):
  call activate-serena.bat
  serena.exe --version

Environment activation (PowerShell):
  . .\activate-serena.ps1
  serena.exe --version

===============================================================================
FEATURES
===============================================================================

✓ Auto-detect portable directory
✓ Handle spaces in paths correctly
✓ Pass through all arguments
✓ Error handling and exit codes
✓ Work from any working directory
✓ No hardcoded paths
✓ Comprehensive comments
✓ Production-ready

===============================================================================
TECHNICAL DETAILS
===============================================================================

Path Detection:
  - Batch: Uses %~dp0 and for loop
  - PowerShell: Uses $PSScriptRoot

Install Dir Calculation:
  - Scripts are in: <install_dir>\scripts\launchers\
  - Navigate up 2 directories to get install root

Error Handling:
  - All launchers check if executables exist
  - Exit codes match the called program
  - Clear error messages

Compatibility:
  - Batch: Works on Windows 7+ with Command Prompt
  - PowerShell: Works on PowerShell 5.0+ (Windows 10+)
  - Both versions have identical functionality

===============================================================================
