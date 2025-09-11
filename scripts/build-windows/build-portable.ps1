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

# Auto-adjust output directory if path would be too long
$maxPathLength = 260
if ($OutputDir.Length -gt ($maxPathLength - 100)) {
    $fallbackDir = ".\dist\sp"  # Short path fallback
    Write-Warning "Output directory path too long ($($OutputDir.Length) chars)"
    Write-Warning "Using fallback directory: $fallbackDir"
    $OutputDir = $fallbackDir
}

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
    
    # Check for potential path length issues
    Write-Info "Checking path lengths..."
    $maxPathLength = 260  # Windows MAX_PATH limitation
    $pathsToCheck = @($OutputDir, $TempDir, $LanguageServersDir, $BuildDir)
    
    foreach ($path in $pathsToCheck) {
        if ($path.Length -gt ($maxPathLength - 50)) {  # Leave some buffer for filenames
            Write-Warning "Path may be too long for Windows: $path (Length: $($path.Length))"
            Write-Warning "Consider using a shorter output directory to avoid path length issues"
        }
    }
    
    # Clean directories if requested
    if ($Clean) {
        Write-Info "Cleaning output directories..."
        Remove-Item $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Create necessary directories with error handling for long paths
    @($OutputDir, $TempDir, $LanguageServersDir, $BuildDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            Write-Info "Creating directory: $_"
            try {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
            } catch {
                if ($_.Exception.Message -like "*path*too*long*" -or $_.Exception.HResult -eq -2147024843) {
                    Write-Error "Path too long for Windows filesystem: $_"
                    Write-Error "Try using a shorter output directory path"
                    throw
                } else {
                    throw
                }
            }
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
        # Verify Windows dependencies first
        Write-Info "Verifying Windows dependencies..." 
        try {
            python -c "import win32api, pywintypes" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Windows dependencies missing, installing..."
                python -m pip install --upgrade pip wheel setuptools
                python -m pip install pywin32 pywin32-ctypes
                
                # Verify installation worked
                python -c "import win32api; print('pywin32 installed successfully')"
                if ($LASTEXITCODE -ne 0) { throw "Failed to install pywin32" }
            } else {
                Write-Success "Windows dependencies already available"
            }
        } catch {
            Write-Warning "Error checking Windows dependencies, installing anyway..."
            python -m pip install --upgrade pip wheel setuptools
            python -m pip install pywin32 pywin32-ctypes
        }
        
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

function Get-PyInstallerSpec {
    param([string]$ProjectVersion)
    
    Write-Step "Preparing PyInstaller configuration..."
    
    # Use existing comprehensive spec file instead of generating
    $specFile = Join-Path $PSScriptRoot ".." ".." "scripts" "pyinstaller" "serena.spec"
    if (-not (Test-Path $specFile)) {
        throw "PyInstaller spec file not found: $specFile"
    }

    Write-Success "Using existing spec file: $specFile"

    # Set environment variables for PyInstaller
    $env:SERENA_VERSION = $ProjectVersion
    $env:SERENA_BUILD_TIER = $Tier
    $env:LANGUAGE_SERVERS_DIR = $LanguageServersDir
    $env:PROJECT_ROOT = $RepoRoot
    
    Write-Info "Environment variables set:"
    Write-Info "  SERENA_VERSION: $ProjectVersion"
    Write-Info "  SERENA_BUILD_TIER: $Tier"
    Write-Info "  LANGUAGE_SERVERS_DIR: $LanguageServersDir"
    Write-Info "  PROJECT_ROOT: $RepoRoot"
    
    return $specFile
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
    
    # Build version info content with proper variable interpolation
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
    try {
        Set-Content -Path $versionPath -Value $versionInfoContent -Encoding UTF8
        
        if (-not (Test-Path $versionPath)) {
            throw "Version info file was not created successfully"
        }
        
        # Verify the content was written correctly
        $writtenContent = Get-Content $versionPath -Raw
        if (-not $writtenContent -or $writtenContent.Length -lt 100) {
            throw "Version info file content appears to be incomplete"
        }
        
        Write-Success "Version info created: $versionPath"
        return $versionPath
    } catch {
        Write-Error "Failed to create version info: $_"
        throw
    }
}

function Build-WithPyInstaller {
    param(
        [string]$SpecPath,
        [string]$ProjectVersion
    )
    
    Write-Step "Building with PyInstaller..."
    
    try {
        # Run PyInstaller from project root
        Push-Location $RepoRoot
        
        # Diagnostic information
        Write-Host "=== Build Environment ===" -ForegroundColor Cyan
        Write-Host "Python Version: $(python --version)"
        Write-Host "UV Version: $(uv --version)"
        Write-Host "Working Directory: $(Get-Location)"
        Write-Host "Project Root: $RepoRoot"
        Write-Host "Language Servers Dir: $LanguageServersDir"
        Write-Host "=========================" -ForegroundColor Cyan
        
        Write-Info "Starting PyInstaller build..."
        Write-Info "Spec file: $SpecPath"
        Write-Info "Working directory: $RepoRoot"
        
        # Check if language servers directory exists and show contents
        if (Test-Path $LanguageServersDir) {
            Write-Info "Language servers found - will be included in bundle:"
            Get-ChildItem $LanguageServersDir | ForEach-Object { Write-Info "  - $($_.Name)" }
        } else {
            Write-Warning "No language servers found at: $LanguageServersDir"
        }
        
        $pyInstallerArgs = @(
            $SpecPath,
            "--clean",
            "--noconfirm",
            "--distpath", "dist",
            "--workpath", "build",
            "--log-level", "DEBUG"
        )
        
        Write-Info "Running PyInstaller with args: $($pyInstallerArgs -join ' ')"
        Write-Info "Starting PyInstaller build process..."
        
        $pyinstallerOutput = & uv run pyinstaller @pyInstallerArgs 2>&1
        
        # Display the output
        Write-Host "PyInstaller Output:" -ForegroundColor Yellow
        $pyinstallerOutput | ForEach-Object { Write-Host $_ }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "PyInstaller failed with exit code $LASTEXITCODE"
            Write-Error "Build output:"
            $pyinstallerOutput | ForEach-Object { Write-Error $_ }
            throw "PyInstaller failed with exit code $LASTEXITCODE"
        }
        
        # Verify output - check for the main serena-mcp-server executable
        $builtAppPath = Join-Path "dist" "serena-mcp-server"
        $exePath = Join-Path $builtAppPath "serena-mcp-server.exe"
        
        if (-not (Test-Path $builtAppPath)) {
            Write-Error "Built application directory not found: $builtAppPath"
            Write-Error "Contents of dist directory:"
            if (Test-Path "dist") {
                Get-ChildItem "dist" | ForEach-Object { Write-Error "  - $($_.Name)" }
            } else {
                Write-Error "Dist directory does not exist"
            }
            throw "Built application directory not found: $builtAppPath"
        }
        
        if (-not (Test-Path $exePath)) {
            Write-Error "PyInstaller did not create expected executable: $exePath"
            Write-Error "Contents of built app directory:"
            Get-ChildItem $builtAppPath | ForEach-Object { Write-Error "  - $($_.Name)" }
            throw "PyInstaller did not create expected executable: $exePath"
        }
        
        # Show build statistics
        $appSize = (Get-ChildItem $builtAppPath -Recurse | Measure-Object -Property Length -Sum).Sum
        $appSizeMB = [math]::Round($appSize / 1MB, 1)
        Write-Info "Build size: $appSizeMB MB"
        
        Write-Success "Successfully created executable: $exePath"
        Write-Success "PyInstaller build completed: $builtAppPath"
        return $builtAppPath
        
    } catch {
        Write-Error "PyInstaller build failed: $_"
        Write-Error "Error details: $($_.Exception.Message)"
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
        throw
    } finally {
        Pop-Location
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
    $specPath = Get-PyInstallerSpec -ProjectVersion $projectVersion
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