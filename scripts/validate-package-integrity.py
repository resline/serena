#!/usr/bin/env python3
"""
Package Integrity Validator for Serena MCP Offline Packages
Validates downloaded dependencies and language servers for completeness and integrity
"""

import argparse
import hashlib
import json
import os
import sys
import time
import zipfile
from pathlib import Path
from typing import Dict, List, Optional


class PackageIntegrityValidator:
    """Comprehensive package integrity validator"""
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.validation_results = []
        
    def validate_offline_package(self, package_dir: Path) -> Dict:
        """Validate complete offline package structure and integrity"""
        print("🔍 Starting Package Integrity Validation...")
        print("=" * 60)
        
        results = {
            'package_directory': str(package_dir),
            'validation_timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'overall_valid': False,
            'categories': {},
            'summary': {
                'total_files': 0,
                'valid_files': 0,
                'invalid_files': 0,
                'total_size_mb': 0,
                'warnings': [],
                'errors': []
            }
        }
        
        if not package_dir.exists():
            results['summary']['errors'].append(f"Package directory does not exist: {package_dir}")
            return results
        
        print(f"📦 Validating package: {package_dir}")
        
        # Validate different components
        results['categories']['dependencies'] = self._validate_dependencies(package_dir)
        results['categories']['language_servers'] = self._validate_language_servers(package_dir)
        results['categories']['installers'] = self._validate_installers(package_dir)
        results['categories']['manifests'] = self._validate_manifests(package_dir)
        
        # Calculate overall statistics
        self._calculate_overall_stats(results)
        
        # Generate validation report
        self._generate_integrity_report(results)
        
        return results
    
    def _validate_dependencies(self, package_dir: Path) -> Dict:
        """Validate Python dependencies (wheels)"""
        print("\n📦 Validating Python Dependencies...")
        
        result = {
            'category': 'Python Dependencies',
            'valid': False,
            'files': [],
            'total_files': 0,
            'valid_files': 0,
            'total_size': 0,
            'issues': []
        }
        
        # Check main dependencies directory
        deps_dir = package_dir
        wheel_files = list(deps_dir.glob("*.whl"))
        
        # Also check uv-deps if it exists
        uv_dir = package_dir / "uv-deps"
        if uv_dir.exists():
            wheel_files.extend(list(uv_dir.glob("*.whl")))
        
        result['total_files'] = len(wheel_files)
        
        if result['total_files'] == 0:
            result['issues'].append("No wheel files found")
            return result
        
        print(f"  Found {result['total_files']} wheel files to validate")
        
        # Validate each wheel file
        for wheel_file in wheel_files:
            file_result = self._validate_wheel_file(wheel_file)
            result['files'].append(file_result)
            result['total_size'] += file_result['size']
            
            if file_result['valid']:
                result['valid_files'] += 1
                if self.verbose:
                    print(f"    ✅ {wheel_file.name}")
            else:
                if self.verbose:
                    print(f"    ❌ {wheel_file.name}: {', '.join(file_result['errors'])}")
        
        # Check for requirements.txt
        requirements_files = list(package_dir.glob("requirements.txt"))
        if not requirements_files:
            result['issues'].append("No requirements.txt found")
        
        # Check validation reports
        validation_reports = list(package_dir.glob("validation-report-*.md"))
        if validation_reports:
            result['has_validation_report'] = True
        else:
            result['issues'].append("No validation reports found")
        
        result['valid'] = (result['valid_files'] / result['total_files']) >= 0.9 if result['total_files'] > 0 else False
        
        print(f"  📊 Dependencies: {result['valid_files']}/{result['total_files']} valid ({result['total_size'] / 1024 / 1024:.1f} MB)")
        
        return result
    
    def _validate_language_servers(self, package_dir: Path) -> Dict:
        """Validate language servers"""
        print("\n🔧 Validating Language Servers...")
        
        result = {
            'category': 'Language Servers',
            'valid': False,
            'servers': [],
            'total_servers': 0,
            'valid_servers': 0,
            'total_size': 0,
            'issues': []
        }
        
        # Look for language-servers directory
        lang_servers_dir = package_dir / "language-servers"
        if not lang_servers_dir.exists():
            # Also check if we're already in the language servers directory
            server_items = [item for item in package_dir.iterdir() 
                          if item.is_dir() and item.name not in ['uv-deps', '.git', '__pycache__']]
            manifest_files = list(package_dir.glob("manifest.json"))
            
            if manifest_files and server_items:
                lang_servers_dir = package_dir  # We're in the language servers directory
            else:
                result['issues'].append("Language servers directory not found")
                return result
        
        # Find server directories
        server_items = [item for item in lang_servers_dir.iterdir() 
                       if item.is_dir() and item.name not in ['manifest.json', '.DS_Store']]
        
        result['total_servers'] = len(server_items)
        
        if result['total_servers'] == 0:
            result['issues'].append("No language server directories found")
            return result
        
        print(f"  Found {result['total_servers']} language servers to validate")
        
        # Validate each server
        for server_dir in server_items:
            server_result = self._validate_language_server(server_dir)
            result['servers'].append(server_result)
            result['total_size'] += server_result['size']
            
            if server_result['valid']:
                result['valid_servers'] += 1
                if self.verbose:
                    print(f"    ✅ {server_dir.name}")
            else:
                if self.verbose:
                    print(f"    ❌ {server_dir.name}: {', '.join(server_result['errors'])}")
        
        # Check for manifest
        manifest_file = lang_servers_dir / "manifest.json"
        if not manifest_file.exists():
            result['issues'].append("Language servers manifest.json not found")
        
        result['valid'] = (result['valid_servers'] / result['total_servers']) >= 0.8 if result['total_servers'] > 0 else False
        
        print(f"  📊 Language Servers: {result['valid_servers']}/{result['total_servers']} valid ({result['total_size'] / 1024 / 1024:.1f} MB)")
        
        return result
    
    def _validate_installers(self, package_dir: Path) -> Dict:
        """Validate installer scripts"""
        print("\n📜 Validating Installer Scripts...")
        
        result = {
            'category': 'Installer Scripts',
            'valid': False,
            'installers': [],
            'issues': []
        }
        
        # Look for installer scripts
        installer_patterns = [
            "install-dependencies-offline.bat",
            "install-dependencies-offline.sh",
            "*.bat",
            "*.sh"
        ]
        
        found_installers = []
        for pattern in installer_patterns:
            found_installers.extend(list(package_dir.glob(pattern)))
            found_installers.extend(list((package_dir / "language-servers").glob(pattern)))
        
        # Remove duplicates
        found_installers = list(set(found_installers))
        
        if not found_installers:
            result['issues'].append("No installer scripts found")
            return result
        
        print(f"  Found {len(found_installers)} installer scripts")
        
        # Validate each installer
        for installer in found_installers:
            installer_result = self._validate_installer_script(installer)
            result['installers'].append(installer_result)
            
            if installer_result['valid']:
                if self.verbose:
                    print(f"    ✅ {installer.name}")
            else:
                if self.verbose:
                    print(f"    ❌ {installer.name}: {', '.join(installer_result['errors'])}")
        
        valid_installers = sum(1 for i in result['installers'] if i['valid'])
        result['valid'] = valid_installers > 0
        
        print(f"  📊 Installer Scripts: {valid_installers}/{len(found_installers)} valid")
        
        return result
    
    def _validate_manifests(self, package_dir: Path) -> Dict:
        """Validate manifest files"""
        print("\n📋 Validating Manifest Files...")
        
        result = {
            'category': 'Manifest Files',
            'valid': False,
            'manifests': [],
            'issues': []
        }
        
        # Look for manifest files
        manifest_patterns = [
            "manifest.json",
            "dependencies-manifest.json",
            "*manifest.json"
        ]
        
        found_manifests = []
        for pattern in manifest_patterns:
            found_manifests.extend(list(package_dir.glob(pattern)))
            lang_servers_dir = package_dir / "language-servers"
            if lang_servers_dir.exists():
                found_manifests.extend(list(lang_servers_dir.glob(pattern)))
        
        # Remove duplicates
        found_manifests = list(set(found_manifests))
        
        if not found_manifests:
            result['issues'].append("No manifest files found")
            return result
        
        print(f"  Found {len(found_manifests)} manifest files")
        
        # Validate each manifest
        for manifest in found_manifests:
            manifest_result = self._validate_manifest_file(manifest)
            result['manifests'].append(manifest_result)
            
            if manifest_result['valid']:
                if self.verbose:
                    print(f"    ✅ {manifest.name}")
            else:
                if self.verbose:
                    print(f"    ❌ {manifest.name}: {', '.join(manifest_result['errors'])}")
        
        valid_manifests = sum(1 for m in result['manifests'] if m['valid'])
        result['valid'] = valid_manifests > 0
        
        print(f"  📊 Manifest Files: {valid_manifests}/{len(found_manifests)} valid")
        
        return result
    
    def _validate_wheel_file(self, wheel_path: Path) -> Dict:
        """Validate a single wheel file"""
        result = {
            'path': str(wheel_path),
            'name': wheel_path.name,
            'valid': False,
            'size': 0,
            'sha256': '',
            'errors': []
        }
        
        try:
            # Check file exists and size
            if not wheel_path.exists():
                result['errors'].append("File does not exist")
                return result
            
            result['size'] = wheel_path.stat().st_size
            if result['size'] == 0:
                result['errors'].append("File is empty")
                return result
            
            if result['size'] < 1024:  # Less than 1KB is suspicious
                result['errors'].append("File too small (< 1KB)")
            
            # Calculate SHA256
            sha256_hash = hashlib.sha256()
            with open(wheel_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(chunk)
            result['sha256'] = sha256_hash.hexdigest()
            
            # Validate wheel structure
            if wheel_path.suffix.lower() == '.whl':
                with zipfile.ZipFile(wheel_path, 'r') as zip_file:
                    files = zip_file.namelist()
                    
                    # Check for required metadata files
                    has_metadata = any('.dist-info/METADATA' in f for f in files)
                    has_wheel = any('.dist-info/WHEEL' in f for f in files)
                    
                    if not has_metadata:
                        result['errors'].append("Missing METADATA file")
                    if not has_wheel:
                        result['errors'].append("Missing WHEEL file")
                    
                    # Test zip integrity
                    bad_file = zip_file.testzip()
                    if bad_file:
                        result['errors'].append(f"Corrupted file in archive: {bad_file}")
            
            result['valid'] = len(result['errors']) == 0
            
        except zipfile.BadZipFile:
            result['errors'].append("Corrupted ZIP file")
        except Exception as e:
            result['errors'].append(f"Validation error: {str(e)}")
        
        return result
    
    def _validate_language_server(self, server_dir: Path) -> Dict:
        """Validate a language server directory"""
        result = {
            'path': str(server_dir),
            'name': server_dir.name,
            'valid': False,
            'size': 0,
            'executable_found': False,
            'errors': []
        }
        
        try:
            if not server_dir.exists():
                result['errors'].append("Server directory does not exist")
                return result
            
            if not server_dir.is_dir():
                result['errors'].append("Path is not a directory")
                return result
            
            # Calculate total size
            total_size = 0
            executable_files = []
            
            for file_path in server_dir.rglob("*"):
                if file_path.is_file():
                    total_size += file_path.stat().st_size
                    
                    # Check for executable files
                    if (file_path.suffix.lower() in ['.exe', '.sh', '.bat', '.cmd'] or
                        (file_path.suffix == '' and os.access(file_path, os.X_OK))):
                        executable_files.append(file_path)
            
            result['size'] = total_size
            result['executable_found'] = len(executable_files) > 0
            
            if result['size'] == 0:
                result['errors'].append("Empty directory")
            elif result['size'] < 1024:
                result['errors'].append("Directory too small (< 1KB)")
            
            if not result['executable_found']:
                # This might be OK for some servers (e.g., Node.js based)
                # So we'll note it but not mark as invalid
                pass
            
            result['valid'] = len(result['errors']) == 0
            
        except Exception as e:
            result['errors'].append(f"Validation error: {str(e)}")
        
        return result
    
    def _validate_installer_script(self, installer_path: Path) -> Dict:
        """Validate an installer script"""
        result = {
            'path': str(installer_path),
            'name': installer_path.name,
            'valid': False,
            'size': 0,
            'errors': []
        }
        
        try:
            if not installer_path.exists():
                result['errors'].append("Installer script does not exist")
                return result
            
            result['size'] = installer_path.stat().st_size
            
            if result['size'] == 0:
                result['errors'].append("Installer script is empty")
                return result
            
            # Read and check content
            content = installer_path.read_text(encoding='utf-8', errors='ignore')
            
            # Basic content validation
            if installer_path.suffix.lower() == '.bat':
                # Check for basic batch script structure
                if not any(line.strip().startswith('@echo') for line in content.split('\n')):
                    result['errors'].append("Batch script missing echo commands")
                if 'pip install' not in content:
                    result['errors'].append("Batch script missing pip install commands")
            elif installer_path.suffix.lower() == '.sh':
                # Check for basic shell script structure
                if not content.startswith('#!/'):
                    result['errors'].append("Shell script missing shebang")
                if 'pip install' not in content:
                    result['errors'].append("Shell script missing pip install commands")
            
            result['valid'] = len(result['errors']) == 0
            
        except Exception as e:
            result['errors'].append(f"Validation error: {str(e)}")
        
        return result
    
    def _validate_manifest_file(self, manifest_path: Path) -> Dict:
        """Validate a manifest file"""
        result = {
            'path': str(manifest_path),
            'name': manifest_path.name,
            'valid': False,
            'size': 0,
            'content': {},
            'errors': []
        }
        
        try:
            if not manifest_path.exists():
                result['errors'].append("Manifest file does not exist")
                return result
            
            result['size'] = manifest_path.stat().st_size
            
            if result['size'] == 0:
                result['errors'].append("Manifest file is empty")
                return result
            
            # Parse JSON content
            with open(manifest_path, 'r', encoding='utf-8') as f:
                result['content'] = json.load(f)
            
            # Basic content validation
            if 'version' not in result['content']:
                result['errors'].append("Missing version field")
            
            # Check specific manifest types
            if manifest_path.name == 'dependencies-manifest.json':
                required_fields = ['dependencies', 'total_dependencies', 'python_version']
                for field in required_fields:
                    if field not in result['content']:
                        result['errors'].append(f"Missing required field: {field}")
            
            elif 'language' in manifest_path.name or 'servers' in result['content']:
                if 'servers' not in result['content']:
                    result['errors'].append("Language server manifest missing servers field")
            
            result['valid'] = len(result['errors']) == 0
            
        except json.JSONDecodeError as e:
            result['errors'].append(f"Invalid JSON: {str(e)}")
        except Exception as e:
            result['errors'].append(f"Validation error: {str(e)}")
        
        return result
    
    def _calculate_overall_stats(self, results: Dict):
        """Calculate overall statistics"""
        total_files = 0
        valid_files = 0
        total_size = 0
        all_warnings = []
        all_errors = []
        
        for category_name, category_result in results['categories'].items():
            if 'files' in category_result:
                total_files += len(category_result['files'])
                valid_files += category_result.get('valid_files', 0)
                total_size += category_result.get('total_size', 0)
            elif 'servers' in category_result:
                total_files += len(category_result['servers'])
                valid_files += category_result.get('valid_servers', 0)
                total_size += category_result.get('total_size', 0)
            elif 'installers' in category_result:
                total_files += len(category_result['installers'])
                valid_files += sum(1 for i in category_result['installers'] if i['valid'])
            elif 'manifests' in category_result:
                total_files += len(category_result['manifests'])
                valid_files += sum(1 for m in category_result['manifests'] if m['valid'])
            
            # Collect issues
            if 'issues' in category_result:
                all_warnings.extend(category_result['issues'])
        
        results['summary']['total_files'] = total_files
        results['summary']['valid_files'] = valid_files
        results['summary']['invalid_files'] = total_files - valid_files
        results['summary']['total_size_mb'] = total_size / 1024 / 1024
        results['summary']['warnings'] = all_warnings
        results['summary']['errors'] = all_errors
        
        # Determine overall validity
        success_rate = (valid_files / total_files) if total_files > 0 else 0
        results['overall_valid'] = success_rate >= 0.9  # 90% success rate required
        results['success_rate'] = success_rate
    
    def _generate_integrity_report(self, results: Dict):
        """Generate comprehensive integrity report"""
        print("\n" + "=" * 60)
        print("📋 Generating Package Integrity Report...")
        print("=" * 60)
        
        # Create report
        report_lines = []
        report_lines.append("# Package Integrity Validation Report")
        report_lines.append(f"Generated: {results['validation_timestamp']}")
        report_lines.append(f"Package Directory: {results['package_directory']}")
        report_lines.append("")
        
        # Executive Summary
        success_rate = results.get('success_rate', 0) * 100
        overall_status = "✅ PASSED" if results['overall_valid'] else "❌ FAILED"
        
        report_lines.append("## Executive Summary")
        report_lines.append(f"**Overall Status: {overall_status}**")
        report_lines.append(f"- Success Rate: {success_rate:.1f}%")
        report_lines.append(f"- Total Files: {results['summary']['total_files']}")
        report_lines.append(f"- Valid Files: {results['summary']['valid_files']}")
        report_lines.append(f"- Invalid Files: {results['summary']['invalid_files']}")
        report_lines.append(f"- Total Size: {results['summary']['total_size_mb']:.1f} MB")
        report_lines.append("")
        
        # Category Results
        report_lines.append("## Category Results")
        report_lines.append("")
        
        for category_name, category_result in results['categories'].items():
            category_title = category_result.get('category', category_name.title())
            category_status = "✅" if category_result['valid'] else "❌"
            
            report_lines.append(f"### {category_status} {category_title}")
            
            if 'total_files' in category_result:
                report_lines.append(f"- Files: {category_result.get('valid_files', 0)}/{category_result['total_files']} valid")
                if 'total_size' in category_result:
                    report_lines.append(f"- Size: {category_result['total_size'] / 1024 / 1024:.1f} MB")
            elif 'total_servers' in category_result:
                report_lines.append(f"- Servers: {category_result.get('valid_servers', 0)}/{category_result['total_servers']} valid")
                if 'total_size' in category_result:
                    report_lines.append(f"- Size: {category_result['total_size'] / 1024 / 1024:.1f} MB")
            elif 'installers' in category_result:
                valid_count = sum(1 for i in category_result['installers'] if i['valid'])
                report_lines.append(f"- Scripts: {valid_count}/{len(category_result['installers'])} valid")
            elif 'manifests' in category_result:
                valid_count = sum(1 for m in category_result['manifests'] if m['valid'])
                report_lines.append(f"- Manifests: {valid_count}/{len(category_result['manifests'])} valid")
            
            if category_result.get('issues'):
                report_lines.append("- Issues:")
                for issue in category_result['issues']:
                    report_lines.append(f"  - ⚠️  {issue}")
            
            report_lines.append("")
        
        # Recommendations
        report_lines.append("## Recommendations")
        report_lines.append("")
        
        if results['overall_valid']:
            report_lines.append("✅ **Package integrity validation passed**")
            report_lines.append("- Package appears to be complete and valid")
            report_lines.append("- Ready for deployment")
        else:
            report_lines.append("❌ **Package integrity validation failed**")
            report_lines.append("- Some components are missing or corrupted")
            report_lines.append("- Review detailed results above")
            report_lines.append("- Re-download or regenerate failed components")
        
        report_lines.append("")
        report_lines.append("## Next Steps")
        report_lines.append("1. Address any failed validations")
        report_lines.append("2. Test package installation on target system")
        report_lines.append("3. Verify functionality of installed components")
        
        # Save report
        package_dir = Path(results['package_directory'])
        report_path = package_dir / "package-integrity-report.md"
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))
        
        # Print summary
        print(f"📊 Package Integrity Summary:")
        print(f"  Overall Status: {overall_status}")
        print(f"  Success Rate: {success_rate:.1f}%")
        print(f"  Valid Files: {results['summary']['valid_files']}/{results['summary']['total_files']}")
        print(f"  Total Size: {results['summary']['total_size_mb']:.1f} MB")
        print(f"📋 Full report: {report_path}")
        
        return report_path


def main():
    """Main function"""
    parser = argparse.ArgumentParser(description="Validate Serena MCP offline package integrity")
    parser.add_argument("package_dir", help="Path to the offline package directory")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--dependencies-only", action="store_true", help="Validate only Python dependencies")
    parser.add_argument("--language-servers-only", action="store_true", help="Validate only language servers")
    
    args = parser.parse_args()
    
    package_path = Path(args.package_dir)
    
    if not package_path.exists():
        print(f"❌ Error: Package directory does not exist: {package_path}")
        return 1
    
    validator = PackageIntegrityValidator(verbose=args.verbose)
    
    print("🔍 Package Integrity Validator for Serena MCP")
    print("=" * 50)
    
    try:
        results = validator.validate_offline_package(package_path)
        
        # Return appropriate exit code
        if results['overall_valid']:
            print("\n🎉 Package validation completed successfully!")
            return 0
        else:
            print("\n⚠️  Package validation detected issues.")
            print("Please review the validation report for details.")
            return 1
            
    except KeyboardInterrupt:
        print("\n⏹️  Validation interrupted by user")
        return 130
    except Exception as e:
        print(f"\n❌ Validation failed with error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())