# ============================================================================
# Serena CLI Launcher (PowerShell)
# ============================================================================
# This script launches the serena.exe CLI tool from the portable package.
# It automatically detects the installation directory and sets up the
# required environment variables.
#
# Usage: serena.ps1 [arguments...]
# All arguments are passed directly to serena.exe
# ============================================================================

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Detect the installation directory (where this script is located)
$ScriptDir = $PSScriptRoot

# Navigate up two directories to get to the installation root
$InstallDir = (Get-Item (Join-Path $ScriptDir "..\..")).FullName

# Set portable mode environment variable
$env:SERENA_PORTABLE = "1"
$env:SERENA_HOME = $InstallDir

# Add runtime directories to PATH
$env:PATH = "$InstallDir\runtimes\nodejs;$env:PATH"
$env:PATH = "$InstallDir\runtimes\dotnet;$env:PATH"
$env:PATH = "$InstallDir\runtimes\java\bin;$env:PATH"

# Set language-specific environment variables
$env:JAVA_HOME = "$InstallDir\runtimes\java"
$env:DOTNET_ROOT = "$InstallDir\runtimes\dotnet"
$env:NODE_PATH = "$InstallDir\runtimes\nodejs\node_modules"

# Check if serena.exe exists
$SerenaExe = Join-Path $InstallDir "bin\serena.exe"
if (-not (Test-Path $SerenaExe)) {
    Write-Error "ERROR: serena.exe not found at: $SerenaExe"
    Write-Error "Please ensure Serena is properly installed."
    exit 1
}

# Launch serena.exe with all provided arguments
# Use & operator to execute and capture exit code
& $SerenaExe @args
$exitCode = $LASTEXITCODE

# Exit with the same code as serena.exe
exit $exitCode
