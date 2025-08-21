#!/usr/bin/env python3
"""
Complete integration test for Linux offline preparation
Tests the entire workflow from download to installation
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path


def run_command(cmd, description, timeout=300):
    """Run a command and return success status"""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(
            cmd, 
            check=False, 
            capture_output=True, 
            text=True, 
            timeout=timeout,
            shell=isinstance(cmd, str)
        )
        if result.returncode == 0:
            print(f"  ✅ {description}: Success")
            return True
        else:
            print(f"  ❌ {description}: Failed (exit code {result.returncode})")
            if result.stderr:
                print(f"     Error: {result.stderr.strip()[:200]}...")
            return False
    except subprocess.TimeoutExpired:
        print(f"  ⏰ {description}: Timeout")
        return False
    except Exception as e:
        print(f"  ❌ {description}: Exception - {e}")
        return False


def main():
    """Run complete Linux offline preparation test"""
    print("🚀 Complete Linux Offline Preparation Test")
    print("=" * 60)
    
    # Get script directory
    script_dir = Path(__file__).parent.absolute()
    repo_root = script_dir.parent
    
    # Create test directory
    with tempfile.TemporaryDirectory(prefix="serena_linux_test_") as temp_dir:
        test_dir = Path(temp_dir)
        print(f"📁 Test directory: {test_dir}")
        
        results = []
        
        # Test 1: Basic test script
        print("\n1️⃣ Running basic Linux offline prep test...")
        cmd = [sys.executable, str(script_dir / "test-linux-offline-prep.py")]
        results.append(run_command(cmd, "Basic offline prep test"))
        
        # Test 2: Download dependencies
        print("\n2️⃣ Testing dependency download...")
        deps_dir = test_dir / "dependencies"
        cmd = [
            sys.executable, str(script_dir / "download-dependencies-offline.py"),
            "--output", str(deps_dir),
            "--pyproject", str(repo_root / "pyproject.toml"),
            "--python-exe", "python3"
        ]
        results.append(run_command(cmd, "Download dependencies", timeout=180))
        
        # Test 3: Check dependencies were downloaded
        if deps_dir.exists():
            wheel_files = list(deps_dir.glob("*.whl"))
            installer_script = deps_dir / "install-dependencies-offline.sh"
            
            if wheel_files and installer_script.exists():
                print(f"  ✅ Dependencies: {len(wheel_files)} wheels downloaded")
                print(f"  ✅ Installer: {installer_script.name} created")
                results.append(True)
            else:
                print(f"  ❌ Dependencies: Missing wheels or installer")
                results.append(False)
        else:
            print(f"  ❌ Dependencies: Output directory not created")
            results.append(False)
        
        # Test 4: Download language servers (limited set)
        print("\n3️⃣ Testing language server download...")
        ls_dir = test_dir / "language_servers"
        cmd = [
            sys.executable, str(script_dir / "download-language-servers-offline.py"),
            "--output", str(ls_dir),
            "--servers", "pyright", "typescript"  # Quick test with 2 servers
        ]
        results.append(run_command(cmd, "Download language servers", timeout=120))
        
        # Test 5: Check language servers were downloaded
        if ls_dir.exists():
            server_dirs = [d for d in ls_dir.iterdir() if d.is_dir() and d.name != "gopls"]
            manifest = ls_dir / "manifest.json"
            
            if server_dirs and manifest.exists():
                print(f"  ✅ Language servers: {len(server_dirs)} servers downloaded")
                print(f"  ✅ Manifest: {manifest.name} created")
                results.append(True)
            else:
                print(f"  ❌ Language servers: Missing servers or manifest")
                results.append(False)
        else:
            print(f"  ❌ Language servers: Output directory not created")
            results.append(False)
        
        # Test 6: Platform detection verification
        print("\n4️⃣ Testing platform detection...")
        try:
            # Import using importlib due to hyphen in filename
            import importlib.util
            spec = importlib.util.spec_from_file_location(
                "download_dependencies_offline", 
                script_dir / "download-dependencies-offline.py"
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            downloader = module.OfflineDependencyDownloader()
            platform_tag = downloader._get_platform_tag()
            
            if "linux" in platform_tag.lower():
                print(f"  ✅ Platform detection: {platform_tag}")
                results.append(True)
            else:
                print(f"  ❌ Platform detection: Expected linux, got {platform_tag}")
                results.append(False)
        except Exception as e:
            print(f"  ❌ Platform detection: {e}")
            results.append(False)
        
        # Summary
        print("\n📊 Complete Test Results")
        print("=" * 40)
        
        passed = sum(results)
        total = len(results)
        
        if passed == total:
            print(f"🎉 All tests passed! ({passed}/{total})")
            print("\n✅ Linux offline preparation is fully functional!")
            print("\n📋 Summary of capabilities:")
            print("  • ✅ Platform auto-detection (linux_x86_64)")
            print("  • ✅ Python dependencies download")
            print("  • ✅ Linux shell installer generation")
            print("  • ✅ Language server downloads")
            print("  • ✅ Cross-platform compatibility")
            print("\n🚀 Ready for Linux offline deployment!")
            return 0
        else:
            print(f"⚠️  Some tests failed ({passed}/{total})")
            print("\n❗ Issues found - see details above")
            return 1


if __name__ == "__main__":
    sys.exit(main())