# ============================================================================
# Serena Environment Activation Script (PowerShell)
# ============================================================================
# This script activates the Serena environment in the current PowerShell session.
# It sets all necessary environment variables but does NOT launch any program.
#
# Usage: Dot-source this script to set up environment variables:
#        . .\activate-serena.ps1
#
#        Then use commands directly:
#        serena.exe --version
#
# NOTE: This script must be dot-sourced (. .\activate-serena.ps1) to affect
#       the current PowerShell session. Simply running it will create a new
#       session that exits immediately.
# ============================================================================

# Detect the installation directory (where this script is located)
$ScriptDir = $PSScriptRoot

# Navigate up two directories to get to the installation root
$InstallDir = (Get-Item (Join-Path $ScriptDir "..\..")).FullName

# Set portable mode environment variable
$env:SERENA_PORTABLE = "1"
$env:SERENA_HOME = $InstallDir

# Add bin directory to PATH
$env:PATH = "$InstallDir\bin;$env:PATH"

# Add runtime directories to PATH
$env:PATH = "$InstallDir\runtimes\nodejs;$env:PATH"
$env:PATH = "$InstallDir\runtimes\dotnet;$env:PATH"
$env:PATH = "$InstallDir\runtimes\java\bin;$env:PATH"

# Set language-specific environment variables
$env:JAVA_HOME = "$InstallDir\runtimes\java"
$env:DOTNET_ROOT = "$InstallDir\runtimes\dotnet"
$env:NODE_PATH = "$InstallDir\runtimes\nodejs\node_modules"

Write-Host ""
Write-Host "============================================================================"
Write-Host "Serena Environment Activated"
Write-Host "============================================================================"
Write-Host ""
Write-Host "SERENA_HOME: $env:SERENA_HOME"
Write-Host "SERENA_PORTABLE: $env:SERENA_PORTABLE"
Write-Host ""
Write-Host "You can now use Serena commands directly:"
Write-Host "  serena.exe --version"
Write-Host "  serena.exe --help"
Write-Host "  serena-mcp-server.exe --help"
Write-Host ""
Write-Host "Runtime paths have been added to PATH:"
Write-Host "  - Node.js: $InstallDir\runtimes\nodejs"
Write-Host "  - .NET: $InstallDir\runtimes\dotnet"
Write-Host "  - Java: $InstallDir\runtimes\java\bin"
Write-Host ""
Write-Host "============================================================================"
Write-Host ""
