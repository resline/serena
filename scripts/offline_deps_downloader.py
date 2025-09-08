#!/usr/bin/env python3
"""
Offline Dependencies Downloader for Serena

This script downloads all language server binaries and runtime dependencies
needed for offline usage of Serena on Windows systems.

Dependencies Downloaded:
1. Java Language Server (Eclipse JDTLS)
   - Gradle 8.14.2
   - VS Code Java Extension v1.42.0 (contains JRE and JDTLS)
   - IntelliCode Extension v1.2.30

2. C# Language Server (Microsoft.CodeAnalysis.LanguageServer)  
   - .NET 9 Runtime for Windows
   - Microsoft.CodeAnalysis.LanguageServer binaries

3. AL Language Server
   - Latest AL Extension from VS Code marketplace

4. TypeScript/JavaScript Language Server
   - TypeScript compiler 5.5.4
   - TypeScript Language Server 4.3.3

5. Node.js Runtime (for TypeScript/JavaScript support)

Usage:
    python scripts/offline_deps_downloader.py [--output-dir DIR] [--platform PLATFORM]
    
Options:
    --output-dir DIR    Output directory for downloads (default: ./offline_deps)
    --platform PLATFORM  Target platform: win-x64, win-arm64 (default: win-x64)
    --resume            Resume interrupted downloads
    --verify            Verify checksums where available
    --create-manifest   Create manifest.json with download metadata
"""

import argparse
import json
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import logging

# Import enterprise download module
try:
    from enterprise_download_simple import SimpleEnterpriseDownloader as EnterpriseDownloader, add_enterprise_args, create_enterprise_downloader_from_args
except ImportError:
    # Fallback if enterprise_download is not available
    EnterpriseDownloader = None
    add_enterprise_args = lambda parser: None
    create_enterprise_downloader_from_args = lambda args: None

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class OfflineDepsDownloader:
    """Downloads all runtime dependencies for offline Windows usage."""
    
    def __init__(self, output_dir: str, platform: str = "win-x64", resume: bool = False, enterprise_downloader=None):
        self.output_dir = Path(output_dir)
        self.platform = platform
        self.resume = resume
        self.enterprise_downloader = enterprise_downloader
        self.manifest = {"platform": platform, "downloads": {}}
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Platform mappings
        self.platform_mappings = {
            "win-x64": "win32-x64",
            "win-arm64": "win32-arm64"
        }
        
    def download_with_progress(self, url: str, target_path: Path, headers: Optional[Dict] = None) -> bool:
        """Download a file with progress tracking and resume support."""
        # Use enterprise downloader if available
        if self.enterprise_downloader:
            logger.info(f"Using enterprise downloader for: {url}")
            return self.enterprise_downloader.download_with_progress(url, target_path, headers)
        
        # Standard download method
        if self.resume and target_path.exists():
            logger.info(f"Resuming download: {target_path.name}")
            resume_pos = target_path.stat().st_size
            if headers is None:
                headers = {}
            headers["Range"] = f"bytes={resume_pos}-"
            mode = "ab"
        else:
            resume_pos = 0
            mode = "wb"
            
        try:
            req = urllib.request.Request(url, headers=headers or {})
            with urllib.request.urlopen(req, timeout=300) as response:
                total_size = int(response.headers.get("content-length", 0))
                if resume_pos > 0:
                    total_size += resume_pos
                    
                logger.info(f"Downloading {url}")
                logger.info(f"Size: {total_size / 1024 / 1024:.1f} MB")
                
                with open(target_path, mode) as f:
                    downloaded = resume_pos
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Progress every 10MB
                        if total_size > 0 and downloaded % (10 * 1024 * 1024) == 0:
                            progress = (downloaded / total_size) * 100
                            logger.info(f"Progress: {progress:.1f}%")
                            
                logger.info(f"Download complete: {target_path.name}")
                return True
                
        except Exception as e:
            logger.error(f"Download failed for {url}: {e}")
            if target_path.exists() and not self.resume:
                target_path.unlink()
            return False
    
    def validate_binary_file(self, file_path: Path) -> bool:
        """Check if downloaded file is actually binary (not HTML error page)."""
        try:
            with open(file_path, 'rb') as f:
                header = f.read(512)
                
                # Check for ZIP/VSIX signature (PK)
                if header.startswith(b'PK'):
                    return True
                
                # Check for HTML content in binary data
                if b'<!DOCTYPE' in header or b'<html' in header or b'<HTML' in header:
                    logger.error(f"File {file_path.name} contains HTML content instead of binary data")
                    return False
                
                # Try to decode as UTF-8 and check for HTML/error indicators
                try:
                    header_text = header.decode('utf-8').lower()
                    html_indicators = ['<html', '<!doctype', '<error', '404', '403', '<title>', 'not found', 'access denied']
                    if any(indicator in header_text for indicator in html_indicators):
                        logger.error(f"File {file_path.name} appears to be an HTML error page")
                        # Log first 200 chars for debugging
                        logger.error(f"Content preview: {header_text[:200]}...")
                        return False
                except UnicodeDecodeError:
                    # If it can't decode as UTF-8, likely binary
                    pass
                
                return True  # Assume binary if not clearly HTML
                
        except Exception as e:
            logger.error(f"Error validating file {file_path}: {e}")
            return False

    def verify_checksum(self, file_path: Path, expected_hash: str, algorithm: str = "sha256") -> bool:
        """Verify file checksum."""
        if not expected_hash:
            return True
            
        hash_func = getattr(hashlib, algorithm)()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_func.update(chunk)
        
        actual_hash = hash_func.hexdigest()
        if actual_hash.lower() != expected_hash.lower():
            logger.error(f"Checksum mismatch for {file_path.name}")
            logger.error(f"Expected: {expected_hash}")
            logger.error(f"Actual: {actual_hash}")
            return False
        return True
    
    def extract_archive(self, archive_path: Path, extract_to: Path, archive_type: str = "zip") -> bool:
        """Extract archive with proper handling."""
        try:
            # First, validate that the file is actually binary/ZIP and not HTML
            if not self.validate_binary_file(archive_path):
                logger.error(f"Cannot extract {archive_path.name}: file is not a valid binary archive")
                return False
            
            logger.info(f"Extracting {archive_path.name} to {extract_to}")
            extract_to.mkdir(parents=True, exist_ok=True)
            
            if archive_type == "zip" or archive_path.suffix.lower() in [".zip", ".vsix", ".nupkg"]:
                # Test if it's a valid ZIP file before extraction
                try:
                    with zipfile.ZipFile(archive_path, 'r') as zip_test:
                        # Test the ZIP file integrity
                        bad_file = zip_test.testzip()
                        if bad_file is not None:
                            logger.error(f"ZIP file {archive_path.name} is corrupted. Bad file: {bad_file}")
                            return False
                except zipfile.BadZipFile:
                    logger.error(f"File {archive_path.name} is not a valid ZIP file")
                    return False
                
                with zipfile.ZipFile(archive_path, 'r') as zip_ref:
                    # Extract with progress
                    members = zip_ref.infolist()
                    for i, member in enumerate(members):
                        zip_ref.extract(member, extract_to)
                        if (i + 1) % 100 == 0:
                            logger.info(f"Extracted {i + 1}/{len(members)} files")
            else:
                shutil.unpack_archive(str(archive_path), str(extract_to))
                
            logger.info(f"Extraction complete: {archive_path.name}")
            return True
            
        except zipfile.BadZipFile as e:
            logger.error(f"ZIP extraction failed for {archive_path}: File is not a zip file or is corrupted - {e}")
            return False
        except Exception as e:
            logger.error(f"Extraction failed for {archive_path}: {e}")
            return False
    
    def download_vsix_with_retry(self, name: str, marketplace_url: str, target_path: Path, fallback_urls: List[str] = None) -> bool:
        """Download VSIX file with retry logic and fallback strategies."""
        logger.info(f"Downloading {name} VSIX...")
        
        # Strategy 1: Marketplace API with proper headers
        headers_marketplace = {
            'User-Agent': 'VSCode/1.85.0 (Windows)',
            'Accept': 'application/octet-stream, application/vsix, application/zip',
            'Accept-Encoding': 'gzip, deflate',
            'X-Market-Client-Id': 'VSCode',
            'X-Market-User-Id': 'anonymous'
        }
        
        strategies = [
            (f"marketplace API for {name}", marketplace_url, headers_marketplace),
        ]
        
        # Add fallback URLs if provided
        if fallback_urls:
            for i, fallback_url in enumerate(fallback_urls):
                strategies.append((f"fallback {i+1} for {name}", fallback_url, headers_marketplace))
        
        for strategy_name, url, headers in strategies:
            logger.info(f"Attempting {strategy_name}...")
            
            if self.download_with_progress(url, target_path, headers):
                # Validate the downloaded file
                if self.validate_binary_file(target_path):
                    logger.info(f"Successfully downloaded {name} using {strategy_name}")
                    return True
                else:
                    logger.warning(f"{strategy_name} downloaded HTML instead of binary - trying next strategy")
                    if target_path.exists():
                        target_path.unlink()
            else:
                logger.warning(f"{strategy_name} failed - trying next strategy")
        
        logger.error(f"All download strategies failed for {name}")
        return False
    
    def download_gradle(self) -> bool:
        """Download Gradle 8.14.2."""
        logger.info("=== Downloading Gradle ===")
        
        url = "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip"
        gradle_dir = self.output_dir / "gradle"
        archive_path = gradle_dir / "gradle-8.14.2-bin.zip"
        
        gradle_dir.mkdir(exist_ok=True)
        
        if not self.download_with_progress(url, archive_path):
            return False
            
        # Extract gradle
        extract_dir = gradle_dir / "extracted"
        if not self.extract_archive(archive_path, extract_dir):
            logger.error("Failed to extract Gradle archive")
            return False
        
        self.manifest["downloads"]["gradle"] = {
            "url": url,
            "archive": str(archive_path),
            "extracted": str(extract_dir),
            "version": "8.14.2"
        }
        
        return True
    
    def download_java_language_server(self) -> bool:
        """Download Java Language Server components."""
        logger.info("=== Downloading Java Language Server ===")
        
        java_dir = self.output_dir / "java"
        java_dir.mkdir(exist_ok=True)
        
        success = True
        
        # VS Code Java Extension  
        platform_map = self.platform_mappings.get(self.platform, "win32-x64")
        java_url = f"https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-{platform_map}-1.42.0-561.vsix"
        java_archive = java_dir / f"java-{platform_map}-1.42.0-561.vsix"
        
        logger.info("Downloading VS Code Java Extension...")
        if not self.download_with_progress(java_url, java_archive):
            logger.error("Failed to download VS Code Java Extension")
            success = False
        else:
            # Extract Java extension
            java_extract_dir = java_dir / "vscode-java"
            if not self.extract_archive(java_archive, java_extract_dir):
                logger.error("Failed to extract VS Code Java extension")
                success = False
        
        # IntelliCode Extension with retry logic
        intellicode_url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/VisualStudioExptTeam/vsextensions/vscodeintellicode/1.2.30/vspackage"
        intellicode_archive = java_dir / "vscodeintellicode-1.2.30.vsix"
        
        # Try alternative GitHub releases URL as fallback
        intellicode_fallbacks = [
            "https://github.com/MicrosoftDocs/intellicode/releases/download/v1.2.30/vscodeintellicode-1.2.30.vsix"
        ]
        
        if self.download_vsix_with_retry("IntelliCode", intellicode_url, intellicode_archive, intellicode_fallbacks):
            # Extract IntelliCode
            intellicode_extract_dir = java_dir / "intellicode" 
            if not self.extract_archive(intellicode_archive, intellicode_extract_dir):
                logger.error("Failed to extract IntelliCode extension")
                # Don't fail completely, just warn since IntelliCode is not critical
                logger.warning("Continuing without IntelliCode extension")
        else:
            logger.warning("Failed to download IntelliCode extension - continuing without it")
            # Don't fail completely since IntelliCode is not critical for basic Java LS functionality
        
        # Update manifest only with successfully downloaded components
        manifest_data = {}
        
        if java_archive.exists():
            manifest_data["vscode_java"] = {
                "url": java_url,
                "archive": str(java_archive),
                "extracted": str(java_dir / "vscode-java") if (java_dir / "vscode-java").exists() else None
            }
        
        if intellicode_archive.exists():
            manifest_data["intellicode"] = {
                "url": intellicode_url,
                "archive": str(intellicode_archive),
                "extracted": str(java_dir / "intellicode") if (java_dir / "intellicode").exists() else None
            }
        
        self.manifest["downloads"]["java"] = manifest_data
        
        # Return success if at least the main Java extension was downloaded
        return success and java_archive.exists()
    
    def download_csharp_language_server(self) -> bool:
        """Download C# Language Server components."""
        logger.info("=== Downloading C# Language Server ===")
        
        csharp_dir = self.output_dir / "csharp"
        csharp_dir.mkdir(exist_ok=True)
        
        # .NET 9 Runtime
        runtime_url = f"https://builds.dotnet.microsoft.com/dotnet/Runtime/9.0.6/dotnet-runtime-9.0.6-{self.platform}.zip"
        runtime_archive = csharp_dir / f"dotnet-runtime-9.0.6-{self.platform}.zip"
        
        logger.info("Downloading .NET 9 Runtime...")
        if not self.download_with_progress(runtime_url, runtime_archive):
            return False
        
        # Extract .NET Runtime
        runtime_extract_dir = csharp_dir / "dotnet-runtime"
        if not self.extract_archive(runtime_archive, runtime_extract_dir):
            return False
        
        # Microsoft.CodeAnalysis.LanguageServer
        package_name = f"Microsoft.CodeAnalysis.LanguageServer.{self.platform}"
        package_version = "5.0.0-1.25329.6"
        
        # Download from Azure NuGet feed
        azure_feed_url = "https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json"
        
        logger.info("Fetching NuGet service index...")
        try:
            with urllib.request.urlopen(azure_feed_url) as response:
                service_index = json.loads(response.read().decode())
        except Exception as e:
            logger.error(f"Failed to fetch NuGet service index: {e}")
            return False
        
        # Find package base address
        package_base_address = None
        for resource in service_index.get("resources", []):
            if resource.get("@type") == "PackageBaseAddress/3.0.0":
                package_base_address = resource.get("@id")
                break
        
        if not package_base_address:
            logger.error("Could not find package base address in Azure NuGet feed")
            return False
        
        # Download language server package
        package_id_lower = package_name.lower()
        package_version_lower = package_version.lower()
        package_url = f"{package_base_address.rstrip('/')}/{package_id_lower}/{package_version_lower}/{package_id_lower}.{package_version_lower}.nupkg"
        package_archive = csharp_dir / f"{package_name}.{package_version}.nupkg"
        
        logger.info(f"Downloading {package_name}...")
        if not self.download_with_progress(package_url, package_archive):
            return False
        
        # Extract language server package
        langserver_extract_dir = csharp_dir / "language-server"
        if not self.extract_archive(package_archive, langserver_extract_dir):
            return False
        
        self.manifest["downloads"]["csharp"] = {
            "runtime": {
                "url": runtime_url,
                "archive": str(runtime_archive),
                "extracted": str(runtime_extract_dir)
            },
            "language_server": {
                "url": package_url,
                "archive": str(package_archive),
                "extracted": str(langserver_extract_dir),
                "package": package_name,
                "version": package_version
            }
        }
        
        return True
    
    def download_al_language_server(self) -> bool:
        """Download AL Language Server."""
        logger.info("=== Downloading AL Language Server ===")
        
        al_dir = self.output_dir / "al"
        al_dir.mkdir(exist_ok=True)
        
        # AL Extension (latest version)
        al_url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-dynamics-smb/vsextensions/al/latest/vspackage"
        al_archive = al_dir / "al-latest.vsix"
        
        # Try to download with retry logic (no known fallbacks for AL currently)
        if self.download_vsix_with_retry("AL Language Server", al_url, al_archive):
            # Extract AL extension
            al_extract_dir = al_dir / "extension"
            if not self.extract_archive(al_archive, al_extract_dir):
                logger.error("Failed to extract AL extension")
                return False
                
            self.manifest["downloads"]["al"] = {
                "url": al_url,
                "archive": str(al_archive),
                "extracted": str(al_extract_dir)
            }
            
            return True
        else:
            logger.error("Failed to download AL Language Server - this may impact AL language support")
            logger.warning("AL Language Server is not available from marketplace. Consider manual installation.")
            return False
    
    def download_typescript_deps(self) -> bool:
        """Download TypeScript Language Server dependencies."""
        logger.info("=== Downloading TypeScript Dependencies ===")
        
        ts_dir = self.output_dir / "typescript"
        ts_dir.mkdir(exist_ok=True)
        
        # Create package.json for npm install
        package_json = {
            "name": "serena-typescript-deps",
            "version": "1.0.0", 
            "description": "TypeScript dependencies for Serena offline usage",
            "dependencies": {
                "typescript": "5.5.4",
                "typescript-language-server": "4.3.3"
            }
        }
        
        package_json_path = ts_dir / "package.json"
        with open(package_json_path, 'w') as f:
            json.dump(package_json, f, indent=2)
        
        # First ensure Node.js is downloaded
        node_version = "20.18.2"
        if self.platform == "win-x64":
            nodejs_dir = self.output_dir / "nodejs" / "extracted" / f"node-v{node_version}-win-x64"
        elif self.platform == "win-arm64":
            nodejs_dir = self.output_dir / "nodejs" / "extracted" / f"node-v{node_version}-win-arm64"
        else:
            logger.error(f"Unsupported platform for Node.js: {self.platform}")
            return False
        
        # Find npm in the downloaded Node.js
        if sys.platform == "win32":
            npm_cmd = nodejs_dir / "npm.cmd"
            node_cmd = nodejs_dir / "node.exe"
        else:
            npm_cmd = nodejs_dir / "bin" / "npm"
            node_cmd = nodejs_dir / "bin" / "node"
        
        # Check if npm exists from our download, if not download Node.js first
        if not npm_cmd.exists():
            logger.info("npm not found in downloaded Node.js, downloading Node.js first...")
            if not self.download_node_runtime():
                logger.error("Failed to download Node.js runtime")
                # Fallback to system npm if available
                npm_command = shutil.which("npm")
                if not npm_command:
                    logger.error("npm not found - cannot install TypeScript dependencies")
                    logger.info("Please ensure Node.js is installed or manually download TypeScript dependencies")
                    # Don't fail completely - TypeScript deps are non-critical
                    logger.warning("Skipping TypeScript dependencies (non-critical for basic functionality)")
                    return True
                else:
                    logger.info("Using system npm as fallback")
            else:
                # Verify npm exists after download
                if not npm_cmd.exists():
                    logger.error("npm still not found after Node.js download")
                    return False
                npm_command = str(npm_cmd)
        else:
            npm_command = str(npm_cmd)
            logger.info(f"Using npm from downloaded Node.js: {npm_command}")
        
        # Set up environment for npm to use the downloaded Node.js
        env = os.environ.copy()
        if npm_command == str(npm_cmd):  # Using downloaded npm
            # Add Node.js bin directory to PATH
            if sys.platform == "win32":
                node_bin_dir = str(nodejs_dir)
            else:
                node_bin_dir = str(nodejs_dir / "bin")
            env["PATH"] = f"{node_bin_dir}{os.pathsep}{env.get('PATH', '')}"
            env["NODE_PATH"] = str(nodejs_dir)
        
        # Run npm install to download packages
        logger.info("Running npm install...")
        try:
            result = subprocess.run(
                [npm_command, "install", "--production", "--no-audit", "--no-fund"],
                cwd=ts_dir,
                capture_output=True,
                text=True,
                check=True,
                env=env,
                timeout=300  # 5 minute timeout
            )
            logger.info("npm install completed successfully")
            if result.stdout:
                logger.info(f"npm stdout: {result.stdout}")
            
        except subprocess.TimeoutExpired:
            logger.error("npm install timed out after 5 minutes")
            logger.warning("TypeScript dependencies download failed (non-critical)")
            return True  # Don't fail the entire process
        except subprocess.CalledProcessError as e:
            logger.error(f"npm install failed: {e}")
            logger.error(f"stdout: {e.stdout}")
            logger.error(f"stderr: {e.stderr}")
            logger.warning("TypeScript dependencies download failed (non-critical)")
            return True  # Don't fail the entire process
        except Exception as e:
            logger.error(f"Unexpected error during npm install: {e}")
            logger.warning("TypeScript dependencies download failed (non-critical)")
            return True  # Don't fail the entire process
        
        self.manifest["downloads"]["typescript"] = {
            "package_json": str(package_json_path),
            "node_modules": str(ts_dir / "node_modules"),
            "packages": package_json["dependencies"],
            "npm_used": npm_command
        }
        
        return True
    
    def download_node_runtime(self) -> bool:
        """Download Node.js runtime for Windows."""
        logger.info("=== Downloading Node.js Runtime ===")
        
        node_dir = self.output_dir / "nodejs"
        node_dir.mkdir(exist_ok=True)
        
        # Node.js version
        node_version = "20.18.2"
        
        # Platform-specific URLs
        if self.platform == "win-x64":
            node_url = f"https://nodejs.org/dist/v{node_version}/node-v{node_version}-win-x64.zip"
            node_archive = node_dir / f"node-v{node_version}-win-x64.zip"
        elif self.platform == "win-arm64":
            node_url = f"https://nodejs.org/dist/v{node_version}/node-v{node_version}-win-arm64.zip"
            node_archive = node_dir / f"node-v{node_version}-win-arm64.zip"
        else:
            logger.error(f"Unsupported platform for Node.js: {self.platform}")
            return False
        
        if not self.download_with_progress(node_url, node_archive):
            return False
        
        # Extract Node.js
        node_extract_dir = node_dir / "extracted"
        if not self.extract_archive(node_archive, node_extract_dir):
            return False
        
        self.manifest["downloads"]["nodejs"] = {
            "url": node_url,
            "archive": str(node_archive),
            "extracted": str(node_extract_dir),
            "version": node_version
        }
        
        return True
    
    def download_all_dependencies(self) -> bool:
        """Download all runtime dependencies."""
        logger.info(f"Starting offline dependencies download for platform: {self.platform}")
        logger.info(f"Output directory: {self.output_dir}")
        
        success = True
        
        # Download all components
        downloads = [
            ("Gradle", self.download_gradle),
            ("Java Language Server", self.download_java_language_server),
            ("C# Language Server", self.download_csharp_language_server),
            ("AL Language Server", self.download_al_language_server),
            ("Node.js Runtime", self.download_node_runtime),
            ("TypeScript Dependencies", self.download_typescript_deps),
        ]
        
        failed_downloads = []
        
        for name, download_func in downloads:
            try:
                logger.info(f"\n{'='*60}")
                if not download_func():
                    failed_downloads.append(name)
                    success = False
                    logger.error(f"Failed to download: {name}")
            except Exception as e:
                failed_downloads.append(name)
                success = False
                logger.error(f"Exception downloading {name}: {e}")
        
        # Summary
        logger.info(f"\n{'='*60}")
        if success:
            logger.info("[SUCCESS] All dependencies downloaded successfully!")
        else:
            logger.error(f"[ERROR] Failed to download: {', '.join(failed_downloads)}")
        
        return success
    
    def create_manifest_file(self) -> bool:
        """Create manifest.json with download metadata."""
        try:
            manifest_path = self.output_dir / "manifest.json"
            
            # Add metadata
            self.manifest["created_at"] = str(Path().resolve())
            self.manifest["total_downloads"] = len(self.manifest["downloads"])
            
            # Calculate total size
            total_size = 0
            for component in self.manifest["downloads"].values():
                if isinstance(component, dict):
                    if "archive" in component:
                        archive_path = Path(component["archive"])
                        if archive_path.exists():
                            total_size += archive_path.stat().st_size
                    else:
                        # Handle nested structure (like java component)
                        for subcomponent in component.values():
                            if isinstance(subcomponent, dict) and "archive" in subcomponent:
                                archive_path = Path(subcomponent["archive"])
                                if archive_path.exists():
                                    total_size += archive_path.stat().st_size
            
            self.manifest["total_size_bytes"] = total_size
            self.manifest["total_size_mb"] = round(total_size / 1024 / 1024, 2)
            
            with open(manifest_path, 'w') as f:
                json.dump(self.manifest, f, indent=2)
            
            logger.info(f"Manifest created: {manifest_path}")
            logger.info(f"Total size: {self.manifest['total_size_mb']} MB")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create manifest: {e}")
            return False


def main():
    parser = argparse.ArgumentParser(description="Download offline dependencies for Serena")
    parser.add_argument(
        "--output-dir", 
        default="./offline_deps",
        help="Output directory for downloads (default: ./offline_deps)"
    )
    parser.add_argument(
        "--platform",
        choices=["win-x64", "win-arm64"],
        default="win-x64", 
        help="Target platform (default: win-x64)"
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume interrupted downloads"
    )
    parser.add_argument(
        "--create-manifest", 
        action="store_true",
        help="Create manifest.json with download metadata"
    )
    
    # Add enterprise networking arguments if available
    if add_enterprise_args:
        add_enterprise_args(parser)
    
    args = parser.parse_args()
    
    # Create enterprise downloader if available
    enterprise_downloader = None
    if EnterpriseDownloader:
        try:
            enterprise_downloader = create_enterprise_downloader_from_args(args)
            logger.info("Enterprise networking features enabled")
        except Exception as e:
            logger.warning(f"Failed to initialize enterprise downloader: {e}")
            logger.warning("Falling back to standard networking")
    
    downloader = OfflineDepsDownloader(
        output_dir=args.output_dir,
        platform=args.platform,
        resume=args.resume,
        enterprise_downloader=enterprise_downloader
    )
    
    success = downloader.download_all_dependencies()
    
    if args.create_manifest:
        downloader.create_manifest_file()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()