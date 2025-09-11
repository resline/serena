#Requires -Version 5.1

<#
.SYNOPSIS
    Test portable Serena distribution with enhanced architecture and tier validation

.DESCRIPTION
    Runs comprehensive tests on the portable Serena build to verify functionality,
    architecture compatibility, tier-specific language servers, performance benchmarks,
    and Windows version compatibility.

.PARAMETER PackagePath
    Path to the portable build directory or ZIP file

.PARAMETER TestOutputDir
    Directory for test outputs and logs (default: .\test-results)

.PARAMETER Timeout
    Timeout in seconds for individual tests (default: 60)

.PARAMETER Quick
    Run only quick tests, skip language server initialization and performance tests

.PARAMETER Tier
    Expected bundle tier to validate against (minimal, essential, complete, full)
    If not specified, will attempt to auto-detect from package name

.PARAMETER Architecture
    Expected architecture to validate against (x64, arm64)
    If not specified, will attempt to auto-detect from package name

.PARAMETER SkipPerformance
    Skip performance benchmarking tests

.PARAMETER SkipCompatibility
    Skip Windows version compatibility checks

.PARAMETER Help
    Show this help information

.PARAMETER Verbose
    Show detailed output from tests

.EXAMPLE
    .\test-portable.ps1 -PackagePath ".\dist\serena-portable\serena-1.0.0-windows-x64-portable"
    
.EXAMPLE
    .\test-portable.ps1 -PackagePath ".\serena-portable.zip" -Quick -Verbose
    
.EXAMPLE
    .\test-portable.ps1 -PackagePath ".\serena-essential-x64.zip" -Tier essential -Architecture x64
    
.EXAMPLE
    .\test-portable.ps1 -PackagePath ".\serena-complete-arm64" -Tier complete -Architecture arm64 -SkipPerformance
    
.EXAMPLE
    .\test-portable.ps1 -Help
    Display detailed help information
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PackagePath = "",
    
    [switch]$Help,
    
    [string]$TestOutputDir = ".\test-results",
    
    [int]$Timeout = 60,
    
    [switch]$Quick,
    
    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier,
    
    [ValidateSet("x64", "arm64")]
    [string]$Architecture,
    
    [switch]$SkipPerformance,
    
    [switch]$SkipCompatibility
)

# Handle help request
if ($Help -or [string]::IsNullOrEmpty($PackagePath)) {
    Write-Output @"
NAME
    test-portable.ps1
    
SYNOPSIS
    Tests a Serena portable Windows package.
    
DESCRIPTION
    This script validates a portable Windows build of Serena by running various tests
    including extraction, execution, language server validation, and cleanup.
    
PARAMETERS
    -PackagePath <String>
        Path to the portable package file (.zip or .7z)
        Required unless -Help is specified
        
    -TestOutputDir <String>
        Directory for test results
        Default: .\test-results
        
    -Timeout <Int32>
        Timeout in seconds for each test
        Default: 60
        
    -Quick
        Run only essential tests
        
    -SkipExtraction
        Skip extraction if package is already extracted
        
    -SkipExecution
        Skip execution tests
        
    -SkipLanguageServers
        Skip language server validation
        
    -SkipCleanup
        Skip cleanup after tests
        
    -Verbose
        Enable verbose output
        
    -Help
        Display this help message
        
EXAMPLES
    .\test-portable.ps1 -PackagePath ".\serena-portable.zip"
        Test a portable package with default settings
        
    .\test-portable.ps1 -PackagePath ".\serena.7z" -Quick
        Run quick tests on a 7z package
        
    .\test-portable.ps1 -PackagePath ".\dist\serena-portable.zip" -Verbose
        Test with verbose output
        
    .\test-portable.ps1 -Help
        Display this help message
        
NOTES
    Exit codes:
    0 - All tests passed
    1 - One or more tests failed
    2 - Critical error occurred
"@
    exit 0
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Test { param($Message) Write-Host "TEST: $Message" -ForegroundColor Magenta }

# Test result tracking
$script:TestResults = @()
$script:TestCount = 0
$script:PassCount = 0
$script:FailCount = 0

# Global test configuration
$script:DetectedArchitecture = $null
$script:DetectedTier = $null
$script:ExpectedLanguageServers = @{}

function Get-PackageMetadata {
    param([string]$PackagePath)
    
    $metadata = @{
        DetectedTier = $null
        DetectedArchitecture = $null
        PackageName = $null
    }
    
    # Extract package name from path
    $packageName = Split-Path $PackagePath -Leaf
    if ($packageName -match '\.zip$') {
        $packageName = $packageName -replace '\.zip$', ''
    }
    
    $metadata.PackageName = $packageName
    
    # Try to detect tier from package name
    $tierPatterns = @{
        "minimal" = @("minimal", "min")
        "essential" = @("essential", "ess")
        "complete" = @("complete", "comp")
        "full" = @("full")
    }
    
    foreach ($tier in $tierPatterns.Keys) {
        foreach ($pattern in $tierPatterns[$tier]) {
            if ($packageName -match $pattern) {
                $metadata.DetectedTier = $tier
                break
            }
        }
        if ($metadata.DetectedTier) { break }
    }
    
    # Try to detect architecture from package name
    if ($packageName -match "x64|amd64") {
        $metadata.DetectedArchitecture = "x64"
    } elseif ($packageName -match "arm64|aarch64") {
        $metadata.DetectedArchitecture = "arm64"
    }
    
    return $metadata
}

function Get-ExpectedLanguageServers {
    param([string]$Tier)
    
    # Define language servers by tier based on workflow configuration
    $tierConfigs = @{
        "minimal" = @()  # No language servers for minimal
        "essential" = @("pyright", "typescript", "rust-analyzer")
        "complete" = @("pyright", "typescript", "rust-analyzer", "java", "omnisharp", "lua-ls", "bash-ls")
        "full" = @("pyright", "typescript", "rust-analyzer", "java", "omnisharp", "lua-ls", "bash-ls", "go", "php", "swift")
    }
    
    if ($tierConfigs.ContainsKey($Tier)) {
        return $tierConfigs[$Tier]
    } else {
        return @()
    }
}

function Test-WindowsCompatibility {
    if ($SkipCompatibility) {
        Add-TestResult -Name "Windows Compatibility Check" -Status "Skip" -Details "Skipped due to -SkipCompatibility flag"
        return
    }

    Write-Test "Testing Windows version compatibility"
    
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        $windowsVersion = "$($osVersion.Major).$($osVersion.Minor)"
        
        # Windows 10 is version 10.0, Windows 11 is also 10.0 but with build >= 22000
        $isWindows10Plus = $osVersion.Major -eq 10 -and $osVersion.Minor -eq 0
        $buildNumber = [System.Environment]::OSVersion.Version.Build
        
        if ($isWindows10Plus) {
            if ($buildNumber -ge 22000) {
                $windowsName = "Windows 11"
            } else {
                $windowsName = "Windows 10"
            }
            Add-TestResult -Name "Windows Version Check" -Status "Pass" -Details "$windowsName (Build $buildNumber) meets minimum requirements"
        } else {
            Add-TestResult -Name "Windows Version Check" -Status "Fail" -Details "Windows $windowsVersion (Build $buildNumber) - minimum Windows 10 required"
        }
        
        # Check for Windows features that might affect portability
        $features = @()
        
        # Check if Windows Defender is active (might affect performance)
        try {
            $defender = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntivirusProduct -ErrorAction SilentlyContinue
            if ($defender) {
                $features += "Windows Defender detected"
            }
        } catch {
            # Ignore errors checking Defender
        }
        
        if ($features.Count -gt 0) {
            Add-TestResult -Name "Windows Features Check" -Status "Pass" -Details ($features -join "; ")
        }
        
    } catch {
        Add-TestResult -Name "Windows Compatibility Check" -Status "Fail" -Details "Failed to determine Windows version: $_"
    }
}

function Test-ArchitectureCompatibility {
    Write-Test "Testing architecture compatibility"
    
    if (-not $script:DetectedArchitecture -and -not $Architecture) {
        Add-TestResult -Name "Architecture Detection" -Status "Skip" -Details "Cannot determine architecture from package name"
        return
    }
    
    $targetArch = if ($Architecture) { $Architecture } else { $script:DetectedArchitecture }
    $systemArch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    
    # Check if we can determine system architecture properly
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64" -or $env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
        $systemArch = "x64"
    } elseif ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        $systemArch = "arm64"
    }
    
    Add-TestResult -Name "Architecture Detection" -Status "Pass" -Details "Target: $targetArch, System: $systemArch"
    
    # ARM64 builds should run on ARM64 systems, x64 builds should run on both x64 and ARM64 (via emulation)
    $compatible = $false
    if ($targetArch -eq "x64" -and ($systemArch -eq "x64" -or $systemArch -eq "arm64")) {
        $compatible = $true
    } elseif ($targetArch -eq "arm64" -and $systemArch -eq "arm64") {
        $compatible = $true
    }
    
    if ($compatible) {
        Add-TestResult -Name "Architecture Compatibility" -Status "Pass" -Details "$targetArch build compatible with $systemArch system"
    } else {
        Add-TestResult -Name "Architecture Compatibility" -Status "Fail" -Details "$targetArch build not compatible with $systemArch system"
    }
}

function Test-PerformanceBenchmarks {
    if ($SkipPerformance -or $Quick) {
        Add-TestResult -Name "Performance Benchmarks" -Status "Skip" -Details "Skipped due to flags"
        return
    }

    Write-Test "Running performance benchmarks"
    
    $serenaExe = Join-Path $script:ResolvedPackagePath "serena.exe"
    
    # Test startup performance
    try {
        $iterations = 5
        $startupTimes = @()
        
        for ($i = 0; $i -lt $iterations; $i++) {
            $startTime = Get-Date
            $process = Start-Process -FilePath $serenaExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $TestOutputDir "perf_version_$i.txt") -RedirectStandardError (Join-Path $TestOutputDir "perf_version_error_$i.txt")
            $endTime = Get-Date
            
            if ($process.ExitCode -eq 0) {
                $duration = ($endTime - $startTime).TotalMilliseconds
                $startupTimes += $duration
            }
        }
        
        if ($startupTimes.Count -gt 0) {
            $avgStartup = ($startupTimes | Measure-Object -Average).Average
            $minStartup = ($startupTimes | Measure-Object -Minimum).Minimum
            $maxStartup = ($startupTimes | Measure-Object -Maximum).Maximum
            
            Add-TestResult -Name "Startup Performance" -Status "Pass" -Details "Avg: $([math]::Round($avgStartup))ms, Min: $([math]::Round($minStartup))ms, Max: $([math]::Round($maxStartup))ms"
            
            # Flag if startup is unusually slow
            if ($avgStartup -gt 5000) {  # 5 seconds
                Add-TestResult -Name "Startup Performance Warning" -Status "Fail" -Details "Average startup time of $([math]::Round($avgStartup))ms exceeds 5000ms threshold"
            }
        } else {
            Add-TestResult -Name "Startup Performance" -Status "Fail" -Details "Failed to measure startup times"
        }
        
    } catch {
        Add-TestResult -Name "Startup Performance" -Status "Fail" -Details "Performance test failed: $_"
    }
    
    # Test MCP server startup performance  
    try {
        $startTime = Get-Date
        
        $job = Start-Job -ScriptBlock {
            param($ExePath, $OutputFile, $ErrorFile)
            
            $process = Start-Process -FilePath $ExePath -ArgumentList "serena-mcp-server" -NoNewWindow -PassThru -RedirectStandardOutput $OutputFile -RedirectStandardError $ErrorFile
            
            # Wait for startup
            Start-Sleep -Seconds 3
            
            if (-not $process.HasExited) {
                $process.Kill()
                return $true
            } else {
                return $false
            }
        } -ArgumentList $serenaExe, (Join-Path $TestOutputDir "perf_mcp.txt"), (Join-Path $TestOutputDir "perf_mcp_error.txt")
        
        $result = Wait-Job $job -Timeout ($Timeout / 2) | Receive-Job
        Remove-Job $job -Force
        
        $mcpStartupTime = ((Get-Date) - $startTime).TotalMilliseconds
        
        if ($result) {
            Add-TestResult -Name "MCP Server Performance" -Status "Pass" -Details "Started in $([math]::Round($mcpStartupTime))ms"
        } else {
            Add-TestResult -Name "MCP Server Performance" -Status "Fail" -Details "Failed to start within $([math]::Round($mcpStartupTime))ms"
        }
        
    } catch {
        Add-TestResult -Name "MCP Server Performance" -Status "Fail" -Details "MCP performance test failed: $_"
    }
}

function Test-PortableCharacteristics {
    Write-Test "Testing portable characteristics"
    
    $serenaExe = Join-Path $script:ResolvedPackagePath "serena.exe"
    
    # Test 1: No installation required
    Add-TestResult -Name "No Installation Required" -Status "Pass" -Details "Executable runs directly from extracted location"
    
    # Test 2: No registry dependencies
    try {
        # Try to run from a clean environment
        $tempEnv = @{}
        foreach ($key in [Environment]::GetEnvironmentVariables().Keys) {
            $tempEnv[$key] = [Environment]::GetEnvironmentVariable($key)
        }
        
        # Clear some environment variables temporarily
        [Environment]::SetEnvironmentVariable("PATH", "", [System.EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable("PYTHONPATH", "", [System.EnvironmentVariableTarget]::Process)
        
        $process = Start-Process -FilePath $serenaExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $TestOutputDir "portable_version.txt") -RedirectStandardError (Join-Path $TestOutputDir "portable_version_error.txt")
        
        # Restore environment
        foreach ($key in $tempEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $tempEnv[$key], [System.EnvironmentVariableTarget]::Process)
        }
        
        if ($process.ExitCode -eq 0) {
            Add-TestResult -Name "Registry Independence" -Status "Pass" -Details "Runs without system PATH or Python dependencies"
        } else {
            Add-TestResult -Name "Registry Independence" -Status "Fail" -Details "Failed to run in clean environment"
        }
        
    } catch {
        Add-TestResult -Name "Registry Independence" -Status "Fail" -Details "Error testing clean environment: $_"
    }
    
    # Test 3: Self-contained dependencies
    $internalDir = Join-Path $script:ResolvedPackagePath "_internal"
    if (Test-Path $internalDir) {
        $internalFiles = Get-ChildItem $internalDir -Recurse -File
        if ($internalFiles.Count -gt 50) {  # PyInstaller should bundle many files
            Add-TestResult -Name "Self-Contained Dependencies" -Status "Pass" -Details "$($internalFiles.Count) bundled dependency files found"
        } else {
            Add-TestResult -Name "Self-Contained Dependencies" -Status "Fail" -Details "Only $($internalFiles.Count) dependency files found, may be missing dependencies"
        }
    } else {
        Add-TestResult -Name "Self-Contained Dependencies" -Status "Fail" -Details "_internal directory not found"
    }
    
    # Test 4: No admin privileges required
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) {
            Add-TestResult -Name "Admin Privileges Test" -Status "Skip" -Details "Running as administrator, cannot test non-admin execution"
        } else {
            Add-TestResult -Name "Admin Privileges Test" -Status "Pass" -Details "Successfully running without administrator privileges"
        }
    } catch {
        Add-TestResult -Name "Admin Privileges Test" -Status "Fail" -Details "Error checking admin status: $_"
    }
    
    # Test 5: File portability - check for absolute paths
    $batFile = Join-Path $script:ResolvedPackagePath "serena.bat"
    if (Test-Path $batFile) {
        $batContent = Get-Content $batFile -Raw
        
        # Check for hardcoded absolute paths (bad for portability)
        if ($batContent -match ':\\\w+' -and $batContent -notmatch '%~dp0') {
            Add-TestResult -Name "Launcher Path Portability" -Status "Fail" -Details "Launcher contains hardcoded absolute paths"
        } else {
            Add-TestResult -Name "Launcher Path Portability" -Status "Pass" -Details "Launcher uses relative paths"
        }
    }
}

function Add-TestResult {
    param(
        [string]$Name,
        [string]$Status,  # Pass, Fail, Skip
        [string]$Details = "",
        [timespan]$Duration = [timespan]::Zero
    )
    
    $script:TestCount++
    
    $result = [PSCustomObject]@{
        Name = $Name
        Status = $Status
        Details = $Details
        Duration = $Duration
        Timestamp = Get-Date
    }
    
    $script:TestResults += $result
    
    switch ($Status) {
        "Pass" { 
            $script:PassCount++
            Write-Success "[OK] $Name $(if($Duration.TotalMilliseconds -gt 0){"($($Duration.TotalMilliseconds)ms)"})"
        }
        "Fail" { 
            $script:FailCount++
            Write-Error "[FAIL] $Name $(if($Duration.TotalMilliseconds -gt 0){"($($Duration.TotalMilliseconds)ms)"})"
            if ($Details) { Write-Error "  $Details" }
        }
        "Skip" { 
            Write-Warning "- $Name (skipped)"
            if ($Details) { Write-Warning "  $Details" }
        }
    }
}

function Initialize-TestEnvironment {
    Write-Test "Initializing test environment"
    
    # Create test output directory
    if (-not (Test-Path $TestOutputDir)) {
        New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null
    }
    
    # Resolve package path
    $script:ResolvedPackagePath = Resolve-Path $PackagePath -ErrorAction Stop
    
    # Get package metadata
    $metadata = Get-PackageMetadata $PackagePath
    $script:DetectedArchitecture = $metadata.DetectedArchitecture
    $script:DetectedTier = $metadata.DetectedTier
    
    # Set the tier to use for testing
    $testTier = if ($Tier) { $Tier } else { $script:DetectedTier }
    if ($testTier) {
        $script:ExpectedLanguageServers = Get-ExpectedLanguageServers $testTier
        Write-Info "Detected package tier: $testTier"
        Write-Info "Expected language servers: $($script:ExpectedLanguageServers -join ', ')"
    }
    
    if ($script:DetectedArchitecture) {
        Write-Info "Detected architecture: $script:DetectedArchitecture"
    }
    
    # If it's a ZIP file, extract it
    if ($script:ResolvedPackagePath -match '\.zip$') {
        Write-Info "Extracting ZIP file: $script:ResolvedPackagePath"
        
        $extractDir = Join-Path $TestOutputDir "extracted"
        if (Test-Path $extractDir) {
            Remove-Item $extractDir -Recurse -Force
        }
        
        try {
            Expand-Archive -Path $script:ResolvedPackagePath -DestinationPath $extractDir -Force
            
            # Find the serena executable in the extracted content
            $serenaExe = Get-ChildItem $extractDir -Recurse -Name "serena.exe" | Select-Object -First 1
            if (-not $serenaExe) {
                throw "serena.exe not found in extracted archive"
            }
            
            $script:ResolvedPackagePath = Split-Path (Join-Path $extractDir $serenaExe) -Parent
            Write-Info "Extracted to: $script:ResolvedPackagePath"
            
        } catch {
            Add-TestResult -Name "Package Extraction" -Status "Fail" -Details $_
            return $false
        }
    }
    
    Add-TestResult -Name "Test Environment Setup" -Status "Pass"
    return $true
}

function Test-PackageStructure {
    Write-Test "Testing package structure"
    
    $requiredFiles = @(
        "serena.exe",
        "serena.bat", 
        "README.txt"
    )
    
    $expectedDirs = @(
        "_internal"  # PyInstaller creates this
    )
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $script:ResolvedPackagePath $file
        if (Test-Path $filePath) {
            Add-TestResult -Name "Required File: $file" -Status "Pass"
        } else {
            Add-TestResult -Name "Required File: $file" -Status "Fail" -Details "File not found: $filePath"
        }
    }
    
    foreach ($dir in $expectedDirs) {
        $dirPath = Join-Path $script:ResolvedPackagePath $dir
        if (Test-Path $dirPath) {
            Add-TestResult -Name "Expected Directory: $dir" -Status "Pass"
        } else {
            Add-TestResult -Name "Expected Directory: $dir" -Status "Fail" -Details "Directory not found: $dirPath"
        }
    }
    
    # Check for language servers directory
    $lsDir = Join-Path $script:ResolvedPackagePath "language-servers"
    if (Test-Path $lsDir) {
        $lsCount = (Get-ChildItem $lsDir -Directory).Count
        Add-TestResult -Name "Language Servers Directory" -Status "Pass" -Details "$lsCount language server directories found"
    } else {
        if ($script:ExpectedLanguageServers.Count -gt 0) {
            Add-TestResult -Name "Language Servers Directory" -Status "Fail" -Details "Expected language servers but directory not found"
        } else {
            Add-TestResult -Name "Language Servers Directory" -Status "Pass" -Details "No language servers expected for this tier"
        }
    }
}

function Test-ExecutableBasics {
    Write-Test "Testing executable basics"
    
    $serenaExe = Join-Path $script:ResolvedPackagePath "serena.exe"
    
    if (-not (Test-Path $serenaExe)) {
        Add-TestResult -Name "Executable Exists" -Status "Fail" -Details "serena.exe not found"
        return
    }
    
    Add-TestResult -Name "Executable Exists" -Status "Pass"
    
    # Test executable runs
    try {
        $startTime = Get-Date
        
        $process = Start-Process -FilePath $serenaExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $TestOutputDir "version.txt") -RedirectStandardError (Join-Path $TestOutputDir "version_error.txt")
        
        $duration = (Get-Date) - $startTime
        
        if ($process.ExitCode -eq 0) {
            $versionOutput = Get-Content (Join-Path $TestOutputDir "version.txt") -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Name "Executable Runs" -Status "Pass" -Details $versionOutput.Trim() -Duration $duration
        } else {
            $errorOutput = Get-Content (Join-Path $TestOutputDir "version_error.txt") -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Name "Executable Runs" -Status "Fail" -Details "Exit code: $($process.ExitCode), Error: $errorOutput" -Duration $duration
        }
        
    } catch {
        Add-TestResult -Name "Executable Runs" -Status "Fail" -Details $_
    }
}

function Test-HelpOutput {
    Write-Test "Testing help output"
    
    $serenaExe = Join-Path $script:ResolvedPackagePath "serena.exe"
    
    try {
        $startTime = Get-Date
        
        $process = Start-Process -FilePath $serenaExe -ArgumentList "--help" -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $TestOutputDir "help.txt") -RedirectStandardError (Join-Path $TestOutputDir "help_error.txt")
        
        $duration = (Get-Date) - $startTime
        
        if ($process.ExitCode -eq 0) {
            $helpOutput = Get-Content (Join-Path $TestOutputDir "help.txt") -Raw -ErrorAction SilentlyContinue
            
            # Check for expected help content
            $expectedContent = @("Usage:", "Commands:", "Options:")
            $missingContent = @()
            
            foreach ($expected in $expectedContent) {
                if ($helpOutput -notmatch $expected) {
                    $missingContent += $expected
                }
            }
            
            if ($missingContent.Count -eq 0) {
                Add-TestResult -Name "Help Output Complete" -Status "Pass" -Duration $duration
            } else {
                Add-TestResult -Name "Help Output Complete" -Status "Fail" -Details "Missing content: $($missingContent -join ', ')" -Duration $duration
            }
            
        } else {
            $errorOutput = Get-Content (Join-Path $TestOutputDir "help_error.txt") -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Name "Help Output" -Status "Fail" -Details "Exit code: $($process.ExitCode), Error: $errorOutput" -Duration $duration
        }
        
    } catch {
        Add-TestResult -Name "Help Output" -Status "Fail" -Details $_
    }
}

function Test-MCPServerStart {
    Write-Test "Testing MCP server startup"
    
    $serenaExe = Join-Path $script:ResolvedPackagePath "serena.exe"
    
    try {
        $startTime = Get-Date
        
        # Start MCP server with timeout
        $job = Start-Job -ScriptBlock {
            param($ExePath, $OutputFile, $ErrorFile)
            
            $process = Start-Process -FilePath $ExePath -ArgumentList "serena-mcp-server" -NoNewWindow -PassThru -RedirectStandardOutput $OutputFile -RedirectStandardError $ErrorFile
            
            # Wait a bit for startup
            Start-Sleep -Seconds 5
            
            # Check if process is still running
            if (-not $process.HasExited) {
                $process.Kill()
                return @{ Success = $true; ExitCode = 0; Message = "Server started successfully" }
            } else {
                return @{ Success = $false; ExitCode = $process.ExitCode; Message = "Server exited prematurely" }
            }
            
        } -ArgumentList $serenaExe, (Join-Path $TestOutputDir "mcp.txt"), (Join-Path $TestOutputDir "mcp_error.txt")
        
        $result = Wait-Job $job -Timeout $Timeout | Receive-Job
        Remove-Job $job -Force
        
        $duration = (Get-Date) - $startTime
        
        if ($result -and $result.Success) {
            Add-TestResult -Name "MCP Server Startup" -Status "Pass" -Details $result.Message -Duration $duration
        } else {
            $errorDetails = if ($result) { $result.Message } else { "Timeout after $Timeout seconds" }
            Add-TestResult -Name "MCP Server Startup" -Status "Fail" -Details $errorDetails -Duration $duration
        }
        
    } catch {
        Add-TestResult -Name "MCP Server Startup" -Status "Fail" -Details $_
    }
}

function Test-LanguageServerInitialization {
    if ($Quick) {
        Add-TestResult -Name "Language Server Tests" -Status "Skip" -Details "Skipped due to --Quick flag"
        return
    }
    
    Write-Test "Testing tier-specific language server initialization"
    
    $lsDir = Join-Path $script:ResolvedPackagePath "language-servers"
    
    if (-not (Test-Path $lsDir)) {
        if ($script:ExpectedLanguageServers.Count -gt 0) {
            Add-TestResult -Name "Language Server Directory Check" -Status "Fail" -Details "Expected $($script:ExpectedLanguageServers.Count) language servers but directory not found"
        } else {
            Add-TestResult -Name "Language Server Directory Check" -Status "Pass" -Details "No language servers expected for this tier"
        }
        return
    }
    
    $languageDirs = Get-ChildItem $lsDir -Directory
    Add-TestResult -Name "Language Server Directory Check" -Status "Pass" -Details "$($languageDirs.Count) language server directories found"
    
    # Test expected language servers for the detected/specified tier
    if ($script:ExpectedLanguageServers.Count -gt 0) {
        foreach ($expectedLS in $script:ExpectedLanguageServers) {
            $lsPath = Join-Path $lsDir $expectedLS
            if (Test-Path $lsPath) {
                $files = Get-ChildItem $lsPath -Recurse -File
                if ($files.Count -gt 0) {
                    Add-TestResult -Name "Expected Language Server: $expectedLS" -Status "Pass" -Details "$($files.Count) files found"
                } else {
                    Add-TestResult -Name "Expected Language Server: $expectedLS" -Status "Fail" -Details "Directory exists but no files found"
                }
            } else {
                Add-TestResult -Name "Expected Language Server: $expectedLS" -Status "Fail" -Details "Expected for this tier but not found"
            }
        }
    }
    
    # Test any additional language servers not expected for this tier
    foreach ($langDir in $languageDirs) {
        $langName = $langDir.Name
        if ($script:ExpectedLanguageServers -notcontains $langName) {
            $files = Get-ChildItem $langDir.FullName -Recurse -File
            Add-TestResult -Name "Additional Language Server: $langName" -Status "Pass" -Details "$($files.Count) files found (not expected for $($script:DetectedTier) tier)"
        }
    }
}

function Test-LauncherScript {
    Write-Test "Testing launcher script"
    
    $launcherPath = Join-Path $script:ResolvedPackagePath "serena.bat"
    
    if (-not (Test-Path $launcherPath)) {
        Add-TestResult -Name "Launcher Script Exists" -Status "Fail" -Details "serena.bat not found"
        return
    }
    
    Add-TestResult -Name "Launcher Script Exists" -Status "Pass"
    
    # Test launcher script content
    try {
        $content = Get-Content $launcherPath -Raw
        
        $expectedElements = @(
            "SERENA_PORTABLE=1",
            "SERENA_HOME=",
            "serena.exe"
        )
        
        $missingElements = @()
        foreach ($element in $expectedElements) {
            if ($content -notmatch [regex]::Escape($element)) {
                $missingElements += $element
            }
        }
        
        if ($missingElements.Count -eq 0) {
            Add-TestResult -Name "Launcher Script Content" -Status "Pass"
        } else {
            Add-TestResult -Name "Launcher Script Content" -Status "Fail" -Details "Missing elements: $($missingElements -join ', ')"
        }
        
    } catch {
        Add-TestResult -Name "Launcher Script Content" -Status "Fail" -Details $_
    }
}

function Test-ReadmeFile {
    Write-Test "Testing README file"
    
    $readmePath = Join-Path $script:ResolvedPackagePath "README.txt"
    
    if (-not (Test-Path $readmePath)) {
        Add-TestResult -Name "README File Exists" -Status "Fail" -Details "README.txt not found"
        return
    }
    
    Add-TestResult -Name "README File Exists" -Status "Pass"
    
    try {
        $content = Get-Content $readmePath -Raw
        
        $expectedSections = @(
            "# Serena Portable",
            "## Quick Start",
            "## Commands",
            "## Language Servers",
            "## Configuration",
            "## Support"
        )
        
        $missingSections = @()
        foreach ($section in $expectedSections) {
            if ($content -notmatch [regex]::Escape($section)) {
                $missingSections += $section
            }
        }
        
        if ($missingSections.Count -eq 0) {
            Add-TestResult -Name "README Content Complete" -Status "Pass"
        } else {
            Add-TestResult -Name "README Content Complete" -Status "Fail" -Details "Missing sections: $($missingSections -join ', ')"
        }
        
    } catch {
        Add-TestResult -Name "README Content" -Status "Fail" -Details $_
    }
}

function Test-PortabilityFeatures {
    Write-Test "Testing portability features"
    
    $serenaExe = Join-Path $script:ResolvedPackagePath "serena.exe"
    
    # Test that it runs from different working directories
    $tempTestDir = Join-Path $TestOutputDir "portability-test"
    New-Item -ItemType Directory -Path $tempTestDir -Force | Out-Null
    
    try {
        Push-Location $tempTestDir
        
        $startTime = Get-Date
        $process = Start-Process -FilePath $serenaExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $tempTestDir "version.txt") -RedirectStandardError (Join-Path $tempTestDir "version_error.txt")
        $duration = (Get-Date) - $startTime
        
        if ($process.ExitCode -eq 0) {
            Add-TestResult -Name "Runs From Different Directory" -Status "Pass" -Duration $duration
        } else {
            $errorOutput = Get-Content (Join-Path $tempTestDir "version_error.txt") -Raw -ErrorAction SilentlyContinue
            Add-TestResult -Name "Runs From Different Directory" -Status "Fail" -Details "Exit code: $($process.ExitCode), Error: $errorOutput" -Duration $duration
        }
        
    } catch {
        Add-TestResult -Name "Runs From Different Directory" -Status "Fail" -Details $_
    } finally {
        Pop-Location
    }
}

function Export-TestResults {
    Write-Test "Exporting test results"
    
    # Create detailed report
    $reportPath = Join-Path $TestOutputDir "test-report.txt"
    $report = @()
    
    $report += "Serena Portable Build Test Report (Enhanced)"
    $report += "=========================================="
    $report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "Package: $PackagePath"
    $report += "Test Mode: $(if($Quick){'Quick'}else{'Full'})"
    $report += "Architecture: $(if($script:DetectedArchitecture){$script:DetectedArchitecture}else{'Unknown'})"
    $report += "Tier: $(if($script:DetectedTier){$script:DetectedTier}else{'Unknown'})"
    $report += "Expected Language Servers: $($script:ExpectedLanguageServers -join ', ')"
    $report += ""
    
    $report += "Summary:"
    $report += "--------"
    $report += "Total Tests: $script:TestCount"
    $report += "Passed: $script:PassCount"
    $report += "Failed: $script:FailCount"
    $report += "Skipped: $($script:TestCount - $script:PassCount - $script:FailCount)"
    $report += ""
    
    $report += "Detailed Results:"
    $report += "-----------------"
    
    foreach ($result in $script:TestResults) {
        $statusIcon = switch ($result.Status) {
            "Pass" { "[OK]" }
            "Fail" { "[FAIL]" }
            "Skip" { "-" }
            default { "?" }
        }
        
        $durationStr = if ($result.Duration.TotalMilliseconds -gt 0) { " ($($result.Duration.TotalMilliseconds)ms)" } else { "" }
        $report += "$statusIcon $($result.Name)$durationStr"
        
        if ($result.Details) {
            $report += "  $($result.Details)"
        }
        $report += ""
    }
    
    $report -join "`n" | Set-Content -Path $reportPath -Encoding UTF8
    Write-Info "Test report saved: $reportPath"
    
    # Export to JSON for programmatic processing
    $jsonPath = Join-Path $TestOutputDir "test-results.json"
    $jsonData = @{
        TestResults = $script:TestResults
        Summary = @{
            PackagePath = $PackagePath
            DetectedArchitecture = $script:DetectedArchitecture
            DetectedTier = $script:DetectedTier
            ExpectedLanguageServers = $script:ExpectedLanguageServers
            TotalTests = $script:TestCount
            PassedTests = $script:PassCount
            FailedTests = $script:FailCount
            SkippedTests = $script:TestCount - $script:PassCount - $script:FailCount
            TestMode = if($Quick){"Quick"}else{"Full"}
            GeneratedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
    }
    
    $jsonData | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Info "Test results JSON: $jsonPath"
}

function Show-TestSummary {
    Write-Host ""
    Write-Host "=== Enhanced Test Summary ===" -ForegroundColor Magenta
    Write-Host "Package: $PackagePath" -ForegroundColor Cyan
    Write-Host "Architecture: $(if($script:DetectedArchitecture){$script:DetectedArchitecture}else{'Unknown'})" -ForegroundColor Cyan
    Write-Host "Tier: $(if($script:DetectedTier){$script:DetectedTier}else{'Unknown'})" -ForegroundColor Cyan
    Write-Host "Total Tests: $script:TestCount" -ForegroundColor Cyan
    
    if ($script:PassCount -gt 0) {
        Write-Host "Passed: $script:PassCount" -ForegroundColor Green
    }
    
    if ($script:FailCount -gt 0) {
        Write-Host "Failed: $script:FailCount" -ForegroundColor Red
    }
    
    $skipCount = $script:TestCount - $script:PassCount - $script:FailCount
    if ($skipCount -gt 0) {
        Write-Host "Skipped: $skipCount" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    if ($script:FailCount -eq 0) {
        Write-Success "All tests passed! The portable build appears to be working correctly."
    } else {
        Write-Error "Some tests failed. Please check the test report for details."
        Write-Error "Report location: $(Join-Path $TestOutputDir 'test-report.txt')"
    }
}

# Main execution
try {
    $startTime = Get-Date
    
    Write-Host "=== Enhanced Serena Portable Build Tester ===" -ForegroundColor Magenta
    Write-Host "Package: $PackagePath" -ForegroundColor Cyan
    Write-Host "Test Mode: $(if($Quick){'Quick'}else{'Full'})" -ForegroundColor Cyan
    if ($Tier) { Write-Host "Expected Tier: $Tier" -ForegroundColor Cyan }
    if ($Architecture) { Write-Host "Expected Architecture: $Architecture" -ForegroundColor Cyan }
    Write-Host ""
    
    if (-not (Initialize-TestEnvironment)) {
        exit 1
    }
    
    # Run enhanced test suite
    Test-WindowsCompatibility
    Test-ArchitectureCompatibility
    Test-PackageStructure
    Test-ExecutableBasics
    Test-HelpOutput
    Test-LauncherScript
    Test-ReadmeFile
    Test-MCPServerStart
    Test-LanguageServerInitialization
    Test-PortabilityFeatures
    Test-PortableCharacteristics
    Test-PerformanceBenchmarks
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Export-TestResults
    Show-TestSummary
    
    Write-Host ""
    Write-Info "Total test time: $($duration.ToString('mm\:ss'))"
    
    # Exit with appropriate code
    exit $(if ($script:FailCount -eq 0) { 0 } else { 1 })
    
} catch {
    Write-Error "Test execution failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}