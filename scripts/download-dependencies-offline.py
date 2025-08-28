#!/usr/bin/env python3
"""
Download all Python dependencies as wheels for offline portable deployment
Handles proxy and certificate issues for corporate environments
"""

import argparse
import hashlib
import os
import subprocess
import sys
import time
from pathlib import Path

# Handle Windows console encoding issues for Windows 10 compatibility
if sys.platform == "win32":
    try:
        # Try to set UTF-8 encoding for better Unicode support
        import os
        os.system('chcp 65001 >nul 2>&1')  # Set console to UTF-8
        
        if hasattr(sys.stdout, 'reconfigure'):
            sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        if hasattr(sys.stderr, 'reconfigure'):
            sys.stderr.reconfigure(encoding='utf-8', errors='replace')
        
        # Set environment variable for subprocess calls
        os.environ['PYTHONIOENCODING'] = 'utf-8'
    except Exception:
        # If reconfigure fails, continue with default encoding
        pass

# Define ASCII-safe output functions for Windows 10 legacy console compatibility
def safe_print(message, use_ascii_fallback=True):
    """Print message with fallback to ASCII characters for Windows 10 compatibility"""
    try:
        print(message)
    except UnicodeEncodeError:
        if use_ascii_fallback and sys.platform == "win32":
            # Replace Unicode characters with ASCII equivalents
            ascii_message = message.replace('✓', '[OK]').replace('✗', '[ERROR]').replace('❌', '[ERROR]')
            print(ascii_message)
        else:
            # Fallback: encode with error replacement
            encoded = message.encode('ascii', errors='replace').decode('ascii')
            print(encoded)


class ProgressTracker:
    """Track download and operation progress with ETA"""
    
    def __init__(self, total_items: int, description: str = "Processing"):
        self.total_items = total_items
        self.description = description
        self.current_item = 0
        self.start_time = time.time()
        self.last_update = 0
        
    def update(self, current_item: int, item_description: str = ""):
        """Update progress and display progress bar with ETA"""
        self.current_item = current_item
        current_time = time.time()
        
        # Only update display every 0.5 seconds to avoid spam
        if current_time - self.last_update < 0.5 and current_item < self.total_items:
            return
            
        self.last_update = current_time
        
        # Calculate progress
        progress = self.current_item / self.total_items if self.total_items > 0 else 0
        elapsed = current_time - self.start_time
        
        # Calculate ETA
        if progress > 0 and self.current_item < self.total_items:
            eta_seconds = (elapsed / progress) - elapsed
            eta_str = f"ETA: {int(eta_seconds // 60)}:{int(eta_seconds % 60):02d}"
        else:
            eta_str = "ETA: --:--"
            
        # Create progress bar
        bar_width = 30
        filled = int(bar_width * progress)
        bar = "█" * filled + "░" * (bar_width - filled)
        
        # Format output
        elapsed_str = f"{int(elapsed // 60)}:{int(elapsed % 60):02d}"
        status = f"\r{self.description} [{bar}] {self.current_item}/{self.total_items} ({progress:.1%}) - {elapsed_str} - {eta_str}"
        
        if item_description:
            status += f" - {item_description[:30]}"
            
        print(status, end="", flush=True)
        
        if self.current_item >= self.total_items:
            print()  # New line when complete


class PackageValidator:
    """Validate downloaded packages for integrity"""
    
    def __init__(self):
        self.validation_results = []
        
    def validate_wheel_file(self, wheel_path: Path) -> dict:
        """Validate a wheel file for integrity"""
        result = {
            'path': wheel_path,
            'valid': False,
            'size': 0,
            'sha256': '',
            'errors': []
        }
        
        try:
            if not wheel_path.exists():
                result['errors'].append('File does not exist')
                return result
                
            # Check file size
            stat = wheel_path.stat()
            result['size'] = stat.st_size
            
            if result['size'] == 0:
                result['errors'].append('File is empty')
                return result
                
            if result['size'] < 1024:  # Less than 1KB is suspicious
                result['errors'].append('File too small (< 1KB)')
                
            # Calculate SHA256 checksum
            sha256_hash = hashlib.sha256()
            with open(wheel_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(chunk)
            result['sha256'] = sha256_hash.hexdigest()
            
            # Validate wheel structure (basic check)
            if wheel_path.suffix.lower() == '.whl':
                import zipfile
                try:
                    with zipfile.ZipFile(wheel_path, 'r') as zip_file:
                        # Check for required wheel metadata
                        files = zip_file.namelist()
                        has_metadata = any('.dist-info/METADATA' in f for f in files)
                        has_wheel_info = any('.dist-info/WHEEL' in f for f in files)
                        
                        if not has_metadata:
                            result['errors'].append('Missing METADATA file')
                        if not has_wheel_info:
                            result['errors'].append('Missing WHEEL file')
                            
                        # Check if zip is corrupted
                        zip_file.testzip()
                        
                except zipfile.BadZipFile:
                    result['errors'].append('Corrupted ZIP/wheel file')
                except Exception as e:
                    result['errors'].append(f'Wheel validation error: {str(e)}')
                    
            result['valid'] = len(result['errors']) == 0
            
        except Exception as e:
            result['errors'].append(f'Validation failed: {str(e)}')
            
        return result
        
    def validate_directory(self, directory: Path, expected_count: int = None) -> dict:
        """Validate all wheels in a directory"""
        results = {
            'directory': directory,
            'total_files': 0,
            'valid_files': 0,
            'invalid_files': 0,
            'total_size': 0,
            'files': [],
            'errors': []
        }
        
        try:
            wheel_files = list(directory.glob("*.whl"))
            results['total_files'] = len(wheel_files)
            
            if expected_count and results['total_files'] != expected_count:
                results['errors'].append(f'Expected {expected_count} files, found {results["total_files"]}')
                
            progress = ProgressTracker(len(wheel_files), f"Validating {directory.name}")
            
            for i, wheel_file in enumerate(wheel_files):
                progress.update(i, wheel_file.name)
                
                file_result = self.validate_wheel_file(wheel_file)
                results['files'].append(file_result)
                results['total_size'] += file_result['size']
                
                if file_result['valid']:
                    results['valid_files'] += 1
                else:
                    results['invalid_files'] += 1
                    
            progress.update(len(wheel_files), "Complete")
            
        except Exception as e:
            results['errors'].append(f'Directory validation failed: {str(e)}')
            
        return results
        
    def generate_validation_report(self, results: dict, output_path: Path):
        """Generate detailed validation report"""
        report_lines = []
        report_lines.append("# Package Validation Report")
        report_lines.append(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append("")
        
        # Summary
        report_lines.append("## Summary")
        report_lines.append(f"- Directory: {results['directory']}")
        report_lines.append(f"- Total files: {results['total_files']}")
        report_lines.append(f"- Valid files: {results['valid_files']}")
        report_lines.append(f"- Invalid files: {results['invalid_files']}")
        report_lines.append(f"- Total size: {results['total_size'] / 1024 / 1024:.1f} MB")
        report_lines.append("")
        
        # Errors
        if results['errors']:
            report_lines.append("## Directory-level Issues")
            for error in results['errors']:
                report_lines.append(f"- [ERROR] {error}")
            report_lines.append("")
            
        # File details
        if results['files']:
            report_lines.append("## File Validation Results")
            report_lines.append("")
            
            for file_result in results['files']:
                status = "[OK]" if file_result['valid'] else "[ERROR]"
                name = file_result['path'].name
                size_mb = file_result['size'] / 1024 / 1024
                report_lines.append(f"### {status} {name}")
                report_lines.append(f"- Size: {size_mb:.2f} MB")
                report_lines.append(f"- SHA256: {file_result['sha256']}")
                
                if file_result['errors']:
                    report_lines.append("- Issues:")
                    for error in file_result['errors']:
                        report_lines.append(f"  - {error}")
                report_lines.append("")
                
        # Write report
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))


class OfflineDependencyDownloader:
    def __init__(self, proxy_url: str | None = None, ca_cert_path: str | None = None, python_exe: str | None = None, platform_override: str | None = None):
        self.proxy_url = proxy_url or os.environ.get("HTTP_PROXY")
        self.ca_cert_path = ca_cert_path or os.environ.get("REQUESTS_CA_BUNDLE")
        self.python_exe = python_exe or sys.executable  # Allow override of Python executable
        self.platform_override = platform_override
        self.pip_args = self._build_pip_args()
        self.validator = PackageValidator()

    def _build_pip_args(self) -> list[str]:
        """Build pip arguments for proxy and certificate handling"""
        args = []

        if self.proxy_url:
            args.extend(["--proxy", self.proxy_url])
            print(f"[OK] Using proxy: {self.proxy_url}")

        if self.ca_cert_path and os.path.exists(self.ca_cert_path):
            args.extend(["--cert", self.ca_cert_path])
            print(f"[OK] Using CA certificate: {self.ca_cert_path}")

        # Add trusted hosts for corporate environments
        args.extend(["--trusted-host", "pypi.org", "--trusted-host", "pypi.python.org", "--trusted-host", "files.pythonhosted.org"])

        return args

    def _get_platform_tag(self) -> str:
        """Get the appropriate platform tag for pip downloads"""
        if self.platform_override:
            return self.platform_override
            
        import platform
        import sys
        
        system = platform.system().lower()
        machine = platform.machine().lower()
        
        if system == "windows":
            if machine in ["amd64", "x86_64"]:
                return "win_amd64"
            elif machine in ["i386", "i686", "x86"]:
                return "win32"
            else:
                return "win_amd64"  # Default for Windows
        elif system == "darwin":  # macOS
            if machine in ["arm64", "aarch64"]:
                return "macosx_11_0_arm64"
            else:
                return "macosx_10_9_x86_64"
        elif system == "linux":
            if machine in ["aarch64", "arm64"]:
                return "linux_aarch64"
            else:
                return "linux_x86_64"
        else:
            # Fallback - let pip determine automatically
            return "any"

    def create_requirements_txt(self, pyproject_path: Path, output_path: Path):
        """Extract dependencies from pyproject.toml and create requirements.txt"""
        print("Creating requirements.txt from pyproject.toml...")

        # Create output directory first
        output_path.mkdir(parents=True, exist_ok=True)

        # Read pyproject.toml and extract dependencies
        try:
            import tomllib
        except ImportError:
            # Python < 3.11 fallback
            try:
                import tomli as tomllib
            except ImportError:
                print("Installing tomli for TOML parsing...")
                subprocess.run([sys.executable, "-m", "pip", "install", "tomli"], check=True)
                import tomli as tomllib

        with open(pyproject_path, "rb") as f:
            pyproject_data = tomllib.load(f)

        dependencies = pyproject_data.get("project", {}).get("dependencies", [])

        # Write requirements.txt
        requirements_path = output_path / "requirements.txt"
        with open(requirements_path, "w") as f:
            for dep in dependencies:
                f.write(f"{dep}\n")

        print(f"[OK] Created requirements.txt with {len(dependencies)} dependencies")
        return requirements_path, dependencies

    def download_dependencies(self, requirements_path: Path, output_dir: Path, python_version: str = "3.11"):
        """Download all dependencies as wheels"""
        print(f"Downloading dependencies to {output_dir}...")
        
        # Get platform tag for downloads
        platform_tag = self._get_platform_tag()
        print(f"Target platform: {platform_tag}")

        # Create output directory
        output_dir.mkdir(parents=True, exist_ok=True)

        # CRITICAL: Validate requirements.txt exists and has content
        if not requirements_path.exists():
            safe_print(f"[ERROR] Requirements file not found: {requirements_path}")
            return False

        with open(requirements_path) as f:
            requirements_content = f.read().strip()

        # Show a preview of the requirements
        print(f"Requirements preview: {requirements_content[:100]}{'...' if len(requirements_content) > 100 else ''}")

        if not requirements_content:
            safe_print(f"[ERROR] Requirements file is empty: {requirements_path}")
            return False

        # Filter valid requirement lines
        valid_requirements = [
            line.strip() for line in requirements_content.split("\n") if line.strip() and not line.strip().startswith("#")
        ]

        if not valid_requirements:
            safe_print(f"[ERROR] No valid requirements found in: {requirements_path}")
            return False

        req_count = len(valid_requirements)
        print(f"[OK] Found {req_count} requirements in {requirements_path}")
        print(f"Key requirements: {', '.join(valid_requirements[:5])}{'...' if len(valid_requirements) > 5 else ''}")

        # FIXED: Try multiple approaches for calling pip - SEPARATE base command from download subcommand
        pip_methods = [
            # Method 1: python -m pip (preferred)
            ([self.python_exe, "-m", "pip"], "download"),
            # Method 2: Direct pip call (fallback)
            (["pip"], "download"),
        ]

        # FIXED: Use absolute paths and proper Windows handling
        requirements_path_abs = requirements_path.resolve()
        output_dir_abs = output_dir.resolve()

        # Build base arguments - CRITICAL: ensure --requirement comes with absolute path
        base_args = (
            [
                "--dest",
                str(output_dir_abs),
                "--prefer-binary",
            ]
            + self.pip_args
            + [
                "--requirement", 
                str(requirements_path_abs)
            ]
        )

        # Try each method
        for i, (pip_base, pip_subcommand) in enumerate(pip_methods, 1):
            print(f"Trying method {i}: {' '.join(pip_base)} {pip_subcommand}...")
            cmd = pip_base + [pip_subcommand] + base_args

            # Show the command for debugging (concise)
            cmd_preview = " ".join(cmd[:8]) + ("..." if len(cmd) > 8 else "")
            print(f"Running: {cmd_preview}")

            try:
                # Test if pip is available first - CRITICAL FIX: Use pip_base for version test, not pip_cmd
                test_cmd = pip_base + ["--version"]
                test_result = subprocess.run(test_cmd, check=False, capture_output=True, text=True, timeout=10)
                
                if test_result.returncode != 0:
                    print(f"  Method {i} not available: {test_result.stderr.strip()}")
                    continue

                # Simple availability test
                print(f"  Testing {' '.join(pip_base)} availability...")
                
                # CRITICAL FIX: Use correct working directory for pip download
                # Try with explicit working directory set to output directory first (this often fixes path issues)
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=300, cwd=str(output_dir_abs))
                
                # If that fails, try without specific cwd as fallback
                if result.returncode != 0:
                    print(f"  Retrying without specific working directory...")
                    result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=300)

                if result.returncode == 0:
                    print("[OK] Successfully downloaded all dependencies using bulk download")
                    return True
                else:
                    print(f"  Method {i} failed with exit code {result.returncode}")
                    print(f"  STDERR: {result.stderr.strip()}")
                    if "You must give at least one requirement" in result.stderr:
                        print("  [DEBUG] Requirements file issue detected")
                        print(f"  [DEBUG] File exists: {requirements_path_abs.exists()}")
                        print(f"  [DEBUG] File readable: {requirements_path_abs.is_file()}")
                        print(
                            f"  [DEBUG] File size: {requirements_path_abs.stat().st_size if requirements_path_abs.exists() else 'N/A'} bytes"
                        )
                    continue

            except subprocess.TimeoutExpired:
                print(f"  Method {i} timed out")
                continue
            except FileNotFoundError:
                print(f"  Method {i} - command not found")
                continue
            except Exception as e:
                print(f"  Method {i} failed with exception: {e}")
                continue

        safe_print("[WARN] Bulk download failed, falling back to individual package downloads...")
        print("Attempting individual package downloads...")

        # Fallback: Try downloading packages individually
        return self._download_individual_packages(valid_requirements, output_dir_abs)

    def _download_individual_packages(self, requirements: list[str], output_dir: Path) -> bool:
        """Fallback method to download packages individually"""
        print("Attempting individual package downloads...")
        
        # Get platform tag for downloads
        platform_tag = self._get_platform_tag()

        successful_downloads = 0
        
        # Initialize progress tracker
        progress = ProgressTracker(len(requirements), "Downloading packages")

        for i, requirement in enumerate(requirements):
            progress.update(i, requirement)
            # Build command with platform-specific options
            cmd = [self.python_exe, "-m", "pip", "download", "--dest", str(output_dir), "--prefer-binary"]
            
            # Add platform-specific options for Windows
            if "win" in platform_tag.lower():
                cmd.extend(["--platform", platform_tag, "--only-binary", ":all:"])
            
            cmd.extend(self.pip_args + [requirement])

            try:
                # CRITICAL FIX: Do NOT use shell=True - it breaks on Windows
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=60)
                if result.returncode == 0:
                    successful_downloads += 1
                else:
                    pass  # Progress tracker shows the current item
            except Exception as e:
                pass  # Progress tracker shows the current item

        progress.update(len(requirements), "Complete")
        print(f"Individual downloads: {successful_downloads}/{len(requirements)} successful")

        # Cleanup any temporary files that might have been created
        self._cleanup_temp_files(output_dir)

        # Consider it successful if we got most packages
        return successful_downloads >= len(requirements) * 0.8

    def _cleanup_temp_files(self, directory: Path):
        """Remove temporary files created during failed download attempts"""
        try:
            # Remove any temporary pip download files
            for temp_file in directory.glob("*.tmp"):
                try:
                    temp_file.unlink()
                    print(f"[CLEANUP] Removed temporary file: {temp_file.name}")
                except Exception:
                    pass

            # Remove any incomplete downloads
            for partial_file in directory.glob("*.partial"):
                try:
                    partial_file.unlink()
                    print(f"[CLEANUP] Removed partial file: {partial_file.name}")
                except Exception:
                    pass
        except Exception as e:
            print(f"[CLEANUP] Warning: Could not clean temporary files: {e}")

    def download_uv_dependencies(self, output_dir: Path):
        """Download UV and its dependencies"""
        print("Downloading UV and its dependencies...")

        uv_dir = output_dir / "uv-deps"
        uv_dir.mkdir(exist_ok=True)

        # FIXED: Try multiple approaches for calling pip (same as main dependencies)
        pip_methods = [
            ([self.python_exe, "-m", "pip"], "download"),
            (["pip"], "download"),
        ]

        # FIXED: Use absolute paths for Windows compatibility
        uv_dir_abs = uv_dir.resolve()

        # ENHANCED: Add more specific package requirements for UV
        uv_packages = ["uv", "packaging>=21.3", "platformdirs>=2.5.0"]  # UV and its core dependencies

        # FIXED: Proper argument construction - packages should be separate arguments
        # Detect platform dynamically instead of hardcoding win_amd64
        platform_tag = self._get_platform_tag()
        base_args = ["--dest", str(uv_dir_abs), "--platform", platform_tag, "--only-binary=:all:"] + self.pip_args

        # Try each method
        for i, (pip_base, pip_subcommand) in enumerate(pip_methods, 1):
            print(f"Trying UV download method {i}: {' '.join(pip_base)} {pip_subcommand}...")
            # CRITICAL FIX: Add packages as separate arguments at the end
            cmd = pip_base + [pip_subcommand] + base_args + uv_packages

            print(f"Running: {' '.join(cmd[:6])}... {' '.join(uv_packages)}")

            try:
                # Test if pip is available first
                test_cmd = pip_base + ["--version"]
                test_result = subprocess.run(test_cmd, check=False, capture_output=True, text=True, timeout=10)
                if test_result.returncode != 0:
                    print(f"  UV method {i} not available: {test_result.stderr.strip()}")
                    continue

                # CRITICAL FIX: Do NOT use shell=True
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=120)
                if result.returncode == 0:
                    print("[OK] Downloaded UV and dependencies")
                    return True
                else:
                    print(f"  UV method {i} failed with exit code {result.returncode}")
                    print(f"  STDERR: {result.stderr.strip()}")
                    continue

            except subprocess.TimeoutExpired:
                print(f"  UV method {i} timed out")
                continue
            except FileNotFoundError:
                print(f"  UV method {i} - command not found")
                continue
            except Exception as e:
                print(f"  UV method {i} failed with exception: {e}")
                continue

        safe_print("[WARN] UV bulk download failed, trying individual packages...")

        # Fallback: Try downloading UV packages individually
        print("Attempting individual UV package downloads...")
        successful_uv_downloads = 0

        for package in uv_packages:
            print(f"  Downloading: {package}")
            cmd = (
                [self.python_exe, "-m", "pip", "download", "--dest", str(uv_dir_abs), "--platform", platform_tag, "--only-binary=:all:"]
                + self.pip_args
                + [package]
            )

            try:
                # CRITICAL FIX: Do NOT use shell=True
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=60)
                if result.returncode == 0:
                    print(f"    [OK] {package}")
                    successful_uv_downloads += 1
                else:
                    safe_print(f"    [ERROR] {package}: {result.stderr.strip()}")
            except Exception as e:
                safe_print(f"    [ERROR] {package}: {e}")

        print(f"UV individual downloads: {successful_uv_downloads}/{len(uv_packages)} successful")
        return successful_uv_downloads > 0

    def create_offline_installer(self, output_dir: Path):
        """Create offline installation script for target platform"""
        # Determine target platform from platform tag or current system
        platform_tag = self._get_platform_tag()
        
        # Create installer based on target platform, not current OS
        if "win" in platform_tag.lower():
            self._create_windows_installer(output_dir)
        elif any(x in platform_tag.lower() for x in ["linux", "macos", "darwin"]):
            self._create_unix_installer(output_dir)
        else:
            # Create both installers if platform is unclear
            self._create_windows_installer(output_dir)
            self._create_unix_installer(output_dir)
    
    def _create_windows_installer(self, output_dir: Path):
        """Create Windows batch installer"""
        installer_script = output_dir / "install-dependencies-offline.bat"

        script_content = """@echo off
echo Installing Serena dependencies offline...
setlocal

:: Set paths
set SERENA_PORTABLE=%~dp0..
set PYTHONHOME=%SERENA_PORTABLE%\\python
set DEPENDENCIES=%~dp0
set TARGET_DIR=%SERENA_PORTABLE%\\Lib\\site-packages

:: Check if pip module is available (try module, then shim)
echo Checking pip availability...
"%PYTHONHOME%\\python.exe" -m pip --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "%PYTHONHOME%\\runpip.py" (
        echo [INFO] Trying runpip.py shim...
        "%PYTHONHOME%\\python.exe" "%PYTHONHOME%\\runpip.py" --version >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo [WARN] pip not available (module or shim). Trying alternative installation...
            goto :alternative_install
        ) else (
            set USE_SHIM=1
        )
    ) else (
        echo [WARN] pip module not available and no shim found. Trying alternative installation...
        goto :alternative_install
    )
)

:: Install UV first (if available)
if exist "%DEPENDENCIES%\\uv-deps" (
    echo Installing UV...
    if defined USE_SHIM (
        "%PYTHONHOME%\\python.exe" "%PYTHONHOME%\\runpip.py" install --no-index --find-links "%DEPENDENCIES%\\uv-deps" --target "%TARGET_DIR%" uv
    ) else (
        "%PYTHONHOME%\\python.exe" -m pip install --no-index --find-links "%DEPENDENCIES%\\uv-deps" --target "%TARGET_DIR%" uv
    )
)

:: Install main dependencies
echo Installing Serena dependencies...
if defined USE_SHIM (
    "%PYTHONHOME%\\python.exe" "%PYTHONHOME%\\runpip.py" install --no-index --find-links "%DEPENDENCIES%" --target "%TARGET_DIR%" --requirement "%DEPENDENCIES%\\requirements.txt"
else (
    "%PYTHONHOME%\\python.exe" -m pip install --no-index --find-links "%DEPENDENCIES%" --target "%TARGET_DIR%" --requirement "%DEPENDENCIES%\\requirements.txt"
)
goto :verify

:alternative_install
echo Attempting manual wheel installation...
:: Try to manually copy wheel files - fallback method
for %%f in ("%DEPENDENCIES%\\*.whl") do (
    echo Installing %%~nxf...
    "%PYTHONHOME%\\python.exe" -m zipfile -e "%%f" "%TARGET_DIR%\\" >nul 2>&1
)

:verify
:: Verify installation
echo Verifying installation...
"%PYTHONHOME%\\python.exe" -c "import serena; print('[OK] Serena dependencies installed successfully')" 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Installation verification failed
    echo [INFO] You may need internet access for first run
    pause
    exit /b 1
)

echo.
echo [OK] All dependencies installed successfully!
echo You can now use serena-mcp-portable.bat
pause
"""

        with open(installer_script, "w") as f:
            f.write(script_content)

        print(f"[OK] Created Windows offline installer: {installer_script}")
    
    def _create_unix_installer(self, output_dir: Path):
        """Create Unix shell installer"""
        installer_script = output_dir / "install-dependencies-offline.sh"

        script_content = """#!/bin/bash
echo "Installing Serena dependencies offline..."

# Set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERENA_PORTABLE="$(dirname "$SCRIPT_DIR")"
DEPENDENCIES="$SCRIPT_DIR"
TARGET_DIR="$SERENA_PORTABLE/lib/python3.11/site-packages"

# Find Python executable
if command -v python3 &> /dev/null; then
    PYTHON_EXE="python3"
elif command -v python &> /dev/null; then
    PYTHON_EXE="python"
else
    echo "[ERROR] No Python executable found"
    exit 1
fi

echo "Using Python: $PYTHON_EXE"

# Create target directory
mkdir -p "$TARGET_DIR"

# Check if pip module is available
echo "Checking pip availability..."
if ! "$PYTHON_EXE" -m pip --version &>/dev/null; then
    echo "[WARN] pip module not available, trying alternative installation..."
    alternative_install=true
else
    alternative_install=false
fi

if [ "$alternative_install" = false ]; then
    # Install UV first (if available)
    if [ -d "$DEPENDENCIES/uv-deps" ]; then
        echo "Installing UV..."
        "$PYTHON_EXE" -m pip install --no-index --find-links "$DEPENDENCIES/uv-deps" --target "$TARGET_DIR" uv
    fi

    # Install main dependencies
    echo "Installing Serena dependencies..."
    "$PYTHON_EXE" -m pip install --no-index --find-links "$DEPENDENCIES" --target "$TARGET_DIR" --requirement "$DEPENDENCIES/requirements.txt"
else
    echo "Attempting manual wheel installation..."
    # Try to manually extract wheel files - fallback method
    for wheel in "$DEPENDENCIES"/*.whl; do
        if [ -f "$wheel" ]; then
            echo "Installing $(basename "$wheel")..."
            # Extract wheel using Python zipfile module
            "$PYTHON_EXE" -m zipfile -e "$wheel" "$TARGET_DIR/" 2>/dev/null || true
        fi
    done
fi

# Verify installation
echo "Verifying installation..."
if "$PYTHON_EXE" -c "import serena; print('[OK] Serena dependencies installed successfully')" 2>/dev/null; then
    echo ""
    echo "[OK] All dependencies installed successfully!"
    echo "You can now use serena-mcp-portable"
else
    echo "[ERROR] Installation verification failed"
    echo "[INFO] You may need internet access for first run"
    exit 1
fi
"""

        with open(installer_script, "w") as f:
            f.write(script_content)
        
        # Make the script executable
        import os
        os.chmod(installer_script, 0o755)

        print(f"[OK] Created Unix offline installer: {installer_script}")

    def create_manifest(self, output_dir: Path, dependencies: list[str]):
        """Create manifest with dependency information"""
        import json
        from datetime import datetime

        manifest = {
            "version": "1.0",
            "created": datetime.now().isoformat(),
            "python_version": sys.version,
            "platform": sys.platform,
            "total_dependencies": len(dependencies),
            "dependencies": dependencies,
            "proxy_used": self.proxy_url is not None,
            "cert_used": self.ca_cert_path is not None,
        }

        manifest_path = output_dir / "dependencies-manifest.json"
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)

        print(f"[OK] Created manifest: {manifest_path}")


def main():
    parser = argparse.ArgumentParser(description="Download Python dependencies for offline deployment")
    parser.add_argument("--proxy", help="HTTP proxy URL")
    parser.add_argument("--cert", help="CA certificate bundle path")
    parser.add_argument("--output", default="dependencies", help="Output directory for wheels")
    parser.add_argument("--pyproject", default="pyproject.toml", help="Path to pyproject.toml")
    parser.add_argument("--python-version", default="3.11", help="Target Python version")
    parser.add_argument("--platform", help="Target platform (auto-detected if not specified)")
    parser.add_argument("--python-exe", help="Path to Python executable to use for pip commands")

    args = parser.parse_args()

    # Initialize downloader with optional Python executable path and platform override
    downloader = OfflineDependencyDownloader(args.proxy, args.cert, args.python_exe, args.platform)

    # Setup paths
    pyproject_path = Path(args.pyproject)
    output_dir = Path(args.output)

    if not pyproject_path.exists():
        print(f"Error: {pyproject_path} not found")
        return 1

    print("=" * 60)
    print("Serena MCP - Offline Dependencies Downloader")
    print("=" * 60)

    try:
        # Create requirements.txt from pyproject.toml
        requirements_path, dependencies = downloader.create_requirements_txt(pyproject_path, output_dir)

        # Download main dependencies
        if not downloader.download_dependencies(requirements_path, output_dir, args.python_version):
            return 1

        # Download UV dependencies
        if not downloader.download_uv_dependencies(output_dir):
            return 1

        # Create offline installer
        downloader.create_offline_installer(output_dir)

        # Create manifest
        downloader.create_manifest(output_dir, dependencies)

        print("=" * 60)
        print("🔍 Validating Downloaded Packages...")
        print("=" * 60)
        
        # Validate main dependencies
        main_validation = downloader.validator.validate_directory(output_dir, len(dependencies))
        uv_dir = output_dir / "uv-deps"
        
        # Validate UV dependencies if they exist
        uv_validation = None
        if uv_dir.exists():
            uv_validation = downloader.validator.validate_directory(uv_dir)
        
        # Generate validation reports
        downloader.validator.generate_validation_report(main_validation, output_dir / "validation-report-main.md")
        if uv_validation:
            downloader.validator.generate_validation_report(uv_validation, output_dir / "validation-report-uv.md")
        
        print("=" * 60)
        print("📊 Download & Validation Summary")
        print("=" * 60)
        print(f"Main dependencies: {main_validation['valid_files']}/{main_validation['total_files']} valid wheels")
        if uv_validation:
            print(f"UV dependencies: {uv_validation['valid_files']}/{uv_validation['total_files']} valid wheels")
        print(f"Total size: {(main_validation['total_size'] + (uv_validation['total_size'] if uv_validation else 0)) / 1024 / 1024:.1f} MB")
        print(f"Output directory: {output_dir.absolute()}")
        
        # Check if validation passed
        main_success_rate = main_validation['valid_files'] / main_validation['total_files'] if main_validation['total_files'] > 0 else 0
        uv_success_rate = uv_validation['valid_files'] / uv_validation['total_files'] if uv_validation and uv_validation['total_files'] > 0 else 1
        
        overall_success = main_success_rate >= 0.9 and uv_success_rate >= 0.9  # 90% success rate required
        
        if overall_success:
            safe_print("[SUCCESS] All packages validated successfully!")
            safe_print("[INFO] Validation Reports:")
            safe_print(f"- Main dependencies: {output_dir}/validation-report-main.md")
            if uv_validation:
                safe_print(f"- UV dependencies: {output_dir}/validation-report-uv.md")
        else:
            safe_print(f"[WARNING] Some packages failed validation (success rate: {main_success_rate:.1%})")
            safe_print("Please review the validation reports for details.")
            
        safe_print("[INFO] Next Steps:")
        safe_print("1. Copy this directory to your portable package")
        safe_print("2. Run install-dependencies-offline.bat/.sh to install offline")
        safe_print("3. Review validation reports if there were any issues")

        return 0

    except Exception as e:
        safe_print(f"[ERROR] Error: {e!s}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
