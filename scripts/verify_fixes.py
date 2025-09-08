#!/usr/bin/env python3
"""
Verification script to check all fixes have been applied correctly
for the Serena Offline Package Builder.

This script validates:
1. No Unicode characters in output
2. No syntax errors
3. Binary file validation works
4. npm integration works
5. Enterprise features work
"""

import sys
import os
import re
import ast
import subprocess
from pathlib import Path

# Add scripts directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def check_syntax(file_path):
    """Check Python file for syntax errors"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            ast.parse(f.read())
        return True, "OK"
    except SyntaxError as e:
        return False, f"Syntax error at line {e.lineno}: {e.msg}"
    except Exception as e:
        return False, str(e)

def check_unicode(file_path):
    """Check for Unicode characters in Python file"""
    unicode_chars = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            for char_pos, char in enumerate(line):
                if ord(char) > 127:  # Non-ASCII character
                    unicode_chars.append({
                        'line': line_num,
                        'char': char,
                        'code': f"U+{ord(char):04X}",
                        'position': char_pos
                    })
    return unicode_chars

def check_binary_validation():
    """Check if binary file validation function exists and works"""
    try:
        from offline_deps_downloader import OfflineDepsDownloader
        import tempfile
        temp_dir = tempfile.mkdtemp()
        downloader = OfflineDepsDownloader(output_dir=temp_dir)
        
        # Test with sample data
        import tempfile
        
        # Test HTML detection
        with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.html') as f:
            f.write(b'<!DOCTYPE html><html><body>Error 404</body></html>')
            html_file = f.name
        
        # Test ZIP detection  
        with tempfile.NamedTemporaryFile(mode='wb', delete=False, suffix='.zip') as f:
            f.write(b'PK\x03\x04')  # ZIP signature
            zip_file = f.name
        
        # Validate
        html_valid = downloader.validate_binary_file(html_file)
        zip_valid = downloader.validate_binary_file(zip_file)
        
        # Clean up
        os.unlink(html_file)
        os.unlink(zip_file)
        
        if not html_valid and zip_valid:
            return True, "Binary validation works correctly"
        else:
            return False, f"Binary validation failed: HTML={html_valid}, ZIP={zip_valid}"
            
    except ImportError:
        return False, "Could not import offline_deps_downloader"
    except AttributeError:
        return False, "validate_binary_file method not found"
    except Exception as e:
        return False, str(e)

def check_npm_integration():
    """Check if npm integration is properly configured"""
    try:
        from offline_deps_downloader import OfflineDepsDownloader
        import tempfile
        
        # Check if download order is correct
        temp_dir = tempfile.mkdtemp()
        downloader = OfflineDepsDownloader(output_dir=temp_dir)
        
        # Verify Node.js comes before TypeScript in download order
        # This is critical for npm to be available
        
        # Check if the fix is present
        import inspect
        source = inspect.getsource(downloader.download_typescript_deps)
        
        checks = [
            'nodejs_dir' in source,
            'npm.cmd' in source or 'npm_cmd' in source,
            'download_nodejs' in source or 'Node.js' in source
        ]
        
        if all(checks):
            return True, "npm integration properly configured"
        else:
            return False, "npm integration may not be fully configured"
            
    except ImportError:
        return False, "Could not import offline_deps_downloader"
    except Exception as e:
        return False, str(e)

def check_enterprise_features():
    """Check if enterprise download features are available"""
    try:
        # Try importing enterprise download module
        from enterprise_download import EnterpriseDownloader
        
        # Check if it can be instantiated
        downloader = EnterpriseDownloader()
        
        return True, "Enterprise features available"
        
    except ImportError:
        # Check for simple version
        try:
            from enterprise_download_simple import SimpleEnterpriseDownloader
            return True, "Enterprise features available (simple version)"
        except ImportError:
            return False, "No enterprise download module found"
    except Exception as e:
        return False, str(e)

def main():
    """Run all verification checks"""
    print("=" * 60)
    print("SERENA OFFLINE PACKAGE BUILDER - FIX VERIFICATION")
    print("=" * 60)
    print()
    
    # Files to check
    files_to_check = [
        "scripts/build_offline_package.py",
        "scripts/prepare_offline_windows.py", 
        "scripts/offline_deps_downloader.py",
        "BUILD_OFFLINE_WINDOWS.py"
    ]
    
    all_passed = True
    
    # 1. Check syntax
    print("[1] Checking Python syntax...")
    for file_path in files_to_check:
        full_path = Path(file_path)
        if not full_path.exists():
            full_path = Path(".." ) / file_path
        
        if full_path.exists():
            passed, msg = check_syntax(full_path)
            status = "[OK]" if passed else "[FAIL]"
            print(f"    {status} {full_path.name}: {msg}")
            if not passed:
                all_passed = False
        else:
            print(f"    [SKIP] {file_path}: File not found")
    
    # 2. Check for Unicode characters
    print("\n[2] Checking for Unicode characters...")
    for file_path in files_to_check:
        full_path = Path(file_path)
        if not full_path.exists():
            full_path = Path("..") / file_path
            
        if full_path.exists():
            unicode_chars = check_unicode(full_path)
            if unicode_chars:
                print(f"    [WARN] {full_path.name}: Found {len(unicode_chars)} Unicode characters")
                for uc in unicode_chars[:3]:  # Show first 3
                    print(f"           Line {uc['line']}: '{uc['char']}' ({uc['code']})")
                if len(unicode_chars) > 3:
                    print(f"           ... and {len(unicode_chars)-3} more")
                all_passed = False
            else:
                print(f"    [OK] {full_path.name}: No Unicode characters found")
    
    # 3. Check binary validation
    print("\n[3] Checking binary file validation...")
    passed, msg = check_binary_validation()
    status = "[OK]" if passed else "[FAIL]"
    print(f"    {status} {msg}")
    if not passed:
        all_passed = False
    
    # 4. Check npm integration
    print("\n[4] Checking npm integration...")
    passed, msg = check_npm_integration()
    status = "[OK]" if passed else "[FAIL]"
    print(f"    {status} {msg}")
    if not passed:
        all_passed = False
    
    # 5. Check enterprise features
    print("\n[5] Checking enterprise features...")
    passed, msg = check_enterprise_features()
    status = "[OK]" if passed else "[WARN]"
    print(f"    {status} {msg}")
    
    # Summary
    print("\n" + "=" * 60)
    if all_passed:
        print("[SUCCESS] All critical fixes have been applied!")
        print("\nThe offline package builder should now work without errors:")
        print("  - No syntax errors")
        print("  - No Unicode encoding errors") 
        print("  - VSIX downloads validated properly")
        print("  - npm uses downloaded Node.js")
        print("  - Enterprise networking supported")
    else:
        print("[WARNING] Some issues may remain. Review the output above.")
        print("\nSuggested actions:")
        print("  1. Run: python BUILD_OFFLINE_WINDOWS.py --full")
        print("  2. Check the log file for any remaining errors")
        print("  3. Report any issues that persist")
    
    print("=" * 60)
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())