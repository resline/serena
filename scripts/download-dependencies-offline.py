#!/usr/bin/env python3
"""
Download all Python dependencies as wheels for offline portable deployment
Handles proxy and certificate issues for corporate environments
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


class OfflineDependencyDownloader:
    def __init__(self, proxy_url: str | None = None, ca_cert_path: str | None = None, python_exe: str | None = None):
        self.proxy_url = proxy_url or os.environ.get("HTTP_PROXY")
        self.ca_cert_path = ca_cert_path or os.environ.get("REQUESTS_CA_BUNDLE")
        self.python_exe = python_exe or sys.executable  # Allow override of Python executable
        self.pip_args = self._build_pip_args()

    def _build_pip_args(self) -> list[str]:
        """Build pip arguments for proxy and certificate handling"""
        args = []

        if self.proxy_url:
            args.extend(["--proxy", self.proxy_url])
            print(f"✓ Using proxy: {self.proxy_url}")

        if self.ca_cert_path and os.path.exists(self.ca_cert_path):
            args.extend(["--cert", self.ca_cert_path])
            print(f"✓ Using CA certificate: {self.ca_cert_path}")

        # Add trusted hosts for corporate environments
        args.extend(["--trusted-host", "pypi.org", "--trusted-host", "pypi.python.org", "--trusted-host", "files.pythonhosted.org"])

        return args

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

        print(f"✓ Created requirements.txt with {len(dependencies)} dependencies")
        return requirements_path, dependencies

    def download_dependencies(self, requirements_path: Path, output_dir: Path, python_version: str = "3.11"):
        """Download all dependencies as wheels"""
        print(f"Downloading dependencies to {output_dir}...")

        # Create output directory
        output_dir.mkdir(parents=True, exist_ok=True)

        # CRITICAL: Validate requirements.txt exists and has content
        if not requirements_path.exists():
            print(f"❌ Error: Requirements file not found: {requirements_path}")
            return False

        with open(requirements_path) as f:
            requirements_content = f.read().strip()

        # Debug: Show the actual requirements content
        print(f"[DEBUG] Requirements file content (first 200 chars): {requirements_content[:200]}")

        if not requirements_content:
            print(f"❌ Error: Requirements file is empty: {requirements_path}")
            return False

        # Filter valid requirement lines
        valid_requirements = [
            line.strip() for line in requirements_content.split("\n") if line.strip() and not line.strip().startswith("#")
        ]

        if not valid_requirements:
            print(f"❌ Error: No valid requirements found in: {requirements_path}")
            return False

        req_count = len(valid_requirements)
        print(f"✓ Found {req_count} requirements in {requirements_path}")
        print(f"[DEBUG] Requirements: {', '.join(valid_requirements[:5])}{'...' if len(valid_requirements) > 5 else ''}")

        # FIXED: Try multiple approaches for calling pip
        pip_methods = [
            # Method 1: python -m pip (preferred)
            [self.python_exe, "-m", "pip", "download"],
            # Method 2: Direct pip call (fallback)
            ["pip", "download"],
        ]

        # FIXED: Use absolute paths and proper Windows handling
        requirements_path_abs = requirements_path.resolve()
        output_dir_abs = output_dir.resolve()

        # Build base arguments - CRITICAL: ensure --requirement comes last with the file path
        base_args = (
            [
                "--dest",
                str(output_dir_abs),
                "--prefer-binary",
            ]
            + self.pip_args
            + ["--requirement", str(requirements_path_abs)]
        )

        # Try each method
        for i, pip_cmd in enumerate(pip_methods, 1):
            print(f"Trying method {i}: {' '.join(pip_cmd[:3])}...")
            cmd = pip_cmd + base_args

            # Show the full command for debugging (but limit length)
            cmd_preview = " ".join(cmd[:8]) + ("..." if len(cmd) > 8 else "")
            print(f"Running: {cmd_preview}")

            try:
                # Test if pip is available first
                test_cmd = pip_cmd + ["--version"]
                test_result = subprocess.run(test_cmd, check=False, capture_output=True, text=True, timeout=10)
                if test_result.returncode != 0:
                    print(f"  Method {i} not available: {test_result.stderr.strip()}")
                    continue

                # CRITICAL FIX: Do NOT use shell=True on Windows - it breaks argument parsing
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=300)

                if result.returncode == 0:
                    print("✓ Successfully downloaded all dependencies")
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

        print("✗ All pip methods failed")
        print("Attempting fallback: download individual packages...")

        # Fallback: Try downloading packages individually
        return self._download_individual_packages(valid_requirements, output_dir_abs)

    def _download_individual_packages(self, requirements: list[str], output_dir: Path) -> bool:
        """Fallback method to download packages individually"""
        print("Attempting individual package downloads...")

        successful_downloads = 0

        for requirement in requirements:
            print(f"  Downloading: {requirement}")
            # Use the correct Python executable (embedded Python, not system Python)
            cmd = [self.python_exe, "-m", "pip", "download", "--dest", str(output_dir), "--prefer-binary"] + self.pip_args + [requirement]

            try:
                # CRITICAL FIX: Do NOT use shell=True - it breaks on Windows
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=60)
                if result.returncode == 0:
                    print(f"    ✓ {requirement}")
                    successful_downloads += 1
                else:
                    print(f"    ✗ {requirement}: {result.stderr.strip()}")
            except Exception as e:
                print(f"    ✗ {requirement}: {e}")

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
            [self.python_exe, "-m", "pip", "download"],
            ["pip", "download"],
        ]

        # FIXED: Use absolute paths for Windows compatibility
        uv_dir_abs = uv_dir.resolve()

        # ENHANCED: Add more specific package requirements for UV
        uv_packages = ["uv", "packaging>=21.3", "platformdirs>=2.5.0"]  # UV and its core dependencies

        # FIXED: Proper argument construction - packages should be separate arguments
        base_args = ["--dest", str(uv_dir_abs), "--platform", "win_amd64", "--only-binary=:all:"] + self.pip_args

        # Try each method
        for i, pip_cmd in enumerate(pip_methods, 1):
            print(f"Trying UV download method {i}: {' '.join(pip_cmd[:3])}...")
            # CRITICAL FIX: Add packages as separate arguments at the end
            cmd = pip_cmd + base_args + uv_packages

            print(f"Running: {' '.join(cmd[:6])}... {' '.join(uv_packages)}")

            try:
                # Test if pip is available first
                test_cmd = pip_cmd + ["--version"]
                test_result = subprocess.run(test_cmd, check=False, capture_output=True, text=True, timeout=10)
                if test_result.returncode != 0:
                    print(f"  UV method {i} not available: {test_result.stderr.strip()}")
                    continue

                # CRITICAL FIX: Do NOT use shell=True
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=120)
                if result.returncode == 0:
                    print("✓ Downloaded UV and dependencies")
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

        print("✗ Failed to download UV with all methods")

        # Fallback: Try downloading UV packages individually
        print("Attempting individual UV package downloads...")
        successful_uv_downloads = 0

        for package in uv_packages:
            print(f"  Downloading: {package}")
            cmd = (
                [self.python_exe, "-m", "pip", "download", "--dest", str(uv_dir_abs), "--platform", "win_amd64", "--only-binary=:all:"]
                + self.pip_args
                + [package]
            )

            try:
                # CRITICAL FIX: Do NOT use shell=True
                result = subprocess.run(cmd, check=False, capture_output=True, text=True, timeout=60)
                if result.returncode == 0:
                    print(f"    ✓ {package}")
                    successful_uv_downloads += 1
                else:
                    print(f"    ✗ {package}: {result.stderr.strip()}")
            except Exception as e:
                print(f"    ✗ {package}: {e}")

        print(f"UV individual downloads: {successful_uv_downloads}/{len(uv_packages)} successful")
        return successful_uv_downloads > 0

    def create_offline_installer(self, output_dir: Path):
        """Create offline installation script"""
        installer_script = output_dir / "install-dependencies-offline.bat"

        script_content = """@echo off
echo Installing Serena dependencies offline...
setlocal

:: Set paths
set SERENA_PORTABLE=%~dp0..
set PYTHONHOME=%SERENA_PORTABLE%\\python
set DEPENDENCIES=%~dp0
set TARGET_DIR=%SERENA_PORTABLE%\\Lib\\site-packages

:: Check if pip module is available
echo Checking pip availability...
"%PYTHONHOME%\\python.exe" -m pip --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [WARN] pip module not available, trying alternative installation...
    goto :alternative_install
)

:: Install UV first (if available)
if exist "%DEPENDENCIES%\\uv-deps" (
    echo Installing UV...
    "%PYTHONHOME%\\python.exe" -m pip install --no-index --find-links "%DEPENDENCIES%\\uv-deps" --target "%TARGET_DIR%" uv
)

:: Install main dependencies
echo Installing Serena dependencies...
"%PYTHONHOME%\\python.exe" -m pip install --no-index --find-links "%DEPENDENCIES%" --target "%TARGET_DIR%" --requirement "%DEPENDENCIES%\\requirements.txt"
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
"%PYTHONHOME%\\python.exe" -c "import serena; print('✓ Serena dependencies installed successfully')" 2>nul
if %ERRORLEVEL% neq 0 (
    echo ✗ Installation verification failed
    echo [INFO] You may need internet access for first run
    pause
    exit /b 1
)

echo.
echo ✓ All dependencies installed successfully!
echo You can now use serena-mcp-portable.bat
pause
"""

        with open(installer_script, "w") as f:
            f.write(script_content)

        print(f"✓ Created offline installer: {installer_script}")

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

        print(f"✓ Created manifest: {manifest_path}")


def main():
    parser = argparse.ArgumentParser(description="Download Python dependencies for offline deployment")
    parser.add_argument("--proxy", help="HTTP proxy URL")
    parser.add_argument("--cert", help="CA certificate bundle path")
    parser.add_argument("--output", default="dependencies", help="Output directory for wheels")
    parser.add_argument("--pyproject", default="pyproject.toml", help="Path to pyproject.toml")
    parser.add_argument("--python-version", default="3.11", help="Target Python version")
    parser.add_argument("--platform", default="win_amd64", help="Target platform")
    parser.add_argument("--python-exe", help="Path to Python executable to use for pip commands")

    args = parser.parse_args()

    # Initialize downloader with optional Python executable path
    downloader = OfflineDependencyDownloader(args.proxy, args.cert, args.python_exe)

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

        # Count downloaded files
        wheel_files = list(output_dir.glob("*.whl"))
        uv_wheels = list((output_dir / "uv-deps").glob("*.whl"))

        print("=" * 60)
        print("✓ Download completed successfully!")
        print(f"Main dependencies: {len(wheel_files)} wheels")
        print(f"UV dependencies: {len(uv_wheels)} wheels")
        print(f"Total size: {sum(f.stat().st_size for f in wheel_files + uv_wheels) / 1024 / 1024:.1f} MB")
        print(f"Output directory: {output_dir.absolute()}")
        print("\nNext steps:")
        print("1. Copy this directory to your portable package")
        print("2. Run install-dependencies-offline.bat to install offline")

        return 0

    except Exception as e:
        print(f"✗ Error: {e!s}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
