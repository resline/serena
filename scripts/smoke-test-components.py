#!/usr/bin/env python3
"""
Smoke Tests for Serena MCP Components
Quick validation tests for individual components
"""

import argparse
import importlib.util
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Dict, List


class ComponentSmokeTests:
    """Run smoke tests on individual components"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.test_results = []
        
    def run_all_smoke_tests(self) -> Dict:
        """Run all component smoke tests"""
        print("💨 Running Component Smoke Tests")
        print("=" * 50)
        
        results = {
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'tests': {},
            'overall_success': False,
            'summary': {
                'total_tests': 0,
                'passed_tests': 0,
                'failed_tests': 0
            }
        }
        
        # Test individual scripts
        results['tests']['dependency_script'] = self.test_dependency_script()
        results['tests']['language_server_script'] = self.test_language_server_script()
        results['tests']['validation_script'] = self.test_validation_script()
        results['tests']['test_scripts'] = self.test_test_scripts()
        
        # Calculate overall results
        self.calculate_overall_results(results)
        
        return results
    
    def test_dependency_script(self) -> Dict:
        """Smoke test for dependency download script"""
        print("\\n📦 Testing dependency download script...")
        
        result = {
            'component': 'Dependency Download Script',
            'tests': [],
            'passed': 0,
            'failed': 0
        }
        
        script_path = Path("scripts/download-dependencies-offline.py")
        
        # Test 1: Script exists
        script_exists = script_path.exists()
        result['tests'].append({
            'name': 'Script Exists',
            'passed': script_exists,
            'details': f"Path: {script_path}"
        })
        
        if script_exists:
            result['passed'] += 1
            print("  ✅ Script file found")
        else:
            result['failed'] += 1
            print("  ❌ Script file not found")
            return result
        
        # Test 2: Syntax check
        try:
            syntax_result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)],
                                         capture_output=True, text=True, timeout=30)
            syntax_ok = syntax_result.returncode == 0
            
            result['tests'].append({
                'name': 'Syntax Check',
                'passed': syntax_ok,
                'details': syntax_result.stderr.strip() if not syntax_ok else "No syntax errors"
            })
            
            if syntax_ok:
                result['passed'] += 1
                print("  ✅ Syntax check passed")
            else:
                result['failed'] += 1
                print(f"  ❌ Syntax errors: {syntax_result.stderr.strip()}")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Syntax Check',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Syntax check failed: {e}")
        
        # Test 3: Help command
        try:
            help_result = subprocess.run([sys.executable, str(script_path), "--help"],
                                       capture_output=True, text=True, timeout=10)
            help_ok = help_result.returncode == 0 and "usage:" in help_result.stdout.lower()
            
            result['tests'].append({
                'name': 'Help Command',
                'passed': help_ok,
                'details': "Help command works and shows usage"
            })
            
            if help_ok:
                result['passed'] += 1
                print("  ✅ Help command works")
            else:
                result['failed'] += 1
                print("  ❌ Help command failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Help Command',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Help command test failed: {e}")
        
        # Test 4: Import validation classes
        try:
            spec = importlib.util.spec_from_file_location("dep_script", script_path)
            module = importlib.util.module_from_spec(spec)
            
            # Test if we can import without executing
            with open(script_path, 'r') as f:
                content = f.read()
                
            has_progress_tracker = 'ProgressTracker' in content
            has_validator = 'PackageValidator' in content
            has_downloader = 'OfflineDependencyDownloader' in content
            
            classes_present = has_progress_tracker and has_validator and has_downloader
            
            result['tests'].append({
                'name': 'Enhanced Classes Present',
                'passed': classes_present,
                'details': f"ProgressTracker: {has_progress_tracker}, PackageValidator: {has_validator}, Downloader: {has_downloader}"
            })
            
            if classes_present:
                result['passed'] += 1
                print("  ✅ Enhanced validation classes present")
            else:
                result['failed'] += 1
                print("  ❌ Missing enhanced validation classes")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Enhanced Classes Present',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Class validation failed: {e}")
        
        return result
    
    def test_language_server_script(self) -> Dict:
        """Smoke test for language server download script"""
        print("\\n🔧 Testing language server download script...")
        
        result = {
            'component': 'Language Server Download Script',
            'tests': [],
            'passed': 0,
            'failed': 0
        }
        
        script_path = Path("scripts/download-language-servers-offline.py")
        
        # Test 1: Script exists
        script_exists = script_path.exists()
        result['tests'].append({
            'name': 'Script Exists',
            'passed': script_exists,
            'details': f"Path: {script_path}"
        })
        
        if script_exists:
            result['passed'] += 1
            print("  ✅ Script file found")
        else:
            result['failed'] += 1
            print("  ❌ Script file not found")
            return result
        
        # Test 2: Syntax check
        try:
            syntax_result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)],
                                         capture_output=True, text=True, timeout=30)
            syntax_ok = syntax_result.returncode == 0
            
            result['tests'].append({
                'name': 'Syntax Check',
                'passed': syntax_ok,
                'details': syntax_result.stderr.strip() if not syntax_ok else "No syntax errors"
            })
            
            if syntax_ok:
                result['passed'] += 1
                print("  ✅ Syntax check passed")
            else:
                result['failed'] += 1
                print(f"  ❌ Syntax errors: {syntax_result.stderr.strip()}")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Syntax Check',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Syntax check failed: {e}")
        
        # Test 3: Language server definitions
        try:
            # Import and check get_language_servers function
            spec = importlib.util.spec_from_file_location("lang_script", script_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            
            if hasattr(module, 'get_language_servers'):
                servers = module.get_language_servers()
                server_count = len(servers)
                has_windows_servers = any(
                    'win32' in info.get('platforms', {}) or not info.get('platform_specific', False)
                    for info in servers.values()
                )
                
                result['tests'].append({
                    'name': 'Language Server Definitions',
                    'passed': server_count > 5 and has_windows_servers,
                    'details': f"{server_count} servers defined, Windows support: {has_windows_servers}"
                })
                
                if server_count > 5:
                    result['passed'] += 1
                    print(f"  ✅ {server_count} language servers defined")
                else:
                    result['failed'] += 1
                    print(f"  ❌ Only {server_count} language servers defined")
            else:
                result['failed'] += 1
                result['tests'].append({
                    'name': 'Language Server Definitions',
                    'passed': False,
                    'details': "get_language_servers function not found"
                })
                print("  ❌ get_language_servers function not found")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Language Server Definitions',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Language server definitions test failed: {e}")
        
        # Test 4: Enhanced validation classes
        try:
            with open(script_path, 'r') as f:
                content = f.read()
                
            has_progress_tracker = 'ProgressTracker' in content
            has_validator = 'LanguageServerValidator' in content
            has_validation_method = 'validate_all_servers' in content
            
            classes_present = has_progress_tracker and has_validator and has_validation_method
            
            result['tests'].append({
                'name': 'Enhanced Validation Classes',
                'passed': classes_present,
                'details': f"ProgressTracker: {has_progress_tracker}, Validator: {has_validator}, Methods: {has_validation_method}"
            })
            
            if classes_present:
                result['passed'] += 1
                print("  ✅ Enhanced validation classes present")
            else:
                result['failed'] += 1
                print("  ❌ Missing enhanced validation classes")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Enhanced Validation Classes',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Enhanced validation test failed: {e}")
        
        return result
    
    def test_validation_script(self) -> Dict:
        """Smoke test for package validation script"""
        print("\\n🔍 Testing package validation script...")
        
        result = {
            'component': 'Package Validation Script',
            'tests': [],
            'passed': 0,
            'failed': 0
        }
        
        script_path = Path("scripts/validate-package-integrity.py")
        
        # Test 1: Script exists
        script_exists = script_path.exists()
        result['tests'].append({
            'name': 'Script Exists',
            'passed': script_exists,
            'details': f"Path: {script_path}"
        })
        
        if script_exists:
            result['passed'] += 1
            print("  ✅ Script file found")
        else:
            result['failed'] += 1
            print("  ❌ Script file not found")
            return result
        
        # Test 2: Syntax check
        try:
            syntax_result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)],
                                         capture_output=True, text=True, timeout=30)
            syntax_ok = syntax_result.returncode == 0
            
            result['tests'].append({
                'name': 'Syntax Check',
                'passed': syntax_ok,
                'details': syntax_result.stderr.strip() if not syntax_ok else "No syntax errors"
            })
            
            if syntax_ok:
                result['passed'] += 1
                print("  ✅ Syntax check passed")
            else:
                result['failed'] += 1
                print(f"  ❌ Syntax errors: {syntax_result.stderr.strip()}")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Syntax Check',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Syntax check failed: {e}")
        
        # Test 3: Help command
        try:
            help_result = subprocess.run([sys.executable, str(script_path), "--help"],
                                       capture_output=True, text=True, timeout=10)
            help_ok = help_result.returncode == 0
            
            result['tests'].append({
                'name': 'Help Command',
                'passed': help_ok,
                'details': "Help command functionality"
            })
            
            if help_ok:
                result['passed'] += 1
                print("  ✅ Help command works")
            else:
                result['failed'] += 1
                print("  ❌ Help command failed")
                
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Help Command',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Help command test failed: {e}")
        
        # Test 4: Validation with non-existent directory
        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                nonexistent_dir = Path(temp_dir) / "nonexistent"
                
                test_result = subprocess.run([sys.executable, str(script_path), str(nonexistent_dir)],
                                           capture_output=True, text=True, timeout=30)
                
                # Should fail gracefully (exit code 1) but not crash
                graceful_failure = test_result.returncode == 1 and "does not exist" in test_result.stdout
                
                result['tests'].append({
                    'name': 'Error Handling',
                    'passed': graceful_failure,
                    'details': f"Graceful failure for non-existent directory"
                })
                
                if graceful_failure:
                    result['passed'] += 1
                    print("  ✅ Error handling works correctly")
                else:
                    result['failed'] += 1
                    print("  ❌ Error handling issues")
                    
        except Exception as e:
            result['failed'] += 1
            result['tests'].append({
                'name': 'Error Handling',
                'passed': False,
                'details': f"Error: {e}"
            })
            print(f"  ❌ Error handling test failed: {e}")
        
        return result
    
    def test_test_scripts(self) -> Dict:
        """Smoke test for test scripts"""
        print("\\n🧪 Testing test scripts...")
        
        result = {
            'component': 'Test Scripts',
            'tests': [],
            'passed': 0,
            'failed': 0
        }
        
        test_scripts = [
            "scripts/test-windows10-compatibility.py",
            "scripts/test-offline-functionality.py",
            "scripts/test-linux-offline-prep.py"
        ]
        
        for script_name in test_scripts:
            script_path = Path(script_name)
            
            # Test script existence and syntax
            script_exists = script_path.exists()
            
            if script_exists:
                try:
                    syntax_result = subprocess.run([sys.executable, "-m", "py_compile", str(script_path)],
                                                 capture_output=True, text=True, timeout=30)
                    syntax_ok = syntax_result.returncode == 0
                    
                    result['tests'].append({
                        'name': f"{script_path.name} Syntax",
                        'passed': syntax_ok,
                        'details': syntax_result.stderr.strip() if not syntax_ok else "Valid syntax"
                    })
                    
                    if syntax_ok:
                        result['passed'] += 1
                        if self.verbose:
                            print(f"  ✅ {script_path.name} syntax OK")
                    else:
                        result['failed'] += 1
                        print(f"  ❌ {script_path.name} syntax error: {syntax_result.stderr.strip()}")
                        
                except Exception as e:
                    result['failed'] += 1
                    result['tests'].append({
                        'name': f"{script_path.name} Syntax",
                        'passed': False,
                        'details': f"Error: {e}"
                    })
                    print(f"  ❌ {script_path.name} syntax test failed: {e}")
            else:
                result['failed'] += 1
                result['tests'].append({
                    'name': f"{script_path.name} Exists",
                    'passed': False,
                    'details': "Script file not found"
                })
                print(f"  ❌ {script_path.name} not found")
        
        # Summary for test scripts
        if result['passed'] > result['failed']:
            print(f"  📊 Test scripts: {result['passed']} OK, {result['failed']} issues")
        
        return result
    
    def calculate_overall_results(self, results: Dict):
        """Calculate overall test results"""
        total_tests = 0
        passed_tests = 0
        failed_tests = 0
        
        for test_category in results['tests'].values():
            total_tests += len(test_category['tests'])
            passed_tests += test_category['passed']
            failed_tests += test_category['failed']
        
        results['summary']['total_tests'] = total_tests
        results['summary']['passed_tests'] = passed_tests
        results['summary']['failed_tests'] = failed_tests
        
        # Overall success if > 80% pass rate
        success_rate = passed_tests / total_tests if total_tests > 0 else 0
        results['overall_success'] = success_rate >= 0.8
        
        print("\\n" + "=" * 50)
        print("📊 Smoke Test Summary")
        print("=" * 50)
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {failed_tests}")
        print(f"Success Rate: {success_rate:.1%}")
        
        if results['overall_success']:
            print("\\n✅ Smoke tests PASSED - Components are ready")
        else:
            print("\\n❌ Smoke tests FAILED - Some components need attention")
        
        # Show component breakdown
        print("\\n📋 Component Results:")
        for component_name, component_result in results['tests'].items():
            component_status = "✅" if component_result['passed'] > component_result['failed'] else "❌"
            print(f"  {component_status} {component_result['component']}: {component_result['passed']}/{len(component_result['tests'])} passed")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="Run smoke tests on Serena MCP components")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--component", choices=['dependency', 'language-server', 'validation', 'test'], 
                       help="Test only specific component")
    
    args = parser.parse_args()
    
    print("💨 Component Smoke Tests for Serena MCP")
    print("Quick validation of individual components")
    print()
    
    try:
        tester = ComponentSmokeTests(verbose=args.verbose)
        
        if args.component:
            # Test specific component
            component_map = {
                'dependency': 'dependency_script',
                'language-server': 'language_server_script', 
                'validation': 'validation_script',
                'test': 'test_scripts'
            }
            
            if args.component in component_map:
                method_name = f"test_{component_map[args.component]}"
                test_method = getattr(tester, method_name)
                result = test_method()
                
                success = result['passed'] > result['failed']
                return 0 if success else 1
            else:
                print(f"Unknown component: {args.component}")
                return 1
        else:
            # Run all tests
            results = tester.run_all_smoke_tests()
            return 0 if results['overall_success'] else 1
            
    except KeyboardInterrupt:
        print("\\n⏹️  Tests interrupted by user")
        return 130
    except Exception as e:
        print(f"\\n❌ Smoke tests failed with error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())