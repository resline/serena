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

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class OfflineDepsDownloader:
    """Downloads all runtime dependencies for offline Windows usage."""
    
    def __init__(self, output_dir: str, platform: str = "win-x64", resume: bool = False):
        self.output_dir = Path(output_dir)
        self.platform = platform
        self.resume = resume
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
            logger.info(f"Extracting {archive_path.name} to {extract_to}")
            extract_to.mkdir(parents=True, exist_ok=True)
            
            if archive_type == "zip" or archive_path.suffix.lower() in [".zip", ".vsix", ".nupkg"]:
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
            
        except Exception as e:
            logger.error(f"Extraction failed for {archive_path}: {e}")
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
        
        # VS Code Java Extension  
        platform_map = self.platform_mappings.get(self.platform, "win32-x64")
        java_url = f"https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-{platform_map}-1.42.0-561.vsix"
        java_archive = java_dir / f"java-{platform_map}-1.42.0-561.vsix"
        
        logger.info("Downloading VS Code Java Extension...")
        if not self.download_with_progress(java_url, java_archive):
            return False
            
        # Extract Java extension
        java_extract_dir = java_dir / "vscode-java"
        if not self.extract_archive(java_archive, java_extract_dir):
            return False
        
        # IntelliCode Extension
        intellicode_url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/VisualStudioExptTeam/vsextensions/vscodeintellicode/1.2.30/vspackage"
        intellicode_archive = java_dir / "vscodeintellicode-1.2.30.vsix"
        
        logger.info("Downloading IntelliCode Extension...")
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        if not self.download_with_progress(intellicode_url, intellicode_archive, headers):
            return False
        
        # Extract IntelliCode
        intellicode_extract_dir = java_dir / "intellicode" 
        if not self.extract_archive(intellicode_archive, intellicode_extract_dir):
            return False
        
        self.manifest["downloads"]["java"] = {
            "vscode_java": {
                "url": java_url,
                "archive": str(java_archive),
                "extracted": str(java_extract_dir)
            },
            "intellicode": {
                "url": intellicode_url,
                "archive": str(intellicode_archive), 
                "extracted": str(intellicode_extract_dir)
            }
        }
        
        return True
    
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
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "application/octet-stream, application/vsix, */*"
        }
        
        if not self.download_with_progress(al_url, al_archive, headers):
            return False
        
        # Extract AL extension
        al_extract_dir = al_dir / "extension"
        if not self.extract_archive(al_archive, al_extract_dir):
            return False
        
        self.manifest["downloads"]["al"] = {
            "url": al_url,
            "archive": str(al_archive),
            "extracted": str(al_extract_dir)
        }
        
        return True
    
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
        
        # Check if npm is available
        if not shutil.which("npm"):
            logger.error("npm is not available. Please install Node.js and npm first.")
            return False
        
        # Run npm install to download packages
        logger.info("Running npm install...")
        try:
            result = subprocess.run(
                ["npm", "install", "--production"],
                cwd=ts_dir,
                capture_output=True,
                text=True,
                check=True
            )
            logger.info("npm install completed successfully")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"npm install failed: {e}")
            logger.error(f"stdout: {e.stdout}")
            logger.error(f"stderr: {e.stderr}")
            return False
        
        self.manifest["downloads"]["typescript"] = {
            "package_json": str(package_json_path),
            "node_modules": str(ts_dir / "node_modules"),
            "packages": package_json["dependencies"]
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
            ("TypeScript Dependencies", self.download_typescript_deps),
            ("Node.js Runtime", self.download_node_runtime),
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
            logger.info("✅ All dependencies downloaded successfully!")
        else:
            logger.error(f"❌ Failed to download: {', '.join(failed_downloads)}")
        
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
    
    args = parser.parse_args()
    
    downloader = OfflineDepsDownloader(
        output_dir=args.output_dir,
        platform=args.platform,
        resume=args.resume
    )
    
    success = downloader.download_all_dependencies()
    
    if args.create_manifest:
        downloader.create_manifest_file()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()