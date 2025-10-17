# PowerShell Build script for Serena NSIS Installer
# This script builds the Windows installer using NSIS with enhanced error handling

param(
    [string]$Configuration = "Release",
    [switch]$Clean,
    [switch]$Sign,
    [string]$CertificatePath = "",
    [string]$CertificatePassword = "",
    [switch]$Verbose
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$InstallerScript = Join-Path $ScriptDir "serena-installer.nsi"
$DistDir = Join-Path $ProjectRoot "dist"
$OutputDir = Join-Path $ScriptDir "output"
$TempDir = Join-Path $ScriptDir "temp"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Serena Agent - Installer Build Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Distribution: $DistDir" -ForegroundColor Gray
Write-Host ""

# Functions
function Test-CommandExists {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    }
    catch {
        return $false
    }
}

function Write-Status {
    param($Message, $Color = "White")
    Write-Host ">> $Message" -ForegroundColor $Color
}

function Write-Error-Exit {
    param($Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

# Check prerequisites
Write-Status "Checking prerequisites..." "Yellow"

if (-not (Test-CommandExists "makensis")) {
    Write-Error-Exit "NSIS (makensis) not found in PATH. Please install NSIS from: https://nsis.sourceforge.io/"
}

if (-not (Test-Path $DistDir)) {
    Write-Error-Exit "Distribution directory not found: $DistDir. Please build the portable distribution first using build-portable.ps1"
}

Write-Status "Prerequisites check passed" "Green"

# Clean previous builds
if ($Clean -or (Test-Path $OutputDir)) {
    Write-Status "Cleaning previous build artifacts..." "Yellow"
    if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
    if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
}

# Create directories
Write-Status "Creating build directories..." "Yellow"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
New-Item -ItemType Directory -Path "$TempDir\dist" -Force | Out-Null

# Copy distribution files
Write-Status "Preparing installer files..." "Yellow"
try {
    Copy-Item -Path "$DistDir\*" -Destination "$TempDir\dist" -Recurse -Force
    Write-Status "Distribution files copied successfully" "Green"
}
catch {
    Write-Error-Exit "Failed to copy distribution files: $($_.Exception.Message)"
}

# Copy language servers if they exist
$LanguageServersDir = Join-Path $ProjectRoot "language-servers"
if (Test-Path $LanguageServersDir) {
    Write-Status "Copying language servers..." "Yellow"
    try {
        New-Item -ItemType Directory -Path "$TempDir\language-servers" -Force | Out-Null
        Copy-Item -Path "$LanguageServersDir\*" -Destination "$TempDir\language-servers" -Recurse -Force
        Write-Status "Language servers copied successfully" "Green"
    }
    catch {
        Write-Warning "Failed to copy language servers: $($_.Exception.Message)"
    }
}

# Build installer
Write-Status "Building installer..." "Yellow"
Push-Location $TempDir

try {
    $BuildArgs = @("/V3", $InstallerScript)
    if ($Verbose) {
        $BuildArgs = @("/V4", $InstallerScript)
    }
    
    $Process = Start-Process -FilePath "makensis" -ArgumentList $BuildArgs -NoNewWindow -Wait -PassThru
    
    if ($Process.ExitCode -ne 0) {
        throw "NSIS build failed with exit code $($Process.ExitCode)"
    }
    
    Write-Status "Installer build completed successfully" "Green"
}
catch {
    Pop-Location
    Write-Error-Exit "Installer build failed: $($_.Exception.Message)"
}
finally {
    Pop-Location
}

# Move installer to output directory
$InstallerFile = Get-ChildItem -Path $TempDir -Name "serena-installer-*.exe" | Select-Object -First 1
if ($InstallerFile) {
    $SourcePath = Join-Path $TempDir $InstallerFile
    $DestPath = Join-Path $OutputDir $InstallerFile
    Move-Item -Path $SourcePath -Destination $DestPath -Force
    Write-Status "Installer moved to: $DestPath" "Green"
} else {
    Write-Error-Exit "Installer file not found after build"
}

# Code signing (if requested and certificate provided)
if ($Sign -and $CertificatePath -and (Test-Path $CertificatePath)) {
    Write-Status "Code signing installer..." "Yellow"
    try {
        $SignArgs = @(
            "sign",
            "/f", "`"$CertificatePath`"",
            "/t", "http://timestamp.verisign.com/scripts/timestamp.dll"
        )
        
        if ($CertificatePassword) {
            $SignArgs += @("/p", $CertificatePassword)
        }
        
        $SignArgs += "`"$DestPath`""
        
        $SignProcess = Start-Process -FilePath "signtool" -ArgumentList $SignArgs -NoNewWindow -Wait -PassThru
        
        if ($SignProcess.ExitCode -eq 0) {
            Write-Status "Installer signed successfully" "Green"
        } else {
            Write-Warning "Code signing failed with exit code $($SignProcess.ExitCode)"
        }
    }
    catch {
        Write-Warning "Code signing failed: $($_.Exception.Message)"
    }
} elseif ($Sign) {
    Write-Warning "Code signing requested but certificate path not provided or file not found"
}

# Cleanup
Write-Status "Cleaning up temporary files..." "Yellow"
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
}

# Final output
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Installer location: $OutputDir" -ForegroundColor White

# Display installer information
$FinalInstaller = Get-ChildItem -Path $OutputDir -Name "serena-installer-*.exe" | Select-Object -First 1
if ($FinalInstaller) {
    $InstallerPath = Join-Path $OutputDir $FinalInstaller
    $InstallerInfo = Get-Item $InstallerPath
    Write-Host "File: $($InstallerInfo.Name)" -ForegroundColor White
    Write-Host "Size: $([math]::Round($InstallerInfo.Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "Created: $($InstallerInfo.CreationTime)" -ForegroundColor White
}

Write-Host ""