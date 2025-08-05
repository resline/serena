# Serena MCP Corporate Deployment Guide for Windows 11

This guide provides solutions for deploying Serena MCP in corporate environments with proxy and certificate restrictions, targeting a 15-minute setup time.

## Table of Contents
- [Quick Start Solution](#quick-start-solution)
- [Corporate Network Configuration](#corporate-network-configuration)
- [VS Code Continue Integration](#vs-code-continue-integration)
- [IntelliJ Integration](#intellij-integration)
- [Troubleshooting](#troubleshooting)

## Quick Start Solution

### Option 1: Docker Container (Recommended for Corporate Networks)

Docker provides the cleanest solution for corporate environments as it encapsulates all dependencies and can be pre-configured with certificates.

1. **Create a corporate Docker image** with pre-installed certificates:

```dockerfile
FROM ghcr.io/oraios/serena:latest

# Add corporate CA certificates
COPY corporate-ca-cert.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Set proxy environment variables
ENV HTTP_PROXY=http://your-proxy:8080
ENV HTTPS_PROXY=http://your-proxy:8080
ENV NO_PROXY=localhost,127.0.0.1,.your-company.com

# Pre-download language servers to avoid runtime downloads
RUN python -c "from solidlsp.language_servers import *; \
    import os; os.makedirs('/root/.solidlsp/language_servers/static', exist_ok=True)"
```

2. **Build and push to internal registry**:
```bash
docker build -t your-registry/serena-corporate:latest .
docker push your-registry/serena-corporate:latest
```

3. **Deploy to users** with simple run command:
```bash
docker run --rm -i --network host -v C:\Projects:/workspaces/projects your-registry/serena-corporate:latest serena-mcp-server --transport stdio
```

### Option 2: Pre-configured Portable Package

Create a portable package with all dependencies pre-installed:

1. **Setup script** (`setup-serena-corporate.bat`):

```batch
@echo off
setlocal enabledelayedexpansion

:: Set corporate proxy
set HTTP_PROXY=http://your-proxy:8080
set HTTPS_PROXY=http://your-proxy:8080
set REQUESTS_CA_BUNDLE=C:\Corporate\ca-bundle.crt
set SSL_CERT_FILE=C:\Corporate\ca-bundle.crt
set NODE_EXTRA_CA_CERTS=C:\Corporate\ca-bundle.crt

:: Install UV with corporate settings
curl -LsSf https://astral.sh/uv/install.ps1 | powershell -

:: Clone Serena
git clone https://github.com/oraios/serena %USERPROFILE%\serena

:: Configure UV for corporate network
cd %USERPROFILE%\serena
echo [tool.uv] > .uv.toml
echo trusted-host = ["pypi.org", "files.pythonhosted.org"] >> .uv.toml

:: Install dependencies
uv sync

:: Pre-download language servers
uv run python scripts/download_language_servers.py

:: Create config with proxy settings
mkdir %USERPROFILE%\.serena
copy corporate-serena-config.yml %USERPROFILE%\.serena\serena_config.yml

echo Setup complete! Serena is ready to use.
```

2. **Language server pre-download script** (`scripts/download_language_servers.py`):

```python
import os
import requests
import subprocess
from pathlib import Path

# Configure session with corporate proxy and certs
session = requests.Session()
session.proxies = {
    'http': os.environ.get('HTTP_PROXY'),
    'https': os.environ.get('HTTPS_PROXY')
}
session.verify = os.environ.get('REQUESTS_CA_BUNDLE', True)

# Download Python language server
pyright_version = "1.1.396"
print("Downloading Pyright...")
# ... download logic with corporate proxy support

# Download other language servers as needed
print("All language servers downloaded successfully!")
```

## Corporate Network Configuration

### Environment Variables Template

Create `corporate-env.bat`:

```batch
@echo off
:: Proxy settings
set HTTP_PROXY=http://proxy.company.com:8080
set HTTPS_PROXY=http://proxy.company.com:8080
set NO_PROXY=localhost,127.0.0.1,.company.com

:: Certificate settings
set REQUESTS_CA_BUNDLE=C:\Corporate\ca-bundle.crt
set SSL_CERT_FILE=C:\Corporate\ca-bundle.crt
set NODE_EXTRA_CA_CERTS=C:\Corporate\ca-bundle.crt
set CURL_CA_BUNDLE=C:\Corporate\ca-bundle.crt

:: Python/pip settings
set PIP_TRUSTED_HOST=pypi.org files.pythonhosted.org
set PIP_CERT=C:\Corporate\ca-bundle.crt

:: UV settings
set UV_TRUSTED_HOST=pypi.org files.pythonhosted.org
set UV_CERT=C:\Corporate\ca-bundle.crt
```

### Serena Configuration Template

`corporate-serena-config.yml`:

```yaml
# Serena configuration for corporate environments
solidlsp:
  # Pre-configured language server paths
  language_servers:
    python:
      path: "C:/serena-portable/language-servers/pyright/node_modules/.bin/pyright-langserver.cmd"
    typescript:
      path: "C:/serena-portable/language-servers/typescript/node_modules/.bin/typescript-language-server.cmd"
    
# Network settings
network:
  proxy:
    http: "http://proxy.company.com:8080"
    https: "http://proxy.company.com:8080"
    no_proxy: "localhost,127.0.0.1,.company.com"
  
  certificates:
    ca_bundle: "C:/Corporate/ca-bundle.crt"
    verify_ssl: true

# Performance settings for corporate networks
performance:
  download_timeout: 300  # 5 minutes for slow corporate networks
  connection_timeout: 60
  
# Logging for troubleshooting
logging:
  level: INFO
  file: "C:/Users/%USERNAME%/.serena/serena.log"
```

## VS Code Continue Integration

### Quick Setup for Continue

1. **Install Continue extension** in VS Code

2. **Configure Continue** (`~/.continue/config.json`):

```json
{
  "models": [
    {
      "title": "Claude with Serena",
      "provider": "anthropic",
      "model": "claude-3-5-sonnet-20241022",
      "apiKey": "YOUR_API_KEY"
    }
  ],
  "mcpServers": {
    "serena": {
      "command": "C:\\serena-portable\\run-serena.bat",
      "args": ["--context", "ide-assistant"],
      "env": {
        "HTTP_PROXY": "http://proxy.company.com:8080",
        "HTTPS_PROXY": "http://proxy.company.com:8080",
        "REQUESTS_CA_BUNDLE": "C:\\Corporate\\ca-bundle.crt"
      }
    }
  }
}
```

3. **Create wrapper script** (`C:\serena-portable\run-serena.bat`):

```batch
@echo off
call C:\Corporate\corporate-env.bat
C:\serena-portable\uv\uv.exe run --directory C:\serena-portable\serena serena-mcp-server %*
```

## IntelliJ Integration

### Using IntelliJ MCP Plugin

1. **Install MCP plugin** from JetBrains Marketplace

2. **Configure MCP settings** (File > Settings > Tools > MCP):

```xml
<mcp-config>
  <server name="serena">
    <command>C:\serena-portable\run-serena.bat</command>
    <args>
      <arg>--context</arg>
      <arg>ide-assistant</arg>
    </args>
    <env>
      <var name="HTTP_PROXY">http://proxy.company.com:8080</var>
      <var name="HTTPS_PROXY">http://proxy.company.com:8080</var>
      <var name="REQUESTS_CA_BUNDLE">C:\Corporate\ca-bundle.crt</var>
    </env>
  </server>
</mcp-config>
```

## Quick Deployment Script

**One-click installer** (`deploy-serena.ps1`):

```powershell
# Serena Corporate Quick Deploy Script
param(
    [string]$ProxyUrl = "http://proxy.company.com:8080",
    [string]$CaCertPath = "C:\Corporate\ca-bundle.crt",
    [string]$InstallPath = "C:\serena-portable"
)

# Set up environment
$env:HTTP_PROXY = $ProxyUrl
$env:HTTPS_PROXY = $ProxyUrl
$env:REQUESTS_CA_BUNDLE = $CaCertPath

Write-Host "Serena Corporate Deployment Starting..." -ForegroundColor Green

# Create installation directory
New-Item -ItemType Directory -Force -Path $InstallPath

# Download pre-packaged Serena
Write-Host "Downloading Serena package..."
Invoke-WebRequest -Uri "http://internal-repo/serena-corporate.zip" -OutFile "$InstallPath\serena.zip"
Expand-Archive -Path "$InstallPath\serena.zip" -DestinationPath $InstallPath -Force

# Configure for user
$configPath = "$env:USERPROFILE\.serena"
New-Item -ItemType Directory -Force -Path $configPath
Copy-Item "$InstallPath\config-templates\*" -Destination $configPath -Recurse

# Create desktop shortcuts
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\Serena MCP.lnk")
$Shortcut.TargetPath = "$InstallPath\run-serena.bat"
$Shortcut.Save()

Write-Host "Installation complete in under 5 minutes!" -ForegroundColor Green
Write-Host "Serena is ready to use with your IDE" -ForegroundColor Yellow
```

## Troubleshooting

### Common Issues and Solutions

1. **SSL Certificate Errors**:
   ```batch
   set REQUESTS_CA_BUNDLE=C:\Corporate\ca-bundle.crt
   set SSL_CERT_FILE=C:\Corporate\ca-bundle.crt
   ```

2. **Proxy Authentication**:
   ```batch
   set HTTP_PROXY=http://username:password@proxy:8080
   ```

3. **Language Server Download Failures**:
   - Use pre-packaged version with all language servers included
   - Or manually download and place in `~/.solidlsp/language_servers/static/`

4. **UV/Gradle Issues**:
   - Pre-configure with corporate proxy settings
   - Use offline package with all dependencies included

### Quick Test

After installation, test with:

```batch
C:\serena-portable\test-serena.bat
```

This should complete in under 30 seconds and verify all components are working.

## Support

For corporate deployment support:
- Check internal wiki at: http://wiki.company.com/serena-mcp
- Contact IT Help Desk with deployment ID
- Join #serena-mcp Slack channel