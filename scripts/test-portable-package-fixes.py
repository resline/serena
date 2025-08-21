#!/usr/bin/env python3
"""
Test script to verify portable package fixes
Run this after creating the portable package to verify all fixes work
"""

import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


def test_language_server_urls():
    """Test that language server URLs are accessible"""
    print("🔍 Testing Language Server URLs...")

    urls_to_test = [
        # gopls doesn't provide pre-built binaries anymore, skip it
        ("Java (JDT.LS)", "https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz"),
        ("Terraform", "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_windows_amd64.zip"),
        (
            "Clojure",
            "https://github.com/clojure-lsp/clojure-lsp/releases/download/2025.06.13-20.45.44/clojure-lsp-native-windows-amd64.zip",
        ),
        ("Rust", "https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-pc-windows-msvc.zip"),
    ]

    results = []
    for name, url in urls_to_test:
        try:
            req = urllib.request.Request(url, method="HEAD")
            req.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

            with urllib.request.urlopen(req, timeout=10) as response:
                status = response.getcode()
                if status == 200:
                    print(f"  ✅ {name}: OK ({status})")
                    results.append(True)
                else:
                    print(f"  ⚠️  {name}: Unexpected status {status}")
                    results.append(False)

        except urllib.error.HTTPError as e:
            print(f"  ❌ {name}: HTTP {e.code} - {e.reason}")
            results.append(False)
        except Exception as e:
            print(f"  ❌ {name}: {e!s}")
            results.append(False)

    return all(results)


def test_python_syntax():
    """Test Python script syntax"""
    print("\n🐍 Testing Python Script Syntax...")

    scripts_to_test = ["scripts/download-dependencies-offline.py", "scripts/download-language-servers-offline.py"]

    results = []
    for script in scripts_to_test:
        script_path = Path(script)
        if not script_path.exists():
            print(f"  ⚠️  {script}: File not found")
            results.append(False)
            continue

        try:
            result = subprocess.run(
                [sys.executable, "-m", "py_compile", str(script_path)], check=False, capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                print(f"  ✅ {script}: Syntax OK")
                results.append(True)
            else:
                print(f"  ❌ {script}: Syntax Error")
                print(f"     {result.stderr.strip()}")
                results.append(False)

        except Exception as e:
            print(f"  ❌ {script}: Test failed - {e!s}")
            results.append(False)

    return all(results)


def test_pip_methods():
    """Test different pip calling methods"""
    print("\n📦 Testing Pip Access Methods...")

    methods = [
        ([sys.executable, "-m", "pip", "--version"], "python -m pip"),
        (["pip", "--version"], "direct pip"),
    ]

    results = []
    for cmd, name in methods:
        try:
            result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version = result.stdout.strip()
                print(f"  ✅ {name}: Available - {version}")
                results.append(True)
            else:
                print(f"  ❌ {name}: Not available - {result.stderr.strip()}")
                results.append(False)
        except FileNotFoundError:
            print(f"  ❌ {name}: Command not found")
            results.append(False)
        except Exception as e:
            print(f"  ❌ {name}: Error - {e!s}")
            results.append(False)

    # At least one method should work
    return any(results)


def main():
    """Run all tests"""
    print("🚀 Testing Portable Package Fixes")
    print("=" * 50)

    test_results = []

    # Test language server URLs
    test_results.append(test_language_server_urls())

    # Test Python syntax
    test_results.append(test_python_syntax())

    # Test pip methods
    test_results.append(test_pip_methods())

    # Summary
    print("\n📊 Test Results Summary")
    print("=" * 30)

    passed = sum(test_results)
    total = len(test_results)

    if passed == total:
        print(f"🎉 All tests passed! ({passed}/{total})")
        print("\n✅ The fixes should resolve the portable package issues!")
        return 0
    else:
        print(f"⚠️  Some tests failed ({passed}/{total})")
        print("\n❗ Review the failed tests above")
        return 1


if __name__ == "__main__":
    sys.exit(main())
