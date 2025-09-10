#Requires -Version 5.1

<#
.SYNOPSIS
    Build portable Serena distribution for Windows

.DESCRIPTION
    Orchestrates the complete build process for creating a portable Windows distribution of Serena.
    This includes downloading language servers, building with PyInstaller, and packaging the output.

.PARAMETER Tier
    Language server tier to include (minimal, essential, complete, full)

.PARAMETER OutputDir
    Directory for the final portable build (default: .\dist\serena-portable)

.PARAMETER Clean
    Clean output directories before building

.PARAMETER SkipLanguageServers
    Skip downloading language servers

.PARAMETER SkipTests
    Skip running tests before building

.PARAMETER Version
    Version to embed in the build (default: auto-detected from pyproject.toml)

.PARAMETER Architecture
    Target architecture (default: x64)

.EXAMPLE
    .\build-portable.ps1 -Tier essential -Clean
    
.EXAMPLE
    .\build-portable.ps1 -Tier full -OutputDir "C:\builds\serena" -Version "1.0.0"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier,
    
    [string]$OutputDir = ".\dist\serena-portable",
    
    [switch]$Clean,
    
    [switch]$SkipLanguageServers,
    
    [switch]$SkipTests,
    
    [string]$Version,
    
    [ValidateSet("x64", "x86", "arm64")]
    [string]$Architecture = "x64"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Step { param($Message) Write-Host ">>> $Message" -ForegroundColor Magenta }

# Global variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$TempDir = Join-Path $OutputDir "temp"
$LanguageServersDir = Join-Path $TempDir "language-servers"
$BuildDir = Join-Path $TempDir "build"

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $requiredTools = @(
        @{ Name = "python"; Version = "3.11" },
        @{ Name = "uv"; Version = $null },
        @{ Name = "node"; Version = $null },
        @{ Name = "npm"; Version = $null }
    )
    
    $missingTools = @()
    $warnings = @()
    
    foreach ($tool in $requiredTools) {
        $command = Get-Command $tool.Name -ErrorAction SilentlyContinue
        if (-not $command) {
            $missingTools += $tool.Name
            continue
        }
        
        # Check version if specified
        if ($tool.Version) {
            try {
                $versionOutput = & $tool.Name --version 2>&1
                if ($tool.Name -eq "python" -and $versionOutput -notmatch "3\.11") {
                    $warnings += "Python 3.11 required, found: $versionOutput"
                }
            } catch {
                $warnings += "Could not check version for $($tool.Name)"
            }
        }
        
        Write-Success "$($tool.Name) is available: $($command.Source)"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Error "Please ensure all prerequisites are installed and in PATH"
        exit 1
    }
    
    foreach ($warning in $warnings) {
        Write-Warning $warning
    }
    
    # Check if we're in a git repository
    if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
        Write-Warning "Not in a git repository - version detection may not work properly"
    }
    
    Write-Success "Prerequisites check completed"
}

function Get-ProjectVersion {
    Write-Step "Detecting project version..."
    
    if ($Version) {
        Write-Info "Using provided version: $Version"
        return $Version
    }
    
    $pyprojectPath = Join-Path $RepoRoot "pyproject.toml"
    if (Test-Path $pyprojectPath) {
        try {
            $content = Get-Content $pyprojectPath -Raw
            if ($content -match 'version\s*=\s*"([^"]+)"') {
                $detectedVersion = $matches[1]
                Write-Success "Detected version from pyproject.toml: $detectedVersion"
                return $detectedVersion
            }
        } catch {
            Write-Warning "Could not parse version from pyproject.toml"
        }
    }
    
    # Try git tag
    try {
        Push-Location $RepoRoot
        $gitVersion = git describe --tags --always 2>$null
        if ($gitVersion) {
            Write-Success "Using git version: $gitVersion"
            return $gitVersion
        }
    } catch {
        Write-Warning "Could not get version from git"
    } finally {
        Pop-Location
    }
    
    $fallbackVersion = "0.1.0-dev"
    Write-Warning "Using fallback version: $fallbackVersion"
    return $fallbackVersion
}

function Initialize-BuildEnvironment {
    Write-Step "Initializing build environment..."
    
    # Change to repository root
    Push-Location $RepoRoot
    
    # Clean directories if requested
    if ($Clean) {
        Write-Info "Cleaning output directories..."
        Remove-Item $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Create necessary directories
    @($OutputDir, $TempDir, $LanguageServersDir, $BuildDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            Write-Info "Creating directory: $_"
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    Write-Success "Build environment initialized"
}

function Install-Dependencies {
    Write-Step "Installing Python dependencies..."
    
    # Validate we're in a Python project
    if (!(Test-Path "pyproject.toml")) {
        Write-Error "pyproject.toml not found. Ensure this script runs from the project root."
        exit 1
    }
    
    try {
        Write-Info "Syncing dependencies with uv..."
        & uv sync --dev
        if ($LASTEXITCODE -ne 0) { throw "uv sync failed" }
        
        Write-Info "Installing PyInstaller..."
        & uv add --dev pyinstaller
        if ($LASTEXITCODE -ne 0) { throw "Failed to install PyInstaller" }
        
        Write-Success "Dependencies installed successfully"
        
    } catch {
        Write-Error "Failed to install dependencies: $_"
        exit 1
    }
}

function Invoke-Tests {
    if ($SkipTests) {
        Write-Warning "Skipping tests (--SkipTests specified)"
        return
    }
    
    Write-Step "Running tests..."
    
    try {
        Write-Info "Running type checking..."
        & uv run poe type-check
        if ($LASTEXITCODE -ne 0) { throw "Type checking failed" }
        
        Write-Info "Running linting..."
        & uv run poe lint
        if ($LASTEXITCODE -ne 0) { throw "Linting failed" }
        
        Write-Info "Running core tests..."
        & uv run poe test -m "python or go or typescript" --maxfail=3
        if ($LASTEXITCODE -ne 0) { throw "Tests failed" }
        
        Write-Success "All tests passed"
        
    } catch {
        Write-Error "Tests failed: $_"
        Write-Error "Fix test failures before building or use -SkipTests to bypass"
        exit 1
    }
}

function Get-LanguageServers {
    if ($SkipLanguageServers) {
        Write-Warning "Skipping language server download (--SkipLanguageServers specified)"
        return
    }
    
    Write-Step "Downloading language servers..."
    
    $downloadScript = Join-Path $ScriptDir "download-language-servers.ps1"
    if (-not (Test-Path $downloadScript)) {
        Write-Error "Download script not found: $downloadScript"
        exit 1
    }
    
    try {
        Write-Info "Running download script for tier: $Tier, architecture: $Architecture"
        & $downloadScript -Tier $Tier -OutputDir $LanguageServersDir -Architecture $Architecture
        if ($LASTEXITCODE -ne 0) { throw "Language server download failed" }
        
        Write-Success "Language servers downloaded successfully"
        
    } catch {
        Write-Error "Failed to download language servers: $_"
        exit 1
    }
}

function Create-PyInstallerSpec {
    param([string]$ProjectVersion)
    
    Write-Step "Creating PyInstaller specification..."
    
    $specContent = @"
# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all

# Collect all data and hidden imports for Serena
datas = [
    ('src/serena/resources', 'serena/resources'),
    ('src/solidlsp', 'solidlsp'),
]

# Add language servers if they exist
import os
ls_dir = r'$LanguageServersDir'
if os.path.exists(ls_dir):
    datas.append((ls_dir, 'language-servers'))

# Hidden imports for various components
hiddenimports = [
    'serena',
    'serena.agent',
    'serena.cli',
    'serena.mcp',
    'solidlsp',
    'solidlsp.ls',
    'solidlsp.language_servers',
    'mcp',
    'anthropic',
    'requests',
    'yaml',
    'ruamel.yaml',
    'jinja2',
    'pathspec',
    'psutil',
    'tqdm',
    'tiktoken',
    'pydantic',
    'dotenv',
]

# Collect all files from main packages
tmp_ret = collect_all('serena')
datas += tmp_ret[0]
hiddenimports += tmp_ret[1]

tmp_ret = collect_all('solidlsp')
datas += tmp_ret[0]
hiddenimports += tmp_ret[1]

# Binary excludes to reduce size
binaries = []

a = Analysis(
    ['src/serena/cli.py'],
    pathex=['src'],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'test', 'unittest', 'matplotlib'],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=None)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='serena',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch='$Architecture',
    codesign_identity=None,
    entitlements_file=None,
    version='version_info.py' if os.path.exists('version_info.py') else None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='serena',
)
"@

    $specPath = Join-Path $BuildDir "serena.spec"
    Set-Content -Path $specPath -Value $specContent -Encoding UTF8
    
    Write-Success "PyInstaller spec created: $specPath"
    return $specPath
}

function Create-VersionInfo {
    param([string]$ProjectVersion)
    
    Write-Step "Creating version information..."
    
    # Parse version into components
    $versionParts = $ProjectVersion -split '\.'
    $major = if ($versionParts.Length -gt 0) { [int]$versionParts[0] } else { 0 }
    $minor = if ($versionParts.Length -gt 1) { [int]$versionParts[1] } else { 1 }
    $micro = if ($versionParts.Length -gt 2) { [int]($versionParts[2] -replace '[^\d].*') } else { 0 }
    $build = 0
    
    $versionInfoContent = @"
# UTF-8
#
# Version information for Serena portable build

VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=($major, $minor, $micro, $build),
    prodvers=($major, $minor, $micro, $build),
    mask=0x3f,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
  ),
  kids=[
    StringFileInfo(
      [
        StringTable(
          u'040904B0',
          [StringStruct(u'CompanyName', u'Oraios AI'),
           StringStruct(u'FileDescription', u'Serena - AI Coding Agent Toolkit'),
           StringStruct(u'FileVersion', u'$ProjectVersion'),
           StringStruct(u'InternalName', u'serena'),
           StringStruct(u'LegalCopyright', u'Copyright (c) 2024 Oraios AI'),
           StringStruct(u'OriginalFilename', u'serena.exe'),
           StringStruct(u'ProductName', u'Serena'),
           StringStruct(u'ProductVersion', u'$ProjectVersion')])
      ]
    ),
    VarFileInfo([VarStruct(u'Translation', [1033, 1200])])
  ]
)
"@

    $versionPath = Join-Path $RepoRoot "version_info.py"
    Set-Content -Path $versionPath -Value $versionInfoContent -Encoding UTF8
    
    Write-Success "Version info created: $versionPath"
    return $versionPath
}

function Build-WithPyInstaller {
    param(
        [string]$SpecPath,
        [string]$ProjectVersion
    )
    
    Write-Step "Building with PyInstaller..."
    
    try {
        $distPath = Join-Path $BuildDir "dist"
        $workPath = Join-Path $BuildDir "work"
        
        Write-Info "Starting PyInstaller build..."
        Write-Info "Spec file: $SpecPath"
        Write-Info "Dist path: $distPath"
        Write-Info "Work path: $workPath"
        
        & uv run pyinstaller `
            --distpath $distPath `
            --workpath $workPath `
            --clean `
            --noconfirm `
            $SpecPath
            
        if ($LASTEXITCODE -ne 0) { throw "PyInstaller build failed" }
        
        $builtAppPath = Join-Path $distPath "serena"
        if (-not (Test-Path $builtAppPath)) {
            throw "Built application not found at: $builtAppPath"
        }
        
        Write-Success "PyInstaller build completed: $builtAppPath"
        return $builtAppPath
        
    } catch {
        Write-Error "PyInstaller build failed: $_"
        exit 1
    }
}

function Create-PortablePackage {
    param(
        [string]$BuiltAppPath,
        [string]$ProjectVersion
    )
    
    Write-Step "Creating portable package..."
    
    try {
        $packageName = "serena-$ProjectVersion-windows-$Architecture-portable"
        $packagePath = Join-Path $OutputDir $packageName
        
        # Clean package directory
        Remove-Item $packagePath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
        
        # Copy built application
        Write-Info "Copying application files..."
        Copy-Item $BuiltAppPath\* $packagePath -Recurse -Force
        
        # Create launcher script
        $launcherContent = @"
@echo off
setlocal

REM Serena Portable Launcher
REM Version: $ProjectVersion
REM Architecture: $Architecture

echo Starting Serena v$ProjectVersion...

REM Set up environment
set SERENA_PORTABLE=1
set SERENA_HOME=%~dp0

REM Add current directory to PATH for language servers
set PATH=%SERENA_HOME%;%SERENA_HOME%\language-servers;%PATH%

REM Launch Serena
"%~dp0serena.exe" %*

endlocal
"@

        Set-Content -Path (Join-Path $packagePath "serena.bat") -Value $launcherContent -Encoding UTF8
        
        # Create README
        $readmeContent = @"
# Serena Portable - Windows $Architecture

Version: $ProjectVersion
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
Language Server Tier: $Tier

## Quick Start

1. Run ``serena.bat`` to start Serena
2. Use ``serena.exe`` directly for command-line access

## Commands

- ``serena-mcp-server`` - Start MCP server
- ``serena --help`` - Show help

## Language Servers Included

This portable build includes language servers for tier: $Tier

- **minimal**: No language servers
- **essential**: Python, TypeScript, Go, Rust
- **complete**: + Java, C#, Lua, Bash
- **full**: + All 28 supported language servers

## Configuration

Create a ``.serena`` directory in your project root for project-specific configuration.

## Support

Visit: https://github.com/oraios/serena
"@

        Set-Content -Path (Join-Path $packagePath "README.txt") -Value $readmeContent -Encoding UTF8
        
        # Create ZIP package
        $zipPath = "$packagePath.zip"
        Write-Info "Creating ZIP package: $zipPath"
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Compress-Archive -Path $packagePath -DestinationPath $zipPath -Force
        
        Write-Success "Portable package created:"
        Write-Success "  Directory: $packagePath"  
        Write-Success "  ZIP: $zipPath"
        
        return @{
            Directory = $packagePath
            Zip = $zipPath
            Name = $packageName
        }
        
    } catch {
        Write-Error "Failed to create portable package: $_"
        exit 1
    }
}

function Show-BuildSummary {
    param(
        [hashtable]$Package,
        [string]$ProjectVersion,
        [timespan]$Duration
    )
    
    Write-Host ""
    Write-Host "=== Build Summary ===" -ForegroundColor Magenta
    Write-Host "Version: $ProjectVersion" -ForegroundColor Cyan
    Write-Host "Architecture: $Architecture" -ForegroundColor Cyan
    Write-Host "Language Server Tier: $Tier" -ForegroundColor Cyan
    Write-Host "Build Time: $($Duration.ToString('mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Package Details:" -ForegroundColor Yellow
    Write-Host "  Name: $($Package.Name)" -ForegroundColor White
    Write-Host "  Directory: $($Package.Directory)" -ForegroundColor White
    Write-Host "  ZIP: $($Package.Zip)" -ForegroundColor White
    
    if (Test-Path $Package.Directory) {
        $dirSize = (Get-ChildItem $Package.Directory -Recurse | Measure-Object -Property Length -Sum).Sum
        $dirSizeMB = [math]::Round($dirSize / 1MB, 1)
        Write-Host "  Directory Size: $dirSizeMB MB" -ForegroundColor White
    }
    
    if (Test-Path $Package.Zip) {
        $zipSize = (Get-Item $Package.Zip).Length
        $zipSizeMB = [math]::Round($zipSize / 1MB, 1)
        Write-Host "  ZIP Size: $zipSizeMB MB" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "To test the build, run:" -ForegroundColor Green
    Write-Host "  .\test-portable.ps1 -PackagePath `"$($Package.Directory)`"" -ForegroundColor White
}

function Cleanup-BuildArtifacts {
    Write-Step "Cleaning up build artifacts..."
    
    try {
        # Remove temporary build files
        $cleanupPaths = @(
            (Join-Path $RepoRoot "version_info.py"),
            (Join-Path $BuildDir "work"),
            $TempDir
        )
        
        foreach ($path in $cleanupPaths) {
            if (Test-Path $path) {
                Write-Info "Removing: $path"
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Success "Cleanup completed"
        
    } catch {
        Write-Warning "Cleanup had some issues: $_"
    }
}

# Main execution
try {
    $startTime = Get-Date
    
    Write-Host "=== Serena Portable Build ===" -ForegroundColor Magenta
    Write-Host "Tier: $Tier" -ForegroundColor Cyan
    Write-Host "Architecture: $Architecture" -ForegroundColor Cyan  
    Write-Host "Output: $OutputDir" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Prerequisites
    $projectVersion = Get-ProjectVersion
    Initialize-BuildEnvironment
    
    Install-Dependencies
    Invoke-Tests
    Get-LanguageServers
    
    $versionInfoPath = Create-VersionInfo -ProjectVersion $projectVersion
    $specPath = Create-PyInstallerSpec -ProjectVersion $projectVersion
    $builtAppPath = Build-WithPyInstaller -SpecPath $specPath -ProjectVersion $projectVersion
    $package = Create-PortablePackage -BuiltAppPath $builtAppPath -ProjectVersion $projectVersion
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Show-BuildSummary -Package $package -ProjectVersion $projectVersion -Duration $duration
    
    Cleanup-BuildArtifacts
    
    Write-Host ""
    Write-Success "Build completed successfully!"
    exit 0
    
} catch {
    Write-Error "Build failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    # Ensure we return to original directory
    if (Test-Path variable:RepoRoot) {
        Pop-Location -ErrorAction SilentlyContinue
    }
}