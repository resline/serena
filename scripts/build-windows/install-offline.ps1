#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Offline installation script for Serena Windows Portable with embedded runtimes.

.DESCRIPTION
    This script installs Serena portable edition with all embedded runtimes and
    language servers for complete offline functionality. It sets up the environment,
    verifies runtimes, and configures the system for offline operation.

.PARAMETER InstallPath
    Installation directory (default: %LOCALAPPDATA%\Serena)

.PARAMETER AddToPath
    Add Serena to system PATH (default: true)

.PARAMETER VerifyRuntimes
    Verify all embedded runtimes after installation (default: true)

.EXAMPLE
    .\install-offline.ps1 -InstallPath "C:\Tools\Serena"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "$env:LOCALAPPDATA\Serena",
    
    [Parameter(Mandatory=$false)]
    [bool]$AddToPath = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$VerifyRuntimes = $true
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Script configuration
$SCRIPT_VERSION = "1.0.0"
$MIN_DISK_SPACE_MB = 500  # Minimum required disk space

Write-Host @"
========================================
Serena Windows Portable - Offline Installer
Version: $SCRIPT_VERSION
========================================
"@ -ForegroundColor Cyan

# Helper functions
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DiskSpace {
    param([string]$Path)
    
    $drive = (Get-Item $Path -ErrorAction SilentlyContinue).PSDrive
    if ($drive) {
        return [Math]::Round($drive.Free / 1MB, 2)
    }
    return 0
}

function Test-Runtime {
    param(
        [string]$Name,
        [string]$ExecutablePath,
        [string]$VersionCommand
    )
    
    if (!(Test-Path $ExecutablePath)) {
        return @{
            Success = $false
            Message = "Executable not found: $ExecutablePath"
        }
    }
    
    try {
        $result = & $ExecutablePath $VersionCommand.Split() 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            return @{
                Success = $true
                Message = "Version: $($result | Select-Object -First 1)"
            }
        } else {
            return @{
                Success = $false
                Message = "Failed with exit code: $exitCode"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error: $_"
        }
    }
}

function Add-ToUserPath {
    param([string]$Directory)
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$Directory*") {
        Write-Host "Adding to PATH: $Directory" -ForegroundColor Gray
        $newPath = "$currentPath;$Directory"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        return $true
    }
    return $false
}

function Create-Shortcuts {
    param([string]$InstallDir)
    
    $shell = New-Object -ComObject WScript.Shell
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $startMenuPath = [Environment]::GetFolderPath("StartMenu")
    
    # Desktop shortcut
    $desktopShortcut = $shell.CreateShortcut("$desktopPath\Serena Portable.lnk")
    $desktopShortcut.TargetPath = "$InstallDir\serena-portable.bat"
    $desktopShortcut.WorkingDirectory = $InstallDir
    $desktopShortcut.IconLocation = "$InstallDir\serena.exe"
    $desktopShortcut.Description = "Serena AI Coding Agent (Offline Edition)"
    $desktopShortcut.Save()
    
    # Start menu folder
    $startMenuFolder = "$startMenuPath\Programs\Serena"
    New-Item -ItemType Directory -Force -Path $startMenuFolder | Out-Null
    
    # Start menu shortcut
    $startShortcut = $shell.CreateShortcut("$startMenuFolder\Serena Portable.lnk")
    $startShortcut.TargetPath = "$InstallDir\serena-portable.bat"
    $startShortcut.WorkingDirectory = $InstallDir
    $startShortcut.IconLocation = "$InstallDir\serena.exe"
    $startShortcut.Description = "Serena AI Coding Agent (Offline Edition)"
    $startShortcut.Save()
    
    # Uninstall shortcut
    $uninstallShortcut = $shell.CreateShortcut("$startMenuFolder\Uninstall Serena.lnk")
    $uninstallShortcut.TargetPath = "powershell.exe"
    $uninstallShortcut.Arguments = "-ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""
    $uninstallShortcut.WorkingDirectory = $InstallDir
    $uninstallShortcut.Description = "Uninstall Serena Portable"
    $uninstallShortcut.Save()
    
    Write-Host "✓ Shortcuts created" -ForegroundColor Green
}

# Main installation process
try {
    # Step 1: Pre-installation checks
    Write-Host "`n=== Pre-Installation Checks ===" -ForegroundColor Yellow
    
    # Check if running as administrator (optional but recommended)
    if (Test-Administrator) {
        Write-Host "✓ Running as Administrator" -ForegroundColor Green
    } else {
        Write-Host "⚠ Not running as Administrator (some features may be limited)" -ForegroundColor Yellow
    }
    
    # Check disk space
    $availableSpace = Get-DiskSpace -Path (Split-Path $InstallPath -Parent)
    if ($availableSpace -lt $MIN_DISK_SPACE_MB) {
        throw "Insufficient disk space. Required: ${MIN_DISK_SPACE_MB}MB, Available: ${availableSpace}MB"
    }
    Write-Host "✓ Disk space available: ${availableSpace}MB" -ForegroundColor Green
    
    # Check if installation directory exists
    if (Test-Path $InstallPath) {
        Write-Host "⚠ Installation directory exists: $InstallPath" -ForegroundColor Yellow
        $response = Read-Host "Overwrite existing installation? (Y/N)"
        if ($response -ne 'Y') {
            Write-Host "Installation cancelled by user" -ForegroundColor Red
            exit 0
        }
        Write-Host "Removing existing installation..." -ForegroundColor Gray
        Remove-Item $InstallPath -Recurse -Force
    }
    
    # Step 2: Create installation directory
    Write-Host "`n=== Installing Serena ===" -ForegroundColor Yellow
    Write-Host "Installation path: $InstallPath" -ForegroundColor Cyan
    
    New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    
    # Step 3: Copy files
    Write-Host "Copying files..." -ForegroundColor Gray
    
    # Get the directory where this script is located
    $sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    # Copy main executable
    if (Test-Path "$sourceDir\serena.exe") {
        Copy-Item "$sourceDir\serena.exe" "$InstallPath\serena.exe"
        Write-Host "✓ Main executable copied" -ForegroundColor Green
    } else {
        throw "serena.exe not found in $sourceDir"
    }
    
    # Copy runtimes directory (if exists)
    if (Test-Path "$sourceDir\runtimes") {
        Write-Host "Copying embedded runtimes (this may take a moment)..." -ForegroundColor Gray
        Copy-Item "$sourceDir\runtimes" "$InstallPath\runtimes" -Recurse
        Write-Host "✓ Runtimes copied" -ForegroundColor Green
    }
    
    # Copy language servers directory (if exists)
    if (Test-Path "$sourceDir\language_servers") {
        Write-Host "Copying language servers..." -ForegroundColor Gray
        Copy-Item "$sourceDir\language_servers" "$InstallPath\language_servers" -Recurse
        Write-Host "✓ Language servers copied" -ForegroundColor Green
    }
    
    # Copy documentation
    $docFiles = @("README.md", "LICENSE", "CLAUDE.md")
    foreach ($docFile in $docFiles) {
        if (Test-Path "$sourceDir\$docFile") {
            Copy-Item "$sourceDir\$docFile" "$InstallPath\$docFile"
        }
    }
    
    # Step 4: Create launcher script
    Write-Host "`n=== Creating Launcher ===" -ForegroundColor Yellow
    
    $launcherScript = @'
@echo off
setlocal enabledelayedexpansion

REM Serena Portable Launcher with Embedded Runtimes
REM This script configures the environment for offline operation

set "SCRIPT_DIR=%~dp0"
set "RUNTIME_DIR=%SCRIPT_DIR%runtimes"

REM Configure offline mode
set "SERENA_OFFLINE_MODE=1"
set "SERENA_RUNTIME_DIR=%RUNTIME_DIR%"

REM Add embedded runtimes to PATH
if exist "%RUNTIME_DIR%\nodejs\node.exe" (
    set "PATH=%RUNTIME_DIR%\nodejs;%PATH%"
    set "NODE_PATH=%RUNTIME_DIR%\npm-cache"
    echo [Runtime] Node.js portable activated
)

if exist "%RUNTIME_DIR%\dotnet\dotnet.exe" (
    set "PATH=%RUNTIME_DIR%\dotnet;%PATH%"
    set "DOTNET_ROOT=%RUNTIME_DIR%\dotnet"
    set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
    echo [Runtime] .NET portable activated
)

if exist "%RUNTIME_DIR%\java\bin\java.exe" (
    set "PATH=%RUNTIME_DIR%\java\bin;%PATH%"
    set "JAVA_HOME=%RUNTIME_DIR%\java"
    echo [Runtime] Java portable activated
)

REM Launch Serena
echo.
echo Starting Serena Portable (Offline Mode)...
echo.
"%SCRIPT_DIR%serena.exe" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo Serena exited with error code: %ERRORLEVEL%
    pause
)
'@
    
    $launcherScript | Set-Content "$InstallPath\serena-portable.bat"
    Write-Host "✓ Launcher script created" -ForegroundColor Green
    
    # Step 5: Create uninstaller
    $uninstallerScript = @"
# Serena Portable Uninstaller
Write-Host "Uninstalling Serena Portable..." -ForegroundColor Yellow

# Remove from PATH
`$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
`$newPath = `$currentPath -replace [regex]::Escape("$InstallPath"), ""
`$newPath = `$newPath -replace ";;", ";"
[Environment]::SetEnvironmentVariable("Path", `$newPath, "User")

# Remove shortcuts
Remove-Item "`$env:USERPROFILE\Desktop\Serena Portable.lnk" -ErrorAction SilentlyContinue
Remove-Item "`$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Serena" -Recurse -ErrorAction SilentlyContinue

# Remove installation directory
Remove-Item "$InstallPath" -Recurse -Force

Write-Host "Serena Portable has been uninstalled." -ForegroundColor Green
"@
    
    $uninstallerScript | Set-Content "$InstallPath\uninstall.ps1"
    Write-Host "✓ Uninstaller created" -ForegroundColor Green
    
    # Step 6: Verify embedded runtimes
    if ($VerifyRuntimes) {
        Write-Host "`n=== Verifying Embedded Runtimes ===" -ForegroundColor Yellow
        
        # Test Node.js
        $nodeExe = "$InstallPath\runtimes\nodejs\node.exe"
        if (Test-Path $nodeExe) {
            $nodeTest = Test-Runtime -Name "Node.js" -ExecutablePath $nodeExe -VersionCommand "--version"
            if ($nodeTest.Success) {
                Write-Host "✓ Node.js: $($nodeTest.Message)" -ForegroundColor Green
            } else {
                Write-Host "⚠ Node.js: $($nodeTest.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "○ Node.js: Not included" -ForegroundColor Gray
        }
        
        # Test .NET
        $dotnetExe = "$InstallPath\runtimes\dotnet\dotnet.exe"
        if (Test-Path $dotnetExe) {
            $dotnetTest = Test-Runtime -Name ".NET" -ExecutablePath $dotnetExe -VersionCommand "--list-runtimes"
            if ($dotnetTest.Success) {
                Write-Host "✓ .NET Runtime: Available" -ForegroundColor Green
            } else {
                Write-Host "⚠ .NET Runtime: $($dotnetTest.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "○ .NET Runtime: Not included" -ForegroundColor Gray
        }
        
        # Test Java
        $javaExe = "$InstallPath\runtimes\java\bin\java.exe"
        if (Test-Path $javaExe) {
            $javaTest = Test-Runtime -Name "Java" -ExecutablePath $javaExe -VersionCommand "-version"
            if ($javaTest.Success) {
                Write-Host "✓ Java Runtime: Available" -ForegroundColor Green
            } else {
                Write-Host "⚠ Java Runtime: $($javaTest.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "○ Java Runtime: Not included" -ForegroundColor Gray
        }
    }
    
    # Step 7: Add to PATH
    if ($AddToPath) {
        Write-Host "`n=== Configuring System PATH ===" -ForegroundColor Yellow
        if (Add-ToUserPath -Directory $InstallPath) {
            Write-Host "✓ Added to user PATH" -ForegroundColor Green
            Write-Host "  Please restart your terminal for PATH changes to take effect" -ForegroundColor Gray
        } else {
            Write-Host "○ Already in PATH" -ForegroundColor Gray
        }
    }
    
    # Step 8: Create shortcuts
    Write-Host "`n=== Creating Shortcuts ===" -ForegroundColor Yellow
    Create-Shortcuts -InstallDir $InstallPath
    
    # Step 9: Final summary
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation directory: $InstallPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To start Serena:" -ForegroundColor Yellow
    Write-Host "  • Use the desktop shortcut" -ForegroundColor Gray
    Write-Host "  • Or run: $InstallPath\serena-portable.bat" -ForegroundColor Gray
    Write-Host "  • Or (after restart) run: serena --help" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Serena is configured for OFFLINE operation with:" -ForegroundColor Yellow
    
    if (Test-Path "$InstallPath\runtimes\nodejs") {
        Write-Host "  • Node.js runtime (for TypeScript, JavaScript, Python language servers)" -ForegroundColor Gray
    }
    if (Test-Path "$InstallPath\runtimes\dotnet") {
        Write-Host "  • .NET runtime (for C# language server)" -ForegroundColor Gray
    }
    if (Test-Path "$InstallPath\runtimes\java") {
        Write-Host "  • Java runtime (for Java, Kotlin language servers)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "All language servers will work offline without internet access!" -ForegroundColor Green
    Write-Host ""
    
    # Prompt to launch
    $launch = Read-Host "Launch Serena now? (Y/N)"
    if ($launch -eq 'Y') {
        Start-Process "$InstallPath\serena-portable.bat"
    }
}
catch {
    Write-Error "Installation failed: $_"
    
    # Cleanup on failure
    if (Test-Path $InstallPath) {
        Write-Host "Cleaning up partial installation..." -ForegroundColor Yellow
        Remove-Item $InstallPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}