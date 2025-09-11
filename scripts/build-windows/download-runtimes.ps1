#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Downloads and prepares portable runtime environments for Windows standalone build.

.DESCRIPTION
    This script downloads Node.js portable and other runtime dependencies needed for
    language servers to function completely offline. All runtimes are downloaded as
    portable versions that can be embedded in the final package.

.PARAMETER RuntimeTier
    Tier of runtimes to download: minimal, essential, complete, full

.PARAMETER Architecture
    Target architecture: x64 or arm64

.PARAMETER OutputPath
    Path where runtimes will be downloaded

.EXAMPLE
    .\download-runtimes.ps1 -RuntimeTier essential -Architecture x64 -OutputPath build/runtimes
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('minimal', 'essential', 'complete', 'full')]
    [string]$RuntimeTier = 'essential',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture = 'x64',
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = 'build/runtimes'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Runtime versions
$NODEJS_VERSION = '20.11.1'
$DOTNET_VERSION = '9.0.6'
$JAVA_VERSION = '21'

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

Write-Host "=== Downloading Portable Runtimes ===" -ForegroundColor Green
Write-Host "Runtime Tier: $RuntimeTier" -ForegroundColor Cyan
Write-Host "Architecture: $Architecture" -ForegroundColor Cyan
Write-Host "Output Path: $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Helper function for downloading with retry
function Download-WithRetry {
    param(
        [string]$Url,
        [string]$OutputFile,
        [int]$MaxRetries = 3
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "Downloading: $Url (attempt $i/$MaxRetries)" -ForegroundColor Gray
            
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
            $webClient.DownloadFile($Url, $OutputFile)
            
            if (Test-Path $OutputFile) {
                $size = (Get-Item $OutputFile).Length / 1MB
                Write-Host "Downloaded successfully: $([Math]::Round($size, 2)) MB" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Warning "Download attempt $i failed: $_"
            if ($i -eq $MaxRetries) {
                throw "Failed to download after $MaxRetries attempts: $Url"
            }
            Start-Sleep -Seconds 5
        }
    }
    return $false
}

# Helper function for extracting archives
function Extract-Archive {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath
    )
    
    Write-Host "Extracting: $(Split-Path $ArchivePath -Leaf)" -ForegroundColor Gray
    
    $extension = [System.IO.Path]::GetExtension($ArchivePath).ToLower()
    
    switch ($extension) {
        '.zip' {
            Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
        }
        '.7z' {
            if (Get-Command 7z -ErrorAction SilentlyContinue) {
                & 7z x "$ArchivePath" "-o$DestinationPath" -y | Out-Null
            } else {
                Write-Warning "7-Zip not found, trying PowerShell extraction"
                Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
            }
        }
        '.tar' {
            tar -xf "$ArchivePath" -C "$DestinationPath"
        }
        default {
            throw "Unsupported archive format: $extension"
        }
    }
    
    Write-Host "Extraction completed" -ForegroundColor Green
}

# Download Node.js Portable (essential for most language servers)
function Download-NodejsPortable {
    Write-Host "`n=== Downloading Node.js Portable v$NODEJS_VERSION ===" -ForegroundColor Yellow
    
    $nodeArch = if ($Architecture -eq 'arm64') { 'arm64' } else { 'x64' }
    $nodeUrl = "https://nodejs.org/dist/v$NODEJS_VERSION/node-v$NODEJS_VERSION-win-$nodeArch.zip"
    $nodeZip = Join-Path $OutputPath "nodejs-$nodeArch.zip"
    $nodeDir = Join-Path $OutputPath "nodejs"
    
    # Download Node.js
    if (Download-WithRetry -Url $nodeUrl -OutputFile $nodeZip) {
        # Extract Node.js
        Extract-Archive -ArchivePath $nodeZip -DestinationPath $OutputPath
        
        # Rename extracted folder to standard name
        $extractedFolder = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "node-v*" } | Select-Object -First 1
        if ($extractedFolder) {
            if (Test-Path $nodeDir) {
                Remove-Item $nodeDir -Recurse -Force
            }
            Move-Item $extractedFolder.FullName $nodeDir
        }
        
        # Verify Node.js works
        $nodeExe = Join-Path $nodeDir "node.exe"
        if (Test-Path $nodeExe) {
            $nodeVersion = & $nodeExe --version 2>&1
            Write-Host "Node.js installed: $nodeVersion" -ForegroundColor Green
            
            # Install critical npm packages locally
            Write-Host "Installing offline npm packages..." -ForegroundColor Gray
            $npmCmd = Join-Path $nodeDir "npm.cmd"
            
            # Create package cache directory
            $npmCache = Join-Path $OutputPath "npm-cache"
            New-Item -ItemType Directory -Force -Path $npmCache | Out-Null
            
            # Pre-install essential npm packages for offline use
            $packages = @(
                "pyright@1.1.388",
                "typescript-language-server@4.3.3",
                "typescript@5.5.4",
                "bash-language-server@5.6.0"
            )
            
            if ($RuntimeTier -eq 'complete' -or $RuntimeTier -eq 'full') {
                $packages += @(
                    "intelephense@1.14.4",
                    "@vtsls/language-server@0.2.6"
                )
            }
            
            foreach ($package in $packages) {
                Write-Host "Pre-installing npm package: $package" -ForegroundColor Gray
                $packageDir = Join-Path $npmCache $package.Split('@')[0]
                New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
                
                & $npmCmd install --prefix $packageDir $package --no-save 2>&1 | Out-Null
            }
            
            Write-Host "Node.js and npm packages ready for offline use" -ForegroundColor Green
        }
        else {
            Write-Warning "Node.js executable not found after extraction"
        }
        
        # Clean up zip file
        Remove-Item $nodeZip -Force -ErrorAction SilentlyContinue
    }
}

# Download .NET Runtime Portable (for C# language server)
function Download-DotNetPortable {
    if ($RuntimeTier -eq 'minimal') {
        Write-Host "Skipping .NET Runtime (minimal tier)" -ForegroundColor Gray
        return
    }
    
    Write-Host "`n=== Downloading .NET Runtime Portable v$DOTNET_VERSION ===" -ForegroundColor Yellow
    
    $dotnetArch = if ($Architecture -eq 'arm64') { 'arm64' } else { 'x64' }
    $dotnetUrl = "https://builds.dotnet.microsoft.com/dotnet/Runtime/$DOTNET_VERSION/dotnet-runtime-$DOTNET_VERSION-win-$dotnetArch.zip"
    $dotnetZip = Join-Path $OutputPath "dotnet-$dotnetArch.zip"
    $dotnetDir = Join-Path $OutputPath "dotnet"
    
    # Download .NET Runtime
    if (Download-WithRetry -Url $dotnetUrl -OutputFile $dotnetZip) {
        # Extract .NET Runtime
        New-Item -ItemType Directory -Force -Path $dotnetDir | Out-Null
        Extract-Archive -ArchivePath $dotnetZip -DestinationPath $dotnetDir
        
        # Verify .NET works
        $dotnetExe = Join-Path $dotnetDir "dotnet.exe"
        if (Test-Path $dotnetExe) {
            $dotnetVersion = & $dotnetExe --list-runtimes 2>&1 | Select-String "Microsoft.NETCore.App"
            Write-Host ".NET Runtime installed: $dotnetVersion" -ForegroundColor Green
        }
        else {
            Write-Warning ".NET executable not found after extraction"
        }
        
        # Clean up zip file
        Remove-Item $dotnetZip -Force -ErrorAction SilentlyContinue
    }
}

# Download Java Runtime Portable (for Java language server)
function Download-JavaPortable {
    if ($RuntimeTier -ne 'complete' -and $RuntimeTier -ne 'full') {
        Write-Host "Skipping Java Runtime (not in $RuntimeTier tier)" -ForegroundColor Gray
        return
    }
    
    Write-Host "`n=== Downloading Java Runtime Portable (OpenJDK $JAVA_VERSION) ===" -ForegroundColor Yellow
    
    $javaArch = if ($Architecture -eq 'arm64') { 'aarch64' } else { 'x64' }
    # Using Adoptium (Eclipse Temurin) builds
    $javaUrl = "https://api.adoptium.net/v3/binary/latest/$JAVA_VERSION/ga/windows/$javaArch/jre/hotspot/normal/eclipse"
    $javaZip = Join-Path $OutputPath "java-$javaArch.zip"
    $javaDir = Join-Path $OutputPath "java"
    
    # Download Java Runtime
    if (Download-WithRetry -Url $javaUrl -OutputFile $javaZip) {
        # Extract Java Runtime
        Extract-Archive -ArchivePath $javaZip -DestinationPath $OutputPath
        
        # Rename extracted folder to standard name
        $extractedFolder = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "jdk-*" -or $_.Name -like "jre-*" } | Select-Object -First 1
        if ($extractedFolder) {
            if (Test-Path $javaDir) {
                Remove-Item $javaDir -Recurse -Force
            }
            Move-Item $extractedFolder.FullName $javaDir
        }
        
        # Verify Java works
        $javaExe = Join-Path $javaDir "bin\java.exe"
        if (Test-Path $javaExe) {
            $javaVersion = & $javaExe -version 2>&1 | Select-String "version"
            Write-Host "Java Runtime installed: $javaVersion" -ForegroundColor Green
        }
        else {
            Write-Warning "Java executable not found after extraction"
        }
        
        # Clean up zip file
        Remove-Item $javaZip -Force -ErrorAction SilentlyContinue
    }
}

# Create runtime configuration file
function Create-RuntimeConfig {
    Write-Host "`n=== Creating Runtime Configuration ===" -ForegroundColor Yellow
    
    $config = @{
        version = "1.0.0"
        tier = $RuntimeTier
        architecture = $Architecture
        runtimes = @{}
    }
    
    # Add Node.js if present
    $nodeDir = Join-Path $OutputPath "nodejs"
    if (Test-Path $nodeDir) {
        $config.runtimes.nodejs = @{
            path = "nodejs"
            executable = "node.exe"
            version = $NODEJS_VERSION
            npmCache = "npm-cache"
        }
    }
    
    # Add .NET if present
    $dotnetDir = Join-Path $OutputPath "dotnet"
    if (Test-Path $dotnetDir) {
        $config.runtimes.dotnet = @{
            path = "dotnet"
            executable = "dotnet.exe"
            version = $DOTNET_VERSION
        }
    }
    
    # Add Java if present
    $javaDir = Join-Path $OutputPath "java"
    if (Test-Path $javaDir) {
        $config.runtimes.java = @{
            path = "java"
            executable = "bin\java.exe"
            version = $JAVA_VERSION
        }
    }
    
    # Save configuration
    $configPath = Join-Path $OutputPath "runtime-config.json"
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    Write-Host "Runtime configuration saved to: $configPath" -ForegroundColor Green
}

# Create launcher wrapper script
function Create-LauncherWrapper {
    Write-Host "`n=== Creating Launcher Wrapper ===" -ForegroundColor Yellow
    
    $wrapperContent = @'
@echo off
setlocal enabledelayedexpansion

REM Serena Portable Runtime Launcher
REM This script sets up the portable runtime environment

set "SCRIPT_DIR=%~dp0"
set "RUNTIME_DIR=%SCRIPT_DIR%runtimes"

REM Add Node.js to PATH if present
if exist "%RUNTIME_DIR%\nodejs\node.exe" (
    set "PATH=%RUNTIME_DIR%\nodejs;%PATH%"
    set "NODE_PATH=%RUNTIME_DIR%\npm-cache"
    echo [Runtime] Node.js portable activated
)

REM Add .NET to PATH if present
if exist "%RUNTIME_DIR%\dotnet\dotnet.exe" (
    set "PATH=%RUNTIME_DIR%\dotnet;%PATH%"
    set "DOTNET_ROOT=%RUNTIME_DIR%\dotnet"
    echo [Runtime] .NET portable activated
)

REM Add Java to PATH if present
if exist "%RUNTIME_DIR%\java\bin\java.exe" (
    set "PATH=%RUNTIME_DIR%\java\bin;%PATH%"
    set "JAVA_HOME=%RUNTIME_DIR%\java"
    echo [Runtime] Java portable activated
)

REM Set offline mode flag
set "SERENA_OFFLINE_MODE=1"
set "SERENA_RUNTIME_DIR=%RUNTIME_DIR%"

REM Launch Serena with portable runtimes
echo [Serena] Launching with portable runtimes...
"%SCRIPT_DIR%serena.exe" %*
'@
    
    $wrapperPath = Join-Path (Split-Path $OutputPath -Parent) "serena-portable.bat"
    $wrapperContent | Set-Content $wrapperPath
    Write-Host "Launcher wrapper created: $wrapperPath" -ForegroundColor Green
}

# Main execution
try {
    # Download runtimes based on tier
    Download-NodejsPortable
    Download-DotNetPortable
    Download-JavaPortable
    
    # Create configuration files
    Create-RuntimeConfig
    Create-LauncherWrapper
    
    # Summary
    Write-Host "`n=== Download Summary ===" -ForegroundColor Green
    $runtimeCount = (Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -in @('nodejs', 'dotnet', 'java') }).Count
    $totalSize = [Math]::Round((Get-ChildItem -Path $OutputPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    
    Write-Host "Runtimes downloaded: $runtimeCount" -ForegroundColor Cyan
    Write-Host "Total size: $totalSize MB" -ForegroundColor Cyan
    Write-Host "Output directory: $OutputPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Portable runtimes are ready for offline use!" -ForegroundColor Green
}
catch {
    Write-Error "Runtime download failed: $_"
    exit 1
}
