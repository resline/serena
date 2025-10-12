# ============================================================================
# Serena Installation Verification Script (PowerShell)
# ============================================================================
# This script performs health checks on the Serena portable installation:
# - Verifies all executables exist
# - Checks language server availability
# - Tests serena --version command
# - Checks disk space
# - Reports overall installation status
#
# Usage: verify-installation.ps1
# Exit code: 0 = success, 1 = failure
# ============================================================================

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"  # Don't stop on errors during checks

Write-Host ""
Write-Host "============================================================================"
Write-Host "Serena Installation Verification"
Write-Host "============================================================================"
Write-Host ""

# Detect the installation directory
$ScriptDir = $PSScriptRoot
$InstallDir = (Get-Item (Join-Path $ScriptDir "..\..")).FullName

# Set environment variables
$env:SERENA_PORTABLE = "1"
$env:SERENA_HOME = $InstallDir
$env:PATH = "$InstallDir\runtimes\nodejs;$env:PATH"
$env:PATH = "$InstallDir\runtimes\dotnet;$env:PATH"
$env:PATH = "$InstallDir\runtimes\java\bin;$env:PATH"
$env:JAVA_HOME = "$InstallDir\runtimes\java"
$env:DOTNET_ROOT = "$InstallDir\runtimes\dotnet"
$env:NODE_PATH = "$InstallDir\runtimes\nodejs\node_modules"

Write-Host "Installation directory: $InstallDir"
Write-Host ""

$Errors = 0
$Warnings = 0

# Check executables
Write-Host "[1/5] Checking executables..."
$Executables = @(
    "bin\serena.exe",
    "bin\serena-mcp-server.exe",
    "bin\index-project.exe"
)

foreach ($Exe in $Executables) {
    $ExePath = Join-Path $InstallDir $Exe
    if (Test-Path $ExePath) {
        Write-Host "      [OK] $Exe" -ForegroundColor Green
    } else {
        Write-Host "      [ERROR] Missing: $Exe" -ForegroundColor Red
        $Errors++
    }
}
Write-Host ""

# Check runtime directories
Write-Host "[2/5] Checking language runtimes..."
$Runtimes = @(
    "runtimes\nodejs",
    "runtimes\dotnet",
    "runtimes\java"
)

foreach ($Runtime in $Runtimes) {
    $RuntimePath = Join-Path $InstallDir $Runtime
    if (Test-Path $RuntimePath) {
        Write-Host "      [OK] $Runtime" -ForegroundColor Green
    } else {
        Write-Host "      [WARNING] Missing: $Runtime" -ForegroundColor Yellow
        $Warnings++
    }
}
Write-Host ""

# Check language servers
Write-Host "[3/5] Checking language servers..."
$LsDir = Join-Path $InstallDir "language_servers"

if (Test-Path $LsDir) {
    $LanguageServers = Get-ChildItem -Path $LsDir -Directory -ErrorAction SilentlyContinue
    if ($LanguageServers) {
        $LsCount = $LanguageServers.Count
        Write-Host "      [OK] Found $LsCount language server(s)" -ForegroundColor Green

        # List first few language servers
        $MaxShow = 5
        $Count = 0
        foreach ($Ls in $LanguageServers) {
            if ($Count -lt $MaxShow) {
                Write-Host "           - $($Ls.Name)"
                $Count++
            }
        }
        if ($LsCount -gt $MaxShow) {
            $Remaining = $LsCount - $MaxShow
            Write-Host "           ... and $Remaining more"
        }
    } else {
        Write-Host "      [WARNING] No language servers found" -ForegroundColor Yellow
        $Warnings++
    }
} else {
    Write-Host "      [WARNING] Language servers directory not found" -ForegroundColor Yellow
    $Warnings++
}
Write-Host ""

# Test serena command
Write-Host "[4/5] Testing serena executable..."
$SerenaExe = Join-Path $InstallDir "bin\serena.exe"

if (Test-Path $SerenaExe) {
    try {
        $VersionOutput = & $SerenaExe --version 2>&1
        $VersionExitCode = $LASTEXITCODE

        if ($VersionExitCode -eq 0) {
            Write-Host "      [OK] serena.exe runs successfully" -ForegroundColor Green
            Write-Host "           Version: $VersionOutput"
        } else {
            Write-Host "      [ERROR] serena.exe failed to execute" -ForegroundColor Red
            $Errors++
        }
    } catch {
        Write-Host "      [ERROR] serena.exe failed to execute: $_" -ForegroundColor Red
        $Errors++
    }
} else {
    Write-Host "      [ERROR] serena.exe not found" -ForegroundColor Red
    $Errors++
}
Write-Host ""

# Check disk space
Write-Host "[5/5] Checking disk space..."
try {
    $Drive = (Get-Item $InstallDir).PSDrive.Name
    $DriveInfo = Get-PSDrive -Name $Drive -PSProvider FileSystem
    $FreeSpaceGB = [math]::Round($DriveInfo.Free / 1GB, 2)
    Write-Host "      [OK] Free space on ${Drive}: $FreeSpaceGB GB" -ForegroundColor Green
} catch {
    Write-Host "      [WARNING] Could not determine free space" -ForegroundColor Yellow
    $Warnings++
}
Write-Host ""

# Summary
Write-Host "============================================================================"
Write-Host "Verification Summary"
Write-Host "============================================================================"

if ($Errors -eq 0) {
    if ($Warnings -eq 0) {
        Write-Host "[SUCCESS] Installation is complete and healthy" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now use Serena:"
        Write-Host "  .\serena.ps1 --version"
        Write-Host "  .\serena.ps1 --help"
        Write-Host "  .\serena-mcp-server.ps1 --help"
        Write-Host ""
        exit 0
    } else {
        Write-Host "[WARNING] Installation is functional but has $Warnings warning(s)" -ForegroundColor Yellow
        Write-Host "Please review the warnings above."
        Write-Host ""
        exit 0
    }
} else {
    Write-Host "[FAILED] Installation has $Errors error(s) and $Warnings warning(s)" -ForegroundColor Red
    Write-Host "Please review the errors above and reinstall if necessary."
    Write-Host ""
    exit 1
}
