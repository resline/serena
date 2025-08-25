#!/usr/bin/env python3
"""
Download language servers for offline/corporate deployment
Handles proxy and certificate issues
"""

import gzip
import hashlib
import json
import os
import platform
import ssl
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

# Handle Windows console encoding issues for Windows 10 compatibility
if sys.platform == "win32":
    try:
        # Set console to UTF-8 for Unicode support
        os.system('chcp 65001 >nul 2>&1')
        
        if hasattr(sys.stdout, 'reconfigure'):
            sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        if hasattr(sys.stderr, 'reconfigure'):
            sys.stderr.reconfigure(encoding='utf-8', errors='replace')
        
        # Set environment variable for subprocess calls
        os.environ['PYTHONIOENCODING'] = 'utf-8'
    except Exception:
        # If setup fails, continue with default encoding
        pass

# Define ASCII-safe output functions for Windows 10 legacy console compatibility
def safe_print(message, use_ascii_fallback=True):
    """Print message with fallback to ASCII characters for Windows 10 compatibility"""
    try:
        print(message)
    except UnicodeEncodeError:
        if use_ascii_fallback and sys.platform == "win32":
            # Replace Unicode characters with ASCII equivalents
            ascii_message = message.replace('\u2713', '[OK]').replace('\u2717', '[ERROR]').replace('\u274c', '[ERROR]')
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


class LanguageServerValidator:
    """Validate downloaded language servers for integrity and functionality"""
    
    def __init__(self):
        self.validation_results = []
        
    def validate_server_binary(self, server_path: Path, server_name: str) -> dict:
        """Validate a language server binary/archive"""
        result = {
            'server': server_name,
            'path': server_path,
            'valid': False,
            'size': 0,
            'sha256': '',
            'errors': [],
            'warnings': [],
            'executable_found': False,
            'version_info': None
        }
        
        try:
            if not server_path.exists():
                result['errors'].append('Server directory/file does not exist')
                return result
                
            # Get size (file or directory)
            if server_path.is_file():
                result['size'] = server_path.stat().st_size
                
                # Calculate checksum for single file
                sha256_hash = hashlib.sha256()
                with open(server_path, "rb") as f:
                    for chunk in iter(lambda: f.read(4096), b""):
                        sha256_hash.update(chunk)
                result['sha256'] = sha256_hash.hexdigest()
                
                # Check if it's executable
                if server_path.suffix.lower() in ['.exe', '']:
                    result['executable_found'] = True
            else:
                # Directory - calculate total size and find executables
                total_size = 0
                executables = []
                
                for file_path in server_path.rglob("*"):
                    if file_path.is_file():
                        total_size += file_path.stat().st_size
                        
                        # Check for executable files
                        if (file_path.suffix.lower() in ['.exe', '.sh', '.bat', '.cmd'] or 
                            (file_path.suffix == '' and os.access(file_path, os.X_OK))):
                            executables.append(file_path)
                            
                result['size'] = total_size
                result['executable_found'] = len(executables) > 0
                
                if executables:
                    result['executables'] = [str(exe.relative_to(server_path)) for exe in executables[:5]]  # First 5
                    
            # Size validation
            if result['size'] == 0:
                result['errors'].append('Empty file/directory')
            elif result['size'] < 1024:  # Less than 1KB suspicious
                result['warnings'].append('Very small size (< 1KB)')
            elif result['size'] > 500 * 1024 * 1024:  # Over 500MB
                result['warnings'].append('Very large size (> 500MB)')
                
            # Executable validation
            if not result['executable_found']:
                result['warnings'].append('No executable files found')
                
            # Try to get version info for some servers
            result['version_info'] = self._get_server_version(server_path, server_name)
            
            # Archive integrity check
            if server_path.is_file():
                archive_valid = self._validate_archive_integrity(server_path)
                if not archive_valid:
                    result['errors'].append('Archive integrity check failed')
                    
            result['valid'] = len(result['errors']) == 0
            
        except Exception as e:
            result['errors'].append(f'Validation failed: {str(e)}')
            
        return result
    
    def _validate_archive_integrity(self, archive_path: Path) -> bool:
        """Validate archive file integrity"""
        try:
            if archive_path.suffix.lower() == '.zip':
                with zipfile.ZipFile(archive_path, 'r') as zf:
                    return zf.testzip() is None
            elif archive_path.suffix.lower() in ['.tgz', '.gz']:
                with gzip.open(archive_path, 'rb') as gz:
                    # Try to read a small chunk
                    gz.read(1024)
                return True
            elif archive_path.suffix.lower() == '.tar':
                with tarfile.open(archive_path, 'r') as tar:
                    # Basic validation - check if we can read the archive
                    return len(tar.getnames()) > 0
        except Exception:
            return False
        return True
    
    def _get_server_version(self, server_path: Path, server_name: str) -> str | None:
        """Try to get version information from server"""
        try:
            # Common version commands to try
            version_commands = [
                ['--version'],
                ['-version'],
                ['version'],
                ['--help']  # Sometimes contains version info
            ]
            
            # Find executable
            executable = None
            if server_path.is_file() and server_path.suffix.lower() in ['.exe', '']:
                executable = server_path
            elif server_path.is_dir():
                # Look for common executable names
                common_names = [server_name, f"{server_name}.exe", "server", "server.exe", "bin/server"]
                for name in common_names:
                    candidate = server_path / name
                    if candidate.exists() and (candidate.suffix.lower() in ['.exe', ''] or os.access(candidate, os.X_OK)):
                        executable = candidate
                        break
            
            if not executable:
                return None
                
            # Try version commands
            for cmd_args in version_commands:
                try:
                    result = subprocess.run(
                        [str(executable)] + cmd_args,
                        capture_output=True,
                        text=True,
                        timeout=10,
                        cwd=executable.parent if executable.is_file() else server_path
                    )
                    
                    output = result.stdout + result.stderr
                    if output and ('version' in output.lower() or 'v' in output[:20].lower()):
                        # Extract version-like patterns
                        import re
                        version_pattern = r'(\d+\.\d+(?:\.\d+)*(?:[-\w]*)?)'
                        matches = re.findall(version_pattern, output)
                        if matches:
                            return matches[0][:20]  # First version, limit length
                            
                except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
                    continue
                    
        except Exception:
            pass
            
        return None
    
    def validate_all_servers(self, servers_dir: Path) -> dict:
        """Validate all language servers in directory"""
        results = {
            'directory': servers_dir,
            'total_servers': 0,
            'valid_servers': 0,
            'invalid_servers': 0,
            'total_size': 0,
            'servers': [],
            'errors': []
        }
        
        try:
            if not servers_dir.exists():
                results['errors'].append('Language servers directory does not exist')
                return results
                
            # Find all server directories/files
            server_items = [item for item in servers_dir.iterdir() if item.name not in ['manifest.json', '.DS_Store']]
            results['total_servers'] = len(server_items)
            
            progress = ProgressTracker(len(server_items), f"Validating servers in {servers_dir.name}")
            
            for i, server_item in enumerate(server_items):
                progress.update(i, server_item.name)
                
                server_result = self.validate_server_binary(server_item, server_item.name)
                results['servers'].append(server_result)
                results['total_size'] += server_result['size']
                
                if server_result['valid']:
                    results['valid_servers'] += 1
                else:
                    results['invalid_servers'] += 1
                    
            progress.update(len(server_items), "Complete")
            
        except Exception as e:
            results['errors'].append(f'Directory validation failed: {str(e)}')
            
        return results
    
    def generate_validation_report(self, results: dict, output_path: Path):
        """Generate detailed validation report for language servers"""
        report_lines = []
        report_lines.append("# Language Server Validation Report")
        report_lines.append(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        report_lines.append("")
        
        # Summary
        report_lines.append("## Summary")
        report_lines.append(f"- Directory: {results['directory']}")
        report_lines.append(f"- Total servers: {results['total_servers']}")
        report_lines.append(f"- Valid servers: {results['valid_servers']}")
        report_lines.append(f"- Invalid servers: {results['invalid_servers']}")
        report_lines.append(f"- Total size: {results['total_size'] / 1024 / 1024:.1f} MB")
        report_lines.append("")
        
        # Directory errors
        if results['errors']:
            report_lines.append("## Directory-level Issues")
            for error in results['errors']:
                report_lines.append(f"- ❌ {error}")
            report_lines.append("")
            
        # Server details
        if results['servers']:
            report_lines.append("## Server Validation Results")
            report_lines.append("")
            
            for server_result in results['servers']:
                status = "✅" if server_result['valid'] else "❌"
                name = server_result['server']
                size_mb = server_result['size'] / 1024 / 1024
                
                report_lines.append(f"### {status} {name}")
                report_lines.append(f"- Size: {size_mb:.2f} MB")
                
                if server_result['sha256']:
                    report_lines.append(f"- SHA256: {server_result['sha256']}")
                
                if server_result['executable_found']:
                    report_lines.append("- ✅ Executable files found")
                    if 'executables' in server_result:
                        report_lines.append(f"  - Files: {', '.join(server_result['executables'])}")
                else:
                    report_lines.append("- ⚠️  No executable files found")
                
                if server_result['version_info']:
                    report_lines.append(f"- Version: {server_result['version_info']}")
                
                if server_result['warnings']:
                    report_lines.append("- Warnings:")
                    for warning in server_result['warnings']:
                        report_lines.append(f"  - ⚠️  {warning}")
                
                if server_result['errors']:
                    report_lines.append("- Issues:")
                    for error in server_result['errors']:
                        report_lines.append(f"  - ❌ {error}")
                        
                report_lines.append("")
                
        # Write report
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))


class CorporateDownloader:
    def __init__(self, proxy_url: str | None = None, ca_cert_path: str | None = None):
        self.proxy_url = proxy_url or os.environ.get("HTTP_PROXY")
        self.ca_cert_path = ca_cert_path or os.environ.get("REQUESTS_CA_BUNDLE")
        self.setup_urllib()

    def setup_urllib(self):
        """Configure urllib for corporate proxy and certificates"""
        # Setup proxy
        if self.proxy_url:
            proxy = urllib.request.ProxyHandler({"http": self.proxy_url, "https": self.proxy_url})
            opener = urllib.request.build_opener(proxy)
            urllib.request.install_opener(opener)
            safe_print(f"[OK] Configured proxy: {self.proxy_url}")

        # Setup SSL context
        self.ssl_context = ssl.create_default_context()
        if self.ca_cert_path and os.path.exists(self.ca_cert_path):
            self.ssl_context.load_verify_locations(self.ca_cert_path)
            safe_print(f"[OK] Loaded CA certificate: {self.ca_cert_path}")
        else:
            # For testing/dev only - disable SSL verification
            # Remove this in production!
            # self.ssl_context.check_hostname = False
            # self.ssl_context.verify_mode = ssl.CERT_NONE
            pass

    def download_file(self, url: str, dest_path: Path, description: str = ""):
        """Download file with progress indication"""
        safe_print(f"Downloading {description or url}...")

        try:
            # Create request with headers
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"})

            with urllib.request.urlopen(req, context=self.ssl_context) as response:
                total_size = int(response.headers.get("Content-Length", 0))
                downloaded = 0
                block_size = 8192

                with open(dest_path, "wb") as f:
                    while True:
                        chunk = response.read(block_size)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)

                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r  Progress: {percent:.1f}%", end="", flush=True)

                print(f"\r  [OK] Downloaded {description}")
                return True

        except Exception as e:
            print(f"\r  [ERROR] Failed to download {description}: {e!s}")
            return False

    def extract_archive(self, archive_path: Path, dest_dir: Path, archive_type: str):
        """Extract downloaded archive"""
        try:
            if archive_type == "zip":
                with zipfile.ZipFile(archive_path, "r") as zf:
                    zf.extractall(dest_dir)
            elif archive_type == "tar.gz" or archive_type == "tgz":
                with gzip.open(archive_path, "rb") as gz:
                    with tarfile.open(fileobj=gz) as tar:
                        tar.extractall(dest_dir)
            elif archive_type == "tar":
                with tarfile.open(archive_path, "r") as tar:
                    tar.extractall(dest_dir)
            elif archive_type == "gem":
                return self._extract_gem_windows_safe(archive_path, dest_dir)

            print(f"  [OK] Extracted to {dest_dir}")
            return True

        except Exception as e:
            print(f"  [ERROR] Failed to extract: {e!s}")
            return False

    def _extract_gem_windows_safe(self, archive_path: Path, dest_dir: Path) -> bool:
        """Windows-safe gem extraction with enhanced retry logic and permission handling"""
        is_windows = platform.system().lower() == "windows"
        is_win10_plus = self._is_windows_10_or_later() if is_windows else False
        max_retries = 5 if is_win10_plus else (3 if is_windows else 1)
        
        # Exponential backoff delays: 0.5s -> 2s -> 5s -> 10s -> 15s
        retry_delays = [0.5, 2.0, 5.0, 10.0, 15.0]
        
        print(f"  [INFO] Detected Windows 10+ environment: {is_win10_plus}")
        
        # Pre-extraction testing
        if not self._test_file_accessibility(archive_path, is_windows):
            print("  [ERROR] Archive file is not accessible for extraction")
            return False
        
        # Use Windows-safe temporary directory for intermediate files
        temp_extract_dir = None
        if is_windows:
            temp_extract_dir = self._create_windows_safe_temp_dir()
            if temp_extract_dir is None:
                print("  [WARN] Could not create temp directory, using destination directly")
                temp_extract_dir = dest_dir
        else:
            temp_extract_dir = dest_dir

        for attempt in range(max_retries):
            try:
                print(f"  [INFO] Extracting Ruby gem (attempt {attempt + 1}/{max_retries})...")
                
                # Wait for antivirus if this is a retry
                if attempt > 0 and is_win10_plus:
                    antivirus_delay = min(retry_delays[attempt - 1], 5.0)
                    print(f"    [INFO] Waiting {antivirus_delay}s for antivirus scan completion...")
                    time.sleep(antivirus_delay)

                # Step 1: Extract the gem tar archive using enhanced method
                if self._extract_gem_tar_enhanced(archive_path, temp_extract_dir, is_windows, attempt):
                    # Step 2: Process extracted contents with integrity checks
                    if self._process_gem_contents_with_checks(temp_extract_dir, dest_dir, is_windows, attempt):
                        # Clean up temp directory if different from dest
                        if temp_extract_dir != dest_dir:
                            self._cleanup_temp_directory(temp_extract_dir, is_windows)
                        
                        print("  [OK] Ruby gem extracted successfully")
                        return True
                    else:
                        print(f"    [WARN] Gem content processing failed on attempt {attempt + 1}")
                else:
                    print(f"    [WARN] Gem tar extraction failed on attempt {attempt + 1}")

            except Exception as e:
                if attempt < max_retries - 1:
                    delay = retry_delays[attempt] if attempt < len(retry_delays) else retry_delays[-1]
                    print(f"    [RETRY] Extraction failed, retrying in {delay}s: {e}")
                    time.sleep(delay)
                    continue
                print(f"    [ERROR] Final attempt failed: {e}")
                
                # Clean up temp directory on failure
                if temp_extract_dir != dest_dir:
                    self._cleanup_temp_directory(temp_extract_dir, is_windows)
                
                # Try enhanced fallback extraction methods
                return self._enhanced_fallback_gem_extraction(archive_path, dest_dir, is_windows)

        return False

    def _is_windows_10_or_later(self) -> bool:
        """Detect if running on Windows 10 or later for enhanced security handling"""
        try:
            if platform.system().lower() != "windows":
                return False
            version = platform.version()
            major_version = int(version.split('.')[0])
            return major_version >= 10
        except:
            return True
    
    def _test_file_accessibility(self, file_path: Path, is_windows: bool) -> bool:
        """Test if file is accessible before attempting extraction"""
        try:
            if not file_path.exists():
                return False
            with open(file_path, "rb") as f:
                f.read(1024)
            if is_windows:
                try:
                    file_stat = file_path.stat()
                    if file_stat.st_size == 0:
                        print("    [WARN] Archive file appears to be empty")
                        return False
                    with open(file_path, "rb") as f:
                        pass
                except (PermissionError, OSError) as e:
                    print(f"    [WARN] File accessibility issue: {e}")
                    return False
            return True
        except Exception as e:
            print(f"    [WARN] File accessibility test failed: {e}")
            return False
    
    def _create_windows_safe_temp_dir(self) -> Path | None:
        """Create a Windows-safe temporary directory for extraction"""
        try:
            temp_base = Path(tempfile.gettempdir())
            temp_dir = temp_base / f"serena_gem_extract_{os.getpid()}_{int(time.time())}"
            temp_dir.mkdir(parents=True, exist_ok=True)
            test_file = temp_dir / "test.txt"
            with open(test_file, "w") as f:
                f.write("test")
            test_file.unlink()
            print(f"    [INFO] Using temp directory: {temp_dir}")
            return temp_dir
        except Exception as e:
            print(f"    [WARN] Could not create temp directory: {e}")
            return None

    def _extract_data_tar_with_retry(self, data_tar: Path, dest_dir: Path, is_windows: bool):
        """Extract data.tar.gz with Windows-specific retry logic"""
        max_attempts = 3 if is_windows else 1

        for attempt in range(max_attempts):
            try:
                with gzip.open(data_tar, "rb") as gz:
                    with tarfile.open(fileobj=gz) as tar:
                        if is_windows:
                            # Extract members individually on Windows
                            for member in tar.getmembers():
                                try:
                                    tar.extract(member, dest_dir)
                                except (PermissionError, OSError) as e:
                                    print(f"      [WARN] Could not extract data file {member.name}: {e}")
                                    continue
                        else:
                            tar.extractall(dest_dir)

                # Try to remove the intermediate file with retry
                for cleanup_attempt in range(3):
                    try:
                        if is_windows:
                            time.sleep(0.2)  # Brief pause for Windows
                        data_tar.unlink()
                        break
                    except (OSError, PermissionError) as e:
                        if cleanup_attempt < 2:
                            time.sleep(0.5)
                            continue
                        print(f"      [WARN] Could not remove {data_tar}: {e}")
                        print("      [INFO] This is normal on Windows and won't affect functionality")
                        break

                return  # Success

            except Exception as e:
                if attempt < max_attempts - 1:
                    print(f"      [RETRY] Data extraction failed, retrying: {e}")
                    time.sleep(0.5)
                    continue
                print(f"      [WARN] Could not extract gem data after {max_attempts} attempts: {e}")
                print("      [INFO] Continuing with partial extraction")
                return

    def _extract_metadata_safely(self, metadata_gz: Path, dest_dir: Path, is_windows: bool):
        """Safely extract metadata.gz without failing the whole process"""
        try:
            # On Windows, check if file is accessible before trying to extract
            if is_windows:
                try:
                    # Test file access
                    with open(metadata_gz, "rb") as test_file:
                        test_file.read(1)
                except (PermissionError, OSError) as e:
                    print(f"      [WARN] Metadata file not accessible: {e}")
                    return

            with gzip.open(metadata_gz, "rb") as gz:
                metadata_content = gz.read()
                # Save metadata as plain text for debugging
                metadata_txt = dest_dir / "metadata.yaml"
                with open(metadata_txt, "wb") as f:
                    f.write(metadata_content)
                print(f"      [INFO] Extracted metadata to {metadata_txt}")

        except Exception as e:
            print(f"      [WARN] Could not extract metadata: {e}")
            print("      [INFO] This won't affect gem functionality")

    def _extract_gem_tar_enhanced(self, archive_path: Path, dest_dir: Path, is_windows: bool, attempt: int) -> bool:
        """Enhanced gem tar extraction with file-by-file error handling"""
        try:
            with tarfile.open(archive_path, "r") as tar:
                members = tar.getmembers()
                print(f"    [INFO] Processing {len(members)} files from gem archive...")
                extracted_count = 0
                failed_files = []
                for i, member in enumerate(members):
                    try:
                        if len(members) > 10 and i % max(1, len(members) // 10) == 0:
                            print(f"      Progress: {i}/{len(members)} files")
                        if is_windows and self._is_problematic_file(member.name):
                            print(f"      [SKIP] Skipping problematic file: {member.name}")
                            continue
                        if self._extract_single_member_with_retry(tar, member, dest_dir, is_windows):
                            extracted_count += 1
                        else:
                            failed_files.append(member.name)
                    except Exception as e:
                        print(f"      [WARN] Failed to extract {member.name}: {e}")
                        failed_files.append(member.name)
                        continue
                print(f"    [INFO] Successfully extracted {extracted_count}/{len(members)} files")
                if failed_files and len(failed_files) < len(members) * 0.3:
                    print(f"    [INFO] Some files failed but continuing ({len(failed_files)} failures)")
                    return True
                elif failed_files:
                    print(f"    [ERROR] Too many extraction failures ({len(failed_files)} failures)")
                    return False
                else:
                    return True
        except Exception as e:
            print(f"    [ERROR] Gem tar extraction failed: {e}")
            return False

    def _is_problematic_file(self, filename: str) -> bool:
        """Check if file is known to cause issues on Windows"""
        if len(filename) > 200:
            return True
        problematic_patterns = ['.git/', '__pycache__/', '.pytest_cache/']
        for pattern in problematic_patterns:
            if pattern in filename:
                return True
        return False

    def _extract_single_member_with_retry(self, tar: tarfile.TarFile, member: tarfile.TarInfo, dest_dir: Path, is_windows: bool) -> bool:
        """Extract single tar member with retry logic"""
        max_attempts = 3 if is_windows else 1
        for attempt in range(max_attempts):
            try:
                if is_windows and member.isfile():
                    member.mode = 0o644
                elif is_windows and member.isdir():
                    member.mode = 0o755
                tar.extract(member, dest_dir)
                return True
            except (PermissionError, OSError) as e:
                if attempt < max_attempts - 1:
                    time.sleep(0.1 * (attempt + 1))
                    continue
                print(f"        [WARN] Could not extract {member.name}: {e}")
                return False
            except Exception as e:
                print(f"        [WARN] Unexpected error extracting {member.name}: {e}")
                return False
        return False

    def _process_gem_contents_with_checks(self, temp_dir: Path, dest_dir: Path, is_windows: bool, attempt: int) -> bool:
        """Process extracted gem contents with integrity checks"""
        try:
            data_tar = temp_dir / "data.tar.gz"
            if data_tar.exists():
                print("    [INFO] Processing gem data archive...")
                if not self._extract_data_tar_enhanced(data_tar, dest_dir, is_windows, attempt):
                    print("    [WARN] Data archive processing failed")
                    return False
            metadata_gz = temp_dir / "metadata.gz"
            if metadata_gz.exists():
                print("    [INFO] Processing gem metadata...")
                self._extract_metadata_safely(metadata_gz, dest_dir, is_windows)
            for item in temp_dir.iterdir():
                if item.name not in ["data.tar.gz", "metadata.gz"]:
                    try:
                        if item.is_file():
                            target = dest_dir / item.name
                            shutil.copy2(item, target)
                        elif item.is_dir():
                            target = dest_dir / item.name
                            shutil.copytree(item, target, dirs_exist_ok=True)
                    except Exception as e:
                        print(f"      [WARN] Could not copy {item.name}: {e}")
            return self._verify_extraction_integrity(dest_dir)
        except Exception as e:
            print(f"    [ERROR] Gem content processing failed: {e}")
            return False

    def _extract_data_tar_enhanced(self, data_tar: Path, dest_dir: Path, is_windows: bool, attempt: int) -> bool:
        """Enhanced data.tar.gz extraction with better Windows support"""
        max_attempts = 5 if is_windows else 1
        retry_delays = [0.2, 0.5, 1.0, 2.0, 3.0]
        for sub_attempt in range(max_attempts):
            try:
                if not self._test_file_accessibility(data_tar, is_windows):
                    if sub_attempt < max_attempts - 1:
                        delay = retry_delays[sub_attempt] if sub_attempt < len(retry_delays) else retry_delays[-1]
                        print(f"        [RETRY] Data file not accessible, waiting {delay}s...")
                        time.sleep(delay)
                        continue
                    else:
                        print("        [ERROR] Data file remains inaccessible")
                        return False
                extracted_count = 0
                failed_count = 0
                with gzip.open(data_tar, "rb") as gz:
                    with tarfile.open(fileobj=gz) as tar:
                        members = tar.getmembers()
                        print(f"        [INFO] Processing {len(members)} data files...")
                        for i, member in enumerate(members):
                            try:
                                if len(members) > 20 and i % max(1, len(members) // 10) == 0:
                                    print(f"          Progress: {i}/{len(members)} data files")
                                if is_windows:
                                    if self._extract_single_member_with_retry(tar, member, dest_dir, is_windows):
                                        extracted_count += 1
                                    else:
                                        failed_count += 1
                                else:
                                    tar.extract(member, dest_dir)
                                    extracted_count += 1
                            except Exception as e:
                                print(f"          [WARN] Could not extract data file {member.name}: {e}")
                                failed_count += 1
                                continue
                print(f"        [INFO] Data extraction: {extracted_count} success, {failed_count} failed")
                # Try to remove the intermediate file
                try:
                    data_tar.unlink()
                except:
                    pass
                success_rate = extracted_count / (extracted_count + failed_count) if (extracted_count + failed_count) > 0 else 0
                return success_rate > 0.7
            except Exception as e:
                if sub_attempt < max_attempts - 1:
                    delay = retry_delays[sub_attempt] if sub_attempt < len(retry_delays) else retry_delays[-1]
                    print(f"        [RETRY] Data extraction failed, retrying in {delay}s: {e}")
                    time.sleep(delay)
                    continue
                print(f"        [ERROR] Could not extract gem data after {max_attempts} attempts: {e}")
                return False
        return False

    def _verify_extraction_integrity(self, dest_dir: Path) -> bool:
        """Verify that extraction completed successfully with basic integrity checks"""
        try:
            if not dest_dir.exists():
                print("    [ERROR] Destination directory does not exist")
                return False
            file_count = 0
            dir_count = 0
            for item in dest_dir.rglob("*"):
                if item.is_file():
                    file_count += 1
                elif item.is_dir():
                    dir_count += 1
            if file_count == 0:
                print("    [WARN] No files found in extraction - possible failure")
                return False
            print(f"    [INFO] Extraction verified: {file_count} files, {dir_count} directories")
            common_files = ["lib", "bin", "README", "LICENSE", "CHANGELOG"]
            found_indicators = 0
            for item in dest_dir.iterdir():
                if any(indicator in item.name.upper() for indicator in common_files):
                    found_indicators += 1
            if found_indicators > 0:
                print(f"    [INFO] Found {found_indicators} gem structure indicators")
                return True
            else:
                print("    [WARN] No typical gem structure found, but proceeding")
                return True
        except Exception as e:
            print(f"    [WARN] Integrity check failed: {e}")
            return True

    def _enhanced_fallback_gem_extraction(self, archive_path: Path, dest_dir: Path, is_windows: bool) -> bool:
        """Enhanced fallback extraction with multiple strategies"""
        print("  [FALLBACK] Attempting enhanced fallback gem extraction...")
        # Try basic tar extraction first
        try:
            with tarfile.open(archive_path, "r") as tar:
                safe_members = []
                for member in tar.getmembers():
                    if member.name.endswith((".gz", ".sig", ".bz2", ".xz")):
                        continue
                    if is_windows and len(member.name) > 200:
                        continue
                    safe_members.append(member)
                if safe_members:
                    print(f"    [INFO] Extracting {len(safe_members)} safe files...")
                    if is_windows:
                        extracted = 0
                        for member in safe_members:
                            try:
                                tar.extract(member, dest_dir)
                                extracted += 1
                            except Exception as e:
                                print(f"      [WARN] Could not extract {member.name}: {e}")
                                continue
                        print(f"    [INFO] Successfully extracted {extracted} files")
                        return extracted > 0
                    else:
                        tar.extractall(dest_dir, members=safe_members)
                        print(f"    [INFO] Extracted {len(safe_members)} safe files")
                        return True
                else:
                    print("    [WARN] No safe files found to extract")
                    return False
        except Exception as e:
            print(f"    [ERROR] Enhanced fallback extraction failed: {e}")
            return False

    def _fallback_gem_extraction(self, archive_path: Path, dest_dir: Path) -> bool:
        """Fallback extraction method for problematic gems"""
        print("  [FALLBACK] Attempting basic gem extraction...")
        try:
            # Just extract the basic tar without processing internals
            with tarfile.open(archive_path, "r") as tar:
                # Get list of members and extract only safe ones
                safe_members = []
                for member in tar.getmembers():
                    # Skip problematic files
                    if member.name.endswith((".gz", ".sig")):
                        continue
                    safe_members.append(member)

                if safe_members:
                    tar.extractall(dest_dir, members=safe_members)
                    print(f"    [INFO] Extracted {len(safe_members)} safe files")
                    return True
                else:
                    print("    [WARN] No safe files found to extract")
                    return False
        except Exception as e:
            print(f"    [ERROR] Fallback extraction failed: {e}")
            return False


def create_gopls_installer(output_dir: Path):
    """Create installer script for gopls since it doesn't have pre-built binaries"""
    gopls_dir = output_dir / "gopls"
    gopls_dir.mkdir(exist_ok=True)

    # Windows batch installer
    installer_bat = """@echo off
echo Installing gopls (Go Language Server)...
echo.
echo This requires an active internet connection and Go toolchain.
echo.

REM Check if Go is available
go version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Go is not installed or not in PATH
    echo Please install Go from https://golang.org/doc/install
    echo.
    pause
    exit /b 1
)

REM Install gopls
echo Installing gopls...
go install -v golang.org/x/tools/gopls@latest

if errorlevel 1 (
    echo ERROR: Failed to install gopls
    echo Check your internet connection and try again
    pause
    exit /b 1
) else (
    echo SUCCESS: gopls installed successfully
    echo Location: %GOPATH%\\bin\\gopls.exe
    echo.
    echo Copying to language servers directory...
    set GOPATH_BIN=%GOPATH%\\bin
    if "%GOPATH%"=="" set GOPATH_BIN=%USERPROFILE%\\go\\bin
    
    if exist "%GOPATH_BIN%\\gopls.exe" (
        copy "%GOPATH_BIN%\\gopls.exe" "%~dp0\\gopls.exe" >nul
        echo SUCCESS: gopls copied to %~dp0\\gopls.exe
    )
)

pause
"""

    with open(gopls_dir / "install-gopls.bat", "w") as f:
        f.write(installer_bat)

    # Create README
    readme = """# gopls - Go Language Server

gopls does not provide pre-built binaries and must be installed using the Go toolchain.

## Installation
1. Ensure Go is installed on your system (https://golang.org/doc/install)
2. Run: install-gopls.bat
3. The installer will download and build gopls

## Manual Installation
```bash
go install golang.org/x/tools/gopls@latest
```

## Requirements
- Go 1.18 or later
- Internet connection for initial download
- Approximately 50MB disk space

## After Installation
The gopls binary will be available at:
- Windows: %USERPROFILE%\\go\\bin\\gopls.exe or %GOPATH%\\bin\\gopls.exe
- Linux/Mac: ~/go/bin/gopls or $GOPATH/bin/gopls
"""

    with open(gopls_dir / "README.md", "w") as f:
        f.write(readme)

    print(f"  [OK] Created gopls installer in {gopls_dir}")


def get_language_servers() -> dict[str, dict[str, Any]]:
    """Define language servers to download"""
    return {
        "pyright": {
            "url": "https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz",
            "type": "tgz",
            "description": "Python Language Server (Pyright)",
            "post_extract": lambda d: (d / "package").rename(d / "pyright"),
        },
        "typescript": {
            "url": "https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz",
            "type": "tgz",
            "description": "TypeScript Language Server",
        },
        "vscode-langservers-extracted": {
            "url": "https://registry.npmjs.org/vscode-langservers-extracted/-/vscode-langservers-extracted-4.10.0.tgz",
            "type": "tgz",
            "description": "VS Code Language Servers (HTML, CSS, JSON)",
        },
        # NOTE: gopls does not provide pre-built binaries and must be installed via 'go install golang.org/x/tools/gopls@latest'
        # Uncomment the following when/if golang provides direct binary downloads
        # 'gopls': {
        #     'url': 'https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip',
        #     'type': 'zip',
        #     'description': 'Go Language Server (gopls) - REQUIRES GO TOOLCHAIN',
        #     'platform_specific': True,
        #     'note': 'gopls must be installed via: go install golang.org/x/tools/gopls@latest',
        #     'platforms': {
        #         'win32': 'https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip',
        #         'linux': 'https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_linux_amd64.tar.gz',
        #         'darwin': 'https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_darwin_amd64.tar.gz'
        #     }
        # },
        "rust-analyzer": {
            "url": "https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-pc-windows-msvc.zip",
            "type": "zip",
            "description": "Rust Language Server",
            "platform_specific": True,
            "platforms": {
                "win32": "https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-pc-windows-msvc.zip",
                "linux": "https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-unknown-linux-gnu.gz",
                "darwin": "https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-apple-darwin.gz",
            },
        },
        "jdtls": {
            "url": "https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz",
            "type": "tar.gz",
            "description": "Java Language Server (Eclipse JDT.LS)",
        },
        "omnisharp": {
            "url": "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-win-x64.zip",
            "type": "zip",
            "description": "C# Language Server (OmniSharp)",
            "platform_specific": True,
            "platforms": {
                "win32": "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-win-x64.zip",
                "linux": "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-linux-x64.tar.gz",
                "darwin": "https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-osx-x64.tar.gz",
            },
        },
        "clangd": {
            "url": "https://github.com/clangd/clangd/releases/download/19.1.0/clangd-windows-19.1.0.zip",
            "type": "zip",
            "description": "C/C++ Language Server (clangd)",
            "platform_specific": True,
            "platforms": {
                "win32": "https://github.com/clangd/clangd/releases/download/19.1.0/clangd-windows-19.1.0.zip",
                "linux": "https://github.com/clangd/clangd/releases/download/19.1.0/clangd-linux-19.1.0.zip",
                "darwin": "https://github.com/clangd/clangd/releases/download/19.1.0/clangd-mac-19.1.0.zip",
            },
        },
        "bash-language-server": {
            "url": "https://registry.npmjs.org/bash-language-server/-/bash-language-server-5.6.0.tgz",
            "type": "tgz",
            "description": "Bash Language Server",
        },
        "solargraph": {
            "url": "https://rubygems.org/downloads/solargraph-0.50.0.gem",
            "type": "gem",
            "description": "Ruby Language Server (Solargraph)",
            "note": "Requires Ruby runtime",
        },
        "intelephense": {
            "url": "https://registry.npmjs.org/intelephense/-/intelephense-1.10.4.tgz",
            "type": "tgz",
            "description": "PHP Language Server (Intelephense)",
        },
        "terraform-ls": {
            "url": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_windows_amd64.zip",
            "type": "zip",
            "description": "Terraform Language Server",
            "platform_specific": True,
            "platforms": {
                "win32": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_windows_amd64.zip",
                "linux": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_linux_amd64.zip",
                "darwin": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_darwin_amd64.zip",
            },
        },
        "elixir-ls": {
            "url": "https://github.com/elixir-lsp/elixir-ls/releases/download/v0.24.1/elixir-ls-v0.24.1.zip",
            "type": "zip",
            "description": "Elixir Language Server",
        },
        "clojure-lsp": {
            "url": "https://github.com/clojure-lsp/clojure-lsp/releases/download/2025.06.13-20.45.44/clojure-lsp-native-windows-amd64.zip",
            "type": "zip",
            "description": "Clojure Language Server",
            "platform_specific": True,
            "platforms": {
                "win32": "https://github.com/clojure-lsp/clojure-lsp/releases/download/2025.06.13-20.45.44/clojure-lsp-native-windows-amd64.zip",
                "linux": "https://github.com/clojure-lsp/clojure-lsp/releases/download/2025.06.13-20.45.44/clojure-lsp-native-linux-amd64.zip",
                "darwin": "https://github.com/clojure-lsp/clojure-lsp/releases/download/2025.06.13-20.45.44/clojure-lsp-native-macos-amd64.zip",
            },
        },
    }


def main():
    # Parse arguments
    import argparse

    parser = argparse.ArgumentParser(description="Download language servers for offline deployment")
    parser.add_argument("--proxy", help="HTTP proxy URL")
    parser.add_argument("--cert", help="CA certificate bundle path")
    parser.add_argument("--output", default="language-servers", help="Output directory")
    parser.add_argument("--servers", nargs="+", help="Specific servers to download")
    args = parser.parse_args()

    # Initialize downloader
    downloader = CorporateDownloader(args.proxy, args.cert)
    validator = LanguageServerValidator()

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get platform
    platform = sys.platform

    # Get servers to download
    all_servers = get_language_servers()
    if args.servers:
        servers = {k: v for k, v in all_servers.items() if k in args.servers}
    else:
        servers = all_servers

    print(f"\nDownloading {len(servers)} language servers to {output_dir}")
    print("=" * 60)

    # Create gopls installer since it doesn't have pre-built binaries
    create_gopls_installer(output_dir)

    print("NOTE: gopls (Go Language Server) is not included as it doesn't provide")
    print("      pre-built binaries. Install it via: go install golang.org/x/tools/gopls@latest")
    print("=" * 60)

    success_count = 0
    
    # Initialize progress tracker for downloads
    progress = ProgressTracker(len(servers), "Downloading language servers")

    for i, (name, info) in enumerate(servers.items()):
        progress.update(i, name)
        server_dir = output_dir / name
        server_dir.mkdir(exist_ok=True)

        # Get platform-specific URL if needed
        if info.get("platform_specific"):
            url = info["platforms"].get(platform, info["url"])
            archive_type = "zip" if platform == "win32" else info["type"]
        else:
            url = info["url"]
            archive_type = info["type"]

        # Download
        archive_name = f"{name}.{archive_type}"
        archive_path = server_dir / archive_name

        if downloader.download_file(url, archive_path, info["description"]):
            # Extract
            if downloader.extract_archive(archive_path, server_dir, archive_type):
                # Run post-extract if defined
                if "post_extract" in info:
                    try:
                        info["post_extract"](server_dir)
                    except:
                        pass

                # Clean up archive
                archive_path.unlink()
                success_count += 1
    
    progress.update(len(servers), "Complete")
    print()

    print("=" * 60)
    print(f"Successfully downloaded {success_count}/{len(servers)} language servers")


    # Create manifest
    manifest = {"version": "1.0", "servers": list(servers.keys()), "platform": platform, "success_count": success_count}

    with open(output_dir / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print("\n" + "=" * 60)
    print("🔍 Validating Language Servers...")
    print("=" * 60)
    
    # Validate all downloaded servers
    validation_results = validator.validate_all_servers(output_dir)
    
    # Generate validation report
    validator.generate_validation_report(validation_results, output_dir / "language-server-validation-report.md")
    
    print("\n" + "=" * 60)
    print("📊 Download & Validation Summary")
    print("=" * 60)
    print(f"Downloaded: {success_count}/{len(servers)} language servers")
    print(f"Validated: {validation_results['valid_servers']}/{validation_results['total_servers']} servers")
    print(f"Total size: {validation_results['total_size'] / 1024 / 1024:.1f} MB")
    print(f"Output directory: {output_dir}")
    
    # Check validation results
    validation_success_rate = validation_results['valid_servers'] / validation_results['total_servers'] if validation_results['total_servers'] > 0 else 0
    
    if validation_success_rate >= 0.9:  # 90% success rate
        print("\n✅ Language servers validated successfully!")
        print(f"📋 Validation report: {output_dir}/language-server-validation-report.md")
    else:
        print(f"\n⚠️  Some servers failed validation (success rate: {validation_success_rate:.1%})")
        print("Please review the validation report for details.")
        
    print("\n🚀 Next Steps:")
    print("1. Copy this directory to target machines for offline deployment")
    print("2. Review validation report for any issues")
    print("3. Test language servers in your development environment")
    
    # Show failed servers if any
    if success_count < len(servers):
        print("\n⚠️  Failed downloads - manual installation required:")
        for name, info in servers.items():
            server_dir = output_dir / name
            if not server_dir.exists() or not any(server_dir.iterdir()):
                print(f"  - {name}: {info['url']}")


if __name__ == "__main__":
    main()
