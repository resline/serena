#Requires -Version 5.1
<#
.SYNOPSIS
    Serena Agent - Environment Setup Script for Windows

.DESCRIPTION
    This PowerShell script configures the Windows environment for Serena Agent:
    - Configures PATH variables
    - Sets SERENA_HOME, SOLIDLSP_HOME
    - Configures language-specific variables (JAVA_HOME, etc.)
    - Creates file associations
    - Sets up Windows Terminal integration
    - Configures firewall rules for MCP server

.PARAMETER SerenaHome
    Path to Serena installation directory

.PARAMETER SolidLspHome
    Path to SolidLSP directory (default: $env:USERPROFILE\.solidlsp)

.PARAMETER ConfigureFirewall
    Configure Windows Firewall rules for MCP server

.PARAMETER SetupFileAssociations
    Create file associations for supported languages

.PARAMETER SetupTerminalIntegration
    Configure Windows Terminal integration

.PARAMETER Silent
    Run without user interaction

.EXAMPLE
    .\setup_environment.ps1
    Interactive environment setup

.EXAMPLE
    .\setup_environment.ps1 -SerenaHome "C:\Tools\Serena" -Silent
    Silent environment setup with custom Serena path

.EXAMPLE
    .\setup_environment.ps1 -ConfigureFirewall -SetupFileAssociations -SetupTerminalIntegration
    Full environment setup with all optional features
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SerenaHome = "$env:USERPROFILE\Serena",
    
    [Parameter(Mandatory=$false)]
    [string]$SolidLspHome = "$env:USERPROFILE\.solidlsp",
    
    [Parameter(Mandatory=$false)]
    [switch]$ConfigureFirewall,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupFileAssociations,
    
    [Parameter(Mandatory=$false)]
    [switch]$SetupTerminalIntegration,
    
    [Parameter(Mandatory=$false)]
    [switch]$Silent
)

# Set strict error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Script variables
$ScriptDir = $PSScriptRoot
$LogFile = Join-Path $ScriptDir "environment_setup.log"
$VenvDir = Join-Path $SerenaHome "venv"

# Language-specific configurations
$LanguageConfigs = @{
    Java = @{
        EnvVars = @("JAVA_HOME")
        Extensions = @(".java", ".jar", ".class")
        Executables = @("java.exe", "javac.exe")
    }
    Node = @{
        EnvVars = @("NODE_HOME", "NPM_CONFIG_PREFIX")
        Extensions = @(".js", ".ts", ".jsx", ".tsx", ".json")
        Executables = @("node.exe", "npm.exe", "npx.exe")
    }
    Go = @{
        EnvVars = @("GOPATH", "GOROOT")
        Extensions = @(".go", ".mod", ".sum")
        Executables = @("go.exe")
    }
    Rust = @{
        EnvVars = @("CARGO_HOME", "RUSTUP_HOME")
        Extensions = @(".rs", ".toml")
        Executables = @("rustc.exe", "cargo.exe")
    }
    Python = @{
        EnvVars = @("PYTHONPATH", "PYTHON_HOME")
        Extensions = @(".py", ".pyw", ".pyi", ".pyc", ".pyo")
        Executables = @("python.exe", "pip.exe")
    }
    Ruby = @{
        EnvVars = @("RUBY_HOME", "GEM_HOME")
        Extensions = @(".rb", ".rake", ".gemspec")
        Executables = @("ruby.exe", "gem.exe")
    }
    PHP = @{
        EnvVars = @("PHP_HOME")
        Extensions = @(".php", ".phtml", ".php3", ".php4", ".php5")
        Executables = @("php.exe", "composer.exe")
    }
    CSharp = @{
        EnvVars = @("DOTNET_ROOT")
        Extensions = @(".cs", ".csx", ".vb", ".fs", ".fsx")
        Executables = @("dotnet.exe", "csc.exe")
    }
}

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
    
    if (-not $Silent) {
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

#region Environment Setup Functions

function Test-Installation {
    Write-Progress-Log -Activity "Verification" -Status "Verifying Serena installation..."
    
    if (-not (Test-Path $SerenaHome)) {
        throw "Serena installation not found: $SerenaHome"
    }
    
    if (-not (Test-Path $VenvDir)) {
        throw "Serena virtual environment not found: $VenvDir"
    }
    
    $serenaExe = Join-Path $VenvDir "Scripts\serena.exe"
    if (-not (Test-Path $serenaExe)) {
        throw "Serena executable not found: $serenaExe"
    }
    
    Write-Log "Serena installation verified" -Level Success
}

function Set-CoreEnvironmentVariables {
    Write-Progress-Log -Activity "Environment Variables" -Status "Setting core environment variables..." -PercentComplete 10
    
    try {
        # Set SERENA_HOME
        [Environment]::SetEnvironmentVariable("SERENA_HOME", $SerenaHome, "Machine")
        Write-Log "Set SERENA_HOME to: $SerenaHome" -Level Success
        
        # Set SOLIDLSP_HOME
        [Environment]::SetEnvironmentVariable("SOLIDLSP_HOME", $SolidLspHome, "Machine")
        Write-Log "Set SOLIDLSP_HOME to: $SolidLspHome" -Level Success
        
        # Update PATH to include Serena scripts
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        $venvScripts = Join-Path $VenvDir "Scripts"
        
        if ($currentPath -notlike "*$venvScripts*") {
            $newPath = "$currentPath;$venvScripts"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-Log "Added Serena to system PATH: $venvScripts" -Level Success
        } else {
            Write-Log "Serena already in system PATH" -Level Info
        }
        
        # Set additional Serena-specific variables
        [Environment]::SetEnvironmentVariable("SERENA_CONFIG_DIR", "$env:USERPROFILE\.serena", "User")
        [Environment]::SetEnvironmentVariable("SERENA_LOG_LEVEL", "INFO", "User")
        [Environment]::SetEnvironmentVariable("SERENA_CACHE_DIR", "$env:LOCALAPPDATA\Serena\Cache", "User")
        
        Write-Log "Core environment variables configured successfully" -Level Success
    }
    catch {
        throw "Failed to set core environment variables: $($_.Exception.Message)"
    }
}

function Find-LanguageInstallation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Language,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $found = @{}
    
    foreach ($executable in $Config.Executables) {
        $path = Get-Command $executable -ErrorAction SilentlyContinue
        if ($path) {
            $found[$executable] = $path.Source
            
            # Try to determine home directory
            $homeDir = Split-Path (Split-Path $path.Source -Parent) -Parent
            if (Test-Path $homeDir) {
                $found["${Language}_HOME"] = $homeDir
            }
        }
    }
    
    return $found
}

function Set-LanguageEnvironmentVariables {
    Write-Progress-Log -Activity "Language Environment" -Status "Configuring language-specific environment variables..." -PercentComplete 30
    
    $detectedLanguages = @{}
    
    foreach ($language in $LanguageConfigs.Keys) {
        $config = $LanguageConfigs[$language]
        $found = Find-LanguageInstallation -Language $language -Config $config
        
        if ($found.Count -gt 0) {
            $detectedLanguages[$language] = $found
            Write-Log "Detected $language installation" -Level Success
            
            # Set environment variables for detected languages
            foreach ($envVar in $config.EnvVars) {
                $homeKey = "${language}_HOME"
                if ($found.ContainsKey($homeKey)) {
                    $currentValue = [Environment]::GetEnvironmentVariable($envVar, "User")
                    if (-not $currentValue) {
                        [Environment]::SetEnvironmentVariable($envVar, $found[$homeKey], "User")
                        Write-Log "Set $envVar to: $($found[$homeKey])" -Level Info
                    }
                }
            }
        }
    }
    
    if ($detectedLanguages.Count -eq 0) {
        Write-Log "No language installations detected" -Level Warning
    } else {
        Write-Log "Configured environment variables for $($detectedLanguages.Count) languages" -Level Success
    }
}

function Set-FileAssociations {
    if (-not $SetupFileAssociations) {
        Write-Log "Skipping file associations setup" -Level Info
        return
    }
    
    Write-Progress-Log -Activity "File Associations" -Status "Setting up file associations..." -PercentComplete 50
    
    try {
        # Create Serena file association
        $serenaExe = Join-Path $VenvDir "Scripts\serena.exe"
        
        # Register Serena as a program
        $progId = "Serena.Agent"
        
        # Create registry entries
        New-Item -Path "HKCR:\$progId" -Force | Out-Null
        Set-ItemProperty -Path "HKCR:\$progId" -Name "(Default)" -Value "Serena Agent Project"
        
        New-Item -Path "HKCR:\$progId\DefaultIcon" -Force | Out-Null
        Set-ItemProperty -Path "HKCR:\$progId\DefaultIcon" -Name "(Default)" -Value "$serenaExe,0"
        
        New-Item -Path "HKCR:\$progId\shell" -Force | Out-Null
        New-Item -Path "HKCR:\$progId\shell\open" -Force | Out-Null
        New-Item -Path "HKCR:\$progId\shell\open\command" -Force | Out-Null
        Set-ItemProperty -Path "HKCR:\$progId\shell\open\command" -Name "(Default)" -Value "`"$serenaExe`" `"%1`""
        
        # Associate with .serena files
        New-Item -Path "HKCR:\.serena" -Force | Out-Null
        Set-ItemProperty -Path "HKCR:\.serena" -Name "(Default)" -Value $progId
        
        Write-Log "File associations configured successfully" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to set up file associations: $($_.Exception.Message)" -Level Warning
    }
}

function Set-WindowsTerminalIntegration {
    if (-not $SetupTerminalIntegration) {
        Write-Log "Skipping Windows Terminal integration setup" -Level Info
        return
    }
    
    Write-Progress-Log -Activity "Terminal Integration" -Status "Setting up Windows Terminal integration..." -PercentComplete 70
    
    try {
        # Check if Windows Terminal is installed
        $terminalPath = Get-Command "wt.exe" -ErrorAction SilentlyContinue
        if (-not $terminalPath) {
            Write-Log "Windows Terminal not found, skipping integration" -Level Warning
            return
        }
        
        # Get Windows Terminal settings path
        $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        
        if (-not (Test-Path $settingsPath)) {
            Write-Log "Windows Terminal settings not found, skipping integration" -Level Warning
            return
        }
        
        # Create backup of settings
        $backupPath = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $settingsPath $backupPath
        Write-Log "Created settings backup: $backupPath" -Level Info
        
        # Read current settings
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        # Add Serena profile
        $serenaProfile = @{
            "guid" = "{$(New-Guid)}"
            "name" = "Serena Agent"
            "commandline" = "cmd.exe /k `"$VenvDir\Scripts\activate.bat`""
            "startingDirectory" = "%USERPROFILE%"
            "icon" = "$VenvDir\Scripts\serena.exe"
            "colorScheme" = "Campbell"
        }
        
        # Check if profile already exists
        $existingProfile = $settings.profiles.list | Where-Object { $_.name -eq "Serena Agent" }
        if (-not $existingProfile) {
            $settings.profiles.list += $serenaProfile
            
            # Save updated settings
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
            Write-Log "Added Serena profile to Windows Terminal" -Level Success
        } else {
            Write-Log "Serena profile already exists in Windows Terminal" -Level Info
        }
    }
    catch {
        Write-Log "WARNING: Failed to set up Windows Terminal integration: $($_.Exception.Message)" -Level Warning
    }
}

function Set-FirewallRules {
    if (-not $ConfigureFirewall) {
        Write-Log "Skipping firewall configuration" -Level Info
        return
    }
    
    Write-Progress-Log -Activity "Firewall Rules" -Status "Configuring Windows Firewall rules..." -PercentComplete 80
    
    try {
        $mcpServerExe = Join-Path $VenvDir "Scripts\serena-mcp-server.exe"
        
        if (-not (Test-Path $mcpServerExe)) {
            Write-Log "MCP server executable not found, skipping firewall rules" -Level Warning
            return
        }
        
        # Remove existing rules
        Get-NetFirewallRule -DisplayName "Serena MCP Server*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        
        # Add inbound rule
        New-NetFirewallRule -DisplayName "Serena MCP Server (Inbound)" -Direction Inbound -Program $mcpServerExe -Action Allow -Protocol TCP -Profile Domain,Private -ErrorAction SilentlyContinue | Out-Null
        
        # Add outbound rule
        New-NetFirewallRule -DisplayName "Serena MCP Server (Outbound)" -Direction Outbound -Program $mcpServerExe -Action Allow -Protocol TCP -Profile Domain,Private -ErrorAction SilentlyContinue | Out-Null
        
        Write-Log "Windows Firewall rules configured for Serena MCP Server" -Level Success
    }
    catch {
        Write-Log "WARNING: Failed to configure firewall rules: $($_.Exception.Message)" -Level Warning
        Write-Log "You may need to manually allow Serena MCP Server through the firewall" -Level Warning
    }
}

function Set-PowerShellProfile {
    Write-Progress-Log -Activity "PowerShell Profile" -Status "Configuring PowerShell profile..." -PercentComplete 90
    
    try {
        # Get PowerShell profile path
        $profilePath = $PROFILE
        $profileDir = Split-Path $profilePath -Parent
        
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        
        # Create or update profile
        $profileContent = @"
# Serena Agent Environment Setup
`$env:SERENA_HOME = "$SerenaHome"
`$env:SOLIDLSP_HOME = "$SolidLspHome"

# Serena Agent Aliases
function Start-SerenaMCP { & "$VenvDir\Scripts\serena-mcp-server.exe" @args }
function Invoke-SerenaIndex { & "$VenvDir\Scripts\index-project.exe" @args }

Set-Alias -Name smcp -Value Start-SerenaMCP
Set-Alias -Name serena -Value "$VenvDir\Scripts\serena.exe"

# Welcome message
Write-Host "Serena Agent environment loaded" -ForegroundColor Green
"@
        
        if (Test-Path $profilePath) {
            $existingContent = Get-Content $profilePath -Raw
            if ($existingContent -notlike "*Serena Agent Environment Setup*") {
                Add-Content -Path $profilePath -Value "`n$profileContent"
                Write-Log "Updated PowerShell profile: $profilePath" -Level Success
            } else {
                Write-Log "PowerShell profile already configured" -Level Info
            }
        } else {
            Set-Content -Path $profilePath -Value $profileContent
            Write-Log "Created PowerShell profile: $profilePath" -Level Success
        }
    }
    catch {
        Write-Log "WARNING: Failed to configure PowerShell profile: $($_.Exception.Message)" -Level Warning
    }
}

function Test-EnvironmentSetup {
    Write-Progress-Log -Activity "Verification" -Status "Verifying environment setup..." -PercentComplete 95
    
    try {
        # Test environment variables
        $serenaHomeEnv = [Environment]::GetEnvironmentVariable("SERENA_HOME", "Machine")
        $solidLspHomeEnv = [Environment]::GetEnvironmentVariable("SOLIDLSP_HOME", "Machine")
        
        if ($serenaHomeEnv -ne $SerenaHome) {
            Write-Log "WARNING: SERENA_HOME not set correctly" -Level Warning
        } else {
            Write-Log "SERENA_HOME verified: $serenaHomeEnv" -Level Success
        }
        
        if ($solidLspHomeEnv -ne $SolidLspHome) {
            Write-Log "WARNING: SOLIDLSP_HOME not set correctly" -Level Warning
        } else {
            Write-Log "SOLIDLSP_HOME verified: $solidLspHomeEnv" -Level Success
        }
        
        # Test PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        $venvScripts = Join-Path $VenvDir "Scripts"
        
        if ($currentPath -like "*$venvScripts*") {
            Write-Log "PATH configuration verified" -Level Success
        } else {
            Write-Log "WARNING: Serena not found in PATH" -Level Warning
        }
        
        Write-Log "Environment setup verification completed" -Level Success
        return $true
    }
    catch {
        Write-Log "Environment setup verification failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Main Setup Flow

function Start-EnvironmentSetup {
    try {
        # Initialize logging
        if (Test-Path $LogFile) {
            Remove-Item $LogFile -Force
        }
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
        
        Write-Log "=== Serena Agent Environment Setup Started ===" -Level Info
        Write-Log "Serena Home: $SerenaHome" -Level Info
        Write-Log "SolidLSP Home: $SolidLspHome" -Level Info
        Write-Log "Configure Firewall: $ConfigureFirewall" -Level Info
        Write-Log "Setup File Associations: $SetupFileAssociations" -Level Info
        Write-Log "Setup Terminal Integration: $SetupTerminalIntegration" -Level Info
        Write-Log "Silent Mode: $Silent" -Level Info
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "===============================================" -ForegroundColor Cyan
            Write-Host "    Serena Agent - Environment Setup" -ForegroundColor Cyan
            Write-Host "===============================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Serena Home: $SerenaHome" -ForegroundColor White
            Write-Host "SolidLSP Home: $SolidLspHome" -ForegroundColor White
            Write-Host "Log file: $LogFile" -ForegroundColor White
            Write-Host ""
            
            Write-Host "Optional Features:" -ForegroundColor White
            Write-Host "  Configure Firewall: $($ConfigureFirewall.IsPresent)" -ForegroundColor Gray
            Write-Host "  Setup File Associations: $($SetupFileAssociations.IsPresent)" -ForegroundColor Gray
            Write-Host "  Setup Terminal Integration: $($SetupTerminalIntegration.IsPresent)" -ForegroundColor Gray
            Write-Host ""
            
            if (-not $Silent) {
                $response = Read-Host "Continue with environment setup? (y/N)"
                if ($response -notmatch '^[Yy]') {
                    Write-Log "Environment setup cancelled by user" -Level Info
                    exit 0
                }
            }
        }
        
        Test-Installation
        Set-CoreEnvironmentVariables
        Set-LanguageEnvironmentVariables
        Set-FileAssociations
        Set-WindowsTerminalIntegration
        Set-FirewallRules
        Set-PowerShellProfile
        
        if (Test-EnvironmentSetup) {
            Write-Progress-Log -Activity "Environment Setup" -Status "Environment setup completed successfully!" -PercentComplete 100
            
            Write-Log "=== Environment Setup Completed Successfully ===" -Level Success
            
            if (-not $Silent) {
                Write-Host ""
                Write-Host "===============================================" -ForegroundColor Green
                Write-Host "    Environment Setup Completed!" -ForegroundColor Green
                Write-Host "===============================================" -ForegroundColor Green
                Write-Host ""
                Write-Host "Environment Variables Configured:" -ForegroundColor White
                Write-Host "  SERENA_HOME=$SerenaHome" -ForegroundColor Gray
                Write-Host "  SOLIDLSP_HOME=$SolidLspHome" -ForegroundColor Gray
                Write-Host "  PATH updated to include Serena commands" -ForegroundColor Gray
                Write-Host ""
                Write-Host "PowerShell Profile Updated:" -ForegroundColor White
                Write-Host "  Aliases: serena, smcp (Start-SerenaMCP)" -ForegroundColor Gray
                Write-Host "  Functions: Start-SerenaMCP, Invoke-SerenaIndex" -ForegroundColor Gray
                Write-Host ""
                
                if ($SetupFileAssociations) {
                    Write-Host "File Associations:" -ForegroundColor White
                    Write-Host "  .serena files associated with Serena Agent" -ForegroundColor Gray
                    Write-Host ""
                }
                
                if ($SetupTerminalIntegration) {
                    Write-Host "Windows Terminal:" -ForegroundColor White
                    Write-Host "  Serena Agent profile added" -ForegroundColor Gray
                    Write-Host ""
                }
                
                if ($ConfigureFirewall) {
                    Write-Host "Windows Firewall:" -ForegroundColor White
                    Write-Host "  Rules configured for Serena MCP Server" -ForegroundColor Gray
                    Write-Host ""
                }
                
                Write-Host "IMPORTANT: Please restart your PowerShell session" -ForegroundColor Yellow
                Write-Host "           to load the updated environment and profile." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Setup log: $LogFile" -ForegroundColor Gray
                Write-Host ""
            }
        } else {
            throw "Environment setup verification failed"
        }
    }
    catch {
        Write-Log "Environment setup failed: $($_.Exception.Message)" -Level Error
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "===============================================" -ForegroundColor Red
            Write-Host "    Environment Setup Failed!" -ForegroundColor Red
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
            Write-Progress -Activity "Environment Setup" -Completed
        }
    }
}

#endregion

# Check if running as Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Administrator privileges are required for environment setup." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Start environment setup
Start-EnvironmentSetup