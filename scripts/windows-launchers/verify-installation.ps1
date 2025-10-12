#!/usr/bin/env pwsh
# ==============================================================================
# Serena Portable Installation Verification - PowerShell Script
# ==============================================================================
#
# This script performs comprehensive health checks on Serena Portable.
#
# Features:
#   - Verifies all executables are present and functional
#   - Checks directory structure
#   - Tests bundled runtimes (Node.js, .NET, Java)
#   - Verifies language server installations
#   - Checks configuration files
#   - Reports disk space usage
#   - Better error handling and detailed reporting than batch script
#
# Usage:
#   .\verify-installation.ps1
#   .\verify-installation.ps1 -Verbose
#   .\verify-installation.ps1 -Fix       (attempt to fix issues)
#
# ==============================================================================

param(
    [switch]$Verbose,
    [switch]$Fix
)

# Enable strict error handling
$ErrorActionPreference = "Continue"  # Continue to run all tests

# ==============================================================================
# Helper Functions
# ==============================================================================

$TestsPassed = 0
$TestsFailed = 0
$TestsWarnings = 0

function Test-Pass {
    param([string]$Message)
    Write-Host "  [PASS] $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Test-Fail {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
    $script:TestsFailed++
}

function Test-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
    $script:TestsWarnings++
}

function Test-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Cyan
}

function Test-Fix {
    param([string]$Message)
    Write-Host "  [FIX]  $Message" -ForegroundColor Magenta
}

# ==============================================================================
# Display Banner
# ==============================================================================

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Serena Portable - Installation Verification" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

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
    Write-Host "[ERROR] Cannot locate Serena installation" -ForegroundColor Red
    exit 1
}

Test-Info "Installation directory: $SerenaPortableRoot"
Write-Host ""

# ==============================================================================
# Test 1: Verify Core Executables
# ==============================================================================

Write-Host "[TEST 1/8] Verifying core executables..." -ForegroundColor Cyan

$SerenaExe = Join-Path $SerenaPortableRoot "serena.exe"
if (Test-Path $SerenaExe) {
    Test-Pass "serena.exe found"

    # Test if executable runs
    try {
        $VersionOutput = & $SerenaExe --version 2>&1 | Out-String
        Test-Pass "serena.exe is functional"
        if ($Verbose -and $VersionOutput) {
            Write-Host "    Version: $($VersionOutput.Trim())" -ForegroundColor Gray
        }
    }
    catch {
        Test-Fail "serena.exe cannot execute: $($_.Exception.Message)"
    }
}
else {
    Test-Fail "serena.exe not found"
}

$McpServerExe = Join-Path $SerenaPortableRoot "serena-mcp-server.exe"
if (Test-Path $McpServerExe) {
    Test-Pass "serena-mcp-server.exe found"
}
else {
    Test-Fail "serena-mcp-server.exe not found"
}

$IndexProjectExe = Join-Path $SerenaPortableRoot "index-project.exe"
if (Test-Path $IndexProjectExe) {
    Test-Pass "index-project.exe found (deprecated)"
}
else {
    Test-Warn "index-project.exe not found (optional)"
}

Write-Host ""

# ==============================================================================
# Test 2: Verify Directory Structure
# ==============================================================================

Write-Host "[TEST 2/8] Verifying directory structure..." -ForegroundColor Cyan

$SerenaHome = Join-Path $SerenaPortableRoot ".serena-portable"

$RequiredDirs = @(
    $SerenaHome,
    (Join-Path $SerenaHome "cache"),
    (Join-Path $SerenaHome "logs"),
    (Join-Path $SerenaHome "temp")
)

foreach ($Dir in $RequiredDirs) {
    if (Test-Path $Dir) {
        if ($Verbose) {
            Test-Pass "Directory exists: $Dir"
        }
        else {
            $TestsPassed++
        }
    }
    else {
        Test-Fail "Directory missing: $Dir"

        if ($Fix) {
            try {
                New-Item -ItemType Directory -Path $Dir -Force | Out-Null
                Test-Fix "Created directory: $Dir"
            }
            catch {
                Write-Host "    Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

if (-not $Verbose) {
    Test-Info "Directory structure verified"
}

Write-Host ""

# ==============================================================================
# Test 3: Verify Configuration Files
# ==============================================================================

Write-Host "[TEST 3/8] Verifying configuration files..." -ForegroundColor Cyan

$ConfigFile = Join-Path $SerenaHome "serena_config.yml"
if (Test-Path $ConfigFile) {
    Test-Pass "serena_config.yml found"

    # Check file size
    $ConfigSize = (Get-Item $ConfigFile).Length
    if ($ConfigSize -eq 0) {
        Test-Warn "serena_config.yml is empty"
    }
    elseif ($Verbose) {
        Write-Host "    Size: $ConfigSize bytes" -ForegroundColor Gray
    }
}
else {
    Test-Warn "serena_config.yml not found"
    Write-Host "    Run 'first-run.ps1' to create default configuration" -ForegroundColor Yellow
}

Write-Host ""

# ==============================================================================
# Test 4: Check Bundled Runtimes
# ==============================================================================

Write-Host "[TEST 4/8] Checking bundled runtimes..." -ForegroundColor Cyan

$RuntimesDir = Join-Path $SerenaPortableRoot "runtimes"

# Node.js
$NodeExe = Join-Path $RuntimesDir "nodejs\node.exe"
if (Test-Path $NodeExe) {
    Test-Pass "Node.js runtime found"

    if ($Verbose) {
        try {
            $NodeVersion = & $NodeExe --version 2>&1
            Write-Host "    Version: $NodeVersion" -ForegroundColor Gray
        }
        catch {
            Write-Host "    Could not determine Node.js version" -ForegroundColor Gray
        }
    }
}
else {
    Test-Warn "Node.js runtime not bundled"
    Write-Host "    Required for: TypeScript, JavaScript, Bash language servers" -ForegroundColor Yellow
}

# .NET
$DotNetExe = Join-Path $RuntimesDir "dotnet\dotnet.exe"
if (Test-Path $DotNetExe) {
    Test-Pass ".NET runtime found"

    if ($Verbose) {
        try {
            $DotNetVersion = & $DotNetExe --version 2>&1
            Write-Host "    Version: $DotNetVersion" -ForegroundColor Gray
        }
        catch {
            Write-Host "    Could not determine .NET version" -ForegroundColor Gray
        }
    }
}
else {
    Test-Warn ".NET runtime not bundled"
    Write-Host "    Required for: C# language server (OmniSharp)" -ForegroundColor Yellow
}

# Java
$JavaExe = Join-Path $RuntimesDir "java\bin\java.exe"
if (Test-Path $JavaExe) {
    Test-Pass "Java runtime found"

    if ($Verbose) {
        try {
            $JavaVersion = & $JavaExe -version 2>&1 | Select-String -Pattern "version" | Select-Object -First 1
            Write-Host "    Version: $JavaVersion" -ForegroundColor Gray
        }
        catch {
            Write-Host "    Could not determine Java version" -ForegroundColor Gray
        }
    }
}
else {
    Test-Warn "Java runtime not bundled"
    Write-Host "    Required for: Java, Kotlin language servers" -ForegroundColor Yellow
}

Write-Host ""

# ==============================================================================
# Test 5: Check Language Servers Directory
# ==============================================================================

Write-Host "[TEST 5/8] Checking language servers..." -ForegroundColor Cyan

$LanguageServersDir = Join-Path $SerenaPortableRoot "language_servers"

if (Test-Path $LanguageServersDir) {
    Test-Pass "Language servers directory exists"

    if ($Verbose) {
        $LsCount = (Get-ChildItem -Path $LanguageServersDir -Directory -ErrorAction SilentlyContinue).Count
        Write-Host "    Language servers installed: $LsCount" -ForegroundColor Gray
        Write-Host "    Additional servers will be downloaded on-demand" -ForegroundColor Gray
    }
}
else {
    Test-Warn "Language servers directory not found"
    Write-Host "    Language servers will be downloaded on first use" -ForegroundColor Yellow

    if ($Fix) {
        try {
            New-Item -ItemType Directory -Path $LanguageServersDir -Force | Out-Null
            Test-Fix "Created language servers directory"
        }
        catch {
            Write-Host "    Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""

# ==============================================================================
# Test 6: Check Available Disk Space
# ==============================================================================

Write-Host "[TEST 6/8] Checking disk space..." -ForegroundColor Cyan

try {
    $Drive = Split-Path -Qualifier $SerenaPortableRoot
    $DriveInfo = Get-PSDrive -Name $Drive.Trim(':')
    $FreeSpaceGB = [math]::Round($DriveInfo.Free / 1GB, 2)
    $UsedSpaceGB = [math]::Round($DriveInfo.Used / 1GB, 2)
    $TotalSpaceGB = [math]::Round(($DriveInfo.Free + $DriveInfo.Used) / 1GB, 2)

    Test-Info "Free space on ${Drive}: $FreeSpaceGB GB / $TotalSpaceGB GB"

    if ($FreeSpaceGB -lt 1) {
        Test-Warn "Low disk space (less than 1 GB free)"
    }
    elseif ($FreeSpaceGB -lt 5) {
        Test-Warn "Disk space is getting low (less than 5 GB free)"
    }
    else {
        $TestsPassed++
    }

    # Calculate installation size
    if ($Verbose) {
        try {
            $InstallSize = (Get-ChildItem -Path $SerenaPortableRoot -Recurse -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum / 1GB
            Write-Host "    Installation size: $([math]::Round($InstallSize, 2)) GB" -ForegroundColor Gray
        }
        catch {
            Write-Host "    Could not calculate installation size" -ForegroundColor Gray
        }
    }
}
catch {
    Test-Warn "Could not determine free disk space: $($_.Exception.Message)"
}

Write-Host ""

# ==============================================================================
# Test 7: Check Environment Variables
# ==============================================================================

Write-Host "[TEST 7/8] Checking environment variables..." -ForegroundColor Cyan

$UserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')

if ($UserPath -like "*$SerenaPortableRoot*") {
    Test-Pass "Serena is in user PATH"
}
else {
    Test-Info "Serena not in PATH"
    Write-Host "    Run 'first-run.ps1' to add to PATH" -ForegroundColor Cyan
}

Write-Host ""

# ==============================================================================
# Test 8: Run Basic Functionality Test
# ==============================================================================

Write-Host "[TEST 8/8] Running basic functionality test..." -ForegroundColor Cyan

if (Test-Path $SerenaExe) {
    try {
        $HelpOutput = & $SerenaExe --help 2>&1
        if ($LASTEXITCODE -eq 0) {
            Test-Pass "serena.exe --help successful"

            if ($Verbose) {
                Write-Host "    First 5 lines of help output:" -ForegroundColor Gray
                ($HelpOutput | Select-Object -First 5) | ForEach-Object {
                    Write-Host "      $_" -ForegroundColor Gray
                }
            }
        }
        else {
            Test-Fail "serena.exe --help returned exit code: $LASTEXITCODE"
        }
    }
    catch {
        Test-Fail "serena.exe --help failed: $($_.Exception.Message)"
    }
}
else {
    Write-Host "  [SKIP] serena.exe not available" -ForegroundColor Gray
}

Write-Host ""

# ==============================================================================
# Summary
# ==============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tests Passed:   " -NoNewline
Write-Host $TestsPassed -ForegroundColor Green
Write-Host "  Tests Failed:   " -NoNewline
Write-Host $TestsFailed -ForegroundColor Red
Write-Host "  Warnings:       " -NoNewline
Write-Host $TestsWarnings -ForegroundColor Yellow
Write-Host ""

if ($TestsFailed -gt 0) {
    Write-Host "  [RESULT] Installation has CRITICAL ISSUES" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Recommended actions:" -ForegroundColor Yellow
    Write-Host "    1. Re-download the Serena portable package"
    Write-Host "    2. Run '.\first-run.ps1' to initialize setup"
    Write-Host "    3. Check the logs in: $SerenaHome\logs"
    Write-Host ""
    exit 1
}
elseif ($TestsWarnings -gt 0) {
    Write-Host "  [RESULT] Installation is FUNCTIONAL with warnings" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Recommended actions:" -ForegroundColor Cyan
    Write-Host "    1. Run '.\first-run.ps1' if not already done"
    Write-Host "    2. Install missing runtimes if needed for your languages"
    Write-Host ""
    exit 0
}
else {
    Write-Host "  [RESULT] Installation is HEALTHY" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Serena Portable is ready to use!" -ForegroundColor Green
    Write-Host ""
    exit 0
}
