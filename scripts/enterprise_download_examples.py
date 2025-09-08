#!/usr/bin/env python3
"""
Enterprise Download Module - Usage Examples

This script demonstrates various usage patterns for the EnterpriseDownloader
class in different enterprise scenarios.

Author: Serena Agent Team
License: MIT
"""

import os
import sys
import tempfile
from pathlib import Path

# Add the scripts directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from enterprise_download import (
    EnterpriseDownloader, 
    create_progress_callback,
    DownloadError,
    ProxyError,
    SSLError,
    ContentValidationError
)

def example_basic_usage():
    """Example 1: Basic download with default settings."""
    print("=== Example 1: Basic Download ===")
    
    downloader = EnterpriseDownloader()
    
    # This would download a real file (commented out for safety)
    # success = downloader.download_file(
    #     url="https://example.com/file.zip",
    #     dest_path="downloaded_file.zip"
    # )
    
    print("Downloader configured with default settings:")
    for key, value in downloader.get_troubleshooting_info().items():
        print(f"  {key}: {value}")
    print()


def example_proxy_configuration():
    """Example 2: Enterprise proxy configuration."""
    print("=== Example 2: Proxy Configuration ===")
    
    # Method 1: Direct configuration
    proxy_config = {
        'http': 'http://proxy.company.com:8080',
        'https': 'https://proxy.company.com:8080'
    }
    
    downloader = EnterpriseDownloader(proxy=proxy_config)
    
    # Method 2: Environment variables (preferred)
    os.environ['HTTP_PROXY'] = 'http://proxy.company.com:8080'
    os.environ['HTTPS_PROXY'] = 'https://proxy.company.com:8080'
    
    # Downloader will automatically pick up environment variables
    downloader_env = EnterpriseDownloader()
    
    print("Proxy configuration methods demonstrated")
    print("Environment-based proxy info:")
    for key, value in downloader_env.get_troubleshooting_info().items():
        if 'proxy' in key.lower():
            print(f"  {key}: {value}")
    
    # Cleanup
    os.environ.pop('HTTP_PROXY', None)
    os.environ.pop('HTTPS_PROXY', None)
    print()


def example_ssl_configuration():
    """Example 3: SSL certificate handling."""
    print("=== Example 3: SSL Configuration ===")
    
    # Example 1: Disable SSL verification (not recommended for production)
    downloader_no_ssl = EnterpriseDownloader(ssl_verify=False)
    
    # Example 2: Custom CA bundle
    # downloader_custom_ca = EnterpriseDownloader(
    #     ca_bundle="/path/to/company-ca-bundle.crt"
    # )
    
    # Example 3: Environment variable configuration
    os.environ['SSL_VERIFY'] = 'false'
    # os.environ['SSL_CERT_FILE'] = '/path/to/ca-bundle.crt'
    
    downloader_env_ssl = EnterpriseDownloader()
    
    print("SSL configuration demonstrated")
    print(f"SSL verify disabled: {not downloader_no_ssl.ssl_verify}")
    print(f"Environment SSL verify: {downloader_env_ssl.ssl_verify}")
    
    # Cleanup
    os.environ.pop('SSL_VERIFY', None)
    print()


def example_retry_and_error_handling():
    """Example 4: Retry logic and error handling."""
    print("=== Example 4: Retry Logic and Error Handling ===")
    
    downloader = EnterpriseDownloader(retry_attempts=5, timeout=60)
    
    # Example of handling different error types
    def robust_download(url, dest_path):
        try:
            success = downloader.download_with_retry(url, dest_path, validate=True)
            if success:
                print(f"✅ Successfully downloaded: {dest_path}")
                return True
            else:
                print(f"❌ Download failed after all retries: {url}")
                return False
                
        except ProxyError as e:
            print(f"🔐 Proxy authentication issue: {e}")
            print("💡 Troubleshooting: Check proxy credentials and configuration")
            return False
            
        except SSLError as e:
            print(f"🔒 SSL certificate issue: {e}")
            print("💡 Troubleshooting: Check CA bundle or disable SSL verification")
            return False
            
        except ContentValidationError as e:
            print(f"📄 Content validation failed: {e}")
            print("💡 Troubleshooting: Server may be returning error page instead of file")
            return False
            
        except DownloadError as e:
            print(f"🌐 Network/download error: {e}")
            print("💡 Troubleshooting: Check network connectivity and URL")
            return False
    
    print("Retry and error handling patterns demonstrated")
    print(f"Configured with {downloader.retry_attempts} retry attempts")
    print(f"Timeout: {downloader.timeout} seconds")
    print()


def example_progress_tracking():
    """Example 5: Progress tracking with custom callback."""
    print("=== Example 5: Progress Tracking ===")
    
    # Create a custom progress callback
    def detailed_progress_callback(downloaded: int, total: int):
        if total > 0:
            percent = (downloaded / total) * 100
            downloaded_mb = downloaded / (1024 * 1024)
            total_mb = total / (1024 * 1024)
            speed_info = f"{downloaded_mb:.1f}/{total_mb:.1f} MB ({percent:.1f}%)"
            
            # Print every 1MB or 10%
            if downloaded % (1024 * 1024) == 0 or percent % 10 == 0:
                print(f"📥 Download progress: {speed_info}")
    
    # Also demonstrate the built-in progress callback
    simple_progress = create_progress_callback("Custom Download")
    
    print("Progress tracking callbacks created")
    print("- detailed_progress_callback: Shows detailed MB progress")
    print("- simple_progress: Built-in progress display")
    print()


def example_vscode_extensions():
    """Example 6: VS Code extension downloads."""
    print("=== Example 6: VS Code Extension Downloads ===")
    
    downloader = EnterpriseDownloader()
    
    # Example extensions to download (not actually downloading)
    extensions = [
        ("ms-python", "python", "latest"),
        ("ms-vscode", "csharp", "1.25.0"),
        ("redhat", "java", "latest")
    ]
    
    for publisher, extension, version in extensions:
        print(f"📦 Would download: {publisher}.{extension} v{version}")
        
        # The actual download call would be:
        # success, path = downloader.download_vscode_extension(
        #     publisher=publisher,
        #     extension=extension,
        #     version=version
        # )
    
    print("VS Code extension download patterns demonstrated")
    print()


def example_enterprise_environment_detection():
    """Example 7: Enterprise environment detection and configuration."""
    print("=== Example 7: Enterprise Environment Detection ===")
    
    # Check for common enterprise environment indicators
    enterprise_indicators = []
    
    # Check for proxy environment variables
    if os.getenv('HTTP_PROXY') or os.getenv('HTTPS_PROXY'):
        enterprise_indicators.append("Proxy configuration detected")
    
    # Check for custom CA certificates
    ca_locations = [
        os.getenv('SSL_CERT_FILE'),
        os.getenv('REQUESTS_CA_BUNDLE'),
        '/etc/ssl/certs/ca-certificates.crt',  # Common Linux location
        '/etc/pki/tls/certs/ca-bundle.crt',   # Common CentOS/RHEL location
    ]
    
    for ca_path in ca_locations:
        if ca_path and Path(ca_path).exists():
            enterprise_indicators.append(f"Custom CA bundle found: {ca_path}")
            break
    
    # Check for common corporate domains in environment
    corporate_domains = ['corp', 'internal', 'intranet', 'company']
    for var_name, var_value in os.environ.items():
        if any(domain in var_value.lower() for domain in corporate_domains):
            enterprise_indicators.append(f"Corporate domain detected in {var_name}")
            break
    
    if enterprise_indicators:
        print("🏢 Enterprise environment detected:")
        for indicator in enterprise_indicators:
            print(f"  • {indicator}")
        
        # Configure downloader for enterprise environment
        downloader = EnterpriseDownloader(
            retry_attempts=5,  # More retries for flaky corporate networks
            timeout=600,       # Longer timeout for slow corporate connections
        )
        print("📋 Configured with enterprise-friendly settings")
    else:
        print("🏠 Standard environment detected")
        downloader = EnterpriseDownloader()
        print("📋 Configured with default settings")
    
    print()


def example_integration_with_existing_code():
    """Example 8: Integration with existing download code."""
    print("=== Example 8: Integration with Existing Code ===")
    
    # Example of integrating with the existing offline_deps_downloader pattern
    class EnhancedOfflineDownloader:
        """Enhanced version of OfflineDepsDownloader using EnterpriseDownloader."""
        
        def __init__(self, output_dir: str):
            self.output_dir = Path(output_dir)
            self.output_dir.mkdir(parents=True, exist_ok=True)
            
            # Use enterprise downloader instead of raw urllib
            self.downloader = EnterpriseDownloader(
                retry_attempts=3,
                timeout=300
            )
        
        def download_with_progress(self, url: str, target_path: Path) -> bool:
            """Download with enterprise-grade error handling."""
            progress_callback = create_progress_callback(f"Downloading {target_path.name}")
            
            return self.downloader.download_with_retry(
                url=url,
                dest_path=target_path,
                validate=True,
                progress_callback=progress_callback
            )
        
        def download_gradle(self) -> bool:
            """Download Gradle with enterprise support."""
            url = "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip"
            target_path = self.output_dir / "gradle" / "gradle-8.14.2-bin.zip"
            target_path.parent.mkdir(exist_ok=True)
            
            return self.download_with_progress(url, target_path)
    
    # Example usage
    enhanced_downloader = EnhancedOfflineDownloader("./offline_deps")
    print("🔧 Enhanced offline downloader created")
    print("Features:")
    print("  • Enterprise proxy support")
    print("  • SSL certificate handling")
    print("  • Advanced retry logic")
    print("  • Content validation")
    print("  • Detailed error reporting")
    print()


def main():
    """Run all examples."""
    print("Enterprise Download Module - Usage Examples")
    print("=" * 60)
    print()
    
    examples = [
        example_basic_usage,
        example_proxy_configuration,
        example_ssl_configuration,
        example_retry_and_error_handling,
        example_progress_tracking,
        example_vscode_extensions,
        example_enterprise_environment_detection,
        example_integration_with_existing_code,
    ]
    
    for example_func in examples:
        try:
            example_func()
        except Exception as e:
            print(f"❌ Error in {example_func.__name__}: {e}")
            import traceback
            traceback.print_exc()
            print()
    
    print("=" * 60)
    print("📚 All examples completed!")
    print()
    print("💡 Key Takeaways:")
    print("  1. Environment variables provide the most flexible configuration")
    print("  2. Always handle specific exception types for better error reporting")  
    print("  3. Use retry logic with exponential backoff for reliable downloads")
    print("  4. Validate downloaded content to detect server error pages")
    print("  5. Enterprise environments often need custom proxy and SSL settings")


if __name__ == "__main__":
    main()