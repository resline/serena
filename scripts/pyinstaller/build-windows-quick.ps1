#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick Windows build script for Serena using serena-windows.spec

.DESCRIPTION
    Simplified build script that automates the PyInstaller build process
    using the production-ready serena-windows.spec file. This script:
    - Validates prerequisites
    - Sets environment variables
    - Generates version info
    - Runs PyInstaller
    - Reports build results

.PARAMETER Clean
    Clean build directories before building

.PARAMETER SkipVersionInfo
    Skip regenerating version_info.txt (use existing)

.PARAMETER DebugLog
    Enable debug logging

.PARAMETER OutputDir
    Custom output directory (default: ../../dist)

.EXAMPLE
    .\build-windows-quick.ps1
    Basic build with all defaults

.EXAMPLE
    .\build-windows-quick.ps1 -Clean -DebugLog
    Clean build with debug logging

.EXAMPLE
    .\build-windows-quick.ps1 -OutputDir C:\Builds\Serena
    Build with custom output directory

.NOTES
    Author: Serena Development Team
    Requires: Python 3.11, PyInstaller 6.0+
#>

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipVersionInfo,
    [switch]$DebugLog,
    [string]$OutputDir = ""
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."

# Colors for output
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Serena Windows Build (Quick Mode)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Validate prerequisites
Write-Info "Validating prerequisites..."

# Check Python version
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python 3\.11\.") {
        Write-Success "Python 3.11 detected: $pythonVersion"
    } else {
        Write-Error "Python 3.11 required, found: $pythonVersion"
        exit 1
    }
} catch {
    Write-Error "Python not found. Please install Python 3.11"
    exit 1
}

# Check PyInstaller
try {
    $pyinstallerVersion = pyinstaller --version 2>&1
    Write-Success "PyInstaller detected: $pyinstallerVersion"
} catch {
    Write-Warning "PyInstaller not found. Installing..."
    pip install pyinstaller>=6.0
}

# Check spec file
$specFile = Join-Path $ScriptDir "serena-windows.spec"
if (-not (Test-Path $specFile)) {
    Write-Error "Spec file not found: $specFile"
    exit 1
}
Write-Success "Spec file found: $specFile"

# Step 2: Set environment variables
Write-Info "Configuring environment..."

$env:PROJECT_ROOT = $ProjectRoot
$env:LANGUAGE_SERVERS_DIR = Join-Path $ProjectRoot "build\language_servers"
$env:RUNTIMES_DIR = Join-Path $ProjectRoot "build\runtimes"

# Get version from pyproject.toml
$pyprojectPath = Join-Path $ProjectRoot "pyproject.toml"
$version = "0.1.4"  # default
if (Test-Path $pyprojectPath) {
    $content = Get-Content $pyprojectPath -Raw
    if ($content -match 'version\s*=\s*"([^"]+)"') {
        $version = $matches[1]
    }
}
$env:SERENA_VERSION = $version
$env:SERENA_BUILD_TIER = "essential"

Write-Success "PROJECT_ROOT: $env:PROJECT_ROOT"
Write-Success "VERSION: $env:SERENA_VERSION"

# Check for language servers and runtimes
if (Test-Path $env:LANGUAGE_SERVERS_DIR) {
    $lsCount = (Get-ChildItem $env:LANGUAGE_SERVERS_DIR -Directory).Count
    Write-Success "Language servers found: $lsCount directories"
} else {
    Write-Warning "Language servers not found at: $env:LANGUAGE_SERVERS_DIR"
    Write-Warning "Build will succeed but LSP functionality will require external servers"
}

if (Test-Path $env:RUNTIMES_DIR) {
    Write-Success "Portable runtimes found"
} else {
    Write-Warning "Portable runtimes not found (offline mode won't work)"
}

# Step 3: Generate version info
if (-not $SkipVersionInfo) {
    Write-Info "Generating Windows version info..."
    Push-Location $ScriptDir
    try {
        python build_version_info.py
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Version info generated"
        } else {
            Write-Warning "Version info generation had issues (continuing anyway)"
        }
    } catch {
        Write-Warning "Could not generate version info: $_"
    }
    Pop-Location
} else {
    Write-Info "Skipping version info generation"
}

# Check for icon
$iconPath = Join-Path $ScriptDir "serena.ico"
if (Test-Path $iconPath) {
    Write-Success "Icon found: serena.ico"
} else {
    Write-Warning "Icon not found (exe will have default icon)"
    Write-Warning "To add icon: Place serena.ico in scripts/pyinstaller/"
}

# Step 4: Clean if requested
if ($Clean) {
    Write-Info "Cleaning build directories..."
    $buildDir = Join-Path $ScriptDir "build"
    $distDir = Join-Path $ScriptDir "dist"

    if (Test-Path $buildDir) {
        Remove-Item $buildDir -Recurse -Force
        Write-Success "Cleaned: build/"
    }
    if (Test-Path $distDir) {
        Remove-Item $distDir -Recurse -Force
        Write-Success "Cleaned: dist/"
    }
}

# Step 5: Run PyInstaller
Write-Host ""
Write-Info "Starting PyInstaller build..."
Write-Info "This may take 3-5 minutes..."
Write-Host ""

Push-Location $ScriptDir

$pyinstallerArgs = @(
    "--noconfirm"
)

if ($Clean) {
    $pyinstallerArgs += "--clean"
}

if ($DebugLog) {
    $pyinstallerArgs += "--log-level", "DEBUG"
} else {
    $pyinstallerArgs += "--log-level", "INFO"
}

if ($OutputDir) {
    $pyinstallerArgs += "--distpath", $OutputDir
}

$pyinstallerArgs += "serena-windows.spec"

$startTime = Get-Date

try {
    pyinstaller @pyinstallerArgs
    $exitCode = $LASTEXITCODE
} catch {
    Write-Error "PyInstaller failed: $_"
    Pop-Location
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime

Pop-Location

# Step 6: Report results
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($exitCode -eq 0) {
    Write-Host "  BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $distPath = if ($OutputDir) { $OutputDir } else { Join-Path $ScriptDir "dist\serena-windows" }

    Write-Success "Build completed in $($duration.TotalSeconds.ToString('F1')) seconds"
    Write-Success "Output directory: $distPath"
    Write-Host ""

    # Check executables
    if (Test-Path $distPath) {
        $exes = @(
            "serena-mcp-server.exe",
            "serena.exe",
            "index-project.exe"
        )

        Write-Info "Executables created:"
        foreach ($exe in $exes) {
            $exePath = Join-Path $distPath $exe
            if (Test-Path $exePath) {
                $size = (Get-Item $exePath).Length / 1MB
                Write-Success "  $exe ($($size.ToString('F1')) MB)"
            } else {
                Write-Warning "  $exe NOT FOUND"
            }
        }

        # Calculate total size
        Write-Host ""
        Write-Info "Bundle analysis:"
        $totalSize = (Get-ChildItem $distPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "  Total size: $($totalSize.ToString('F1')) MB" -ForegroundColor Cyan

        # Count files
        $fileCount = (Get-ChildItem $distPath -Recurse -File).Count
        Write-Host "  File count: $fileCount files" -ForegroundColor Cyan

        # Check for key components
        $internalDir = Join-Path $distPath "_internal"
        if (Test-Path $internalDir) {
            Write-Success "  _internal/ directory present (ONEDIR mode correct)"
        }

        $resourcesDir = Join-Path $distPath "serena\resources"
        if (Test-Path $resourcesDir) {
            Write-Success "  serena/resources/ directory present"
        } else {
            Write-Warning "  serena/resources/ NOT FOUND (may cause runtime errors)"
        }

        $lsDir = Join-Path $distPath "language_servers"
        if (Test-Path $lsDir) {
            $lsCount = (Get-ChildItem $lsDir -Directory).Count
            Write-Success "  language_servers/ present ($lsCount servers)"
        } else {
            Write-Warning "  language_servers/ not bundled (will download on demand)"
        }

        $runtimesDir = Join-Path $distPath "runtimes"
        if (Test-Path $runtimesDir) {
            Write-Success "  runtimes/ present (offline mode supported)"
        }

        Write-Host ""
        Write-Info "Quick test commands:"
        Write-Host "  cd $distPath" -ForegroundColor Yellow
        Write-Host "  .\serena.exe --help" -ForegroundColor Yellow
        Write-Host "  .\serena-mcp-server.exe --help" -ForegroundColor Yellow
        Write-Host ""

        Write-Info "To create ZIP for distribution:"
        Write-Host "  Compress-Archive -Path '$distPath\*' -DestinationPath serena-windows-v$version-x64.zip" -ForegroundColor Yellow

    } else {
        Write-Warning "Output directory not found: $distPath"
    }

} else {
    Write-Host "  BUILD FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Error "PyInstaller exited with code: $exitCode"
    Write-Host ""
    Write-Info "Troubleshooting steps:"
    Write-Host "  1. Run with -DebugLog for detailed output"
    Write-Host "  2. Check build.log in scripts/pyinstaller/"
    Write-Host "  3. Verify all dependencies installed: pip install -e .[dev]"
    Write-Host "  4. See WINDOWS-BUILD-GUIDE.md for common issues"
    exit 1
}

Write-Host ""
