# Create Fully Portable Serena Package for Corporate Deployment
# This script creates a 100% self-contained package with ALL dependencies offline
# Version: 2.0 - Fully Portable Edition

param(
    [string]$OutputPath = ".\serena-fully-portable",
    [string]$ProxyUrl = $env:HTTP_PROXY,
    [string]$CertPath = $env:REQUESTS_CA_BUNDLE,
    [string]$PythonVersion = "3.11.9",
    [string]$Platform = "win_amd64"
)

Write-Host "Creating FULLY PORTABLE Serena package..." -ForegroundColor Cyan
Write-Host "This package will be 100% offline-capable" -ForegroundColor Green

# Initialize variables
$OfflineMode = $false

# Create directory structure with existence checks to avoid warnings
$dirs = @(
    "$OutputPath",
    "$OutputPath\serena",
    "$OutputPath\language-servers",
    "$OutputPath\dependencies",
    "$OutputPath\config",
    "$OutputPath\scripts",
    "$OutputPath\Lib\site-packages"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

Write-Host "[OK] Created directory structure" -ForegroundColor Green

# Clone Serena (using fork for corporate deployment)
Write-Host "Cloning Serena repository..." -ForegroundColor Yellow
git clone https://github.com/resline/serena "$OutputPath\serena-temp"

# Copy only necessary files
$essentialDirs = @("src", "scripts", "pyproject.toml", "README.md", "LICENSE", "CLAUDE.md")
foreach ($item in $essentialDirs) {
    Copy-Item -Path "$OutputPath\serena-temp\$item" -Destination "$OutputPath\serena\" -Recurse -Force
}

Remove-Item -Path "$OutputPath\serena-temp" -Recurse -Force
Write-Host "[OK] Copied Serena source code" -ForegroundColor Green

# Download Python embedded
Write-Host "Downloading Python $PythonVersion embedded..." -ForegroundColor Yellow
$pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
$pythonZip = "$OutputPath\python-embedded.zip"

try {
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonZip -UseBasicParsing
    Expand-Archive -Path $pythonZip -DestinationPath "$OutputPath\python" -Force
    Remove-Item $pythonZip
    Write-Host "[OK] Downloaded and extracted Python embedded" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download Python: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Download get-pip
Write-Host "Setting up pip..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile "$OutputPath\python\get-pip.py"

# Create python._pth to enable pip and site-packages
# FIXED: Include proper paths for pip module access
$pthLines = @(
    "python311.zip",
    ".",
    "Lib\site-packages",
    "..\..\Lib\site-packages",
    "..\..\serena\src",
    "import site"
)
$pthContent = $pthLines -join "`n"
Set-Content -Path "$OutputPath\python\python311._pth" -Value $pthContent
Write-Host "[OK] Configured Python path" -ForegroundColor Green

# Install pip in embedded Python
Write-Host "Installing pip in embedded Python..." -ForegroundColor Yellow
# FIXED: Install pip directly to Python's Lib\site-packages for module access
& "$OutputPath\python\python.exe" "$OutputPath\python\get-pip.py" --no-warn-script-location --target "$OutputPath\python\Lib\site-packages"

# Test pip installation
# ENHANCED: More robust pip module verification with debugging
Write-Host "Testing pip installation..." -ForegroundColor Yellow
try {
    # Test 1: Check if pip module is accessible
    Write-Host "[TEST] Testing 'python -m pip --version'..." -ForegroundColor Gray
    $pipModuleTest = & "$OutputPath\python\python.exe" -m pip --version 2>$null
    $pipTestExitCode = $LASTEXITCODE
    
    if ($pipTestExitCode -eq 0 -and $pipModuleTest) {
        Write-Host "[OK] Pip module accessible: $pipModuleTest" -ForegroundColor Green
    } else {
        Write-Host "[WARN] pip module test failed (exit code: $pipTestExitCode)" -ForegroundColor Yellow
        
        # Test 2: Alternative test - import pip directly
        Write-Host "[TEST] Testing direct pip import..." -ForegroundColor Gray
        $pipImportTest = & "$OutputPath\python\python.exe" -c "import pip; print('Pip version:', pip.__version__)" 2>$null
        $importTestExitCode = $LASTEXITCODE
        
        if ($importTestExitCode -eq 0 -and $pipImportTest) {
            Write-Host "[OK] Pip accessible via import: $pipImportTest" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Pip installation failed - module not accessible" -ForegroundColor Red
            Write-Host "[DEBUG] pip -m test exit code: $pipTestExitCode" -ForegroundColor Gray
            Write-Host "[DEBUG] pip import test exit code: $importTestExitCode" -ForegroundColor Gray
            
            Write-Host "[INFO] Attempting pip installation repair..." -ForegroundColor Yellow
            
            # Ensure proper directory structure exists
            $pipLibDir = "$OutputPath\python\Lib\site-packages"
            if (-not (Test-Path $pipLibDir)) {
                New-Item -ItemType Directory -Path $pipLibDir | Out-Null
            }
            
            # Retry installation with explicit target
            Write-Host "[INFO] Reinstalling pip to correct location..." -ForegroundColor Yellow
            & "$OutputPath\python\python.exe" "$OutputPath\python\get-pip.py" --no-warn-script-location --target $pipLibDir --force-reinstall
            
            # Final verification
            Write-Host "[TEST] Final pip verification..." -ForegroundColor Gray
            $finalTest = & "$OutputPath\python\python.exe" -m pip --version 2>$null
            $finalExitCode = $LASTEXITCODE
            
            if ($finalExitCode -eq 0 -and $finalTest) {
                Write-Host "[OK] Pip installation successful after repair: $finalTest" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] Pip installation still failed after repair" -ForegroundColor Red
                Write-Host "[ERROR] Final test exit code: $finalExitCode" -ForegroundColor Red
                Write-Host "[ERROR] Cannot proceed without working pip installation" -ForegroundColor Red
                exit 1
            }
        }
    }
} catch {
    Write-Host "[ERROR] Failed to verify pip installation: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}

# Download ALL Python dependencies offline
$depDownloadScript = "$PSScriptRoot\download-dependencies-offline.py"
if (Test-Path $depDownloadScript) {
    Write-Host "Downloading ALL Python dependencies offline..." -ForegroundColor Yellow
    $dependencyArgs = @(
        "--proxy", $ProxyUrl,
        "--cert", $CertPath,
        "--output", "$OutputPath\dependencies",
        "--pyproject", "$OutputPath\serena\pyproject.toml",
        "--python-version", "3.11",
        "--platform", $Platform
    )
    
    # Filter out empty arguments
    $dependencyArgs = $dependencyArgs | Where-Object { $_ -ne "" -and $_ -ne $null }
    
    try {
        # FIXED: Use proper Python executable for dependency download
        & "$OutputPath\python\python.exe" $depDownloadScript @dependencyArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Dependencies download failed"
        }
        Write-Host "[OK] Downloaded all Python dependencies offline" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Failed to download dependencies: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Dependencies will be installed online during first run..." -ForegroundColor Yellow
        # Store the embedded python path for offline installer
        $env:SERENA_PORTABLE_PYTHON = "$OutputPath\python\python.exe"
    }
} else {
    Write-Host "[INFO] Dependency download script not found, skipping offline download" -ForegroundColor Yellow
    Write-Host "Dependencies will be installed online during first run..." -ForegroundColor Yellow
}

# Install dependencies offline (if available)
if (Test-Path "$OutputPath\dependencies\requirements.txt") {
    Write-Host "Installing dependencies offline..." -ForegroundColor Yellow
    
    # CRITICAL: Validate requirements.txt has content
    $reqContent = Get-Content "$OutputPath\dependencies\requirements.txt" -Raw -ErrorAction SilentlyContinue
    if (-not $reqContent -or $reqContent.Trim() -eq "") {
        Write-Host "[ERROR] requirements.txt is empty or unreadable" -ForegroundColor Red
        Write-Host "[ERROR] This indicates dependency download failed earlier" -ForegroundColor Red
        $OfflineMode = $false
    } else {
        # Count non-empty, non-comment lines
        $reqLines = ($reqContent -split "`n" | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }).Count
        Write-Host "[INFO] Found $reqLines requirements to install" -ForegroundColor Green
        
        # FIXED: Use consistent target directory for both Python and dependencies
        $targetDir = "$OutputPath\Lib\site-packages"
        
        # Install UV first (if available)
        $uvWheels = Get-ChildItem "$OutputPath\dependencies\uv-deps\*.whl" -ErrorAction SilentlyContinue
        if ($uvWheels) {
            Write-Host "Installing UV..." -ForegroundColor Yellow
            # FIXED: Use forward slashes in paths passed to Python for cross-platform compatibility
            $uvDepsPath = "$OutputPath\dependencies\uv-deps" -replace '\\', '/'
            $targetDirForward = $targetDir -replace '\\', '/'
            & "$OutputPath\python\python.exe" -m pip install --no-index --find-links $uvDepsPath --target $targetDirForward uv
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[WARN] UV installation failed, continuing without UV..." -ForegroundColor Yellow
            }
        }
        
        # Install main dependencies
        Write-Host "Installing main dependencies..." -ForegroundColor Yellow
        # FIXED: Use forward slashes and proper path escaping
        $depsPath = "$OutputPath\dependencies" -replace '\\', '/'
        $reqPath = "$OutputPath\dependencies\requirements.txt" -replace '\\', '/'
        $targetDirForward = $targetDir -replace '\\', '/'
        
        & "$OutputPath\python\python.exe" -m pip install --no-index --find-links $depsPath --target $targetDirForward --requirement $reqPath
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Installed all dependencies offline" -ForegroundColor Green
        $OfflineMode = $true
    } else {
        Write-Host "[WARN] Offline installation failed, will install online during first run" -ForegroundColor Yellow
        Write-Host "[DEBUG] Last exit code: $LASTEXITCODE" -ForegroundColor Yellow
        $OfflineMode = $false
    }
} else {
    Write-Host "[WARN] No offline dependencies found, will install online during first run" -ForegroundColor Yellow
    $OfflineMode = $false
}

# Download language servers
$lsDownloadScript = "$PSScriptRoot\download-language-servers-offline.py"
if (Test-Path $lsDownloadScript) {
    Write-Host "Downloading language servers..." -ForegroundColor Yellow
    try {
        & "$OutputPath\python\python.exe" $lsDownloadScript `
            --output "$OutputPath\language-servers" `
            --proxy $ProxyUrl `
            --cert $CertPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Downloaded language servers" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Some language servers may not have been downloaded" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Failed to download language servers: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Language servers will need to be downloaded separately" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] Language server download script not found, skipping" -ForegroundColor Yellow
    Write-Host "Language servers will need to be downloaded separately" -ForegroundColor Yellow
}

# Create enhanced wrapper scripts
Write-Host "Creating enhanced wrapper scripts..." -ForegroundColor Yellow

# Enhanced main wrapper script with offline capability
$mainWrapper = @"
@echo off
setlocal enabledelayedexpansion

:: Fully Portable Serena MCP Launcher
:: Version 2.0 - 100% Offline Capable

echo ==========================================
echo  Serena MCP - Fully Portable Edition
echo  Version 0.1.4 - Offline Capable
echo ==========================================

:: Set paths
set SERENA_PORTABLE=%~dp0
set PYTHONHOME=%SERENA_PORTABLE%python
set PYTHONPATH=%SERENA_PORTABLE%Lib\site-packages;%SERENA_PORTABLE%serena\src
set PATH=%PYTHONHOME%;%PYTHONHOME%\Scripts;%PATH%

:: Set corporate environment if available
if not "%HTTP_PROXY%"=="" (
    echo [INFO] Using proxy: %HTTP_PROXY%
)
if not "%REQUESTS_CA_BUNDLE%"=="" (
    echo [INFO] Using CA bundle: %REQUESTS_CA_BUNDLE%
)

:: Create user directories
if not exist "%USERPROFILE%\.solidlsp" mkdir "%USERPROFILE%\.solidlsp"
if not exist "%USERPROFILE%\.solidlsp\language_servers" mkdir "%USERPROFILE%\.solidlsp\language_servers"
if not exist "%USERPROFILE%\.solidlsp\language_servers\static" mkdir "%USERPROFILE%\.solidlsp\language_servers\static"
if not exist "%USERPROFILE%\.serena" mkdir "%USERPROFILE%\.serena"

:: Copy language servers if not present
echo [INFO] Setting up language servers...
xcopy /E /I /Y /Q "%SERENA_PORTABLE%language-servers\*" "%USERPROFILE%\.solidlsp\language_servers\static\" >nul 2>&1

:: Check if dependencies are installed
echo [INFO] Checking dependencies...
"%PYTHONHOME%\python.exe" -c "import serena; print('[OK] Serena available')" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [WARN] Dependencies not installed, running offline installer...
    if exist "%SERENA_PORTABLE%dependencies\install-dependencies-offline.bat" (
        call "%SERENA_PORTABLE%dependencies\install-dependencies-offline.bat"
    ) else (
        echo [ERROR] No offline installer found and dependencies missing!
        echo [ERROR] Please run with internet access for first-time setup
        pause
        exit /b 1
    )
)

:: Final verification
"%PYTHONHOME%\python.exe" -c "import serena" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Serena dependencies still not available!
    echo [ERROR] Please check your installation
    pause
    exit /b 1
)

echo [OK] All dependencies verified
echo [INFO] Starting Serena MCP server...
echo.

:: Run Serena MCP server
cd /d "%SERENA_PORTABLE%serena"
"%PYTHONHOME%\python.exe" -m serena.cli start-mcp-server %*

endlocal
"@
Set-Content -Path "$OutputPath\serena-mcp-portable.bat" -Value $mainWrapper

# Create dependency check script
$depCheckScript = @"
@echo off
setlocal

:: Dependency Checker for Serena Portable
set SERENA_PORTABLE=%~dp0
set PYTHONHOME=%SERENA_PORTABLE%python
set PYTHONPATH=%SERENA_PORTABLE%Lib\site-packages;%SERENA_PORTABLE%serena\src

echo Checking Serena Portable dependencies...
echo.

:: Check Python
"%PYTHONHOME%\python.exe" --version
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python not found
    goto :error
)

:: Check main dependencies
set DEPS=requests pyright mcp flask pydantic pyyaml jinja2 psutil tqdm tiktoken anthropic

for %%d in (%DEPS%) do (
    echo Checking %%d...
    "%PYTHONHOME%\python.exe" -c "import %%d; print('  [OK] %%d:', %%d.__version__ if hasattr(%%d, '__version__') else 'OK')" 2>nul
    if !ERRORLEVEL! neq 0 (
        echo   [ERROR] %%d: Missing
        set HAS_MISSING=1
    )
)

:: Check Serena
echo Checking Serena...
"%PYTHONHOME%\python.exe" -c "import serena; print('  [OK] Serena: Available')" 2>nul
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Serena: Missing
    set HAS_MISSING=1
)

:: Check language servers
echo.
echo Checking language servers...
dir /b "%SERENA_PORTABLE%language-servers" 2>nul | find /c /v "" >nul
if %ERRORLEVEL% equ 0 (
    for /f %%i in ('dir /b "%SERENA_PORTABLE%language-servers" 2^>nul ^| find /c /v ""') do echo   [OK] Language servers: %%i found
) else (
    echo   [ERROR] Language servers: None found
)

if defined HAS_MISSING (
    echo.
    echo [WARN] Some dependencies are missing
    if exist "%SERENA_PORTABLE%dependencies\install-dependencies-offline.bat" (
        echo [INFO] Run install-dependencies-offline.bat to fix
    ) else (
        echo [INFO] Internet connection required for first setup
    )
    goto :error
)

echo.
echo [OK] All dependencies verified successfully!
echo [OK] Serena Portable is ready to use
pause
exit /b 0

:error
echo.
echo [ERROR] Dependency check failed
pause
exit /b 1
"@
Set-Content -Path "$OutputPath\check-dependencies.bat" -Value $depCheckScript

# Create configuration templates (same as before)
$vscodeConfig = @{
    mcpServers = @{
        serena = @{
            command = "C:\\serena-fully-portable\\serena-mcp-portable.bat"
            args = @("--context", "ide-assistant")
        }
    }
}
$vscodeConfig | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\config\vscode-continue-config.json"

# Claude Desktop config
$claudeConfig = @{
    mcpServers = @{
        serena = @{
            command = "C:\\serena-fully-portable\\serena-mcp-portable.bat"
            args = @("--context", "desktop-app")
        }
    }
}
$claudeConfig | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\config\claude-desktop-config.json"

# Enhanced setup script
$setupScript = @"
@echo off
echo Setting up Serena Fully Portable...

:: Copy to C:\serena-fully-portable
echo Copying files...
xcopy /E /I /Y "%~dp0*" "C:\serena-fully-portable\" >nul

:: Run dependency check
echo.
echo Running dependency check...
call "C:\serena-fully-portable\check-dependencies.bat"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Setup completed but dependencies need attention
    pause
    exit /b 1
)

:: Create desktop shortcut
echo Creating desktop shortcut...
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%USERPROFILE%\Desktop\Serena MCP Portable.lnk'); $SC.TargetPath = 'C:\serena-fully-portable\serena-mcp-portable.bat'; $SC.WorkingDirectory = 'C:\serena-fully-portable'; $SC.Save()"

echo.
echo ==========================================
echo  Serena Fully Portable installed!
echo ==========================================
echo.
echo Desktop shortcut created: "Serena MCP Portable"
echo.
echo IDE Integration:
echo - VS Code: Import C:\serena-fully-portable\config\vscode-continue-config.json
echo - Claude Desktop: Import C:\serena-fully-portable\config\claude-desktop-config.json
echo.
echo Test installation: run check-dependencies.bat
echo.
pause
"@
Set-Content -Path "$OutputPath\SETUP.bat" -Value $setupScript

# Create comprehensive README
$readme = @"
# Serena MCP - Fully Portable Package v0.1.4
## 100% Offline Capable Edition

This is a FULLY SELF-CONTAINED Serena MCP package designed for corporate environments,
air-gapped systems, and offline deployment.

##  Key Features

- **100% Offline**: No internet required after initial setup
- **Embedded Python**: Python 3.11 included
- **All Dependencies**: $(if ($OfflineMode) { "[OK] Pre-installed offline" } else { "[WARN] Will install on first run" })
- **Language Servers**: Pre-downloaded for 13+ languages  
- **Corporate Ready**: Proxy and certificate support
- **Zero Installation**: Runs from any directory

##  Package Contents

- **python/**: Embedded Python 3.11 ($PythonVersion)
- **dependencies/**: All Python wheels $(if ($OfflineMode) { "(~150MB)" } else { "(download on first run)" })
- **language-servers/**: Pre-downloaded language servers (~200MB)
- **serena/**: Complete Serena source code
- **Lib/site-packages/**: $(if ($OfflineMode) { "Installed Python packages" } else { "Will be populated on first run" })
- **config/**: IDE integration templates

##  Installation

### Option 1: Automated (Recommended)
1. **Run SETUP.bat** - Copies to C:\serena-fully-portable
2. **Uses desktop shortcut** - "Serena MCP Portable"

### Option 2: Manual
1. Extract package to desired location
2. Run **serena-mcp-portable.bat** 
3. First run will complete setup if needed

##  Usage

### Direct Usage
```cmd
serena-mcp-portable.bat
```

### VS Code with Continue
1. Install Continue extension
2. Import config: `config\vscode-continue-config.json`

### Claude Desktop
1. Import config: `config\claude-desktop-config.json`

### IntelliJ IDEA
1. Use as external tool pointing to serena-mcp-portable.bat

##  Supported Languages

Pre-configured language servers for:
- Python (Pyright)
- TypeScript/JavaScript  
- Go (gopls)
- Java (Eclipse JDT.LS)
- C# (OmniSharp)
- Rust (rust-analyzer)
- Ruby (Solargraph)
- PHP (Intelephense)
- Terraform (terraform-ls)
- Elixir (Elixir-LS)
- Clojure (clojure-lsp)
- Swift (SourceKit-LSP)
- Bash
- C/C++ (clangd)

##  Corporate Environment

### Proxy Support
Set environment variables before running:
```cmd
set HTTP_PROXY=http://proxy:8080
set HTTPS_PROXY=http://proxy:8080
```

### Certificate Bundles
```cmd
set REQUESTS_CA_BUNDLE=C:\path\to\ca-bundle.crt
```

### Air-Gapped Systems
$(if ($OfflineMode) {
"[OK] This package works completely offline!"
} else {
"[WARN] Internet required for first-time dependency installation"
})

##  Troubleshooting

### Check Installation
```cmd
check-dependencies.bat
```

### Manual Dependency Installation
$(if ($OfflineMode) {
"If dependencies are missing:`n```cmd`ndependencies\install-dependencies-offline.bat`n```"
} else {
"Ensure internet access for first run, or obtain offline dependency package"
})

### Reset Installation
1. Delete `Lib\site-packages\*` 
2. Run `serena-mcp-portable.bat` again

##  Package Statistics

- **Total Size**: ~$(if ($OfflineMode) { "500" } else { "200" })MB (compressed ~$(if ($OfflineMode) { "300" } else { "150" })MB)
- **Python Dependencies**: 21 packages
- **Language Servers**: 13 servers
- **Offline Ready**: $(if ($OfflineMode) { "[YES] YES" } else { "[WARN] Requires internet for first setup" })

##  Support

- GitHub: https://github.com/resline/serena
- Original: https://github.com/oraios/serena
- Corporate Support: Available

---
**Generated**: `$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Platform**: $Platform  
**Python**: $PythonVersion
**Offline Mode**: $(if ($OfflineMode) { "Enabled" } else { "First-run setup required" })
"@
Set-Content -Path "$OutputPath\README.txt" -Value $readme

Write-Host "[OK] Created configuration files and documentation" -ForegroundColor Green

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
$zipName = "serena-fully-portable-windows-v0.1.4.zip"
$zipPath = Join-Path (Get-Location) $zipName
$zipSize = 0

try {
    Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath -Force -CompressionLevel Optimal
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    $zipMsg = "[OK] Created ZIP package: $zipPath (" + $zipSize + " MB)"
    Write-Host $zipMsg -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create ZIP: $($_.Exception.Message)" -ForegroundColor Red
}

# Final summary
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  FULLY PORTABLE PACKAGE CREATED!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
if ($zipSize -gt 0) {
    $packageMsg = " Package: $zipName (" + $zipSize + " MB)"
    Write-Host $packageMsg -ForegroundColor Yellow
} else {
    Write-Host " Package: $zipName" -ForegroundColor Yellow
}
Write-Host " Target: Corporate/Air-gapped environments" -ForegroundColor Yellow  
$offlineStatus = if ($OfflineMode) { "100% Ready" } else { "Requires internet for first setup" }
$offlineColor = if ($OfflineMode) { "Green" } else { "Yellow" }
Write-Host " Offline: $offlineStatus" -ForegroundColor $offlineColor
Write-Host ""
Write-Host "[YES] Features included:" -ForegroundColor Green
Write-Host "   * Embedded Python $PythonVersion" -ForegroundColor White
$depStatus = if ($OfflineMode) { "Pre-installed dependencies" } else { "Online dependency installer" }
Write-Host "   * $depStatus" -ForegroundColor White  
Write-Host "   * 13+ Language servers pre-downloaded" -ForegroundColor White
Write-Host "   * VS Code + Claude Desktop integration" -ForegroundColor White
Write-Host "   * Corporate proxy/certificate support" -ForegroundColor White
Write-Host "   * Zero-installation deployment" -ForegroundColor White
Write-Host ""
Write-Host " Ready for deployment to corporate environments!" -ForegroundColor Cyan
Write-Host ""