#!/usr/bin/env pwsh
# ==============================================================================
# Serena Portable First-Run Setup - PowerShell Script
# ==============================================================================
#
# This script performs first-time setup for Serena Portable installation.
#
# Features:
#   - Creates .serena-portable directory structure
#   - Copies default configuration files
#   - Optionally adds Serena to user PATH
#   - Verifies installation integrity
#   - Tests executable functionality
#   - Better error handling and reporting than batch script
#
# Usage:
#   .\first-run.ps1
#   .\first-run.ps1 -NoPath        (skip adding to PATH)
#   .\first-run.ps1 -Silent        (minimal output)
#
# ==============================================================================

param(
    [switch]$NoPath,
    [switch]$Silent
)

# Enable strict error handling
$ErrorActionPreference = "Stop"

# ==============================================================================
# Helper Functions
# ==============================================================================

function Write-Step {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor Cyan
    }
}

function Write-Success {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "  $Message" -ForegroundColor Green
    }
}

function Write-Warning {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "  WARNING: $Message" -ForegroundColor Yellow
    }
}

function Write-Error {
    param([string]$Message)
    Write-Host "  ERROR: $Message" -ForegroundColor Red
}

# ==============================================================================
# Display Banner
# ==============================================================================

if (-not $Silent) {
    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  Serena Portable - First-Run Setup" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# Detect Installation Directory
# ==============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$SerenaPortableRoot = $null
if (Test-Path "$ScriptDir\serena.exe") {
    $SerenaPortableRoot = $ScriptDir
}
elseif (Test-Path "$ScriptDir\..\serena.exe") {
    $SerenaPortableRoot = (Resolve-Path "$ScriptDir\..").Path
}
else {
    Write-Error "Cannot locate Serena installation"
    Write-Host "Please run this script from the Serena portable installation directory."
    exit 1
}

Write-Step "[1/6] Detected installation directory:"
Write-Success $SerenaPortableRoot
Write-Host ""

# ==============================================================================
# Verify Installation
# ==============================================================================

Write-Step "[2/6] Verifying installation files..."

$RequiredFiles = @(
    "serena.exe",
    "serena-mcp-server.exe"
)

$OptionalFiles = @(
    "index-project.exe"
)

$MissingFiles = $false

foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $SerenaPortableRoot $File
    if (-not (Test-Path $FilePath)) {
        Write-Error "$File not found"
        $MissingFiles = $true
    }
}

if ($MissingFiles) {
    Write-Host ""
    Write-Error "Installation is incomplete. Please download the full Serena portable package."
    exit 1
}

foreach ($File in $OptionalFiles) {
    $FilePath = Join-Path $SerenaPortableRoot $File
    if (-not (Test-Path $FilePath)) {
        Write-Warning "$File not found (optional)"
    }
}

Write-Success "All required executables found"
Write-Host ""

# ==============================================================================
# Create Directory Structure
# ==============================================================================

Write-Step "[3/6] Creating directory structure..."

$SerenaHome = Join-Path $SerenaPortableRoot ".serena-portable"

$Directories = @(
    $SerenaHome,
    (Join-Path $SerenaHome "cache"),
    (Join-Path $SerenaHome "logs"),
    (Join-Path $SerenaHome "temp"),
    (Join-Path $SerenaHome "contexts"),
    (Join-Path $SerenaHome "modes"),
    (Join-Path $SerenaHome "prompt_templates"),
    (Join-Path $SerenaHome "memories")
)

foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Write-Success "Created: $Dir"
    }
}

Write-Host ""

# ==============================================================================
# Copy Default Configuration Files
# ==============================================================================

Write-Step "[4/6] Copying default configuration files..."

# Check if running from a PyInstaller bundle (resources in _internal)
$ResourcesDir = Join-Path $SerenaPortableRoot "_internal\serena\resources"
if (-not (Test-Path $ResourcesDir)) {
    $ResourcesDir = Join-Path $SerenaPortableRoot "serena\resources"
}

# Copy serena_config.yml if it doesn't exist
$ConfigFile = Join-Path $SerenaHome "serena_config.yml"
$TemplateFile = Join-Path $ResourcesDir "serena_config.template.yml"

if (-not (Test-Path $ConfigFile)) {
    if (Test-Path $TemplateFile) {
        Copy-Item -Path $TemplateFile -Destination $ConfigFile -Force
        Write-Success "Copied: serena_config.yml"
    }
    else {
        Write-Warning "Template file not found: $TemplateFile"
    }
}
else {
    Write-Success "EXISTS: serena_config.yml (not overwritten)"
}

# Copy default contexts
$ContextsSrc = Join-Path $ResourcesDir "config\contexts"
if (Test-Path $ContextsSrc) {
    $ContextFiles = Get-ChildItem -Path $ContextsSrc -Filter "*.yml" -File
    foreach ($File in $ContextFiles) {
        Copy-Item -Path $File.FullName -Destination (Join-Path $SerenaHome "contexts") -Force
    }
    Write-Success "Copied: default contexts ($($ContextFiles.Count) files)"
}

# Copy default modes
$ModesSrc = Join-Path $ResourcesDir "config\modes"
if (Test-Path $ModesSrc) {
    $ModeFiles = Get-ChildItem -Path $ModesSrc -Filter "*.yml" -File
    foreach ($File in $ModeFiles) {
        Copy-Item -Path $File.FullName -Destination (Join-Path $SerenaHome "modes") -Force
    }
    Write-Success "Copied: default modes ($($ModeFiles.Count) files)"
}

# Copy prompt templates
$TemplatesSrc = Join-Path $ResourcesDir "config\prompt_templates"
if (Test-Path $TemplatesSrc) {
    $TemplateFiles = Get-ChildItem -Path $TemplatesSrc -Filter "*.yml" -File
    foreach ($File in $TemplateFiles) {
        Copy-Item -Path $File.FullName -Destination (Join-Path $SerenaHome "prompt_templates") -Force
    }
    Write-Success "Copied: prompt templates ($($TemplateFiles.Count) files)"
}

Write-Host ""

# ==============================================================================
# Add to PATH (Optional)
# ==============================================================================

if (-not $NoPath) {
    Write-Step "[5/6] Adding Serena to user PATH..."

    try {
        $CurrentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')

        if ($CurrentPath -notlike "*$SerenaPortableRoot*") {
            $NewPath = $CurrentPath + ";$SerenaPortableRoot"
            [Environment]::SetEnvironmentVariable('PATH', $NewPath, 'User')
            Write-Success "Added to PATH: $SerenaPortableRoot"
            Write-Warning "Restart your terminal to use 'serena' from any directory"
        }
        else {
            Write-Success "Already in PATH"
        }
    }
    catch {
        Write-Warning "Failed to add to PATH: $($_.Exception.Message)"
        Write-Host "  You can manually add this directory to your PATH:"
        Write-Host "  $SerenaPortableRoot"
    }
}
else {
    Write-Step "[5/6] Skipping PATH modification (-NoPath specified)"
}

Write-Host ""

# ==============================================================================
# Verify Installation
# ==============================================================================

Write-Step "[6/6] Verifying installation..."

$SerenaExe = Join-Path $SerenaPortableRoot "serena.exe"

try {
    $VersionOutput = & $SerenaExe --version 2>&1
    Write-Success "serena.exe is functional"
    if ($VersionOutput) {
        Write-Host "  Version: $VersionOutput" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "serena.exe returned an error: $($_.Exception.Message)"
}

Write-Host ""

# ==============================================================================
# Completion
# ==============================================================================

if (-not $Silent) {
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Serena Portable is now ready to use." -ForegroundColor White
    Write-Host ""
    Write-Host "Installation directory: " -NoNewline
    Write-Host $SerenaPortableRoot -ForegroundColor Cyan
    Write-Host "User data directory:    " -NoNewline
    Write-Host $SerenaHome -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Run 'serena --help' to see available commands"
    Write-Host "  2. Run 'serena config edit' to customize your configuration"
    Write-Host "  3. Run 'serena project index [path]' to index your first project"
    Write-Host "  4. Run '.\verify-installation.ps1' to perform a health check"
    Write-Host ""

    if (-not $NoPath) {
        Write-Host "Note: " -NoNewline -ForegroundColor Yellow
        Write-Host "Restart your terminal to use 'serena' from any directory."
        Write-Host ""
    }

    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host ""
}

exit 0
