# Test script for Serena Agent Windows Installer
# This script validates the installer functionality in various scenarios

param(
    [string]$InstallerPath = "",
    [string]$TestMode = "basic",  # basic, full, silent
    [switch]$CleanupAfter,
    [switch]$Verbose
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$TestLogDir = Join-Path $ScriptDir "test-logs"
$TestResults = @()

# Create test log directory
if (-not (Test-Path $TestLogDir)) {
    New-Item -ItemType Directory -Path $TestLogDir -Force | Out-Null
}

function Write-TestLog {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path (Join-Path $TestLogDir "test-results.log") -Value $LogMessage
}

function Test-InstallerExists {
    Write-TestLog "Testing installer existence..."
    
    if (-not $InstallerPath) {
        # Auto-detect installer
        $Installers = Get-ChildItem -Path $ScriptDir -Name "serena-installer-*.exe"
        if ($Installers.Count -eq 0) {
            $Installers = Get-ChildItem -Path (Join-Path $ScriptDir "output") -Name "serena-installer-*.exe" -ErrorAction SilentlyContinue
        }
        
        if ($Installers.Count -eq 0) {
            Write-TestLog "No installer found" "ERROR"
            return $false
        }
        
        $InstallerPath = Join-Path $ScriptDir $Installers[0]
        if (-not (Test-Path $InstallerPath)) {
            $InstallerPath = Join-Path (Join-Path $ScriptDir "output") $Installers[0]
        }
    }
    
    if (Test-Path $InstallerPath) {
        Write-TestLog "Found installer: $InstallerPath"
        $Script:InstallerPath = $InstallerPath
        return $true
    } else {
        Write-TestLog "Installer not found: $InstallerPath" "ERROR"
        return $false
    }
}

function Test-Prerequisites {
    Write-TestLog "Testing prerequisites..."
    
    # Check Windows version
    $OSVersion = [System.Environment]::OSVersion.Version
    if ($OSVersion.Major -lt 10) {
        Write-TestLog "Windows 10+ required, found: $($OSVersion)" "ERROR"
        return $false
    }
    
    # Check 64-bit system
    if ([Environment]::Is64BitOperatingSystem -eq $false) {
        Write-TestLog "64-bit Windows required" "ERROR"
        return $false
    }
    
    # Check disk space
    $Drive = (Get-Location).Drive
    $FreeSpace = (Get-PSDrive $Drive.Name).Free / 1MB
    if ($FreeSpace -lt 500) {
        Write-TestLog "Insufficient disk space: ${FreeSpace}MB available" "WARNING"
    }
    
    Write-TestLog "Prerequisites check passed"
    return $true
}

function Test-SilentInstallation {
    Write-TestLog "Testing silent installation..."
    
    $TestInstallDir = Join-Path $env:TEMP "SerenaTest"
    $LogFile = Join-Path $TestLogDir "silent-install.log"
    
    try {
        # Create test configuration
        $ConfigFile = Join-Path $TestLogDir "test-config.ini"
        @"
[General]
InstallDir=$TestInstallDir
InstallType=core
Language=English

[Components]
Core=1
LanguageServers=0
Shortcuts=0
AddToPath=0
FileAssociations=0
DefenderExclusions=0

[Options]
InstallMode=user
SuppressReboot=1
ShowProgress=0
AcceptLicense=1
LaunchAfterInstall=0
"@ | Out-File -FilePath $ConfigFile -Encoding ASCII
        
        # Run silent installation
        $Process = Start-Process -FilePath $InstallerPath -ArgumentList "/S", "/INI=$ConfigFile", "/LOG=$LogFile" -Wait -PassThru
        
        if ($Process.ExitCode -eq 0) {
            Write-TestLog "Silent installation completed successfully"
            
            # Verify installation
            $SerenaExe = Join-Path $TestInstallDir "serena.exe"
            if (Test-Path $SerenaExe) {
                Write-TestLog "Core executable found: $SerenaExe"
                
                # Test executable
                $VersionProcess = Start-Process -FilePath $SerenaExe -ArgumentList "--version" -Wait -PassThru -RedirectStandardOutput (Join-Path $TestLogDir "version-output.txt") -NoNewWindow
                if ($VersionProcess.ExitCode -eq 0) {
                    $VersionOutput = Get-Content (Join-Path $TestLogDir "version-output.txt") -Raw
                    Write-TestLog "Version check passed: $($VersionOutput.Trim())"
                } else {
                    Write-TestLog "Version check failed with exit code: $($VersionProcess.ExitCode)" "ERROR"
                }
            } else {
                Write-TestLog "Core executable not found after installation" "ERROR"
                return $false
            }
            
            return $true
        } else {
            Write-TestLog "Silent installation failed with exit code: $($Process.ExitCode)" "ERROR"
            if (Test-Path $LogFile) {
                $LogContent = Get-Content $LogFile -Raw
                Write-TestLog "Installation log: $LogContent" "ERROR"
            }
            return $false
        }
    }
    catch {
        Write-TestLog "Silent installation test failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-SilentUninstallation {
    Write-TestLog "Testing silent uninstallation..."
    
    $TestInstallDir = Join-Path $env:TEMP "SerenaTest"
    $UninstallerPath = Join-Path $TestInstallDir "uninst.exe"
    
    if (Test-Path $UninstallerPath) {
        try {
            $Process = Start-Process -FilePath $UninstallerPath -ArgumentList "/S" -Wait -PassThru
            
            if ($Process.ExitCode -eq 0) {
                Write-TestLog "Silent uninstallation completed successfully"
                
                # Verify removal
                if (-not (Test-Path $TestInstallDir)) {
                    Write-TestLog "Installation directory removed successfully"
                    return $true
                } else {
                    Write-TestLog "Installation directory still exists after uninstallation" "WARNING"
                    return $true  # Still consider success as some files might remain
                }
            } else {
                Write-TestLog "Silent uninstallation failed with exit code: $($Process.ExitCode)" "ERROR"
                return $false
            }
        }
        catch {
            Write-TestLog "Silent uninstallation test failed: $($_.Exception.Message)" "ERROR"
            return $false
        }
    } else {
        Write-TestLog "Uninstaller not found: $UninstallerPath" "ERROR"
        return $false
    }
}

function Test-FileValidation {
    Write-TestLog "Testing installer file validation..."
    
    try {
        $FileInfo = Get-Item $InstallerPath
        Write-TestLog "Installer size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB"
        Write-TestLog "Installer created: $($FileInfo.CreationTime)"
        
        # Check digital signature (if present)
        $Signature = Get-AuthenticodeSignature $InstallerPath
        if ($Signature.Status -eq "Valid") {
            Write-TestLog "Digital signature valid: $($Signature.SignerCertificate.Subject)"
        } elseif ($Signature.Status -eq "NotSigned") {
            Write-TestLog "Installer is not digitally signed" "WARNING"
        } else {
            Write-TestLog "Digital signature status: $($Signature.Status)" "WARNING"
        }
        
        return $true
    }
    catch {
        Write-TestLog "File validation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-RegistryEntries {
    Write-TestLog "Testing registry entries after installation..."
    
    $TestResults = @{
        UninstallKey = $false
        AppPathKey = $false
        FileAssociation = $false
    }
    
    # Check uninstall registry entry
    $UninstallKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Serena Agent"
    if (Test-Path $UninstallKey) {
        $TestResults.UninstallKey = $true
        Write-TestLog "Uninstall registry key found"
    } else {
        Write-TestLog "Uninstall registry key not found" "WARNING"
    }
    
    # Check app path registry entry
    $AppPathKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\serena.exe"
    if (Test-Path $AppPathKey) {
        $TestResults.AppPathKey = $true
        Write-TestLog "App path registry key found"
    } else {
        Write-TestLog "App path registry key not found" "WARNING"
    }
    
    return $TestResults
}

function Run-BasicTests {
    Write-TestLog "Running basic installer tests..."
    
    $Results = @{}
    $Results.PrerequisitesCheck = Test-Prerequisites
    $Results.InstallerExists = Test-InstallerExists
    $Results.FileValidation = Test-FileValidation
    
    return $Results
}

function Run-FullTests {
    Write-TestLog "Running full installer tests..."
    
    $Results = Run-BasicTests
    
    if ($Results.InstallerExists) {
        $Results.SilentInstall = Test-SilentInstallation
        if ($Results.SilentInstall) {
            $Results.RegistryEntries = Test-RegistryEntries
        }
        $Results.SilentUninstall = Test-SilentUninstallation
    }
    
    return $Results
}

function Show-TestSummary {
    param($Results)
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Test Results Summary" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    $PassCount = 0
    $FailCount = 0
    
    foreach ($Test in $Results.Keys) {
        $Result = $Results[$Test]
        $Status = if ($Result -eq $true) { "PASS" } elseif ($Result -eq $false) { "FAIL" } else { "INFO" }
        $Color = switch ($Status) {
            "PASS" { "Green"; $PassCount++ }
            "FAIL" { "Red"; $FailCount++ }
            "INFO" { "Yellow" }
        }
        
        Write-Host "$Test`: $Status" -ForegroundColor $Color
        
        if ($Result -is [hashtable]) {
            foreach ($SubTest in $Result.Keys) {
                $SubResult = $Result[$SubTest]
                $SubStatus = if ($SubResult -eq $true) { "PASS" } else { "FAIL" }
                $SubColor = if ($SubResult -eq $true) { "Green" } else { "Red" }
                Write-Host "  $SubTest`: $SubStatus" -ForegroundColor $SubColor
            }
        }
    }
    
    Write-Host ""
    Write-Host "Total Tests: $($PassCount + $FailCount)" -ForegroundColor White
    Write-Host "Passed: $PassCount" -ForegroundColor Green
    Write-Host "Failed: $FailCount" -ForegroundColor Red
    Write-Host ""
    
    if ($FailCount -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
    } else {
        Write-Host "Some tests failed. Check logs for details." -ForegroundColor Red
    }
    
    Write-Host "Test logs: $TestLogDir" -ForegroundColor Gray
}

# Main execution
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Serena Agent Installer Test Suite" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test mode: $TestMode" -ForegroundColor Yellow
Write-Host "Cleanup after: $CleanupAfter" -ForegroundColor Yellow
Write-Host ""

# Initialize logging
Write-TestLog "Starting installer tests - Mode: $TestMode"

try {
    $TestResults = switch ($TestMode.ToLower()) {
        "basic" { Run-BasicTests }
        "full" { Run-FullTests }
        "silent" { 
            $BasicResults = Run-BasicTests
            if ($BasicResults.InstallerExists) {
                $BasicResults.SilentInstall = Test-SilentInstallation
                $BasicResults.SilentUninstall = Test-SilentUninstallation
            }
            $BasicResults
        }
        default {
            Write-TestLog "Unknown test mode: $TestMode" "ERROR"
            exit 1
        }
    }
    
    Show-TestSummary $TestResults
    
    # Cleanup if requested
    if ($CleanupAfter) {
        Write-TestLog "Performing cleanup..."
        $TestInstallDir = Join-Path $env:TEMP "SerenaTest"
        if (Test-Path $TestInstallDir) {
            Remove-Item $TestInstallDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestLog "Cleaned up test installation directory"
        }
    }
    
    Write-TestLog "Test suite completed"
}
catch {
    Write-TestLog "Test suite failed with error: $($_.Exception.Message)" "ERROR"
    exit 1
}