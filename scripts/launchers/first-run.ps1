# ============================================================================
# Serena First-Run Setup Script (PowerShell)
# ============================================================================
# This script performs first-time setup for Serena portable installation:
# - Creates ~/.serena/ directory structure
# - Copies default configuration files
# - Optionally adds Serena to Windows PATH
# - Runs installation verification
#
# Usage: first-run.ps1 [-AddToPath]
#        -AddToPath: Automatically add to PATH (may require admin)
# ============================================================================

param(
    [switch]$AddToPath = $false
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================================"
Write-Host "Serena First-Run Setup"
Write-Host "============================================================================"
Write-Host ""

# Detect the installation directory
$ScriptDir = $PSScriptRoot
$InstallDir = (Get-Item (Join-Path $ScriptDir "..\..")).FullName

# Set environment variables
$env:SERENA_PORTABLE = "1"
$env:SERENA_HOME = $InstallDir

Write-Host "Installation directory: $InstallDir"
Write-Host ""

# Create user configuration directory
$UserConfigDir = Join-Path $env:USERPROFILE ".serena"
Write-Host "[1/5] Creating configuration directory..."

if (-not (Test-Path $UserConfigDir)) {
    try {
        New-Item -ItemType Directory -Path $UserConfigDir -Force | Out-Null
        Write-Host "      Created: $UserConfigDir" -ForegroundColor Green
    } catch {
        Write-Error "ERROR: Failed to create directory: $UserConfigDir"
        exit 1
    }
} else {
    Write-Host "      Already exists: $UserConfigDir" -ForegroundColor Yellow
}
Write-Host ""

# Create subdirectories
Write-Host "[2/5] Creating subdirectories..."
$Subdirs = @("memories", "projects", "logs", "cache")
foreach ($Subdir in $Subdirs) {
    $SubdirPath = Join-Path $UserConfigDir $Subdir
    if (-not (Test-Path $SubdirPath)) {
        New-Item -ItemType Directory -Path $SubdirPath -Force | Out-Null
        Write-Host "      Created: $SubdirPath" -ForegroundColor Green
    }
}
Write-Host ""

# Copy default configuration files
Write-Host "[3/5] Copying default configuration files..."
$DefaultConfig = Join-Path $InstallDir "config"
$DefaultConfigFile = Join-Path $DefaultConfig "serena_config.yml"
$UserConfigFile = Join-Path $UserConfigDir "serena_config.yml"

if (Test-Path $DefaultConfigFile) {
    if (-not (Test-Path $UserConfigFile)) {
        try {
            Copy-Item $DefaultConfigFile $UserConfigFile -Force
            Write-Host "      Copied: serena_config.yml" -ForegroundColor Green
        } catch {
            Write-Warning "      WARNING: Failed to copy serena_config.yml"
        }
    } else {
        Write-Host "      Already exists: serena_config.yml" -ForegroundColor Yellow
    }
}
Write-Host ""

# PATH Configuration
Write-Host "[4/5] PATH Configuration..."
if ($AddToPath) {
    Write-Host "      Attempting to add Serena to system PATH..."
    Write-Host "      NOTE: This may require administrator privileges."

    $LauncherDir = Join-Path $InstallDir "scripts\launchers"

    try {
        # Get current user PATH
        $CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

        # Check if already in PATH
        if ($CurrentPath -notlike "*$LauncherDir*") {
            # Add to user PATH
            $NewPath = "$CurrentPath;$LauncherDir"
            [Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
            Write-Host "      SUCCESS: Added to PATH: $LauncherDir" -ForegroundColor Green
            Write-Host "      Restart your PowerShell/Command Prompt to use serena commands globally."
        } else {
            Write-Host "      Already in PATH: $LauncherDir" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "      FAILED: Could not add to PATH automatically."
        Write-Warning "      Please add manually: $LauncherDir"
    }
} else {
    Write-Host "      Skipped (use -AddToPath to add automatically)"
    Write-Host ""
    Write-Host "      To use Serena from anywhere, add this to your PATH:"
    Write-Host "      $InstallDir\scripts\launchers"
}
Write-Host ""

# Run verification
Write-Host "[5/5] Running installation verification..."
Write-Host ""

$VerifyScript = Join-Path $ScriptDir "verify-installation.ps1"
$VerifyResult = & $VerifyScript
$VerifyExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "============================================================================"
if ($VerifyExitCode -eq 0) {
    Write-Host "First-run setup completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now use Serena. Try these commands:"
    Write-Host "  cd `"$InstallDir\scripts\launchers`""
    Write-Host "  .\serena.ps1 --version"
    Write-Host "  .\serena.ps1 --help"
} else {
    Write-Warning "First-run setup completed with warnings."
    Write-Warning "Please review the verification results above."
}
Write-Host "============================================================================"
Write-Host ""

exit $VerifyExitCode
