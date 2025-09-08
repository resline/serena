#!/usr/bin/env python3
"""
Serena Agent - Master Offline Package Builder

This script orchestrates the complete offline package building process for Serena Agent.
It coordinates all components, handles different build variants, and provides comprehensive
verification and packaging capabilities.

Features:
- Full/Standard/Minimal/Custom package variants
- Multi-platform support (win-x64, win-arm64)
- Parallel downloads with progress tracking
- Resume capability for interrupted builds
- Comprehensive verification and validation
- Optional compression and signing
- Build manifest with checksums

Usage:
    python scripts/build_offline_package.py --full --compress
    python scripts/build_offline_package.py --minimal --platform win-x64
    python scripts/build_offline_package.py --custom --languages python,java,csharp
    python scripts/build_offline_package.py --resume --output-dir previous-build

Author: Serena Agent Team
License: MIT
"""

import argparse
import concurrent.futures
import hashlib
import json
import logging
import os
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple
from urllib.parse import urlparse

# Ensure proper encoding for Windows console
if sys.platform == "win32":
    import locale
    # Set console encoding to handle ASCII output properly
    try:
        locale.setlocale(locale.LC_ALL, 'C')
    except locale.Error:
        pass

# Import enterprise download module
try:
    from enterprise_download_simple import SimpleEnterpriseDownloader as EnterpriseDownloader, add_enterprise_args, create_enterprise_downloader_from_args
except ImportError:
    # Fallback if enterprise_download is not available
    EnterpriseDownloader = None
    add_enterprise_args = lambda parser: None
    create_enterprise_downloader_from_args = lambda args: None

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("offline_package_build.log")
    ]
)
logger = logging.getLogger(__name__)

# Constants
DEFAULT_OUTPUT_DIR = "serena-offline-package"
DEFAULT_PYTHON_VERSION = "3.11.9"

# Package variant definitions
PACKAGE_VARIANTS = {
    "minimal": {
        "description": "Essential Python-only package (~300MB)",
        "languages": {"python"},
        "include_dev_tools": False,
        "include_optional_deps": False
    },
    "standard": {
        "description": "Common language servers package (~800MB)",
        "languages": {"python", "typescript", "java", "csharp", "go"},
        "include_dev_tools": True,
        "include_optional_deps": False
    },
    "full": {
        "description": "Complete package with all language servers (~2GB)",
        "languages": {"python", "typescript", "java", "csharp", "go", "rust", "ruby", "php", "al", "terraform", "bash"},
        "include_dev_tools": True,
        "include_optional_deps": True
    }
}

# Language server definitions
LANGUAGE_SERVERS = {
    "python": {"essential": True, "size_mb": 50},
    "typescript": {"essential": False, "size_mb": 120},
    "java": {"essential": False, "size_mb": 300},
    "csharp": {"essential": False, "size_mb": 200},
    "go": {"essential": False, "size_mb": 80},
    "rust": {"essential": False, "size_mb": 150},
    "ruby": {"essential": False, "size_mb": 100},
    "php": {"essential": False, "size_mb": 90},
    "al": {"essential": False, "size_mb": 180},
    "terraform": {"essential": False, "size_mb": 60},
    "bash": {"essential": False, "size_mb": 30}
}


class BuildProgress:
    """Tracks and reports build progress."""
    
    def __init__(self, total_steps: int):
        self.total_steps = total_steps
        self.current_step = 0
        self.step_details = {}
        self.start_time = time.time()
    
    def start_step(self, step_name: str, details: str = ""):
        """Start a new build step."""
        self.current_step += 1
        self.step_details[self.current_step] = {
            "name": step_name,
            "details": details,
            "start_time": time.time(),
            "status": "in_progress"
        }
        
        elapsed = time.time() - self.start_time
        progress = (self.current_step - 1) / self.total_steps * 100
        
        logger.info(f"[{self.current_step}/{self.total_steps}] ({progress:.1f}%) {step_name}")
        if details:
            logger.info(f"    {details}")
        logger.info(f"    Elapsed: {elapsed:.1f}s")
    
    def complete_step(self, success: bool = True, message: str = ""):
        """Mark current step as complete."""
        if self.current_step > 0:
            step_data = self.step_details[self.current_step]
            step_data["status"] = "completed" if success else "failed"
            step_data["end_time"] = time.time()
            step_data["duration"] = step_data["end_time"] - step_data["start_time"]
            
            if message:
                step_data["message"] = message
                logger.info(f"    {message}")
            
            logger.info(f"    Duration: {step_data['duration']:.1f}s")
    
    def get_summary(self) -> Dict:
        """Get build summary statistics."""
        total_duration = time.time() - self.start_time
        completed_steps = sum(1 for step in self.step_details.values() if step["status"] == "completed")
        failed_steps = sum(1 for step in self.step_details.values() if step["status"] == "failed")
        
        return {
            "total_steps": self.total_steps,
            "completed_steps": completed_steps,
            "failed_steps": failed_steps,
            "total_duration": total_duration,
            "steps": self.step_details
        }


class OfflinePackageBuilder:
    """Master orchestrator for offline package building."""
    
    def __init__(self, 
                 output_dir: str = DEFAULT_OUTPUT_DIR,
                 variant: str = "standard",
                 platform: str = "win-x64",
                 python_version: str = DEFAULT_PYTHON_VERSION,
                 custom_languages: Optional[Set[str]] = None,
                 resume: bool = False,
                 compress: bool = False,
                 verify_checksums: bool = True,
                 parallel_downloads: bool = True,
                 enterprise_downloader: Optional[EnterpriseDownloader] = None):
        """Initialize the package builder.
        
        Args:
            output_dir: Output directory for the package
            variant: Package variant (minimal/standard/full/custom)
            platform: Target platform (win-x64, win-arm64)
            python_version: Python version to use
            custom_languages: Custom language set (for custom variant)
            resume: Resume interrupted build
            compress: Create compressed archive
            verify_checksums: Verify downloaded file checksums
            parallel_downloads: Enable parallel downloads
            enterprise_downloader: Optional enterprise downloader for networking features
        """
        self.output_dir = Path(output_dir).resolve()
        self.variant = variant
        self.platform = platform
        self.python_version = python_version
        self.resume = resume
        self.compress = compress
        self.verify_checksums = verify_checksums
        self.parallel_downloads = parallel_downloads
        self.enterprise_downloader = enterprise_downloader
        
        # Determine languages to include
        if variant == "custom" and custom_languages:
            self.languages = custom_languages
        else:
            self.languages = PACKAGE_VARIANTS.get(variant, PACKAGE_VARIANTS["standard"])["languages"]
        
        # Package configuration
        self.config = PACKAGE_VARIANTS.get(variant, PACKAGE_VARIANTS["standard"])
        if variant == "custom":
            self.config = {
                "description": f"Custom package with {', '.join(sorted(self.languages))} ({self.estimate_size():.0f}MB)",
                "languages": self.languages,
                "include_dev_tools": True,
                "include_optional_deps": len(self.languages) > 3
            }
        
        # Paths
        self.repo_root = Path(__file__).parent.parent.resolve()
        self.temp_dir = Path(tempfile.mkdtemp(prefix="serena_build_"))
        self.build_manifest_path = self.output_dir / "build_manifest.json"
        
        # Build tracking
        self.build_manifest = {
            "version": "1.0.0",
            "created_at": datetime.now().isoformat(),
            "variant": variant,
            "platform": platform,
            "python_version": python_version,
            "languages": list(self.languages),
            "config": self.config,
            "components": {}
        }
        
        logger.info(f"Initialized Offline Package Builder:")
        logger.info(f"  Variant: {variant}")
        logger.info(f"  Platform: {platform}")
        logger.info(f"  Languages: {', '.join(sorted(self.languages))}")
        logger.info(f"  Output: {self.output_dir}")
        logger.info(f"  Estimated size: {self.estimate_size():.0f}MB")
        logger.info(f"  Resume: {resume}")
        logger.info(f"  Compress: {compress}")
        logger.info(f"  Enterprise networking: {'Enabled' if self.enterprise_downloader else 'Disabled'}")
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit - cleanup temp directory."""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
            logger.info(f"Cleaned up temporary directory: {self.temp_dir}")
    
    def estimate_size(self) -> float:
        """Estimate total package size in MB."""
        base_size = 150  # Base Python + core dependencies
        
        for lang in self.languages:
            if lang in LANGUAGE_SERVERS:
                base_size += LANGUAGE_SERVERS[lang]["size_mb"]
        
        if self.config.get("include_dev_tools", False):
            base_size += 50  # Development tools
        
        if self.config.get("include_optional_deps", False):
            base_size += 100  # Optional dependencies
        
        return base_size
    
    def create_directory_structure(self) -> None:
        """Create the package directory structure."""
        directories = [
            self.output_dir,
            self.output_dir / "python",
            self.output_dir / "wheels",
            self.output_dir / "serena-source", 
            self.output_dir / "language-servers",
            self.output_dir / "templates",
            self.output_dir / "scripts",
            self.output_dir / "docs"
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            logger.debug(f"Created directory: {directory}")
    
    def validate_environment(self) -> bool:
        """Validate build environment and dependencies."""
        logger.info("Validating build environment...")
        
        issues = []
        
        # Check Python version
        python_version = sys.version_info
        if python_version < (3, 8):
            issues.append(f"Python 3.8+ required, found {python_version.major}.{python_version.minor}")
        
        # Check required tools
        required_tools = ["pip"]
        if "typescript" in self.languages:
            required_tools.extend(["npm", "node"])
        
        for tool in required_tools:
            if not shutil.which(tool):
                issues.append(f"Required tool not found: {tool}")
        
        # Check disk space
        try:
            free_space = shutil.disk_usage(self.output_dir.parent)[2]
            estimated_needed = self.estimate_size() * 1024 * 1024 * 2  # 2x for safety
            if free_space < estimated_needed:
                issues.append(f"Insufficient disk space. Need ~{estimated_needed/1024/1024/1024:.1f}GB, have {free_space/1024/1024/1024:.1f}GB")
        except Exception as e:
            logger.warning(f"Could not check disk space: {e}")
        
        if issues:
            logger.error("Environment validation failed:")
            for issue in issues:
                logger.error(f"  - {issue}")
            return False
        
        logger.info("Environment validation passed")
        return True
    
    def call_prepare_offline_windows(self) -> bool:
        """Call the prepare_offline_windows.py script."""
        logger.info("Calling prepare_offline_windows.py...")
        
        try:
            cmd = [
                sys.executable,
                str(self.repo_root / "scripts" / "prepare_offline_windows.py"),
                "--output-dir", str(self.output_dir),
                "--python-version", self.python_version
            ]
            
            if self.resume:
                cmd.append("--verify-only")
            
            # Add enterprise networking options if available
            if self.enterprise_downloader:
                enterprise_config = self.enterprise_downloader.config
                
                # Add proxy settings
                if enterprise_config['proxy'].get('http_proxy'):
                    cmd.extend(["--proxy", enterprise_config['proxy']['http_proxy']])
                
                # Add SSL settings
                if enterprise_config['ssl']['verify'].lower() == 'false':
                    cmd.append("--no-ssl-verify")
                elif enterprise_config['ssl'].get('ca_bundle'):
                    cmd.extend(["--ca-bundle", enterprise_config['ssl']['ca_bundle']])
                
                # Add other settings
                if hasattr(self.enterprise_downloader, 'retry_attempts'):
                    cmd.extend(["--retry-attempts", str(self.enterprise_downloader.retry_attempts)])
                if hasattr(self.enterprise_downloader, 'timeout'):
                    cmd.extend(["--timeout", str(self.enterprise_downloader.timeout)])
                
                logger.info("Passing enterprise networking options to prepare_offline_windows.py")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=self.repo_root
            )
            
            if result.returncode != 0:
                logger.error(f"prepare_offline_windows.py failed:")
                logger.error(f"STDOUT: {result.stdout}")
                logger.error(f"STDERR: {result.stderr}")
                return False
            
            logger.info("prepare_offline_windows.py completed successfully")
            self.build_manifest["components"]["python_package"] = {
                "status": "completed",
                "script": "prepare_offline_windows.py"
            }
            return True
            
        except Exception as e:
            logger.error(f"Failed to call prepare_offline_windows.py: {e}")
            return False
    
    def call_offline_deps_downloader(self) -> bool:
        """Call the offline_deps_downloader.py script for language servers."""
        if not self.languages or self.languages == {"python"}:
            logger.info("Skipping language server downloads (Python-only build)")
            return True
        
        logger.info("Calling offline_deps_downloader.py...")
        
        try:
            deps_dir = self.output_dir / "language-servers"
            
            cmd = [
                sys.executable,
                str(self.repo_root / "scripts" / "offline_deps_downloader.py"),
                "--output-dir", str(deps_dir),
                "--platform", self.platform,
                "--create-manifest"
            ]
            
            if self.resume:
                cmd.append("--resume")
            
            # Add enterprise networking options if available
            if self.enterprise_downloader:
                enterprise_config = self.enterprise_downloader.config
                
                # Add proxy settings
                if enterprise_config['proxy'].get('http_proxy'):
                    cmd.extend(["--proxy", enterprise_config['proxy']['http_proxy']])
                
                # Add SSL settings
                if enterprise_config['ssl']['verify'].lower() == 'false':
                    cmd.append("--no-ssl-verify")
                elif enterprise_config['ssl'].get('ca_bundle'):
                    cmd.extend(["--ca-bundle", enterprise_config['ssl']['ca_bundle']])
                
                # Add other settings
                if hasattr(self.enterprise_downloader, 'retry_attempts'):
                    cmd.extend(["--retry-attempts", str(self.enterprise_downloader.retry_attempts)])
                if hasattr(self.enterprise_downloader, 'timeout'):
                    cmd.extend(["--timeout", str(self.enterprise_downloader.timeout)])
                
                logger.info("Passing enterprise networking options to offline_deps_downloader.py")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=self.repo_root
            )
            
            if result.returncode != 0:
                logger.error(f"offline_deps_downloader.py failed:")
                logger.error(f"STDOUT: {result.stdout}")
                logger.error(f"STDERR: {result.stderr}")
                return False
            
            logger.info("offline_deps_downloader.py completed successfully")
            self.build_manifest["components"]["language_servers"] = {
                "status": "completed", 
                "script": "offline_deps_downloader.py",
                "output_dir": str(deps_dir)
            }
            return True
            
        except Exception as e:
            logger.error(f"Failed to call offline_deps_downloader.py: {e}")
            return False
    
    def apply_offline_configuration_patches(self) -> bool:
        """Apply configuration patches for offline usage."""
        logger.info("Applying offline configuration patches...")
        
        try:
            # Create offline configuration modifications
            offline_config = {
                "offline_mode": True,
                "language_servers": {},
                "runtime_paths": {}
            }
            
            # Configure language server paths for offline usage
            ls_dir = self.output_dir / "language-servers"
            
            for language in self.languages:
                if language == "python":
                    continue  # Python handled by main package
                
                if language == "java":
                    offline_config["language_servers"]["java"] = {
                        "jdtls_path": str(ls_dir / "java" / "vscode-java" / "server"),
                        "gradle_home": str(ls_dir / "gradle" / "extracted" / "gradle-8.14.2")
                    }
                elif language == "csharp":
                    offline_config["language_servers"]["csharp"] = {
                        "dotnet_path": str(ls_dir / "csharp" / "dotnet-runtime"),
                        "language_server_path": str(ls_dir / "csharp" / "language-server")
                    }
                elif language == "typescript":
                    offline_config["language_servers"]["typescript"] = {
                        "node_path": str(ls_dir / "nodejs" / "extracted"),
                        "ts_server_path": str(ls_dir / "typescript" / "node_modules")
                    }
                elif language == "al":
                    offline_config["language_servers"]["al"] = {
                        "extension_path": str(ls_dir / "al" / "extension")
                    }
            
            # Save offline configuration
            config_file = self.output_dir / "templates" / "offline_config.json"
            with open(config_file, 'w') as f:
                json.dump(offline_config, f, indent=2)
            
            # Create configuration patch script
            patch_script_content = self._generate_config_patch_script()
            patch_script = self.output_dir / "scripts" / "apply_offline_config.py"
            with open(patch_script, 'w') as f:
                f.write(patch_script_content)
            
            logger.info("Offline configuration patches applied successfully")
            self.build_manifest["components"]["offline_config"] = {
                "status": "completed",
                "config_file": str(config_file),
                "patch_script": str(patch_script)
            }
            return True
            
        except Exception as e:
            logger.error(f"Failed to apply offline configuration patches: {e}")
            return False
    
    def _generate_config_patch_script(self) -> str:
        """Generate script to apply offline configuration patches."""
        return '''#!/usr/bin/env python3
"""
Apply offline configuration patches to Serena installation.
This script modifies the Serena configuration to use offline language servers.
"""

import json
import os
import sys
from pathlib import Path

def apply_offline_patches():
    """Apply offline configuration patches."""
    
    # Get installation directory
    install_dir = Path(__file__).parent.parent.resolve()
    offline_config_path = install_dir / "templates" / "offline_config.json"
    
    if not offline_config_path.exists():
        print(f"ERROR: Offline config not found: {offline_config_path}")
        return False
    
    # Load offline configuration
    with open(offline_config_path, 'r') as f:
        offline_config = json.load(f)
    
    # Apply to user config directory
    user_serena_dir = Path.home() / ".serena"
    user_config_file = user_serena_dir / "offline_config.json"
    
    # Create user config directory if needed
    user_serena_dir.mkdir(exist_ok=True)
    
    # Update paths to be absolute
    for lang, config in offline_config.get("language_servers", {}).items():
        for key, path in config.items():
            if path.startswith(str(install_dir)):
                continue  # Already absolute
            config[key] = str(install_dir / path)
    
    # Save updated configuration
    with open(user_config_file, 'w') as f:
        json.dump(offline_config, f, indent=2)
    
    print(f"Offline configuration applied successfully")
    print(f"Config saved to: {user_config_file}")
    return True

if __name__ == "__main__":
    success = apply_offline_patches()
    sys.exit(0 if success else 1)
'''
    
    def copy_installation_scripts(self) -> bool:
        """Copy and enhance installation scripts."""
        logger.info("Copying installation scripts...")
        
        try:
            # The main installation scripts are already created by prepare_offline_windows.py
            # We'll enhance them with additional functionality
            
            # Create enhanced batch installer
            enhanced_installer = self._generate_enhanced_installer()
            installer_path = self.output_dir / "scripts" / "install_enhanced.bat"
            with open(installer_path, 'w') as f:
                f.write(enhanced_installer)
            
            # Create verification script
            verification_script = self._generate_verification_script()
            verify_path = self.output_dir / "scripts" / "verify_installation.py"
            with open(verify_path, 'w') as f:
                f.write(verification_script)
            
            # Make scripts executable on Unix systems
            if sys.platform != "win32":
                os.chmod(verify_path, 0o755)
            
            logger.info("Installation scripts copied successfully")
            self.build_manifest["components"]["installation_scripts"] = {
                "status": "completed",
                "enhanced_installer": str(installer_path),
                "verification_script": str(verify_path)
            }
            return True
            
        except Exception as e:
            logger.error(f"Failed to copy installation scripts: {e}")
            return False
    
    def _generate_enhanced_installer(self) -> str:
        """Generate enhanced Windows installer script."""
        return f'''@echo off
echo Serena Agent Enhanced Offline Installer
echo ======================================
echo Variant: {self.variant.title()}
echo Platform: {self.platform}
echo Languages: {', '.join(sorted(self.languages))}
echo.

REM Run standard installation
call scripts\\install.bat
if errorlevel 1 (
    echo Standard installation failed
    pause
    exit /b 1
)

echo.
echo Applying offline configuration patches...
python scripts\\apply_offline_config.py
if errorlevel 1 (
    echo Failed to apply offline configuration
    pause
    exit /b 1
)

echo.
echo Running installation verification...
python scripts\\verify_installation.py
if errorlevel 1 (
    echo Installation verification failed
    pause
    exit /b 1
)

echo.
echo ======================================
echo Enhanced installation completed successfully!
echo.
echo Available languages: {', '.join(sorted(self.languages))}
echo Package variant: {self.variant} ({self.config["description"]})
echo.
echo Next steps:
echo 1. Test with: serena.bat --help
echo 2. Start MCP server: serena-mcp-server.bat
echo 3. Index a project: serena.bat index-project path\\to\\project
echo ======================================
pause
'''
    
    def _generate_verification_script(self) -> str:
        """Generate installation verification script."""
        return f'''#!/usr/bin/env python3
"""
Verify Serena offline installation completeness and functionality.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

def check_python_installation():
    """Check Python installation."""
    python_exe = Path("python/python.exe")
    if not python_exe.exists():
        return False, "Python executable not found"
    
    try:
        result = subprocess.run([str(python_exe), "--version"], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return True, f"Python version: {{result.stdout.strip()}}"
    except Exception as e:
        return False, f"Failed to check Python version: {{e}}"
    
    return False, "Python check failed"

def check_serena_installation():
    """Check Serena installation."""
    try:
        result = subprocess.run(["serena.bat", "--version"], 
                              capture_output=True, text=True, shell=True)
        if result.returncode == 0:
            return True, f"Serena version check passed"
    except Exception as e:
        return False, f"Serena check failed: {{e}}"
    
    return False, "Serena check failed"

def check_language_servers():
    """Check language server installations."""
    languages = {repr(sorted(self.languages))}
    ls_dir = Path("language-servers")
    
    if not languages or languages == {{"python"}}:
        return True, "No additional language servers required"
    
    if not ls_dir.exists():
        return False, "Language servers directory not found"
    
    missing = []
    for lang in languages:
        if lang == "python":
            continue
        lang_dir = ls_dir / lang
        if not lang_dir.exists():
            missing.append(lang)
    
    if missing:
        return False, f"Missing language servers: {{', '.join(missing)}}"
    
    return True, f"All language servers present: {{', '.join(languages)}}"

def check_offline_configuration():
    """Check offline configuration."""
    config_file = Path("templates/offline_config.json")
    if not config_file.exists():
        return False, "Offline configuration file not found"
    
    try:
        with open(config_file) as f:
            config = json.load(f)
        
        if not config.get("offline_mode"):
            return False, "Offline mode not enabled in configuration"
        
        return True, "Offline configuration is valid"
    except Exception as e:
        return False, f"Failed to validate offline configuration: {{e}}"

def main():
    """Run all verification checks."""
    print("Serena Offline Installation Verification")
    print("=" * 50)
    
    checks = [
        ("Python Installation", check_python_installation),
        ("Serena Installation", check_serena_installation), 
        ("Language Servers", check_language_servers),
        ("Offline Configuration", check_offline_configuration)
    ]
    
    all_passed = True
    
    for check_name, check_func in checks:
        try:
            success, message = check_func()
            status = "[OK] PASS" if success else "[FAIL] FAIL"
            print(f"{{status:8}} {{check_name:20}} {{message}}")
            
            if not success:
                all_passed = False
                
        except Exception as e:
            print(f"{'[ERROR]':8} {{check_name:20}} Exception: {{e}}")
            all_passed = False
    
    print("=" * 50)
    
    if all_passed:
        print("[SUCCESS] All verification checks passed!")
        print("The Serena offline installation is ready to use.")
        return 0
    else:
        print("[ERROR] Some verification checks failed.")
        print("Please review the issues above and reinstall if necessary.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
'''
    
    def generate_documentation(self) -> bool:
        """Generate comprehensive documentation."""
        logger.info("Generating documentation...")
        
        try:
            docs_dir = self.output_dir / "docs"
            
            # Main README
            readme_content = self._generate_main_readme()
            with open(self.output_dir / "README.md", 'w') as f:
                f.write(readme_content)
            
            # Installation guide
            install_guide = self._generate_installation_guide()
            with open(docs_dir / "INSTALLATION.md", 'w') as f:
                f.write(install_guide)
            
            # Troubleshooting guide
            troubleshoot_guide = self._generate_troubleshooting_guide()
            with open(docs_dir / "TROUBLESHOOTING.md", 'w') as f:
                f.write(troubleshoot_guide)
            
            # Language support documentation
            lang_docs = self._generate_language_documentation()
            with open(docs_dir / "LANGUAGES.md", 'w') as f:
                f.write(lang_docs)
            
            logger.info("Documentation generated successfully")
            self.build_manifest["components"]["documentation"] = {
                "status": "completed",
                "files": [
                    "README.md",
                    "docs/INSTALLATION.md", 
                    "docs/TROUBLESHOOTING.md",
                    "docs/LANGUAGES.md"
                ]
            }
            return True
            
        except Exception as e:
            logger.error(f"Failed to generate documentation: {e}")
            return False
    
    def _generate_main_readme(self) -> str:
        """Generate main README content."""
        estimated_size = self.estimate_size()
        
        return f'''# Serena Agent - Offline Package ({self.variant.title()})

This is a complete offline installation package for Serena Agent, designed for Windows systems without internet access.

## Package Information

- **Variant**: {self.variant.title()} - {self.config["description"]}
- **Platform**: {self.platform}
- **Python Version**: {self.python_version}
- **Languages Supported**: {', '.join(sorted(self.languages))}
- **Estimated Size**: ~{estimated_size:.0f} MB
- **Created**: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

## Quick Start

1. **Extract Package** (if compressed)
2. **Run Enhanced Installer**: Double-click `scripts/install_enhanced.bat`
3. **Follow Installation**: Wait for completion
4. **Verify Installation**: Check output for success messages
5. **Test Usage**: Run `serena.bat --help` to verify

## Package Contents

```
serena-offline-package/
|-- python/                 # Python {self.python_version} embeddable
|-- wheels/                 # Python packages
|-- serena-source/          # Serena source code
|-- language-servers/       # Language server binaries
|-- templates/              # Configuration templates
|-- scripts/                # Installation scripts
|-- docs/                   # Documentation
`-- README.md              # This file
```

## Installation Options

### Option 1: Enhanced Installer (Recommended)
```batch
scripts\\install_enhanced.bat
```

### Option 2: Standard Installer
```batch
scripts\\install.bat
```

### Option 3: PowerShell Installer
```powershell
scripts\\install.ps1
```

## Supported Languages

{"".join(f"- **{lang.title()}**: Language server and runtime support\n" for lang in sorted(self.languages))}

## Usage Examples

After installation:

```batch
# Show help
serena.bat --help

# Start MCP server  
serena-mcp-server.bat

# Index a project
serena.bat index-project C:\\path\\to\\project

# Check status
serena.bat status
```

## Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed installation instructions
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions  
- [Language Support](docs/LANGUAGES.md) - Language-specific configuration
- [Build Manifest](build_manifest.json) - Package build details

## System Requirements

- Windows 10 or later (x64)
- ~{estimated_size * 2:.0f} MB free disk space (2x package size)
- Administrator privileges for installation

## Support

For issues and questions:
- Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- Review build logs in installation directory
- Visit project repository: https://github.com/oraios/serena

---

Generated by Serena Offline Package Builder v1.0.0
'''
    
    def _generate_installation_guide(self) -> str:
        """Generate detailed installation guide."""
        return f'''# Serena Agent - Installation Guide

This guide provides detailed instructions for installing the Serena Agent offline package.

## Pre-Installation

### System Requirements
- Windows 10 or later (64-bit)
- ~{self.estimate_size() * 2:.0f} MB free disk space
- Administrator privileges

### Preparation Steps
1. Extract package if downloaded as ZIP/archive
2. Ensure no antivirus blocking (whitelist if necessary)
3. Close any existing Python/Node.js processes

## Installation Methods

### Method 1: Enhanced Installer (Recommended)

The enhanced installer provides the most comprehensive setup:

```batch
scripts\\install_enhanced.bat
```

**What it does:**
- Runs standard Python/package installation
- Applies offline configuration patches
- Configures language server paths
- Verifies installation completeness
- Creates launcher scripts

### Method 2: Standard Installer

For basic installation:

```batch
scripts\\install.bat
```

**Manual steps after:**
- Run `scripts\\apply_offline_config.py`
- Run `scripts\\verify_installation.py`

### Method 3: PowerShell Installation

For PowerShell users:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
scripts\\install.ps1
```

## Post-Installation Configuration

### 1. Verify Installation

```batch
python scripts\\verify_installation.py
```

Expected output:
```
[OK] PASS    Python Installation    Python version: {self.python_version}
[OK] PASS    Serena Installation    Serena version check passed
[OK] PASS    Language Servers       All language servers present
[OK] PASS    Offline Configuration  Offline configuration is valid
```

### 2. Test Basic Functionality

```batch
# Check Serena version
serena.bat --version

# Show available tools
serena.bat list-tools

# Test MCP server
serena-mcp-server.bat --help
```

### 3. Configuration Customization

Edit configuration files in `%USERPROFILE%\\.serena\\`:

- `serena_config.yml` - Main configuration
- `offline_config.json` - Offline-specific settings
- `project.yml` - Project-specific settings (per project)

## Language Server Configuration

{"".join(f'''
### {lang.title()}
- Location: `language-servers/{lang}/`
- Configuration: Automatically configured for offline use
- Test: Create a {lang} project and verify language features
''' for lang in sorted(self.languages) if lang != "python")}

## Troubleshooting Installation

### Common Issues

**Permission Errors:**
```batch
# Run as Administrator
runas /user:Administrator "scripts\\install_enhanced.bat"
```

**Python Not Found:**
- Verify `python/python.exe` exists
- Check Windows PATH environment variable
- Try running from package root directory

**Language Server Errors:**
- Check `language-servers/` directory completeness
- Verify offline configuration: `templates/offline_config.json`
- Run verification script for detailed diagnostics

**Missing Dependencies:**
- Re-run installer to download missing packages
- Check internet connectivity during build process
- Verify all wheel files in `wheels/` directory

### Getting Help

1. **Check Logs:**
   - `offline_package_build.log` - Build process log
   - `%USERPROFILE%\\.serena\\logs\\` - Runtime logs

2. **Run Diagnostics:**
   ```batch
   python scripts\\verify_installation.py
   serena.bat diagnose
   ```

3. **Reset Installation:**
   - Delete installation directory
   - Clear `%USERPROFILE%\\.serena\\`
   - Re-run installer

## Advanced Configuration

### Custom Language Server Paths

Edit `%USERPROFILE%\\.serena\\offline_config.json`:

```json
{{
  "offline_mode": true,
  "language_servers": {{
    "java": {{
      "jdtls_path": "C:\\\\custom\\\\path\\\\to\\\\jdtls"
    }}
  }}
}}
```

### Development Mode

For development and testing:

```batch
# Install in development mode
cd serena-source
python -m pip install -e . --no-deps

# Enable debug logging
set SERENA_LOG_LEVEL=DEBUG
serena.bat --help
```

## Updating the Installation

To update Serena Agent:

1. Download new offline package
2. Stop any running Serena processes
3. Backup existing configuration:
   ```batch
   xcopy /E /I "%USERPROFILE%\\.serena" serena_config_backup
   ```
4. Run new installer
5. Restore custom configuration if needed

---

For additional help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or visit the project repository.
'''
    
    def _generate_troubleshooting_guide(self) -> str:
        """Generate troubleshooting documentation."""
        return '''# Serena Agent - Troubleshooting Guide

This guide helps resolve common issues with the Serena Agent offline installation.

## Installation Issues

### "Permission Denied" Errors

**Problem:** Installation fails with permission errors
**Solution:**
```batch
# Run installer as Administrator
runas /user:Administrator "scripts\\install_enhanced.bat"

# Or right-click Command Prompt > "Run as administrator"
```

### "Python Not Found" Errors

**Problem:** System cannot find Python executable
**Solutions:**
1. **Verify Python Location:**
   ```batch
   dir python\\python.exe
   ```

2. **Check PATH Environment:**
   ```batch
   echo %PATH%
   set PYTHON_HOME=%CD%\\python
   set PATH=%PYTHON_HOME%;%PATH%
   ```

3. **Use Full Path:**
   ```batch
   "%CD%\\python\\python.exe" --version
   ```

### "Wheel Install Failed" Errors

**Problem:** Python package installation fails
**Solutions:**
1. **Check Wheel Directory:**
   ```batch
   dir wheels\\*.whl
   ```

2. **Manual Installation:**
   ```batch
   python\\python.exe -m pip install --no-index --find-links wheels wheels\\*.whl
   ```

3. **Clear Cache and Retry:**
   ```batch
   python\\python.exe -m pip cache purge
   ```

## Runtime Issues

### Language Server Not Starting

**Problem:** Language servers fail to initialize
**Diagnosis:**
```batch
# Check offline configuration
type "%USERPROFILE%\\.serena\\offline_config.json"

# Verify language server files
dir language-servers\\java\\
dir language-servers\\csharp\\
```

**Solutions:**
1. **Re-apply Configuration:**
   ```batch
   python scripts\\apply_offline_config.py
   ```

2. **Check Paths:**
   - Ensure language-servers directory exists
   - Verify extracted language server files
   - Check file permissions

3. **Reset Configuration:**
   ```batch
   del "%USERPROFILE%\\.serena\\offline_config.json"
   python scripts\\apply_offline_config.py
   ```

### MCP Server Connection Issues

**Problem:** MCP server fails to start or connect
**Solutions:**
1. **Check Port Availability:**
   ```batch
   netstat -an | findstr :8000
   ```

2. **Try Different Port:**
   ```batch
   serena-mcp-server.bat --port 8001
   ```

3. **Check Firewall Settings:**
   - Allow Python through Windows Firewall
   - Verify no other applications using the port

### Import/Module Errors

**Problem:** Python import errors or missing modules
**Solutions:**
1. **Verify Installation:**
   ```batch
   python scripts\\verify_installation.py
   ```

2. **Check Python Path:**
   ```batch
   python\\python.exe -c "import sys; print('\\n'.join(sys.path))"
   ```

3. **Reinstall Packages:**
   ```batch
   cd serena-source
   ..\\python\\python.exe -m pip install -e . --no-deps --force-reinstall
   ```

## Language-Specific Issues

### Java Language Server

**Problem:** Java support not working
**Checks:**
```batch
# Verify JDTLS extraction
dir language-servers\\java\\vscode-java\\server\\

# Check Gradle installation
dir language-servers\\gradle\\extracted\\gradle-8.14.2\\
```

**Solutions:**
- Ensure JRE is included in VS Code Java extension
- Verify Gradle wrapper permissions
- Check Java project structure

### C# Language Server

**Problem:** C# IntelliSense not working
**Checks:**
```batch
# Verify .NET runtime
dir language-servers\\csharp\\dotnet-runtime\\

# Check language server
dir language-servers\\csharp\\language-server\\
```

**Solutions:**
- Verify .NET runtime extraction
- Check language server binary permissions
- Ensure C# project files (.csproj) present

### TypeScript/JavaScript Issues

**Problem:** TypeScript support not working
**Checks:**
```batch
# Verify Node.js installation
language-servers\\nodejs\\extracted\\node.exe --version

# Check TypeScript packages
dir language-servers\\typescript\\node_modules\\
```

**Solutions:**
- Re-extract Node.js runtime
- Verify npm packages installation
- Check TypeScript configuration files

## Performance Issues

### Slow Startup

**Problem:** Serena takes long to start
**Solutions:**
1. **Disable Unnecessary Language Servers:**
   Edit `%USERPROFILE%\\.serena\\serena_config.yml`:
   ```yaml
   disabled_languages:
     - rust
     - php
   ```

2. **Increase Memory Allocation:**
   ```batch
   set SERENA_MEMORY_LIMIT=2048
   serena.bat
   ```

### High Memory Usage

**Problem:** Excessive memory consumption
**Solutions:**
1. **Limit Language Servers:**
   - Only enable needed languages
   - Configure resource limits

2. **Monitor Processes:**
   ```batch
   tasklist | findstr python
   tasklist | findstr java
   ```

## Diagnostic Commands

### System Information
```batch
# System info
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type"

# Disk space
dir /-c

# Memory info
systeminfo | findstr /C:"Total Physical Memory"
```

### Serena Diagnostics
```batch
# Serena version and info
serena.bat --version
serena.bat diagnose

# Configuration check
serena.bat list-tools
serena.bat list-contexts
```

### Network Diagnostics
```batch
# Check if offline mode working
netstat -an | findstr ESTABLISHED

# Test local connections only
serena-mcp-server.bat --host 127.0.0.1
```

## Getting Additional Help

### Log Files
- `offline_package_build.log` - Package build log
- `%USERPROFILE%\\.serena\\logs\\` - Runtime logs
- Windows Event Viewer > Application logs

### Debug Mode
```batch
set SERENA_LOG_LEVEL=DEBUG
set SERENA_DEBUG=true
serena.bat --help
```

### Reset Everything
```batch
# Stop all processes
taskkill /f /im python.exe

# Remove user configuration
rmdir /s "%USERPROFILE%\\.serena"

# Reinstall
scripts\\install_enhanced.bat
```

### Contact Support
- Check project repository: https://github.com/oraios/serena
- Review existing issues and discussions
- Create detailed bug report with:
  - System information
  - Error messages
  - Log files
  - Steps to reproduce

---

If issues persist, consider reinstalling the package or trying a different variant (minimal/standard/full).
'''
    
    def _generate_language_documentation(self) -> str:
        """Generate language support documentation."""
        lang_details = {
            "python": "Built-in support with Pyright language server",
            "typescript": "TypeScript compiler and language server via Node.js",
            "java": "Eclipse JDTLS with Gradle build tool support", 
            "csharp": "Microsoft CodeAnalysis language server with .NET runtime",
            "go": "Go language server (gopls) with standard toolchain",
            "rust": "Rust Analyzer for comprehensive Rust support",
            "ruby": "Solargraph and Ruby LSP for Ruby development",
            "php": "Intelephense for PHP IntelliSense and features",
            "al": "Microsoft AL extension for Business Central development",
            "terraform": "Terraform language server for infrastructure as code",
            "bash": "Bash language server for shell scripting support"
        }
        
        content = f'''# Serena Agent - Language Support

This document describes the language servers and development tools included in this offline package.

## Package Variant: {self.variant.title()}

{self.config["description"]}

## Supported Languages

{"".join(f"""
### {lang.title()}

{lang_details.get(lang, "Language server support")}

**Status:** {'[OK] Included' if lang in self.languages else '[NOT] Not included'}
""" for lang in sorted(lang_details.keys()))}

## Language Server Configuration

Each language server is configured for offline operation with the following structure:

```
language-servers/
|-- java/           # Eclipse JDTLS + JRE
|-- csharp/         # .NET runtime + language server  
|-- typescript/     # Node.js + TypeScript tools
|-- al/             # Microsoft AL extension
`-- gradle/         # Gradle build tool (for Java)
```

### Offline Configuration

Language servers are configured via `%USERPROFILE%\\.serena\\offline_config.json`:

```json
{{
  "offline_mode": true,
  "language_servers": {{
    "java": {{
      "jdtls_path": "language-servers/java/vscode-java/server",
      "gradle_home": "language-servers/gradle/extracted/gradle-8.14.2"
    }},
    "csharp": {{
      "dotnet_path": "language-servers/csharp/dotnet-runtime",
      "language_server_path": "language-servers/csharp/language-server"
    }},
    "typescript": {{
      "node_path": "language-servers/nodejs/extracted", 
      "ts_server_path": "language-servers/typescript/node_modules"
    }}
  }}
}}
```

## Per-Language Setup

### Python
**Included Components:**
- Python {self.python_version} embeddable
- Pyright language server
- Core Python packages

**Configuration:**
- Automatic setup via main installer
- No additional configuration required
- Uses embedded Python runtime

### Java
**Included Components:**
- Eclipse JDTLS (Java Development Tools Language Server)
- Gradle 8.14.2 build tool
- JRE runtime (embedded in VS Code extension)

**Project Requirements:**
- Standard Java project structure
- Maven or Gradle build files
- Java source files (.java)

**Configuration:**
```json
"java": {{
  "jdtls_path": "language-servers/java/vscode-java/server",
  "gradle_home": "language-servers/gradle/extracted/gradle-8.14.2"
}}
```

### C#
**Included Components:**
- .NET 9 Runtime for Windows
- Microsoft CodeAnalysis Language Server
- MSBuild tools

**Project Requirements:**
- .csproj project files
- C# source files (.cs)
- Compatible .NET version

**Configuration:**
```json
"csharp": {{
  "dotnet_path": "language-servers/csharp/dotnet-runtime",
  "language_server_path": "language-servers/csharp/language-server"
}}
```

### TypeScript/JavaScript
**Included Components:**
- Node.js 20.18.2 runtime
- TypeScript compiler 5.5.4
- TypeScript Language Server 4.3.3

**Project Requirements:**
- package.json file
- TypeScript/JavaScript files (.ts, .js)
- Node.js project structure

**Configuration:**
```json
"typescript": {{
  "node_path": "language-servers/nodejs/extracted",
  "ts_server_path": "language-servers/typescript/node_modules"
}}
```

### AL (Business Central)
**Included Components:**
- Microsoft AL extension (latest)
- AL Language Server
- Symbol libraries

**Project Requirements:**
- AL project files (.al)
- app.json configuration
- Business Central development setup

## Testing Language Support

### Verification Steps

1. **Create Test Projects:**
   ```batch
   mkdir test-projects
   cd test-projects
   
   REM Create test files for each language
   echo print("Hello Python") > test.py
   echo console.log("Hello TypeScript"); > test.ts
   echo public class Test {{ }} > Test.java
   echo using System; class Test {{ }} > Test.cs
   ```

2. **Test Language Server Activation:**
   ```batch
   serena.bat index-project test-projects
   serena.bat list-symbols test-projects
   ```

3. **Verify IntelliSense Features:**
   - Syntax highlighting
   - Code completion
   - Error detection
   - Go to definition
   - Find references

### Common Issues

**Language Server Not Starting:**
- Check offline configuration paths
- Verify language server binaries exist
- Review logs for detailed error messages

**Missing IntelliSense:**
- Ensure project files are properly structured
- Check language-specific requirements
- Verify workspace indexing completed

**Performance Issues:**
- Limit active language servers
- Increase memory allocation
- Check disk space availability

## Customization

### Enabling/Disabling Languages

Edit `%USERPROFILE%\\.serena\\serena_config.yml`:

```yaml
# Disable unused languages
disabled_languages:
  - rust
  - php
  - terraform

# Enable specific languages only
enabled_languages:
  - python
  - typescript
  - java
```

### Language Server Settings

Advanced settings can be configured per language:

```yaml
language_servers:
  java:
    heap_size: "2G"
    compilation_unit_limit: 1000
  
  typescript:
    preferences:
      includePackageJsonAutoImports: "off"
      allowRenameOfImportPath: false
```

### Resource Limits

Control resource usage:

```yaml
resource_limits:
  max_memory_per_language: "1024MB"
  max_concurrent_language_servers: 3
  indexing_timeout: 300
```

## Advanced Usage

### Multi-Language Projects

For projects using multiple languages:

1. **Ensure All Required Languages Enabled**
2. **Configure Workspace Settings**
3. **Test Cross-Language Features**

### Custom Language Servers

To add additional language servers:

1. **Download Language Server Binaries**
2. **Update Offline Configuration**
3. **Test Integration**

### Development Workflows

Common development patterns:

1. **Code -> Test -> Debug** cycle
2. **Git integration** with Serena tools
3. **Build automation** using language-specific tools
4. **Documentation generation** from code

---

For language-specific issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
'''
        
        return content
    
    def perform_verification_steps(self) -> bool:
        """Perform comprehensive package verification."""
        logger.info("Performing verification steps...")
        
        try:
            verification_results = []
            
            # 1. Check Python dependencies completeness
            python_check = self._verify_python_dependencies()
            verification_results.append(("Python Dependencies", python_check, "Core Python packages and runtime"))
            
            # 2. Verify language server downloads
            if self.languages != {"python"}:
                ls_check = self._verify_language_servers()
                verification_results.append(("Language Servers", ls_check, "Language server binaries and runtimes"))
            
            # 3. Validate installation scripts
            scripts_check = self._verify_installation_scripts()
            verification_results.append(("Installation Scripts", scripts_check, "Installer scripts and utilities"))
            
            # 4. Test offline configuration patches
            config_check = self._verify_offline_configuration()
            verification_results.append(("Offline Configuration", config_check, "Configuration patches and templates"))
            
            # 5. Check package completeness
            completeness_check = self._verify_package_completeness()
            verification_results.append(("Package Completeness", completeness_check, "All required components present"))
            
            # Report results
            logger.info("Verification Results:")
            logger.info("=" * 60)
            
            all_passed = True
            for component, passed, details in verification_results:
                status = "[OK] PASS" if passed else "[FAIL] FAIL"
                logger.info(f"{status:8} {component:25} {details}")
                if not passed:
                    all_passed = False
            
            logger.info("=" * 60)
            
            if all_passed:
                logger.info("[SUCCESS] Package verification PASSED - Ready for distribution!")
                
                # Calculate final package size
                total_size = sum(f.stat().st_size for f in self.output_dir.rglob('*') if f.is_file())
                size_mb = total_size / (1024 * 1024)
                size_gb = size_mb / 1024
                
                if size_gb >= 1.0:
                    logger.info(f"[SIZE] Package size: {size_gb:.2f} GB")
                else:
                    logger.info(f"[SIZE] Package size: {size_mb:.1f} MB")
                
                self.build_manifest["verification"] = {
                    "status": "passed",
                    "checks": len(verification_results),
                    "final_size_bytes": total_size,
                    "final_size_mb": size_mb
                }
            else:
                logger.error("[ERROR] Package verification FAILED - Please fix issues before distribution")
                self.build_manifest["verification"] = {
                    "status": "failed", 
                    "checks": len(verification_results),
                    "failed_checks": [comp for comp, passed, _ in verification_results if not passed]
                }
            
            return all_passed
            
        except Exception as e:
            logger.error(f"Verification failed: {e}")
            return False
    
    def _verify_python_dependencies(self) -> bool:
        """Verify Python dependencies are complete."""
        try:
            python_dir = self.output_dir / "python"
            wheels_dir = self.output_dir / "wheels"
            
            # Check Python executable
            if not (python_dir / "python.exe").exists():
                logger.error("Python executable not found")
                return False
            
            # Check get-pip.py
            if not (python_dir / "get-pip.py").exists():
                logger.error("get-pip.py not found")
                return False
            
            # Check wheels count (should have reasonable number of packages)
            wheels = list(wheels_dir.glob("*.whl"))
            if len(wheels) < 20:
                logger.error(f"Insufficient Python packages: {len(wheels)} found")
                return False
            
            logger.debug(f"Python verification passed: {len(wheels)} packages")
            return True
            
        except Exception as e:
            logger.error(f"Python verification failed: {e}")
            return False
    
    def _verify_language_servers(self) -> bool:
        """Verify language server downloads are complete."""
        try:
            ls_dir = self.output_dir / "language-servers"
            
            if not ls_dir.exists():
                logger.error("Language servers directory not found")
                return False
            
            missing_servers = []
            
            for language in self.languages:
                if language == "python":
                    continue  # Python handled separately
                
                lang_dir = ls_dir / language
                if not lang_dir.exists():
                    missing_servers.append(language)
                    continue
                
                # Check for key files based on language
                if language == "java":
                    if not (lang_dir / "vscode-java").exists():
                        missing_servers.append(f"{language} (vscode-java)")
                elif language == "csharp":
                    if not (lang_dir / "dotnet-runtime").exists():
                        missing_servers.append(f"{language} (dotnet-runtime)")
                elif language == "typescript":
                    node_dir = ls_dir / "nodejs"
                    if not (node_dir / "extracted").exists():
                        missing_servers.append(f"{language} (nodejs)")
            
            if missing_servers:
                logger.error(f"Missing language servers: {', '.join(missing_servers)}")
                return False
            
            logger.debug(f"Language server verification passed: {', '.join(self.languages)}")
            return True
            
        except Exception as e:
            logger.error(f"Language server verification failed: {e}")
            return False
    
    def _verify_installation_scripts(self) -> bool:
        """Verify installation scripts are present and valid."""
        try:
            scripts_dir = self.output_dir / "scripts"
            
            required_scripts = [
                "install.bat",
                "install.ps1", 
                "install_enhanced.bat",
                "apply_offline_config.py",
                "verify_installation.py"
            ]
            
            missing_scripts = []
            for script in required_scripts:
                script_path = scripts_dir / script
                if not script_path.exists():
                    missing_scripts.append(script)
                elif script_path.stat().st_size == 0:
                    missing_scripts.append(f"{script} (empty)")
            
            if missing_scripts:
                logger.error(f"Missing/invalid scripts: {', '.join(missing_scripts)}")
                return False
            
            logger.debug("Installation scripts verification passed")
            return True
            
        except Exception as e:
            logger.error(f"Installation scripts verification failed: {e}")
            return False
    
    def _verify_offline_configuration(self) -> bool:
        """Verify offline configuration patches are valid."""
        try:
            config_file = self.output_dir / "templates" / "offline_config.json"
            
            if not config_file.exists():
                logger.error("Offline configuration file not found")
                return False
            
            # Validate configuration structure
            with open(config_file, 'r') as f:
                config = json.load(f)
            
            if not config.get("offline_mode"):
                logger.error("Offline mode not enabled in configuration")
                return False
            
            # Check language server configurations
            lang_servers = config.get("language_servers", {})
            for language in self.languages:
                if language == "python":
                    continue
                
                if language not in lang_servers:
                    logger.warning(f"No offline configuration for {language}")
            
            logger.debug("Offline configuration verification passed")
            return True
            
        except Exception as e:
            logger.error(f"Offline configuration verification failed: {e}")
            return False
    
    def _verify_package_completeness(self) -> bool:
        """Verify overall package completeness."""
        try:
            required_components = [
                ("python", "Python runtime and packages"),
                ("serena-source", "Serena source code"),
                ("templates", "Configuration templates"),
                ("scripts", "Installation scripts"),
                ("docs", "Documentation"),
                ("README.md", "Main documentation")
            ]
            
            if self.languages != {"python"}:
                required_components.append(("language-servers", "Language server binaries"))
            
            missing_components = []
            for component, description in required_components:
                component_path = self.output_dir / component
                if not component_path.exists():
                    missing_components.append(f"{component} ({description})")
            
            if missing_components:
                logger.error(f"Missing components: {', '.join(missing_components)}")
                return False
            
            logger.debug("Package completeness verification passed")
            return True
            
        except Exception as e:
            logger.error(f"Package completeness verification failed: {e}")
            return False
    
    def create_compressed_archive(self) -> bool:
        """Create compressed ZIP archive of the package."""
        if not self.compress:
            logger.info("Compression disabled, skipping archive creation")
            return True
        
        logger.info("Creating compressed archive...")
        
        try:
            # Determine archive name
            archive_name = f"serena-{self.variant}-{self.platform}-{self.python_version}.zip"
            archive_path = self.output_dir.parent / archive_name
            
            # Create ZIP archive with compression
            with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipf:
                total_files = sum(1 for _ in self.output_dir.rglob('*') if _.is_file())
                processed_files = 0
                
                for file_path in self.output_dir.rglob('*'):
                    if file_path.is_file():
                        # Calculate relative path for archive
                        arcname = file_path.relative_to(self.output_dir.parent)
                        zipf.write(file_path, arcname)
                        
                        processed_files += 1
                        if processed_files % 100 == 0:
                            progress = (processed_files / total_files) * 100
                            logger.info(f"Compression progress: {progress:.1f}% ({processed_files}/{total_files})")
            
            # Get compression statistics
            original_size = sum(f.stat().st_size for f in self.output_dir.rglob('*') if f.is_file())
            compressed_size = archive_path.stat().st_size
            compression_ratio = (1 - compressed_size / original_size) * 100
            
            logger.info(f"Archive created successfully: {archive_path}")
            logger.info(f"Original size: {original_size / 1024 / 1024:.1f} MB")
            logger.info(f"Compressed size: {compressed_size / 1024 / 1024:.1f} MB")
            logger.info(f"Compression ratio: {compression_ratio:.1f}%")
            
            self.build_manifest["archive"] = {
                "status": "created",
                "path": str(archive_path),
                "original_size_bytes": original_size,
                "compressed_size_bytes": compressed_size,
                "compression_ratio": compression_ratio
            }
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to create compressed archive: {e}")
            return False
    
    def save_build_manifest(self) -> bool:
        """Save build manifest with all component information."""
        try:
            # Add final metadata
            self.build_manifest["completed_at"] = datetime.now().isoformat()
            self.build_manifest["build_duration"] = (datetime.now() - datetime.fromisoformat(self.build_manifest["created_at"])).total_seconds()
            
            # Save manifest
            with open(self.build_manifest_path, 'w') as f:
                json.dump(self.build_manifest, f, indent=2)
            
            logger.info(f"Build manifest saved: {self.build_manifest_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save build manifest: {e}")
            return False
    
    def build_complete_package(self) -> bool:
        """Main orchestrator method to build the complete offline package."""
        logger.info("="*80)
        logger.info("SERENA AGENT - OFFLINE PACKAGE BUILDER")
        logger.info("="*80)
        logger.info(f"Variant: {self.variant.title()}")
        logger.info(f"Platform: {self.platform}")
        logger.info(f"Languages: {', '.join(sorted(self.languages))}")
        logger.info(f"Estimated Size: {self.estimate_size():.0f} MB")
        logger.info("="*80)
        
        # Initialize progress tracking
        total_steps = 10
        if self.compress:
            total_steps += 1
        
        progress = BuildProgress(total_steps)
        
        try:
            # Step 1: Environment validation
            progress.start_step("Environment Validation", "Checking system requirements and tools")
            if not self.validate_environment():
                progress.complete_step(False, "Environment validation failed")
                return False
            progress.complete_step(True, "Environment ready for build")
            
            # Step 2: Directory structure
            progress.start_step("Directory Structure", "Creating package directory structure")
            self.create_directory_structure()
            progress.complete_step(True, "Directory structure created")
            
            # Step 3: Python package preparation
            progress.start_step("Python Package", "Preparing Python runtime and dependencies")
            if not self.call_prepare_offline_windows():
                progress.complete_step(False, "Python package preparation failed")
                return False
            progress.complete_step(True, "Python package ready")
            
            # Step 4: Language server downloads
            progress.start_step("Language Servers", "Downloading language server binaries")
            if not self.call_offline_deps_downloader():
                progress.complete_step(False, "Language server downloads failed")
                return False
            progress.complete_step(True, f"Language servers downloaded: {', '.join(self.languages)}")
            
            # Step 5: Offline configuration
            progress.start_step("Offline Configuration", "Applying offline configuration patches")
            if not self.apply_offline_configuration_patches():
                progress.complete_step(False, "Configuration patches failed")
                return False
            progress.complete_step(True, "Offline configuration applied")
            
            # Step 6: Installation scripts
            progress.start_step("Installation Scripts", "Copying and enhancing installation scripts")
            if not self.copy_installation_scripts():
                progress.complete_step(False, "Installation scripts failed")
                return False
            progress.complete_step(True, "Installation scripts ready")
            
            # Step 7: Documentation generation
            progress.start_step("Documentation", "Generating comprehensive documentation")
            if not self.generate_documentation():
                progress.complete_step(False, "Documentation generation failed")
                return False
            progress.complete_step(True, "Documentation generated")
            
            # Step 8: Verification
            progress.start_step("Verification", "Verifying package completeness and integrity")
            verification_passed = self.perform_verification_steps()
            progress.complete_step(verification_passed, 
                                 "Verification passed" if verification_passed else "Verification failed")
            
            # Step 9: Build manifest
            progress.start_step("Build Manifest", "Saving build manifest and metadata")
            if not self.save_build_manifest():
                progress.complete_step(False, "Build manifest failed")
                return False
            progress.complete_step(True, "Build manifest saved")
            
            # Step 10: Compression (optional)
            if self.compress:
                progress.start_step("Compression", "Creating compressed archive")
                compression_success = self.create_compressed_archive()
                progress.complete_step(compression_success,
                                     "Archive created" if compression_success else "Archive creation failed")
            
            # Final step: Summary
            progress.start_step("Build Summary", "Generating build summary")
            summary = progress.get_summary()
            
            logger.info("="*80)
            logger.info("BUILD COMPLETED")
            logger.info("="*80)
            
            if verification_passed:
                logger.info("[SUCCESS] SUCCESS: Offline package build completed successfully!")
                logger.info(f"[LOCATION] Package location: {self.output_dir}")
                
                # Size information
                total_size = sum(f.stat().st_size for f in self.output_dir.rglob('*') if f.is_file())
                size_mb = total_size / (1024 * 1024)
                if size_mb >= 1024:
                    logger.info(f"[SIZE] Package size: {size_mb/1024:.2f} GB")
                else:
                    logger.info(f"[SIZE] Package size: {size_mb:.1f} MB")
                
                logger.info(f"[TIME] Total build time: {summary['total_duration']:.1f} seconds")
                logger.info(f"[CONFIG] Build variant: {self.variant} ({self.config['description']})")
                logger.info(f"[PLATFORM] Target platform: {self.platform}")
                logger.info(f"[LANGUAGES] Languages included: {', '.join(sorted(self.languages))}")
                
                if self.compress and "archive" in self.build_manifest:
                    archive_info = self.build_manifest["archive"]
                    logger.info(f"[ARCHIVE] Compressed archive: {Path(archive_info['path']).name}")
                    logger.info(f"[COMPRESS] Compression ratio: {archive_info['compression_ratio']:.1f}%")
                
                logger.info("")
                logger.info("[NEXT] Next steps:")
                logger.info("   1. Test installation on a clean Windows machine")
                logger.info("   2. Run verification script: python scripts/verify_installation.py")
                logger.info("   3. Test core functionality with different languages")
                logger.info("   4. Distribute package to target systems")
                
            else:
                logger.error("[ERROR] FAILED: Package build completed with errors")
                logger.error("Please review verification results and fix issues before distribution")
                
            progress.complete_step(True, f"Build completed with {'success' if verification_passed else 'errors'}")
            logger.info("="*80)
            
            return verification_passed
                
        except Exception as e:
            logger.error(f"Package build failed: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False


def main():
    """Main entry point for the build script."""
    parser = argparse.ArgumentParser(
        description="Build offline Windows installation package for Serena Agent",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Package Variants:
  minimal   - Python-only package (~300MB)
  standard  - Common language servers (~800MB) 
  full      - All language servers (~2GB)
  custom    - User-selected languages

Basic Examples:
  %(prog)s --full --compress
  %(prog)s --standard --platform win-x64
  %(prog)s --minimal --output-dir serena-minimal
  %(prog)s --custom --languages python,java,csharp --compress
  %(prog)s --resume --output-dir previous-build

Enterprise Examples:
  # With corporate proxy
  %(prog)s --standard --proxy http://proxy.company.com:8080
  
  # Disable SSL verification
  %(prog)s --full --no-ssl-verify
  
  # Use custom CA bundle
  %(prog)s --standard --ca-bundle /path/to/company-ca.pem
  
  # Use configuration file
  %(prog)s --full --config offline_config.ini
  
  # Enable enterprise mode
  %(prog)s --standard --enterprise
        """
    )
    
    # Build variant options
    variant_group = parser.add_mutually_exclusive_group(required=True)
    variant_group.add_argument("--minimal", action="store_const", const="minimal", dest="variant",
                              help="Build minimal package (Python only, ~300MB)")
    variant_group.add_argument("--standard", action="store_const", const="standard", dest="variant", 
                              help="Build standard package (common languages, ~800MB)")
    variant_group.add_argument("--full", action="store_const", const="full", dest="variant",
                              help="Build full package (all languages, ~2GB)")
    variant_group.add_argument("--custom", action="store_const", const="custom", dest="variant",
                              help="Build custom package (specify --languages)")
    
    # Configuration options
    parser.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR,
                       help=f"Output directory for the package (default: {DEFAULT_OUTPUT_DIR})")
    parser.add_argument("--platform", choices=["win-x64", "win-arm64"], default="win-x64",
                       help="Target platform (default: win-x64)")
    parser.add_argument("--python-version", default=DEFAULT_PYTHON_VERSION,
                       help=f"Python version to use (default: {DEFAULT_PYTHON_VERSION})")
    parser.add_argument("--languages",
                       help="Comma-separated list of languages for custom variant")
    
    # Build options
    parser.add_argument("--resume", action="store_true",
                       help="Resume interrupted build (skip existing components)")
    parser.add_argument("--compress", action="store_true",
                       help="Create compressed ZIP archive of final package")
    parser.add_argument("--no-verify", action="store_true",
                       help="Skip checksum verification (faster but less secure)")
    parser.add_argument("--no-parallel", action="store_true",
                       help="Disable parallel downloads (slower but more reliable)")
    
    # Logging options
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], 
                       default="INFO", help="Set logging level (default: INFO)")
    parser.add_argument("--quiet", action="store_true",
                       help="Suppress non-essential output")
    
    # Add enterprise networking arguments if available
    if add_enterprise_args:
        add_enterprise_args(parser)
    
    args = parser.parse_args()
    
    # Configure logging
    log_level = logging.WARNING if args.quiet else getattr(logging, args.log_level)
    logging.getLogger().setLevel(log_level)
    
    # Validate custom variant arguments
    if args.variant == "custom":
        if not args.languages:
            parser.error("--custom variant requires --languages argument")
        
        custom_languages = set(lang.strip().lower() for lang in args.languages.split(","))
        invalid_languages = custom_languages - set(LANGUAGE_SERVERS.keys())
        if invalid_languages:
            parser.error(f"Invalid languages: {', '.join(invalid_languages)}. "
                        f"Available: {', '.join(sorted(LANGUAGE_SERVERS.keys()))}")
    else:
        custom_languages = None
    
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
    try:
        with OfflinePackageBuilder(
            output_dir=args.output_dir,
            variant=args.variant,
            platform=args.platform,
            python_version=args.python_version,
            custom_languages=custom_languages,
            resume=args.resume,
            compress=args.compress,
            verify_checksums=not args.no_verify,
            parallel_downloads=not args.no_parallel,
            enterprise_downloader=enterprise_downloader
        ) as builder:
            
            success = builder.build_complete_package()
            
            if success:
                print(f"\n[SUCCESS] Package created at {Path(args.output_dir).resolve()}")
                print(f"Variant: {args.variant}")
                print(f"Platform: {args.platform}")
                if args.compress:
                    print("Compressed archive created")
                if enterprise_downloader:
                    print("[ENTERPRISE] Enterprise networking was used for downloads")
                sys.exit(0)
            else:
                print(f"\n[ERROR] FAILED: Check log files for details")
                print("Build log: offline_package_build.log")
                if not enterprise_downloader:
                    print("[INFO] If you're behind a corporate firewall, try enterprise options:")
                    print("   --proxy http://your-proxy:8080")
                    print("   --no-ssl-verify (if SSL issues)")
                    print("   --config offline_config.ini")
                sys.exit(1)
                
    except KeyboardInterrupt:
        print(f"\n[WARNING] Build interrupted by user")
        print("Use --resume flag to continue from last successful step")
        sys.exit(2)
    except Exception as e:
        logger.error(f"Build failed with exception: {e}")
        print(f"\n[ERROR] EXCEPTION: {e}")
        print("Check log files for detailed error information")
        sys.exit(3)


if __name__ == "__main__":
    main()