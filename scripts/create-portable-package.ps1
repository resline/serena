# Create Portable Serena Package for Corporate Deployment
# This script creates a self-contained package with all dependencies

param(
    [string]$OutputPath = ".\serena-portable",
    [string]$ProxyUrl = $env:HTTP_PROXY,
    [string]$CertPath = $env:REQUESTS_CA_BUNDLE
)

Write-Host "Creating portable Serena package..." -ForegroundColor Cyan

# Create directory structure
$dirs = @(
    "$OutputPath",
    "$OutputPath\serena",
    "$OutputPath\language-servers",
    "$OutputPath\config",
    "$OutputPath\scripts"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# Clone Serena (using fork for corporate deployment)
Write-Host "Cloning Serena repository..." -ForegroundColor Yellow
git clone https://github.com/resline/serena "$OutputPath\serena-temp"

# Copy only necessary files
$essentialDirs = @("src", "scripts", "pyproject.toml", "README.md", "LICENSE")
foreach ($item in $essentialDirs) {
    Copy-Item -Path "$OutputPath\serena-temp\$item" -Destination "$OutputPath\serena\" -Recurse -Force
}

Remove-Item -Path "$OutputPath\serena-temp" -Recurse -Force

# Download Python embedded
Write-Host "Downloading Python 3.11 embedded..." -ForegroundColor Yellow
$pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip"
$pythonZip = "$OutputPath\python-embedded.zip"

Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonZip -UseBasicParsing
Expand-Archive -Path $pythonZip -DestinationPath "$OutputPath\python" -Force
Remove-Item $pythonZip

# Download get-pip
Write-Host "Setting up pip..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile "$OutputPath\python\get-pip.py"

# Create python._pth to enable pip
$pthContent = @"
python311.zip
.
..\..\serena\src
..\..\Lib\site-packages
import site
"@
Set-Content -Path "$OutputPath\python\python311._pth" -Value $pthContent

# Install pip in embedded Python
& "$OutputPath\python\python.exe" "$OutputPath\python\get-pip.py" --no-warn-script-location

# Install UV in portable mode
Write-Host "Installing UV..." -ForegroundColor Yellow
& "$OutputPath\python\python.exe" -m pip install uv --target "$OutputPath\Lib\site-packages"

# Create UV wrapper
$uvWrapper = @"
@echo off
"%~dp0python\python.exe" -m uv %*
"@
Set-Content -Path "$OutputPath\uv.cmd" -Value $uvWrapper

# Download language servers
Write-Host "Downloading language servers..." -ForegroundColor Yellow
& "$OutputPath\python\python.exe" "$PSScriptRoot\download-language-servers-offline.py" `
    --output "$OutputPath\language-servers" `
    --proxy $ProxyUrl `
    --cert $CertPath

# Create configuration templates
Write-Host "Creating configuration templates..." -ForegroundColor Yellow

# Main wrapper script
$mainWrapper = @"
@echo off
setlocal

:: Portable Serena MCP Launcher
:: This script sets up the environment and runs Serena MCP

:: Set paths
set SERENA_PORTABLE=%~dp0
set PYTHONHOME=%SERENA_PORTABLE%python
set PATH=%PYTHONHOME%;%PYTHONHOME%\Scripts;%PATH%

:: Set corporate proxy if provided
if not "%HTTP_PROXY%"=="" (
    echo Using proxy: %HTTP_PROXY%
)

:: Set certificate if provided
if not "%REQUESTS_CA_BUNDLE%"=="" (
    echo Using CA bundle: %REQUESTS_CA_BUNDLE%
)

:: Create .solidlsp directory if not exists
if not exist "%USERPROFILE%\.solidlsp" mkdir "%USERPROFILE%\.solidlsp"
if not exist "%USERPROFILE%\.solidlsp\language_servers" mkdir "%USERPROFILE%\.solidlsp\language_servers"
if not exist "%USERPROFILE%\.solidlsp\language_servers\static" mkdir "%USERPROFILE%\.solidlsp\language_servers\static"

:: Copy language servers if not present
echo Checking language servers...
xcopy /E /I /Y "%SERENA_PORTABLE%language-servers\*" "%USERPROFILE%\.solidlsp\language_servers\static\" >nul 2>&1

:: Run Serena MCP server
cd /d "%SERENA_PORTABLE%serena"
"%PYTHONHOME%\python.exe" -m serena.cli start-mcp-server %*

endlocal
"@
Set-Content -Path "$OutputPath\serena-mcp-portable.bat" -Value $mainWrapper

# VS Code Continue config template
$vscodeConfig = @{
    mcpServers = @{
        serena = @{
            command = "C:\\serena-portable\\serena-mcp-portable.bat"
            args = @("--context", "ide-assistant")
        }
    }
}
$vscodeConfig | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\config\vscode-continue-config.json"

# IntelliJ config template
$intellijConfig = @"
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="Serena MCP Portable" type="ShConfigurationType">
    <option name="SCRIPT_PATH" value="C:\serena-portable\serena-mcp-portable.bat" />
    <option name="SCRIPT_OPTIONS" value="--context ide-assistant" />
  </configuration>
</component>
"@
Set-Content -Path "$OutputPath\config\intellij-serena.run.xml" -Value $intellijConfig

# Setup script for end users
$setupScript = @"
@echo off
echo Setting up Serena Portable...

:: Copy to C:\serena-portable
xcopy /E /I /Y "%~dp0*" "C:\serena-portable\" >nul

:: Create desktop shortcut
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%USERPROFILE%\Desktop\Serena MCP.lnk'); $SC.TargetPath = 'C:\serena-portable\serena-mcp-portable.bat'; $SC.Save()"

echo.
echo Serena Portable installed successfully!
echo Desktop shortcut created.
echo.
echo To use with VS Code Continue: Import config from C:\serena-portable\config\vscode-continue-config.json
echo To use with IntelliJ: Import run config from C:\serena-portable\config\intellij-serena.run.xml
echo.
pause
"@
Set-Content -Path "$OutputPath\SETUP.bat" -Value $setupScript

# Create README
$readme = @"
# Serena MCP Portable Package v0.1.4

This is a self-contained Serena MCP package for corporate environments.

## Installation

1. Run SETUP.bat to install to C:\serena-portable
2. A desktop shortcut will be created automatically

## Supported Languages

- Python (via Pylsp)
- TypeScript/JavaScript (via TypeScript Language Server)
- Go (via gopls)
- Java (via Eclipse JDT.LS)
- C# (via OmniSharp)
- Rust (via rust-analyzer)
- Ruby (via Solargraph)
- PHP (via Intelephense)
- Terraform (via terraform-ls)
- Elixir (via Elixir-LS)
- Clojure (via clojure-lsp)
- Swift (via sourcekit-lsp)
- Bash (via bash-language-server)
- C/C++ (via clangd)

## Usage

### VS Code with Continue Extension
1. Install Continue extension in VS Code
2. Import the configuration from: config\vscode-continue-config.json

### IntelliJ IDEA
1. Import the run configuration from: config\intellij-serena.run.xml
2. The configuration will appear in your run configurations

### Claude Desktop
1. Use the provided MCP configuration for Claude Desktop
2. Point to serena-mcp-portable.bat as the command

### Direct Usage
Run: serena-mcp-portable.bat

## Corporate Network

If you need to set proxy/certificates:
1. Set environment variables before running:
   - HTTP_PROXY=http://your-proxy:8080
   - HTTPS_PROXY=http://your-proxy:8080
   - REQUESTS_CA_BUNDLE=C:\path\to\ca-bundle.crt

2. Or create a batch file that sets these before calling serena-mcp-portable.bat

## Contents

- python\         - Embedded Python 3.11
- serena\        - Serena source code (v0.1.4)
- language-servers\ - Pre-downloaded language servers
- config\        - Configuration templates

## Features

- Symbol-based code editing with LSP support
- Project memory and context management
- Multiple IDE integrations
- ChatGPT and Claude compatible
- Offline/air-gapped environment support

## Support

See https://github.com/resline/serena for documentation
Original project: https://github.com/oraios/serena
"@
Set-Content -Path "$OutputPath\README.txt" -Value $readme

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
$zipPath = "serena-portable-windows.zip"
Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath -Force

Write-Host "`nPortable package created successfully!" -ForegroundColor Green
Write-Host "Output: $zipPath" -ForegroundColor Yellow
Write-Host "Size: $([math]::Round((Get-Item $zipPath).Length / 1MB, 2)) MB" -ForegroundColor Yellow
Write-Host "`nThis package can be distributed to users without internet access" -ForegroundColor Cyan