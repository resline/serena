#Requires -Version 5.1
<#
.SYNOPSIS
    Serena Agent - PowerShell Installer for Windows

.DESCRIPTION
    This PowerShell script provides a comprehensive installation of Serena Agent with:
    - Enhanced error handling and logging
    - Progress bars for extraction/installation
    - Verification of installations
    - Option to install runtime dependencies
    - System requirements check (Windows version, architecture)
    - Rollback capability on failure
    - Support for silent/unattended installation
    - Creates Start Menu entries

.PARAMETER Silent
    Run installation without user interaction

.PARAMETER SkipDependencies
    Skip installation of runtime dependencies

.PARAMETER InstallPath
    Custom installation path (default: $env:USERPROFILE\Serena)

.PARAMETER LogLevel
    Logging level: Info, Warning, Error (default: Info)

.EXAMPLE
    .\install.ps1
    Interactive installation with all features

.EXAMPLE
    .\install.ps1 -Silent
    Silent installation with default settings

.EXAMPLE
    .\install.ps1 -InstallPath "C:\Tools\Serena" -LogLevel Warning
    Custom installation path with warning-level logging
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Silent,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDependencies,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "$env:USERPROFILE\Serena",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Info", "Warning", "Error")]
    [string]$LogLevel = "Info"
)

# Set strict error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Script variables
$ScriptDir = $PSScriptRoot
$LogFile = Join-Path $ScriptDir "install.log"
$PythonDir = Join-Path $InstallPath "python"
$VenvDir = Join-Path $InstallPath "venv"
$SolidLspDir = Join-Path $env:USERPROFILE ".solidlsp"
$WheelsDir = Join-Path $ScriptDir "wheels"
$LanguageServersDir = Join-Path $ScriptDir "language_servers"
$PythonZip = Join-Path $ScriptDir "python-embeddable.zip"

# Global variables for rollback
$script:CreatedPaths = @()
$script:ModifiedRegistry = @()
$script:OriginalPath = $env:PATH

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
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    
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

#region System Check Functions

function Test-SystemRequirements {
    Write-Progress-Log -Activity "System Check" -Status "Checking system requirements..."
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        throw "PowerShell 5.1 or later is required. Current version: $psVersion"
    }
    Write-Log "PowerShell version: $psVersion" -Level Info
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Log "WARNING: Windows 10 or later is recommended. Current version: $osVersion" -Level Warning
    } else {
        Write-Log "Windows version: $osVersion" -Level Info
    }
    
    # Check architecture
    $architecture = $env:PROCESSOR_ARCHITECTURE
    if ($architecture -notin @("AMD64", "ARM64")) {
        throw "Unsupported architecture: $architecture. Only x64 and ARM64 are supported."
    }
    Write-Log "Architecture: $architecture" -Level Info
    
    # Check available disk space (require at least 2GB)
    $installDrive = Split-Path $InstallPath -Qualifier
    $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $installDrive }
    $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    
    if ($freeSpaceGB -lt 2) {
        throw "Insufficient disk space. Available: ${freeSpaceGB}GB, Required: 2GB"
    }
    Write-Log "Available disk space: ${freeSpaceGB}GB" -Level Info
    
    # Check if running as Administrator
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "Administrator privileges are required for installation. Please run PowerShell as Administrator."
    }
    Write-Log "Administrator privileges confirmed" -Level Info
}

function Test-RequiredFiles {
    Write-Progress-Log -Activity "File Check" -Status "Verifying required files..."
    
    $requiredFiles = @(
        @{ Path = $PythonZip; Name = "Python embeddable package" },
        @{ Path = $WheelsDir; Name = "Wheels directory" }
    )
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file.Path)) {
            throw "$($file.Name) not found: $($file.Path)"
        }
        Write-Log "$($file.Name) found: $($file.Path)" -Level Info
    }
    
    # Check if wheels directory contains .whl files
    $wheelFiles = Get-ChildItem -Path $WheelsDir -Filter "*.whl" -ErrorAction SilentlyContinue
    if ($wheelFiles.Count -eq 0) {
        throw "No wheel files found in: $WheelsDir"
    }
    Write-Log "Found $($wheelFiles.Count) wheel files" -Level Info
}

#endregion

#region Installation Functions

function Initialize-Installation {
    Write-Progress-Log -Activity "Initialization" -Status "Initializing installation..."
    
    # Create log file
    if (Test-Path $LogFile) {
        Remove-Item $LogFile -Force
    }
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
    
    Write-Log "=== Serena Agent Installation Started ===" -Level Info
    Write-Log "Script directory: $ScriptDir" -Level Info
    Write-Log "Installation directory: $InstallPath" -Level Info
    Write-Log "Log file: $LogFile" -Level Info
    Write-Log "Silent mode: $Silent" -Level Info
    Write-Log "Skip dependencies: $SkipDependencies" -Level Info
    Write-Log "Log level: $LogLevel" -Level Info
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host "    Serena Agent - PowerShell Installation" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Installation directory: $InstallPath" -ForegroundColor White
        Write-Host "Log file: $LogFile" -ForegroundColor White
        Write-Host ""
        
        if (-not $Silent) {
            $response = Read-Host "Continue with installation? (y/N)"
            if ($response -notmatch '^[Yy]') {
                Write-Log "Installation cancelled by user" -Level Info
                exit 0
            }
        }
    }
}

function Remove-ExistingInstallation {
    if (Test-Path $InstallPath) {
        Write-Progress-Log -Activity "Cleanup" -Status "Removing existing installation..."
        Write-Log "Removing existing installation: $InstallPath" -Level Warning
        
        try {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-Log "Existing installation removed successfully" -Level Info
        }
        catch {
            Write-Log "Failed to remove existing installation: $($_.Exception.Message)" -Level Error
            throw "Failed to remove existing installation. Please remove manually: $InstallPath"
        }
    }
}

function New-InstallationDirectory {
    Write-Progress-Log -Activity "Directory Setup" -Status "Creating installation directory..."
    
    try {
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
        $script:CreatedPaths += $InstallPath
        Write-Log "Installation directory created: $InstallPath" -Level Success
    }
    catch {
        throw "Failed to create installation directory: $($_.Exception.Message)"
    }
}

function Install-PythonEmbeddable {
    Write-Progress-Log -Activity "Python Setup" -Status "Extracting Python embeddable package..." -PercentComplete 10
    
    try {
        # Extract Python embeddable package
        Expand-Archive -Path $PythonZip -DestinationPath $PythonDir -Force
        $script:CreatedPaths += $PythonDir
        Write-Log "Python embeddable package extracted successfully" -Level Success
        
        # Enable site packages
        $pthFile = Join-Path $PythonDir "python311._pth"
        if (Test-Path $pthFile) {
            Write-Progress-Log -Activity "Python Setup" -Status "Configuring Python embeddable..." -PercentComplete 20
            
            $content = Get-Content $pthFile
            $newContent = $content -replace '^#import site', 'import site'
            Set-Content -Path $pthFile -Value $newContent
            Write-Log "Python site packages enabled" -Level Info
        }
        
        # Install pip
        Write-Progress-Log -Activity "Python Setup" -Status "Installing pip..." -PercentComplete 30
        
        $pythonExe = Join-Path $PythonDir "python.exe"
        
        try {
            & $pythonExe -m ensurepip --upgrade 2>&1 | Out-String | Write-Log -Level Info
        }
        catch {
            Write-Log "ensurepip failed, trying get-pip.py..." -Level Warning
            
            $getPipPath = Join-Path $PythonDir "get-pip.py"
            Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPipPath
            & $pythonExe $getPipPath 2>&1 | Out-String | Write-Log -Level Info
        }
        
        Write-Log "Pip installation completed" -Level Success
    }
    catch {
        throw "Failed to install Python embeddable: $($_.Exception.Message)"
    }
}

function New-VirtualEnvironment {
    Write-Progress-Log -Activity "Virtual Environment" -Status "Creating virtual environment..." -PercentComplete 40
    
    try {
        $pythonExe = Join-Path $PythonDir "python.exe"
        & $pythonExe -m venv $VenvDir 2>&1 | Out-String | Write-Log -Level Info
        
        if (-not (Test-Path (Join-Path $VenvDir "Scripts\python.exe"))) {
            throw "Virtual environment creation failed"
        }
        
        $script:CreatedPaths += $VenvDir
        Write-Log "Virtual environment created successfully" -Level Success
        
        # Upgrade pip in virtual environment
        Write-Progress-Log -Activity "Virtual Environment" -Status "Upgrading pip..." -PercentComplete 45
        
        $venvPython = Join-Path $VenvDir "Scripts\python.exe"
        & $venvPython -m pip install --upgrade pip setuptools wheel 2>&1 | Out-String | Write-Log -Level Info
        
        Write-Log "Pip upgraded in virtual environment" -Level Success
    }
    catch {
        throw "Failed to create virtual environment: $($_.Exception.Message)"
    }
}

function Install-Wheels {
    Write-Progress-Log -Activity "Package Installation" -Status "Installing Serena Agent and dependencies..." -PercentComplete 50
    
    try {
        $venvPip = Join-Path $VenvDir "Scripts\pip.exe"
        $wheelFiles = Get-ChildItem -Path $WheelsDir -Filter "*.whl"
        
        $totalWheels = $wheelFiles.Count
        $currentWheel = 0
        
        foreach ($wheel in $wheelFiles) {
            $currentWheel++
            $percent = 50 + [int](($currentWheel / $totalWheels) * 30)
            
            Write-Progress-Log -Activity "Package Installation" -Status "Installing wheel $currentWheel/$totalWheels`: $($wheel.Name)" -PercentComplete $percent
            
            try {
                & $venvPip install $wheel.FullName --no-deps --force-reinstall 2>&1 | Out-String | Write-Log -Level Info
                Write-Log "Successfully installed: $($wheel.Name)" -Level Success
            }
            catch {
                Write-Log "WARNING: Failed to install wheel: $($wheel.Name) - $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Install any remaining dependencies
        Write-Progress-Log -Activity "Package Installation" -Status "Installing remaining dependencies..." -PercentComplete 80
        
        & $venvPip install --upgrade setuptools wheel 2>&1 | Out-String | Write-Log -Level Info
        
        Write-Log "Package installation completed" -Level Success
    }
    catch {
        throw "Failed to install packages: $($_.Exception.Message)"
    }
}

function Install-LanguageServers {
    if (Test-Path $LanguageServersDir) {
        Write-Progress-Log -Activity "Language Servers" -Status "Installing language servers..." -PercentComplete 85
        
        try {
            if (-not (Test-Path $SolidLspDir)) {
                New-Item -Path $SolidLspDir -ItemType Directory -Force | Out-Null
                $script:CreatedPaths += $SolidLspDir
            }
            
            Copy-Item -Path "$LanguageServersDir\*" -Destination $SolidLspDir -Recurse -Force
            Write-Log "Language servers installed successfully" -Level Success
        }
        catch {
            Write-Log "WARNING: Failed to install language servers: $($_.Exception.Message)" -Level Warning
        }
    }
    else {
        Write-Log "Language servers directory not found, skipping..." -Level Warning
    }
}

function Set-EnvironmentVariables {
    Write-Progress-Log -Activity "Environment Setup" -Status "Setting up environment variables..." -PercentComplete 90
    
    try {
        # Add Serena to system PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        $venvScripts = Join-Path $VenvDir "Scripts"
        
        if ($currentPath -notlike "*$venvScripts*") {
            $newPath = "$currentPath;$venvScripts"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-Log "Added Serena to system PATH" -Level Success
        }
        
        # Set SERENA_HOME
        [Environment]::SetEnvironmentVariable("SERENA_HOME", $InstallPath, "Machine")
        Write-Log "Set SERENA_HOME to: $InstallPath" -Level Info
        
        # Set SOLIDLSP_HOME
        [Environment]::SetEnvironmentVariable("SOLIDLSP_HOME", $SolidLspDir, "Machine")
        Write-Log "Set SOLIDLSP_HOME to: $SolidLspDir" -Level Info
        
        Write-Log "Environment variables configured successfully" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to set some environment variables: $($_.Exception.Message)" -Level Warning
    }
}

function New-Shortcuts {
    Write-Progress-Log -Activity "Shortcuts" -Status "Creating shortcuts and menu entries..." -PercentComplete 95
    
    try {
        # Create desktop shortcut
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "Serena MCP Server.lnk"
        $targetPath = Join-Path $VenvDir "Scripts\serena-mcp-server.exe"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetPath
        $shortcut.WorkingDirectory = Join-Path $VenvDir "Scripts"
        $shortcut.Description = "Serena MCP Server"
        $shortcut.Save()
        
        Write-Log "Desktop shortcut created: $shortcutPath" -Level Success
        
        # Create Start Menu entry
        $startMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Serena Agent"
        if (-not (Test-Path $startMenuPath)) {
            New-Item -Path $startMenuPath -ItemType Directory -Force | Out-Null
        }
        
        $startMenuShortcut = Join-Path $startMenuPath "Serena MCP Server.lnk"
        $startMenuLink = $shell.CreateShortcut($startMenuShortcut)
        $startMenuLink.TargetPath = $targetPath
        $startMenuLink.WorkingDirectory = Join-Path $VenvDir "Scripts"
        $startMenuLink.Description = "Serena MCP Server"
        $startMenuLink.Save()
        
        Write-Log "Start Menu entry created: $startMenuShortcut" -Level Success
        
        # Create uninstaller shortcut
        $uninstallShortcut = Join-Path $startMenuPath "Uninstall Serena Agent.lnk"
        $uninstallLink = $shell.CreateShortcut($uninstallShortcut)
        $uninstallLink.TargetPath = "powershell.exe"
        $uninstallLink.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptDir\uninstall.ps1`""
        $uninstallLink.WorkingDirectory = $ScriptDir
        $uninstallLink.Description = "Uninstall Serena Agent"
        $uninstallLink.Save()
        
        Write-Log "Uninstaller shortcut created: $uninstallShortcut" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to create some shortcuts: $($_.Exception.Message)" -Level Warning
    }
}

#endregion

#region Verification and Rollback Functions

function Test-Installation {
    Write-Progress-Log -Activity "Verification" -Status "Verifying installation..." -PercentComplete 98
    
    try {
        $venvPython = Join-Path $VenvDir "Scripts\python.exe"
        
        # Test Python import
        $importResult = & $venvPython -c "import serena; print('Serena Agent installed successfully')" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to import Serena module: $importResult"
        }
        Write-Log "Serena module import successful" -Level Success
        
        # Test serena command
        $serenaExe = Join-Path $VenvDir "Scripts\serena.exe"
        if (Test-Path $serenaExe) {
            & $serenaExe --help 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Serena command test successful" -Level Success
            } else {
                Write-Log "WARNING: Serena command test failed" -Level Warning
            }
        }
        
        # Test MCP server command
        $mcpServerExe = Join-Path $VenvDir "Scripts\serena-mcp-server.exe"
        if (Test-Path $mcpServerExe) {
            Write-Log "MCP server executable found" -Level Success
        } else {
            Write-Log "WARNING: MCP server executable not found" -Level Warning
        }
        
        Write-Log "Installation verification completed successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Installation verification failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Invoke-Rollback {
    Write-Log "=== PERFORMING ROLLBACK ===" -Level Error
    
    try {
        # Remove created paths
        foreach ($path in $script:CreatedPaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed: $path" -Level Info
            }
        }
        
        # Restore original PATH
        [Environment]::SetEnvironmentVariable("PATH", $script:OriginalPath, "Machine")
        
        # Remove environment variables
        [Environment]::SetEnvironmentVariable("SERENA_HOME", $null, "Machine")
        [Environment]::SetEnvironmentVariable("SOLIDLSP_HOME", $null, "Machine")
        
        Write-Log "Rollback completed" -Level Info
    }
    catch {
        Write-Log "Rollback failed: $($_.Exception.Message)" -Level Error
    }
}

#endregion

#region Main Installation Flow

function Start-Installation {
    try {
        Initialize-Installation
        Test-SystemRequirements
        Test-RequiredFiles
        Remove-ExistingInstallation
        New-InstallationDirectory
        Install-PythonEmbeddable
        New-VirtualEnvironment
        Install-Wheels
        Install-LanguageServers
        Set-EnvironmentVariables
        New-Shortcuts
        
        if (Test-Installation) {
            Write-Progress-Log -Activity "Installation" -Status "Installation completed successfully!" -PercentComplete 100
            
            Write-Log "=== Installation Completed Successfully ===" -Level Success
            
            if (-not $Silent) {
                Write-Host ""
                Write-Host "===============================================" -ForegroundColor Green
                Write-Host "    Installation Completed Successfully!" -ForegroundColor Green
                Write-Host "===============================================" -ForegroundColor Green
                Write-Host ""
                Write-Host "Serena Agent has been installed to: $InstallPath" -ForegroundColor White
                Write-Host ""
                Write-Host "Environment Variables Set:" -ForegroundColor White
                Write-Host "  SERENA_HOME=$InstallPath" -ForegroundColor Gray
                Write-Host "  SOLIDLSP_HOME=$SolidLspDir" -ForegroundColor Gray
                Write-Host "  PATH updated to include Serena commands" -ForegroundColor Gray
                Write-Host ""
                Write-Host "Available Commands:" -ForegroundColor White
                Write-Host "  serena                - Main Serena CLI" -ForegroundColor Gray
                Write-Host "  serena-mcp-server     - Start MCP server" -ForegroundColor Gray
                Write-Host "  index-project         - Index project for faster performance" -ForegroundColor Gray
                Write-Host ""
                Write-Host "Desktop shortcuts and Start Menu entries have been created." -ForegroundColor White
                Write-Host ""
                Write-Host "IMPORTANT: Please restart your PowerShell session" -ForegroundColor Yellow
                Write-Host "           to use the updated PATH environment variable." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Installation log: $LogFile" -ForegroundColor Gray
                Write-Host ""
            }
        } else {
            throw "Installation verification failed"
        }
    }
    catch {
        Write-Log "Installation failed: $($_.Exception.Message)" -Level Error
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "===============================================" -ForegroundColor Red
            Write-Host "    Installation Failed!" -ForegroundColor Red
            Write-Host "===============================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "Check the log file for details: $LogFile" -ForegroundColor Yellow
            Write-Host ""
            
            $response = Read-Host "Perform rollback to clean up partial installation? (Y/n)"
            if ($response -notmatch '^[Nn]') {
                Invoke-Rollback
            }
        } else {
            Invoke-Rollback
        }
        
        exit 1
    }
    finally {
        if (-not $Silent) {
            Write-Progress -Activity "Installation" -Completed
        }
    }
}

#endregion

# Start installation
Start-Installation