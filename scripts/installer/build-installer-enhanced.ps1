#Requires -Version 5.1

<#
.SYNOPSIS
    Enhanced build script for Serena NSIS Installer with portable distribution integration

.DESCRIPTION
    This script builds the Windows installer using NSIS with enhanced functionality:
    - Integrates with portable distribution (ZIP or folder)
    - Supports tier-based language server selection
    - Automatic NSIS download if not present
    - Code signing support
    - Comprehensive validation and testing

.PARAMETER PortablePath
    Path to the portable distribution (ZIP file or extracted folder)

.PARAMETER Tier
    Language server tier to include (minimal, essential, complete, full)

.PARAMETER Configuration
    Build configuration (Release or Debug)

.PARAMETER Clean
    Clean previous build artifacts

.PARAMETER Sign
    Sign the installer executable

.PARAMETER CertificatePath
    Path to code signing certificate (P12/PFX format)

.PARAMETER CertificatePassword
    Password for code signing certificate

.PARAMETER Verbose
    Enable verbose output

.PARAMETER DownloadNSIS
    Automatically download NSIS if not found

.PARAMETER ValidateOnly
    Only validate prerequisites without building

.EXAMPLE
    .\build-installer-enhanced.ps1 -PortablePath ".\dist\serena-portable.zip" -Tier essential

.EXAMPLE
    .\build-installer-enhanced.ps1 -PortablePath ".\dist\serena-portable\" -Tier full -Sign -CertificatePath "cert.p12"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$PortablePath = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier = "essential",

    [string]$Configuration = "Release",

    [switch]$Clean,

    [switch]$Sign,

    [string]$CertificatePath = "",

    [SecureString]$CertificatePassword,

    [switch]$Verbose,

    [switch]$DownloadNSIS,

    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$InstallerScript = Join-Path $ScriptDir "serena-installer-enhanced.nsi"
$OutputDir = Join-Path $ScriptDir "output"
$TempDir = Join-Path $ScriptDir "temp"
$NSISVersion = "3.10"
$NSISUrl = "https://downloads.sourceforge.net/project/nsis/NSIS%203/$NSISVersion/nsis-$NSISVersion.zip"

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error-Fatal { param($Message) Write-Host "ERROR: $Message" -ForegroundColor Red }
function Write-Warning-Custom { param($Message) Write-Host "WARNING: $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }
function Write-Step { param($Message) Write-Host "`n>>> $Message" -ForegroundColor Magenta }

function Test-CommandExists {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    }
    catch {
        return $false
    }
}

function Get-NSIS {
    Write-Step "Checking for NSIS installation..."

    if (Test-CommandExists "makensis") {
        $nsisPath = (Get-Command makensis).Source
        Write-Success "NSIS found: $nsisPath"
        return $true
    }

    if (-not $DownloadNSIS) {
        Write-Error-Fatal "NSIS (makensis) not found in PATH."
        Write-Info "Options:"
        Write-Info "  1. Install NSIS from: https://nsis.sourceforge.io/"
        Write-Info "  2. Run this script with -DownloadNSIS to automatically download"
        return $false
    }

    Write-Info "NSIS not found. Downloading NSIS $NSISVersion..."

    try {
        $nsisDir = Join-Path $TempDir "nsis"
        $nsisZip = Join-Path $TempDir "nsis.zip"

        # Create temp directory
        New-Item -ItemType Directory -Path $nsisDir -Force | Out-Null

        # Download NSIS
        Write-Info "Downloading from: $NSISUrl"
        Invoke-WebRequest -Uri $NSISUrl -OutFile $nsisZip -UseBasicParsing

        # Extract NSIS
        Write-Info "Extracting NSIS..."
        Expand-Archive -Path $nsisZip -DestinationPath $nsisDir -Force

        # Find makensis.exe
        $makeNSIS = Get-ChildItem -Path $nsisDir -Recurse -Filter "makensis.exe" | Select-Object -First 1

        if ($makeNSIS) {
            $env:PATH = "$($makeNSIS.DirectoryName);$env:PATH"
            Write-Success "NSIS downloaded and configured successfully"
            return $true
        } else {
            Write-Error-Fatal "Could not find makensis.exe in downloaded NSIS package"
            return $false
        }
    }
    catch {
        Write-Error-Fatal "Failed to download NSIS: $($_.Exception.Message)"
        return $false
    }
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."

    $allGood = $true

    # Check NSIS
    if (-not (Get-NSIS)) {
        $allGood = $false
    }

    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Error-Fatal "Windows 10 or later required for building"
        $allGood = $false
    } else {
        Write-Success "Windows version check passed: $($osVersion.Major).$($osVersion.Minor)"
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error-Fatal "PowerShell 5.1 or later required"
        $allGood = $false
    } else {
        Write-Success "PowerShell version check passed: $($PSVersionTable.PSVersion)"
    }

    # Check for portable distribution
    if ($PortablePath) {
        if (Test-Path $PortablePath) {
            Write-Success "Portable distribution found: $PortablePath"
        } else {
            Write-Error-Fatal "Portable distribution not found: $PortablePath"
            $allGood = $false
        }
    } else {
        Write-Warning-Custom "No portable path specified - will use default dist directory"
        # Try to auto-detect
        $defaultDist = Join-Path $ProjectRoot "dist"
        if (Test-Path $defaultDist) {
            $PortablePath = $defaultDist
            Write-Info "Auto-detected portable distribution: $PortablePath"
        } else {
            Write-Error-Fatal "Could not find portable distribution in: $defaultDist"
            Write-Info "Build the portable distribution first using: .\scripts\build-windows\build-portable.ps1"
            $allGood = $false
        }
    }

    # Check installer script exists
    if (Test-Path $InstallerScript) {
        Write-Success "Installer script found: $InstallerScript"
    } else {
        Write-Error-Fatal "Installer script not found: $InstallerScript"
        $allGood = $false
    }

    # Check code signing prerequisites
    if ($Sign) {
        if (-not $CertificatePath) {
            Write-Error-Fatal "Code signing requested but no certificate path provided"
            $allGood = $false
        } elseif (-not (Test-Path $CertificatePath)) {
            Write-Error-Fatal "Certificate file not found: $CertificatePath"
            $allGood = $false
        } else {
            Write-Success "Code signing certificate found: $CertificatePath"
        }

        if (-not (Test-CommandExists "signtool")) {
            Write-Warning-Custom "signtool.exe not found - code signing may fail"
            Write-Info "Install Windows SDK to get signtool.exe"
        }
    }

    if ($allGood) {
        Write-Success "All prerequisites check passed"
    } else {
        Write-Error-Fatal "Prerequisites check failed"
    }

    return $allGood
}

function Initialize-BuildEnvironment {
    Write-Step "Initializing build environment..."

    # Clean directories if requested
    if ($Clean) {
        Write-Info "Cleaning output directories..."
        Remove-Item $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Create necessary directories
    @($OutputDir, $TempDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            Write-Info "Creating directory: $_"
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }

    Write-Success "Build environment initialized"
}

function Prepare-PortableDistribution {
    Write-Step "Preparing portable distribution..."

    $distDir = Join-Path $TempDir "dist"

    # Clean dist directory
    if (Test-Path $distDir) {
        Remove-Item $distDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null

    # Check if portable path is a ZIP or directory
    if ($PortablePath.EndsWith(".zip")) {
        Write-Info "Extracting portable ZIP: $PortablePath"
        try {
            Expand-Archive -Path $PortablePath -DestinationPath $distDir -Force

            # If extracted to a subdirectory, move contents up
            $subdirs = Get-ChildItem -Path $distDir -Directory
            if ($subdirs.Count -eq 1) {
                $subdir = $subdirs[0]
                Write-Info "Moving contents from subdirectory: $($subdir.Name)"
                Get-ChildItem -Path $subdir.FullName | Move-Item -Destination $distDir -Force
                Remove-Item $subdir.FullName -Force
            }

            Write-Success "Portable distribution extracted successfully"
        }
        catch {
            Write-Error-Fatal "Failed to extract portable ZIP: $($_.Exception.Message)"
            throw
        }
    } else {
        Write-Info "Copying portable distribution from: $PortablePath"
        try {
            Copy-Item -Path "$PortablePath\*" -Destination $distDir -Recurse -Force
            Write-Success "Portable distribution copied successfully"
        }
        catch {
            Write-Error-Fatal "Failed to copy portable distribution: $($_.Exception.Message)"
            throw
        }
    }

    # Verify essential files exist
    $essentialFiles = @("serena-mcp-server.exe")
    $missingFiles = @()

    foreach ($file in $essentialFiles) {
        $filePath = Join-Path $distDir $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }

    if ($missingFiles.Count -gt 0) {
        Write-Error-Fatal "Essential files missing from portable distribution: $($missingFiles -join ', ')"
        throw "Invalid portable distribution"
    }

    # Show distribution statistics
    $distSize = (Get-ChildItem $distDir -Recurse | Measure-Object -Property Length -Sum).Sum
    $distSizeMB = [math]::Round($distSize / 1MB, 1)
    Write-Info "Distribution size: $distSizeMB MB"

    # Check for language servers
    $lsDir = Join-Path $distDir "language-servers"
    if (Test-Path $lsDir) {
        $lsCount = (Get-ChildItem $lsDir -Directory).Count
        Write-Info "Language servers found: $lsCount"
    } else {
        Write-Warning-Custom "No language servers directory found"
    }

    Write-Success "Portable distribution prepared: $distDir"
    return $distDir
}

function Build-Installer {
    param([string]$DistPath)

    Write-Step "Building installer with NSIS..."

    Push-Location $TempDir

    try {
        # Copy installer script to temp directory
        $tempInstallerScript = Join-Path $TempDir "installer.nsi"
        Copy-Item $InstallerScript $tempInstallerScript -Force

        # Build arguments
        $buildArgs = @(
            "/V4",  # Verbose level 4
            "/DTIER=$Tier",
            "/DDIST_PATH=$DistPath",
            $tempInstallerScript
        )

        if ($Verbose) {
            Write-Info "NSIS command: makensis $($buildArgs -join ' ')"
        }

        Write-Info "Starting NSIS build..."
        $process = Start-Process -FilePath "makensis" -ArgumentList $buildArgs -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            throw "NSIS build failed with exit code $($process.ExitCode)"
        }

        Write-Success "Installer build completed successfully"
    }
    catch {
        Pop-Location
        Write-Error-Fatal "Installer build failed: $($_.Exception.Message)"
        throw
    }
    finally {
        Pop-Location
    }

    # Find and move installer
    $installerFile = Get-ChildItem -Path $TempDir -Name "serena-installer-*.exe" | Select-Object -First 1
    if ($installerFile) {
        $sourcePath = Join-Path $TempDir $installerFile
        $destPath = Join-Path $OutputDir $installerFile
        Move-Item -Path $sourcePath -Destination $destPath -Force
        Write-Success "Installer moved to: $destPath"
        return $destPath
    } else {
        Write-Error-Fatal "Installer file not found after build"
        throw "Installer build failed"
    }
}

function Sign-Installer {
    param([string]$InstallerPath)

    if (-not $Sign) {
        return
    }

    Write-Step "Code signing installer..."

    try {
        $signArgs = @(
            "sign",
            "/f", "`"$CertificatePath`"",
            "/t", "http://timestamp.digicert.com",
            "/fd", "SHA256"
        )

        if ($CertificatePassword) {
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertificatePassword)
            )
            $signArgs += @("/p", $plainPassword)
        }

        $signArgs += "`"$InstallerPath`""

        Write-Info "Signing installer..."
        $signProcess = Start-Process -FilePath "signtool" -ArgumentList $signArgs -NoNewWindow -Wait -PassThru

        if ($signProcess.ExitCode -eq 0) {
            Write-Success "Installer signed successfully"

            # Verify signature
            $signature = Get-AuthenticodeSignature $InstallerPath
            if ($signature.Status -eq "Valid") {
                Write-Success "Digital signature verified: $($signature.SignerCertificate.Subject)"
            } else {
                Write-Warning-Custom "Digital signature status: $($signature.Status)"
            }
        } else {
            Write-Error-Fatal "Code signing failed with exit code $($signProcess.ExitCode)"
            throw "Code signing failed"
        }
    }
    catch {
        Write-Error-Fatal "Code signing failed: $($_.Exception.Message)"
        throw
    }
}

function Test-Installer {
    param([string]$InstallerPath)

    Write-Step "Validating installer..."

    try {
        # Check file exists
        if (-not (Test-Path $InstallerPath)) {
            Write-Error-Fatal "Installer not found: $InstallerPath"
            return $false
        }

        $fileInfo = Get-Item $InstallerPath
        Write-Info "Installer size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
        Write-Info "Installer created: $($fileInfo.CreationTime)"

        # Check digital signature
        $signature = Get-AuthenticodeSignature $InstallerPath
        if ($signature.Status -eq "Valid") {
            Write-Success "Digital signature valid: $($signature.SignerCertificate.Subject)"
        } elseif ($signature.Status -eq "NotSigned") {
            Write-Warning-Custom "Installer is not digitally signed"
        } else {
            Write-Warning-Custom "Digital signature status: $($signature.Status)"
        }

        # Try to extract version info (would require additional tools)
        Write-Info "Installer validation completed"

        return $true
    }
    catch {
        Write-Error-Fatal "Installer validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-BuildSummary {
    param(
        [string]$InstallerPath,
        [timespan]$Duration
    )

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Build Summary" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Configuration: $Configuration" -ForegroundColor White
    Write-Host "Language Server Tier: $Tier" -ForegroundColor White
    Write-Host "Build Time: $($Duration.ToString('mm\:ss'))" -ForegroundColor White
    Write-Host ""
    Write-Host "Installer Details:" -ForegroundColor Yellow
    Write-Host "  Path: $InstallerPath" -ForegroundColor White

    if (Test-Path $InstallerPath) {
        $fileInfo = Get-Item $InstallerPath
        Write-Host "  Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "  Created: $($fileInfo.CreationTime)" -ForegroundColor White

        $signature = Get-AuthenticodeSignature $InstallerPath
        Write-Host "  Signed: $(if ($signature.Status -eq 'Valid') { 'Yes' } else { 'No' })" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Testing Options:" -ForegroundColor Green
    Write-Host "  Basic test: .\test-installer.ps1 -InstallerPath `"$InstallerPath`" -TestMode basic" -ForegroundColor White
    Write-Host "  Full test: .\test-installer.ps1 -InstallerPath `"$InstallerPath`" -TestMode full" -ForegroundColor White
    Write-Host "  Silent install: `"$InstallerPath`" /S /D=C:\TestInstall" -ForegroundColor White
    Write-Host ""
}

function Cleanup-BuildArtifacts {
    Write-Step "Cleaning up build artifacts..."

    try {
        # Remove temporary files but keep output
        $cleanupPaths = @(
            $TempDir
        )

        foreach ($path in $cleanupPaths) {
            if (Test-Path $path) {
                Write-Info "Removing: $path"
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Success "Cleanup completed"
    }
    catch {
        Write-Warning-Custom "Cleanup had some issues: $_"
    }
}

# Main execution
try {
    $startTime = Get-Date

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "Serena Agent - Enhanced Installer Build" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Host "Configuration: $Configuration" -ForegroundColor Cyan
    Write-Host "Language Server Tier: $Tier" -ForegroundColor Cyan
    Write-Host "Portable Path: $PortablePath" -ForegroundColor Cyan
    Write-Host "Output Directory: $OutputDir" -ForegroundColor Cyan
    Write-Host ""

    # Prerequisites check
    if (-not (Test-Prerequisites)) {
        Write-Error-Fatal "Prerequisites check failed"
        exit 1
    }

    if ($ValidateOnly) {
        Write-Success "Validation completed successfully - exiting without build"
        exit 0
    }

    # Initialize build environment
    Initialize-BuildEnvironment

    # Prepare portable distribution
    $distPath = Prepare-PortableDistribution

    # Build installer
    $installerPath = Build-Installer -DistPath $distPath

    # Sign installer if requested
    if ($Sign) {
        Sign-Installer -InstallerPath $installerPath
    }

    # Test installer
    Test-Installer -InstallerPath $installerPath

    # Calculate duration
    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Show summary
    Show-BuildSummary -InstallerPath $installerPath -Duration $duration

    # Cleanup
    if (-not $Verbose) {
        Cleanup-BuildArtifacts
    }

    Write-Host ""
    Write-Success "Build completed successfully!"
    Write-Host ""

    exit 0
}
catch {
    Write-Error-Fatal "Build failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
