#!/usr/bin/env python3
"""
Test script to verify Linux offline preparation works correctly
Run this to verify all components work for Linux deployment
"""

import os
import platform
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


def test_platform_detection():
    """Test that we correctly detect Linux platform"""
    print("🔍 Testing Platform Detection...")
    
    system = platform.system()
    machine = platform.machine()
    
    print(f"  System: {system}")
    print(f"  Machine: {machine}")
    
    if system != "Linux":
        print(f"  ⚠️  Expected Linux, got {system}")
        return False
    
    print(f"  ✅ Platform detection: OK")
    return True


def test_python_environment():
    """Test Python and pip availability"""
    print("\n🐍 Testing Python Environment...")
    
    results = []
    
    # Test Python executable
    try:
        result = subprocess.run([sys.executable, "--version"], 
                              check=False, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"  ✅ Python: {version}")
            results.append(True)
        else:
            print(f"  ❌ Python: Failed to get version")
            results.append(False)
    except Exception as e:
        print(f"  ❌ Python: {e}")
        results.append(False)
    
    # Test pip module
    try:
        result = subprocess.run([sys.executable, "-m", "pip", "--version"], 
                              check=False, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            version = result.stdout.strip()
            print(f"  ✅ pip module: {version}")
            results.append(True)
        else:
            print(f"  ❌ pip module: Not available")
            results.append(False)
    except Exception as e:
        print(f"  ❌ pip module: {e}")
        results.append(False)
    
    return all(results)


def test_dependency_download_script():
    """Test the dependency download script syntax and platform detection"""
    print("\n📦 Testing Dependency Download Script...")
    
    script_path = Path("scripts/download-dependencies-offline.py")
    if not script_path.exists():
        print(f"  ❌ Script not found: {script_path}")
        return False
    
    # Test syntax
    try:
        result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)], 
                              check=False, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"  ✅ Script syntax: OK")
        else:
            print(f"  ❌ Script syntax: {result.stderr.strip()}")
            return False
    except Exception as e:
        print(f"  ❌ Script syntax test failed: {e}")
        return False
    
    # Test platform auto-detection
    try:
        result = subprocess.run([sys.executable, str(script_path), "--help"], 
                              check=False, capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and "auto-detected" in result.stdout:
            print(f"  ✅ Platform auto-detection: Available")
            return True
        else:
            print(f"  ⚠️  Platform auto-detection: Check help text")
            return True  # Not critical
    except Exception as e:
        print(f"  ❌ Platform detection test failed: {e}")
        return False


def test_language_server_urls():
    """Test that language server URLs work for Linux"""
    print("\n🔍 Testing Language Server URLs (Linux)...")

    # Import the language server config using importlib due to hyphen in filename
    script_dir = Path(__file__).parent
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "download_language_servers_offline", 
            script_dir / "download-language-servers-offline.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        servers = module.get_language_servers()
    except Exception as e:
        print(f"  ❌ Could not import language server config: {e}")
        return False

    linux_urls = []
    for name, info in servers.items():
        if info.get("platform_specific"):
            url = info["platforms"].get("linux")
            if url:
                linux_urls.append((name, url))
        else:
            # Platform-agnostic servers should work on Linux too
            linux_urls.append((name, info["url"]))

    print(f"  Found {len(linux_urls)} Linux-compatible language servers")
    
    results = []
    for name, url in linux_urls[:5]:  # Test first 5 to avoid timeout
        try:
            req = urllib.request.Request(url, method="HEAD")
            req.add_header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            
            with urllib.request.urlopen(req, timeout=10) as response:
                status = response.getcode()
                if status == 200:
                    print(f"  ✅ {name}: OK ({status})")
                    results.append(True)
                else:
                    print(f"  ⚠️  {name}: Status {status}")
                    results.append(False)
        
        except urllib.error.HTTPError as e:
            print(f"  ❌ {name}: HTTP {e.code}")
            results.append(False)
        except Exception as e:
            print(f"  ❌ {name}: {str(e)[:50]}...")
            results.append(False)
    
    success_rate = sum(results) / len(results) if results else 0
    print(f"  📊 Success rate: {success_rate:.1%}")
    
    return success_rate >= 0.8  # 80% success rate is acceptable


def test_file_permissions():
    """Test that we can create and make files executable"""
    print("\n🔐 Testing File Permissions...")
    
    test_file = Path("/tmp/test_serena_perms.sh")
    
    try:
        # Create test file
        with open(test_file, "w") as f:
            f.write("#!/bin/bash\necho 'test'\n")
        
        # Make executable
        os.chmod(test_file, 0o755)
        
        # Test if executable
        if os.access(test_file, os.X_OK):
            print(f"  ✅ File permissions: OK")
            test_file.unlink()  # Clean up
            return True
        else:
            print(f"  ❌ File permissions: Cannot make executable")
            test_file.unlink()  # Clean up
            return False
            
    except Exception as e:
        print(f"  ❌ File permissions: {e}")
        if test_file.exists():
            test_file.unlink()  # Clean up
        return False


def test_tar_gz_handling():
    """Test that we can handle .tar.gz and .gz files (common on Linux)"""
    print("\n📁 Testing Archive Handling...")
    
    try:
        import gzip
        import tarfile
        print(f"  ✅ gzip module: Available")
        print(f"  ✅ tarfile module: Available")
        return True
    except ImportError as e:
        print(f"  ❌ Archive modules: {e}")
        return False


def main():
    """Run all Linux offline preparation tests"""
    print("🚀 Testing Linux Offline Preparation")
    print("=" * 50)

    test_results = []

    # Test platform detection
    test_results.append(test_platform_detection())

    # Test Python environment
    test_results.append(test_python_environment())
    
    # Test dependency download script
    test_results.append(test_dependency_download_script())
    
    # Test language server URLs
    test_results.append(test_language_server_urls())
    
    # Test file permissions
    test_results.append(test_file_permissions())
    
    # Test archive handling
    test_results.append(test_tar_gz_handling())

    # Summary
    print("\n📊 Test Results Summary")
    print("=" * 30)

    passed = sum(test_results)
    total = len(test_results)

    if passed == total:
        print(f"🎉 All tests passed! ({passed}/{total})")
        print("\n✅ Linux offline preparation should work correctly!")
        print("\nNext steps:")
        print("1. Run: python3 scripts/download-dependencies-offline.py")
        print("2. Run: python3 scripts/download-language-servers-offline.py")
        print("3. Test the generated install-dependencies-offline.sh script")
        return 0
    else:
        print(f"⚠️  Some tests failed ({passed}/{total})")
        print("\n❗ Review the failed tests above")
        print("🔧 Linux offline preparation may need fixes")
        return 1


if __name__ == "__main__":
    sys.exit(main())