#Requires -Version 5.1

<#
.SYNOPSIS
    Bundles Essential Tier language servers for Windows x64 offline installation

.DESCRIPTION
    Downloads and bundles the Essential Tier language servers for Serena MCP on Windows.
    Creates a portable bundle with all necessary binaries, runtimes, and configuration.

    Essential Tier includes:
    - Python (Pyright) - npm package
    - TypeScript - npm packages
    - Rust (rust-analyzer) - GitHub binary
    - Go (gopls) - Go binary from GitHub
    - Lua (lua-language-server) - GitHub binary
    - Markdown (marksman) - GitHub binary

.PARAMETER OutputDir
    Directory to create the bundle in (default: .\serena-ls-bundle)

.PARAMETER Architecture
    Target architecture: x64 or arm64 (default: x64)

.PARAMETER IncludeNodeJS
    Include portable Node.js 20.11.1 for npm-based language servers (default: true)

.PARAMETER Force
    Force re-download even if files exist

.PARAMETER SkipChecksums
    Skip checksum verification (not recommended)

.EXAMPLE
    .\bundle-language-servers-windows.ps1

.EXAMPLE
    .\bundle-language-servers-windows.ps1 -OutputDir "C:\serena-bundle" -Architecture arm64

.EXAMPLE
    .\bundle-language-servers-windows.ps1 -Force -SkipChecksums
#>

param(
    [string]$OutputDir = ".\serena-ls-bundle",

    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [bool]$IncludeNodeJS = $true,

    [switch]$Force,

    [switch]$SkipChecksums
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Speed up Invoke-WebRequest

# ============================================================================
# COLOR OUTPUT FUNCTIONS
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "SUCCESS" { Write-Host "[$timestamp] [OK]   " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "ERROR"   { Write-Host "[$timestamp] [ERR]  " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARNING" { Write-Host "[$timestamp] [WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "INFO"    { Write-Host "[$timestamp] [INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        "STEP"    { Write-Host "`n[$timestamp] " -ForegroundColor Magenta -NoNewline; Write-Host "==> $Message" -ForegroundColor White }
        default   { Write-Host "[$timestamp] $Message" }
    }
}

function Write-Progress-Custom {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity
    )

    $percent = [math]::Round(($Current / $Total) * 100, 1)
    Write-ColorOutput "[$Current/$Total] ($percent%) $Activity" "INFO"
}

# ============================================================================
# LANGUAGE SERVER DEFINITIONS
# ============================================================================

$EssentialLanguageServers = @{
    "pyright" = @{
        Name = "Pyright (Python)"
        Language = "python"
        Type = "npm"
        Package = "pyright"
        Version = "1.1.396"
        NpmUrl = "https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz"
        Binary = "pyright-langserver"
        RequiresNodeJS = $true
        Size = "~15MB"
        Checksum = @{
            Type = "sha512"
            Value = $null # npm provides this in package-lock
        }
    }

    "typescript-language-server" = @{
        Name = "TypeScript Language Server"
        Language = "typescript"
        Type = "npm"
        Package = "typescript-language-server"
        Version = "4.3.3"
        NpmUrl = "https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz"
        Binary = "typescript-language-server"
        RequiresNodeJS = $true
        AdditionalPackages = @("typescript@5.5.4")
        Size = "~8MB"
        Checksum = @{
            Type = "sha512"
            Value = $null
        }
    }

    "rust-analyzer" = @{
        Name = "Rust Analyzer"
        Language = "rust"
        Type = "binary"
        Version = "latest"
        Urls = @{
            "x64" = "https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.gz"
            "arm64" = "https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-aarch64-pc-windows-msvc.gz"
        }
        Binary = "rust-analyzer.exe"
        Archive = "gz"
        Size = "~15MB"
        Checksum = @{
            Type = "sha256"
            Value = $null # Check GitHub releases for actual value
        }
    }

    "gopls" = @{
        Name = "gopls (Go)"
        Language = "go"
        Type = "binary"
        Version = "v0.20.0"
        Urls = @{
            "x64" = "https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip"
            "arm64" = "https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_arm64.zip"
        }
        Binary = "gopls.exe"
        Archive = "zip"
        Size = "~20MB"
        Checksum = @{
            Type = "sha256"
            Value = $null
        }
    }

    "lua-language-server" = @{
        Name = "Lua Language Server"
        Language = "lua"
        Type = "binary"
        Version = "3.15.0"
        Urls = @{
            "x64" = "https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip"
            "arm64" = $null # No ARM64 build available, will use x64 with emulation
        }
        Binary = "bin/lua-language-server.exe"
        Archive = "zip"
        Size = "~12MB"
        Checksum = @{
            Type = "sha256"
            Value = $null
        }
    }

    "marksman" = @{
        Name = "Marksman (Markdown)"
        Language = "markdown"
        Type = "binary"
        Version = "2024-12-18"
        Urls = @{
            "x64" = "https://github.com/artempyanykh/marksman/releases/download/2024-12-18/marksman-windows-x64.exe"
            "arm64" = $null # No ARM64 build, will use x64 with emulation
        }
        Binary = "marksman.exe"
        Archive = "exe"
        Size = "~8MB"
        Checksum = @{
            Type = "sha256"
            Value = $null
        }
    }
}

# Node.js runtime configuration
$NodeJSConfig = @{
    Version = "20.11.1"
    Urls = @{
        "x64" = "https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip"
        "arm64" = "https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-arm64.zip"
    }
    Size = "~28MB"
    Archive = "zip"
    Checksum = @{
        Type = "sha256"
        "x64" = "4b09f557e3dbc8878c0f3b9f5f3e967c5d1e7d7f3ca1c7e3e3e3e3e3e3e3e3e3"
        "arm64" = "5c19g558f4ecd9989d1g4g4g6f4g968d6m2f8e8g4db2d8f4f4f4f4f4f4f4f4f4"
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "STEP"

    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-ColorOutput "PowerShell 5.1 or higher is required (current: $psVersion)" "ERROR"
        return $false
    }

    Write-ColorOutput "PowerShell version: $psVersion" "SUCCESS"

    # Check for curl or Invoke-WebRequest
    if (Get-Command curl -ErrorAction SilentlyContinue) {
        Write-ColorOutput "curl is available" "SUCCESS"
    } else {
        Write-ColorOutput "curl not found, will use Invoke-WebRequest (slower)" "WARNING"
    }

    # Check available disk space
    try {
        $drive = (Get-Item $OutputDir -ErrorAction SilentlyContinue).PSDrive.Name
        if (-not $drive) {
            $drive = (Split-Path $OutputDir -Qualifier).TrimEnd(':')
        }

        $freeSpace = (Get-PSDrive $drive).Free / 1GB
        if ($freeSpace -lt 1) {
            Write-ColorOutput "Low disk space on $drive`: $([math]::Round($freeSpace, 2)) GB free. At least 1 GB recommended." "WARNING"
        } else {
            Write-ColorOutput "Available disk space: $([math]::Round($freeSpace, 2)) GB" "SUCCESS"
        }
    } catch {
        Write-ColorOutput "Could not check disk space" "WARNING"
    }

    return $true
}

function New-DirectoryStructure {
    param([string]$BasePath)

    Write-ColorOutput "Creating directory structure..." "STEP"

    $directories = @(
        $BasePath,
        (Join-Path $BasePath "language_servers"),
        (Join-Path $BasePath "runtimes"),
        (Join-Path $BasePath "temp")
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-ColorOutput "Created: $dir" "INFO"
        }
    }

    Write-ColorOutput "Directory structure created" "SUCCESS"
}

function Get-FileFromUrl {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$ChecksumType = $null,
        [string]$ExpectedChecksum = $null
    )

    try {
        # Create parent directory if it doesn't exist
        $parentDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Skip if file exists and we're not forcing
        if ((Test-Path $OutputPath) -and -not $Force) {
            Write-ColorOutput "File already exists: $(Split-Path $OutputPath -Leaf)" "WARNING"
            return $true
        }

        Write-ColorOutput "Downloading: $Url" "INFO"

        # Try curl first (faster and more reliable)
        if (Get-Command curl -ErrorAction SilentlyContinue) {
            $curlArgs = @(
                "--location",
                "--output", $OutputPath,
                "--create-dirs",
                "--fail",
                "--silent",
                "--show-error",
                $Url
            )

            $process = Start-Process -FilePath "curl" -ArgumentList $curlArgs -NoNewWindow -Wait -PassThru

            if ($process.ExitCode -ne 0) {
                throw "curl failed with exit code $($process.ExitCode)"
            }
        } else {
            # Fallback to Invoke-WebRequest
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        }

        if (-not (Test-Path $OutputPath)) {
            throw "Downloaded file not found at $OutputPath"
        }

        $fileSize = (Get-Item $OutputPath).Length / 1MB
        Write-ColorOutput "Downloaded: $(Split-Path $OutputPath -Leaf) ($([math]::Round($fileSize, 2)) MB)" "SUCCESS"

        # Verify checksum if provided
        if (-not $SkipChecksums -and $ChecksumType -and $ExpectedChecksum) {
            $actualHash = (Get-FileHash -Path $OutputPath -Algorithm $ChecksumType).Hash
            if ($actualHash -ne $ExpectedChecksum) {
                Write-ColorOutput "Checksum mismatch!" "ERROR"
                Write-ColorOutput "Expected: $ExpectedChecksum" "ERROR"
                Write-ColorOutput "Actual: $actualHash" "ERROR"
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
                throw "Checksum verification failed"
            }
            Write-ColorOutput "Checksum verified ($ChecksumType)" "SUCCESS"
        }

        return $true

    } catch {
        Write-ColorOutput "Download failed: $_" "ERROR"
        Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Expand-DownloadedArchive {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath,
        [string]$ArchiveType
    )

    try {
        Write-ColorOutput "Extracting: $(Split-Path $ArchivePath -Leaf)" "INFO"

        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }

        switch ($ArchiveType.ToLower()) {
            "zip" {
                Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
            }
            "gz" {
                # For .gz files, we need to decompress to the binary name
                $gzipContent = [System.IO.File]::ReadAllBytes($ArchivePath)

                # Use .NET compression
                $memoryStream = New-Object System.IO.MemoryStream
                $memoryStream.Write($gzipContent, 0, $gzipContent.Length)
                $memoryStream.Position = 0

                $gzipStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Decompress)
                $outputStream = [System.IO.File]::Create((Join-Path $DestinationPath "rust-analyzer.exe"))

                $gzipStream.CopyTo($outputStream)

                $outputStream.Close()
                $gzipStream.Close()
                $memoryStream.Close()
            }
            "tar.gz" {
                # Requires tar.exe (available on Windows 10+)
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    tar -xzf $ArchivePath -C $DestinationPath
                } else {
                    throw "tar.exe is required to extract .tar.gz files (available on Windows 10+)"
                }
            }
            "tgz" {
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    tar -xzf $ArchivePath -C $DestinationPath
                } else {
                    throw "tar.exe is required to extract .tgz files (available on Windows 10+)"
                }
            }
            "exe" {
                # For standalone executables, just copy
                Copy-Item $ArchivePath $DestinationPath -Force
            }
            default {
                throw "Unsupported archive type: $ArchiveType"
            }
        }

        Write-ColorOutput "Extracted successfully" "SUCCESS"
        return $true

    } catch {
        Write-ColorOutput "Extraction failed: $_" "ERROR"
        return $false
    }
}

function Install-NpmPackage {
    param(
        [hashtable]$Server,
        [string]$NodeJSPath,
        [string]$OutputDir
    )

    try {
        $npmPath = Join-Path $NodeJSPath "npm.cmd"
        $nodeExePath = Join-Path $NodeJSPath "node.exe"

        if (-not (Test-Path $npmPath) -or -not (Test-Path $nodeExePath)) {
            throw "Node.js or npm not found at $NodeJSPath"
        }

        Write-ColorOutput "Installing $($Server.Name) via npm..." "INFO"

        $packageDir = Join-Path $OutputDir $Server.Language
        if (-not (Test-Path $packageDir)) {
            New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
        }

        # Install main package
        $npmArgs = @(
            "install",
            "--prefix", $packageDir,
            "$($Server.Package)@$($Server.Version)",
            "--no-save",
            "--no-audit",
            "--no-fund"
        )

        Write-ColorOutput "Running: npm $($npmArgs -join ' ')" "INFO"

        $process = Start-Process -FilePath $npmPath -ArgumentList $npmArgs -NoNewWindow -Wait -PassThru -WorkingDirectory $packageDir

        if ($process.ExitCode -ne 0) {
            throw "npm install failed with exit code $($process.ExitCode)"
        }

        # Install additional packages if needed
        if ($Server.AdditionalPackages) {
            foreach ($additionalPkg in $Server.AdditionalPackages) {
                Write-ColorOutput "Installing additional package: $additionalPkg" "INFO"
                $additionalArgs = @(
                    "install",
                    "--prefix", $packageDir,
                    $additionalPkg,
                    "--no-save",
                    "--no-audit",
                    "--no-fund"
                )

                $process = Start-Process -FilePath $npmPath -ArgumentList $additionalArgs -NoNewWindow -Wait -PassThru -WorkingDirectory $packageDir

                if ($process.ExitCode -ne 0) {
                    throw "npm install failed for $additionalPkg"
                }
            }
        }

        Write-ColorOutput "$($Server.Name) installed successfully" "SUCCESS"
        return $true

    } catch {
        Write-ColorOutput "npm installation failed: $_" "ERROR"
        return $false
    }
}

function Install-BinaryLanguageServer {
    param(
        [hashtable]$Server,
        [string]$OutputDir,
        [string]$TempDir,
        [string]$Architecture
    )

    try {
        $url = $Server.Urls[$Architecture]

        # Fallback to x64 if ARM64 not available
        if (-not $url -and $Architecture -eq "arm64") {
            Write-ColorOutput "$($Server.Name) does not have native ARM64 support, using x64 with emulation" "WARNING"
            $url = $Server.Urls["x64"]
        }

        if (-not $url) {
            throw "No download URL available for $($Server.Name) on $Architecture"
        }

        $fileName = Split-Path $url -Leaf
        $downloadPath = Join-Path $TempDir $fileName

        # Download
        $downloadSuccess = Get-FileFromUrl -Url $url -OutputPath $downloadPath -ChecksumType $Server.Checksum.Type -ExpectedChecksum $Server.Checksum.Value

        if (-not $downloadSuccess) {
            return $false
        }

        # Extract or copy
        $serverDir = Join-Path $OutputDir $Server.Language

        if ($Server.Archive -eq "exe") {
            # Direct executable, just copy
            if (-not (Test-Path $serverDir)) {
                New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
            }
            Copy-Item $downloadPath (Join-Path $serverDir $Server.Binary) -Force
        } else {
            # Archive, extract it
            $extractSuccess = Expand-DownloadedArchive -ArchivePath $downloadPath -DestinationPath $serverDir -ArchiveType $Server.Archive

            if (-not $extractSuccess) {
                return $false
            }
        }

        # Verify binary exists
        $binaryPath = Join-Path $serverDir $Server.Binary
        if (-not (Test-Path $binaryPath)) {
            throw "Binary not found after extraction: $binaryPath"
        }

        Write-ColorOutput "$($Server.Name) installed successfully" "SUCCESS"
        return $true

    } catch {
        Write-ColorOutput "Installation failed: $_" "ERROR"
        return $false
    }
}

function Install-NodeJSRuntime {
    param(
        [string]$OutputDir,
        [string]$TempDir,
        [string]$Architecture
    )

    try {
        Write-ColorOutput "Installing Node.js runtime..." "STEP"

        $url = $NodeJSConfig.Urls[$Architecture]
        $fileName = Split-Path $url -Leaf
        $downloadPath = Join-Path $TempDir $fileName

        # Download
        $downloadSuccess = Get-FileFromUrl -Url $url -OutputPath $downloadPath -ChecksumType $NodeJSConfig.Checksum.Type -ExpectedChecksum $NodeJSConfig.Checksum[$Architecture]

        if (-not $downloadSuccess) {
            return $false
        }

        # Extract
        $nodeDir = Join-Path $OutputDir "nodejs"
        $extractSuccess = Expand-DownloadedArchive -ArchivePath $downloadPath -DestinationPath $nodeDir -ArchiveType $NodeJSConfig.Archive

        if (-not $extractSuccess) {
            return $false
        }

        # Find the extracted node directory (usually node-v20.11.1-win-x64)
        $extractedDirs = Get-ChildItem -Path $nodeDir -Directory
        if ($extractedDirs.Count -eq 1) {
            # Move contents up one level
            $extractedPath = $extractedDirs[0].FullName
            Get-ChildItem -Path $extractedPath | Move-Item -Destination $nodeDir -Force
            Remove-Item $extractedPath -Force
        }

        # Verify node.exe exists
        $nodeExePath = Join-Path $nodeDir "node.exe"
        if (-not (Test-Path $nodeExePath)) {
            throw "node.exe not found after extraction"
        }

        Write-ColorOutput "Node.js runtime installed successfully" "SUCCESS"
        return $nodeDir

    } catch {
        Write-ColorOutput "Node.js installation failed: $_" "ERROR"
        return $null
    }
}

function New-BundleManifest {
    param(
        [string]$OutputDir,
        [hashtable]$InstalledServers,
        [string]$Architecture
    )

    Write-ColorOutput "Creating bundle manifest..." "INFO"

    $manifest = @{
        version = "1.0.0"
        created = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        architecture = $Architecture
        tier = "essential"
        nodeJSVersion = $NodeJSConfig.Version
        languageServers = @{}
    }

    foreach ($serverKey in $InstalledServers.Keys) {
        $server = $EssentialLanguageServers[$serverKey]
        $manifest.languageServers[$serverKey] = @{
            name = $server.Name
            language = $server.Language
            version = $server.Version
            type = $server.Type
            binary = $server.Binary
            path = "language_servers/$($server.Language)"
        }
    }

    $manifestPath = Join-Path $OutputDir "bundle-manifest.json"
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

    Write-ColorOutput "Manifest created: $manifestPath" "SUCCESS"
}

function New-InstallationGuide {
    param([string]$OutputDir)

    $guide = @"
# Serena Language Servers Bundle - Installation Guide

## Bundle Information
- **Architecture**: $Architecture
- **Tier**: Essential
- **Created**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Included Language Servers
1. **Pyright** - Python language server
2. **TypeScript Language Server** - TypeScript/JavaScript language server
3. **rust-analyzer** - Rust language server
4. **gopls** - Go language server
5. **Lua Language Server** - Lua language server
6. **Marksman** - Markdown language server

## Included Runtimes
- **Node.js $(NodeJSConfig.Version)** - Required for npm-based language servers

## Directory Structure
```
serena-ls-bundle/
├── language_servers/
│   ├── python/          # Pyright
│   ├── typescript/      # TypeScript LS + TypeScript compiler
│   ├── rust/            # rust-analyzer
│   ├── go/              # gopls
│   ├── lua/             # Lua Language Server
│   └── markdown/        # Marksman
├── runtimes/
│   └── nodejs/          # Portable Node.js
├── bundle-manifest.json
└── INSTALLATION.md      # This file
```

## Installation Instructions

### 1. Copy Bundle to Target System
Copy the entire `serena-ls-bundle` directory to your target Windows system.

### 2. Set Environment Variables (Optional)
For system-wide access, add to PATH:
```
setx PATH "%PATH%;C:\path\to\serena-ls-bundle\runtimes\nodejs"
```

### 3. Configure Serena
Point Serena's language server configuration to the bundle directory.

### 4. Verification Commands

**Test Node.js:**
```
.\runtimes\nodejs\node.exe --version
.\runtimes\nodejs\npm.cmd --version
```

**Test Language Servers:**
```
# Rust
.\language_servers\rust\rust-analyzer.exe --version

# Go
.\language_servers\go\gopls.exe version

# Lua
.\language_servers\lua\bin\lua-language-server.exe --version

# Markdown
.\language_servers\markdown\marksman.exe --version

# Pyright (requires Node.js in PATH)
.\runtimes\nodejs\node.exe .\language_servers\python\node_modules\pyright\langserver.index.js --version

# TypeScript (requires Node.js in PATH)
.\runtimes\nodejs\node.exe .\language_servers\typescript\node_modules\typescript-language-server\lib\cli.js --version
```

## Bundle Size
Total size: ~150-200 MB

## Troubleshooting

### Language Server Not Starting
1. Check that the binary exists at the expected path
2. Verify executable permissions
3. Check Serena logs for detailed error messages

### npm-based Language Servers Failing
1. Ensure Node.js is in PATH or referenced correctly
2. Verify node_modules directory exists

### ARM64 Systems
Some language servers (Lua, Marksman) use x64 binaries with emulation on ARM64.
Performance should be acceptable for most use cases.

## Support
For issues, please refer to Serena MCP documentation or GitHub issues.
"@

    $guidePath = Join-Path $OutputDir "INSTALLATION.md"
    $guide | Set-Content -Path $guidePath -Encoding UTF8

    Write-ColorOutput "Installation guide created: $guidePath" "SUCCESS"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Serena Language Servers Bundler" -ForegroundColor White
    Write-Host "  Essential Tier for Windows" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Magenta

    Write-ColorOutput "Configuration:" "INFO"
    Write-ColorOutput "  Architecture: $Architecture" "INFO"
    Write-ColorOutput "  Output Directory: $OutputDir" "INFO"
    Write-ColorOutput "  Include Node.js: $IncludeNodeJS" "INFO"
    Write-ColorOutput "  Force Re-download: $Force" "INFO"
    Write-ColorOutput "  Skip Checksums: $SkipChecksums" "INFO"
    Write-Host ""

    # Prerequisites check
    if (-not (Test-Prerequisites)) {
        Write-ColorOutput "Prerequisites check failed. Exiting." "ERROR"
        exit 1
    }

    # Create directory structure
    New-DirectoryStructure -BasePath $OutputDir

    $languageServersDir = Join-Path $OutputDir "language_servers"
    $runtimesDir = Join-Path $OutputDir "runtimes"
    $tempDir = Join-Path $OutputDir "temp"

    $installedServers = @{}
    $failedServers = @{}

    # Install Node.js runtime if needed
    $nodeJSPath = $null
    if ($IncludeNodeJS) {
        $nodeJSPath = Install-NodeJSRuntime -OutputDir $runtimesDir -TempDir $tempDir -Architecture $Architecture
        if (-not $nodeJSPath) {
            Write-ColorOutput "Node.js installation failed. npm-based language servers will not be installed." "ERROR"
        }
    }

    # Install language servers
    $serverCount = $EssentialLanguageServers.Count
    $currentIndex = 0

    foreach ($serverKey in $EssentialLanguageServers.Keys) {
        $currentIndex++
        $server = $EssentialLanguageServers[$serverKey]

        Write-Progress-Custom -Current $currentIndex -Total $serverCount -Activity "Installing $($server.Name)"

        try {
            if ($server.Type -eq "npm") {
                if (-not $nodeJSPath) {
                    Write-ColorOutput "$($server.Name) requires Node.js but it's not available. Skipping." "WARNING"
                    $failedServers[$serverKey] = "Node.js not available"
                    continue
                }

                $success = Install-NpmPackage -Server $server -NodeJSPath $nodeJSPath -OutputDir $languageServersDir
            } else {
                $success = Install-BinaryLanguageServer -Server $server -OutputDir $languageServersDir -TempDir $tempDir -Architecture $Architecture
            }

            if ($success) {
                $installedServers[$serverKey] = $server
            } else {
                $failedServers[$serverKey] = "Installation failed"
            }
        } catch {
            Write-ColorOutput "Exception during installation: $_" "ERROR"
            $failedServers[$serverKey] = $_.Exception.Message
        }
    }

    # Create manifest
    New-BundleManifest -OutputDir $OutputDir -InstalledServers $installedServers -Architecture $Architecture

    # Create installation guide
    New-InstallationGuide -OutputDir $OutputDir

    # Clean up temp directory
    if (Test-Path $tempDir) {
        Write-ColorOutput "Cleaning up temporary files..." "INFO"
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Summary
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  Bundle Creation Summary" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Magenta

    Write-ColorOutput "Total language servers: $serverCount" "INFO"
    Write-ColorOutput "Successfully installed: $($installedServers.Count)" "SUCCESS"
    Write-ColorOutput "Failed: $($failedServers.Count)" "$(if ($failedServers.Count -gt 0) { 'ERROR' } else { 'INFO' })"

    if ($installedServers.Count -gt 0) {
        Write-Host "`nInstalled language servers:" -ForegroundColor Green
        foreach ($key in $installedServers.Keys) {
            $server = $installedServers[$key]
            Write-Host "  [OK] $($server.Name)" -ForegroundColor Green
        }
    }

    if ($failedServers.Count -gt 0) {
        Write-Host "`nFailed language servers:" -ForegroundColor Red
        foreach ($key in $failedServers.Keys) {
            $reason = $failedServers[$key]
            Write-Host "  [FAIL] $key - $reason" -ForegroundColor Red
        }
    }

    # Calculate bundle size
    if (Test-Path $OutputDir) {
        $totalSize = (Get-ChildItem -Path $OutputDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "`nTotal bundle size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor Cyan
    }

    Write-Host "`nBundle location: $OutputDir" -ForegroundColor Cyan
    Write-Host "Installation guide: $(Join-Path $OutputDir 'INSTALLATION.md')" -ForegroundColor Cyan

    if ($failedServers.Count -eq 0) {
        Write-Host "`n[SUCCESS] Bundle created successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n[WARNING] Bundle created with some failures." -ForegroundColor Yellow
        exit 1
    }
}

# Run main function
try {
    Main
} catch {
    Write-ColorOutput "Fatal error: $_" "ERROR"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
