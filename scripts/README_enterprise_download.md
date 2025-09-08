# Enterprise Download Module

A comprehensive, enterprise-ready file downloading module for Serena Agent that handles proxy servers, SSL certificates, retry logic, and content validation with robust error handling.

## Features

### Core Capabilities
- **Proxy Server Support**: Automatic configuration from environment variables (HTTP_PROXY, HTTPS_PROXY, NO_PROXY)
- **SSL Certificate Handling**: Custom CA bundles, verification options, and corporate certificate support
- **Retry Logic**: Exponential backoff with configurable attempts (default 3)
- **Content Validation**: Detects HTML error pages vs binary files to prevent corrupted downloads
- **Progress Tracking**: Cross-platform progress callbacks with proper encoding
- **Dual Library Support**: Both urllib (built-in) and requests (optional) backends
- **VS Code Marketplace Integration**: Special handling for VSIX extension downloads
- **Enterprise Error Handling**: Specific exceptions for proxy, SSL, and content validation issues

### Environment Variables

The module automatically reads configuration from environment variables:

```bash
# Proxy Configuration
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=https://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,.company.com

# SSL Configuration
export SSL_CERT_FILE=/path/to/company-ca-bundle.crt
export REQUESTS_CA_BUNDLE=/path/to/ca-bundle.crt
export SSL_VERIFY=true  # or false to disable (not recommended)

# Download Configuration
export DOWNLOAD_TIMEOUT=300  # seconds
export DOWNLOAD_RETRY_ATTEMPTS=3
```

## Usage Examples

### Basic Usage

```python
from enterprise_download import EnterpriseDownloader, create_progress_callback

# Create downloader with default settings
downloader = EnterpriseDownloader()

# Simple download
success = downloader.download_file(
    url="https://example.com/file.zip",
    dest_path="downloaded_file.zip"
)

# Download with progress tracking
progress = create_progress_callback("Downloading File")
success = downloader.download_with_retry(
    url="https://example.com/file.zip",
    dest_path="file.zip",
    validate=True,
    progress_callback=progress
)
```

### Enterprise Configuration

```python
# Explicit proxy configuration
proxy_config = {
    'http': 'http://proxy.company.com:8080',
    'https': 'https://proxy.company.com:8080'
}

downloader = EnterpriseDownloader(
    proxy=proxy_config,
    ssl_verify=True,
    ca_bundle="/path/to/company-ca-bundle.crt",
    retry_attempts=5,
    timeout=600  # 10 minutes for slow corporate networks
)
```

### Error Handling

```python
from enterprise_download import (
    EnterpriseDownloader, 
    DownloadError, 
    ProxyError, 
    SSLError, 
    ContentValidationError
)

downloader = EnterpriseDownloader()

try:
    success = downloader.download_with_retry(url, dest_path)
    if success:
        print("✅ Download successful")
    else:
        print("❌ Download failed after all retries")
        
except ProxyError as e:
    print(f"🔐 Proxy issue: {e}")
    print("💡 Check proxy credentials and configuration")
    
except SSLError as e:
    print(f"🔒 SSL certificate issue: {e}")
    print("💡 Check CA bundle or disable SSL verification")
    
except ContentValidationError as e:
    print(f"📄 Content validation failed: {e}")
    print("💡 Server returned error page instead of file")
    
except DownloadError as e:
    print(f"🌐 Download error: {e}")
```

### VS Code Extensions

```python
downloader = EnterpriseDownloader()

# Download latest version
success, path = downloader.download_vscode_extension(
    publisher="ms-python",
    extension="python",
    version="latest"
)

# Download specific version
success, path = downloader.download_vscode_extension(
    publisher="ms-vscode",
    extension="csharp", 
    version="1.25.0",
    dest_path="csharp-extension.vsix"
)
```

### Integration with Existing Code

Replace existing urllib-based downloads:

```python
# Before: Raw urllib with minimal error handling
import urllib.request

def old_download(url, dest_path):
    urllib.request.urlretrieve(url, dest_path)

# After: Enterprise-grade downloading
from enterprise_download import EnterpriseDownloader, create_progress_callback

def new_download(url, dest_path):
    downloader = EnterpriseDownloader()
    progress = create_progress_callback("Downloading")
    
    return downloader.download_with_retry(
        url=url,
        dest_path=dest_path,
        validate=True,
        progress_callback=progress
    )
```

## Command Line Interface

The module includes a CLI for testing and standalone usage:

```bash
# Basic download
python enterprise_download.py https://example.com/file.zip -o output.zip

# With enterprise options
python enterprise_download.py https://example.com/file.zip \
    --no-ssl-verify \
    --retry-attempts 5 \
    --timeout 600 \
    --debug

# Force urllib backend
python enterprise_download.py https://example.com/file.zip --use-urllib
```

## Class Reference

### EnterpriseDownloader

#### Constructor

```python
EnterpriseDownloader(
    proxy: Optional[Dict[str, str]] = None,
    ssl_verify: bool = True,
    ca_bundle: Optional[str] = None,
    retry_attempts: int = 3,
    timeout: int = 300,
    use_requests: bool = None
)
```

#### Key Methods

**download_file(url, dest_path, headers=None, progress_callback=None) -> bool**
- Single download attempt with progress tracking

**download_with_retry(url, dest_path, validate=True, headers=None, progress_callback=None) -> bool**
- Download with retry logic and content validation

**download_vscode_extension(publisher, extension, version="latest", dest_path=None) -> Tuple[bool, Optional[Path]]**
- Specialized VS Code extension download

**validate_binary_content(file_path) -> bool**
- Validate downloaded file is binary (not HTML error page)

**get_troubleshooting_info() -> Dict[str, str]**
- Get configuration and environment info for debugging

**setup_proxy_handler() -> urllib.request.ProxyHandler**
- Create configured proxy handler for urllib

**setup_ssl_context() -> ssl.SSLContext**
- Create configured SSL context

## Exception Hierarchy

```
Exception
└── DownloadError (base download exception)
    ├── ProxyError (proxy authentication/configuration issues)
    ├── SSLError (SSL certificate/verification issues)  
    └── ContentValidationError (HTML error page instead of binary)
```

## Enterprise Environment Detection

The module automatically detects enterprise environments by checking:

1. **Proxy Environment Variables**: HTTP_PROXY, HTTPS_PROXY presence
2. **Custom CA Certificates**: SSL_CERT_FILE, common system locations
3. **Corporate Domains**: Corporate keywords in environment variables
4. **Network Configuration**: Enterprise-specific network settings

When detected, it automatically configures:
- Increased retry attempts (5 instead of 3)
- Longer timeouts (10 minutes instead of 5)
- More aggressive error handling
- Enhanced logging for troubleshooting

## Troubleshooting

### Common Issues

**Proxy Authentication Required (407)**
```python
# Solution: Set proxy with credentials in environment
export HTTP_PROXY=http://username:password@proxy.company.com:8080
```

**SSL Certificate Verification Failed**
```python
# Solution 1: Add company CA bundle
export SSL_CERT_FILE=/path/to/company-ca-bundle.crt

# Solution 2: Disable SSL verification (not recommended)
export SSL_VERIFY=false
```

**HTML Error Page Downloaded Instead of Binary**
- The content validation will catch this automatically
- Check if URL is correct and accessible
- Verify if authentication is required

**Slow Downloads in Corporate Environment**
```python
# Increase timeout for slow corporate networks
downloader = EnterpriseDownloader(
    timeout=1200,  # 20 minutes
    retry_attempts=5
)
```

### Debugging Information

Get comprehensive configuration details:

```python
downloader = EnterpriseDownloader()
info = downloader.get_troubleshooting_info()
for key, value in info.items():
    print(f"{key}: {value}")
```

This will show:
- HTTP library being used (requests vs urllib)
- SSL verification status
- CA bundle location
- Proxy configuration (sanitized)
- Environment variable values
- Timeout and retry settings

## Testing

Run the test suite:

```bash
python test_enterprise_download.py
```

Run usage examples:

```bash
python enterprise_download_examples.py
```

Both scripts demonstrate all major features and provide comprehensive testing of the module's capabilities.

## Integration with Serena Agent

This module is designed to replace basic urllib usage throughout the Serena Agent codebase, particularly in:

- **offline_deps_downloader.py**: Language server and runtime downloads
- **build_offline_package.py**: Component and dependency downloads  
- **VS Code extension downloads**: Marketplace integration
- **Any network file operations**: Enhanced reliability and enterprise support

The module maintains API compatibility while providing enterprise-grade reliability and error handling.