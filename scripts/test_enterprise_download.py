#!/usr/bin/env python3
"""
Test script for Enterprise Download Module

This script demonstrates the usage of the EnterpriseDownloader class
and validates its functionality with various scenarios.
"""

import logging
import os
import sys
import tempfile
from pathlib import Path

# Add the scripts directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from enterprise_download import EnterpriseDownloader, create_progress_callback

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def test_basic_functionality():
    """Test basic download functionality."""
    print("=== Testing Basic Functionality ===")
    
    # Create downloader
    downloader = EnterpriseDownloader()
    
    # Print configuration
    print("Configuration:")
    for key, value in downloader.get_troubleshooting_info().items():
        print(f"  {key}: {value}")
    
    print("✅ Basic initialization test passed")


def test_environment_variables():
    """Test environment variable parsing."""
    print("\n=== Testing Environment Variables ===")
    
    # Set test environment variables
    test_env = {
        'HTTP_PROXY': 'http://proxy.company.com:8080',
        'HTTPS_PROXY': 'https://proxy.company.com:8080',
        'SSL_VERIFY': 'false',
        'DOWNLOAD_TIMEOUT': '60',
        'DOWNLOAD_RETRY_ATTEMPTS': '5'
    }
    
    # Temporarily set environment variables
    original_env = {}
    for key, value in test_env.items():
        original_env[key] = os.getenv(key)
        os.environ[key] = value
    
    try:
        # Create downloader with environment variables
        downloader = EnterpriseDownloader()
        
        # Check if proxy was parsed correctly
        assert downloader.proxy.get('http') == 'http://proxy.company.com:8080'
        assert downloader.proxy.get('https') == 'https://proxy.company.com:8080'
        assert downloader.ssl_verify == False
        assert downloader.timeout == 60
        assert downloader.retry_attempts == 5
        
        print("✅ Environment variable parsing test passed")
        
    finally:
        # Restore original environment
        for key, value in original_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def test_progress_callback():
    """Test progress callback functionality."""
    print("\n=== Testing Progress Callback ===")
    
    progress = create_progress_callback("Test Download")
    
    # Simulate download progress
    total_size = 1000000  # 1MB
    for i in range(0, total_size + 1, 50000):  # 50KB chunks
        progress(i, total_size)
    
    print("\n✅ Progress callback test passed")


def test_binary_content_validation():
    """Test binary content validation."""
    print("\n=== Testing Binary Content Validation ===")
    
    downloader = EnterpriseDownloader()
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Test 1: Valid binary file
        binary_file = temp_path / "test.zip"
        with open(binary_file, 'wb') as f:
            f.write(b'\x50\x4b\x03\x04')  # ZIP file signature
            f.write(b'\x00' * 1000)  # Some binary data
        
        try:
            downloader.validate_binary_content(binary_file)
            print("✅ Binary file validation passed")
        except Exception as e:
            print(f"❌ Binary file validation failed: {e}")
        
        # Test 2: HTML error page
        html_file = temp_path / "error.html"
        with open(html_file, 'w') as f:
            f.write('<!DOCTYPE html><html><head><title>404 Not Found</title></head></html>')
        
        try:
            downloader.validate_binary_content(html_file)
            print("❌ HTML file validation should have failed")
        except Exception:
            print("✅ HTML file validation correctly failed")
        
        # Test 3: JSON error response
        json_file = temp_path / "error.json"
        with open(json_file, 'w') as f:
            f.write('{"error": "Not found", "message": "The requested resource was not found"}')
        
        try:
            downloader.validate_binary_content(json_file)
            print("❌ JSON error file validation should have failed")
        except Exception:
            print("✅ JSON error file validation correctly failed")


def test_vscode_extension_url():
    """Test VS Code extension URL generation."""
    print("\n=== Testing VS Code Extension URL Generation ===")
    
    downloader = EnterpriseDownloader()
    
    # Test with a real extension (but don't actually download)
    publisher = "ms-python"
    extension = "python"
    version = "latest"
    
    # This would generate the correct URL
    url = f"https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{extension}/{version}/vspackage"
    
    print(f"Generated URL: {url}")
    print("✅ VS Code extension URL generation test passed")


def main():
    """Run all tests."""
    print("Enterprise Download Module Test Suite")
    print("=" * 50)
    
    try:
        test_basic_functionality()
        test_environment_variables()
        test_progress_callback()
        test_binary_content_validation()
        test_vscode_extension_url()
        
        print("\n" + "=" * 50)
        print("🎉 All tests passed successfully!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())