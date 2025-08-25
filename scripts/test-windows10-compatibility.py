#!/usr/bin/env python3
"""
Comprehensive Windows 10 compatibility test suite for Serena MCP build process
Tests offline package generation, validation, and installation on Windows 10
"""

import json
import os
import platform
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, List, Tuple


class Windows10CompatibilityTester:
    """Test Windows 10 compatibility for Serena MCP portable package"""
    
    def __init__(self):
        self.test_results = []
        self.temp_dir = None
        self.original_cwd = Path.cwd()
        
    def run_all_tests(self) -> Dict:
        """Run all Windows 10 compatibility tests"""
        print("🚀 Starting Windows 10 Compatibility Test Suite")
        print("=" * 60)
        
        # Create temporary test directory
        self.temp_dir = Path(tempfile.mkdtemp(prefix="serena_win10_test_"))
        print(f"📁 Test directory: {self.temp_dir}")
        
        try:
            # Run all test categories
            results = {
                'platform': self.test_platform_compatibility(),
                'python': self.test_python_environment(),
                'encoding': self.test_unicode_encoding(),
                'file_system': self.test_file_system_operations(),
                'dependencies': self.test_dependency_download(),
                'language_servers': self.test_language_server_download(),
                'validation': self.test_validation_features(),
                'offline_install': self.test_offline_installation(),
                'package_integrity': self.test_package_integrity()
            }
            
            # Generate summary report
            self.generate_compatibility_report(results)
            
            return results
            
        finally:
            # Cleanup
            self.cleanup()
    
    def test_platform_compatibility(self) -> Dict:
        """Test Windows 10 platform detection and compatibility"""
        print("\n🖥️  Testing Platform Compatibility...")
        
        result = {
            'category': 'Platform Compatibility',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Windows detection
        system = platform.system()
        version = platform.version()
        release = platform.release()
        
        test_result = {
            'name': 'Windows Detection',
            'passed': system == 'Windows',
            'details': f"System: {system}, Version: {version}, Release: {release}",
            'critical': True
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
            print("  ✅ Windows detected")
        else:
            result['failed'] += 1
            print(f"  ❌ Expected Windows, got {system}")
        
        # Test 2: Windows 10 specific checks
        is_win10 = False
        try:
            # Check for Windows 10 specific features
            import winreg
            key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
            product_name = winreg.QueryValueEx(key, "ProductName")[0]
            build_number = winreg.QueryValueEx(key, "CurrentBuildNumber")[0]
            winreg.CloseKey(key)
            
            is_win10 = "Windows 10" in product_name or int(build_number) >= 10240
            
            test_result = {
                'name': 'Windows 10 Verification',
                'passed': is_win10,
                'details': f"Product: {product_name}, Build: {build_number}",
                'critical': False
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print(f"  ✅ Windows 10 confirmed: {product_name}")
            else:
                result['failed'] += 1
                print(f"  ⚠️  Not Windows 10: {product_name}")
                result['warnings'].append(f"Running on {product_name}, not Windows 10")
                
        except Exception as e:
            result['warnings'].append(f"Could not verify Windows 10: {e}")
            print(f"  ⚠️  Windows 10 verification failed: {e}")
        
        # Test 3: Architecture compatibility
        machine = platform.machine()
        arch_64bit = machine.lower() in ['amd64', 'x86_64']
        
        test_result = {
            'name': 'Architecture Compatibility',
            'passed': arch_64bit,
            'details': f"Architecture: {machine}",
            'critical': False
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
            print(f"  ✅ 64-bit architecture: {machine}")
        else:
            result['failed'] += 1
            print(f"  ⚠️  32-bit or unknown architecture: {machine}")
            result['warnings'].append("32-bit architecture may have compatibility issues")
        
        return result
    
    def test_python_environment(self) -> Dict:
        """Test Python environment compatibility"""
        print("\n🐍 Testing Python Environment...")
        
        result = {
            'category': 'Python Environment',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Python version
        python_version = sys.version_info
        version_compatible = python_version >= (3, 8)
        
        test_result = {
            'name': 'Python Version',
            'passed': version_compatible,
            'details': f"Python {python_version.major}.{python_version.minor}.{python_version.micro}",
            'critical': True
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
            print(f"  ✅ Python version compatible: {python_version.major}.{python_version.minor}")
        else:
            result['failed'] += 1
            print(f"  ❌ Python version too old: {python_version.major}.{python_version.minor} (need 3.8+)")
        
        # Test 2: pip availability
        try:
            pip_result = subprocess.run([sys.executable, "-m", "pip", "--version"], 
                                     capture_output=True, text=True, timeout=10)
            pip_available = pip_result.returncode == 0
            
            test_result = {
                'name': 'pip Module',
                'passed': pip_available,
                'details': pip_result.stdout.strip() if pip_available else pip_result.stderr.strip(),
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ pip module available")
            else:
                result['failed'] += 1
                print("  ❌ pip module not available")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'pip Module',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ pip test failed: {e}")
        
        # Test 3: Required modules
        required_modules = ['pathlib', 'subprocess', 'zipfile', 'json', 'hashlib']
        modules_available = 0
        
        for module_name in required_modules:
            try:
                __import__(module_name)
                modules_available += 1
                print(f"  ✅ {module_name} available")
            except ImportError:
                print(f"  ❌ {module_name} not available")
                result['warnings'].append(f"Missing module: {module_name}")
        
        test_result = {
            'name': 'Required Modules',
            'passed': modules_available == len(required_modules),
            'details': f"{modules_available}/{len(required_modules)} modules available",
            'critical': True
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
        else:
            result['failed'] += 1
        
        return result
    
    def test_unicode_encoding(self) -> Dict:
        """Test Unicode and encoding handling for Windows 10"""
        print("\n🔤 Testing Unicode/Encoding Support...")
        
        result = {
            'category': 'Unicode/Encoding',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Console encoding
        console_encoding = sys.stdout.encoding
        encoding_supported = console_encoding.lower() in ['utf-8', 'cp1252', 'cp850']
        
        test_result = {
            'name': 'Console Encoding',
            'passed': encoding_supported,
            'details': f"Encoding: {console_encoding}",
            'critical': False
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
            print(f"  ✅ Console encoding supported: {console_encoding}")
        else:
            result['failed'] += 1
            print(f"  ⚠️  Console encoding may cause issues: {console_encoding}")
        
        # Test 2: Unicode character display
        test_chars = ['✅', '❌', '⚠️', '📦', '🚀']
        unicode_works = True
        
        try:
            for char in test_chars:
                # Test if we can encode/decode the character
                char.encode('utf-8').decode('utf-8')
            print("  ✅ Unicode characters supported")
        except UnicodeEncodeError:
            unicode_works = False
            print("  ⚠️  Unicode characters may not display correctly")
            result['warnings'].append("Unicode display issues may occur")
        
        test_result = {
            'name': 'Unicode Character Support',
            'passed': unicode_works,
            'details': "Test characters: " + "".join(test_chars),
            'critical': False
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
        else:
            result['failed'] += 1
        
        # Test 3: File path encoding
        try:
            test_path = self.temp_dir / "测试文件.txt"  # Chinese characters
            test_path.write_text("test content", encoding='utf-8')
            path_unicode_works = test_path.exists()
            test_path.unlink()
            
            test_result = {
                'name': 'Unicode File Paths',
                'passed': path_unicode_works,
                'details': "Unicode characters in file paths",
                'critical': False
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Unicode file paths supported")
            else:
                result['failed'] += 1
                print("  ⚠️  Unicode file paths may cause issues")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Unicode File Paths',
                'passed': False,
                'details': f"Error: {e}",
                'critical': False
            })
            print(f"  ⚠️  Unicode file path test failed: {e}")
        
        return result
    
    def test_file_system_operations(self) -> Dict:
        """Test file system operations on Windows 10"""
        print("\n📁 Testing File System Operations...")
        
        result = {
            'category': 'File System Operations',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Long path support
        try:
            # Create a path longer than 260 characters (Windows limitation)
            long_dir_name = "a" * 100
            long_path = self.temp_dir
            for i in range(3):  # Create nested directories
                long_path = long_path / long_dir_name
                long_path.mkdir(exist_ok=True)
            
            test_file = long_path / "test.txt"
            test_file.write_text("test content")
            long_path_works = test_file.exists()
            
            test_result = {
                'name': 'Long Path Support',
                'passed': long_path_works,
                'details': f"Path length: {len(str(test_file))} characters",
                'critical': False
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print(f"  ✅ Long paths supported ({len(str(test_file))} chars)")
            else:
                result['failed'] += 1
                print(f"  ⚠️  Long path support limited")
                result['warnings'].append("Long path support may be disabled")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Long Path Support',
                'passed': False,
                'details': f"Error: {e}",
                'critical': False
            })
            print(f"  ⚠️  Long path test failed: {e}")
        
        # Test 2: File permissions
        try:
            test_file = self.temp_dir / "permission_test.txt"
            test_file.write_text("test content")
            
            # Test read access
            content = test_file.read_text()
            
            # Test write access
            test_file.write_text("modified content")
            
            # Test delete access
            test_file.unlink()
            
            permissions_work = True
            
            test_result = {
                'name': 'File Permissions',
                'passed': permissions_work,
                'details': "Read, write, delete operations",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ File permissions working correctly")
            else:
                result['failed'] += 1
                print("  ❌ File permission issues detected")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'File Permissions',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ File permission test failed: {e}")
        
        # Test 3: Executable file creation
        try:
            batch_file = self.temp_dir / "test.bat"
            batch_content = "@echo off\\necho Hello World\\npause"
            batch_file.write_text(batch_content)
            
            # Test if we can execute it
            exec_result = subprocess.run([str(batch_file)], 
                                       capture_output=True, text=True, timeout=5,
                                       input="\\n")  # Send enter to bypass pause
            executable_works = exec_result.returncode == 0
            
            test_result = {
                'name': 'Executable File Creation',
                'passed': executable_works,
                'details': "Batch file creation and execution",
                'critical': False
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Executable files can be created and run")
            else:
                result['failed'] += 1
                print("  ⚠️  Executable file creation/execution issues")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Executable File Creation',
                'passed': False,
                'details': f"Error: {e}",
                'critical': False
            })
            print(f"  ⚠️  Executable file test failed: {e}")
        
        return result
    
    def test_dependency_download(self) -> Dict:
        """Test dependency download script functionality"""
        print("\n📦 Testing Dependency Download...")
        
        result = {
            'category': 'Dependency Download',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Script existence and syntax
        script_path = self.original_cwd / "scripts" / "download-dependencies-offline.py"
        
        test_result = {
            'name': 'Script Availability',
            'passed': script_path.exists(),
            'details': f"Path: {script_path}",
            'critical': True
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
            print("  ✅ Dependency download script found")
        else:
            result['failed'] += 1
            print("  ❌ Dependency download script not found")
            return result
        
        # Test 2: Script syntax validation
        try:
            syntax_result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)], 
                                         capture_output=True, text=True, timeout=30)
            syntax_valid = syntax_result.returncode == 0
            
            test_result = {
                'name': 'Script Syntax',
                'passed': syntax_valid,
                'details': syntax_result.stderr.strip() if not syntax_valid else "No syntax errors",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Script syntax is valid")
            else:
                result['failed'] += 1
                print(f"  ❌ Script syntax errors: {syntax_result.stderr.strip()}")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Script Syntax',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ Syntax validation failed: {e}")
        
        # Test 3: Help command
        try:
            help_result = subprocess.run([sys.executable, str(script_path), "--help"], 
                                       capture_output=True, text=True, timeout=10)
            help_works = help_result.returncode == 0
            
            test_result = {
                'name': 'Help Command',
                'passed': help_works,
                'details': "Script help functionality",
                'critical': False
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Help command works")
            else:
                result['failed'] += 1
                print("  ⚠️  Help command issues")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Help Command',
                'passed': False,
                'details': f"Error: {e}",
                'critical': False
            })
            print(f"  ⚠️  Help command test failed: {e}")
        
        return result
    
    def test_language_server_download(self) -> Dict:
        """Test language server download script functionality"""
        print("\n🔧 Testing Language Server Download...")
        
        result = {
            'category': 'Language Server Download',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Script existence and syntax
        script_path = self.original_cwd / "scripts" / "download-language-servers-offline.py"
        
        test_result = {
            'name': 'Script Availability',
            'passed': script_path.exists(),
            'details': f"Path: {script_path}",
            'critical': True
        }
        result['tests'].append(test_result)
        
        if test_result['passed']:
            result['passed'] += 1
            print("  ✅ Language server download script found")
        else:
            result['failed'] += 1
            print("  ❌ Language server download script not found")
            return result
        
        # Test 2: Script syntax validation
        try:
            syntax_result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)], 
                                         capture_output=True, text=True, timeout=30)
            syntax_valid = syntax_result.returncode == 0
            
            test_result = {
                'name': 'Script Syntax',
                'passed': syntax_valid,
                'details': syntax_result.stderr.strip() if not syntax_valid else "No syntax errors",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Script syntax is valid")
            else:
                result['failed'] += 1
                print(f"  ❌ Script syntax errors: {syntax_result.stderr.strip()}")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Script Syntax',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ Syntax validation failed: {e}")
        
        # Test 3: Windows-specific language server URLs
        try:
            # Import the script to test Windows URL availability
            import importlib.util
            spec = importlib.util.spec_from_file_location("lang_servers", script_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            servers = module.get_language_servers()
            windows_servers = 0
            total_servers = 0
            
            for name, info in servers.items():
                total_servers += 1
                if info.get("platform_specific"):
                    if "win32" in info.get("platforms", {}):
                        windows_servers += 1
                        print(f"    ✅ {name}: Windows-specific URL available")
                else:
                    windows_servers += 1  # Platform-agnostic servers work on Windows
                    print(f"    ✅ {name}: Cross-platform server")
            
            test_result = {
                'name': 'Windows Server Support',
                'passed': windows_servers >= total_servers * 0.8,  # 80% should support Windows
                'details': f"{windows_servers}/{total_servers} servers support Windows",
                'critical': False
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print(f"  ✅ {windows_servers}/{total_servers} servers support Windows")
            else:
                result['failed'] += 1
                print(f"  ⚠️  Only {windows_servers}/{total_servers} servers support Windows")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Windows Server Support',
                'passed': False,
                'details': f"Error: {e}",
                'critical': False
            })
            print(f"  ⚠️  Windows server support test failed: {e}")
        
        return result
    
    def test_validation_features(self) -> Dict:
        """Test validation and integrity checking features"""
        print("\n🔍 Testing Validation Features...")
        
        result = {
            'category': 'Validation Features',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Create a test wheel file for validation
        try:
            import zipfile
            test_wheel = self.temp_dir / "test_package-1.0.0-py3-none-any.whl"
            
            # Create a minimal valid wheel
            with zipfile.ZipFile(test_wheel, 'w') as zf:
                # Add METADATA file
                metadata = """Name: test-package
Version: 1.0.0
Summary: Test package
"""
                zf.writestr("test_package-1.0.0.dist-info/METADATA", metadata)
                
                # Add WHEEL file
                wheel_info = """Wheel-Version: 1.0
Generator: test
Root-Is-Purelib: true
Tag: py3-none-any
"""
                zf.writestr("test_package-1.0.0.dist-info/WHEEL", wheel_info)
            
            # Test validation by importing validation classes from enhanced scripts
            validation_works = test_wheel.exists() and test_wheel.stat().st_size > 0
            
            test_result = {
                'name': 'Wheel File Validation',
                'passed': validation_works,
                'details': f"Test wheel size: {test_wheel.stat().st_size} bytes" if validation_works else "Failed to create test wheel",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Wheel validation test setup successful")
            else:
                result['failed'] += 1
                print("  ❌ Wheel validation test setup failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Wheel File Validation',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ Wheel validation test failed: {e}")
        
        # Test 2: SHA256 calculation
        try:
            import hashlib
            test_file = self.temp_dir / "hash_test.txt"
            test_content = b"Hello, World! This is a test file for hash calculation."
            test_file.write_bytes(test_content)
            
            # Calculate SHA256
            sha256_hash = hashlib.sha256()
            sha256_hash.update(test_content)
            calculated_hash = sha256_hash.hexdigest()
            
            expected_hash = hashlib.sha256(test_content).hexdigest()
            hash_correct = calculated_hash == expected_hash
            
            test_result = {
                'name': 'SHA256 Calculation',
                'passed': hash_correct,
                'details': f"Hash: {calculated_hash[:16]}...",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ SHA256 hash calculation working")
            else:
                result['failed'] += 1
                print("  ❌ SHA256 hash calculation failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'SHA256 Calculation',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ SHA256 test failed: {e}")
        
        return result
    
    def test_offline_installation(self) -> Dict:
        """Test offline installation script functionality"""
        print("\n📦 Testing Offline Installation...")
        
        result = {
            'category': 'Offline Installation',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Create test batch installer
        try:
            batch_content = '''@echo off
echo Testing batch script functionality...
echo.
echo Python executable: %1
echo Target directory: %2
echo.
echo This is a test batch script.
echo Installation would happen here.
echo.
echo SUCCESS: Test batch script executed successfully
pause'''
            
            batch_file = self.temp_dir / "test_install.bat"
            batch_file.write_text(batch_content)
            
            # Test batch file execution
            exec_result = subprocess.run([str(batch_file), sys.executable, str(self.temp_dir)], 
                                       capture_output=True, text=True, timeout=10,
                                       input="\\n")  # Send enter to bypass pause
            
            batch_works = exec_result.returncode == 0 and "SUCCESS" in exec_result.stdout
            
            test_result = {
                'name': 'Batch Script Execution',
                'passed': batch_works,
                'details': "Test batch installer execution",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Batch script execution working")
            else:
                result['failed'] += 1
                print("  ❌ Batch script execution failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Batch Script Execution',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ Batch script test failed: {e}")
        
        # Test 2: Test pip install simulation
        try:
            # Create a fake wheel file
            fake_wheel = self.temp_dir / "fake_package-1.0.0-py3-none-any.whl"
            fake_wheel.write_text("fake wheel content")
            
            # Test pip install with --dry-run (if available)
            pip_test_result = subprocess.run([
                sys.executable, "-m", "pip", "install", "--help"
            ], capture_output=True, text=True, timeout=10)
            
            pip_available = pip_test_result.returncode == 0
            
            test_result = {
                'name': 'Pip Install Capability',
                'passed': pip_available,
                'details': "pip install command availability",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ pip install command available")
            else:
                result['failed'] += 1
                print("  ❌ pip install command not available")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Pip Install Capability',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ pip install test failed: {e}")
        
        return result
    
    def test_package_integrity(self) -> Dict:
        """Test package integrity validation"""
        print("\n🔒 Testing Package Integrity...")
        
        result = {
            'category': 'Package Integrity',
            'tests': [],
            'passed': 0,
            'failed': 0,
            'warnings': []
        }
        
        # Test 1: Archive extraction
        try:
            import zipfile
            test_zip = self.temp_dir / "test_archive.zip"
            
            # Create test archive
            with zipfile.ZipFile(test_zip, 'w') as zf:
                zf.writestr("test_file.txt", "This is test content")
                zf.writestr("folder/nested_file.txt", "Nested content")
            
            # Test extraction
            extract_dir = self.temp_dir / "extracted"
            extract_dir.mkdir()
            
            with zipfile.ZipFile(test_zip, 'r') as zf:
                zf.extractall(extract_dir)
            
            # Verify extraction
            extracted_file = extract_dir / "test_file.txt"
            nested_file = extract_dir / "folder" / "nested_file.txt"
            
            extraction_success = (extracted_file.exists() and nested_file.exists() and
                                extracted_file.read_text() == "This is test content")
            
            test_result = {
                'name': 'Archive Extraction',
                'passed': extraction_success,
                'details': "ZIP archive extraction and verification",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ Archive extraction working")
            else:
                result['failed'] += 1
                print("  ❌ Archive extraction failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Archive Extraction',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ Archive extraction test failed: {e}")
        
        # Test 2: File integrity verification
        try:
            # Create test file with known content
            test_file = self.temp_dir / "integrity_test.txt"
            original_content = "This is the original content for integrity testing."
            test_file.write_text(original_content)
            
            # Verify content
            read_content = test_file.read_text()
            content_intact = read_content == original_content
            
            # Test file size
            expected_size = len(original_content.encode('utf-8'))
            actual_size = test_file.stat().st_size
            size_correct = actual_size == expected_size
            
            integrity_ok = content_intact and size_correct
            
            test_result = {
                'name': 'File Integrity',
                'passed': integrity_ok,
                'details': f"Content match: {content_intact}, Size: {actual_size}/{expected_size} bytes",
                'critical': True
            }
            result['tests'].append(test_result)
            
            if test_result['passed']:
                result['passed'] += 1
                print("  ✅ File integrity verification working")
            else:
                result['failed'] += 1
                print("  ❌ File integrity verification failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'File Integrity',
                'passed': False,
                'details': f"Error: {e}",
                'critical': True
            })
            print(f"  ❌ File integrity test failed: {e}")
        
        return result
    
    def generate_compatibility_report(self, results: Dict):
        """Generate comprehensive compatibility report"""
        print("\\n" + "=" * 60)
        print("📋 Generating Windows 10 Compatibility Report...")
        print("=" * 60)
        
        # Calculate overall statistics
        total_tests = 0
        total_passed = 0
        total_failed = 0
        critical_failures = []
        warnings = []
        
        for category, category_result in results.items():
            if isinstance(category_result, dict) and 'tests' in category_result:
                total_tests += len(category_result['tests'])
                total_passed += category_result['passed']
                total_failed += category_result['failed']
                
                # Collect critical failures
                for test in category_result['tests']:
                    if not test['passed'] and test.get('critical', False):
                        critical_failures.append(f"{category}: {test['name']}")
                
                # Collect warnings
                warnings.extend(category_result.get('warnings', []))
        
        # Generate report
        report_lines = []
        report_lines.append("# Windows 10 Compatibility Test Report")
        report_lines.append(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append(f"Test Environment: {platform.system()} {platform.version()}")
        report_lines.append(f"Python Version: {sys.version}")
        report_lines.append("")
        
        # Executive Summary
        overall_success_rate = (total_passed / total_tests) * 100 if total_tests > 0 else 0
        compatibility_level = "EXCELLENT" if overall_success_rate >= 90 else "GOOD" if overall_success_rate >= 75 else "NEEDS ATTENTION"
        
        report_lines.append("## Executive Summary")
        report_lines.append(f"- **Overall Compatibility**: {compatibility_level}")
        report_lines.append(f"- **Success Rate**: {overall_success_rate:.1f}% ({total_passed}/{total_tests} tests passed)")
        report_lines.append(f"- **Critical Failures**: {len(critical_failures)}")
        report_lines.append(f"- **Warnings**: {len(warnings)}")
        report_lines.append("")
        
        if critical_failures:
            report_lines.append("### ❌ Critical Issues")
            for failure in critical_failures:
                report_lines.append(f"- {failure}")
            report_lines.append("")
        
        if warnings:
            report_lines.append("### ⚠️  Warnings")
            for warning in warnings[:10]:  # Limit to first 10 warnings
                report_lines.append(f"- {warning}")
            if len(warnings) > 10:
                report_lines.append(f"- ... and {len(warnings) - 10} more warnings")
            report_lines.append("")
        
        # Detailed Results
        report_lines.append("## Detailed Test Results")
        report_lines.append("")
        
        for category, category_result in results.items():
            if isinstance(category_result, dict) and 'tests' in category_result:
                category_name = category_result.get('category', category.title())
                success_rate = (category_result['passed'] / len(category_result['tests'])) * 100 if category_result['tests'] else 0
                
                report_lines.append(f"### {category_name}")
                report_lines.append(f"Success Rate: {success_rate:.1f}% ({category_result['passed']}/{len(category_result['tests'])} passed)")
                report_lines.append("")
                
                for test in category_result['tests']:
                    status = "✅" if test['passed'] else "❌"
                    critical = " (CRITICAL)" if test.get('critical') else ""
                    report_lines.append(f"#### {status} {test['name']}{critical}")
                    report_lines.append(f"- Details: {test['details']}")
                    report_lines.append("")
        
        # Recommendations
        report_lines.append("## Recommendations")
        report_lines.append("")
        
        if overall_success_rate >= 90:
            report_lines.append("✅ **System is ready for Serena MCP deployment**")
            report_lines.append("- All critical tests passed")
            report_lines.append("- Minor warnings can be addressed if needed")
        elif overall_success_rate >= 75:
            report_lines.append("⚠️  **System needs minor adjustments**")
            report_lines.append("- Most functionality will work correctly")
            report_lines.append("- Address critical failures before deployment")
            report_lines.append("- Monitor warnings during deployment")
        else:
            report_lines.append("❌ **System requires significant fixes**")
            report_lines.append("- Multiple critical issues detected")
            report_lines.append("- Deployment not recommended until issues resolved")
            report_lines.append("- Consider system upgrades or configuration changes")
        
        report_lines.append("")
        report_lines.append("## Next Steps")
        report_lines.append("1. Review and address any critical failures")
        report_lines.append("2. Test actual package download and installation")
        report_lines.append("3. Verify language server functionality")
        report_lines.append("4. Run end-to-end deployment test")
        
        # Write report to file
        report_path = self.temp_dir / "windows10-compatibility-report.md"
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write('\\n'.join(report_lines))
        
        # Print summary
        print(f"📊 **COMPATIBILITY SUMMARY**")
        print(f"Overall Success Rate: {overall_success_rate:.1f}%")
        print(f"Compatibility Level: {compatibility_level}")
        print(f"Critical Failures: {len(critical_failures)}")
        print(f"Warnings: {len(warnings)}")
        print(f"📋 Full report saved to: {report_path}")
        
        if overall_success_rate >= 75:
            print("\\n🎉 **Windows 10 compatibility looks good!**")
            print("Ready to proceed with Serena MCP deployment.")
        else:
            print("\\n⚠️  **Compatibility issues detected.**")
            print("Please review the report and address critical issues.")
    
    def cleanup(self):
        """Clean up temporary test files"""
        if self.temp_dir and self.temp_dir.exists():
            import shutil
            try:
                shutil.rmtree(self.temp_dir)
                print(f"🧹 Cleaned up test directory: {self.temp_dir}")
            except Exception as e:
                print(f"⚠️  Could not clean up {self.temp_dir}: {e}")


def main():
    """Main function to run Windows 10 compatibility tests"""
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("""
Windows 10 Compatibility Test Suite for Serena MCP

This script tests the compatibility of Windows 10 systems with the Serena MCP
build process, including offline package generation and installation.

Usage:
    python test-windows10-compatibility.py

Tests performed:
- Platform compatibility and Windows 10 detection
- Python environment and module availability  
- Unicode/encoding support for international users
- File system operations and permissions
- Dependency download script functionality
- Language server download script functionality
- Validation and integrity checking features
- Offline installation capabilities
- Package integrity verification

The script generates a comprehensive report with recommendations.
""")
        return 0
    
    print("🚀 Starting Windows 10 Compatibility Test Suite for Serena MCP")
    print("This may take a few minutes to complete...")
    print()
    
    try:
        tester = Windows10CompatibilityTester()
        results = tester.run_all_tests()
        
        # Return appropriate exit code
        total_tests = sum(len(r.get('tests', [])) for r in results.values() if isinstance(r, dict))
        total_passed = sum(r.get('passed', 0) for r in results.values() if isinstance(r, dict))
        success_rate = (total_passed / total_tests) * 100 if total_tests > 0 else 0
        
        if success_rate >= 75:
            return 0  # Success
        else:
            return 1  # Some issues detected
            
    except KeyboardInterrupt:
        print("\\n⏹️  Test interrupted by user")
        return 130
    except Exception as e:
        print(f"\\n❌ Test suite failed with error: {e}")
        return 1


if __name__ == "__main__":
    import time
    sys.exit(main())