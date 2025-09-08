# 🏢 Enterprise Usage Guide - Serena Offline Package Builder

## Overview

This guide explains how to use the Serena Offline Package Builder in enterprise environments with proxy servers, custom SSL certificates, and restricted network access.

## ✅ Completed Fixes for Enterprise Support

### Critical Issues Resolved:
1. **Fixed Python version** - Changed from non-existent 3.11.10 to 3.11.9
2. **Fixed f-string syntax error** - Removed backslash from f-string expression
3. **Replaced Unicode characters** - All scripts now use ASCII-only output for Windows console compatibility
4. **Added proxy support** - Full HTTP/HTTPS proxy configuration
5. **Added SSL certificate handling** - Custom CA bundles and verification options
6. **Fixed VSIX downloads** - Proper handling of VS Code marketplace downloads

## 🚀 Quick Start for Enterprise Users

### Option 1: Using Environment Variables

```bash
# Windows Command Prompt
set HTTP_PROXY=http://proxy.company.com:8080
set HTTPS_PROXY=http://proxy.company.com:8080
set SSL_CERT_FILE=C:\path\to\company-ca-bundle.crt
python BUILD_OFFLINE_WINDOWS.py --full

# Windows PowerShell
$env:HTTP_PROXY = "http://proxy.company.com:8080"
$env:HTTPS_PROXY = "http://proxy.company.com:8080"
$env:SSL_CERT_FILE = "C:\path\to\company-ca-bundle.crt"
python BUILD_OFFLINE_WINDOWS.py --full
```

### Option 2: Using Command-Line Arguments

```bash
# With proxy
python BUILD_OFFLINE_WINDOWS.py --full --proxy http://proxy.company.com:8080

# With proxy and custom CA certificate
python BUILD_OFFLINE_WINDOWS.py --full --proxy http://proxy.company.com:8080 --ca-bundle C:\certs\company-ca.crt

# Disable SSL verification (NOT recommended for production)
python BUILD_OFFLINE_WINDOWS.py --full --proxy http://proxy.company.com:8080 --no-ssl-verify

# Using configuration file
python BUILD_OFFLINE_WINDOWS.py --full --config offline_config.ini
```

### Option 3: Using Configuration File

1. Copy the template:
```bash
copy scripts\offline_config.ini.template offline_config.ini
```

2. Edit `offline_config.ini`:
```ini
[proxy]
http_proxy = http://proxy.company.com:8080
https_proxy = http://proxy.company.com:8080
no_proxy = localhost,127.0.0.1,.company.internal
proxy_auth = username:password  # Optional, if proxy requires authentication

[ssl]
verify = true
ca_bundle = C:\certificates\company-ca-bundle.crt
trusted_hosts = pypi.org,files.pythonhosted.org,github.com

[download]
retry_attempts = 3
timeout = 300
```

3. Run with config file:
```bash
python BUILD_OFFLINE_WINDOWS.py --full --config offline_config.ini
```

## 📋 Available Command-Line Options

### Main Build Script (`BUILD_OFFLINE_WINDOWS.py`)
```
--minimal          Build minimal package (Python only, ~300MB)
--standard         Build standard package (common languages, ~800MB)
--full             Build full package (all languages, ~2GB) [default]
--no-compress      Don't compress the final package
--proxy URL        HTTP/HTTPS proxy server URL
--no-ssl-verify    Disable SSL certificate verification
--ca-bundle PATH   Path to custom CA certificate bundle
--config PATH      Path to configuration file
--enterprise       Enable enterprise mode with auto-detection
```

### Individual Scripts

#### `scripts/offline_deps_downloader.py`
```
--output-dir DIR   Output directory for language servers
--platform PLAT    Platform (win-x64, win-arm64) [default: win-x64]
--proxy URL        Proxy server URL
--no-ssl-verify    Disable SSL verification
--ca-bundle PATH   Custom CA certificate bundle
--config PATH      Configuration file
--enterprise       Auto-detect enterprise settings
--resume           Resume interrupted downloads
--create-manifest  Create download manifest
```

#### `scripts/prepare_offline_windows.py`
```
--output-dir DIR     Output directory for package
--python-version VER Python version to download [default: 3.11.9]
--verify-only        Only verify existing package
--proxy URL          Proxy server URL
--no-ssl-verify      Disable SSL verification
--ca-bundle PATH     Custom CA certificate bundle
--config PATH        Configuration file
```

## 🔧 Environment Variables

### Proxy Configuration
- `HTTP_PROXY` - HTTP proxy server (e.g., `http://proxy:8080`)
- `HTTPS_PROXY` - HTTPS proxy server
- `NO_PROXY` - Comma-separated list of hosts to bypass proxy
- `PROXY_USERNAME` - Proxy authentication username
- `PROXY_PASSWORD` - Proxy authentication password

### SSL Configuration
- `SSL_CERT_FILE` - Path to custom CA certificate bundle
- `REQUESTS_CA_BUNDLE` - Alternative CA bundle path (for requests library)
- `SSL_VERIFY` - Set to `false` to disable SSL verification
- `PYTHONHTTPSVERIFY` - Set to `0` to disable SSL for Python

### Download Configuration
- `DOWNLOAD_TIMEOUT` - Connection timeout in seconds (default: 300)
- `DOWNLOAD_RETRY_ATTEMPTS` - Number of retry attempts (default: 3)
- `OFFLINE_BUILDER_ASCII_ONLY` - Set to `true` for ASCII-only output

## 🛠️ Troubleshooting Common Enterprise Issues

### Issue 1: Proxy Authentication Error (407)
**Error**: `HTTP Error 407: Proxy Authentication Required`

**Solution**:
```bash
# Include credentials in proxy URL
python BUILD_OFFLINE_WINDOWS.py --proxy http://username:password@proxy:8080

# Or use environment variables
set HTTP_PROXY=http://username:password@proxy:8080
```

### Issue 2: SSL Certificate Verification Failed
**Error**: `SSL: CERTIFICATE_VERIFY_FAILED`

**Solution**:
```bash
# Use your company's CA certificate bundle
python BUILD_OFFLINE_WINDOWS.py --ca-bundle C:\certs\company-ca-bundle.crt

# Or set environment variable
set SSL_CERT_FILE=C:\certs\company-ca-bundle.crt
```

### Issue 3: VSIX Files Not Downloading (VS Code Extensions)
**Error**: `File is not a zip file` for .vsix files

**Solution**:
```bash
# Ensure proxy allows VS Code marketplace
# Add marketplace to trusted hosts in config:
[ssl]
trusted_hosts = marketplace.visualstudio.com,*.gallerycdn.vsassets.io
```

### Issue 4: Python Package Downloads Failing
**Error**: `Could not find a version that satisfies the requirement`

**Solution**:
```bash
# Use proxy for pip downloads
# The scripts automatically pass proxy to pip, but ensure:
set PIP_PROXY=http://proxy:8080
set PIP_TRUSTED_HOST=pypi.org files.pythonhosted.org
```

### Issue 5: Timeout Errors
**Error**: `Connection timeout`

**Solution**:
```bash
# Increase timeout value
set DOWNLOAD_TIMEOUT=600

# Or in config file:
[download]
timeout = 600
```

## 📦 Building Different Package Types

### Minimal Package (~300MB)
Python-only, suitable for Python development:
```bash
python BUILD_OFFLINE_WINDOWS.py --minimal --proxy http://proxy:8080
```

### Standard Package (~800MB)
Common languages (Python, TypeScript, Java, C#, Go):
```bash
python BUILD_OFFLINE_WINDOWS.py --standard --proxy http://proxy:8080
```

### Full Package (~2GB)
All 25+ language servers:
```bash
python BUILD_OFFLINE_WINDOWS.py --full --proxy http://proxy:8080
```

### Custom Package
Specific languages only:
```bash
python scripts/build_offline_package.py --custom --languages python,java,typescript --proxy http://proxy:8080
```

## 🔍 Verifying Your Configuration

### Check Enterprise Settings
```bash
# Display current configuration
python scripts/enterprise_download.py --show-config

# Test download with your settings
python scripts/enterprise_download.py --test-download https://www.python.org
```

### Verify Proxy Connectivity
```bash
# Windows Command Prompt
curl -I --proxy http://proxy:8080 https://www.python.org

# PowerShell
Invoke-WebRequest -Uri https://www.python.org -Proxy http://proxy:8080
```

## 📝 Example Enterprise Workflow

1. **Prepare configuration file**:
```bash
copy scripts\offline_config.ini.template my_company_config.ini
# Edit my_company_config.ini with your settings
```

2. **Test connectivity**:
```bash
python scripts/enterprise_download.py --config my_company_config.ini --test-download
```

3. **Build package**:
```bash
python BUILD_OFFLINE_WINDOWS.py --full --config my_company_config.ini
```

4. **Transfer to offline machine**:
- Copy the generated `serena-offline-windows-[timestamp]` folder to your offline Windows machine

5. **Install on offline machine**:
```bash
# Run as Administrator
powershell -ExecutionPolicy Bypass .\install.ps1
```

## 🔐 Security Considerations

1. **Proxy Credentials**: Never commit proxy credentials to version control. Use environment variables or secure credential storage.

2. **SSL Verification**: Only disable SSL verification for testing. Always use proper CA certificates in production.

3. **Configuration Files**: Keep configuration files with sensitive information (proxy passwords) secure and with appropriate permissions.

4. **Audit Trail**: The build process logs all downloads and configurations for security auditing.

## 📞 Support

If you encounter issues specific to your enterprise environment:

1. Check the `build_offline_windows.log` file for detailed error messages
2. Run with `--debug` flag for verbose output
3. Use `--show-config` to verify your settings
4. Consult with your IT department for proxy/certificate details

## ✅ Summary

The Serena Offline Package Builder now fully supports enterprise environments with:
- HTTP/HTTPS proxy servers with authentication
- Custom SSL certificates and CA bundles
- Configurable timeouts and retry logic
- Multiple configuration methods (env vars, CLI args, config files)
- ASCII-only output for Windows console compatibility
- Comprehensive error handling and troubleshooting

All scripts have been tested and verified to work behind corporate firewalls with proper configuration.