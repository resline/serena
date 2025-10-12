#!/usr/bin/env pwsh
# ==============================================================================
# Serena Index Project Tool Launcher - PowerShell Script
# ==============================================================================
#
# This script launches the Serena project indexing tool in portable mode.
#
# Features:
#   - Automatically detects portable installation directory
#   - Sets up environment variables (SERENA_PORTABLE, SERENA_HOME, PATH)
#   - Supports bundled runtimes (Node.js, Java, .NET)
#   - Passes through all command-line arguments
#   - Works from any working directory
#   - Handles spaces in paths
#   - Better error handling than batch script
#
# Usage:
#   .\index-project.ps1 [PROJECT_PATH]
#   .\index-project.ps1 C:\MyProjects\MyApp
#   .\index-project.ps1 --help
#
# Note: This tool is deprecated. Use 'serena project index' instead.
#
# ==============================================================================

# Enable strict error handling
$ErrorActionPreference = "Stop"

# ==============================================================================
# Detect Installation Directory
# ==============================================================================

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set portable root (one level up from scripts directory, or current if in root)
$SerenaPortableRoot = $null

if (Test-Path "$ScriptDir\index-project.exe") {
    $SerenaPortableRoot = $ScriptDir
}
elseif (Test-Path "$ScriptDir\..\index-project.exe") {
    $SerenaPortableRoot = (Resolve-Path "$ScriptDir\..").Path
}
else {
    Write-Host "ERROR: Cannot locate index-project.exe" -ForegroundColor Red
    Write-Host "Searched in:"
    Write-Host "  - $ScriptDir"
    Write-Host "  - $ScriptDir\.."
    Write-Host ""
    Write-Host "Please ensure this script is in the Serena portable installation directory."
    exit 1
}

# ==============================================================================
# Verify Installation
# ==============================================================================

$IndexProjectExe = Join-Path $SerenaPortableRoot "index-project.exe"

if (-not (Test-Path $IndexProjectExe)) {
    Write-Host "ERROR: index-project.exe not found at:" -ForegroundColor Red
    Write-Host "  $IndexProjectExe"
    Write-Host ""
    Write-Host "Please verify your Serena portable installation is complete."
    exit 1
}

# ==============================================================================
# Set Up Environment Variables
# ==============================================================================

# Portable mode flag
$env:SERENA_PORTABLE = "1"

# Serena home directory (user data, configs, cache)
$env:SERENA_HOME = Join-Path $SerenaPortableRoot ".serena-portable"
$env:SERENA_CONFIG_DIR = $env:SERENA_HOME
$env:SERENA_CACHE_DIR = Join-Path $env:SERENA_HOME "cache"
$env:SERENA_LOG_DIR = Join-Path $env:SERENA_HOME "logs"
$env:SERENA_TEMP_DIR = Join-Path $env:SERENA_HOME "temp"

# Create directories if they don't exist
@($env:SERENA_HOME, $env:SERENA_CACHE_DIR, $env:SERENA_LOG_DIR, $env:SERENA_TEMP_DIR) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# ==============================================================================
# Set Up Bundled Runtimes
# ==============================================================================

$RuntimesDir = Join-Path $SerenaPortableRoot "runtimes"
$LanguageServersDir = Join-Path $SerenaPortableRoot "language_servers"

# Prepare PATH modifications
$PathAdditions = @()

# Add bundled Node.js to PATH (for TypeScript, Bash language servers)
$NodeExe = Join-Path $RuntimesDir "nodejs\node.exe"
if (Test-Path $NodeExe) {
    $NodeDir = Split-Path -Parent $NodeExe
    $PathAdditions += $NodeDir
    $env:NODE_PATH = $NodeDir
}

# Add bundled .NET to PATH (for C# language server - OmniSharp)
$DotNetExe = Join-Path $RuntimesDir "dotnet\dotnet.exe"
if (Test-Path $DotNetExe) {
    $DotNetDir = Split-Path -Parent $DotNetExe
    $PathAdditions += $DotNetDir
    $env:DOTNET_ROOT = $DotNetDir
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
}

# Add bundled Java to PATH (for Java, Kotlin language servers)
$JavaExe = Join-Path $RuntimesDir "java\bin\java.exe"
if (Test-Path $JavaExe) {
    $JavaBinDir = Split-Path -Parent $JavaExe
    $PathAdditions += $JavaBinDir
    $env:JAVA_HOME = (Resolve-Path "$JavaBinDir\..").Path
}

# Add language servers directory to PATH
if (Test-Path $LanguageServersDir) {
    $PathAdditions += $LanguageServersDir
}

# Add main executable directory to PATH
$PathAdditions += $SerenaPortableRoot

# Update PATH environment variable
if ($PathAdditions.Count -gt 0) {
    $env:PATH = ($PathAdditions -join ";") + ";" + $env:PATH
}

# ==============================================================================
# Launch Index Project Tool
# ==============================================================================

# Pass all arguments to the executable
try {
    & $IndexProjectExe @args
    $ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: Failed to launch index-project.exe" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Exit with the same code as index-project.exe
exit $ExitCode
