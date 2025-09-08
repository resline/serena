#!/usr/bin/env python3
"""
BUILD_OFFLINE_WINDOWS.py - Master script to build complete offline Serena package for Windows

This is the main entry point for building the offline portable version of Serena MCP for Windows.
It orchestrates all the scripts created for offline package preparation.

Usage:
    python BUILD_OFFLINE_WINDOWS.py                  # Build full package
    python BUILD_OFFLINE_WINDOWS.py --minimal        # Build minimal package
    python BUILD_OFFLINE_WINDOWS.py --help           # Show help
"""

import os
import sys
import argparse
import subprocess
import logging
import time
from pathlib import Path
from datetime import datetime
import shutil
import json

# Ensure proper encoding for Windows console
if sys.platform == "win32":
    import locale
    # Set console encoding to handle ASCII output properly
    try:
        locale.setlocale(locale.LC_ALL, 'C')
    except locale.Error:
        pass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('build_offline_windows.log')
    ]
)
logger = logging.getLogger(__name__)

class OfflinePackageBuilder:
    """Master builder for Serena offline package"""
    
    def __init__(self):
        self.root_dir = Path(__file__).parent
        self.scripts_dir = self.root_dir / "scripts"
        self.build_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.output_dir = self.root_dir / f"serena-offline-windows-{self.build_timestamp}"
        
    def print_banner(self):
        """Print build banner"""
        banner = """
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     SERENA OFFLINE PACKAGE BUILDER FOR WINDOWS                      ║
║     Building Complete Portable Offline Version                      ║
║                                                                      ║
║     Version: 1.0.0                                                  ║
║     Target: Windows 10/11 (x64/ARM64)                              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
        """
        print(banner)
        
    def check_prerequisites(self):
        """Check if all required scripts exist"""
        logger.info("Checking prerequisites...")
        
        required_scripts = [
            self.scripts_dir / "prepare_offline_windows.py",
            self.scripts_dir / "offline_deps_downloader.py",
            self.scripts_dir / "offline_config.py",
            self.scripts_dir / "build_offline_package.py"
        ]
        
        missing = []
        for script in required_scripts:
            if not script.exists():
                missing.append(script.name)
                
        if missing:
            logger.error(f"Missing required scripts: {', '.join(missing)}")
            logger.error("Please ensure all scripts have been created first.")
            return False
            
        logger.info("[OK] All required scripts found")
        return True
        
    def run_command(self, cmd, description):
        """Run a command with logging"""
        logger.info(f"Running: {description}")
        logger.debug(f"Command: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True
            )
            if result.stdout:
                logger.debug(result.stdout)
            logger.info(f"[OK] {description} completed successfully")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"[FAIL] {description} failed")
            logger.error(f"Error: {e.stderr}")
            return False
        except FileNotFoundError:
            logger.error(f"[NOT_FOUND] Command not found: {cmd[0]}")
            return False
            
    def build_package(self, package_type="full", compress=True):
        """Build the offline package"""
        logger.info(f"Building {package_type} package...")
        logger.info(f"Output directory: {self.output_dir}")
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Step 1: Run the main build script
        logger.info("\n" + "="*60)
        logger.info("STEP 1: Running main package builder")
        logger.info("="*60)
        
        cmd = [
            sys.executable,
            str(self.scripts_dir / "build_offline_package.py"),
            f"--{package_type}",
            "--output-dir", str(self.output_dir)
        ]
        
        if compress:
            cmd.append("--compress")
            
        if not self.run_command(cmd, "Main package build"):
            logger.warning("Main build script failed, trying individual components...")
            
            # Try running individual scripts as fallback
            self.run_fallback_build()
            
        # Step 2: Copy installation scripts to package root
        logger.info("\n" + "="*60)
        logger.info("STEP 2: Copying installation scripts")
        logger.info("="*60)
        
        self.copy_installation_scripts()
        
        # Step 3: Generate final documentation
        logger.info("\n" + "="*60)
        logger.info("STEP 3: Generating documentation")
        logger.info("="*60)
        
        self.generate_documentation()
        
        # Step 4: Create package manifest
        logger.info("\n" + "="*60)
        logger.info("STEP 4: Creating package manifest")
        logger.info("="*60)
        
        self.create_manifest(package_type)
        
        # Step 5: Verify package
        logger.info("\n" + "="*60)
        logger.info("STEP 5: Verifying package")
        logger.info("="*60)
        
        if self.verify_package():
            logger.info("[OK] Package verification successful")
        else:
            logger.warning("[WARNING] Package verification failed - manual review recommended")
            
        return True
        
    def run_fallback_build(self):
        """Run individual scripts if main build fails"""
        logger.info("Running fallback build with individual scripts...")
        
        # Run prepare_offline_windows.py
        cmd = [
            sys.executable,
            str(self.scripts_dir / "prepare_offline_windows.py"),
            "--output-dir", str(self.output_dir)
        ]
        self.run_command(cmd, "Python package preparation")
        
        # Run offline_deps_downloader.py
        deps_dir = self.output_dir / "language-servers"
        deps_dir.mkdir(parents=True, exist_ok=True)
        
        cmd = [
            sys.executable,
            str(self.scripts_dir / "offline_deps_downloader.py"),
            "--output-dir", str(deps_dir)
        ]
        self.run_command(cmd, "Language server downloads")
        
        # Apply offline configuration
        cmd = [
            sys.executable,
            str(self.scripts_dir / "offline_config.py"),
            "--enable",
            "--offline-deps-dir", str(deps_dir)
        ]
        self.run_command(cmd, "Offline configuration")
        
    def copy_installation_scripts(self):
        """Copy all installation scripts to package root"""
        scripts_to_copy = [
            "install.bat",
            "install.ps1",
            "setup_environment.ps1",
            "uninstall.ps1"
        ]
        
        for script in scripts_to_copy:
            src = self.root_dir / script
            if src.exists():
                dst = self.output_dir / script
                shutil.copy2(src, dst)
                logger.info(f"[OK] Copied {script}")
            else:
                logger.warning(f"[WARNING] Script not found: {script}")
                
    def generate_documentation(self):
        """Generate final documentation"""
        # Copy README_OFFLINE.md
        readme_src = self.root_dir / "README_OFFLINE.md"
        if readme_src.exists():
            readme_dst = self.output_dir / "README.md"
            shutil.copy2(readme_src, readme_dst)
            logger.info("[OK] Copied README.md")
            
        # Create QUICK_START.txt
        quick_start = self.output_dir / "QUICK_START.txt"
        quick_start.write_text("""
SERENA OFFLINE PACKAGE - QUICK START GUIDE
==========================================

1. INSTALLATION (Run as Administrator):
   
   Option A - PowerShell (Recommended):
   > powershell -ExecutionPolicy Bypass .\\install.ps1
   
   Option B - Command Prompt:
   > install.bat

2. VERIFY INSTALLATION:
   > serena-mcp-server --version

3. START USING:
   > serena-mcp-server

4. FOR HELP:
   See README.md for detailed instructions

5. UNINSTALL:
   > powershell -ExecutionPolicy Bypass .\\uninstall.ps1

==========================================
Build Date: {date}
Package Type: Full Offline Package
Platform: Windows 10/11 (x64/ARM64)
==========================================
""".format(date=datetime.now().strftime("%Y-%m-%d")))
        logger.info("[OK] Created QUICK_START.txt")
        
    def create_manifest(self, package_type):
        """Create package manifest"""
        manifest = {
            "package_name": "serena-offline-windows",
            "version": "1.0.0",
            "build_date": self.build_timestamp,
            "package_type": package_type,
            "platform": "windows",
            "architecture": ["x64", "arm64"],
            "python_version": "3.11.9",
            "components": {
                "python": "3.11.9",
                "language_servers": {
                    "java": "Eclipse JDT.LS 1.42.0",
                    "csharp": "Microsoft.CodeAnalysis.LanguageServer 5.0.0",
                    "al": "AL Language Extension (latest)",
                    "typescript": "TypeScript 5.5.4",
                    "python": "Pyright 1.1.396",
                    "go": "gopls (system)",
                    "rust": "rust-analyzer (system)"
                }
            },
            "size_mb": self.calculate_package_size(),
            "files": {
                "installers": ["install.bat", "install.ps1", "setup_environment.ps1", "uninstall.ps1"],
                "documentation": ["README.md", "QUICK_START.txt"],
                "directories": ["python", "wheels", "language-servers", "serena-source", "templates", "scripts"]
            }
        }
        
        manifest_path = self.output_dir / "manifest.json"
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        logger.info("[OK] Created manifest.json")
        
    def calculate_package_size(self):
        """Calculate total package size in MB"""
        total_size = 0
        for path in self.output_dir.rglob('*'):
            if path.is_file():
                total_size += path.stat().st_size
        return round(total_size / (1024 * 1024), 2)
        
    def verify_package(self):
        """Verify package completeness"""
        required_items = [
            self.output_dir / "python",
            self.output_dir / "wheels",
            self.output_dir / "install.bat",
            self.output_dir / "install.ps1",
            self.output_dir / "README.md"
        ]
        
        all_present = True
        for item in required_items:
            if item.exists():
                logger.info(f"[OK] Found: {item.name}")
            else:
                logger.warning(f"[MISSING] Missing: {item.name}")
                all_present = False
                
        return all_present
        
    def print_summary(self):
        """Print build summary"""
        size_mb = self.calculate_package_size()
        
        summary = f"""
╔══════════════════════════════════════════════════════════════════════╗
║                         BUILD COMPLETE                              ║
╠══════════════════════════════════════════════════════════════════════╣
║  Package Location: {str(self.output_dir):<49}║
║  Package Size: {size_mb:<53.2f} MB ║
║  Build Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S"):<55}║
╠══════════════════════════════════════════════════════════════════════╣
║                         NEXT STEPS                                  ║
╠══════════════════════════════════════════════════════════════════════╣
║  1. Copy the package folder to target Windows machine               ║
║  2. Run install.ps1 or install.bat as Administrator                 ║
║  3. Follow the installation prompts                                 ║
║  4. Start using: serena-mcp-server                                 ║
╚══════════════════════════════════════════════════════════════════════╝
        """
        print(summary)
        
def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Build Serena offline package for Windows",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python BUILD_OFFLINE_WINDOWS.py              # Build full package
  python BUILD_OFFLINE_WINDOWS.py --minimal    # Build minimal package
  python BUILD_OFFLINE_WINDOWS.py --standard   # Build standard package
  python BUILD_OFFLINE_WINDOWS.py --no-compress # Don't compress final package
        """
    )
    
    parser.add_argument(
        '--minimal',
        action='store_true',
        help='Build minimal package (Python only)'
    )
    
    parser.add_argument(
        '--standard',
        action='store_true',
        help='Build standard package (common languages)'
    )
    
    parser.add_argument(
        '--full',
        action='store_true',
        help='Build full package (all languages) - default'
    )
    
    parser.add_argument(
        '--no-compress',
        action='store_true',
        help='Do not compress the final package'
    )
    
    args = parser.parse_args()
    
    # Determine package type
    if args.minimal:
        package_type = "minimal"
    elif args.standard:
        package_type = "standard"
    else:
        package_type = "full"
        
    compress = not args.no_compress
    
    # Create builder and run
    builder = OfflinePackageBuilder()
    
    try:
        builder.print_banner()
        
        if not builder.check_prerequisites():
            logger.error("Prerequisites check failed. Exiting.")
            return 1
            
        logger.info(f"Starting {package_type} package build...")
        start_time = time.time()
        
        if builder.build_package(package_type, compress):
            elapsed = time.time() - start_time
            logger.info(f"Build completed in {elapsed:.2f} seconds")
            builder.print_summary()
            return 0
        else:
            logger.error("Build failed")
            return 1
            
    except KeyboardInterrupt:
        logger.warning("\nBuild interrupted by user")
        return 1
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        logger.exception("Full traceback:")
        return 1

if __name__ == "__main__":
    sys.exit(main())