#!/usr/bin/env python3
"""
Offline Windows Package Builder for Serena Agent

This script creates a complete offline installation package for Windows users.
It downloads Python embeddable, all required wheels, and creates installation scripts.

Usage:
    python scripts/prepare_offline_windows.py [--verify-only] [--output-dir DIR] [--python-version VERSION]

Options:
    --verify-only       Only verify existing package, don't download
    --output-dir        Output directory (default: serena-offline-windows)
    --python-version    Python version (default: 3.11.9)

Author: Serena Agent Team
License: MIT
"""

import json
import logging
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from urllib.parse import urlparse
from urllib.request import urlretrieve

# Import enterprise download module
try:
    from enterprise_download_simple import SimpleEnterpriseDownloader as EnterpriseDownloader, add_enterprise_args, create_enterprise_downloader_from_args
except ImportError:
    # Fallback if enterprise_download is not available
    EnterpriseDownloader = None
    add_enterprise_args = lambda parser: None
    create_enterprise_downloader_from_args = lambda args: None

# Conditional imports - some may not be available in all environments
try:
    import requests
except ImportError:
    requests = None

try:
    import toml
except ImportError:
    toml = None

# Constants
DEFAULT_PYTHON_VERSION = "3.11.9"
DEFAULT_OUTPUT_DIR = "serena-offline-windows"
PYTHON_EMBEDDABLE_URL_TEMPLATE = "https://www.python.org/ftp/python/{version}/python-{version}-embed-amd64.zip"
GET_PIP_URL = "https://bootstrap.pypa.io/get-pip.py"

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("offline_package_builder.log")
    ]
)
logger = logging.getLogger(__name__)


class DownloadProgress:
    """Simple progress tracker for downloads."""
    
    def __init__(self, description: str):
        self.description = description
        self.downloaded = 0
        self.total = 0
    
    def __call__(self, chunk_num: int, chunk_size: int, total_size: int):
        if total_size > 0:
            self.total = total_size
            self.downloaded = chunk_num * chunk_size
            percent = min(100, (self.downloaded / self.total) * 100)
            print(f"\r{self.description}: {percent:.1f}% ({self.downloaded}/{self.total} bytes)", end="", flush=True)
        else:
            self.downloaded += chunk_size
            print(f"\r{self.description}: {self.downloaded} bytes downloaded", end="", flush=True)


class OfflinePackageBuilder:
    """Main class for building offline Windows packages."""
    
    def __init__(self, 
                 output_dir: str = DEFAULT_OUTPUT_DIR,
                 python_version: str = DEFAULT_PYTHON_VERSION,
                 verify_only: bool = False,
                 enterprise_downloader: Optional[EnterpriseDownloader] = None):
        """Initialize the package builder.
        
        Args:
            output_dir: Directory to create the package in
            python_version: Python version to use (e.g., "3.11.9")
            verify_only: If True, only verify existing package
            enterprise_downloader: Optional enterprise downloader for networking features
        """
        self.output_dir = Path(output_dir).resolve()
        self.python_version = python_version
        self.verify_only = verify_only
        self.enterprise_downloader = enterprise_downloader
        self.repo_root = Path(__file__).parent.parent.resolve()
        
        # Package structure paths
        self.python_dir = self.output_dir / "python"
        self.wheels_dir = self.output_dir / "wheels"
        self.source_dir = self.output_dir / "serena-source"
        self.templates_dir = self.output_dir / "templates"
        self.scripts_dir = self.output_dir / "scripts"
        
        # Temporary directory for intermediate files
        self.temp_dir = Path(tempfile.mkdtemp(prefix="serena_offline_"))
        
        logger.info(f"Initialized OfflinePackageBuilder:")
        logger.info(f"  Output directory: {self.output_dir}")
        logger.info(f"  Python version: {self.python_version}")
        logger.info(f"  Verify only: {self.verify_only}")
        logger.info(f"  Enterprise networking: {'Enabled' if self.enterprise_downloader else 'Disabled'}")
        logger.info(f"  Repository root: {self.repo_root}")
        logger.info(f"  Temporary directory: {self.temp_dir}")
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - cleanup temp directory."""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
            logger.info(f"Cleaned up temporary directory: {self.temp_dir}")
    
    def create_directory_structure(self) -> None:
        """Create the base directory structure for the offline package."""
        logger.info("Creating directory structure...")
        
        directories = [
            self.output_dir,
            self.python_dir,
            self.wheels_dir,
            self.source_dir,
            self.templates_dir,
            self.scripts_dir,
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.debug(f"Created directory: {directory}")
        
        logger.info("Directory structure created successfully")
    
    def download_python_embeddable(self) -> None:
        """Download Python embeddable package for Windows."""
        if self.verify_only:
            logger.info("Skipping Python download (verify-only mode)")
            return
            
        logger.info(f"Downloading Python {self.python_version} embeddable for Windows x64...")
        
        url = PYTHON_EMBEDDABLE_URL_TEMPLATE.format(version=self.python_version)
        zip_path = self.temp_dir / f"python-{self.python_version}-embed-amd64.zip"
        
        try:
            # Check if Python is already downloaded
            python_exe = self.python_dir / "python.exe"
            if python_exe.exists():
                logger.info("Python embeddable already exists, skipping download")
                return
            
            logger.info(f"Downloading from: {url}")
            
            # Use enterprise downloader if available
            if self.enterprise_downloader:
                success = self.enterprise_downloader.download_with_progress(
                    url, zip_path
                )
                if not success:
                    raise RuntimeError(f"Failed to download Python embeddable: {url}")
            else:
                # Fallback to standard download
                progress = DownloadProgress(f"Python {self.python_version}")
                urlretrieve(url, zip_path, reporthook=progress)
                print()  # New line after progress
            
            # Extract Python embeddable
            logger.info("Extracting Python embeddable...")
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(self.python_dir)
            
            # Verify extraction
            if not python_exe.exists():
                raise RuntimeError("Python executable not found after extraction")
            
            logger.info("Python embeddable downloaded and extracted successfully")
            
        except Exception as e:
            logger.error(f"Failed to download Python embeddable: {e}")
            raise
    
    def download_get_pip(self) -> None:
        """Download get-pip.py script."""
        if self.verify_only:
            logger.info("Skipping get-pip.py download (verify-only mode)")
            return
            
        logger.info("Downloading get-pip.py...")
        
        get_pip_path = self.python_dir / "get-pip.py"
        
        try:
            if get_pip_path.exists():
                logger.info("get-pip.py already exists, skipping download")
                return
            
            # Use enterprise downloader if available
            if self.enterprise_downloader:
                success = self.enterprise_downloader.download_with_progress(
                    GET_PIP_URL, get_pip_path
                )
                if not success:
                    raise RuntimeError(f"Failed to download get-pip.py: {GET_PIP_URL}")
            else:
                # Fallback to standard download
                progress = DownloadProgress("get-pip.py")
                urlretrieve(GET_PIP_URL, get_pip_path, reporthook=progress)
                print()  # New line after progress
            
            logger.info("get-pip.py downloaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to download get-pip.py: {e}")
            raise
    
    def generate_requirements_txt(self) -> Path:
        """Generate requirements.txt from pyproject.toml."""
        logger.info("Generating requirements.txt from pyproject.toml...")
        
        requirements_path = self.temp_dir / "requirements.txt"
        
        try:
            # Read pyproject.toml
            if toml is None:
                raise ImportError("toml package not available")
            
            pyproject_path = self.repo_root / "pyproject.toml"
            if not pyproject_path.exists():
                raise FileNotFoundError(f"pyproject.toml not found at {pyproject_path}")
            
            with open(pyproject_path, 'r') as f:
                pyproject_data = toml.load(f)
            
            # Extract dependencies
            dependencies = pyproject_data.get("project", {}).get("dependencies", [])
            optional_deps = pyproject_data.get("project", {}).get("optional-dependencies", {})
            
            # Collect all dependencies
            all_deps = set(dependencies)
            
            # Add optional dependencies (dev, agno, google)
            for group_name in ["dev", "agno", "google"]:
                if group_name in optional_deps:
                    all_deps.update(optional_deps[group_name])
            
            # Write requirements.txt
            with open(requirements_path, 'w') as f:
                for dep in sorted(all_deps):
                    f.write(f"{dep}\n")
            
            logger.info(f"Generated requirements.txt with {len(all_deps)} dependencies")
            return requirements_path
            
        except ImportError:
            logger.warning("toml package not available, using fallback method")
            return self._generate_requirements_fallback()
        except Exception as e:
            logger.error(f"Failed to generate requirements.txt: {e}")
            raise
    
    def _generate_requirements_fallback(self) -> Path:
        """Fallback method to generate requirements using pip-tools or manual parsing."""
        requirements_path = self.temp_dir / "requirements.txt"
        
        # Try using pip-tools if available
        try:
            result = subprocess.run([
                sys.executable, "-m", "pip", "install", "pip-tools"
            ], capture_output=True, text=True, check=False)
            
            if result.returncode == 0:
                # Use pip-compile to generate requirements
                result = subprocess.run([
                    sys.executable, "-m", "piptools", "compile",
                    str(self.repo_root / "pyproject.toml"),
                    "--output-file", str(requirements_path),
                    "--extra", "dev",
                    "--extra", "agno", 
                    "--extra", "google"
                ], capture_output=True, text=True, cwd=self.repo_root)
                
                if result.returncode == 0:
                    logger.info("Generated requirements.txt using pip-tools")
                    return requirements_path
        except Exception as e:
            logger.debug(f"pip-tools approach failed: {e}")
        
        # Manual fallback - parse pyproject.toml manually
        logger.info("Using manual parsing fallback for requirements.txt")
        
        # Basic dependency list (this should be updated if dependencies change)
        basic_deps = [
            "requests>=2.32.3,<3",
            "pyright>=1.1.396,<2", 
            "overrides>=7.7.0,<8",
            "python-dotenv>=1.0.0,<2",
            "mcp==1.12.3",
            "flask>=3.0.0",
            "sensai-utils>=1.5.0",
            "pydantic>=2.10.6",
            "types-pyyaml>=6.0.12.20241230",
            "pyyaml>=6.0.2",
            "ruamel.yaml>=0.18.0",
            "jinja2>=3.1.6",
            "dotenv>=0.9.9",
            "pathspec>=0.12.1",
            "psutil>=7.0.0",
            "docstring_parser>=0.16",
            "joblib>=1.5.1",
            "tqdm>=4.67.1",
            "tiktoken>=0.9.0",
            "anthropic>=0.54.0",
            # Dev dependencies
            "black[jupyter]>=23.7.0",
            "mypy>=1.16.1",
            "poethepoet>=0.20.0",
            "pytest>=8.0.2",
            "pytest-xdist>=3.5.0",
            "ruff>=0.0.285",
            "toml-sort>=0.24.2",
            "syrupy>=4.9.1",
            "types-requests>=2.32.4.20241230",
            # Optional dependencies
            "agno>=1.2.6",
            "sqlalchemy>=2.0.40",
            "google-genai>=1.8.0"
        ]
        
        with open(requirements_path, 'w') as f:
            for dep in basic_deps:
                f.write(f"{dep}\n")
        
        logger.info(f"Generated fallback requirements.txt with {len(basic_deps)} dependencies")
        return requirements_path
    
    def download_python_wheels(self) -> None:
        """Download all Python wheels using pip download."""
        if self.verify_only:
            logger.info("Skipping wheel downloads (verify-only mode)")
            return
            
        logger.info("Downloading Python wheels...")
        
        try:
            # Generate requirements.txt
            requirements_path = self.generate_requirements_txt()
            
            # Check if wheels already exist
            existing_wheels = list(self.wheels_dir.glob("*.whl"))
            if existing_wheels and len(existing_wheels) > 20:  # Reasonable threshold
                logger.info(f"Found {len(existing_wheels)} existing wheels, skipping download")
                return
            
            # Download wheels using pip
            logger.info("Running pip download...")
            
            pip_cmd = [
                sys.executable, "-m", "pip", "download",
                "--requirement", str(requirements_path),
                "--dest", str(self.wheels_dir),
                "--only-binary=:all:",
                "--platform", "win_amd64",
                "--python-version", "3.11",
                "--abi", "cp311",
                "--implementation", "cp"
            ]
            
            # Add enterprise networking options
            pip_env = os.environ.copy()
            if self.enterprise_downloader:
                # Get enterprise environment variables
                enterprise_env = self.enterprise_downloader.get_environment_config()
                pip_env.update(enterprise_env)
                
                # Add enterprise pip arguments
                enterprise_pip_args = self.enterprise_downloader.get_pip_args()
                pip_cmd.extend(enterprise_pip_args)
                
                logger.info("Using enterprise networking for pip downloads")
            
            result = subprocess.run(
                pip_cmd,
                capture_output=True, 
                text=True, 
                cwd=self.temp_dir,
                env=pip_env
            )
            
            if result.returncode != 0:
                logger.warning("pip download with binary-only failed, trying with source packages...")
                
                # Retry without --only-binary constraint
                pip_cmd_retry = [
                    sys.executable, "-m", "pip", "download",
                    "--requirement", str(requirements_path),
                    "--dest", str(self.wheels_dir),
                    "--platform", "win_amd64",
                    "--python-version", "3.11"
                ]
                
                # Add enterprise networking options to retry
                if self.enterprise_downloader:
                    enterprise_pip_args = self.enterprise_downloader.get_pip_args()
                    pip_cmd_retry.extend(enterprise_pip_args)
                
                result = subprocess.run(
                    pip_cmd_retry,
                    capture_output=True,
                    text=True,
                    cwd=self.temp_dir,
                    env=pip_env
                )
            
            if result.returncode != 0:
                logger.error("pip download failed:")
                logger.error(f"STDOUT: {result.stdout}")
                logger.error(f"STDERR: {result.stderr}")
                
                # Provide helpful troubleshooting information
                if "proxy" in result.stderr.lower():
                    logger.error("\nProxy-related error detected. Try:")
                    logger.error("  --proxy http://your-proxy:8080")
                elif "ssl" in result.stderr.lower() or "certificate" in result.stderr.lower():
                    logger.error("\nSSL/Certificate error detected. Try:")
                    logger.error("  --no-ssl-verify (not recommended for production)")
                    logger.error("  --ca-bundle /path/to/your/ca-bundle.pem")
                elif "timeout" in result.stderr.lower():
                    logger.error("\nTimeout error detected. Try:")
                    logger.error("  --timeout 600 (increase timeout)")
                
                raise RuntimeError("Failed to download Python wheels")
            
            # Count downloaded packages
            wheels = list(self.wheels_dir.glob("*.whl"))
            tarballs = list(self.wheels_dir.glob("*.tar.gz"))
            total_packages = len(wheels) + len(tarballs)
            
            logger.info(f"Downloaded {total_packages} packages ({len(wheels)} wheels, {len(tarballs)} source packages)")
            
        except Exception as e:
            logger.error(f"Failed to download Python wheels: {e}")
            raise
    
    def copy_source_code(self) -> None:
        """Copy the entire Serena source code to the package."""
        logger.info("Copying source code...")
        
        try:
            # Check if source already exists
            if (self.source_dir / "src").exists():
                logger.info("Source code already exists, skipping copy")
                return
            
            # Directories to copy
            source_dirs = ["src", "scripts", "resources"]
            source_files = ["pyproject.toml", "README.md", "LICENSE", "CHANGELOG.md"]
            
            # Copy directories
            for dir_name in source_dirs:
                src_path = self.repo_root / dir_name
                dst_path = self.source_dir / dir_name
                if src_path.exists():
                    if dst_path.exists():
                        shutil.rmtree(dst_path)
                    shutil.copytree(src_path, dst_path)
                    logger.debug(f"Copied directory: {dir_name}")
            
            # Copy files
            for file_name in source_files:
                src_path = self.repo_root / file_name
                dst_path = self.source_dir / file_name
                if src_path.exists():
                    shutil.copy2(src_path, dst_path)
                    logger.debug(f"Copied file: {file_name}")
            
            logger.info("Source code copied successfully")
            
        except Exception as e:
            logger.error(f"Failed to copy source code: {e}")
            raise
    
    def prepare_config_templates(self) -> None:
        """Prepare configuration templates."""
        logger.info("Preparing configuration templates...")
        
        try:
            # Copy .serena directory if it exists
            serena_config_src = self.repo_root / ".serena"
            serena_config_dst = self.templates_dir / "serena-config"
            
            if serena_config_src.exists():
                if serena_config_dst.exists():
                    shutil.rmtree(serena_config_dst)
                shutil.copytree(serena_config_src, serena_config_dst)
                logger.debug("Copied .serena configuration directory")
            
            # Create sample configuration files
            sample_config_content = """# Serena Agent Configuration
# Copy this file to ~/.serena/serena_config.yml and customize as needed

# Default context and mode
default_context: desktop-app
default_mode: interactive

# Logging configuration
logging:
  level: INFO
  file: serena.log

# Tool configurations
tools:
  memory:
    enabled: true
    max_memories: 1000
  
  symbol:
    enabled: true
    cache_timeout: 300
"""
            
            with open(self.templates_dir / "sample_config.yml", 'w') as f:
                f.write(sample_config_content)
            
            # Create .env template
            env_template_content = """# Serena Agent Environment Variables
# Copy this file to your project root as .env and customize as needed

# API Keys (uncomment and set as needed)
# ANTHROPIC_API_KEY=your_anthropic_api_key_here
# OPENAI_API_KEY=your_openai_api_key_here

# Logging
LOG_LEVEL=INFO

# Server configuration
MCP_SERVER_PORT=8000
"""
            
            with open(self.templates_dir / "env_template", 'w') as f:
                f.write(env_template_content)
            
            logger.info("Configuration templates prepared successfully")
            
        except Exception as e:
            logger.error(f"Failed to prepare configuration templates: {e}")
            raise
    
    def generate_installation_scripts(self) -> None:
        """Generate installation scripts for Windows."""
        logger.info("Generating installation scripts...")
        
        try:
            # Generate install.bat
            bat_script = f"""@echo off
echo Installing Serena Agent for Windows (Offline)
echo =============================================

REM Check if Python directory exists
if not exist "python\\python.exe" (
    echo ERROR: Python executable not found in python\\python.exe
    echo Please ensure the offline package is complete.
    pause
    exit /b 1
)

REM Set up Python path
set PYTHON_HOME=%~dp0python
set PATH=%PYTHON_HOME%;%PYTHON_HOME%\\Scripts;%PATH%

echo Step 1: Setting up pip...
"%PYTHON_HOME%\\python.exe" get-pip.py --no-index --find-links wheels
if errorlevel 1 (
    echo ERROR: Failed to install pip
    pause
    exit /b 1
)

echo Step 2: Installing Serena dependencies...
"%PYTHON_HOME%\\python.exe" -m pip install --no-index --find-links wheels --find-links . wheels\\*.whl
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo Step 3: Installing Serena from source...
cd serena-source
"%PYTHON_HOME%\\python.exe" -m pip install -e . --no-deps
if errorlevel 1 (
    echo ERROR: Failed to install Serena
    pause
    exit /b 1
)
cd ..

echo Step 4: Setting up configuration...
if not exist "%USERPROFILE%\\.serena" (
    mkdir "%USERPROFILE%\\.serena"
    xcopy /E /I /Y templates\\serena-config "%USERPROFILE%\\.serena"
    echo Configuration templates copied to %USERPROFILE%\\.serena
)

echo Step 5: Creating launcher scripts...
echo @echo off > serena.bat
echo set PYTHON_HOME=%~dp0python >> serena.bat
echo set PATH=%PYTHON_HOME%;%PYTHON_HOME%\\Scripts;%PATH% >> serena.bat
echo "%PYTHON_HOME%\\python.exe" -m serena.cli %%* >> serena.bat

echo @echo off > serena-mcp-server.bat
echo set PYTHON_HOME=%~dp0python >> serena-mcp-server.bat
echo set PATH=%PYTHON_HOME%;%PYTHON_HOME%\\Scripts;%PATH% >> serena-mcp-server.bat
echo "%PYTHON_HOME%\\python.exe" -m serena.cli:start_mcp_server %%* >> serena-mcp-server.bat

echo.
echo =============================================
echo Installation completed successfully!
echo.
echo Usage:
echo   .\\serena.bat --help           - Show Serena help
echo   .\\serena-mcp-server.bat       - Start MCP server
echo.
echo Configuration files are in: %USERPROFILE%\\.serena
echo Copy templates\\env_template to your project as .env if needed.
echo =============================================
pause
"""
            
            with open(self.scripts_dir / "install.bat", 'w') as f:
                f.write(bat_script)
            
            # Generate install.ps1
            ps1_script = f"""# Serena Agent Windows Installation Script (Offline)
# PowerShell version

Write-Host "Installing Serena Agent for Windows (Offline)" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check if Python directory exists
if (-not (Test-Path "python\\python.exe")) {{
    Write-Host "ERROR: Python executable not found in python\\python.exe" -ForegroundColor Red
    Write-Host "Please ensure the offline package is complete." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}}

# Set up Python path
$pythonHome = Join-Path $PSScriptRoot "python"
$env:PYTHON_HOME = $pythonHome
$env:PATH = "$pythonHome;$pythonHome\\Scripts;$env:PATH"

try {{
    Write-Host "Step 1: Setting up pip..." -ForegroundColor Yellow
    & "$pythonHome\\python.exe" "python\\get-pip.py" --no-index --find-links wheels
    if ($LASTEXITCODE -ne 0) {{ throw "Failed to install pip" }}

    Write-Host "Step 2: Installing Serena dependencies..." -ForegroundColor Yellow
    & "$pythonHome\\python.exe" -m pip install --no-index --find-links wheels --find-links . wheels\\*.whl
    if ($LASTEXITCODE -ne 0) {{ throw "Failed to install dependencies" }}

    Write-Host "Step 3: Installing Serena from source..." -ForegroundColor Yellow
    Push-Location "serena-source"
    & "$pythonHome\\python.exe" -m pip install -e . --no-deps
    if ($LASTEXITCODE -ne 0) {{ throw "Failed to install Serena" }}
    Pop-Location

    Write-Host "Step 4: Setting up configuration..." -ForegroundColor Yellow
    $userSerenaDir = Join-Path $env:USERPROFILE ".serena"
    if (-not (Test-Path $userSerenaDir)) {{
        New-Item -ItemType Directory -Path $userSerenaDir -Force | Out-Null
        Copy-Item -Path "templates\\serena-config\\*" -Destination $userSerenaDir -Recurse -Force
        Write-Host "Configuration templates copied to $userSerenaDir" -ForegroundColor Green
    }}

    Write-Host "Step 5: Creating launcher scripts..." -ForegroundColor Yellow
    
    # Create serena.bat
    @"
@echo off
set PYTHON_HOME=%~dp0python
set PATH=%PYTHON_HOME%;%PYTHON_HOME%\\Scripts;%PATH%
"%PYTHON_HOME%\\python.exe" -m serena.cli %*
"@ | Out-File -FilePath "serena.bat" -Encoding ASCII
    
    # Create serena-mcp-server.bat
    @"
@echo off
set PYTHON_HOME=%~dp0python
set PATH=%PYTHON_HOME%;%PYTHON_HOME%\\Scripts;%PATH%
"%PYTHON_HOME%\\python.exe" -m serena.cli:start_mcp_server %*
"@ | Out-File -FilePath "serena-mcp-server.bat" -Encoding ASCII

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\\serena.bat --help           - Show Serena help" -ForegroundColor White
    Write-Host "  .\\serena-mcp-server.bat       - Start MCP server" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration files are in: $userSerenaDir" -ForegroundColor Cyan
    Write-Host "Copy templates\\env_template to your project as .env if needed." -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Green

}} catch {{
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}}

Read-Host "Press Enter to continue"
"""
            
            with open(self.scripts_dir / "install.ps1", 'w') as f:
                f.write(ps1_script)
            
            # Generate README for the package
            readme_content = f"""# Serena Agent - Offline Windows Installation Package

This package contains everything needed to install Serena Agent on Windows without an internet connection.

## Contents

- `python/` - Python {self.python_version} embeddable distribution
- `wheels/` - All required Python packages
- `serena-source/` - Serena Agent source code
- `templates/` - Configuration templates
- `scripts/` - Installation scripts

## Installation

### Option 1: Batch Script (Recommended)
1. Double-click `scripts/install.bat`
2. Wait for installation to complete
3. Use `serena.bat` to run Serena commands

### Option 2: PowerShell Script
1. Right-click `scripts/install.ps1` and "Run with PowerShell"
2. If execution policy prevents running, first run:
   ```
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Wait for installation to complete
4. Use `serena.bat` to run Serena commands

## Usage

After installation:

```bash
# Show help
.\\serena.bat --help

# Start MCP server
.\\serena-mcp-server.bat

# Index a project
.\\serena.bat index-project /path/to/project
```

## Configuration

Configuration files are installed to `%USERPROFILE%\\.serena\\`

To customize:
1. Edit `%USERPROFILE%\\.serena\\serena_config.yml`
2. Copy `templates\\env_template` to your project root as `.env`

## Troubleshooting

1. **Permission errors**: Run installation as Administrator
2. **Python not found**: Ensure the `python/` directory is intact
3. **Import errors**: Verify all wheels were downloaded correctly

## Package Information

- Python Version: {self.python_version}
- Package Format: Offline installer
- Target Platform: Windows x64
- Generated: {logger.handlers[0].formatter.formatTime if logger.handlers else 'Unknown'}

For more information, visit: https://github.com/oraios/serena
"""
            
            with open(self.output_dir / "README.md", 'w') as f:
                f.write(readme_content)
            
            logger.info("Installation scripts generated successfully")
            
        except Exception as e:
            logger.error(f"Failed to generate installation scripts: {e}")
            raise
    
    def verify_package(self) -> bool:
        """Verify that the package is complete and functional."""
        logger.info("Verifying package completeness...")
        
        verification_results = []
        
        # Check Python embeddable
        python_exe = self.python_dir / "python.exe"
        if python_exe.exists():
            verification_results.append(("Python executable", True, str(python_exe)))
        else:
            verification_results.append(("Python executable", False, f"Missing: {python_exe}"))
        
        # Check get-pip.py
        get_pip = self.python_dir / "get-pip.py"
        if get_pip.exists():
            verification_results.append(("get-pip.py", True, str(get_pip)))
        else:
            verification_results.append(("get-pip.py", False, f"Missing: {get_pip}"))
        
        # Check wheels directory
        wheels = list(self.wheels_dir.glob("*.whl"))
        tarballs = list(self.wheels_dir.glob("*.tar.gz"))
        total_packages = len(wheels) + len(tarballs)
        
        if total_packages > 20:  # Reasonable minimum
            verification_results.append(("Python packages", True, f"{total_packages} packages ({len(wheels)} wheels)"))
        else:
            verification_results.append(("Python packages", False, f"Only {total_packages} packages found"))
        
        # Check source code
        src_dir = self.source_dir / "src"
        pyproject = self.source_dir / "pyproject.toml"
        
        if src_dir.exists() and pyproject.exists():
            verification_results.append(("Source code", True, f"src/ and pyproject.toml present"))
        else:
            verification_results.append(("Source code", False, f"Missing src/ or pyproject.toml"))
        
        # Check installation scripts
        install_bat = self.scripts_dir / "install.bat"
        install_ps1 = self.scripts_dir / "install.ps1"
        
        if install_bat.exists() and install_ps1.exists():
            verification_results.append(("Installation scripts", True, "install.bat and install.ps1 present"))
        else:
            verification_results.append(("Installation scripts", False, "Missing installation scripts"))
        
        # Check templates
        templates_exist = len(list(self.templates_dir.glob("*"))) > 0
        if templates_exist:
            verification_results.append(("Configuration templates", True, f"{len(list(self.templates_dir.glob('*')))} templates"))
        else:
            verification_results.append(("Configuration templates", False, "No templates found"))
        
        # Report results
        logger.info("Verification Results:")
        logger.info("=" * 50)
        
        all_passed = True
        for component, passed, details in verification_results:
            status = "✓ PASS" if passed else "✗ FAIL"
            logger.info(f"{status:8} {component:25} {details}")
            if not passed:
                all_passed = False
        
        logger.info("=" * 50)
        
        if all_passed:
            logger.info("🎉 Package verification PASSED - Ready for distribution!")
            
            # Calculate package size
            total_size = sum(f.stat().st_size for f in self.output_dir.rglob('*') if f.is_file())
            size_mb = total_size / (1024 * 1024)
            logger.info(f"📦 Package size: {size_mb:.1f} MB")
            
        else:
            logger.error("❌ Package verification FAILED - Please fix issues before distribution")
        
        return all_passed
    
    def build_package(self) -> bool:
        """Main orchestrator method to build the complete package."""
        logger.info("Starting offline package build process...")
        
        try:
            # Step 1: Create directory structure
            self.create_directory_structure()
            
            # Step 2: Download Python embeddable
            self.download_python_embeddable()
            
            # Step 3: Download get-pip.py
            self.download_get_pip()
            
            # Step 4: Download Python wheels
            self.download_python_wheels()
            
            # Step 5: Copy source code
            self.copy_source_code()
            
            # Step 6: Prepare configuration templates
            self.prepare_config_templates()
            
            # Step 7: Generate installation scripts
            self.generate_installation_scripts()
            
            # Step 8: Verify package
            verification_passed = self.verify_package()
            
            if verification_passed:
                logger.info("🎉 Offline package build completed successfully!")
                logger.info(f"📁 Package location: {self.output_dir}")
                logger.info("📋 Next steps:")
                logger.info("   1. Test installation on a clean Windows machine")
                logger.info("   2. Create ZIP archive for distribution")
                logger.info("   3. Update documentation with installation instructions")
                return True
            else:
                logger.error("❌ Package build completed with errors - please review verification results")
                return False
                
        except Exception as e:
            logger.error(f"Package build failed: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False


def main():
    """Main entry point for the script."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Build offline Windows installation package for Serena Agent",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Basic Examples:
  python scripts/prepare_offline_windows.py
  python scripts/prepare_offline_windows.py --output-dir my-package
  python scripts/prepare_offline_windows.py --verify-only
  python scripts/prepare_offline_windows.py --python-version 3.11.9

Enterprise Examples:
  # With corporate proxy
  python scripts/prepare_offline_windows.py --proxy http://proxy.company.com:8080
  
  # Disable SSL verification (not recommended)
  python scripts/prepare_offline_windows.py --no-ssl-verify
  
  # Use custom CA bundle
  python scripts/prepare_offline_windows.py --ca-bundle /path/to/company-ca.pem
  
  # Use configuration file
  python scripts/prepare_offline_windows.py --config offline_config.ini
  
  # Enable enterprise mode with auto-detection
  python scripts/prepare_offline_windows.py --enterprise

For detailed enterprise configuration, see offline_config.ini.template
        """
    )
    
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Output directory for the package (default: {DEFAULT_OUTPUT_DIR})"
    )
    
    parser.add_argument(
        "--python-version",
        default=DEFAULT_PYTHON_VERSION,
        help=f"Python version to use (default: {DEFAULT_PYTHON_VERSION})"
    )
    
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Only verify existing package, don't download new files"
    )
    
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Set logging level (default: INFO)"
    )
    
    # Add enterprise networking arguments if available
    if add_enterprise_args:
        add_enterprise_args(parser)
    
    args = parser.parse_args()
    
    # Set log level
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    # Create enterprise downloader if available
    enterprise_downloader = None
    if EnterpriseDownloader:
        try:
            enterprise_downloader = create_enterprise_downloader_from_args(args)
            logger.info("Enterprise networking features enabled")
        except Exception as e:
            logger.warning(f"Failed to initialize enterprise downloader: {e}")
            logger.warning("Falling back to standard networking")
    
    # Build package
    with OfflinePackageBuilder(
        output_dir=args.output_dir,
        python_version=args.python_version,
        verify_only=args.verify_only,
        enterprise_downloader=enterprise_downloader
    ) as builder:
        success = builder.build_package()
        
        if success:
            print(f"\n✅ Success! Package created at: {Path(args.output_dir).resolve()}")
            if enterprise_downloader:
                print("🏢 Enterprise networking was used for downloads")
            sys.exit(0)
        else:
            print(f"\n❌ Failed! Check the log file for details.")
            if not enterprise_downloader:
                print("💡 If you're behind a corporate firewall, try enterprise options:")
                print("   --proxy http://your-proxy:8080")
                print("   --no-ssl-verify (if SSL issues)")
                print("   --config offline_config.ini")
            sys.exit(1)


if __name__ == "__main__":
    main()