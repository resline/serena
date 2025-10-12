#Requires -Version 5.1

<#
.SYNOPSIS
    Master Windows Portable Package Build Automation for Serena MCP

.DESCRIPTION
    Orchestrates the complete Windows portable package creation process including:
    - Environment validation and setup
    - Dependency resolution and caching
    - PyInstaller build execution (all entry points)
    - Language server bundling
    - Configuration and documentation packaging
    - Final archive creation with compression
    - Checksum generation and build manifest

.PARAMETER Tier
    Language server tier to bundle: minimal, essential, complete, full
    - minimal: No language servers (smallest package)
    - essential: Python, TypeScript, Go, C# (recommended)
    - complete: + Java, Rust, Kotlin, Clojure
    - full: All 28+ supported language servers (largest)

.PARAMETER Version
    Version string for the build (default: auto-detected from pyproject.toml)

.PARAMETER OutputDir
    Output directory for the build artifacts (default: dist/windows)

.PARAMETER Architecture
    Target architecture: x64, x86, or arm64 (default: x64)

.PARAMETER Clean
    Remove previous build artifacts before starting

.PARAMETER SkipTests
    Skip running tests before building (not recommended for production)

.PARAMETER SkipLanguageServers
    Skip language server downloads (creates minimal package)

.PARAMETER NoArchive
    Don't create ZIP archive (keep directory only)

.PARAMETER Parallel
    Number of parallel operations (default: 4)

.EXAMPLE
    .\build-windows-portable.ps1 -Tier essential -Clean

    Creates a clean build with essential language servers

.EXAMPLE
    .\build-windows-portable.ps1 -Tier full -Version "1.0.0" -OutputDir "C:\builds"

    Creates a full build with custom version and output directory

.EXAMPLE
    .\build-windows-portable.ps1 -Tier minimal -SkipTests -NoArchive

    Quick development build without tests or archiving

.NOTES
    Author: Serena Development Team
    License: MIT
    Requires: Python 3.11, uv, PowerShell 5.1+
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier,

    [string]$Version,

    [string]$OutputDir = "dist\windows",

    [ValidateSet("x64", "x86", "arm64")]
    [string]$Architecture = "x64",

    [switch]$Clean,

    [switch]$SkipTests,

    [switch]$SkipLanguageServers,

    [switch]$NoArchive,

    [int]$Parallel = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# ==============================================================================
# Global Variables
# ==============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildStartTime = Get-Date

# Build paths
$TempDir = Join-Path $OutputDir "temp"
$StageDir = Join-Path $TempDir "stage"
$LanguageServersDir = Join-Path $TempDir "language_servers"
$PyInstallerDistDir = Join-Path $RepoRoot "dist"
$BuildLogPath = Join-Path $OutputDir "build.log"

# Build metadata
$BuildId = (Get-Date -Format "yyyyMMdd-HHmmss")
$BuildManifest = @{
    build_id = $BuildId
    timestamp = $BuildStartTime.ToString("o")
    version = $null
    tier = $Tier
    architecture = $Architecture
    stages = @{}
    files = @{}
    checksums = @{}
    metadata = @{
        python_version = $null
        uv_version = $null
        system_info = @{
            os = $null
            platform = "windows"
        }
    }
}

# ==============================================================================
# Logging and Output Functions
# ==============================================================================

function Write-Success {
    param($Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
    Add-BuildLog "SUCCESS" $Message
}

function Write-Error {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Add-BuildLog "ERROR" $Message
}

function Write-Warning {
    param($Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
    Add-BuildLog "WARNING" $Message
}

function Write-Info {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Add-BuildLog "INFO" $Message
}

function Write-Stage {
    param($Stage, $Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host ""
    Write-Host ">>> [$timestamp] STAGE $Stage : $Message" -ForegroundColor Magenta
    Write-Host ""
    Add-BuildLog "STAGE" "$Stage - $Message"
}

function Add-BuildLog {
    param(
        [string]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        if (-not (Test-Path (Split-Path $BuildLogPath))) {
            New-Item -ItemType Directory -Path (Split-Path $BuildLogPath) -Force | Out-Null
        }
        Add-Content -Path $BuildLogPath -Value $logEntry -Encoding UTF8
    } catch {
        # Silently fail if logging doesn't work
    }
}

function Write-Progress-Custom {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )

    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    Write-Info "$Activity - $Status ($PercentComplete%)"
}

# ==============================================================================
# Stage 1: Environment Validation
# ==============================================================================

function Invoke-Stage1-EnvironmentValidation {
    Write-Stage 1 "Environment Validation"
    $stageStart = Get-Date

    try {
        Write-Progress-Custom -Activity "Stage 1" -Status "Checking prerequisites" -PercentComplete 5

        # Check Python 3.11
        Write-Info "Checking Python 3.11..."
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonCmd) {
            throw "Python not found in PATH"
        }

        $pythonVersion = python --version 2>&1
        Write-Info "Found: $pythonVersion"

        if ($pythonVersion -notmatch "Python 3\.11") {
            throw "Python 3.11 required, found: $pythonVersion"
        }

        $BuildManifest.metadata.python_version = $pythonVersion.ToString().Trim()

        # Check uv
        Write-Info "Checking uv..."
        $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
        if (-not $uvCmd) {
            throw "uv not found in PATH. Install from: https://docs.astral.sh/uv/getting-started/installation/"
        }

        $uvVersion = uv --version 2>&1
        Write-Info "Found: $uvVersion"
        $BuildManifest.metadata.uv_version = $uvVersion.ToString().Trim()

        # Check PyInstaller
        Write-Info "Checking PyInstaller availability..."
        try {
            $pyinstallerCheck = & uv run pyinstaller --version 2>&1
            Write-Info "PyInstaller is available"
        } catch {
            Write-Warning "PyInstaller not found, will install in dependency stage"
        }

        # Optional tools
        Write-Info "Checking optional tools..."
        $optionalTools = @{
            "node" = "Node.js (for TypeScript, JavaScript language servers)"
            "npm" = "npm (for installing Node.js language servers)"
            "git" = "Git (for version detection)"
            "curl" = "curl (for downloads)"
        }

        foreach ($tool in $optionalTools.Keys) {
            if (Get-Command $tool -ErrorAction SilentlyContinue) {
                Write-Success "$tool is available"
            } else {
                Write-Warning "$tool not found - $($optionalTools[$tool])"
            }
        }

        # System info
        $BuildManifest.metadata.system_info.os = (Get-CimInstance Win32_OperatingSystem).Caption
        Write-Info "OS: $($BuildManifest.metadata.system_info.os)"

        # Disk space check
        $drive = (Get-Item $OutputDir -ErrorAction SilentlyContinue)?.PSDrive.Name
        if (-not $drive) {
            $drive = (Get-Location).Drive.Name
        }

        $driveInfo = Get-PSDrive $drive
        $freeSpaceGB = [math]::Round($driveInfo.Free / 1GB, 2)
        Write-Info "Free disk space on ${drive}:: ${freeSpaceGB}GB"

        if ($freeSpaceGB -lt 2) {
            Write-Warning "Low disk space! At least 2GB recommended for builds"
        }

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["1_environment_validation"] = @{
            status = "completed"
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Environment validation completed ($('{0:N1}' -f $stageDuration.TotalSeconds)s)"
        return $true

    } catch {
        $BuildManifest.stages["1_environment_validation"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 1 failed: $_"
    }
}

# ==============================================================================
# Stage 2: Dependency Resolution
# ==============================================================================

function Invoke-Stage2-DependencyResolution {
    Write-Stage 2 "Dependency Resolution and Caching"
    $stageStart = Get-Date

    try {
        Push-Location $RepoRoot
        Write-Progress-Custom -Activity "Stage 2" -Status "Resolving dependencies" -PercentComplete 15

        # Verify pyproject.toml
        if (-not (Test-Path "pyproject.toml")) {
            throw "pyproject.toml not found in repository root"
        }

        Write-Info "Reading pyproject.toml..."
        $pyprojectContent = Get-Content "pyproject.toml" -Raw

        # Extract version
        if ($pyprojectContent -match 'version\s*=\s*"([^"]+)"') {
            $detectedVersion = $matches[1]
            if (-not $Version) {
                $Version = $detectedVersion
            }
            Write-Info "Project version: $detectedVersion"
        }

        $BuildManifest.version = $Version

        # Check for Windows dependencies
        Write-Info "Verifying Windows dependencies..."
        try {
            python -c "import win32api, pywintypes" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Installing Windows dependencies..."
                python -m pip install --upgrade pip wheel setuptools
                python -m pip install pywin32 pywin32-ctypes

                python -c "import win32api; print('pywin32 installed successfully')"
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to install pywin32"
                }
            } else {
                Write-Success "Windows dependencies already available"
            }
        } catch {
            Write-Warning "Installing Windows dependencies anyway..."
            python -m pip install --upgrade pip wheel setuptools
            python -m pip install pywin32 pywin32-ctypes
        }

        # Sync dependencies with uv
        Write-Info "Syncing project dependencies with uv..."
        Write-Progress-Custom -Activity "Stage 2" -Status "Syncing dependencies" -PercentComplete 20

        & uv sync --all-extras
        if ($LASTEXITCODE -ne 0) {
            throw "uv sync failed with exit code $LASTEXITCODE"
        }

        Write-Success "Dependencies synced"

        # Install PyInstaller
        Write-Info "Installing PyInstaller..."
        & uv pip install pyinstaller
        if ($LASTEXITCODE -ne 0) {
            throw "PyInstaller installation failed"
        }

        Write-Success "PyInstaller installed"

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["2_dependency_resolution"] = @{
            status = "completed"
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Dependency resolution completed ($('{0:N1}' -f $stageDuration.TotalSeconds)s)"
        return $true

    } catch {
        $BuildManifest.stages["2_dependency_resolution"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 2 failed: $_"
    } finally {
        Pop-Location
    }
}

# ==============================================================================
# Stage 3: Tests Execution
# ==============================================================================

function Invoke-Stage3-TestsExecution {
    Write-Stage 3 "Tests Execution"
    $stageStart = Get-Date

    if ($SkipTests) {
        Write-Warning "Tests skipped by user request (-SkipTests flag)"
        $BuildManifest.stages["3_tests_execution"] = @{
            status = "skipped"
            reason = "user_request"
            timestamp = (Get-Date).ToString("o")
        }
        return $true
    }

    try {
        Push-Location $RepoRoot
        Write-Progress-Custom -Activity "Stage 3" -Status "Running tests" -PercentComplete 30

        # Type checking
        Write-Info "Running type checks with mypy..."
        & uv run poe type-check
        if ($LASTEXITCODE -ne 0) {
            throw "Type checking failed"
        }
        Write-Success "Type checking passed"

        # Linting
        Write-Info "Running linting with ruff..."
        & uv run poe lint
        if ($LASTEXITCODE -ne 0) {
            throw "Linting failed"
        }
        Write-Success "Linting passed"

        # Core tests
        Write-Info "Running core test suite..."
        Write-Progress-Custom -Activity "Stage 3" -Status "Running core tests" -PercentComplete 35

        & uv run poe test -m "python or go or typescript" --maxfail=5
        if ($LASTEXITCODE -ne 0) {
            throw "Core tests failed"
        }
        Write-Success "Core tests passed"

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["3_tests_execution"] = @{
            status = "completed"
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            tests_passed = $true
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Tests execution completed ($('{0:N1}' -f $stageDuration.TotalSeconds)s)"
        return $true

    } catch {
        $BuildManifest.stages["3_tests_execution"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 3 failed: Tests did not pass. Fix issues or use -SkipTests (not recommended)"
    } finally {
        Pop-Location
    }
}

# ==============================================================================
# Stage 4: Language Server Bundling
# ==============================================================================

function Invoke-Stage4-LanguageServerBundling {
    Write-Stage 4 "Language Server Bundling"
    $stageStart = Get-Date

    if ($SkipLanguageServers -or $Tier -eq "minimal") {
        Write-Warning "Language server download skipped (Tier: $Tier)"
        $BuildManifest.stages["4_language_server_bundling"] = @{
            status = "skipped"
            tier = $Tier
            reason = if ($SkipLanguageServers) { "user_request" } else { "minimal_tier" }
            timestamp = (Get-Date).ToString("o")
        }
        return $true
    }

    try {
        Write-Progress-Custom -Activity "Stage 4" -Status "Downloading language servers" -PercentComplete 45

        $downloadScript = Join-Path $ScriptDir "download-language-servers.ps1"
        if (-not (Test-Path $downloadScript)) {
            throw "Download script not found: $downloadScript"
        }

        Write-Info "Downloading language servers for tier: $Tier"
        Write-Info "Target architecture: $Architecture"
        Write-Info "Output directory: $LanguageServersDir"

        # Create output directory
        if (-not (Test-Path $LanguageServersDir)) {
            New-Item -ItemType Directory -Path $LanguageServersDir -Force | Out-Null
        }

        # Run download script
        & $downloadScript -Tier $Tier -OutputDir $LanguageServersDir -Architecture $Architecture -Parallel $Parallel

        if ($LASTEXITCODE -ne 0) {
            throw "Language server download script failed with exit code $LASTEXITCODE"
        }

        # Calculate total size
        if (Test-Path $LanguageServersDir) {
            $lsSize = (Get-ChildItem $LanguageServersDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $lsSizeMB = [math]::Round($lsSize / 1MB, 2)
            $lsCount = (Get-ChildItem $LanguageServersDir -Directory).Count

            Write-Success "Downloaded $lsCount language servers ($lsSizeMB MB)"

            $BuildManifest.stages["4_language_server_bundling"] = @{
                status = "completed"
                tier = $Tier
                count = $lsCount
                size_mb = $lsSizeMB
                duration_seconds = [math]::Round(((Get-Date) - $stageStart).TotalSeconds, 2)
                timestamp = (Get-Date).ToString("o")
            }
        } else {
            throw "Language servers directory not created"
        }

        Write-Success "Language server bundling completed"
        return $true

    } catch {
        $BuildManifest.stages["4_language_server_bundling"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 4 failed: $_"
    }
}

# ==============================================================================
# Stage 5: PyInstaller Build
# ==============================================================================

function Invoke-Stage5-PyInstallerBuild {
    Write-Stage 5 "PyInstaller Build (3 Entry Points)"
    $stageStart = Get-Date

    try {
        Push-Location $RepoRoot
        Write-Progress-Custom -Activity "Stage 5" -Status "Building executables" -PercentComplete 55

        # Locate spec file
        $specFile = Join-Path $ScriptDir ".." "pyinstaller" "serena.spec"
        if (-not (Test-Path $specFile)) {
            throw "PyInstaller spec file not found: $specFile"
        }

        Write-Info "Using spec file: $specFile"

        # Set environment variables for PyInstaller
        $env:SERENA_VERSION = $Version
        $env:SERENA_BUILD_TIER = $Tier
        $env:LANGUAGE_SERVERS_DIR = $LanguageServersDir
        $env:PROJECT_ROOT = $RepoRoot

        Write-Info "Environment variables:"
        Write-Info "  SERENA_VERSION = $Version"
        Write-Info "  SERENA_BUILD_TIER = $Tier"
        Write-Info "  LANGUAGE_SERVERS_DIR = $LanguageServersDir"
        Write-Info "  PROJECT_ROOT = $RepoRoot"

        # Clean previous build
        if ($Clean -and (Test-Path "dist")) {
            Write-Info "Cleaning previous PyInstaller build..."
            Remove-Item "dist" -Recurse -Force -ErrorAction SilentlyContinue
        }

        if ($Clean -and (Test-Path "build")) {
            Remove-Item "build" -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Run PyInstaller
        Write-Info "Running PyInstaller (this may take several minutes)..."
        Write-Progress-Custom -Activity "Stage 5" -Status "Compiling with PyInstaller" -PercentComplete 60

        $pyInstallerArgs = @(
            $specFile,
            "--clean",
            "--noconfirm",
            "--distpath", "dist",
            "--workpath", "build"
        )

        Write-Info "PyInstaller command: uv run pyinstaller $($pyInstallerArgs -join ' ')"

        $buildOutput = & uv run pyinstaller @pyInstallerArgs 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "PyInstaller output:"
            $buildOutput | ForEach-Object { Write-Error $_ }
            throw "PyInstaller failed with exit code $LASTEXITCODE"
        }

        # Verify outputs
        Write-Info "Verifying built executables..."
        $expectedExes = @("serena-mcp-server", "serena", "index-project")
        $builtExes = @()

        foreach ($exeName in $expectedExes) {
            $exePath = Join-Path "dist" $exeName "$exeName.exe"
            if (Test-Path $exePath) {
                $exeSize = (Get-Item $exePath).Length
                $exeSizeMB = [math]::Round($exeSize / 1MB, 2)
                Write-Success "Built: $exeName.exe ($exeSizeMB MB)"
                $builtExes += @{
                    name = $exeName
                    path = $exePath
                    size_mb = $exeSizeMB
                }
            } else {
                Write-Warning "Expected executable not found: $exePath"
            }
        }

        if ($builtExes.Count -eq 0) {
            throw "No executables were built successfully"
        }

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["5_pyinstaller_build"] = @{
            status = "completed"
            executables = $builtExes
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "PyInstaller build completed ($('{0:N1}' -f $stageDuration.TotalSeconds)s)"
        return $true

    } catch {
        $BuildManifest.stages["5_pyinstaller_build"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 5 failed: $_"
    } finally {
        Pop-Location
    }
}

# ==============================================================================
# Stage 6: Directory Structure Creation
# ==============================================================================

function Invoke-Stage6-DirectoryStructure {
    Write-Stage 6 "Directory Structure Creation"
    $stageStart = Get-Date

    try {
        Write-Progress-Custom -Activity "Stage 6" -Status "Creating package structure" -PercentComplete 70

        $packageName = "serena-portable-v$Version-windows-$Architecture-$Tier"
        $packageDir = Join-Path $OutputDir $packageName

        Write-Info "Package name: $packageName"
        Write-Info "Package directory: $packageDir"

        # Clean previous package
        if (Test-Path $packageDir) {
            Write-Info "Removing previous package directory..."
            Remove-Item $packageDir -Recurse -Force
        }

        # Create directory structure
        $directories = @(
            $packageDir,
            (Join-Path $packageDir "bin"),
            (Join-Path $packageDir "config"),
            (Join-Path $packageDir "docs"),
            (Join-Path $packageDir "scripts"),
            (Join-Path $packageDir "language_servers")
        )

        foreach ($dir in $directories) {
            Write-Info "Creating: $dir"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $BuildManifest.stages["6_directory_structure"] = @{
            status = "completed"
            package_name = $packageName
            package_dir = $packageDir
            duration_seconds = [math]::Round(((Get-Date) - $stageStart).TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Directory structure created"
        return @{
            PackageName = $packageName
            PackageDir = $packageDir
        }

    } catch {
        $BuildManifest.stages["6_directory_structure"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 6 failed: $_"
    }
}

# ==============================================================================
# Stage 7: File Copying and Integration
# ==============================================================================

function Invoke-Stage7-FileCopying {
    param(
        [hashtable]$PackageInfo
    )

    Write-Stage 7 "File Copying and Integration"
    $stageStart = Get-Date

    try {
        $packageDir = $PackageInfo.PackageDir
        Write-Progress-Custom -Activity "Stage 7" -Status "Copying files" -PercentComplete 75

        $copiedFiles = @()

        # Copy PyInstaller executables
        Write-Info "Copying executables..."
        $exeNames = @("serena-mcp-server", "serena", "index-project")
        foreach ($exeName in $exeNames) {
            $sourcePath = Join-Path $PyInstallerDistDir $exeName
            $destPath = Join-Path $packageDir "bin" "$exeName.exe"

            $sourceExe = Join-Path $sourcePath "$exeName.exe"
            if (Test-Path $sourceExe) {
                Copy-Item $sourceExe $destPath -Force
                Write-Success "Copied: $exeName.exe"
                $copiedFiles += "bin/$exeName.exe"
            } else {
                Write-Warning "Executable not found: $sourceExe"
            }
        }

        # Copy language servers
        if ((Test-Path $LanguageServersDir) -and $Tier -ne "minimal") {
            Write-Info "Copying language servers..."
            $lsDest = Join-Path $packageDir "language_servers"
            Copy-Item "$LanguageServersDir\*" $lsDest -Recurse -Force
            Write-Success "Copied language servers"
            $copiedFiles += "language_servers/*"
        }

        # Copy configuration files
        Write-Info "Copying configuration files..."
        $configSources = @(
            (Join-Path $ScriptDir "launcher-config.json")
        )

        foreach ($source in $configSources) {
            if (Test-Path $source) {
                $fileName = Split-Path $source -Leaf
                $dest = Join-Path $packageDir "config" $fileName
                Copy-Item $source $dest -Force
                Write-Success "Copied: $fileName"
                $copiedFiles += "config/$fileName"
            }
        }

        # Copy documentation
        Write-Info "Copying documentation..."
        $docSources = @(
            (Join-Path $RepoRoot "README.md"),
            (Join-Path $RepoRoot "LICENSE"),
            (Join-Path $ScriptDir "README-PORTABLE.md")
        )

        foreach ($source in $docSources) {
            if (Test-Path $source) {
                $fileName = Split-Path $source -Leaf
                $dest = Join-Path $packageDir "docs" $fileName
                Copy-Item $source $dest -Force
                Write-Success "Copied: $fileName"
                $copiedFiles += "docs/$fileName"
            }
        }

        # Copy launcher script
        Write-Info "Copying launcher script..."
        $launcherSource = Join-Path $ScriptDir "serena-portable.bat"
        if (Test-Path $launcherSource) {
            $launcherDest = Join-Path $packageDir "serena-portable.bat"
            Copy-Item $launcherSource $launcherDest -Force
            Write-Success "Copied: serena-portable.bat"
            $copiedFiles += "serena-portable.bat"
        }

        # Create VERSION file
        Write-Info "Creating VERSION file..."
        $versionContent = @"
Serena Portable for Windows
Version: $Version
Architecture: $Architecture
Language Server Tier: $Tier
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
Build ID: $BuildId

For more information, see docs/README-PORTABLE.md
"@
        Set-Content -Path (Join-Path $packageDir "VERSION.txt") -Value $versionContent -Encoding UTF8
        $copiedFiles += "VERSION.txt"

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["7_file_copying"] = @{
            status = "completed"
            files_copied = $copiedFiles.Count
            files = $copiedFiles
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "File copying completed ($($copiedFiles.Count) files)"
        return $true

    } catch {
        $BuildManifest.stages["7_file_copying"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 7 failed: $_"
    }
}

# ==============================================================================
# Stage 8: Archive Creation
# ==============================================================================

function Invoke-Stage8-ArchiveCreation {
    param(
        [hashtable]$PackageInfo
    )

    Write-Stage 8 "Archive Creation and Compression"
    $stageStart = Get-Date

    if ($NoArchive) {
        Write-Warning "Archive creation skipped (-NoArchive flag)"
        $BuildManifest.stages["8_archive_creation"] = @{
            status = "skipped"
            reason = "user_request"
            timestamp = (Get-Date).ToString("o")
        }
        return $PackageInfo
    }

    try {
        $packageDir = $PackageInfo.PackageDir
        $packageName = $PackageInfo.PackageName
        $archivePath = Join-Path $OutputDir "$packageName.zip"

        Write-Progress-Custom -Activity "Stage 8" -Status "Creating ZIP archive" -PercentComplete 85

        Write-Info "Creating ZIP archive: $archivePath"
        Write-Info "Source: $packageDir"

        # Remove existing archive
        if (Test-Path $archivePath) {
            Remove-Item $archivePath -Force
        }

        # Create ZIP with maximum compression
        Write-Info "Compressing (this may take a few minutes)..."
        Compress-Archive -Path $packageDir -DestinationPath $archivePath -CompressionLevel Optimal -Force

        if (-not (Test-Path $archivePath)) {
            throw "Archive was not created"
        }

        # Calculate sizes
        $dirSize = (Get-ChildItem $packageDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $zipSize = (Get-Item $archivePath).Length
        $dirSizeMB = [math]::Round($dirSize / 1MB, 2)
        $zipSizeMB = [math]::Round($zipSize / 1MB, 2)
        $compressionRatio = [math]::Round(($dirSize - $zipSize) / $dirSize * 100, 1)

        Write-Success "Archive created: $archivePath"
        Write-Info "Directory size: $dirSizeMB MB"
        Write-Info "Archive size: $zipSizeMB MB"
        Write-Info "Compression: $compressionRatio% size reduction"

        $PackageInfo.ArchivePath = $archivePath
        $PackageInfo.DirSizeMB = $dirSizeMB
        $PackageInfo.ArchiveSizeMB = $zipSizeMB

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["8_archive_creation"] = @{
            status = "completed"
            archive_path = $archivePath
            dir_size_mb = $dirSizeMB
            archive_size_mb = $zipSizeMB
            compression_ratio = $compressionRatio
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Archive creation completed ($('{0:N1}' -f $stageDuration.TotalSeconds)s)"
        return $PackageInfo

    } catch {
        $BuildManifest.stages["8_archive_creation"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 8 failed: $_"
    }
}

# ==============================================================================
# Stage 9: Checksum Generation
# ==============================================================================

function Invoke-Stage9-ChecksumGeneration {
    param(
        [hashtable]$PackageInfo
    )

    Write-Stage 9 "Checksum Generation"
    $stageStart = Get-Date

    try {
        Write-Progress-Custom -Activity "Stage 9" -Status "Generating checksums" -PercentComplete 92

        $checksums = @{}

        # Generate checksum for archive
        if ($PackageInfo.ArchivePath -and (Test-Path $PackageInfo.ArchivePath)) {
            Write-Info "Generating SHA256 checksum for archive..."
            $archiveHash = (Get-FileHash -Path $PackageInfo.ArchivePath -Algorithm SHA256).Hash
            $checksums.archive = $archiveHash

            # Write checksum file
            $checksumFile = "$($PackageInfo.ArchivePath).sha256"
            $checksumContent = "$archiveHash  $(Split-Path $PackageInfo.ArchivePath -Leaf)"
            Set-Content -Path $checksumFile -Value $checksumContent -Encoding UTF8

            Write-Success "Archive SHA256: $archiveHash"
            Write-Success "Checksum file: $checksumFile"
        }

        # Generate checksums for key executables
        Write-Info "Generating checksums for executables..."
        $binDir = Join-Path $PackageInfo.PackageDir "bin"
        if (Test-Path $binDir) {
            $exeFiles = Get-ChildItem $binDir -Filter "*.exe"
            foreach ($exe in $exeFiles) {
                $hash = (Get-FileHash -Path $exe.FullName -Algorithm SHA256).Hash
                $checksums[$exe.Name] = $hash
                Write-Info "$($exe.Name): $hash"
            }
        }

        $BuildManifest.checksums = $checksums

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["9_checksum_generation"] = @{
            status = "completed"
            checksums_generated = $checksums.Count
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Checksum generation completed"
        return $true

    } catch {
        $BuildManifest.stages["9_checksum_generation"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        throw "Stage 9 failed: $_"
    }
}

# ==============================================================================
# Stage 10: Build Manifest Generation
# ==============================================================================

function Invoke-Stage10-ManifestGeneration {
    param(
        [hashtable]$PackageInfo
    )

    Write-Stage 10 "Build Manifest Generation"
    $stageStart = Get-Date

    try {
        Write-Progress-Custom -Activity "Stage 10" -Status "Generating manifest" -PercentComplete 96

        # Finalize build metadata
        $BuildManifest.build_duration_seconds = [math]::Round(((Get-Date) - $BuildStartTime).TotalSeconds, 2)
        $BuildManifest.build_end_time = (Get-Date).ToString("o")

        # Add package information
        $BuildManifest.package = @{
            name = $PackageInfo.PackageName
            directory = $PackageInfo.PackageDir
            archive = $PackageInfo.ArchivePath
            dir_size_mb = $PackageInfo.DirSizeMB
            archive_size_mb = $PackageInfo.ArchiveSizeMB
        }

        # Save manifest
        $manifestPath = Join-Path $OutputDir "build-manifest-$BuildId.json"
        $BuildManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

        Write-Success "Build manifest saved: $manifestPath"

        # Also save a "latest" manifest
        $latestManifestPath = Join-Path $OutputDir "build-manifest-latest.json"
        Copy-Item $manifestPath $latestManifestPath -Force

        $stageDuration = (Get-Date) - $stageStart
        $BuildManifest.stages["10_manifest_generation"] = @{
            status = "completed"
            manifest_path = $manifestPath
            duration_seconds = [math]::Round($stageDuration.TotalSeconds, 2)
            timestamp = (Get-Date).ToString("o")
        }

        Write-Success "Manifest generation completed"
        return $manifestPath

    } catch {
        $BuildManifest.stages["10_manifest_generation"] = @{
            status = "failed"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("o")
        }
        Write-Warning "Failed to generate manifest: $_"
        return $null
    }
}

# ==============================================================================
# Build Summary
# ==============================================================================

function Show-BuildSummary {
    param(
        [hashtable]$PackageInfo,
        [string]$ManifestPath
    )

    $buildDuration = (Get-Date) - $BuildStartTime

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "                   BUILD SUMMARY - SUCCESS" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "Build Information:" -ForegroundColor Cyan
    Write-Host "  Build ID:            $BuildId" -ForegroundColor White
    Write-Host "  Version:             $Version" -ForegroundColor White
    Write-Host "  Tier:                $Tier" -ForegroundColor White
    Write-Host "  Architecture:        $Architecture" -ForegroundColor White
    Write-Host "  Total Duration:      $('{0:N1}' -f $buildDuration.TotalMinutes) minutes" -ForegroundColor White
    Write-Host ""

    Write-Host "Package Details:" -ForegroundColor Cyan
    Write-Host "  Name:                $($PackageInfo.PackageName)" -ForegroundColor White
    Write-Host "  Directory:           $($PackageInfo.PackageDir)" -ForegroundColor White
    Write-Host "  Directory Size:      $($PackageInfo.DirSizeMB) MB" -ForegroundColor White

    if ($PackageInfo.ArchivePath) {
        Write-Host "  Archive:             $($PackageInfo.ArchivePath)" -ForegroundColor White
        Write-Host "  Archive Size:        $($PackageInfo.ArchiveSizeMB) MB" -ForegroundColor White
        Write-Host "  Checksum File:       $($PackageInfo.ArchivePath).sha256" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Stage Timings:" -ForegroundColor Cyan
    $stageNames = @(
        @{ Num = 1; Name = "Environment Validation" }
        @{ Num = 2; Name = "Dependency Resolution" }
        @{ Num = 3; Name = "Tests Execution" }
        @{ Num = 4; Name = "Language Server Bundling" }
        @{ Num = 5; Name = "PyInstaller Build" }
        @{ Num = 6; Name = "Directory Structure" }
        @{ Num = 7; Name = "File Copying" }
        @{ Num = 8; Name = "Archive Creation" }
        @{ Num = 9; Name = "Checksum Generation" }
        @{ Num = 10; Name = "Manifest Generation" }
    )

    foreach ($stage in $stageNames) {
        $stageKey = "$($stage.Num)_$($stage.Name.ToLower().Replace(' ', '_'))"
        $stageData = $BuildManifest.stages[$stageKey]
        if ($stageData) {
            $status = $stageData.status.ToUpper()
            $statusColor = switch ($status) {
                "COMPLETED" { "Green" }
                "SKIPPED" { "Yellow" }
                "FAILED" { "Red" }
                default { "White" }
            }

            $duration = if ($stageData.duration_seconds) {
                "$('{0:N1}' -f $stageData.duration_seconds)s"
            } else {
                "N/A"
            }

            Write-Host ("  Stage {0:D2} - {1,-30} [{2}] {3}" -f $stage.Num, $stage.Name, $status, $duration) -ForegroundColor $statusColor
        }
    }

    Write-Host ""
    Write-Host "Output Files:" -ForegroundColor Cyan
    Write-Host "  Build Log:           $BuildLogPath" -ForegroundColor White
    Write-Host "  Build Manifest:      $ManifestPath" -ForegroundColor White
    Write-Host ""

    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Test the build:" -ForegroundColor White
    Write-Host "     .\test-portable.ps1 -PackagePath `"$($PackageInfo.PackageDir)`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Verify the archive:" -ForegroundColor White
    Write-Host "     Extract $($PackageInfo.ArchivePath)" -ForegroundColor Gray
    Write-Host "     Run serena-portable.bat" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Distribute:" -ForegroundColor White
    Write-Host "     Upload $($PackageInfo.ArchivePath) to releases" -ForegroundColor Gray
    Write-Host "     Include $($PackageInfo.ArchivePath).sha256 for verification" -ForegroundColor Gray
    Write-Host ""

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
}

# ==============================================================================
# Cleanup
# ==============================================================================

function Invoke-Cleanup {
    Write-Info "Cleaning up temporary files..."

    try {
        # Remove temp directory
        if (Test-Path $TempDir) {
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed temporary directory"
        }

        # Remove PyInstaller build artifacts
        $buildDir = Join-Path $RepoRoot "build"
        if (Test-Path $buildDir) {
            Remove-Item $buildDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed PyInstaller build directory"
        }

    } catch {
        Write-Warning "Cleanup had issues: $_"
    }
}

# ==============================================================================
# Main Execution
# ==============================================================================

function Main {
    try {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
        Write-Host "     Windows Portable Package Build - Serena MCP v$Version" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "Configuration:" -ForegroundColor Cyan
        Write-Host "  Tier:                $Tier" -ForegroundColor White
        Write-Host "  Architecture:        $Architecture" -ForegroundColor White
        Write-Host "  Output Directory:    $OutputDir" -ForegroundColor White
        Write-Host "  Clean Build:         $Clean" -ForegroundColor White
        Write-Host "  Skip Tests:          $SkipTests" -ForegroundColor White
        Write-Host "  Skip Lang Servers:   $SkipLanguageServers" -ForegroundColor White
        Write-Host "  Create Archive:      $(-not $NoArchive)" -ForegroundColor White
        Write-Host ""

        # Initialize output directory
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }

        # Execute build stages
        $null = Invoke-Stage1-EnvironmentValidation
        $null = Invoke-Stage2-DependencyResolution
        $null = Invoke-Stage3-TestsExecution
        $null = Invoke-Stage4-LanguageServerBundling
        $null = Invoke-Stage5-PyInstallerBuild
        $packageInfo = Invoke-Stage6-DirectoryStructure
        $null = Invoke-Stage7-FileCopying -PackageInfo $packageInfo
        $packageInfo = Invoke-Stage8-ArchiveCreation -PackageInfo $packageInfo
        $null = Invoke-Stage9-ChecksumGeneration -PackageInfo $packageInfo
        $manifestPath = Invoke-Stage10-ManifestGeneration -PackageInfo $packageInfo

        # Show summary
        Show-BuildSummary -PackageInfo $packageInfo -ManifestPath $manifestPath

        # Cleanup
        if ($Clean) {
            Invoke-Cleanup
        }

        Write-Host ""
        Write-Success "Build completed successfully!"
        Write-Host ""

        exit 0

    } catch {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "                      BUILD FAILED" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
        Write-Error "Build failed: $_"
        Write-Host ""
        Write-Host "Error Details:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Stack Trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        Write-Host ""
        Write-Host "Check the build log for details: $BuildLogPath" -ForegroundColor Yellow
        Write-Host ""

        # Save error manifest
        $BuildManifest.build_status = "failed"
        $BuildManifest.build_error = $_.Exception.Message
        $errorManifestPath = Join-Path $OutputDir "build-manifest-error-$BuildId.json"
        $BuildManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $errorManifestPath -Encoding UTF8

        exit 1
    }
}

# Run main
Main
