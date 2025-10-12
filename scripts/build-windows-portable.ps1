#Requires -Version 5.1

<#
.SYNOPSIS
    Master Build Orchestrator for Serena Windows Portable Distribution

.DESCRIPTION
    Complete CI/CD-ready build automation script that orchestrates all stages of creating
    a production-ready Windows portable package for Serena MCP.

    This script performs:
    1. Environment validation (Python 3.11, uv, PyInstaller)
    2. Dependency installation (uv sync)
    3. Test execution (type-check, lint, pytest - optional with -SkipTests)
    4. Language server bundling (calls bundle-language-servers-windows.ps1)
    5. PyInstaller build (all 3 executables)
    6. Directory structure creation
    7. File copying (executables, configs, docs, launchers, LS)
    8. ZIP archive creation
    9. SHA256 checksum generation
    10. Build manifest generation

.PARAMETER Tier
    Language server tier to bundle: minimal, essential, complete, or full
    - minimal: Python only
    - essential: Python, TypeScript, Rust, Go, Lua, Markdown (default)
    - complete: Essential + Java, C#, PHP, Ruby, Bash, Swift
    - full: All supported language servers

.PARAMETER Version
    Version string for the build. If not specified, auto-detected from pyproject.toml

.PARAMETER OutputDir
    Output directory for the build artifacts (default: dist/windows)

.PARAMETER Architecture
    Target architecture: x64 or arm64 (default: x64)

.PARAMETER Clean
    Remove previous builds before starting

.PARAMETER SkipTests
    Skip type-checking, linting, and test execution

.PARAMETER SkipLanguageServers
    Skip language server bundling (faster builds for testing)

.PARAMETER NoArchive
    Skip ZIP archive creation (keeps directory only)

.PARAMETER NoChecksums
    Skip SHA256 checksum generation

.PARAMETER Verbose
    Enable verbose logging output

.EXAMPLE
    .\build-windows-portable.ps1
    # Build with default settings (essential tier, x64, with tests)

.EXAMPLE
    .\build-windows-portable.ps1 -Tier full -Architecture arm64 -Clean
    # Clean build with full language servers for ARM64

.EXAMPLE
    .\build-windows-portable.ps1 -SkipTests -SkipLanguageServers -NoArchive
    # Fast development build without tests, language servers, or archiving

.EXAMPLE
    .\build-windows-portable.ps1 -Version "0.2.0-beta" -OutputDir "C:\builds"
    # Custom version and output directory

.NOTES
    Author: Serena Development Team / Anthropic Claude Code
    License: MIT
    Requires: PowerShell 5.1+, Python 3.11, uv, PyInstaller
    CI/CD: Suitable for GitHub Actions, Azure DevOps, Jenkins
#>

param(
    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier = "essential",

    [string]$Version = "",

    [string]$OutputDir = "dist\windows",

    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [switch]$Clean,

    [switch]$SkipTests,

    [switch]$SkipLanguageServers,

    [switch]$NoArchive,

    [switch]$NoChecksums,

    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Speed up operations

# ============================================================================
# GLOBAL CONFIGURATION
# ============================================================================

$script:BuildStartTime = Get-Date
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:LogFile = Join-Path $script:ProjectRoot "build.log"
$script:BuildErrors = @()
$script:BuildWarnings = @()

# Build stage tracking
$script:CurrentStage = 0
$script:TotalStages = 10
$script:StageNames = @(
    "Environment Validation",
    "Dependency Installation",
    "Test Execution",
    "Language Server Bundling",
    "PyInstaller Build",
    "Directory Structure Creation",
    "File Copying",
    "ZIP Archive Creation",
    "Checksum Generation",
    "Build Manifest Generation"
)

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "STEP", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue

    # Console output with colors
    switch ($Level) {
        "SUCCESS" {
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[OK]   " -ForegroundColor Green -NoNewline
            Write-Host $Message
        }
        "ERROR" {
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[ERR]  " -ForegroundColor Red -NoNewline
            Write-Host $Message -ForegroundColor Red
            $script:BuildErrors += $Message
        }
        "WARNING" {
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
            Write-Host $Message -ForegroundColor Yellow
            $script:BuildWarnings += $Message
        }
        "STEP" {
            Write-Host "`n[$timestamp] " -ForegroundColor Magenta -NoNewline
            Write-Host "===> $Message" -ForegroundColor White
        }
        "DEBUG" {
            if ($Verbose) {
                Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
                Write-Host "[DBG]  " -ForegroundColor Cyan -NoNewline
                Write-Host $Message -ForegroundColor Gray
            }
        }
        default {
            Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
            Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
            Write-Host $Message
        }
    }
}

function Write-StageHeader {
    param([string]$StageName)

    $script:CurrentStage++
    $stageNum = $script:CurrentStage
    $totalStages = $script:TotalStages

    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Magenta
    Write-Host "STAGE [$stageNum/$totalStages]: $StageName" -ForegroundColor White
    Write-Host "=" * 80 -ForegroundColor Magenta
    Write-Log "Starting stage $stageNum/$totalStages`: $StageName" "STEP"
}

function Write-Progress-Bar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity
    )

    $percent = [math]::Round(($Current / $Total) * 100, 1)
    $barWidth = 50
    $filledWidth = [math]::Floor(($percent / 100) * $barWidth)
    $emptyWidth = $barWidth - $filledWidth

    $bar = "[" + ("=" * $filledWidth) + (" " * $emptyWidth) + "]"

    Write-Host "`r$bar $percent% - $Activity" -NoNewline
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Get-SerenaVersion {
    <#
    .SYNOPSIS
        Extracts version from pyproject.toml
    #>
    try {
        $pyprojectPath = Join-Path $script:ProjectRoot "pyproject.toml"

        if (-not (Test-Path $pyprojectPath)) {
            throw "pyproject.toml not found at: $pyprojectPath"
        }

        $content = Get-Content $pyprojectPath -Raw
        if ($content -match 'version\s*=\s*"([^"]+)"') {
            return $Matches[1]
        } else {
            throw "Could not parse version from pyproject.toml"
        }
    } catch {
        Write-Log "Failed to extract version from pyproject.toml: $_" "WARNING"
        return "0.1.4-unknown"
    }
}

function Test-CommandExists {
    param([string]$Command)

    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Test-DiskSpace {
    param(
        [string]$Path,
        [int]$RequiredGB = 2
    )

    try {
        $drive = (Get-Item $Path -ErrorAction SilentlyContinue).PSDrive.Name
        if (-not $drive) {
            $drive = (Split-Path $Path -Qualifier).TrimEnd(':')
        }

        $freeSpace = (Get-PSDrive $drive).Free / 1GB

        if ($freeSpace -lt $RequiredGB) {
            Write-Log "Low disk space on $drive`: $([math]::Round($freeSpace, 2)) GB free. At least $RequiredGB GB recommended." "WARNING"
            return $false
        }

        Write-Log "Available disk space: $([math]::Round($freeSpace, 2)) GB" "SUCCESS"
        return $true
    } catch {
        Write-Log "Could not check disk space: $_" "WARNING"
        return $true # Don't fail build on disk check error
    }
}

function Invoke-CommandWithLogging {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $script:ProjectRoot,
        [string]$Description = "Running command",
        [bool]$CaptureOutput = $false
    )

    Write-Log "$Description..." "INFO"
    Write-Log "Command: $Command $($Arguments -join ' ')" "DEBUG"

    try {
        $processArgs = @{
            FilePath = $Command
            ArgumentList = $Arguments
            WorkingDirectory = $WorkingDirectory
            NoNewWindow = $true
            Wait = $true
            PassThru = $true
        }

        if ($CaptureOutput) {
            $processArgs['RedirectStandardOutput'] = Join-Path $env:TEMP "stdout.txt"
            $processArgs['RedirectStandardError'] = Join-Path $env:TEMP "stderr.txt"
        }

        $process = Start-Process @processArgs

        if ($CaptureOutput) {
            $stdout = Get-Content (Join-Path $env:TEMP "stdout.txt") -Raw -ErrorAction SilentlyContinue
            $stderr = Get-Content (Join-Path $env:TEMP "stderr.txt") -Raw -ErrorAction SilentlyContinue

            Remove-Item (Join-Path $env:TEMP "stdout.txt") -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $env:TEMP "stderr.txt") -Force -ErrorAction SilentlyContinue
        }

        if ($process.ExitCode -ne 0) {
            if ($CaptureOutput -and $stderr) {
                throw "$Description failed with exit code $($process.ExitCode): $stderr"
            } else {
                throw "$Description failed with exit code $($process.ExitCode)"
            }
        }

        Write-Log "$Description completed successfully" "SUCCESS"

        if ($CaptureOutput) {
            return @{
                ExitCode = $process.ExitCode
                StandardOutput = $stdout
                StandardError = $stderr
            }
        }

        return $process.ExitCode
    } catch {
        Write-Log "$Description failed: $_" "ERROR"
        throw
    }
}

# ============================================================================
# STAGE 1: ENVIRONMENT VALIDATION
# ============================================================================

function Test-BuildEnvironment {
    Write-StageHeader "Environment Validation"

    $validationPassed = $true

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Log "PowerShell 5.1 or higher is required (current: $psVersion)" "ERROR"
        $validationPassed = $false
    } else {
        Write-Log "PowerShell version: $psVersion" "SUCCESS"
    }

    # Check Python 3.11
    if (Test-CommandExists "python") {
        $pythonVersion = python --version 2>&1 | Out-String
        if ($pythonVersion -match "Python 3\.11\.(\d+)") {
            Write-Log "Python version: $pythonVersion" "SUCCESS"
        } else {
            Write-Log "Python 3.11 is required (current: $pythonVersion)" "ERROR"
            $validationPassed = $false
        }
    } else {
        Write-Log "Python not found in PATH" "ERROR"
        $validationPassed = $false
    }

    # Check uv
    if (Test-CommandExists "uv") {
        $uvVersion = uv --version 2>&1 | Out-String
        Write-Log "uv version: $uvVersion" "SUCCESS"
    } else {
        Write-Log "uv not found in PATH. Install from: https://docs.astral.sh/uv/getting-started/installation/" "ERROR"
        $validationPassed = $false
    }

    # Check PyInstaller (will be installed if missing)
    if (Test-CommandExists "pyinstaller") {
        $pyinstallerVersion = pyinstaller --version 2>&1 | Out-String
        Write-Log "PyInstaller version: $pyinstallerVersion" "SUCCESS"
    } else {
        Write-Log "PyInstaller not found (will be installed with dependencies)" "WARNING"
    }

    # Check disk space
    $null = Test-DiskSpace -Path $script:ProjectRoot -RequiredGB 2

    # Check required directories
    $requiredDirs = @(
        (Join-Path $script:ProjectRoot "src"),
        (Join-Path $script:ProjectRoot "scripts")
    )

    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir) {
            Write-Log "Found required directory: $dir" "SUCCESS"
        } else {
            Write-Log "Missing required directory: $dir" "ERROR"
            $validationPassed = $false
        }
    }

    # Check pyproject.toml
    $pyprojectPath = Join-Path $script:ProjectRoot "pyproject.toml"
    if (Test-Path $pyprojectPath) {
        Write-Log "Found pyproject.toml" "SUCCESS"
    } else {
        Write-Log "Missing pyproject.toml" "ERROR"
        $validationPassed = $false
    }

    # Check PyInstaller spec file
    $specFile = Join-Path $script:ProjectRoot "scripts\pyinstaller\serena-windows.spec"
    if (Test-Path $specFile) {
        Write-Log "Found PyInstaller spec file" "SUCCESS"
    } else {
        Write-Log "Missing PyInstaller spec file: $specFile" "ERROR"
        $validationPassed = $false
    }

    if (-not $validationPassed) {
        throw "Environment validation failed. Please fix the errors above."
    }

    Write-Log "Environment validation passed" "SUCCESS"
}

# ============================================================================
# STAGE 2: DEPENDENCY INSTALLATION
# ============================================================================

function Install-Dependencies {
    Write-StageHeader "Dependency Installation"

    try {
        # Install dependencies with uv
        Invoke-CommandWithLogging `
            -Command "uv" `
            -Arguments @("sync", "--all-extras") `
            -Description "Installing dependencies with uv sync"

        # Verify installation
        Write-Log "Verifying core dependencies..." "INFO"

        $testImports = @(
            "serena",
            "solidlsp",
            "mcp",
            "anthropic",
            "pydantic",
            "flask"
        )

        foreach ($import in $testImports) {
            try {
                $result = python -c "import $import; print('OK')" 2>&1
                if ($result -match "OK") {
                    Write-Log "Verified import: $import" "SUCCESS"
                } else {
                    Write-Log "Failed to import: $import" "WARNING"
                }
            } catch {
                Write-Log "Failed to verify import: $import" "WARNING"
            }
        }

        Write-Log "Dependency installation completed" "SUCCESS"

    } catch {
        Write-Log "Dependency installation failed: $_" "ERROR"
        throw
    }
}

# ============================================================================
# STAGE 3: TEST EXECUTION
# ============================================================================

function Invoke-Tests {
    Write-StageHeader "Test Execution"

    if ($SkipTests) {
        Write-Log "Skipping tests (SkipTests flag set)" "WARNING"
        return
    }

    try {
        # Type checking with mypy
        Write-Log "Running type checking (mypy)..." "INFO"
        Invoke-CommandWithLogging `
            -Command "uv" `
            -Arguments @("run", "poe", "type-check") `
            -Description "Type checking with mypy"

        # Linting with black and ruff
        Write-Log "Running linting checks..." "INFO"
        Invoke-CommandWithLogging `
            -Command "uv" `
            -Arguments @("run", "poe", "lint") `
            -Description "Linting with black and ruff"

        # Run tests (exclude slow language tests by default)
        Write-Log "Running pytest..." "INFO"
        Invoke-CommandWithLogging `
            -Command "uv" `
            -Arguments @("run", "poe", "test", "-m", "not java and not rust and not erlang") `
            -Description "Running pytest"

        Write-Log "All tests passed" "SUCCESS"

    } catch {
        Write-Log "Tests failed: $_" "ERROR"
        throw
    }
}

# ============================================================================
# STAGE 4: LANGUAGE SERVER BUNDLING
# ============================================================================

function Invoke-LanguageServerBundling {
    Write-StageHeader "Language Server Bundling"

    if ($SkipLanguageServers) {
        Write-Log "Skipping language server bundling (SkipLanguageServers flag set)" "WARNING"
        return
    }

    try {
        $bundleScript = Join-Path $script:ProjectRoot "scripts\bundle-language-servers-windows.ps1"

        if (-not (Test-Path $bundleScript)) {
            Write-Log "Language server bundling script not found: $bundleScript" "WARNING"
            Write-Log "Language servers will be downloaded on first use" "WARNING"
            return
        }

        $lsOutputDir = Join-Path $script:ProjectRoot "build\language_servers_bundle"

        Write-Log "Running bundle-language-servers-windows.ps1..." "INFO"
        Write-Log "Tier: $Tier, Architecture: $Architecture" "INFO"

        # Call the language server bundling script
        & $bundleScript `
            -OutputDir $lsOutputDir `
            -Architecture $Architecture `
            -IncludeNodeJS $true

        if ($LASTEXITCODE -ne 0) {
            throw "Language server bundling failed with exit code: $LASTEXITCODE"
        }

        # Verify bundle was created
        if (Test-Path $lsOutputDir) {
            $bundleSize = (Get-ChildItem -Path $lsOutputDir -Recurse -File |
                          Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Log "Language server bundle created: $([math]::Round($bundleSize, 2)) MB" "SUCCESS"
        } else {
            Write-Log "Language server bundle directory not found after bundling" "WARNING"
        }

    } catch {
        Write-Log "Language server bundling failed: $_" "ERROR"
        # Don't fail the build - language servers can be downloaded on first use
        Write-Log "Continuing without bundled language servers" "WARNING"
    }
}

# ============================================================================
# STAGE 5: PYINSTALLER BUILD
# ============================================================================

function Invoke-PyInstallerBuild {
    Write-StageHeader "PyInstaller Build"

    try {
        $specFile = Join-Path $script:ProjectRoot "scripts\pyinstaller\serena-windows.spec"
        $distDir = Join-Path $script:ProjectRoot "dist"

        # Set environment variables for PyInstaller spec
        $env:PROJECT_ROOT = $script:ProjectRoot
        $env:SERENA_VERSION = $Version
        $env:SERENA_BUILD_TIER = $Tier
        $env:LANGUAGE_SERVERS_DIR = Join-Path $script:ProjectRoot "build\language_servers_bundle\language_servers"
        $env:RUNTIMES_DIR = Join-Path $script:ProjectRoot "build\language_servers_bundle\runtimes"

        Write-Log "Running PyInstaller..." "INFO"
        Write-Log "Spec file: $specFile" "DEBUG"
        Write-Log "Output: $distDir\serena-windows" "DEBUG"

        # Run PyInstaller
        Invoke-CommandWithLogging `
            -Command "pyinstaller" `
            -Arguments @(
                "--clean",
                "--noconfirm",
                "--distpath", $distDir,
                "--workpath", (Join-Path $script:ProjectRoot "build\pyinstaller"),
                $specFile
            ) `
            -Description "Building with PyInstaller"

        # Verify build output
        $buildOutput = Join-Path $distDir "serena-windows"
        if (Test-Path $buildOutput) {
            $executables = @(
                "serena-mcp-server.exe",
                "serena.exe",
                "index-project.exe"
            )

            foreach ($exe in $executables) {
                $exePath = Join-Path $buildOutput $exe
                if (Test-Path $exePath) {
                    $exeSize = (Get-Item $exePath).Length / 1MB
                    Write-Log "Built: $exe ($([math]::Round($exeSize, 2)) MB)" "SUCCESS"
                } else {
                    Write-Log "Missing executable: $exe" "ERROR"
                    throw "PyInstaller build incomplete"
                }
            }

            $totalSize = (Get-ChildItem -Path $buildOutput -Recurse -File |
                         Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Log "Total build size: $([math]::Round($totalSize, 2)) MB" "SUCCESS"

        } else {
            throw "PyInstaller output directory not found: $buildOutput"
        }

        Write-Log "PyInstaller build completed" "SUCCESS"

    } catch {
        Write-Log "PyInstaller build failed: $_" "ERROR"
        throw
    }
}

# ============================================================================
# STAGE 6: DIRECTORY STRUCTURE CREATION
# ============================================================================

function New-PortableStructure {
    Write-StageHeader "Directory Structure Creation"

    try {
        $packageName = "serena-portable-v$Version-windows-$Architecture-$Tier"
        $packageDir = Join-Path $OutputDir $packageName

        Write-Log "Creating portable package structure..." "INFO"
        Write-Log "Package directory: $packageDir" "DEBUG"

        # Create main directories
        $directories = @(
            $packageDir,
            (Join-Path $packageDir "bin"),
            (Join-Path $packageDir "language_servers"),
            (Join-Path $packageDir "config"),
            (Join-Path $packageDir "docs"),
            (Join-Path $packageDir "scripts"),
            (Join-Path $packageDir "examples")
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Log "Created directory: $dir" "DEBUG"
            }
        }

        Write-Log "Directory structure created" "SUCCESS"
        return $packageDir

    } catch {
        Write-Log "Directory structure creation failed: $_" "ERROR"
        throw
    }
}

# ============================================================================
# STAGE 7: FILE COPYING
# ============================================================================

function Copy-BuildArtifacts {
    param([string]$PackageDir)

    Write-StageHeader "File Copying"

    try {
        # Copy PyInstaller output to bin/
        Write-Log "Copying executables and runtime..." "INFO"
        $buildOutput = Join-Path $script:ProjectRoot "dist\serena-windows"
        $binDir = Join-Path $PackageDir "bin"

        if (Test-Path $buildOutput) {
            # Copy all files from PyInstaller output
            Copy-Item -Path "$buildOutput\*" -Destination $binDir -Recurse -Force
            Write-Log "Copied PyInstaller output to bin/" "SUCCESS"
        } else {
            throw "PyInstaller output not found: $buildOutput"
        }

        # Copy language servers if bundled
        $lsSourceDir = Join-Path $script:ProjectRoot "build\language_servers_bundle\language_servers"
        $lsDestDir = Join-Path $PackageDir "language_servers"

        if (Test-Path $lsSourceDir) {
            Write-Log "Copying language servers..." "INFO"
            Copy-Item -Path "$lsSourceDir\*" -Destination $lsDestDir -Recurse -Force
            Write-Log "Copied language servers" "SUCCESS"
        } else {
            Write-Log "No language servers to copy (will be downloaded on first use)" "WARNING"
        }

        # Copy config examples
        Write-Log "Copying configuration examples..." "INFO"
        $configSourceDir = Join-Path $script:ProjectRoot "src\serena\resources\config"
        $configDestDir = Join-Path $PackageDir "config"

        if (Test-Path $configSourceDir) {
            Copy-Item -Path "$configSourceDir\*" -Destination $configDestDir -Recurse -Force
            Write-Log "Copied configuration examples" "SUCCESS"
        }

        # Copy documentation
        Write-Log "Copying documentation..." "INFO"
        $docsDestDir = Join-Path $PackageDir "docs"

        $docFiles = @(
            @{ Source = "README.md"; Dest = "README.md" },
            @{ Source = "LICENSE"; Dest = "LICENSE.txt" },
            @{ Source = "CHANGELOG.md"; Dest = "CHANGELOG.md" }
        )

        foreach ($doc in $docFiles) {
            $sourcePath = Join-Path $script:ProjectRoot $doc.Source
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination (Join-Path $docsDestDir $doc.Dest) -Force
                Write-Log "Copied: $($doc.Source)" "DEBUG"
            }
        }

        # Create launcher scripts
        Write-Log "Creating launcher scripts..." "INFO"
        New-LauncherScripts -PackageDir $PackageDir

        # Create installation guide
        Write-Log "Creating installation guide..." "INFO"
        New-InstallationGuide -PackageDir $PackageDir

        Write-Log "File copying completed" "SUCCESS"

    } catch {
        Write-Log "File copying failed: $_" "ERROR"
        throw
    }
}

function New-LauncherScripts {
    param([string]$PackageDir)

    $scriptsDir = Join-Path $PackageDir "scripts"

    # Windows batch launcher for MCP server
    $mcpLauncher = @"
@echo off
REM Serena MCP Server Launcher
REM This script starts the Serena MCP server with stdio transport

setlocal
set SERENA_ROOT=%~dp0..
set PATH=%SERENA_ROOT%\bin;%PATH%

REM Run the MCP server
"%SERENA_ROOT%\bin\serena-mcp-server.exe" %*

endlocal
"@

    $mcpLauncherPath = Join-Path $scriptsDir "start-mcp-server.bat"
    $mcpLauncher | Set-Content -Path $mcpLauncherPath -Encoding ASCII
    Write-Log "Created: start-mcp-server.bat" "DEBUG"

    # PowerShell launcher for CLI
    $cliLauncher = @"
# Serena CLI Launcher
# This script runs the Serena command-line interface

`$env:SERENA_ROOT = Split-Path `$PSScriptRoot -Parent
`$env:PATH = "`$env:SERENA_ROOT\bin;`$env:PATH"

& "`$env:SERENA_ROOT\bin\serena.exe" `$args
"@

    $cliLauncherPath = Join-Path $scriptsDir "serena.ps1"
    $cliLauncher | Set-Content -Path $cliLauncherPath -Encoding UTF8
    Write-Log "Created: serena.ps1" "DEBUG"

    # Add PATH setup script
    $pathSetup = @"
@echo off
REM Add Serena to PATH for current session
REM Run this script as: call add-to-path.bat

set SERENA_ROOT=%~dp0..
set PATH=%SERENA_ROOT%\bin;%SERENA_ROOT%\bin\language_servers;%PATH%

echo Serena added to PATH for this session.
echo Run 'serena --help' to get started.
"@

    $pathSetupPath = Join-Path $scriptsDir "add-to-path.bat"
    $pathSetup | Set-Content -Path $pathSetupPath -Encoding ASCII
    Write-Log "Created: add-to-path.bat" "DEBUG"
}

function New-InstallationGuide {
    param([string]$PackageDir)

    $guide = @"
# Serena Portable Windows Package - Installation Guide

## Package Information
- **Version**: $Version
- **Architecture**: $Architecture
- **Tier**: $Tier
- **Build Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## What's Included

### Executables (in `bin/` directory)
- **serena-mcp-server.exe** - MCP server for AI assistant integration
- **serena.exe** - Command-line interface
- **index-project.exe** - Project indexing tool (legacy)

### Language Servers (in `language_servers/` directory)
The following language servers are bundled for offline use:
$( if ($Tier -eq "minimal") {
    "- Python (Pyright)"
} elseif ($Tier -eq "essential") {
    @"
- Python (Pyright)
- TypeScript/JavaScript
- Rust (rust-analyzer)
- Go (gopls)
- Lua
- Markdown (marksman)
"@
} elseif ($Tier -eq "complete") {
    @"
- Python (Pyright)
- TypeScript/JavaScript
- Rust (rust-analyzer)
- Go (gopls)
- Lua
- Markdown (marksman)
- Java (Eclipse JDT.LS)
- C# (OmniSharp)
- PHP (Intelephense)
- Ruby
- Bash
- Swift
"@
} else {
    "- All supported language servers (16+ languages)"
} )

## Installation Instructions

### Quick Start

1. **Extract the Package**
   Extract this ZIP file to a permanent location (e.g., `C:\Tools\Serena`)

2. **Add to PATH (Optional)**
   For system-wide access, run PowerShell as Administrator:
   ```powershell
   `$serenaPath = "C:\Tools\Serena\bin"
   [Environment]::SetEnvironmentVariable("Path", `$env:Path + ";`$serenaPath", "Machine")
   ```

3. **Verify Installation**
   Open a new terminal and run:
   ```cmd
   serena --version
   serena-mcp-server --help
   ```

### Using with Claude Code

1. **Configure MCP Server**
   Edit your Claude Code configuration file:
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

2. **Add Serena MCP Server**
   ```json
   {
     "mcpServers": {
       "serena": {
         "command": "C:\\Tools\\Serena\\bin\\serena-mcp-server.exe",
         "args": ["--stdio"]
       }
     }
   }
   ```

3. **Restart Claude Code**
   Restart Claude Code/Desktop to load the MCP server

### Using with Other MCP Clients

Serena works with any MCP-compatible client:
- **Cursor**: Configure in settings
- **VSCode with Cline**: Add to MCP servers
- **Terminal clients**: Use stdio transport

Example configuration:
```bash
serena-mcp-server.exe --stdio
```

## Configuration

### Global Configuration
Edit: `%USERPROFILE%\.serena\serena_config.yml`

### Project Configuration
In your project root, create: `.serena/project.yml`

### Example Project Config
```yaml
project_name: "My Project"
project_root: "."
languages:
  - python
  - typescript
  - rust

context: "agent"
mode: "editing"
```

## Directory Structure

```
serena-portable-v$Version-windows-$Architecture-$Tier/
├── bin/                    # Executables and Python runtime
│   ├── serena-mcp-server.exe
│   ├── serena.exe
│   ├── index-project.exe
│   └── _internal/          # Python runtime and dependencies
├── language_servers/       # LSP servers for code analysis
├── config/                 # Configuration examples
│   ├── contexts/
│   └── modes/
├── docs/                   # Documentation
│   ├── README.md
│   ├── CHANGELOG.md
│   └── LICENSE.txt
├── scripts/                # Launcher scripts
│   ├── start-mcp-server.bat
│   ├── serena.ps1
│   └── add-to-path.bat
└── INSTALL.md             # This file
```

## Troubleshooting

### MCP Server Not Starting
1. Check that the path in your MCP config is correct
2. Verify executable permissions
3. Check logs in: `%TEMP%\serena-mcp-server.log`

### Language Server Not Working
1. Verify language server binary exists in `language_servers/`
2. Check language server logs in project `.serena/logs/`
3. Try downloading language server manually: `serena tools list`

### Permission Denied Errors
- Run as Administrator if needed
- Check Windows Defender hasn't quarantined files
- Verify NTFS permissions on extracted files

### Path Not Found
- Use absolute paths in configuration
- Avoid spaces in installation path
- Use forward slashes or escaped backslashes in configs

## Advanced Usage

### Environment Variables
- `SERENA_ROOT` - Override default installation path
- `SERENA_CONFIG_DIR` - Custom config directory
- `SERENA_LOG_LEVEL` - Set logging level (DEBUG, INFO, WARNING, ERROR)

### CLI Commands
```cmd
# Start MCP server
serena-mcp-server --stdio

# Index a project
serena project index

# List available tools
serena tools list

# View configuration
serena config show

# Start interactive mode
serena interactive
```

### Offline Usage
This portable package is designed for offline use. All required:
- Python runtime (embedded)
- Language servers (bundled)
- Dependencies (included)

No internet connection required after installation!

## Getting Help

- **Documentation**: https://github.com/oraios/serena
- **Issues**: https://github.com/oraios/serena/issues
- **Discord**: Join our community server

## License

Serena is open-source software licensed under the MIT License.
See LICENSE.txt for full license text.

## Build Information

- Build Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Build Machine: $env:COMPUTERNAME
- Build Version: $Version
- Architecture: $Architecture
- Language Server Tier: $Tier

---

Thank you for using Serena! Happy coding!
"@

    $guidePath = Join-Path $PackageDir "INSTALL.md"
    $guide | Set-Content -Path $guidePath -Encoding UTF8
    Write-Log "Created installation guide: INSTALL.md" "SUCCESS"
}

# ============================================================================
# STAGE 8: ZIP ARCHIVE CREATION
# ============================================================================

function New-ZipArchive {
    param([string]$PackageDir)

    Write-StageHeader "ZIP Archive Creation"

    if ($NoArchive) {
        Write-Log "Skipping ZIP archive creation (NoArchive flag set)" "WARNING"
        return $null
    }

    try {
        $packageName = Split-Path $PackageDir -Leaf
        $zipPath = Join-Path $OutputDir "$packageName.zip"

        Write-Log "Creating ZIP archive..." "INFO"
        Write-Log "Source: $PackageDir" "DEBUG"
        Write-Log "Destination: $zipPath" "DEBUG"

        # Remove existing archive if present
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
            Write-Log "Removed existing archive" "DEBUG"
        }

        # Create ZIP archive using .NET compression
        Add-Type -Assembly System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($PackageDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length / 1MB
            Write-Log "Created ZIP archive: $([math]::Round($zipSize, 2)) MB" "SUCCESS"
            return $zipPath
        } else {
            throw "ZIP archive not created"
        }

    } catch {
        Write-Log "ZIP archive creation failed: $_" "ERROR"
        throw
    }
}

# ============================================================================
# STAGE 9: CHECKSUM GENERATION
# ============================================================================

function New-Checksums {
    param([string]$ZipPath)

    Write-StageHeader "Checksum Generation"

    if ($NoChecksums) {
        Write-Log "Skipping checksum generation (NoChecksums flag set)" "WARNING"
        return
    }

    if (-not $ZipPath -or -not (Test-Path $ZipPath)) {
        Write-Log "No ZIP archive to checksum" "WARNING"
        return
    }

    try {
        Write-Log "Generating SHA256 checksum..." "INFO"

        $hash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash
        $zipName = Split-Path $ZipPath -Leaf

        $checksumContent = "$hash  $zipName"
        $checksumPath = "$ZipPath.sha256"

        $checksumContent | Set-Content -Path $checksumPath -Encoding ASCII

        Write-Log "SHA256: $hash" "INFO"
        Write-Log "Checksum file: $checksumPath" "SUCCESS"

    } catch {
        Write-Log "Checksum generation failed: $_" "ERROR"
        # Don't fail build on checksum error
    }
}

# ============================================================================
# STAGE 10: BUILD MANIFEST GENERATION
# ============================================================================

function New-BuildManifest {
    param(
        [string]$PackageDir,
        [string]$ZipPath
    )

    Write-StageHeader "Build Manifest Generation"

    try {
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $script:BuildStartTime

        $manifest = @{
            version = $Version
            build = @{
                date = $script:BuildStartTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
                duration_seconds = [math]::Round($buildDuration.TotalSeconds, 2)
                machine = $env:COMPUTERNAME
                user = $env:USERNAME
            }
            package = @{
                name = Split-Path $PackageDir -Leaf
                architecture = $Architecture
                tier = $Tier
                path = $PackageDir
            }
            components = @{
                python_version = (python --version 2>&1 | Out-String).Trim()
                pyinstaller_version = (pyinstaller --version 2>&1 | Out-String).Trim()
                executables = @(
                    "serena-mcp-server.exe",
                    "serena.exe",
                    "index-project.exe"
                )
            }
            flags = @{
                skip_tests = $SkipTests.IsPresent
                skip_language_servers = $SkipLanguageServers.IsPresent
                no_archive = $NoArchive.IsPresent
                clean_build = $Clean.IsPresent
            }
        }

        # Add archive info if created
        if ($ZipPath -and (Test-Path $ZipPath)) {
            $zipSize = (Get-Item $ZipPath).Length
            $zipHash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

            $manifest.archive = @{
                path = $ZipPath
                size_bytes = $zipSize
                size_mb = [math]::Round($zipSize / 1MB, 2)
                sha256 = $zipHash
            }
        }

        # Add build statistics
        $manifest.statistics = @{
            errors = $script:BuildErrors.Count
            warnings = $script:BuildWarnings.Count
        }

        if ($script:BuildErrors.Count -gt 0) {
            $manifest.errors = $script:BuildErrors
        }

        if ($script:BuildWarnings.Count -gt 0) {
            $manifest.warnings = $script:BuildWarnings
        }

        # Save manifest
        $manifestPath = Join-Path $OutputDir "build-manifest.json"
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

        Write-Log "Build manifest created: $manifestPath" "SUCCESS"

        # Also save in package directory
        $packageManifestPath = Join-Path $PackageDir "BUILD-MANIFEST.json"
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $packageManifestPath -Encoding UTF8

        Write-Log "Package manifest created: $packageManifestPath" "SUCCESS"

    } catch {
        Write-Log "Build manifest generation failed: $_" "ERROR"
        # Don't fail build on manifest error
    }
}

# ============================================================================
# MAIN BUILD ORCHESTRATION
# ============================================================================

function Start-Build {
    try {
        # Initialize log file
        if (Test-Path $script:LogFile) {
            Remove-Item $script:LogFile -Force
        }
        "Build Log - Started at $($script:BuildStartTime)" | Set-Content -Path $script:LogFile

        # Print banner
        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Magenta
        Write-Host "  SERENA WINDOWS PORTABLE BUILD SYSTEM" -ForegroundColor White
        Write-Host "  Production CI/CD-Ready Build Automation" -ForegroundColor White
        Write-Host "=" * 80 -ForegroundColor Magenta
        Write-Host ""

        # Get version if not specified
        if (-not $Version) {
            $script:Version = Get-SerenaVersion
            Write-Log "Auto-detected version from pyproject.toml: $Version" "INFO"
        } else {
            $script:Version = $Version
        }

        # Display build configuration
        Write-Log "Build Configuration:" "INFO"
        Write-Log "  Version: $Version" "INFO"
        Write-Log "  Architecture: $Architecture" "INFO"
        Write-Log "  Tier: $Tier" "INFO"
        Write-Log "  Output Directory: $OutputDir" "INFO"
        Write-Log "  Clean Build: $Clean" "INFO"
        Write-Log "  Skip Tests: $SkipTests" "INFO"
        Write-Log "  Skip Language Servers: $SkipLanguageServers" "INFO"
        Write-Log "  No Archive: $NoArchive" "INFO"
        Write-Host ""

        # Clean previous builds if requested
        if ($Clean) {
            Write-Log "Cleaning previous builds..." "INFO"
            $cleanDirs = @(
                (Join-Path $script:ProjectRoot "dist"),
                (Join-Path $script:ProjectRoot "build"),
                $OutputDir
            )

            foreach ($dir in $cleanDirs) {
                if (Test-Path $dir) {
                    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $dir" "DEBUG"
                }
            }
            Write-Log "Clean completed" "SUCCESS"
        }

        # Ensure output directory exists
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }

        # Execute build stages
        Test-BuildEnvironment
        Install-Dependencies
        Invoke-Tests
        Invoke-LanguageServerBundling
        Invoke-PyInstallerBuild
        $packageDir = New-PortableStructure
        Copy-BuildArtifacts -PackageDir $packageDir
        $zipPath = New-ZipArchive -PackageDir $packageDir
        New-Checksums -ZipPath $zipPath
        New-BuildManifest -PackageDir $packageDir -ZipPath $zipPath

        # Build complete!
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $script:BuildStartTime

        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Green
        Write-Host "  BUILD COMPLETED SUCCESSFULLY!" -ForegroundColor White
        Write-Host "=" * 80 -ForegroundColor Green
        Write-Host ""

        Write-Log "Build Duration: $([math]::Round($buildDuration.TotalMinutes, 2)) minutes" "SUCCESS"
        Write-Log "Package Location: $packageDir" "SUCCESS"

        if ($zipPath) {
            Write-Log "Archive Location: $zipPath" "SUCCESS"
        }

        Write-Log "Build Log: $script:LogFile" "SUCCESS"

        # Display summary
        Write-Host "`nBuild Summary:" -ForegroundColor Cyan
        Write-Host "  Errors: $($script:BuildErrors.Count)" -ForegroundColor $(if ($script:BuildErrors.Count -eq 0) { "Green" } else { "Red" })
        Write-Host "  Warnings: $($script:BuildWarnings.Count)" -ForegroundColor $(if ($script:BuildWarnings.Count -eq 0) { "Green" } else { "Yellow" })

        if ($script:BuildWarnings.Count -gt 0) {
            Write-Host "`nWarnings:" -ForegroundColor Yellow
            foreach ($warning in $script:BuildWarnings) {
                Write-Host "  - $warning" -ForegroundColor Yellow
            }
        }

        Write-Host "`nNext Steps:" -ForegroundColor Cyan
        Write-Host "  1. Test the executable: .\$packageDir\bin\serena-mcp-server.exe --help" -ForegroundColor White
        Write-Host "  2. Read installation guide: .\$packageDir\INSTALL.md" -ForegroundColor White
        Write-Host "  3. Distribute the ZIP: $zipPath" -ForegroundColor White
        Write-Host ""

        exit 0

    } catch {
        # Build failed!
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $script:BuildStartTime

        Write-Host "`n" -NoNewline
        Write-Host "=" * 80 -ForegroundColor Red
        Write-Host "  BUILD FAILED!" -ForegroundColor White
        Write-Host "=" * 80 -ForegroundColor Red
        Write-Host ""

        Write-Log "Build failed after $([math]::Round($buildDuration.TotalMinutes, 2)) minutes" "ERROR"
        Write-Log "Error: $_" "ERROR"
        Write-Log "Build Log: $script:LogFile" "ERROR"

        if ($script:BuildErrors.Count -gt 0) {
            Write-Host "`nBuild Errors:" -ForegroundColor Red
            foreach ($error in $script:BuildErrors) {
                Write-Host "  - $error" -ForegroundColor Red
            }
        }

        Write-Host "`nFor detailed information, check: $script:LogFile" -ForegroundColor Yellow
        Write-Host ""

        exit 1
    }
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Run the build
Start-Build
