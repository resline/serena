#!/usr/bin/env python3
"""
Enterprise Download Module for Serena Agent

This module provides robust, enterprise-ready file downloading capabilities with
comprehensive proxy support, SSL certificate handling, retry logic, and content validation.

Features:
- Proxy server configuration from environment variables
- Custom SSL certificate handling and verification options
- Exponential backoff retry logic with configurable attempts
- Content validation to detect HTML error pages vs binary files
- Progress tracking with proper encoding for cross-platform support
- Support for both urllib and requests libraries
- VS Code Marketplace specific optimizations
- Enterprise-grade error handling and logging

Environment Variables:
- HTTP_PROXY, HTTPS_PROXY, NO_PROXY: Proxy configuration
- SSL_CERT_FILE, REQUESTS_CA_BUNDLE: Custom CA certificates
- SSL_VERIFY: Enable/disable SSL verification (true/false)
- DOWNLOAD_TIMEOUT: Connection timeout in seconds
- DOWNLOAD_RETRY_ATTEMPTS: Number of retry attempts

Author: Serena Agent Team
License: MIT
"""

import json
import logging
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple, Union
import socket

# Optional requests support
try:
    import requests
    from requests.adapters import HTTPAdapter
    from requests.packages.urllib3.util.retry import Retry
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# Configure logging
logger = logging.getLogger(__name__)


class DownloadError(Exception):
    """Base exception for download-related errors."""
    pass


class ProxyError(DownloadError):
    """Proxy authentication or configuration error."""
    pass


class SSLError(DownloadError):
    """SSL certificate or verification error."""
    pass


class ContentValidationError(DownloadError):
    """Content validation error (e.g., HTML error page instead of binary)."""
    pass


class EnterpriseDownloader:
    """
    Enterprise-grade file downloader with proxy and SSL support.
    
    This class provides robust downloading capabilities suitable for enterprise
    environments with proxy servers, custom SSL certificates, and strict security
    requirements.
    """
    
    def __init__(
        self,
        proxy: Optional[Dict[str, str]] = None,
        ssl_verify: bool = True,
        ca_bundle: Optional[str] = None,
        retry_attempts: int = 3,
        timeout: int = 300,
        use_requests: bool = None
    ):
        """
        Initialize the EnterpriseDownloader.
        
        Args:
            proxy: Dictionary with proxy configuration {'http': 'proxy_url', 'https': 'proxy_url'}
            ssl_verify: Whether to verify SSL certificates
            ca_bundle: Path to custom CA bundle file
            retry_attempts: Number of retry attempts for failed downloads
            timeout: Connection timeout in seconds
            use_requests: Force use of requests library (if available)
        """
        self.proxy = proxy or self._get_proxy_from_env()
        self.ssl_verify = self._get_ssl_verify_from_env() if ssl_verify is True else ssl_verify
        self.ca_bundle = ca_bundle or self._get_ca_bundle_from_env()
        self.retry_attempts = int(os.getenv('DOWNLOAD_RETRY_ATTEMPTS', str(retry_attempts)))
        self.timeout = int(os.getenv('DOWNLOAD_TIMEOUT', str(timeout)))
        
        # Determine which HTTP library to use
        if use_requests is None:
            self.use_requests = HAS_REQUESTS
        else:
            self.use_requests = use_requests and HAS_REQUESTS
            
        if self.use_requests and not HAS_REQUESTS:
            logger.warning("Requests library not available, falling back to urllib")
            self.use_requests = False
        
        # Setup HTTP handlers
        self._setup_urllib_handlers()
        if self.use_requests:
            self._setup_requests_session()
        
        logger.info(f"EnterpriseDownloader initialized - Library: {'requests' if self.use_requests else 'urllib'}")
        if self.proxy:
            logger.info(f"Proxy configuration: {self._sanitize_proxy_for_logging(self.proxy)}")
        logger.info(f"SSL verification: {self.ssl_verify}")
        if self.ca_bundle:
            logger.info(f"CA bundle: {self.ca_bundle}")
    
    def _get_proxy_from_env(self) -> Dict[str, str]:
        """Extract proxy configuration from environment variables."""
        proxy = {}
        
        http_proxy = os.getenv('HTTP_PROXY') or os.getenv('http_proxy')
        https_proxy = os.getenv('HTTPS_PROXY') or os.getenv('https_proxy')
        
        if http_proxy:
            proxy['http'] = http_proxy
        if https_proxy:
            proxy['https'] = https_proxy
            
        return proxy
    
    def _get_ssl_verify_from_env(self) -> bool:
        """Get SSL verification setting from environment."""
        ssl_verify = os.getenv('SSL_VERIFY', 'true').lower()
        return ssl_verify in ('true', '1', 'yes', 'on')
    
    def _get_ca_bundle_from_env(self) -> Optional[str]:
        """Get CA bundle path from environment variables."""
        ca_bundle = (
            os.getenv('SSL_CERT_FILE') or 
            os.getenv('REQUESTS_CA_BUNDLE') or 
            os.getenv('CURL_CA_BUNDLE')
        )
        
        if ca_bundle and Path(ca_bundle).exists():
            return ca_bundle
        elif ca_bundle:
            logger.warning(f"CA bundle file not found: {ca_bundle}")
            
        return None
    
    def _sanitize_proxy_for_logging(self, proxy: Dict[str, str]) -> Dict[str, str]:
        """Remove credentials from proxy URLs for safe logging."""
        sanitized = {}
        for protocol, url in proxy.items():
            parsed = urllib.parse.urlparse(url)
            if parsed.username or parsed.password:
                sanitized_url = f"{parsed.scheme}://***:***@{parsed.hostname}:{parsed.port or 80}"
                sanitized[protocol] = sanitized_url
            else:
                sanitized[protocol] = url
        return sanitized
    
    def _setup_urllib_handlers(self):
        """Setup urllib handlers for proxy and SSL configuration."""
        handlers = []
        
        # Proxy handler
        if self.proxy:
            proxy_handler = urllib.request.ProxyHandler(self.proxy)
            handlers.append(proxy_handler)
        
        # SSL context
        if hasattr(ssl, 'create_default_context'):
            ssl_context = ssl.create_default_context()
            
            if not self.ssl_verify:
                ssl_context.check_hostname = False
                ssl_context.verify_mode = ssl.CERT_NONE
                logger.warning("SSL verification disabled - this is insecure for production use")
            
            if self.ca_bundle:
                ssl_context.load_verify_locations(self.ca_bundle)
                logger.info(f"Loaded custom CA bundle: {self.ca_bundle}")
            
            https_handler = urllib.request.HTTPSHandler(context=ssl_context)
            handlers.append(https_handler)
        
        # Build opener
        if handlers:
            opener = urllib.request.build_opener(*handlers)
            urllib.request.install_opener(opener)
    
    def _setup_requests_session(self):
        """Setup requests session with retry logic and proxy configuration."""
        if not HAS_REQUESTS:
            return
            
        self.session = requests.Session()
        
        # Configure proxy
        if self.proxy:
            self.session.proxies.update(self.proxy)
        
        # Configure SSL
        if not self.ssl_verify:
            self.session.verify = False
            # Disable SSL warnings
            import urllib3
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        elif self.ca_bundle:
            self.session.verify = self.ca_bundle
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=self.retry_attempts,
            status_forcelist=[429, 500, 502, 503, 504],
            method_whitelist=["HEAD", "GET", "OPTIONS"],
            backoff_factor=1
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def setup_proxy_handler(self) -> urllib.request.ProxyHandler:
        """
        Create and return a configured proxy handler for urllib.
        
        Returns:
            ProxyHandler configured with current proxy settings
        """
        if not self.proxy:
            return None
        return urllib.request.ProxyHandler(self.proxy)
    
    def setup_ssl_context(self) -> ssl.SSLContext:
        """
        Create and return a configured SSL context.
        
        Returns:
            SSLContext configured with current SSL settings
        """
        if not hasattr(ssl, 'create_default_context'):
            return None
            
        context = ssl.create_default_context()
        
        if not self.ssl_verify:
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        
        if self.ca_bundle:
            context.load_verify_locations(self.ca_bundle)
        
        return context
    
    def validate_binary_content(self, file_path: Union[str, Path]) -> bool:
        """
        Validate that a downloaded file contains binary content and not an HTML error page.
        
        Args:
            file_path: Path to the file to validate
            
        Returns:
            True if file appears to be valid binary content, False otherwise
            
        Raises:
            ContentValidationError: If file contains HTML error page
        """
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise ContentValidationError(f"File does not exist: {file_path}")
        
        if file_path.stat().st_size == 0:
            raise ContentValidationError(f"File is empty: {file_path}")
        
        # Read first few KB to check for HTML content
        try:
            with open(file_path, 'rb') as f:
                header = f.read(8192)  # Read first 8KB
        except Exception as e:
            raise ContentValidationError(f"Cannot read file {file_path}: {e}")
        
        # Try to decode as text to check for HTML
        try:
            text_content = header.decode('utf-8', errors='ignore').lower()
        except Exception:
            # If we can't decode it, it's probably binary - that's good
            return True
        
        # Check for common HTML error page indicators
        html_indicators = [
            '<!doctype html',
            '<html',
            '<head>',
            '<title>error',
            '<title>404',
            '<title>403',
            '<title>500',
            'content-type: text/html',
            'application/json',  # JSON error responses
        ]
        
        for indicator in html_indicators:
            if indicator in text_content:
                # Log first 500 chars for debugging
                preview = text_content[:500].replace('\n', ' ').replace('\r', ' ')
                logger.error(f"HTML/text content detected in binary file: {file_path}")
                logger.error(f"Content preview: {preview}")
                raise ContentValidationError(f"File contains HTML/text content instead of binary: {file_path}")
        
        # Additional check for JSON error responses
        if text_content.strip().startswith('{') and 'error' in text_content:
            try:
                data = json.loads(header.decode('utf-8'))
                if 'error' in data or 'message' in data:
                    logger.error(f"JSON error response detected: {data}")
                    raise ContentValidationError(f"File contains JSON error response: {file_path}")
            except (json.JSONDecodeError, UnicodeDecodeError):
                pass  # Not JSON, probably binary
        
        logger.debug(f"Binary content validation passed: {file_path}")
        return True
    
    def download_with_retry(
        self, 
        url: str, 
        dest_path: Union[str, Path], 
        validate: bool = True,
        headers: Optional[Dict[str, str]] = None,
        progress_callback: Optional[Callable[[int, int], None]] = None
    ) -> bool:
        """
        Download a file with automatic retry logic and validation.
        
        Args:
            url: URL to download
            dest_path: Destination path for the downloaded file
            validate: Whether to validate the downloaded content
            headers: Optional HTTP headers
            progress_callback: Optional callback for progress updates (bytes_downloaded, total_size)
            
        Returns:
            True if download successful, False otherwise
        """
        dest_path = Path(dest_path)
        last_exception = None
        
        for attempt in range(self.retry_attempts):
            try:
                logger.info(f"Download attempt {attempt + 1}/{self.retry_attempts}: {url}")
                
                success = self.download_file(
                    url=url,
                    dest_path=dest_path,
                    headers=headers,
                    progress_callback=progress_callback
                )
                
                if not success:
                    raise DownloadError("Download failed")
                
                if validate:
                    self.validate_binary_content(dest_path)
                
                logger.info(f"Download completed successfully: {dest_path}")
                return True
                
            except Exception as e:
                last_exception = e
                logger.warning(f"Download attempt {attempt + 1} failed: {e}")
                
                # Clean up partial download
                if dest_path.exists():
                    try:
                        dest_path.unlink()
                    except Exception:
                        pass
                
                # Wait before retry (exponential backoff)
                if attempt < self.retry_attempts - 1:
                    wait_time = min(300, (2 ** attempt) * 5)  # Cap at 5 minutes
                    logger.info(f"Waiting {wait_time} seconds before retry...")
                    time.sleep(wait_time)
        
        logger.error(f"All download attempts failed for {url}")
        if last_exception:
            logger.error(f"Last error: {last_exception}")
        
        return False
    
    def download_file(
        self,
        url: str,
        dest_path: Union[str, Path],
        headers: Optional[Dict[str, str]] = None,
        progress_callback: Optional[Callable[[int, int], None]] = None
    ) -> bool:
        """
        Download a file from URL to destination path.
        
        Args:
            url: URL to download from
            dest_path: Path where to save the downloaded file
            headers: Optional HTTP headers to include in request
            progress_callback: Optional callback for progress updates (bytes_downloaded, total_size)
            
        Returns:
            True if download successful, False otherwise
            
        Raises:
            DownloadError: For general download failures
            ProxyError: For proxy-related issues
            SSLError: For SSL-related issues
        """
        dest_path = Path(dest_path)
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Determine download method
        if self.use_requests:
            return self._download_with_requests(url, dest_path, headers, progress_callback)
        else:
            return self._download_with_urllib(url, dest_path, headers, progress_callback)
    
    def _download_with_requests(
        self,
        url: str,
        dest_path: Path,
        headers: Optional[Dict[str, str]],
        progress_callback: Optional[Callable[[int, int], None]]
    ) -> bool:
        """Download using requests library."""
        try:
            # Prepare headers
            request_headers = {
                'User-Agent': 'Serena-Agent/1.0 (Enterprise-Downloader)'
            }
            if headers:
                request_headers.update(headers)
            
            # VS Code Marketplace specific headers
            if 'marketplace.visualstudio.com' in url:
                request_headers.update({
                    'Accept': 'application/octet-stream, application/vsix, */*',
                    'Accept-Encoding': 'gzip, deflate, br',
                    'Accept-Language': 'en-US,en;q=0.9',
                    'Cache-Control': 'no-cache'
                })
            
            # Make request
            response = self.session.get(
                url,
                headers=request_headers,
                timeout=self.timeout,
                stream=True
            )
            response.raise_for_status()
            
            # Get total size
            total_size = int(response.headers.get('content-length', 0))
            logger.info(f"Downloading {url} ({total_size / 1024 / 1024:.1f} MB)")
            
            # Download with progress tracking
            downloaded = 0
            with open(dest_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress_callback and total_size > 0:
                            progress_callback(downloaded, total_size)
                        
                        # Log progress every 10MB
                        if total_size > 0 and downloaded % (10 * 1024 * 1024) == 0:
                            progress = (downloaded / total_size) * 100
                            logger.info(f"Progress: {progress:.1f}%")
            
            logger.debug(f"Download completed: {dest_path}")
            return True
            
        except requests.exceptions.ProxyError as e:
            raise ProxyError(f"Proxy error: {e}")
        except requests.exceptions.SSLError as e:
            raise SSLError(f"SSL error: {e}")
        except requests.exceptions.Timeout as e:
            raise DownloadError(f"Timeout error: {e}")
        except requests.exceptions.RequestException as e:
            raise DownloadError(f"Request error: {e}")
        except Exception as e:
            raise DownloadError(f"Unexpected error: {e}")
    
    def _download_with_urllib(
        self,
        url: str,
        dest_path: Path,
        headers: Optional[Dict[str, str]],
        progress_callback: Optional[Callable[[int, int], None]]
    ) -> bool:
        """Download using urllib."""
        try:
            # Prepare headers
            request_headers = {
                'User-Agent': 'Serena-Agent/1.0 (Enterprise-Downloader)'
            }
            if headers:
                request_headers.update(headers)
            
            # VS Code Marketplace specific headers
            if 'marketplace.visualstudio.com' in url:
                request_headers.update({
                    'Accept': 'application/octet-stream, application/vsix, */*',
                    'Accept-Encoding': 'gzip, deflate, br',
                    'Accept-Language': 'en-US,en;q=0.9',
                    'Cache-Control': 'no-cache'
                })
            
            # Create request
            req = urllib.request.Request(url, headers=request_headers)
            
            # Open connection
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                total_size = int(response.headers.get('content-length', 0))
                logger.info(f"Downloading {url} ({total_size / 1024 / 1024:.1f} MB)")
                
                # Download with progress tracking
                downloaded = 0
                with open(dest_path, 'wb') as f:
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress_callback and total_size > 0:
                            progress_callback(downloaded, total_size)
                        
                        # Log progress every 10MB
                        if total_size > 0 and downloaded % (10 * 1024 * 1024) == 0:
                            progress = (downloaded / total_size) * 100
                            logger.info(f"Progress: {progress:.1f}%")
            
            logger.debug(f"Download completed: {dest_path}")
            return True
            
        except urllib.error.HTTPError as e:
            if e.code == 407:  # Proxy Authentication Required
                raise ProxyError(f"Proxy authentication required: {e}")
            else:
                raise DownloadError(f"HTTP error {e.code}: {e}")
        except urllib.error.URLError as e:
            if 'SSL' in str(e) or 'CERTIFICATE' in str(e.reason).upper():
                raise SSLError(f"SSL error: {e}")
            elif 'proxy' in str(e).lower():
                raise ProxyError(f"Proxy error: {e}")
            else:
                raise DownloadError(f"URL error: {e}")
        except socket.timeout as e:
            raise DownloadError(f"Timeout error: {e}")
        except Exception as e:
            raise DownloadError(f"Unexpected error: {e}")
    
    def download_vscode_extension(
        self,
        publisher: str,
        extension: str,
        version: str = "latest",
        dest_path: Optional[Union[str, Path]] = None
    ) -> Tuple[bool, Optional[Path]]:
        """
        Download a VS Code extension from the marketplace.
        
        Args:
            publisher: Extension publisher name
            extension: Extension name
            version: Extension version (default: "latest")
            dest_path: Optional destination path (auto-generated if not provided)
            
        Returns:
            Tuple of (success, downloaded_file_path)
        """
        if dest_path is None:
            dest_path = Path(f"{publisher}-{extension}-{version}.vsix")
        else:
            dest_path = Path(dest_path)
        
        # VS Code Marketplace API URL
        if version == "latest":
            url = f"https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{extension}/latest/vspackage"
        else:
            url = f"https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{extension}/{version}/vspackage"
        
        logger.info(f"Downloading VS Code extension: {publisher}.{extension} (v{version})")
        
        # Special headers for VS Code marketplace
        headers = {
            'Accept': 'application/octet-stream, application/vsix, */*',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        try:
            success = self.download_with_retry(url, dest_path, validate=True, headers=headers)
            if success:
                logger.info(f"Successfully downloaded extension: {dest_path}")
                return True, dest_path
            else:
                logger.error(f"Failed to download extension: {publisher}.{extension}")
                return False, None
                
        except Exception as e:
            logger.error(f"Exception downloading extension {publisher}.{extension}: {e}")
            return False, None
    
    def get_troubleshooting_info(self) -> Dict[str, str]:
        """
        Get troubleshooting information for debugging download issues.
        
        Returns:
            Dictionary with troubleshooting information
        """
        info = {
            'library': 'requests' if self.use_requests else 'urllib',
            'ssl_verify': str(self.ssl_verify),
            'ca_bundle': self.ca_bundle or 'system default',
            'proxy_configured': 'yes' if self.proxy else 'no',
            'timeout': str(self.timeout),
            'retry_attempts': str(self.retry_attempts),
        }
        
        # Add proxy info (sanitized)
        if self.proxy:
            info['proxy_details'] = str(self._sanitize_proxy_for_logging(self.proxy))
        
        # Add environment variables
        env_vars = [
            'HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY',
            'SSL_CERT_FILE', 'REQUESTS_CA_BUNDLE', 'SSL_VERIFY',
            'DOWNLOAD_TIMEOUT', 'DOWNLOAD_RETRY_ATTEMPTS'
        ]
        
        for var in env_vars:
            value = os.getenv(var)
            if value and 'PROXY' in var:
                # Sanitize proxy URLs
                parsed = urllib.parse.urlparse(value)
                if parsed.username or parsed.password:
                    value = f"{parsed.scheme}://***:***@{parsed.hostname}:{parsed.port or 80}"
            info[f'env_{var}'] = value or 'not set'
        
        return info


def create_progress_callback(description: str = "Downloading") -> Callable[[int, int], None]:
    """
    Create a progress callback function for download progress tracking.
    
    Args:
        description: Description to show in progress updates
        
    Returns:
        Progress callback function
    """
    last_reported = 0
    
    def progress_callback(downloaded: int, total: int):
        nonlocal last_reported
        if total > 0:
            percent = (downloaded / total) * 100
            # Report every 5% or every 10MB
            if percent - last_reported >= 5 or downloaded - last_reported >= 10 * 1024 * 1024:
                print(f"\r{description}: {percent:.1f}% ({downloaded / 1024 / 1024:.1f}/{total / 1024 / 1024:.1f} MB)", end="", flush=True)
                last_reported = percent
                if percent >= 100:
                    print()  # New line when complete
    
    return progress_callback


def main():
    """Example usage and testing."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Enterprise Downloader Test")
    parser.add_argument("url", help="URL to download")
    parser.add_argument("-o", "--output", help="Output file path")
    parser.add_argument("--no-ssl-verify", action="store_true", help="Disable SSL verification")
    parser.add_argument("--use-urllib", action="store_true", help="Force use of urllib")
    parser.add_argument("--retry-attempts", type=int, default=3, help="Number of retry attempts")
    parser.add_argument("--timeout", type=int, default=300, help="Timeout in seconds")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    
    args = parser.parse_args()
    
    # Setup logging
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)
    
    # Create downloader
    downloader = EnterpriseDownloader(
        ssl_verify=not args.no_ssl_verify,
        retry_attempts=args.retry_attempts,
        timeout=args.timeout,
        use_requests=not args.use_urllib
    )
    
    # Print troubleshooting info
    print("Configuration:")
    for key, value in downloader.get_troubleshooting_info().items():
        print(f"  {key}: {value}")
    print()
    
    # Determine output file
    output_file = args.output
    if not output_file:
        parsed_url = urllib.parse.urlparse(args.url)
        output_file = Path(parsed_url.path).name or "downloaded_file"
    
    # Download with progress
    progress = create_progress_callback("Downloading")
    
    try:
        success = downloader.download_with_retry(
            url=args.url,
            dest_path=output_file,
            validate=True,
            progress_callback=progress
        )
        
        if success:
            print(f"✅ Download successful: {output_file}")
            file_size = Path(output_file).stat().st_size
            print(f"File size: {file_size / 1024 / 1024:.1f} MB")
        else:
            print("❌ Download failed")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ Download error: {e}")
        sys.exit(1)


def create_enterprise_downloader_from_args(args) -> EnterpriseDownloader:
    """Create EnterpriseDownloader from command line arguments."""
    return EnterpriseDownloader(
        ssl_verify=not getattr(args, 'no_ssl_verify', False),
        retry_attempts=getattr(args, 'retry_attempts', 3),
        timeout=getattr(args, 'timeout', 300),
        use_requests=not getattr(args, 'use_urllib', False)
    )


def add_enterprise_args(parser) -> None:
    """Add enterprise networking arguments to argument parser."""
    enterprise_group = parser.add_argument_group('enterprise networking')
    
    enterprise_group.add_argument(
        '--no-ssl-verify',
        action='store_true',
        help='Disable SSL certificate verification (not recommended)'
    )
    
    enterprise_group.add_argument(
        '--retry-attempts',
        type=int,
        default=3,
        help='Number of retry attempts on download failure (default: 3)'
    )
    
    enterprise_group.add_argument(
        '--timeout',
        type=int,
        default=300,
        help='Download timeout in seconds (default: 300)'
    )
    
    enterprise_group.add_argument(
        '--use-urllib',
        action='store_true',
        help='Use urllib instead of requests (for compatibility)'
    )
    
    enterprise_group.add_argument(
        '--enterprise',
        action='store_true',
        help='Enable automatic enterprise mode detection'
    )


if __name__ == "__main__":
    main()