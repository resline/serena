#Requires -Version 5.1
<#
.SYNOPSIS
    Serena Agent - Uninstaller for Windows

.DESCRIPTION
    This PowerShell script completely removes Serena Agent from Windows:
    - Removes installation directory
    - Cleans up environment variables
    - Removes registry entries
    - Removes shortcuts and Start Menu entries
    - Removes firewall rules
    - Cleans up PATH variable
    - Optional backup of user data

.PARAMETER KeepUserData
    Keep user configuration and cache data

.PARAMETER Silent
    Run without user interaction

.PARAMETER LogLevel
    Logging level: Info, Warning, Error (default: Info)

.EXAMPLE
    .\uninstall.ps1
    Interactive uninstallation

.EXAMPLE
    .\uninstall.ps1 -Silent
    Silent uninstallation

.EXAMPLE
    .\uninstall.ps1 -KeepUserData
    Uninstall but keep user configuration and cache
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$KeepUserData,
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Info", "Warning", "Error")]
    [string]$LogLevel = "Info"
)

# Set strict error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Script variables
$ScriptDir = $PSScriptRoot
$LogFile = Join-Path $ScriptDir "uninstall.log"
$SerenaHome = [Environment]::GetEnvironmentVariable("SERENA_HOME", "Machine")
$SolidLspHome = [Environment]::GetEnvironmentVariable("SOLIDLSP_HOME", "Machine")

# Default paths if environment variables not set
if (-not $SerenaHome) {
    $SerenaHome = "$env:USERPROFILE\Serena"
}
if (-not $SolidLspHome) {
    $SolidLspHome = "$env:USERPROFILE\.solidlsp"
}

$VenvDir = Join-Path $SerenaHome "venv"
$UserDataDirs = @(
    "$env:USERPROFILE\.serena",
    "$env:LOCALAPPDATA\Serena",
    "$env:APPDATA\Serena"
)

#region Logging Functions

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    
    # Write to console based on log level preference
    $shouldOutput = switch ($LogLevel) {
        "Info" { $true }
        "Warning" { $Level -in @("Warning", "Error", "Success") }
        "Error" { $Level -in @("Error", "Success") }
    }
    
    if ($shouldOutput -and -not $Silent) {
        switch ($Level) {
            "Info" { Write-Host $Message -ForegroundColor White }
            "Warning" { Write-Host $Message -ForegroundColor Yellow }
            "Error" { Write-Host $Message -ForegroundColor Red }
            "Success" { Write-Host $Message -ForegroundColor Green }
        }
    }
}

function Write-Progress-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Activity,
        
        [Parameter(Mandatory=$true)]
        [string]$Status,
        
        [Parameter(Mandatory=$false)]
        [int]$PercentComplete = -1
    )
    
    if (-not $Silent) {
        if ($PercentComplete -ge 0) {
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        } else {
            Write-Progress -Activity $Activity -Status $Status
        }
    }
    
    Write-Log "$Activity - $Status" -Level Info
}

#endregion

#region Uninstall Functions

function Initialize-Uninstall {
    # Create log file
    if (Test-Path $LogFile) {
        Remove-Item $LogFile -Force
    }
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
    
    Write-Log "=== Serena Agent Uninstallation Started ===" -Level Info
    Write-Log "Serena Home: $SerenaHome" -Level Info
    Write-Log "SolidLSP Home: $SolidLspHome" -Level Info
    Write-Log "Keep User Data: $KeepUserData" -Level Info
    Write-Log "Silent Mode: $Silent" -Level Info
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host "    Serena Agent - Uninstallation" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "This will remove Serena Agent from your system." -ForegroundColor White
        Write-Host ""
        Write-Host "Serena Home: $SerenaHome" -ForegroundColor White
        Write-Host "SolidLSP Home: $SolidLspHome" -ForegroundColor White
        Write-Host "Keep User Data: $($KeepUserData.IsPresent)" -ForegroundColor White
        Write-Host "Log file: $LogFile" -ForegroundColor White
        Write-Host ""
        
        $response = Read-Host "Are you sure you want to uninstall Serena Agent? (y/N)"
        if ($response -notmatch '^[Yy]') {
            Write-Log "Uninstallation cancelled by user" -Level Info
            exit 0
        }
    }
}

function Stop-SerenaProcesses {
    Write-Progress-Log -Activity "Process Cleanup" -Status "Stopping Serena processes..." -PercentComplete 10
    
    try {
        # Stop any running Serena processes
        $processes = Get-Process | Where-Object { 
            $_.ProcessName -like "*serena*" -or 
            $_.ProcessName -like "*solidlsp*" -or
            ($_.Path -and $_.Path -like "*$SerenaHome*")
        }
        
        if ($processes) {
            foreach ($process in $processes) {
                try {
                    Write-Log "Stopping process: $($process.ProcessName) (PID: $($process.Id))" -Level Info
                    $process.CloseMainWindow()
                    if (-not $process.WaitForExit(5000)) {
                        $process.Kill()
                    }
                    Write-Log "Process stopped: $($process.ProcessName)" -Level Success
                }
                catch {
                    Write-Log "WARNING: Failed to stop process $($process.ProcessName): $($_.Exception.Message)" -Level Warning
                }
            }
        } else {
            Write-Log "No Serena processes found running" -Level Info
        }
    }
    catch {
        Write-Log "WARNING: Error during process cleanup: $($_.Exception.Message)" -Level Warning
    }
}

function Remove-InstallationDirectories {
    Write-Progress-Log -Activity "Directory Cleanup" -Status "Removing installation directories..." -PercentComplete 20
    
    # Remove main installation directory
    if (Test-Path $SerenaHome) {
        try {
            Write-Log "Removing Serena installation directory: $SerenaHome" -Level Info
            Remove-Item -Path $SerenaHome -Recurse -Force
            Write-Log "Serena installation directory removed successfully" -Level Success
        }
        catch {
            Write-Log "ERROR: Failed to remove Serena installation directory: $($_.Exception.Message)" -Level Error
        }
    } else {
        Write-Log "Serena installation directory not found: $SerenaHome" -Level Info
    }
    
    # Remove SolidLSP directory
    if (Test-Path $SolidLspHome) {
        try {
            Write-Log "Removing SolidLSP directory: $SolidLspHome" -Level Info
            Remove-Item -Path $SolidLspHome -Recurse -Force
            Write-Log "SolidLSP directory removed successfully" -Level Success
        }
        catch {
            Write-Log "ERROR: Failed to remove SolidLSP directory: $($_.Exception.Message)" -Level Error
        }
    } else {
        Write-Log "SolidLSP directory not found: $SolidLspHome" -Level Info
    }
}

function Remove-UserDataDirectories {
    if ($KeepUserData) {
        Write-Log "Keeping user data directories as requested" -Level Info
        return
    }
    
    Write-Progress-Log -Activity "User Data Cleanup" -Status "Removing user data directories..." -PercentComplete 30
    
    foreach ($userDir in $UserDataDirs) {
        if (Test-Path $userDir) {
            try {
                Write-Log "Removing user data directory: $userDir" -Level Info
                Remove-Item -Path $userDir -Recurse -Force
                Write-Log "User data directory removed: $userDir" -Level Success
            }
            catch {
                Write-Log "WARNING: Failed to remove user data directory: $userDir - $($_.Exception.Message)" -Level Warning
            }
        }
    }
}

function Remove-EnvironmentVariables {
    Write-Progress-Log -Activity "Environment Cleanup" -Status "Removing environment variables..." -PercentComplete 40
    
    try {
        # Remove system environment variables
        $systemVars = @("SERENA_HOME", "SOLIDLSP_HOME")
        foreach ($var in $systemVars) {
            $value = [Environment]::GetEnvironmentVariable($var, "Machine")
            if ($value) {
                [Environment]::SetEnvironmentVariable($var, $null, "Machine")
                Write-Log "Removed system environment variable: $var" -Level Success
            }
        }
        
        # Remove user environment variables
        $userVars = @("SERENA_CONFIG_DIR", "SERENA_LOG_LEVEL", "SERENA_CACHE_DIR")
        foreach ($var in $userVars) {
            $value = [Environment]::GetEnvironmentVariable($var, "User")
            if ($value) {
                [Environment]::SetEnvironmentVariable($var, $null, "User")
                Write-Log "Removed user environment variable: $var" -Level Success
            }
        }
        
        # Clean up PATH variable
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($currentPath) {
            $venvScripts = Join-Path $VenvDir "Scripts"
            if ($currentPath -like "*$venvScripts*") {
                $newPath = $currentPath -replace [regex]::Escape(";$venvScripts"), "" -replace [regex]::Escape("$venvScripts;"), ""
                [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
                Write-Log "Removed Serena from system PATH" -Level Success
            }
        }
        
        Write-Log "Environment variables cleanup completed" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to clean up some environment variables: $($_.Exception.Message)" -Level Warning
    }
}

function Remove-RegistryEntries {
    Write-Progress-Log -Activity "Registry Cleanup" -Status "Removing registry entries..." -PercentComplete 50
    
    try {
        # Remove file associations
        if (Test-Path "HKCR:\Serena.Agent") {
            Remove-Item -Path "HKCR:\Serena.Agent" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed Serena.Agent registry key" -Level Success
        }
        
        if (Test-Path "HKCR:\.serena") {
            Remove-Item -Path "HKCR:\.serena" -Force -ErrorAction SilentlyContinue
            Write-Log "Removed .serena file association" -Level Success
        }
        
        # Remove uninstall entry
        $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\SerenaAgent"
        if (Test-Path $uninstallKey) {
            Remove-Item -Path $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed uninstall registry entry" -Level Success
        }
        
        Write-Log "Registry cleanup completed" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to clean up some registry entries: $($_.Exception.Message)" -Level Warning
    }
}

function Remove-Shortcuts {
    Write-Progress-Log -Activity "Shortcuts Cleanup" -Status "Removing shortcuts and menu entries..." -PercentComplete 60
    
    try {
        # Remove desktop shortcuts
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $desktopShortcuts = @(
            "Serena MCP Server.lnk",
            "Serena Agent.lnk"
        )
        
        foreach ($shortcut in $desktopShortcuts) {
            $shortcutPath = Join-Path $desktopPath $shortcut
            if (Test-Path $shortcutPath) {
                Remove-Item -Path $shortcutPath -Force
                Write-Log "Removed desktop shortcut: $shortcut" -Level Success
            }
        }
        
        # Remove Start Menu entries
        $startMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Serena Agent"
        if (Test-Path $startMenuPath) {
            Remove-Item -Path $startMenuPath -Recurse -Force
            Write-Log "Removed Start Menu folder: Serena Agent" -Level Success
        }
        
        # Remove All Users Start Menu entries
        $allUsersStartMenu = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Serena Agent"
        if (Test-Path $allUsersStartMenu) {
            Remove-Item -Path $allUsersStartMenu -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed All Users Start Menu folder" -Level Success
        }
        
        Write-Log "Shortcuts cleanup completed" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to remove some shortcuts: $($_.Exception.Message)" -Level Warning
    }
}

function Remove-FirewallRules {
    Write-Progress-Log -Activity "Firewall Cleanup" -Status "Removing firewall rules..." -PercentComplete 70
    
    try {
        # Remove firewall rules
        $rules = Get-NetFirewallRule -DisplayName "Serena*" -ErrorAction SilentlyContinue
        if ($rules) {
            $rules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            Write-Log "Removed $($rules.Count) firewall rules" -Level Success
        } else {
            Write-Log "No Serena firewall rules found" -Level Info
        }
    }
    catch {
        Write-Log "WARNING: Failed to remove firewall rules: $($_.Exception.Message)" -Level Warning
    }
}

function Clean-PowerShellProfile {
    Write-Progress-Log -Activity "Profile Cleanup" -Status "Cleaning PowerShell profile..." -PercentComplete 80
    
    try {
        $profilePath = $PROFILE
        if (Test-Path $profilePath) {
            $content = Get-Content $profilePath -Raw
            if ($content -like "*Serena Agent Environment Setup*") {
                # Remove Serena section from profile
                $lines = Get-Content $profilePath
                $newLines = @()
                $skipSection = $false
                
                foreach ($line in $lines) {
                    if ($line -like "*Serena Agent Environment Setup*") {
                        $skipSection = $true
                        continue
                    }
                    
                    if ($skipSection -and ($line.Trim() -eq "" -and $newLines[-1].Trim() -eq "")) {
                        $skipSection = $false
                        continue
                    }
                    
                    if (-not $skipSection) {
                        $newLines += $line
                    }
                }
                
                Set-Content -Path $profilePath -Value $newLines
                Write-Log "Cleaned PowerShell profile" -Level Success
            }
        }
    }
    catch {
        Write-Log "WARNING: Failed to clean PowerShell profile: $($_.Exception.Message)" -Level Warning
    }
}

function Remove-WindowsTerminalProfile {
    Write-Progress-Log -Activity "Terminal Cleanup" -Status "Removing Windows Terminal profile..." -PercentComplete 85
    
    try {
        $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        
        if (Test-Path $settingsPath) {
            # Create backup
            $backupPath = "$settingsPath.uninstall-backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $settingsPath $backupPath
            
            # Read and modify settings
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            
            # Remove Serena profile
            $settings.profiles.list = $settings.profiles.list | Where-Object { $_.name -ne "Serena Agent" }
            
            # Save updated settings
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
            Write-Log "Removed Serena profile from Windows Terminal" -Level Success
        }
    }
    catch {
        Write-Log "WARNING: Failed to remove Windows Terminal profile: $($_.Exception.Message)" -Level Warning
    }
}

function Test-UninstallCompletion {
    Write-Progress-Log -Activity "Verification" -Status "Verifying uninstallation..." -PercentComplete 90
    
    $issues = @()
    
    # Check if directories still exist
    if (Test-Path $SerenaHome) {
        $issues += "Serena installation directory still exists: $SerenaHome"
    }
    
    if (Test-Path $SolidLspHome) {
        $issues += "SolidLSP directory still exists: $SolidLspHome"
    }
    
    # Check environment variables
    $serenaHomeEnv = [Environment]::GetEnvironmentVariable("SERENA_HOME", "Machine")
    if ($serenaHomeEnv) {
        $issues += "SERENA_HOME environment variable still set"
    }
    
    $solidLspHomeEnv = [Environment]::GetEnvironmentVariable("SOLIDLSP_HOME", "Machine")
    if ($solidLspHomeEnv) {
        $issues += "SOLIDLSP_HOME environment variable still set"
    }
    
    # Check PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    $venvScripts = Join-Path $VenvDir "Scripts"
    if ($currentPath -like "*$venvScripts*") {
        $issues += "Serena still in system PATH"
    }
    
    if ($issues.Count -gt 0) {
        Write-Log "Uninstallation completed with issues:" -Level Warning
        foreach ($issue in $issues) {
            Write-Log "  - $issue" -Level Warning
        }
        return $false
    } else {
        Write-Log "Uninstallation verification completed successfully" -Level Success
        return $true
    }
}

#endregion

#region Main Uninstall Flow

function Start-Uninstall {
    try {
        Initialize-Uninstall
        Stop-SerenaProcesses
        Remove-InstallationDirectories
        Remove-UserDataDirectories
        Remove-EnvironmentVariables
        Remove-RegistryEntries
        Remove-Shortcuts
        Remove-FirewallRules
        Clean-PowerShellProfile
        Remove-WindowsTerminalProfile
        
        $success = Test-UninstallCompletion
        
        Write-Progress-Log -Activity "Uninstallation" -Status "Uninstallation completed!" -PercentComplete 100
        
        Write-Log "=== Serena Agent Uninstallation Completed ===" -Level Success
        
        if (-not $Silent) {
            Write-Host ""
            if ($success) {
                Write-Host "===============================================" -ForegroundColor Green
                Write-Host "    Uninstallation Completed Successfully!" -ForegroundColor Green
                Write-Host "===============================================" -ForegroundColor Green
            } else {
                Write-Host "===============================================" -ForegroundColor Yellow
                Write-Host "    Uninstallation Completed with Issues!" -ForegroundColor Yellow
                Write-Host "===============================================" -ForegroundColor Yellow
            }
            Write-Host ""
            Write-Host "Serena Agent has been removed from your system." -ForegroundColor White
            Write-Host ""
            
            if ($KeepUserData) {
                Write-Host "User data has been preserved in:" -ForegroundColor White
                foreach ($userDir in $UserDataDirs) {
                    if (Test-Path $userDir) {
                        Write-Host "  $userDir" -ForegroundColor Gray
                    }
                }
                Write-Host ""
            }
            
            Write-Host "IMPORTANT: Please restart your PowerShell session" -ForegroundColor Yellow
            Write-Host "           to complete the environment cleanup." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Uninstall log: $LogFile" -ForegroundColor Gray
            Write-Host ""
            
            if (-not $success) {
                Write-Host "Some components could not be automatically removed." -ForegroundColor Yellow
                Write-Host "Please check the log file for details and remove them manually if needed." -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
    catch {
        Write-Log "Uninstallation failed: $($_.Exception.Message)" -Level Error
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "===============================================" -ForegroundColor Red
            Write-Host "    Uninstallation Failed!" -ForegroundColor Red
            Write-Host "===============================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Check the log file for details: $LogFile" -ForegroundColor Yellow
            Write-Host ""
        }
        
        exit 1
    }
    finally {
        if (-not $Silent) {
            Write-Progress -Activity "Uninstallation" -Completed
        }
    }
}

#endregion

# Check if running as Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Administrator privileges are required for uninstallation." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Start uninstallation
Start-Uninstall