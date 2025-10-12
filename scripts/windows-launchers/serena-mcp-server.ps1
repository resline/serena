#!/usr/bin/env pwsh
# ==============================================================================
# Serena MCP Server Launcher - PowerShell Script
# ==============================================================================
#
# This script launches the Serena MCP Server executable in portable mode.
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
#   .\serena-mcp-server.ps1 [ARGUMENTS...]
#   .\serena-mcp-server.ps1 --transport stdio
#   .\serena-mcp-server.ps1 --transport sse --port 8001
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

if (Test-Path "$ScriptDir\serena-mcp-server.exe") {
    $SerenaPortableRoot = $ScriptDir
}
elseif (Test-Path "$ScriptDir\..\serena-mcp-server.exe") {
    $SerenaPortableRoot = (Resolve-Path "$ScriptDir\..").Path
}
else {
    Write-Host "ERROR: Cannot locate serena-mcp-server.exe" -ForegroundColor Red
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

$SerenaMcpServerExe = Join-Path $SerenaPortableRoot "serena-mcp-server.exe"

if (-not (Test-Path $SerenaMcpServerExe)) {
    Write-Host "ERROR: serena-mcp-server.exe not found at:" -ForegroundColor Red
    Write-Host "  $SerenaMcpServerExe"
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
# Launch Serena MCP Server
# ==============================================================================

# Pass all arguments to the executable
try {
    & $SerenaMcpServerExe @args
    $ExitCode = $LASTEXITCODE
}
catch {
    Write-Host "ERROR: Failed to launch serena-mcp-server.exe" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Exit with the same code as serena-mcp-server.exe
exit $ExitCode
