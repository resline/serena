#Requires -Version 5.1

<#
.SYNOPSIS
    Downloads language servers for Serena portable build

.DESCRIPTION
    Downloads and extracts language servers based on tier selection.
    Supports minimal, essential, complete, and full tiers.

.PARAMETER Tier
    The tier of language servers to download (minimal, essential, complete, full)

.PARAMETER OutputDir
    Directory to download language servers to (default: .\language-servers)

.PARAMETER Force
    Force re-download even if files exist

.PARAMETER Parallel
    Number of parallel downloads (default: 4)

.PARAMETER Architecture
    Target architecture (x64, x86, arm64) (default: x64)

.EXAMPLE
    .\download-language-servers.ps1 -Tier essential
    
.EXAMPLE
    .\download-language-servers.ps1 -Tier full -OutputDir "C:\serena\ls" -Force

.EXAMPLE
    .\download-language-servers.ps1 -Tier essential -Architecture arm64
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("minimal", "essential", "complete", "full")]
    [string]$Tier,
    
    [string]$OutputDir = ".\language-servers",
    
    [switch]$Force,
    
    [int]$Parallel = 4,
    
    [ValidateSet("x64", "x86", "arm64")]
    [string]$Architecture = "x64"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }

# Global script directory for manifest loading
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Get-ArchitectureUrls {
    param(
        [string]$BaseUrl,
        [string]$Architecture
    )
    
    # Map architecture strings and provide ARM64 URLs where available
    switch ($Architecture.ToLower()) {
        "arm64" {
            switch -Wildcard ($BaseUrl) {
                "*rust-analyzer*" { return $BaseUrl -replace "x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc" }
                "*gopls*" { return $BaseUrl -replace "windows_amd64", "windows_arm64" }
                "*clangd*" { return $BaseUrl } # No ARM64 binary available, will use emulation
                "*zls*" { return $BaseUrl -replace "x86_64-windows", "aarch64-windows" }
                "*terraform-ls*" { return $BaseUrl -replace "windows_amd64", "windows_arm64" }  
                "*clojure-lsp*" { return $BaseUrl } # No ARM64 binary available, will use emulation
                default { return $BaseUrl } # Fallback to x64 for emulation
            }
        }
        "x86" {
            # Most servers don't have x86 builds, fallback to x64
            return $BaseUrl
        }
        default {
            return $BaseUrl
        }
    }
}

function Test-Arm64Support {
    param([string]$ServerName, [string]$Architecture)
    
    if ($Architecture -ne "arm64") {
        return $true
    }
    
    # List of servers with native ARM64 support
    $arm64Supported = @(
        "rust-analyzer", "gopls", "zls", "terraform-ls", "pyright", "typescript-language-server", 
        "bash-language-server", "intelephense", "ruby-lsp", "solargraph",
        "jedi-language-server", "vtsls", "csharp-language-server"
    )
    
    # Check if server has ARM64 support
    $hasArm64 = $arm64Supported | Where-Object { $ServerName -like "*$_*" }
    
    if (-not $hasArm64) {
        Write-Warning "${ServerName}: No native ARM64 support available, will use x64 with emulation"
        return $false  # Will use emulation
    }
    
    return $true
}

# Language server definitions by tier
$LanguageServers = @{
    "essential" = @(
        @{
            Name = "Python (Pyright)"
            Language = "python"
            Url = "https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz"
            Archive = "tgz"
            Binary = "pyright-langserver.js"
            Commands = @("npm install -g pyright")
            Checksum = $null
        },
        @{
            Name = "TypeScript Language Server"
            Language = "typescript"
            Url = "https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz"
            Archive = "tgz" 
            Binary = "typescript-language-server.js"
            Commands = @("npm install -g typescript-language-server", "npm install -g typescript")
            Checksum = $null
        },
        @{
            Name = "C# Language Server"
            Language = "csharp"
            Url = "https://github.com/razzmatazz/csharp-language-server/releases/latest/download/csharp-ls-win-x64.zip"
            Archive = "zip"
            Binary = "csharp-ls.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Go Language Server (gopls)"
            Language = "go"
            Url = "https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip"
            Archive = "zip"
            Binary = "gopls.exe"
            Commands = $null
            Checksum = $null
        }
    )
    
    "complete" = @(
        @{
            Name = "Java Language Server (Eclipse JDT-LS)"
            Language = "java"
            Url = "https://download.eclipse.org/jdtls/milestones/1.50.0/jdt-language-server-1.50.0-202409261450.tar.gz"
            Archive = "tar.gz"
            Binary = "bin/jdtls"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Rust Analyzer"
            Language = "rust"
            Url = "https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.zip"
            Archive = "zip"
            Binary = "rust-analyzer.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Kotlin Language Server"
            Language = "kotlin"
            Url = "https://github.com/fwcd/kotlin-language-server/releases/latest/download/server.zip"
            Archive = "zip"
            Binary = "server/bin/kotlin-language-server.bat"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Clojure LSP"
            Language = "clojure"
            Url = "https://github.com/clojure-lsp/clojure-lsp/releases/latest/download/clojure-lsp-native-windows-amd64.zip"
            Archive = "zip"
            Binary = "clojure-lsp.exe"
            Commands = $null
            Checksum = $null
        }
    )
    
    "extended" = @(
        @{
            Name = "Ruby LSP"
            Language = "ruby"
            Url = $null # Gem install
            Archive = $null
            Binary = "ruby-lsp"
            Commands = @("gem install ruby-lsp")
            Checksum = $null
        },
        @{
            Name = "PHP Language Server (Intelephense)"
            Language = "php"
            Url = "https://registry.npmjs.org/intelephense/-/intelephense-1.10.4.tgz"
            Archive = "tgz"
            Binary = "intelephense.js"
            Commands = @("npm install -g intelephense")
            Checksum = $null
        },
        @{
            Name = "Dart Language Server"
            Language = "dart"
            Url = $null # Part of Dart SDK
            Archive = $null
            Binary = "dart"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Swift Language Server (SourceKit-LSP)"
            Language = "swift"
            Url = $null # Part of Swift toolchain
            Archive = $null
            Binary = "sourcekit-lsp.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Clangd (C/C++)"
            Language = "cpp"
            Url = "https://github.com/clangd/clangd/releases/download/19.1.2/clangd-windows-19.1.2.zip"
            Archive = "zip"
            Binary = "bin/clangd.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Terraform Language Server"
            Language = "terraform"
            Url = "https://releases.hashicorp.com/terraform-ls/0.33.2/terraform-ls_0.33.2_windows_amd64.zip"
            Archive = "zip"
            Binary = "terraform-ls.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "R Language Server"
            Language = "r"
            Url = $null # R package
            Archive = $null
            Binary = "R.exe"
            Commands = @("R -e `"install.packages('languageserver')`"")
            Checksum = $null
        },
        @{
            Name = "Bash Language Server"
            Language = "bash"
            Url = "https://registry.npmjs.org/bash-language-server/-/bash-language-server-5.4.0.tgz"
            Archive = "tgz"
            Binary = "bash-language-server.js"
            Commands = @("npm install -g bash-language-server")
            Checksum = $null
        }
    )
    
    "full" = @(
        @{
            Name = "Elixir Language Server (Next LS)"
            Language = "elixir"
            Url = "https://github.com/elixir-tools/next-ls/releases/latest/download/next_ls_windows_amd64.exe"
            Archive = "exe"
            Binary = "next_ls_windows_amd64.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Erlang Language Server"
            Language = "erlang"
            Url = "https://github.com/erlang-ls/erlang_ls/releases/latest/download/erlang_ls_windows.zip"
            Archive = "zip"
            Binary = "erlang_ls.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Lua Language Server"
            Language = "lua"
            Url = "https://github.com/LuaLS/lua-language-server/releases/latest/download/lua-language-server-3.7.4-win32-x64.zip"
            Archive = "zip"
            Binary = "bin/lua-language-server.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Zig Language Server"
            Language = "zig"
            Url = "https://github.com/zigtools/zls/releases/latest/download/zls-windows-x86_64.zip"
            Archive = "zip"
            Binary = "zls.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "Nix Language Server (nixd)"
            Language = "nix"
            Url = $null # Built from source or Nix package
            Archive = $null
            Binary = "nixd.exe"
            Commands = $null
            Checksum = $null
        },
        @{
            Name = "AL Language Server"
            Language = "al"
            Url = $null # VS Code extension
            Archive = $null
            Binary = "ALLanguageServer.exe"
            Commands = $null
            Checksum = $null
        }
    )
}

function Get-ServersForTier {
    param([string]$TierName)
    
    $servers = @()
    switch ($TierName) {
        "minimal" { 
            # No language servers for minimal tier
            $servers = @()
        }
        "essential" { 
            $servers += $LanguageServers["essential"]
        }
        "complete" { 
            $servers += $LanguageServers["essential"]
            $servers += $LanguageServers["complete"]
        }
        "full" { 
            $servers += $LanguageServers["essential"]
            $servers += $LanguageServers["complete"]
            $servers += $LanguageServers["extended"]
            $servers += $LanguageServers["full"]
        }
    }
    return $servers
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check if we have required tools
    $requiredTools = @("powershell", "curl")
    $missingTools = @()
    
    foreach ($tool in $requiredTools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missingTools += $tool
        }
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        exit 1
    }
    
    # Check for optional tools
    $optionalTools = @("node", "npm", "gem", "R")
    foreach ($tool in $optionalTools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Success "$tool is available"
        } else {
            Write-Warning "$tool not found - some language servers may not be installable"
        }
    }
    
    Write-Success "Prerequisites check completed"
}

function New-DirectoryIfNotExists {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Info "Creating directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-FileHash-Safe {
    param(
        [string]$Path,
        [string]$Algorithm = "SHA256"
    )
    
    try {
        return (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash
    } catch {
        Write-Warning "Could not compute hash for $Path"
        return $null
    }
}

function Invoke-DownloadFile {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$ExpectedChecksum = $null
    )
    
    Write-Info "Downloading $Url to $OutputPath"
    
    try {
        # Use curl for reliable downloads with progress
        $curlArgs = @(
            "--location",
            "--output", $OutputPath,
            "--create-dirs",
            "--progress-bar",
            "--fail",
            $Url
        )
        
        $process = Start-Process -FilePath "curl" -ArgumentList $curlArgs -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "curl failed with exit code $($process.ExitCode)"
        }
        
        if (-not (Test-Path $OutputPath)) {
            throw "Downloaded file not found at $OutputPath"
        }
        
        # Verify checksum if provided
        if ($ExpectedChecksum) {
            $actualHash = Get-FileHash-Safe -Path $OutputPath
            if ($actualHash -and $actualHash -ne $ExpectedChecksum) {
                Write-Error "Checksum mismatch for $OutputPath"
                Write-Error "Expected: $ExpectedChecksum"
                Write-Error "Actual: $actualHash"
                Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
                throw "Checksum verification failed"
            }
            Write-Success "Checksum verified"
        }
        
        Write-Success "Downloaded successfully: $(Split-Path $OutputPath -Leaf)"
        return $true
        
    } catch {
        Write-Error "Failed to download $Url`: $_"
        Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Expand-Archive-Safe {
    param(
        [string]$Path,
        [string]$DestinationPath,
        [string]$ArchiveType
    )
    
    Write-Info "Extracting $Path to $DestinationPath"
    
    try {
        New-DirectoryIfNotExists -Path $DestinationPath
        
        switch ($ArchiveType.ToLower()) {
            "zip" {
                Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force
            }
            "tar.gz" {
                # Use tar if available, otherwise 7zip
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    tar -xzf $Path -C $DestinationPath
                } else {
                    throw "tar.gz extraction requires tar command"
                }
            }
            "tgz" {
                if (Get-Command tar -ErrorAction SilentlyContinue) {
                    tar -xzf $Path -C $DestinationPath
                } else {
                    throw "tgz extraction requires tar command"
                }
            }
            "exe" {
                # For .exe files, just copy to destination
                Copy-Item $Path $DestinationPath -Force
            }
            default {
                throw "Unsupported archive type: $ArchiveType"
            }
        }
        
        Write-Success "Extracted successfully"
        return $true
        
    } catch {
        Write-Error "Failed to extract $Path`: $_"
        return $false
    }
}

function Install-LanguageServerCommands {
    param(
        [array]$Commands,
        [string]$Language
    )
    
    if (-not $Commands) {
        return $true
    }
    
    Write-Info "Running installation commands for $Language"
    
    foreach ($command in $Commands) {
        Write-Info "Executing: $command"
        
        try {
            $result = Invoke-Expression $command
            Write-Success "Command completed successfully"
        } catch {
            Write-Error "Command failed: $command"
            Write-Error $_
            return $false
        }
    }
    
    return $true
}

function Install-LanguageServer {
    param(
        [hashtable]$Server,
        [string]$BaseOutputDir,
        [string]$Architecture = "x64"
    )
    
    $languageDir = Join-Path $BaseOutputDir $Server.Language
    New-DirectoryIfNotExists -Path $languageDir
    
    # Check ARM64 support and provide appropriate warnings
    $hasNativeSupport = Test-Arm64Support -ServerName $Server.Name -Architecture $Architecture
    $statusText = if ($hasNativeSupport) { "native $Architecture" } else { "x64 (emulated)" }
    
    Write-Info "Installing $($Server.Name) [$statusText]..."
    
    # Handle command-based installations (npm, gem, etc.)
    if ($Server.Commands) {
        if ($Architecture -eq "arm64" -and -not $hasNativeSupport) {
            Write-Warning "Using x64 binaries with ARM64 emulation for $($Server.Name)"
        }
        return Install-LanguageServerCommands -Commands $Server.Commands -Language $Server.Language
    }
    
    # Handle URL-based installations
    if ($Server.Url) {
        # Get architecture-appropriate URL
        $actualUrl = Get-ArchitectureUrls -BaseUrl $Server.Url -Architecture $Architecture
        
        $fileName = Split-Path $actualUrl -Leaf
        $downloadPath = Join-Path $languageDir $fileName
        
        # Skip if already exists and not forcing
        if ((Test-Path $downloadPath) -and -not $Force) {
            Write-Warning "File already exists, skipping: $downloadPath"
            return $true
        }
        
        # Show emulation warning if using fallback URL
        if ($Architecture -eq "arm64" -and $actualUrl -eq $Server.Url -and -not $hasNativeSupport) {
            Write-Warning "Using x64 binary with ARM64 emulation for $($Server.Name)"
        }
        
        # Download the file
        if (-not (Invoke-DownloadFile -Url $actualUrl -OutputPath $downloadPath -ExpectedChecksum $Server.Checksum)) {
            Write-Error "Failed to download $($Server.Name) from $actualUrl"
            return $false
        }
        
        # Extract if it's an archive
        if ($Server.Archive -and $Server.Archive -ne "exe") {
            $extractDir = Join-Path $languageDir "extracted"
            if (-not (Expand-Archive-Safe -Path $downloadPath -DestinationPath $extractDir -ArchiveType $Server.Archive)) {
                Write-Error "Failed to extract $($Server.Name) archive: $downloadPath"
                return $false
            }
            
            # Clean up archive file to save space
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        }
        
        return $true
    }
    
    # Handle servers that need manual installation
    Write-Warning "$($Server.Name) requires manual installation or is part of a larger toolchain"
    return $true
}

function Show-Summary {
    param(
        [array]$Servers,
        [array]$SuccessfulInstalls,
        [array]$FailedInstalls
    )
    
    Write-Host ""
    Write-Host "=== Installation Summary ===" -ForegroundColor Magenta
    Write-Host "Tier: $Tier" -ForegroundColor Cyan
    Write-Host "Total servers: $($Servers.Count)" -ForegroundColor Cyan
    Write-Host "Successful: $($SuccessfulInstalls.Count)" -ForegroundColor Green
    Write-Host "Failed: $($FailedInstalls.Count)" -ForegroundColor Red
    
    if ($SuccessfulInstalls.Count -gt 0) {
        Write-Host ""
        Write-Host "Successfully installed:" -ForegroundColor Green
        foreach ($server in $SuccessfulInstalls) {
            Write-Host "  [OK] $($server.Name)" -ForegroundColor Green
        }
    }
    
    if ($FailedInstalls.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed to install:" -ForegroundColor Red
        foreach ($server in $FailedInstalls) {
            Write-Host "  [FAIL] $($server.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Output directory: $OutputDir" -ForegroundColor Cyan
}

# Main execution
try {
    Write-Host "=== Serena Language Server Downloader ===" -ForegroundColor Magenta
    Write-Host "Tier: $Tier" -ForegroundColor Cyan
    Write-Host "Architecture: $Architecture" -ForegroundColor Cyan
    Write-Host "Output: $OutputDir" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Prerequisites
    
    $servers = Get-ServersForTier -TierName $Tier
    Write-Info "Found $($servers.Count) language servers for tier '$Tier'"
    
    New-DirectoryIfNotExists -Path $OutputDir
    
    $successfulInstalls = @()
    $failedInstalls = @()
    $totalServers = $servers.Count
    $currentIndex = 0
    
    foreach ($server in $servers) {
        $currentIndex++
        $progress = [math]::Round(($currentIndex / $totalServers) * 100, 1)
        
        Write-Host ""
        Write-Host "[$currentIndex/$totalServers] ($progress%) Installing $($server.Name)..." -ForegroundColor Yellow
        
        if (Install-LanguageServer -Server $server -BaseOutputDir $OutputDir -Architecture $Architecture) {
            $successfulInstalls += $server
        } else {
            $failedInstalls += $server
        }
    }
    
    Show-Summary -Servers $servers -SuccessfulInstalls $successfulInstalls -FailedInstalls $failedInstalls
    
    if ($failedInstalls.Count -gt 0) {
        Write-Host ""
        Write-Warning "Some language servers failed to install. The portable build may have limited functionality."
        exit 1
    }
    
    Write-Host ""
    Write-Success "All language servers downloaded successfully!"
    exit 0
    
} catch {
    Write-Error "Script failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}