#!/usr/bin/env python3
"""
Test script to verify Windows compatibility after Linux fixes
Ensures that Windows offline preparation still works correctly
"""

import os
import sys
import tempfile
from pathlib import Path


def test_windows_platform_detection():
    """Test that Windows platform detection works"""
    print("🔍 Testing Windows Platform Detection...")
    
    # Import the module
    import importlib.util
    script_dir = Path(__file__).parent
    spec = importlib.util.spec_from_file_location(
        "download_deps", 
        script_dir / "download-dependencies-offline.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    
    # Test Windows platform override
    downloader_win = module.OfflineDependencyDownloader(platform_override="win_amd64")
    platform_tag = downloader_win._get_platform_tag()
    
    if platform_tag == "win_amd64":
        print(f"  ✅ Windows platform override: {platform_tag}")
        return True
    else:
        print(f"  ❌ Windows platform override failed: {platform_tag}")
        return False


def test_windows_installer_creation():
    """Test that Windows batch installer is created"""
    print("\n📝 Testing Windows Installer Creation...")
    
    with tempfile.TemporaryDirectory(prefix="test_win_") as temp_dir:
        temp_path = Path(temp_dir)
        
        # Import and test
        import importlib.util
        script_dir = Path(__file__).parent
        spec = importlib.util.spec_from_file_location(
            "download_deps", 
            script_dir / "download-dependencies-offline.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        
        # Create Windows downloader
        downloader = module.OfflineDependencyDownloader(platform_override="win_amd64")
        
        # Create installer
        downloader.create_offline_installer(temp_path)
        
        # Check if .bat file was created
        bat_file = temp_path / "install-dependencies-offline.bat"
        if bat_file.exists():
            # Check content
            content = bat_file.read_text()
            if "@echo off" in content and "PYTHONHOME" in content:
                print(f"  ✅ Windows batch installer created correctly")
                return True
            else:
                print(f"  ❌ Windows batch installer has incorrect content")
                return False
        else:
            print(f"  ❌ Windows batch installer not created")
            return False


def test_language_server_urls():
    """Test that Windows language server URLs are correct"""
    print("\n🔗 Testing Windows Language Server URLs...")
    
    # Import language server module
    import importlib.util
    script_dir = Path(__file__).parent
    spec = importlib.util.spec_from_file_location(
        "download_ls", 
        script_dir / "download-language-servers-offline.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    
    servers = module.get_language_servers()
    windows_servers = []
    
    for name, info in servers.items():
        if info.get("platform_specific"):
            win_url = info["platforms"].get("win32")
            if win_url:
                windows_servers.append((name, win_url))
    
    if windows_servers:
        print(f"  ✅ Found {len(windows_servers)} Windows-specific language servers")
        # Check a few URLs format
        sample_checks = [
            ("rust-analyzer", "windows"),
            ("clangd", "windows"),
            ("terraform-ls", "windows_amd64")
        ]
        
        passed = 0
        for server_name, expected_keyword in sample_checks:
            for name, url in windows_servers:
                if name == server_name:
                    if expected_keyword.lower() in url.lower():
                        print(f"    ✅ {server_name}: Correct Windows URL")
                        passed += 1
                    else:
                        print(f"    ❌ {server_name}: Incorrect URL format")
                    break
        
        return passed == len(sample_checks)
    else:
        print(f"  ❌ No Windows-specific language servers found")
        return False


def test_cross_platform_compatibility():
    """Test that both Windows and Linux work from same codebase"""
    print("\n🌍 Testing Cross-Platform Compatibility...")
    
    # Import module
    import importlib.util
    script_dir = Path(__file__).parent
    spec = importlib.util.spec_from_file_location(
        "download_deps", 
        script_dir / "download-dependencies-offline.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    
    with tempfile.TemporaryDirectory(prefix="test_cross_") as temp_dir:
        temp_path = Path(temp_dir)
        
        # Test Windows
        win_downloader = module.OfflineDependencyDownloader(platform_override="win_amd64")
        win_downloader.create_offline_installer(temp_path)
        
        # Test Linux
        linux_downloader = module.OfflineDependencyDownloader(platform_override="linux_x86_64")
        linux_downloader.create_offline_installer(temp_path)
        
        # Check both installers exist
        bat_file = temp_path / "install-dependencies-offline.bat"
        sh_file = temp_path / "install-dependencies-offline.sh"
        
        if bat_file.exists() and sh_file.exists():
            print(f"  ✅ Both Windows (.bat) and Linux (.sh) installers created")
            return True
        else:
            if not bat_file.exists():
                print(f"  ❌ Windows installer missing")
            if not sh_file.exists():
                print(f"  ❌ Linux installer missing")
            return False


def main():
    """Run all Windows compatibility tests"""
    print("🪟 Windows Compatibility Test Suite")
    print("=" * 50)
    print("Verifying Windows support after Linux fixes...")
    
    test_results = []
    
    # Run tests
    test_results.append(test_windows_platform_detection())
    test_results.append(test_windows_installer_creation())
    test_results.append(test_language_server_urls())
    test_results.append(test_cross_platform_compatibility())
    
    # Summary
    print("\n📊 Windows Compatibility Test Results")
    print("=" * 40)
    
    passed = sum(test_results)
    total = len(test_results)
    
    if passed == total:
        print(f"🎉 All tests passed! ({passed}/{total})")
        print("\n✅ Windows compatibility CONFIRMED!")
        print("\nCapabilities verified:")
        print("  • ✅ Windows platform detection (win_amd64)")
        print("  • ✅ Windows batch installer (.bat) generation")
        print("  • ✅ Windows-specific language server URLs")
        print("  • ✅ Cross-platform support (Windows + Linux)")
        print("\n🚀 Windows offline deployment remains fully functional!")
        return 0
    else:
        print(f"⚠️  Some tests failed ({passed}/{total})")
        print("\n❗ Windows compatibility may have issues")
        return 1


if __name__ == "__main__":
    sys.exit(main())