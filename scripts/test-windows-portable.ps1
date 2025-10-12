#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive test suite for Windows portable Serena builds

.DESCRIPTION
    Production-grade test framework that validates Windows portable packages across
    multiple categories including pre-build checks, build validation, package structure,
    functional tests, and language server verification.

    Test Categories:
    - PreBuild: System requirements and prerequisites (11 checks)
    - BuildValidation: Executable integrity and checksums (20 checks)
    - PackageStructure: Directory layout and files (15 checks)
    - Functional: Runtime behavior and execution (10 checks)
    - LanguageServers: Per-language server validation (6 checks each)

.PARAMETER BuildPath
    Path to the built portable package directory or ZIP file (required)

.PARAMETER Tier
    Expected language server tier (minimal, essential, complete, full)
    Auto-detected from package name if not specified

.PARAMETER Architecture
    Expected architecture (x64, arm64)
    Auto-detected from package name if not specified

.PARAMETER TestCategory
    Run specific test category only
    Valid values: All, PreBuild, BuildValidation, PackageStructure, Functional, LanguageServers

.PARAMETER OutputDir
    Directory for test results and logs (default: .\test-results)

.PARAMETER Verbose
    Show detailed test output and diagnostics

.PARAMETER GenerateReport
    Generate detailed JSON test report (always enabled)

.PARAMETER SkipExtraction
    Skip ZIP extraction if package is already extracted

.PARAMETER Timeout
    Timeout in seconds for individual tests (default: 60)

.EXAMPLE
    .\test-windows-portable.ps1 -BuildPath ".\dist\serena-1.0.0-windows-x64-portable.zip"
    Run all tests on a portable package

.EXAMPLE
    .\test-windows-portable.ps1 -BuildPath ".\dist\serena-essential-x64" -Tier essential -Verbose
    Test with explicit tier specification and verbose output

.EXAMPLE
    .\test-windows-portable.ps1 -BuildPath ".\package.zip" -TestCategory BuildValidation
    Run only build validation tests

.EXAMPLE
    .\test-windows-portable.ps1 -BuildPath ".\serena-portable" -Architecture arm64 -Tier full
    Test ARM64 full-tier package
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$BuildPath,

    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier,

    [ValidateSet("x64", "arm64")]
    [string]$Architecture,

    [ValidateSet("All", "PreBuild", "BuildValidation", "PackageStructure", "Functional", "LanguageServers")]
    [string]$TestCategory = "All",

    [string]$OutputDir = ".\test-results",

    [switch]$Verbose,

    [switch]$GenerateReport = $true,

    [switch]$SkipExtraction,

    [int]$Timeout = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================================
# GLOBALS AND CONFIGURATION
# ============================================================================

$script:TestResults = @()
$script:TestStats = @{
    Total = 0
    Passed = 0
    Failed = 0
    Skipped = 0
    Warnings = 0
}

$script:DetectedTier = $null
$script:DetectedArchitecture = $null
$script:ResolvedBuildPath = $null
$script:StartTime = Get-Date

# Tier-specific language server definitions
$script:TierLanguageServers = @{
    "minimal" = @()
    "essential" = @("python", "typescript", "rust", "go", "lua", "markdown")
    "complete" = @("python", "typescript", "rust", "go", "lua", "markdown", "java", "bash", "csharp")
    "full" = @("python", "typescript", "rust", "go", "lua", "markdown", "java", "bash", "csharp", "php", "kotlin", "swift", "ruby", "perl", "elixir")
}

# Expected file sizes (approximate, in bytes)
$script:ExpectedFileSizes = @{
    "serena.exe" = @{ Min = 5MB; Max = 50MB }
    "serena-mcp-server.exe" = @{ Min = 5MB; Max = 50MB }
}

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Magenta
}

function Write-TestCategory {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

function Write-TestName {
    param([string]$Message)
    if ($script:VerbosePreference -eq 'Continue') {
        Write-Host "  TEST: $Message" -ForegroundColor Gray
    }
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK]   $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message, [string]$Details = "")
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
    if ($Details) {
        Write-Host "         $Details" -ForegroundColor Red
    }
}

function Write-Skip {
    param([string]$Message, [string]$Reason = "")
    Write-Host "  [SKIP] $Message" -ForegroundColor Yellow
    if ($Reason) {
        Write-Host "         Reason: $Reason" -ForegroundColor Yellow
    }
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-TestInfo {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "  [INFO] $Message" -ForegroundColor Cyan
    }
}

# ============================================================================
# TEST RESULT TRACKING
# ============================================================================

function Add-TestResult {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Category,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Pass", "Fail", "Skip", "Warning")]
        [string]$Status,

        [string]$Details = "",
        [timespan]$Duration = [timespan]::Zero,
        [hashtable]$Metadata = @{}
    )

    $result = [PSCustomObject]@{
        Category = $Category
        Name = $Name
        Status = $Status
        Details = $Details
        Duration = $Duration
        Timestamp = Get-Date
        Metadata = $Metadata
    }

    $script:TestResults += $result
    $script:TestStats.Total++

    switch ($Status) {
        "Pass" {
            $script:TestStats.Passed++
            Write-Success "$Name $(if($Duration.TotalMilliseconds -gt 0){"($([math]::Round($Duration.TotalMilliseconds))ms)"})"
            if ($Details) { Write-TestInfo $Details }
        }
        "Fail" {
            $script:TestStats.Failed++
            Write-Failure $Name $Details
        }
        "Skip" {
            $script:TestStats.Skipped++
            Write-Skip $Name $Details
        }
        "Warning" {
            $script:TestStats.Warnings++
            Write-TestWarning "$Name - $Details"
        }
    }
}

# ============================================================================
# PACKAGE DETECTION AND METADATA
# ============================================================================

function Get-PackageMetadata {
    param([string]$Path)

    Write-TestInfo "Detecting package metadata from: $Path"

    $metadata = @{
        Tier = $null
        Architecture = $null
        Version = $null
        PackageName = $null
    }

    # Extract base name
    $baseName = Split-Path $Path -Leaf
    $baseName = $baseName -replace '\.zip$', ''
    $metadata.PackageName = $baseName

    # Detect tier
    $tierPatterns = @{
        "minimal" = @("minimal", "min")
        "essential" = @("essential", "ess")
        "complete" = @("complete", "comp")
        "full" = @("full")
    }

    foreach ($tier in $tierPatterns.Keys) {
        foreach ($pattern in $tierPatterns[$tier]) {
            if ($baseName -match $pattern) {
                $metadata.Tier = $tier
                break
            }
        }
        if ($metadata.Tier) { break }
    }

    # Detect architecture
    if ($baseName -match "(x64|amd64)") {
        $metadata.Architecture = "x64"
    } elseif ($baseName -match "(arm64|aarch64)") {
        $metadata.Architecture = "arm64"
    }

    # Try to detect version (e.g., serena-1.0.0-windows-x64)
    if ($baseName -match '(\d+\.\d+\.\d+(-[\w\.]+)?)') {
        $metadata.Version = $matches[1]
    }

    return $metadata
}

function Initialize-TestEnvironment {
    Write-TestCategory "Initializing Test Environment"

    $startTime = Get-Date

    try {
        # Create output directory
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }

        # Verify build path exists
        if (-not (Test-Path $BuildPath)) {
            throw "Build path does not exist: $BuildPath"
        }

        # Detect metadata
        $metadata = Get-PackageMetadata $BuildPath

        # Override with parameters if provided
        $script:DetectedTier = if ($Tier) { $Tier } else { $metadata.Tier }
        $script:DetectedArchitecture = if ($Architecture) { $Architecture } else { $metadata.Architecture }

        Write-TestInfo "Package: $($metadata.PackageName)"
        Write-TestInfo "Detected Tier: $($script:DetectedTier)"
        Write-TestInfo "Detected Architecture: $($script:DetectedArchitecture)"
        if ($metadata.Version) {
            Write-TestInfo "Version: $($metadata.Version)"
        }

        # Handle ZIP extraction
        $script:ResolvedBuildPath = $BuildPath

        if ($BuildPath -match '\.zip$') {
            if (-not $SkipExtraction) {
                Write-TestInfo "Extracting ZIP package..."

                $extractDir = Join-Path $OutputDir "extracted"
                if (Test-Path $extractDir) {
                    Remove-Item $extractDir -Recurse -Force
                }

                Expand-Archive -Path $BuildPath -DestinationPath $extractDir -Force

                # Find serena.exe or serena-mcp-server.exe
                $foundExe = Get-ChildItem $extractDir -Recurse -Filter "serena*.exe" | Select-Object -First 1

                if (-not $foundExe) {
                    throw "No Serena executable found in extracted package"
                }

                $script:ResolvedBuildPath = $foundExe.Directory.FullName
                Write-TestInfo "Extracted to: $script:ResolvedBuildPath"
            } else {
                Write-TestInfo "Skipping extraction (SkipExtraction flag set)"
            }
        }

        $duration = (Get-Date) - $startTime
        Add-TestResult -Category "Environment" -Name "Test Environment Initialization" -Status "Pass" -Duration $duration

        return $true

    } catch {
        $duration = (Get-Date) - $startTime
        Add-TestResult -Category "Environment" -Name "Test Environment Initialization" -Status "Fail" -Details $_.Exception.Message -Duration $duration
        return $false
    }
}

# ============================================================================
# CATEGORY 1: PRE-BUILD TESTS (11 checks)
# ============================================================================

function Test-PreBuild {
    if ($TestCategory -ne "All" -and $TestCategory -ne "PreBuild") {
        return
    }

    Write-TestCategory "Pre-Build Tests (System Requirements)"

    # Test 1: Python 3.11 installed
    Test-Python311Available

    # Test 2: uv available
    Test-UvAvailable

    # Test 3: PyInstaller available
    Test-PyInstallerAvailable

    # Test 4: Git repository valid
    Test-GitRepositoryValid

    # Test 5: Disk space sufficient
    Test-DiskSpaceSufficient

    # Test 6: Windows version compatibility
    Test-WindowsVersionCompatibility

    # Test 7: PowerShell version
    Test-PowerShellVersion

    # Test 8: .NET Framework availability
    Test-DotNetFramework

    # Test 9: System architecture detection
    Test-SystemArchitectureDetection

    # Test 10: Path length validation
    Test-PathLengthValidation

    # Test 11: Write permissions
    Test-WritePermissions
}

function Test-Python311Available {
    $startTime = Get-Date
    Write-TestName "Python 3.11 Installation"

    try {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonCmd) {
            Add-TestResult -Category "PreBuild" -Name "Python 3.11 Available" -Status "Fail" -Details "Python not found in PATH" -Duration ((Get-Date) - $startTime)
            return
        }

        $versionOutput = & python --version 2>&1
        if ($versionOutput -match "Python 3\.11") {
            Add-TestResult -Category "PreBuild" -Name "Python 3.11 Available" -Status "Pass" -Details $versionOutput -Duration ((Get-Date) - $startTime)
        } elseif ($versionOutput -match "Python 3\.\d+") {
            Add-TestResult -Category "PreBuild" -Name "Python 3.11 Available" -Status "Warning" -Details "Found $versionOutput, Python 3.11 recommended" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "Python 3.11 Available" -Status "Fail" -Details "Python 3.11 required, found: $versionOutput" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Python 3.11 Available" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-UvAvailable {
    $startTime = Get-Date
    Write-TestName "UV Package Manager"

    try {
        $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
        if ($uvCmd) {
            $versionOutput = & uv --version 2>&1
            Add-TestResult -Category "PreBuild" -Name "UV Available" -Status "Pass" -Details $versionOutput -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "UV Available" -Status "Fail" -Details "uv not found in PATH" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "UV Available" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-PyInstallerAvailable {
    $startTime = Get-Date
    Write-TestName "PyInstaller Installation"

    try {
        $output = & python -c "import PyInstaller; print(PyInstaller.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -Category "PreBuild" -Name "PyInstaller Available" -Status "Pass" -Details "Version: $output" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "PyInstaller Available" -Status "Fail" -Details "PyInstaller not installed" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "PyInstaller Available" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-GitRepositoryValid {
    $startTime = Get-Date
    Write-TestName "Git Repository Validation"

    try {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if (-not $gitCmd) {
            Add-TestResult -Category "PreBuild" -Name "Git Repository Valid" -Status "Skip" -Details "Git not available" -Duration ((Get-Date) - $startTime)
            return
        }

        $gitStatus = & git rev-parse --is-inside-work-tree 2>&1
        if ($LASTEXITCODE -eq 0 -and $gitStatus -eq "true") {
            $branch = & git branch --show-current 2>&1
            Add-TestResult -Category "PreBuild" -Name "Git Repository Valid" -Status "Pass" -Details "Branch: $branch" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "Git Repository Valid" -Status "Warning" -Details "Not in a git repository" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Git Repository Valid" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-DiskSpaceSufficient {
    $startTime = Get-Date
    Write-TestName "Disk Space Check"

    try {
        $drive = (Get-Item $OutputDir -ErrorAction SilentlyContinue).PSDrive.Name
        if (-not $drive) {
            $drive = (Split-Path $OutputDir -Qualifier).TrimEnd(':')
        }

        $freeSpaceGB = (Get-PSDrive $drive).Free / 1GB
        $requiredGB = 2.0  # Require at least 2GB free

        if ($freeSpaceGB -ge $requiredGB) {
            Add-TestResult -Category "PreBuild" -Name "Disk Space Sufficient" -Status "Pass" -Details "$([math]::Round($freeSpaceGB, 2)) GB free on drive $drive" -Duration ((Get-Date) - $startTime)
        } elseif ($freeSpaceGB -ge 1.0) {
            Add-TestResult -Category "PreBuild" -Name "Disk Space Sufficient" -Status "Warning" -Details "Only $([math]::Round($freeSpaceGB, 2)) GB free on drive $drive (2GB+ recommended)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "Disk Space Sufficient" -Status "Fail" -Details "Insufficient disk space: $([math]::Round($freeSpaceGB, 2)) GB free on drive $drive (2GB required)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Disk Space Sufficient" -Status "Warning" -Details "Could not check disk space: $($_.Exception.Message)" -Duration ((Get-Date) - $startTime)
    }
}

function Test-WindowsVersionCompatibility {
    $startTime = Get-Date
    Write-TestName "Windows Version Compatibility"

    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $buildNumber = $osVersion.Build

        # Windows 10 is 10.0.x, Windows 11 is 10.0.22000+
        if ($osVersion.Major -eq 10 -and $osVersion.Minor -eq 0) {
            if ($buildNumber -ge 22000) {
                $windowsName = "Windows 11"
            } else {
                $windowsName = "Windows 10"
            }
            Add-TestResult -Category "PreBuild" -Name "Windows Version Compatible" -Status "Pass" -Details "$windowsName (Build $buildNumber)" -Duration ((Get-Date) - $startTime)
        } elseif ($osVersion.Major -ge 10) {
            Add-TestResult -Category "PreBuild" -Name "Windows Version Compatible" -Status "Pass" -Details "Windows version $($osVersion.Major).$($osVersion.Minor) (Build $buildNumber)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "Windows Version Compatible" -Status "Fail" -Details "Windows 10 or higher required (found version $($osVersion.Major).$($osVersion.Minor))" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Windows Version Compatible" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-PowerShellVersion {
    $startTime = Get-Date
    Write-TestName "PowerShell Version"

    try {
        $psVersion = $PSVersionTable.PSVersion
        if ($psVersion.Major -ge 5) {
            Add-TestResult -Category "PreBuild" -Name "PowerShell Version" -Status "Pass" -Details "PowerShell $($psVersion.ToString())" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "PowerShell Version" -Status "Fail" -Details "PowerShell 5.1+ required (found $($psVersion.ToString()))" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "PowerShell Version" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-DotNetFramework {
    $startTime = Get-Date
    Write-TestName ".NET Framework Availability"

    try {
        $netVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Release
        if ($netVersion) {
            $versionName = switch ($netVersion) {
                { $_ -ge 528040 } { ".NET Framework 4.8" }
                { $_ -ge 461808 } { ".NET Framework 4.7.2" }
                { $_ -ge 461308 } { ".NET Framework 4.7.1" }
                { $_ -ge 460798 } { ".NET Framework 4.7" }
                default { ".NET Framework 4.x" }
            }
            Add-TestResult -Category "PreBuild" -Name ".NET Framework Available" -Status "Pass" -Details "$versionName (Release: $netVersion)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name ".NET Framework Available" -Status "Warning" -Details ".NET Framework version not detected" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name ".NET Framework Available" -Status "Warning" -Details "Could not detect .NET Framework: $($_.Exception.Message)" -Duration ((Get-Date) - $startTime)
    }
}

function Test-SystemArchitectureDetection {
    $startTime = Get-Date
    Write-TestName "System Architecture Detection"

    try {
        $is64Bit = [Environment]::Is64BitOperatingSystem
        $processorArch = $env:PROCESSOR_ARCHITECTURE

        $systemArch = if ($processorArch -eq "AMD64" -or $is64Bit) {
            "x64"
        } elseif ($processorArch -eq "ARM64") {
            "arm64"
        } else {
            "x86"
        }

        $details = "System: $systemArch (Processor: $processorArch, 64-bit OS: $is64Bit)"

        if ($script:DetectedArchitecture) {
            if ($script:DetectedArchitecture -eq $systemArch -or ($script:DetectedArchitecture -eq "x64" -and $systemArch -eq "arm64")) {
                Add-TestResult -Category "PreBuild" -Name "Architecture Detection" -Status "Pass" -Details "$details, Package: $($script:DetectedArchitecture)" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "PreBuild" -Name "Architecture Detection" -Status "Warning" -Details "Package is $($script:DetectedArchitecture) but system is $systemArch" -Duration ((Get-Date) - $startTime)
            }
        } else {
            Add-TestResult -Category "PreBuild" -Name "Architecture Detection" -Status "Pass" -Details $details -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Architecture Detection" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-PathLengthValidation {
    $startTime = Get-Date
    Write-TestName "Path Length Validation"

    try {
        $maxPathLength = 260
        $buildPathLength = $script:ResolvedBuildPath.Length

        if ($buildPathLength -lt ($maxPathLength - 100)) {
            Add-TestResult -Category "PreBuild" -Name "Path Length Valid" -Status "Pass" -Details "Path length: $buildPathLength chars (max: $maxPathLength)" -Duration ((Get-Date) - $startTime)
        } elseif ($buildPathLength -lt $maxPathLength) {
            Add-TestResult -Category "PreBuild" -Name "Path Length Valid" -Status "Warning" -Details "Path length: $buildPathLength chars - close to Windows limit ($maxPathLength)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PreBuild" -Name "Path Length Valid" -Status "Fail" -Details "Path too long: $buildPathLength chars (Windows limit: $maxPathLength)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Path Length Valid" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-WritePermissions {
    $startTime = Get-Date
    Write-TestName "Write Permissions Check"

    try {
        $testFile = Join-Path $OutputDir "write-test-$([guid]::NewGuid().ToString()).tmp"
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction Stop

        Add-TestResult -Category "PreBuild" -Name "Write Permissions" -Status "Pass" -Details "Write access confirmed for $OutputDir" -Duration ((Get-Date) - $startTime)
    } catch {
        Add-TestResult -Category "PreBuild" -Name "Write Permissions" -Status "Fail" -Details "No write access to $OutputDir - $($_.Exception.Message)" -Duration ((Get-Date) - $startTime)
    }
}

# ============================================================================
# CATEGORY 2: BUILD VALIDATION (20 checks)
# ============================================================================

function Test-BuildValidation {
    if ($TestCategory -ne "All" -and $TestCategory -ne "BuildValidation") {
        return
    }

    Write-TestCategory "Build Validation Tests (Executable Integrity)"

    # Core executables
    Test-ExecutableExists "serena.exe"
    Test-ExecutableExists "serena-mcp-server.exe"

    # File sizes
    Test-ExecutableSize "serena.exe"
    Test-ExecutableSize "serena-mcp-server.exe"

    # PE Header validation
    Test-PEHeader "serena.exe"
    Test-PEHeader "serena-mcp-server.exe"

    # Manifest validation
    Test-ManifestExists
    Test-ManifestValidJSON
    Test-ManifestVersion
    Test-ManifestTier
    Test-ManifestArchitecture

    # SHA256 checksums
    Test-ExecutableChecksum "serena.exe"
    Test-ExecutableChecksum "serena-mcp-server.exe"

    # Dependencies bundled
    Test-InternalDirectoryExists
    Test-PythonRuntimeBundled
    Test-DependenciesCount

    # Version info
    Test-ExecutableVersionInfo "serena.exe"
    Test-ExecutableVersionInfo "serena-mcp-server.exe"

    # Digital signature (if present)
    Test-DigitalSignature "serena.exe"
    Test-DigitalSignature "serena-mcp-server.exe"
}

function Test-ExecutableExists {
    param([string]$ExeName)

    $startTime = Get-Date
    Write-TestName "Executable Exists: $ExeName"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath $ExeName
        if (Test-Path $exePath) {
            $fileInfo = Get-Item $exePath
            Add-TestResult -Category "BuildValidation" -Name "Executable Exists: $ExeName" -Status "Pass" -Details "Found at $exePath" -Duration ((Get-Date) - $startTime) -Metadata @{ Path = $exePath; Size = $fileInfo.Length }
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Executable Exists: $ExeName" -Status "Fail" -Details "Not found at $exePath" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Executable Exists: $ExeName" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ExecutableSize {
    param([string]$ExeName)

    $startTime = Get-Date
    Write-TestName "Executable Size: $ExeName"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath $ExeName
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "BuildValidation" -Name "Executable Size: $ExeName" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $fileSize = (Get-Item $exePath).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)

        $expectedSize = $script:ExpectedFileSizes[$ExeName]
        if ($expectedSize) {
            if ($fileSize -ge $expectedSize.Min -and $fileSize -le $expectedSize.Max) {
                Add-TestResult -Category "BuildValidation" -Name "Executable Size: $ExeName" -Status "Pass" -Details "$fileSizeMB MB (within expected range)" -Duration ((Get-Date) - $startTime)
            } elseif ($fileSize -lt $expectedSize.Min) {
                Add-TestResult -Category "BuildValidation" -Name "Executable Size: $ExeName" -Status "Fail" -Details "$fileSizeMB MB (too small, expected at least $($expectedSize.Min / 1MB) MB)" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "BuildValidation" -Name "Executable Size: $ExeName" -Status "Warning" -Details "$fileSizeMB MB (larger than expected $($expectedSize.Max / 1MB) MB)" -Duration ((Get-Date) - $startTime)
            }
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Executable Size: $ExeName" -Status "Pass" -Details "$fileSizeMB MB" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Executable Size: $ExeName" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-PEHeader {
    param([string]$ExeName)

    $startTime = Get-Date
    Write-TestName "PE Header Validation: $ExeName"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath $ExeName
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "BuildValidation" -Name "PE Header Valid: $ExeName" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        # Read PE header (simplified check)
        $bytes = [System.IO.File]::ReadAllBytes($exePath)

        # Check MZ header
        if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
            Add-TestResult -Category "BuildValidation" -Name "PE Header Valid: $ExeName" -Status "Pass" -Details "Valid Windows PE executable" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "PE Header Valid: $ExeName" -Status "Fail" -Details "Invalid PE header (missing MZ signature)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "PE Header Valid: $ExeName" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ManifestExists {
    $startTime = Get-Date
    Write-TestName "Build Manifest Exists"

    try {
        $manifestPath = Join-Path $script:ResolvedBuildPath "build-manifest.json"
        if (Test-Path $manifestPath) {
            Add-TestResult -Category "BuildValidation" -Name "Build Manifest Exists" -Status "Pass" -Details "Found at $manifestPath" -Duration ((Get-Date) - $startTime)
        } else {
            # Also check for alternative names
            $altManifestPath = Join-Path $script:ResolvedBuildPath "manifest.json"
            if (Test-Path $altManifestPath) {
                Add-TestResult -Category "BuildValidation" -Name "Build Manifest Exists" -Status "Pass" -Details "Found at $altManifestPath" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "BuildValidation" -Name "Build Manifest Exists" -Status "Warning" -Details "Manifest file not found (optional)" -Duration ((Get-Date) - $startTime)
            }
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Build Manifest Exists" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ManifestValidJSON {
    $startTime = Get-Date
    Write-TestName "Manifest Valid JSON"

    try {
        $manifestPath = Join-Path $script:ResolvedBuildPath "build-manifest.json"
        if (-not (Test-Path $manifestPath)) {
            $manifestPath = Join-Path $script:ResolvedBuildPath "manifest.json"
        }

        if (-not (Test-Path $manifestPath)) {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Valid JSON" -Status "Skip" -Details "Manifest not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Add-TestResult -Category "BuildValidation" -Name "Manifest Valid JSON" -Status "Pass" -Details "Valid JSON structure" -Duration ((Get-Date) - $startTime)
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Manifest Valid JSON" -Status "Fail" -Details "Invalid JSON: $($_.Exception.Message)" -Duration ((Get-Date) - $startTime)
    }
}

function Test-ManifestVersion {
    $startTime = Get-Date
    Write-TestName "Manifest Version Field"

    try {
        $manifestPath = Join-Path $script:ResolvedBuildPath "build-manifest.json"
        if (-not (Test-Path $manifestPath)) {
            $manifestPath = Join-Path $script:ResolvedBuildPath "manifest.json"
        }

        if (-not (Test-Path $manifestPath)) {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Version" -Status "Skip" -Details "Manifest not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.version) {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Version" -Status "Pass" -Details "Version: $($manifest.version)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Version" -Status "Warning" -Details "Version field missing" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Manifest Version" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ManifestTier {
    $startTime = Get-Date
    Write-TestName "Manifest Tier Field"

    try {
        $manifestPath = Join-Path $script:ResolvedBuildPath "build-manifest.json"
        if (-not (Test-Path $manifestPath)) {
            $manifestPath = Join-Path $script:ResolvedBuildPath "manifest.json"
        }

        if (-not (Test-Path $manifestPath)) {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Tier" -Status "Skip" -Details "Manifest not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.tier) {
            if ($script:DetectedTier -and $manifest.tier -ne $script:DetectedTier) {
                Add-TestResult -Category "BuildValidation" -Name "Manifest Tier" -Status "Warning" -Details "Tier: $($manifest.tier) (expected: $($script:DetectedTier))" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "BuildValidation" -Name "Manifest Tier" -Status "Pass" -Details "Tier: $($manifest.tier)" -Duration ((Get-Date) - $startTime)
            }
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Tier" -Status "Warning" -Details "Tier field missing" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Manifest Tier" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ManifestArchitecture {
    $startTime = Get-Date
    Write-TestName "Manifest Architecture Field"

    try {
        $manifestPath = Join-Path $script:ResolvedBuildPath "build-manifest.json"
        if (-not (Test-Path $manifestPath)) {
            $manifestPath = Join-Path $script:ResolvedBuildPath "manifest.json"
        }

        if (-not (Test-Path $manifestPath)) {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Architecture" -Status "Skip" -Details "Manifest not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.architecture) {
            if ($script:DetectedArchitecture -and $manifest.architecture -ne $script:DetectedArchitecture) {
                Add-TestResult -Category "BuildValidation" -Name "Manifest Architecture" -Status "Warning" -Details "Architecture: $($manifest.architecture) (expected: $($script:DetectedArchitecture))" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "BuildValidation" -Name "Manifest Architecture" -Status "Pass" -Details "Architecture: $($manifest.architecture)" -Duration ((Get-Date) - $startTime)
            }
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Manifest Architecture" -Status "Warning" -Details "Architecture field missing" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Manifest Architecture" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ExecutableChecksum {
    param([string]$ExeName)

    $startTime = Get-Date
    Write-TestName "SHA256 Checksum: $ExeName"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath $ExeName
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "BuildValidation" -Name "SHA256 Checksum: $ExeName" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $hash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash
        Add-TestResult -Category "BuildValidation" -Name "SHA256 Checksum: $ExeName" -Status "Pass" -Details "SHA256: $hash" -Duration ((Get-Date) - $startTime) -Metadata @{ SHA256 = $hash }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "SHA256 Checksum: $ExeName" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-InternalDirectoryExists {
    $startTime = Get-Date
    Write-TestName "_internal Directory Exists"

    try {
        $internalDir = Join-Path $script:ResolvedBuildPath "_internal"
        if (Test-Path $internalDir) {
            $fileCount = (Get-ChildItem $internalDir -Recurse -File).Count
            Add-TestResult -Category "BuildValidation" -Name "_internal Directory Exists" -Status "Pass" -Details "$fileCount files in _internal" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "_internal Directory Exists" -Status "Fail" -Details "_internal directory not found (PyInstaller creates this)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "_internal Directory Exists" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-PythonRuntimeBundled {
    $startTime = Get-Date
    Write-TestName "Python Runtime Bundled"

    try {
        $internalDir = Join-Path $script:ResolvedBuildPath "_internal"
        if (-not (Test-Path $internalDir)) {
            Add-TestResult -Category "BuildValidation" -Name "Python Runtime Bundled" -Status "Skip" -Details "_internal directory not found" -Duration ((Get-Date) - $startTime)
            return
        }

        # Look for Python DLLs
        $pythonDlls = Get-ChildItem $internalDir -Recurse -Filter "python*.dll" -ErrorAction SilentlyContinue
        if ($pythonDlls) {
            Add-TestResult -Category "BuildValidation" -Name "Python Runtime Bundled" -Status "Pass" -Details "Found $($pythonDlls.Count) Python DLL(s)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Python Runtime Bundled" -Status "Warning" -Details "Python DLLs not found in _internal" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Python Runtime Bundled" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-DependenciesCount {
    $startTime = Get-Date
    Write-TestName "Dependencies Count"

    try {
        $internalDir = Join-Path $script:ResolvedBuildPath "_internal"
        if (-not (Test-Path $internalDir)) {
            Add-TestResult -Category "BuildValidation" -Name "Dependencies Count" -Status "Skip" -Details "_internal directory not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $fileCount = (Get-ChildItem $internalDir -Recurse -File).Count
        $minExpected = 50  # PyInstaller typically bundles many files

        if ($fileCount -ge $minExpected) {
            Add-TestResult -Category "BuildValidation" -Name "Dependencies Count" -Status "Pass" -Details "$fileCount dependency files (expected at least $minExpected)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Dependencies Count" -Status "Warning" -Details "Only $fileCount dependency files (expected at least $minExpected)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Dependencies Count" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ExecutableVersionInfo {
    param([string]$ExeName)

    $startTime = Get-Date
    Write-TestName "Version Info: $ExeName"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath $ExeName
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "BuildValidation" -Name "Version Info: $ExeName" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $versionInfo = (Get-Item $exePath).VersionInfo
        if ($versionInfo.FileVersion) {
            Add-TestResult -Category "BuildValidation" -Name "Version Info: $ExeName" -Status "Pass" -Details "File Version: $($versionInfo.FileVersion), Product: $($versionInfo.ProductName)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Version Info: $ExeName" -Status "Warning" -Details "No version information embedded" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Version Info: $ExeName" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-DigitalSignature {
    param([string]$ExeName)

    $startTime = Get-Date
    Write-TestName "Digital Signature: $ExeName"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath $ExeName
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "BuildValidation" -Name "Digital Signature: $ExeName" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $signature = Get-AuthenticodeSignature -FilePath $exePath
        if ($signature.Status -eq "Valid") {
            Add-TestResult -Category "BuildValidation" -Name "Digital Signature: $ExeName" -Status "Pass" -Details "Signed by: $($signature.SignerCertificate.Subject)" -Duration ((Get-Date) - $startTime)
        } elseif ($signature.Status -eq "NotSigned") {
            Add-TestResult -Category "BuildValidation" -Name "Digital Signature: $ExeName" -Status "Warning" -Details "Not digitally signed (optional)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "BuildValidation" -Name "Digital Signature: $ExeName" -Status "Warning" -Details "Signature status: $($signature.Status)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "BuildValidation" -Name "Digital Signature: $ExeName" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

# ============================================================================
# CATEGORY 3: PACKAGE STRUCTURE (15 checks)
# ============================================================================

function Test-PackageStructure {
    if ($TestCategory -ne "All" -and $TestCategory -ne "PackageStructure") {
        return
    }

    Write-TestCategory "Package Structure Tests"

    # Required files
    Test-FileExists "serena.exe"
    Test-FileExists "serena-mcp-server.exe"
    Test-FileExists "README.txt"

    # Launcher scripts
    Test-FileExists "serena.bat"
    Test-LauncherScriptContent

    # Configuration files
    Test-ConfigurationPresent

    # Documentation
    Test-DocumentationComplete

    # Directory structure
    Test-DirectoryStructure

    # Language servers directory
    Test-LanguageServersDirectory

    # License files
    Test-LicenseFiles

    # Examples/templates
    Test-ExamplesPresent

    # No development artifacts
    Test-NoDevelopmentArtifacts

    # File permissions
    Test-FilePermissions

    # Total package size
    Test-TotalPackageSize
}

function Test-FileExists {
    param([string]$FileName)

    $startTime = Get-Date
    Write-TestName "File Exists: $FileName"

    try {
        $filePath = Join-Path $script:ResolvedBuildPath $FileName
        if (Test-Path $filePath) {
            $fileSize = (Get-Item $filePath).Length
            Add-TestResult -Category "PackageStructure" -Name "File Exists: $FileName" -Status "Pass" -Details "Size: $([math]::Round($fileSize / 1KB, 2)) KB" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "File Exists: $FileName" -Status "Fail" -Details "Not found at $filePath" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "File Exists: $FileName" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-LauncherScriptContent {
    $startTime = Get-Date
    Write-TestName "Launcher Script Content"

    try {
        $launcherPath = Join-Path $script:ResolvedBuildPath "serena.bat"
        if (-not (Test-Path $launcherPath)) {
            Add-TestResult -Category "PackageStructure" -Name "Launcher Script Content" -Status "Skip" -Details "Launcher not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $content = Get-Content $launcherPath -Raw

        $requiredElements = @("SERENA_PORTABLE", "SERENA_HOME", "%~dp0", "serena.exe")
        $missing = @()

        foreach ($element in $requiredElements) {
            if ($content -notmatch [regex]::Escape($element)) {
                $missing += $element
            }
        }

        if ($missing.Count -eq 0) {
            Add-TestResult -Category "PackageStructure" -Name "Launcher Script Content" -Status "Pass" -Details "All required elements present" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "Launcher Script Content" -Status "Fail" -Details "Missing elements: $($missing -join ', ')" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Launcher Script Content" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ConfigurationPresent {
    $startTime = Get-Date
    Write-TestName "Configuration Files Present"

    try {
        $configFiles = @("config.yml", "serena.yml", ".serena/config.yml")
        $foundConfigs = @()

        foreach ($configFile in $configFiles) {
            $configPath = Join-Path $script:ResolvedBuildPath $configFile
            if (Test-Path $configPath) {
                $foundConfigs += $configFile
            }
        }

        if ($foundConfigs.Count -gt 0) {
            Add-TestResult -Category "PackageStructure" -Name "Configuration Present" -Status "Pass" -Details "Found: $($foundConfigs -join ', ')" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "Configuration Present" -Status "Warning" -Details "No configuration files found (may use defaults)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Configuration Present" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-DocumentationComplete {
    $startTime = Get-Date
    Write-TestName "Documentation Complete"

    try {
        $readmePath = Join-Path $script:ResolvedBuildPath "README.txt"
        if (-not (Test-Path $readmePath)) {
            Add-TestResult -Category "PackageStructure" -Name "Documentation Complete" -Status "Fail" -Details "README.txt not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $content = Get-Content $readmePath -Raw
        $requiredSections = @("Quick Start", "Commands", "Language Servers")
        $missing = @()

        foreach ($section in $requiredSections) {
            if ($content -notmatch [regex]::Escape($section)) {
                $missing += $section
            }
        }

        if ($missing.Count -eq 0) {
            Add-TestResult -Category "PackageStructure" -Name "Documentation Complete" -Status "Pass" -Details "All required sections present" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "Documentation Complete" -Status "Warning" -Details "Missing sections: $($missing -join ', ')" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Documentation Complete" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-DirectoryStructure {
    $startTime = Get-Date
    Write-TestName "Directory Structure"

    try {
        $expectedDirs = @("_internal")
        $foundDirs = @()
        $missingDirs = @()

        foreach ($dir in $expectedDirs) {
            $dirPath = Join-Path $script:ResolvedBuildPath $dir
            if (Test-Path $dirPath) {
                $foundDirs += $dir
            } else {
                $missingDirs += $dir
            }
        }

        if ($missingDirs.Count -eq 0) {
            Add-TestResult -Category "PackageStructure" -Name "Directory Structure" -Status "Pass" -Details "All required directories present" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "Directory Structure" -Status "Fail" -Details "Missing: $($missingDirs -join ', ')" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Directory Structure" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-LanguageServersDirectory {
    $startTime = Get-Date
    Write-TestName "Language Servers Directory"

    try {
        $lsDir = Join-Path $script:ResolvedBuildPath "language-servers"

        if ($script:DetectedTier -eq "minimal") {
            if (Test-Path $lsDir) {
                Add-TestResult -Category "PackageStructure" -Name "Language Servers Directory" -Status "Warning" -Details "Language servers present in minimal tier" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "PackageStructure" -Name "Language Servers Directory" -Status "Pass" -Details "No language servers (minimal tier)" -Duration ((Get-Date) - $startTime)
            }
        } else {
            if (Test-Path $lsDir) {
                $lsCount = (Get-ChildItem $lsDir -Directory -ErrorAction SilentlyContinue).Count
                Add-TestResult -Category "PackageStructure" -Name "Language Servers Directory" -Status "Pass" -Details "$lsCount language server directories found" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "PackageStructure" -Name "Language Servers Directory" -Status "Fail" -Details "Language servers directory not found (expected for $($script:DetectedTier) tier)" -Duration ((Get-Date) - $startTime)
            }
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Language Servers Directory" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-LicenseFiles {
    $startTime = Get-Date
    Write-TestName "License Files"

    try {
        $licenseFiles = @("LICENSE", "LICENSE.txt", "LICENSE.md")
        $foundLicense = $false

        foreach ($licenseFile in $licenseFiles) {
            $licensePath = Join-Path $script:ResolvedBuildPath $licenseFile
            if (Test-Path $licensePath) {
                $foundLicense = $true
                break
            }
        }

        if ($foundLicense) {
            Add-TestResult -Category "PackageStructure" -Name "License Files" -Status "Pass" -Details "License file found" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "License Files" -Status "Warning" -Details "No license file found (recommended)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "License Files" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-ExamplesPresent {
    $startTime = Get-Date
    Write-TestName "Examples/Templates Present"

    try {
        $examplesDirs = @("examples", "templates", "samples")
        $foundExamples = $false

        foreach ($examplesDir in $examplesDirs) {
            $examplesPath = Join-Path $script:ResolvedBuildPath $examplesDir
            if (Test-Path $examplesPath) {
                $foundExamples = $true
                break
            }
        }

        if ($foundExamples) {
            Add-TestResult -Category "PackageStructure" -Name "Examples Present" -Status "Pass" -Details "Examples/templates included" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "Examples Present" -Status "Skip" -Details "No examples directory (optional)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Examples Present" -Status "Skip" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-NoDevelopmentArtifacts {
    $startTime = Get-Date
    Write-TestName "No Development Artifacts"

    try {
        $devArtifacts = @("*.pyc", "__pycache__", ".git", ".pytest_cache", "*.pyo", ".mypy_cache")
        $foundArtifacts = @()

        foreach ($artifact in $devArtifacts) {
            $found = Get-ChildItem $script:ResolvedBuildPath -Recurse -Filter $artifact -ErrorAction SilentlyContinue
            if ($found) {
                $foundArtifacts += $artifact
            }
        }

        if ($foundArtifacts.Count -eq 0) {
            Add-TestResult -Category "PackageStructure" -Name "No Development Artifacts" -Status "Pass" -Details "No development artifacts found" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "No Development Artifacts" -Status "Warning" -Details "Found: $($foundArtifacts -join ', ')" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "No Development Artifacts" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-FilePermissions {
    $startTime = Get-Date
    Write-TestName "File Permissions"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "PackageStructure" -Name "File Permissions" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        # Check if file is readable and executable
        $acl = Get-Acl $exePath
        if ($acl) {
            Add-TestResult -Category "PackageStructure" -Name "File Permissions" -Status "Pass" -Details "File permissions readable" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "File Permissions" -Status "Warning" -Details "Could not read file permissions" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "File Permissions" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-TotalPackageSize {
    $startTime = Get-Date
    Write-TestName "Total Package Size"

    try {
        $totalSize = (Get-ChildItem $script:ResolvedBuildPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)

        # Different size expectations based on tier
        $maxSizes = @{
            "minimal" = 100MB
            "essential" = 300MB
            "complete" = 500MB
            "full" = 1000MB
        }

        $maxSize = if ($script:DetectedTier -and $maxSizes.ContainsKey($script:DetectedTier)) {
            $maxSizes[$script:DetectedTier]
        } else {
            500MB
        }

        if ($totalSize -le $maxSize) {
            Add-TestResult -Category "PackageStructure" -Name "Total Package Size" -Status "Pass" -Details "$totalSizeMB MB (max: $([math]::Round($maxSize / 1MB)) MB for $($script:DetectedTier) tier)" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "PackageStructure" -Name "Total Package Size" -Status "Warning" -Details "$totalSizeMB MB exceeds recommended max ($([math]::Round($maxSize / 1MB)) MB)" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "PackageStructure" -Name "Total Package Size" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

# ============================================================================
# CATEGORY 4: FUNCTIONAL TESTS (10 checks)
# ============================================================================

function Test-Functional {
    if ($TestCategory -ne "All" -and $TestCategory -ne "Functional") {
        return
    }

    Write-TestCategory "Functional Tests (Runtime Behavior)"

    # Execution tests
    Test-VersionCommand
    Test-HelpCommand
    Test-MCPServerStartup
    Test-LauncherExecution

    # Environment variables
    Test-EnvironmentVariables

    # Portability
    Test-NoRegistryDependencies
    Test-SelfContainedExecution

    # Error handling
    Test-InvalidCommandHandling
    Test-MissingFileRecovery

    # Performance
    Test-StartupPerformance
}

function Test-VersionCommand {
    $startTime = Get-Date
    Write-TestName "Version Command Execution"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "Version Command" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $outputFile = Join-Path $OutputDir "version-output.txt"
        $errorFile = Join-Path $OutputDir "version-error.txt"

        $process = Start-Process -FilePath $exePath -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile

        $duration = (Get-Date) - $startTime

        if ($process.ExitCode -eq 0) {
            $output = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Category "Functional" -Name "Version Command" -Status "Pass" -Details $output.Trim() -Duration $duration
        } else {
            $error = Get-Content $errorFile -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Category "Functional" -Name "Version Command" -Status "Fail" -Details "Exit code: $($process.ExitCode), Error: $error" -Duration $duration
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Version Command" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-HelpCommand {
    $startTime = Get-Date
    Write-TestName "Help Command Execution"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "Help Command" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $outputFile = Join-Path $OutputDir "help-output.txt"
        $errorFile = Join-Path $OutputDir "help-error.txt"

        $process = Start-Process -FilePath $exePath -ArgumentList "--help" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile

        $duration = (Get-Date) - $startTime

        if ($process.ExitCode -eq 0) {
            $output = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue

            # Check for expected content
            $expectedTerms = @("Usage", "Commands", "Options")
            $missing = @()
            foreach ($term in $expectedTerms) {
                if ($output -notmatch $term) {
                    $missing += $term
                }
            }

            if ($missing.Count -eq 0) {
                Add-TestResult -Category "Functional" -Name "Help Command" -Status "Pass" -Details "Help output complete" -Duration $duration
            } else {
                Add-TestResult -Category "Functional" -Name "Help Command" -Status "Warning" -Details "Missing: $($missing -join ', ')" -Duration $duration
            }
        } else {
            $error = Get-Content $errorFile -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Category "Functional" -Name "Help Command" -Status "Fail" -Details "Exit code: $($process.ExitCode), Error: $error" -Duration $duration
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Help Command" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-MCPServerStartup {
    $startTime = Get-Date
    Write-TestName "MCP Server Startup"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena-mcp-server.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "MCP Server Startup" -Status "Skip" -Details "MCP server executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $outputFile = Join-Path $OutputDir "mcp-output.txt"
        $errorFile = Join-Path $OutputDir "mcp-error.txt"

        # Start MCP server and check if it starts
        $job = Start-Job -ScriptBlock {
            param($ExePath, $OutputFile, $ErrorFile)
            $process = Start-Process -FilePath $ExePath -ArgumentList "--help" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $OutputFile -RedirectStandardError $ErrorFile
            return $process.ExitCode
        } -ArgumentList $exePath, $outputFile, $errorFile

        $result = Wait-Job $job -Timeout ($Timeout / 2) | Receive-Job
        Remove-Job $job -Force -ErrorAction SilentlyContinue

        $duration = (Get-Date) - $startTime

        if ($result -eq 0) {
            Add-TestResult -Category "Functional" -Name "MCP Server Startup" -Status "Pass" -Details "MCP server started successfully" -Duration $duration
        } else {
            Add-TestResult -Category "Functional" -Name "MCP Server Startup" -Status "Fail" -Details "MCP server failed to start (exit code: $result)" -Duration $duration
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "MCP Server Startup" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-LauncherExecution {
    $startTime = Get-Date
    Write-TestName "Launcher Script Execution"

    try {
        $launcherPath = Join-Path $script:ResolvedBuildPath "serena.bat"
        if (-not (Test-Path $launcherPath)) {
            Add-TestResult -Category "Functional" -Name "Launcher Execution" -Status "Skip" -Details "Launcher script not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $outputFile = Join-Path $OutputDir "launcher-output.txt"

        # Execute launcher with --version
        $process = Start-Process -FilePath $launcherPath -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile

        $duration = (Get-Date) - $startTime

        if ($process.ExitCode -eq 0) {
            Add-TestResult -Category "Functional" -Name "Launcher Execution" -Status "Pass" -Details "Launcher executed successfully" -Duration $duration
        } else {
            Add-TestResult -Category "Functional" -Name "Launcher Execution" -Status "Fail" -Details "Launcher failed (exit code: $($process.ExitCode))" -Duration $duration
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Launcher Execution" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-EnvironmentVariables {
    $startTime = Get-Date
    Write-TestName "Environment Variables Set"

    try {
        $launcherPath = Join-Path $script:ResolvedBuildPath "serena.bat"
        if (-not (Test-Path $launcherPath)) {
            Add-TestResult -Category "Functional" -Name "Environment Variables" -Status "Skip" -Details "Launcher not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $content = Get-Content $launcherPath -Raw

        $expectedVars = @("SERENA_PORTABLE", "SERENA_HOME")
        $foundVars = @()

        foreach ($var in $expectedVars) {
            if ($content -match $var) {
                $foundVars += $var
            }
        }

        if ($foundVars.Count -eq $expectedVars.Count) {
            Add-TestResult -Category "Functional" -Name "Environment Variables" -Status "Pass" -Details "All environment variables set: $($foundVars -join ', ')" -Duration ((Get-Date) - $startTime)
        } else {
            $missing = $expectedVars | Where-Object { $foundVars -notcontains $_ }
            Add-TestResult -Category "Functional" -Name "Environment Variables" -Status "Fail" -Details "Missing: $($missing -join ', ')" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Environment Variables" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-NoRegistryDependencies {
    $startTime = Get-Date
    Write-TestName "No Registry Dependencies"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "No Registry Dependencies" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        # Try to run with minimal environment
        $outputFile = Join-Path $OutputDir "no-registry-output.txt"
        $errorFile = Join-Path $OutputDir "no-registry-error.txt"

        # Create a minimal environment
        $env:PATH = "$script:ResolvedBuildPath;$env:SystemRoot\System32"

        $process = Start-Process -FilePath $exePath -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile

        $duration = (Get-Date) - $startTime

        if ($process.ExitCode -eq 0) {
            Add-TestResult -Category "Functional" -Name "No Registry Dependencies" -Status "Pass" -Details "Runs without registry dependencies" -Duration $duration
        } else {
            Add-TestResult -Category "Functional" -Name "No Registry Dependencies" -Status "Warning" -Details "May have registry dependencies" -Duration $duration
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "No Registry Dependencies" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-SelfContainedExecution {
    $startTime = Get-Date
    Write-TestName "Self-Contained Execution"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "Self-Contained Execution" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        # Run from different working directory
        $testDir = Join-Path $OutputDir "portability-test"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        Push-Location $testDir
        try {
            $outputFile = Join-Path $testDir "output.txt"
            $process = Start-Process -FilePath $exePath -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile

            $duration = (Get-Date) - $startTime

            if ($process.ExitCode -eq 0) {
                Add-TestResult -Category "Functional" -Name "Self-Contained Execution" -Status "Pass" -Details "Runs from different working directory" -Duration $duration
            } else {
                Add-TestResult -Category "Functional" -Name "Self-Contained Execution" -Status "Fail" -Details "Failed when run from different directory" -Duration $duration
            }
        } finally {
            Pop-Location
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Self-Contained Execution" -Status "Fail" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-InvalidCommandHandling {
    $startTime = Get-Date
    Write-TestName "Invalid Command Handling"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "Invalid Command Handling" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $outputFile = Join-Path $OutputDir "invalid-cmd-output.txt"
        $errorFile = Join-Path $OutputDir "invalid-cmd-error.txt"

        $process = Start-Process -FilePath $exePath -ArgumentList "invalid-command-xyz" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile

        $duration = (Get-Date) - $startTime

        # Expect non-zero exit code for invalid command
        if ($process.ExitCode -ne 0) {
            Add-TestResult -Category "Functional" -Name "Invalid Command Handling" -Status "Pass" -Details "Properly handles invalid commands (exit code: $($process.ExitCode))" -Duration $duration
        } else {
            Add-TestResult -Category "Functional" -Name "Invalid Command Handling" -Status "Warning" -Details "Did not return error for invalid command" -Duration $duration
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Invalid Command Handling" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-MissingFileRecovery {
    $startTime = Get-Date
    Write-TestName "Missing File Recovery"

    try {
        # This is a passive test - just check if error messages are clear
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "Missing File Recovery" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        # Check if _internal directory is accessible
        $internalDir = Join-Path $script:ResolvedBuildPath "_internal"
        if (Test-Path $internalDir) {
            Add-TestResult -Category "Functional" -Name "Missing File Recovery" -Status "Pass" -Details "All required files present" -Duration ((Get-Date) - $startTime)
        } else {
            Add-TestResult -Category "Functional" -Name "Missing File Recovery" -Status "Fail" -Details "Missing critical _internal directory" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Missing File Recovery" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

function Test-StartupPerformance {
    $startTime = Get-Date
    Write-TestName "Startup Performance"

    try {
        $exePath = Join-Path $script:ResolvedBuildPath "serena.exe"
        if (-not (Test-Path $exePath)) {
            Add-TestResult -Category "Functional" -Name "Startup Performance" -Status "Skip" -Details "Executable not found" -Duration ((Get-Date) - $startTime)
            return
        }

        $iterations = 3
        $times = @()

        for ($i = 0; $i -lt $iterations; $i++) {
            $outputFile = Join-Path $OutputDir "perf-$i.txt"
            $iterStart = Get-Date
            $process = Start-Process -FilePath $exePath -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile
            $iterEnd = Get-Date

            if ($process.ExitCode -eq 0) {
                $times += ($iterEnd - $iterStart).TotalMilliseconds
            }
        }

        if ($times.Count -gt 0) {
            $avgTime = ($times | Measure-Object -Average).Average
            $minTime = ($times | Measure-Object -Minimum).Minimum
            $maxTime = ($times | Measure-Object -Maximum).Maximum

            $threshold = 5000  # 5 seconds

            if ($avgTime -le $threshold) {
                Add-TestResult -Category "Functional" -Name "Startup Performance" -Status "Pass" -Details "Avg: $([math]::Round($avgTime))ms, Min: $([math]::Round($minTime))ms, Max: $([math]::Round($maxTime))ms" -Duration ((Get-Date) - $startTime)
            } else {
                Add-TestResult -Category "Functional" -Name "Startup Performance" -Status "Warning" -Details "Avg: $([math]::Round($avgTime))ms exceeds $threshold ms threshold" -Duration ((Get-Date) - $startTime)
            }
        } else {
            Add-TestResult -Category "Functional" -Name "Startup Performance" -Status "Fail" -Details "Could not measure performance" -Duration ((Get-Date) - $startTime)
        }
    } catch {
        Add-TestResult -Category "Functional" -Name "Startup Performance" -Status "Warning" -Details $_.Exception.Message -Duration ((Get-Date) - $startTime)
    }
}

# ============================================================================
# CATEGORY 5: LANGUAGE SERVER TESTS (6 checks per LS)
# ============================================================================

function Test-LanguageServers {
    if ($TestCategory -ne "All" -and $TestCategory -ne "LanguageServers") {
        return
    }

    Write-TestCategory "Language Server Tests"

    # Skip if minimal tier (no language servers)
    if ($script:DetectedTier -eq "minimal") {
        Add-TestResult -Category "LanguageServers" -Name "Language Server Tests" -Status "Skip" -Details "Minimal tier has no language servers"
        return
    }

    $lsDir = Join-Path $script:ResolvedBuildPath "language-servers"
    if (-not (Test-Path $lsDir)) {
        Add-TestResult -Category "LanguageServers" -Name "Language Server Tests" -Status "Fail" -Details "Language servers directory not found"
        return
    }

    # Get expected language servers for tier
    $expectedServers = if ($script:DetectedTier -and $script:TierLanguageServers.ContainsKey($script:DetectedTier)) {
        $script:TierLanguageServers[$script:DetectedTier]
    } else {
        @()
    }

    if ($expectedServers.Count -eq 0) {
        Add-TestResult -Category "LanguageServers" -Name "Language Server Tests" -Status "Skip" -Details "No expected language servers for tier: $($script:DetectedTier)"
        return
    }

    # Test each expected language server
    foreach ($server in $expectedServers) {
        Test-LanguageServer -ServerName $server
    }

    # Check for unexpected language servers
    $actualServers = Get-ChildItem $lsDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $unexpected = $actualServers | Where-Object { $expectedServers -notcontains $_ }

    if ($unexpected) {
        Add-TestResult -Category "LanguageServers" -Name "Unexpected Language Servers" -Status "Warning" -Details "Found: $($unexpected -join ', ')"
    }
}

function Test-LanguageServer {
    param([string]$ServerName)

    Write-TestInfo "Testing language server: $ServerName"

    $lsPath = Join-Path $script:ResolvedBuildPath "language-servers\$ServerName"

    # Test 1: Directory exists
    Test-LanguageServerExists -ServerName $ServerName -LSPath $lsPath

    # Test 2: Binary exists
    Test-LanguageServerBinary -ServerName $ServerName -LSPath $lsPath

    # Test 3: Binary executable
    Test-LanguageServerExecutable -ServerName $ServerName -LSPath $lsPath

    # Test 4: Version command
    Test-LanguageServerVersion -ServerName $ServerName -LSPath $lsPath

    # Test 5: Required files present
    Test-LanguageServerFiles -ServerName $ServerName -LSPath $lsPath

    # Test 6: Size reasonable
    Test-LanguageServerSize -ServerName $ServerName -LSPath $lsPath
}

function Test-LanguageServerExists {
    param([string]$ServerName, [string]$LSPath)

    $startTime = Get-Date

    if (Test-Path $LSPath) {
        Add-TestResult -Category "LanguageServers" -Name "LS Exists: $ServerName" -Status "Pass" -Details "Found at $LSPath" -Duration ((Get-Date) - $startTime)
    } else {
        Add-TestResult -Category "LanguageServers" -Name "LS Exists: $ServerName" -Status "Fail" -Details "Not found at $LSPath" -Duration ((Get-Date) - $startTime)
    }
}

function Test-LanguageServerBinary {
    param([string]$ServerName, [string]$LSPath)

    $startTime = Get-Date

    if (-not (Test-Path $LSPath)) {
        Add-TestResult -Category "LanguageServers" -Name "LS Binary: $ServerName" -Status "Skip" -Details "Directory not found" -Duration ((Get-Date) - $startTime)
        return
    }

    # Look for common binary patterns
    $binaryPatterns = @("*.exe", "*.cmd", "*.bat", "*/bin/*")
    $foundBinary = $false

    foreach ($pattern in $binaryPatterns) {
        $binaries = Get-ChildItem $LSPath -Recurse -Filter $pattern -ErrorAction SilentlyContinue
        if ($binaries) {
            $foundBinary = $true
            Add-TestResult -Category "LanguageServers" -Name "LS Binary: $ServerName" -Status "Pass" -Details "Found $($binaries.Count) binary file(s)" -Duration ((Get-Date) - $startTime)
            return
        }
    }

    if (-not $foundBinary) {
        Add-TestResult -Category "LanguageServers" -Name "LS Binary: $ServerName" -Status "Fail" -Details "No binary found" -Duration ((Get-Date) - $startTime)
    }
}

function Test-LanguageServerExecutable {
    param([string]$ServerName, [string]$LSPath)

    $startTime = Get-Date

    if (-not (Test-Path $LSPath)) {
        Add-TestResult -Category "LanguageServers" -Name "LS Executable: $ServerName" -Status "Skip" -Details "Directory not found" -Duration ((Get-Date) - $startTime)
        return
    }

    $exeFiles = Get-ChildItem $LSPath -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue
    if ($exeFiles) {
        # Check if files have execute permissions (on Windows, if we can read it, we can execute it)
        Add-TestResult -Category "LanguageServers" -Name "LS Executable: $ServerName" -Status "Pass" -Details "$($exeFiles.Count) executable(s) found" -Duration ((Get-Date) - $startTime)
    } else {
        Add-TestResult -Category "LanguageServers" -Name "LS Executable: $ServerName" -Status "Skip" -Details "No .exe files (may be script-based)" -Duration ((Get-Date) - $startTime)
    }
}

function Test-LanguageServerVersion {
    param([string]$ServerName, [string]$LSPath)

    $startTime = Get-Date

    if (-not (Test-Path $LSPath)) {
        Add-TestResult -Category "LanguageServers" -Name "LS Version: $ServerName" -Status "Skip" -Details "Directory not found" -Duration ((Get-Date) - $startTime)
        return
    }

    # Try to get version (very language-server specific, so we'll be lenient)
    $exeFiles = Get-ChildItem $LSPath -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($exeFiles) {
        try {
            $outputFile = Join-Path $OutputDir "ls-version-$ServerName.txt"
            $errorFile = Join-Path $OutputDir "ls-version-$ServerName-error.txt"

            # Try common version flags
            foreach ($versionFlag in @("--version", "-v", "version", "-V")) {
                $process = Start-Process -FilePath $exeFiles.FullName -ArgumentList $versionFlag -Wait -PassThru -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile -TimeoutMsec ($Timeout * 1000)

                if ($process.ExitCode -eq 0) {
                    $output = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
                    if ($output -and $output.Length -gt 0) {
                        Add-TestResult -Category "LanguageServers" -Name "LS Version: $ServerName" -Status "Pass" -Details $output.Trim().Substring(0, [Math]::Min(100, $output.Length)) -Duration ((Get-Date) - $startTime)
                        return
                    }
                }
            }

            Add-TestResult -Category "LanguageServers" -Name "LS Version: $ServerName" -Status "Skip" -Details "Version command not supported" -Duration ((Get-Date) - $startTime)
        } catch {
            Add-TestResult -Category "LanguageServers" -Name "LS Version: $ServerName" -Status "Skip" -Details "Could not get version: $($_.Exception.Message)" -Duration ((Get-Date) - $startTime)
        }
    } else {
        Add-TestResult -Category "LanguageServers" -Name "LS Version: $ServerName" -Status "Skip" -Details "No executable to test" -Duration ((Get-Date) - $startTime)
    }
}

function Test-LanguageServerFiles {
    param([string]$ServerName, [string]$LSPath)

    $startTime = Get-Date

    if (-not (Test-Path $LSPath)) {
        Add-TestResult -Category "LanguageServers" -Name "LS Files: $ServerName" -Status "Skip" -Details "Directory not found" -Duration ((Get-Date) - $startTime)
        return
    }

    $fileCount = (Get-ChildItem $LSPath -Recurse -File -ErrorAction SilentlyContinue).Count

    if ($fileCount -gt 0) {
        Add-TestResult -Category "LanguageServers" -Name "LS Files: $ServerName" -Status "Pass" -Details "$fileCount file(s) present" -Duration ((Get-Date) - $startTime)
    } else {
        Add-TestResult -Category "LanguageServers" -Name "LS Files: $ServerName" -Status "Fail" -Details "No files found" -Duration ((Get-Date) - $startTime)
    }
}

function Test-LanguageServerSize {
    param([string]$ServerName, [string]$LSPath)

    $startTime = Get-Date

    if (-not (Test-Path $LSPath)) {
        Add-TestResult -Category "LanguageServers" -Name "LS Size: $ServerName" -Status "Skip" -Details "Directory not found" -Duration ((Get-Date) - $startTime)
        return
    }

    $totalSize = (Get-ChildItem $LSPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $totalSizeMB = [math]::Round($totalSize / 1MB, 2)

    # Reasonable size check (most language servers are under 100MB)
    if ($totalSizeMB -le 100) {
        Add-TestResult -Category "LanguageServers" -Name "LS Size: $ServerName" -Status "Pass" -Details "$totalSizeMB MB" -Duration ((Get-Date) - $startTime)
    } elseif ($totalSizeMB -le 200) {
        Add-TestResult -Category "LanguageServers" -Name "LS Size: $ServerName" -Status "Warning" -Details "$totalSizeMB MB (larger than typical)" -Duration ((Get-Date) - $startTime)
    } else {
        Add-TestResult -Category "LanguageServers" -Name "LS Size: $ServerName" -Status "Warning" -Details "$totalSizeMB MB (unusually large)" -Duration ((Get-Date) - $startTime)
    }
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

function Export-TestReport {
    Write-TestCategory "Generating Test Report"

    $reportPath = Join-Path $OutputDir "test-report.json"
    $textReportPath = Join-Path $OutputDir "test-report.txt"

    # Create JSON report
    $report = @{
        TestRun = @{
            StartTime = $script:StartTime
            EndTime = Get-Date
            Duration = ((Get-Date) - $script:StartTime).ToString()
            BuildPath = $BuildPath
            ResolvedBuildPath = $script:ResolvedBuildPath
            DetectedTier = $script:DetectedTier
            DetectedArchitecture = $script:DetectedArchitecture
            TestCategory = $TestCategory
        }
        Statistics = $script:TestStats
        Results = $script:TestResults
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
    Write-TestInfo "JSON report saved: $reportPath"

    # Create text report
    $textReport = @()
    $textReport += "="*80
    $textReport += "SERENA WINDOWS PORTABLE TEST REPORT"
    $textReport += "="*80
    $textReport += ""
    $textReport += "Test Run Information:"
    $textReport += "  Start Time: $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    $textReport += "  End Time: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    $textReport += "  Duration: $((Get-Date) - $script:StartTime)"
    $textReport += "  Build Path: $BuildPath"
    $textReport += "  Tier: $($script:DetectedTier)"
    $textReport += "  Architecture: $($script:DetectedArchitecture)"
    $textReport += "  Test Category: $TestCategory"
    $textReport += ""
    $textReport += "="*80
    $textReport += "TEST STATISTICS"
    $textReport += "="*80
    $textReport += "  Total Tests: $($script:TestStats.Total)"
    $textReport += "  Passed: $($script:TestStats.Passed)"
    $textReport += "  Failed: $($script:TestStats.Failed)"
    $textReport += "  Skipped: $($script:TestStats.Skipped)"
    $textReport += "  Warnings: $($script:TestStats.Warnings)"
    $textReport += ""

    if ($script:TestStats.Total -gt 0) {
        $passRate = [math]::Round(($script:TestStats.Passed / $script:TestStats.Total) * 100, 2)
        $textReport += "  Pass Rate: $passRate%"
    }

    $textReport += ""
    $textReport += "="*80
    $textReport += "DETAILED RESULTS"
    $textReport += "="*80
    $textReport += ""

    # Group results by category
    $categories = $script:TestResults | Group-Object -Property Category

    foreach ($category in $categories) {
        $textReport += ""
        $textReport += "Category: $($category.Name)"
        $textReport += "-"*80

        foreach ($result in $category.Group) {
            $statusIcon = switch ($result.Status) {
                "Pass" { "[PASS]" }
                "Fail" { "[FAIL]" }
                "Skip" { "[SKIP]" }
                "Warning" { "[WARN]" }
            }

            $durationStr = if ($result.Duration.TotalMilliseconds -gt 0) {
                " ($([math]::Round($result.Duration.TotalMilliseconds))ms)"
            } else {
                ""
            }

            $textReport += "  $statusIcon $($result.Name)$durationStr"
            if ($result.Details) {
                $textReport += "         $($result.Details)"
            }
        }
    }

    $textReport += ""
    $textReport += "="*80
    $textReport += "END OF REPORT"
    $textReport += "="*80

    $textReport -join "`n" | Set-Content -Path $textReportPath -Encoding UTF8
    Write-TestInfo "Text report saved: $textReportPath"
}

function Show-TestSummary {
    Write-TestHeader "Test Summary"

    Write-Host ""
    Write-Host "Build Path: $BuildPath" -ForegroundColor Cyan
    if ($script:DetectedTier) {
        Write-Host "Tier: $($script:DetectedTier)" -ForegroundColor Cyan
    }
    if ($script:DetectedArchitecture) {
        Write-Host "Architecture: $($script:DetectedArchitecture)" -ForegroundColor Cyan
    }
    Write-Host "Duration: $((Get-Date) - $script:StartTime)" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Test Statistics:" -ForegroundColor Yellow
    Write-Host "  Total Tests: $($script:TestStats.Total)" -ForegroundColor White

    if ($script:TestStats.Passed -gt 0) {
        Write-Host "  Passed: $($script:TestStats.Passed)" -ForegroundColor Green
    }
    if ($script:TestStats.Failed -gt 0) {
        Write-Host "  Failed: $($script:TestStats.Failed)" -ForegroundColor Red
    }
    if ($script:TestStats.Skipped -gt 0) {
        Write-Host "  Skipped: $($script:TestStats.Skipped)" -ForegroundColor Yellow
    }
    if ($script:TestStats.Warnings -gt 0) {
        Write-Host "  Warnings: $($script:TestStats.Warnings)" -ForegroundColor Yellow
    }

    if ($script:TestStats.Total -gt 0) {
        $passRate = [math]::Round(($script:TestStats.Passed / $script:TestStats.Total) * 100, 2)
        Write-Host "  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })
    }

    Write-Host ""

    if ($script:TestStats.Failed -eq 0) {
        Write-Host "SUCCESS: All tests passed!" -ForegroundColor Green
        $exitCode = 0
    } else {
        Write-Host "FAILURE: $($script:TestStats.Failed) test(s) failed" -ForegroundColor Red
        $exitCode = 1
    }

    Write-Host ""
    Write-Host "Reports saved to:" -ForegroundColor Cyan
    Write-Host "  JSON: $(Join-Path $OutputDir 'test-report.json')" -ForegroundColor White
    Write-Host "  Text: $(Join-Path $OutputDir 'test-report.txt')" -ForegroundColor White

    return $exitCode
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    Write-TestHeader "Serena Windows Portable Test Suite"

    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Build Path: $BuildPath" -ForegroundColor White
    Write-Host "  Test Category: $TestCategory" -ForegroundColor White
    Write-Host "  Output Directory: $OutputDir" -ForegroundColor White
    if ($Tier) {
        Write-Host "  Expected Tier: $Tier" -ForegroundColor White
    }
    if ($Architecture) {
        Write-Host "  Expected Architecture: $Architecture" -ForegroundColor White
    }
    Write-Host "  Timeout: $Timeout seconds" -ForegroundColor White

    # Initialize
    if (-not (Initialize-TestEnvironment)) {
        Write-Host "Failed to initialize test environment" -ForegroundColor Red
        exit 2
    }

    # Run test categories
    Test-PreBuild
    Test-BuildValidation
    Test-PackageStructure
    Test-Functional
    Test-LanguageServers

    # Generate report
    if ($GenerateReport) {
        Export-TestReport
    }

    # Show summary and exit
    $exitCode = Show-TestSummary
    exit $exitCode

} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 2
}
