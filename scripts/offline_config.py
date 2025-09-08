#!/usr/bin/env python3
"""
Offline Configuration Modifier for Serena
==========================================

This script modifies the Serena codebase to work in offline mode by:
1. Patching FileUtils to check for offline cache before attempting downloads
2. Creating offline language server registry for local paths
3. Setting up environment variables and configuration overrides
4. Handling Windows path conventions for offline packages

The script can be:
- Run standalone to patch an existing installation
- Imported by the installer to patch during installation
- Used to revert changes for online mode restoration

Usage:
    python scripts/offline_config.py --enable [--offline-deps-dir DIR] [--verify]
    python scripts/offline_config.py --disable [--verify]
    python scripts/offline_config.py --status

Environment Variables:
    SERENA_OFFLINE_MODE=1       # Enable offline mode
    SERENA_OFFLINE_DEPS_DIR     # Path to offline dependencies directory

Author: Serena Offline Team
License: MIT
"""

import argparse
import json
import logging
import os
import platform
import shutil
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('offline_config.log')
    ]
)
logger = logging.getLogger(__name__)


class OfflineConfigError(Exception):
    """Custom exception for offline configuration errors."""
    pass


class OfflineConfigModifier:
    """Main class for modifying Serena to work in offline mode."""
    
    def __init__(self, serena_root: Optional[str] = None, offline_deps_dir: Optional[str] = None):
        """
        Initialize the offline configuration modifier.
        
        Args:
            serena_root: Path to Serena installation root (auto-detect if None)
            offline_deps_dir: Path to offline dependencies directory
        """
        self.serena_root = Path(serena_root) if serena_root else self._find_serena_root()
        self.offline_deps_dir = Path(offline_deps_dir) if offline_deps_dir else self._find_offline_deps_dir()
        
        # Key file paths
        self.ls_utils_path = self.serena_root / "src" / "solidlsp" / "ls_utils.py"
        self.common_path = self.serena_root / "src" / "solidlsp" / "language_servers" / "common.py"
        self.backup_dir = self.serena_root / ".serena_offline_backups"
        
        # Runtime dependency mappings for offline mode
        self.offline_mappings = self._create_offline_mappings()
        
        logger.info(f"Initialized OfflineConfigModifier:")
        logger.info(f"  Serena root: {self.serena_root}")
        logger.info(f"  Offline deps: {self.offline_deps_dir}")
        logger.info(f"  Backup dir: {self.backup_dir}")
    
    def _find_serena_root(self) -> Path:
        """Auto-detect Serena installation root."""
        # Try current directory first
        current = Path.cwd()
        if (current / "src" / "solidlsp").exists():
            return current
        
        # Try parent directories
        for parent in current.parents:
            if (parent / "src" / "solidlsp").exists():
                return parent
        
        # Try script directory
        script_dir = Path(__file__).parent.parent
        if (script_dir / "src" / "solidlsp").exists():
            return script_dir
        
        raise OfflineConfigError(
            "Could not find Serena root directory. Please specify --serena-root"
        )
    
    def _find_offline_deps_dir(self) -> Optional[Path]:
        """Auto-detect offline dependencies directory."""
        # Check environment variable
        env_path = os.environ.get("SERENA_OFFLINE_DEPS_DIR")
        if env_path and Path(env_path).exists():
            return Path(env_path)
        
        # Check common locations
        potential_dirs = [
            self.serena_root / "offline_deps",
            self.serena_root.parent / "offline_deps",
            Path.cwd() / "offline_deps",
            Path.home() / "serena_offline_deps"
        ]
        
        for path in potential_dirs:
            if path.exists() and (path / "manifest.json").exists():
                return path
        
        return None
    
    def _create_offline_mappings(self) -> Dict[str, Dict]:
        """Create runtime dependency mappings for offline mode."""
        if not self.offline_deps_dir:
            return {}
        
        mappings = {}
        
        # Java Language Server mappings
        mappings["java"] = {
            "gradle": str(self.offline_deps_dir / "gradle" / "extracted" / "gradle-8.14.2"),
            "vscode_java": str(self.offline_deps_dir / "java" / "vscode-java"),
            "intellicode": str(self.offline_deps_dir / "java" / "intellicode")
        }
        
        # C# Language Server mappings  
        mappings["csharp"] = {
            "dotnet_runtime": str(self.offline_deps_dir / "csharp" / "dotnet-runtime"),
            "language_server": str(self.offline_deps_dir / "csharp" / "language-server")
        }
        
        # AL Language Server mappings
        mappings["al"] = {
            "extension": str(self.offline_deps_dir / "al" / "extension")
        }
        
        # TypeScript/Node.js mappings
        mappings["typescript"] = {
            "node_modules": str(self.offline_deps_dir / "typescript" / "node_modules"),
            "nodejs": str(self.offline_deps_dir / "nodejs" / "extracted")
        }
        
        return mappings
    
    def create_backups(self) -> None:
        """Create backups of files that will be modified."""
        logger.info("Creating backups of original files...")
        
        self.backup_dir.mkdir(exist_ok=True)
        
        files_to_backup = [
            self.ls_utils_path,
            self.common_path,
        ]
        
        # Also backup any existing language server files
        language_servers_dir = self.serena_root / "src" / "solidlsp" / "language_servers"
        for ls_file in language_servers_dir.glob("*.py"):
            if ls_file.name not in ["__init__.py", "common.py"]:
                files_to_backup.append(ls_file)
        
        for file_path in files_to_backup:
            if file_path.exists():
                backup_path = self.backup_dir / f"{file_path.name}.backup"
                shutil.copy2(file_path, backup_path)
                logger.debug(f"Backed up: {file_path} -> {backup_path}")
    
    def restore_backups(self) -> None:
        """Restore original files from backups."""
        logger.info("Restoring original files from backups...")
        
        if not self.backup_dir.exists():
            logger.warning("No backup directory found")
            return
        
        for backup_file in self.backup_dir.glob("*.backup"):
            original_name = backup_file.stem
            
            # Find original file location
            if original_name == "ls_utils.py":
                original_path = self.ls_utils_path
            elif original_name == "common.py":
                original_path = self.common_path
            else:
                # Language server file
                original_path = self.serena_root / "src" / "solidlsp" / "language_servers" / original_name
            
            if backup_file.exists() and original_path.exists():
                shutil.copy2(backup_file, original_path)
                logger.debug(f"Restored: {backup_file} -> {original_path}")
    
    def patch_file_utils(self) -> None:
        """Patch FileUtils in ls_utils.py to support offline mode."""
        logger.info("Patching FileUtils for offline mode...")
        
        if not self.ls_utils_path.exists():
            raise OfflineConfigError(f"ls_utils.py not found at {self.ls_utils_path}")
        
        # Read current content
        with open(self.ls_utils_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already patched
        if "SERENA_OFFLINE_MODE" in content:
            logger.info("FileUtils already patched for offline mode")
            return
        
        # Add offline mode imports at the top (after existing imports)
        import_insertion_point = content.find('from solidlsp.ls_exceptions import SolidLSPException')
        if import_insertion_point == -1:
            raise OfflineConfigError("Could not find import insertion point in ls_utils.py")
        
        # Find end of imports section
        lines = content.split('\n')
        import_end_idx = 0
        for i, line in enumerate(lines):
            if line.strip().startswith('from ') or line.strip().startswith('import '):
                import_end_idx = i
        
        # Insert offline mode helper functions after imports
        offline_helpers = '''

# === OFFLINE MODE SUPPORT ===
def check_offline_cache() -> Optional[str]:
    """
    Check if offline cache directory is available.
    
    Returns:
        Path to offline cache directory or None if not available
    """
    offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "").lower() in ("1", "true", "yes", "on")
    if not offline_mode:
        return None
        
    cache_dir = os.environ.get("SERENA_OFFLINE_DEPS_DIR")
    if cache_dir and os.path.exists(cache_dir):
        return cache_dir
    
    # Try to find offline deps in common locations
    potential_dirs = [
        os.path.join(os.getcwd(), "offline_deps"),
        os.path.join(os.path.dirname(__file__), "..", "..", "..", "offline_deps"),
        os.path.join(os.path.expanduser("~"), "serena_offline_deps")
    ]
    
    for potential_dir in potential_dirs:
        if os.path.exists(potential_dir) and os.path.exists(os.path.join(potential_dir, "manifest.json")):
            return potential_dir
    
    return None


def get_offline_file_path(url: str, logger: LanguageServerLogger) -> Optional[str]:
    """
    Get local file path for a URL in offline mode.
    
    Args:
        url: Original URL to download from
        logger: Logger instance
        
    Returns:
        Local file path or None if not available offline
    """
    cache_dir = check_offline_cache()
    if not cache_dir:
        return None
    
    logger.log(f"Checking offline cache for URL: {url}", logging.DEBUG)
    
    # Map URLs to local paths based on known patterns
    url_mappings = {
        # Gradle
        "gradle-8.14.2-bin.zip": os.path.join(cache_dir, "gradle", "gradle-8.14.2-bin.zip"),
        
        # Java Language Server (VS Code Extension)  
        "java-": os.path.join(cache_dir, "java"),
        "vscodeintellicode": os.path.join(cache_dir, "java"),
        
        # C# Language Server and .NET Runtime
        "dotnet-runtime-9.0.6": os.path.join(cache_dir, "csharp"),
        "Microsoft.CodeAnalysis.LanguageServer": os.path.join(cache_dir, "csharp"),
        
        # AL Language Server
        "/al/": os.path.join(cache_dir, "al", "al-latest.vsix"),
        
        # Node.js Runtime
        "nodejs.org": os.path.join(cache_dir, "nodejs"),
    }
    
    for pattern, local_path in url_mappings.items():
        if pattern in url:
            # Check if file or directory exists
            if os.path.exists(local_path):
                logger.log(f"Found offline file for {url}: {local_path}", logging.DEBUG)
                return local_path
            else:
                # Try to find the actual file in the directory
                if os.path.isdir(os.path.dirname(local_path)):
                    for file in os.listdir(os.path.dirname(local_path)):
                        if pattern.replace("-", "").replace(".", "") in file.replace("-", "").replace(".", ""):
                            full_path = os.path.join(os.path.dirname(local_path), file)
                            if os.path.exists(full_path):
                                logger.log(f"Found offline file for {url}: {full_path}", logging.DEBUG)
                                return full_path
    
    logger.log(f"No offline file found for URL: {url}", logging.DEBUG)
    return None


def copy_local_file_to_target(local_path: str, target_path: str, logger: LanguageServerLogger) -> None:
    """
    Copy local file to target location, handling both files and archives.
    
    Args:
        local_path: Source file or directory path
        target_path: Target file path
        logger: Logger instance
    """
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    if os.path.isfile(local_path):
        # Copy file directly
        shutil.copy2(local_path, target_path)
        logger.log(f"Copied offline file: {local_path} -> {target_path}", logging.INFO)
    elif os.path.isdir(local_path):
        # Copy directory contents
        if os.path.exists(target_path):
            shutil.rmtree(target_path)
        shutil.copytree(local_path, target_path)
        logger.log(f"Copied offline directory: {local_path} -> {target_path}", logging.INFO)
    else:
        raise SolidLSPException(f"Offline file not found: {local_path}")
'''
        
        # Insert after imports
        lines.insert(import_end_idx + 1, offline_helpers)
        
        # Patch download_file method
        download_file_start = content.find("def download_file(")
        if download_file_start == -1:
            raise OfflineConfigError("Could not find download_file method")
        
        # Find the method and patch it
        method_lines = []
        in_method = False
        indent_level = 0
        
        for i, line in enumerate(lines):
            if "def download_file(" in line:
                in_method = True
                indent_level = len(line) - len(line.lstrip())
                # Add offline check at the beginning of the method
                method_lines.append(line)
                method_lines.append(" " * (indent_level + 8) + "# Check for offline mode first")
                method_lines.append(" " * (indent_level + 8) + "offline_path = get_offline_file_path(url, logger)")
                method_lines.append(" " * (indent_level + 8) + "if offline_path:")
                method_lines.append(" " * (indent_level + 12) + "copy_local_file_to_target(offline_path, target_path, logger)")
                method_lines.append(" " * (indent_level + 12) + "return")
                method_lines.append("")
                continue
            elif in_method:
                current_indent = len(line) - len(line.lstrip())
                if line.strip() and current_indent <= indent_level:
                    # End of method
                    in_method = False
                    method_lines.append(line)
                else:
                    method_lines.append(line)
            else:
                method_lines.append(line)
        
        # Patch download_and_extract_archive method
        archive_method_start = -1
        for i, line in enumerate(method_lines):
            if "def download_and_extract_archive(" in line:
                archive_method_start = i
                break
        
        if archive_method_start != -1:
            # Find method end and add offline support
            indent_level = len(method_lines[archive_method_start]) - len(method_lines[archive_method_start].lstrip())
            
            # Insert offline check after method signature
            insert_idx = archive_method_start + 3  # Skip docstring
            offline_check_lines = [
                " " * (indent_level + 8) + "# Check for offline mode first", 
                " " * (indent_level + 8) + "offline_path = get_offline_file_path(url, logger)",
                " " * (indent_level + 8) + "if offline_path:",
                " " * (indent_level + 12) + "if os.path.isfile(offline_path):",
                " " * (indent_level + 16) + "# Copy file and extract normally",
                " " * (indent_level + 16) + "copy_local_file_to_target(offline_path, os.path.join(target_path, os.path.basename(offline_path)), logger)",
                " " * (indent_level + 16) + "# Continue with normal extraction logic using the copied file",
                " " * (indent_level + 16) + "tmp_file_name = os.path.join(target_path, os.path.basename(offline_path))",
                " " * (indent_level + 12) + "elif os.path.isdir(offline_path):",
                " " * (indent_level + 16) + "# Copy directory directly",
                " " * (indent_level + 16) + "copy_local_file_to_target(offline_path, target_path, logger)",
                " " * (indent_level + 16) + "return",
                " " * (indent_level + 12) + "else:",
                " " * (indent_level + 16) + "logger.log(f'Offline path exists but is neither file nor directory: {offline_path}', logging.WARNING)",
                ""
            ]
            
            for j, offline_line in enumerate(offline_check_lines):
                method_lines.insert(insert_idx + j, offline_line)
        
        # Write modified content
        with open(self.ls_utils_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(method_lines))
        
        logger.info("Successfully patched FileUtils for offline mode")
    
    def patch_runtime_dependencies(self) -> None:
        """Patch RuntimeDependency class to support offline mode."""
        logger.info("Patching RuntimeDependency for offline mode...")
        
        if not self.common_path.exists():
            raise OfflineConfigError(f"common.py not found at {self.common_path}")
        
        # Read current content
        with open(self.common_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already patched
        if "SERENA_OFFLINE_MODE" in content:
            logger.info("RuntimeDependency already patched for offline mode")
            return
        
        # Add offline mode support to _install_from_url method
        install_method_start = content.find("def _install_from_url(")
        if install_method_start == -1:
            raise OfflineConfigError("Could not find _install_from_url method")
        
        # Find the method and add offline support
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if "def _install_from_url(" in line:
                # Find method body start
                j = i + 1
                while j < len(lines) and (lines[j].strip() == '' or '"""' in lines[j]):
                    j += 1
                
                # Insert offline mode check
                indent = len(lines[j]) - len(lines[j].lstrip())
                offline_lines = [
                    " " * indent + "# Check for offline mode",
                    " " * indent + "offline_mode = os.environ.get('SERENA_OFFLINE_MODE', '').lower() in ('1', 'true', 'yes', 'on')",
                    " " * indent + "if offline_mode:",
                    " " * (indent + 4) + "from solidlsp.ls_utils import get_offline_file_path, copy_local_file_to_target",
                    " " * (indent + 4) + "offline_path = get_offline_file_path(dep.url, logger)",
                    " " * (indent + 4) + "if offline_path:",
                    " " * (indent + 8) + "if dep.archive_type == 'gz' and dep.binary_name:",
                    " " * (indent + 12) + "dest = os.path.join(target_dir, dep.binary_name)",
                    " " * (indent + 12) + "copy_local_file_to_target(offline_path, dest, logger)",
                    " " * (indent + 8) + "else:",
                    " " * (indent + 12) + "copy_local_file_to_target(offline_path, target_dir, logger)",
                    " " * (indent + 8) + "return",
                    ""
                ]
                
                for k, offline_line in enumerate(offline_lines):
                    lines.insert(j + k, offline_line)
                break
        
        # Write modified content
        with open(self.common_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        
        logger.info("Successfully patched RuntimeDependency for offline mode")
    
    def patch_language_servers(self) -> None:
        """Patch individual language server implementations for offline mode."""
        logger.info("Patching language server implementations...")
        
        language_servers_dir = self.serena_root / "src" / "solidlsp" / "language_servers"
        
        # Patch Java Language Server (Eclipse JDTLS)
        self._patch_java_language_server(language_servers_dir / "eclipse_jdtls.py")
        
        # Patch C# Language Server
        self._patch_csharp_language_server(language_servers_dir / "csharp_language_server.py")
        
        # Patch AL Language Server
        self._patch_al_language_server(language_servers_dir / "al_language_server.py")
    
    def _patch_java_language_server(self, file_path: Path) -> None:
        """Patch Java Language Server for offline mode."""
        if not file_path.exists():
            logger.warning(f"Java language server file not found: {file_path}")
            return
        
        logger.info("Patching Java Language Server for offline mode...")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already patched
        if "SERENA_OFFLINE_MODE" in content:
            logger.info("Java Language Server already patched")
            return
        
        # Patch the runtime dependencies setup
        if "gradle" in self.offline_mappings and "java" in self.offline_mappings:
            offline_java_mappings = f"""
        # === OFFLINE MODE OVERRIDE ===
        offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "").lower() in ("1", "true", "yes", "on")
        if offline_mode:
            offline_java_dir = "{self.offline_mappings['java']['vscode_java']}"
            offline_gradle_dir = "{self.offline_mappings['java']['gradle']}"
            offline_intellicode_dir = "{self.offline_mappings['java']['intellicode']}"
            
            if os.path.exists(offline_java_dir) and os.path.exists(offline_gradle_dir):
                logger.log("Using offline Java language server dependencies", logging.INFO)
                
                # Override paths with offline versions
                gradle_path = offline_gradle_dir
                vscode_java_path = offline_java_dir
                intellicode_directory_path = offline_intellicode_dir
                
                # Set up paths based on offline structure
                dependency = runtime_dependencies["vscode-java"][platformId.value]
                jre_home_path = str(PurePath(vscode_java_path, dependency["jre_home_path"]))
                jre_path = str(PurePath(vscode_java_path, dependency["jre_path"]))
                lombok_jar_path = str(PurePath(vscode_java_path, dependency["lombok_jar_path"]))
                jdtls_launcher_jar_path = str(PurePath(vscode_java_path, dependency["jdtls_launcher_jar_path"]))
                jdtls_readonly_config_path = str(PurePath(vscode_java_path, dependency["jdtls_readonly_config_path"]))
                
                dependency = runtime_dependencies["intellicode"]["platform-agnostic"]
                intellicode_jar_path = str(PurePath(intellicode_directory_path, dependency["intellicode_jar_path"]))
                intellisense_members_path = str(PurePath(intellicode_directory_path, dependency["intellisense_members_path"]))
                
                # Verify all paths exist
                required_paths = [gradle_path, jre_home_path, jre_path, lombok_jar_path, 
                                 jdtls_launcher_jar_path, jdtls_readonly_config_path,
                                 intellicode_jar_path, intellisense_members_path]
                
                missing_paths = [p for p in required_paths if not os.path.exists(p)]
                if not missing_paths:
                    # Set executable permissions
                    if platform.system() != "Windows":
                        os.chmod(jre_path, 0o755)
                    
                    return RuntimeDependencyPaths(
                        gradle_path=gradle_path,
                        lombok_jar_path=lombok_jar_path,
                        jre_path=jre_path,
                        jre_home_path=jre_home_path,
                        jdtls_launcher_jar_path=jdtls_launcher_jar_path,
                        jdtls_readonly_config_path=jdtls_readonly_config_path,
                        intellicode_jar_path=intellicode_jar_path,
                        intellisense_members_path=intellisense_members_path,
                    )
                else:
                    logger.log(f"Missing offline Java paths: {{missing_paths}}", logging.WARNING)
        # === END OFFLINE MODE ===
        """
            
            # Insert after platformId assignment
            pattern = "platformId = PlatformUtils.get_platform_id()"
            content = content.replace(pattern, pattern + offline_java_mappings)
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            logger.info("Successfully patched Java Language Server")
    
    def _patch_csharp_language_server(self, file_path: Path) -> None:
        """Patch C# Language Server for offline mode."""
        if not file_path.exists():
            logger.warning(f"C# language server file not found: {file_path}")
            return
        
        logger.info("Patching C# Language Server for offline mode...")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already patched
        if "SERENA_OFFLINE_MODE" in content:
            logger.info("C# Language Server already patched")
            return
        
        # Patch the _ensure_server_installed method
        if "csharp" in self.offline_mappings:
            offline_csharp_code = f"""
        # === OFFLINE MODE OVERRIDE ===
        offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "").lower() in ("1", "true", "yes", "on")
        if offline_mode:
            offline_dotnet = "{self.offline_mappings['csharp']['dotnet_runtime']}"
            offline_langserver = "{self.offline_mappings['csharp']['language_server']}"
            
            if os.path.exists(offline_dotnet) and os.path.exists(offline_langserver):
                logger.log("Using offline C# language server dependencies", logging.INFO)
                
                # Find dotnet executable
                runtime_id = CSharpLanguageServer._get_runtime_id()
                if runtime_id.startswith("win"):
                    dotnet_exe = os.path.join(offline_dotnet, "dotnet.exe")
                else:
                    dotnet_exe = os.path.join(offline_dotnet, "dotnet")
                
                # Find language server DLL
                langserver_dll = None
                for root, dirs, files in os.walk(offline_langserver):
                    for file in files:
                        if file == "Microsoft.CodeAnalysis.LanguageServer.dll":
                            langserver_dll = os.path.join(root, file)
                            break
                    if langserver_dll:
                        break
                
                if os.path.exists(dotnet_exe) and langserver_dll and os.path.exists(langserver_dll):
                    # Set executable permissions on Unix
                    if not runtime_id.startswith("win"):
                        os.chmod(dotnet_exe, 0o755)
                    
                    logger.log(f"Using offline .NET: {{dotnet_exe}}", logging.INFO)
                    logger.log(f"Using offline Language Server: {{langserver_dll}}", logging.INFO)
                    return dotnet_exe, langserver_dll
                else:
                    logger.log("Offline C# dependencies incomplete, falling back to online", logging.WARNING)
        # === END OFFLINE MODE ===
        """
            
            # Insert at the beginning of _ensure_server_installed method
            pattern = 'def _ensure_server_installed('
            insertion_point = content.find(pattern)
            if insertion_point != -1:
                # Find the first line of the method body
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if pattern in line:
                        # Find the first non-comment, non-docstring line
                        j = i + 1
                        while j < len(lines) and (lines[j].strip().startswith('"""') or 
                                                  lines[j].strip().startswith('#') or
                                                  lines[j].strip() == ''):
                            j += 1
                        
                        # Insert offline code
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        offline_lines = offline_csharp_code.strip().split('\n')
                        offline_lines = [' ' * indent + line for line in offline_lines]
                        
                        for k, offline_line in enumerate(offline_lines):
                            lines.insert(j + k, offline_line)
                        break
                
                content = '\n'.join(lines)
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                logger.info("Successfully patched C# Language Server")
    
    def _patch_al_language_server(self, file_path: Path) -> None:
        """Patch AL Language Server for offline mode."""
        if not file_path.exists():
            logger.warning(f"AL language server file not found: {file_path}")
            return
        
        logger.info("Patching AL Language Server for offline mode...")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already patched
        if "SERENA_OFFLINE_MODE" in content:
            logger.info("AL Language Server already patched")
            return
        
        # Patch the _find_al_extension method
        if "al" in self.offline_mappings:
            offline_al_code = f"""
        # === OFFLINE MODE OVERRIDE ===
        offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "").lower() in ("1", "true", "yes", "on")
        if offline_mode:
            offline_al_extension = "{self.offline_mappings['al']['extension']}"
            if os.path.exists(offline_al_extension):
                logger.log(f"Using offline AL extension: {{offline_al_extension}}", level=5)
                return offline_al_extension
            else:
                logger.log("Offline AL extension not found, falling back to normal detection", level=5)
        # === END OFFLINE MODE ===
        """
            
            # Insert at the beginning of _find_al_extension method
            pattern = 'def _find_al_extension('
            insertion_point = content.find(pattern)
            if insertion_point != -1:
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if pattern in line:
                        # Find method body start
                        j = i + 1
                        while j < len(lines) and (lines[j].strip().startswith('"""') or
                                                  lines[j].strip().startswith('#') or
                                                  lines[j].strip() == ''):
                            j += 1
                        
                        # Insert offline code
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        offline_lines = offline_al_code.strip().split('\n')
                        offline_lines = [' ' * indent + line for line in offline_lines]
                        
                        for k, offline_line in enumerate(offline_lines):
                            lines.insert(j + k, offline_line)
                        break
                
                content = '\n'.join(lines)
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                logger.info("Successfully patched AL Language Server")
    
    def create_environment_setup(self) -> None:
        """Create environment setup scripts for offline mode."""
        logger.info("Creating environment setup scripts...")
        
        # Create setup script for Windows
        windows_setup = self.serena_root / "setup_offline_mode.bat"
        windows_content = f"""@echo off
REM Setup Serena for offline mode

echo Setting up Serena for offline mode...

REM Set environment variables
set SERENA_OFFLINE_MODE=1
set SERENA_OFFLINE_DEPS_DIR={self.offline_deps_dir}

REM Set for current session
setx SERENA_OFFLINE_MODE 1
setx SERENA_OFFLINE_DEPS_DIR "{self.offline_deps_dir}"

echo Offline mode configured successfully!
echo.
echo Environment variables set:
echo   SERENA_OFFLINE_MODE=1
echo   SERENA_OFFLINE_DEPS_DIR={self.offline_deps_dir}
echo.
echo You may need to restart your command prompt for changes to take effect.
pause
"""
        
        with open(windows_setup, 'w') as f:
            f.write(windows_content)
        
        # Create setup script for Unix (Linux/macOS)
        unix_setup = self.serena_root / "setup_offline_mode.sh"
        unix_content = f"""#!/bin/bash
# Setup Serena for offline mode

echo "Setting up Serena for offline mode..."

# Export environment variables
export SERENA_OFFLINE_MODE=1
export SERENA_OFFLINE_DEPS_DIR="{self.offline_deps_dir}"

# Add to shell profile
PROFILE_FILE=""
if [ -f ~/.bashrc ]; then
    PROFILE_FILE=~/.bashrc
elif [ -f ~/.zshrc ]; then
    PROFILE_FILE=~/.zshrc
elif [ -f ~/.profile ]; then
    PROFILE_FILE=~/.profile
fi

if [ -n "$PROFILE_FILE" ]; then
    echo "" >> "$PROFILE_FILE"
    echo "# Serena Offline Mode" >> "$PROFILE_FILE"
    echo "export SERENA_OFFLINE_MODE=1" >> "$PROFILE_FILE"
    echo "export SERENA_OFFLINE_DEPS_DIR=\"{self.offline_deps_dir}\"" >> "$PROFILE_FILE"
    echo "Added environment variables to $PROFILE_FILE"
else
    echo "Could not find shell profile file. Please manually add:"
    echo "  export SERENA_OFFLINE_MODE=1"
    echo "  export SERENA_OFFLINE_DEPS_DIR=\"{self.offline_deps_dir}\""
fi

echo "Offline mode configured successfully!"
echo ""
echo "Environment variables set:"
echo "  SERENA_OFFLINE_MODE=1"
echo "  SERENA_OFFLINE_DEPS_DIR={self.offline_deps_dir}"
echo ""
echo "You may need to source your shell profile or restart your terminal."
"""
        
        with open(unix_setup, 'w') as f:
            f.write(unix_content)
        
        # Make Unix script executable
        unix_setup.chmod(0o755)
        
        logger.info("Environment setup scripts created")
    
    def verify_offline_setup(self) -> bool:
        """Verify that offline mode is properly configured."""
        logger.info("Verifying offline mode setup...")
        
        issues = []
        
        # Check if backups exist
        if not self.backup_dir.exists():
            issues.append("No backup directory found")
        
        # Check if files are patched
        with open(self.ls_utils_path, 'r') as f:
            if "SERENA_OFFLINE_MODE" not in f.read():
                issues.append("ls_utils.py not patched for offline mode")
        
        with open(self.common_path, 'r') as f:
            if "SERENA_OFFLINE_MODE" not in f.read():
                issues.append("common.py not patched for offline mode")
        
        # Check offline dependencies
        if not self.offline_deps_dir or not self.offline_deps_dir.exists():
            issues.append("Offline dependencies directory not found")
        else:
            # Check for key dependency files
            required_files = [
                "manifest.json",
                "gradle/gradle-8.14.2-bin.zip",
                "java/vscode-java", 
                "csharp/dotnet-runtime",
                "al/extension"
            ]
            
            for req_file in required_files:
                file_path = self.offline_deps_dir / req_file
                if not file_path.exists():
                    issues.append(f"Missing offline dependency: {req_file}")
        
        # Check environment variables
        offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "").lower()
        if offline_mode not in ("1", "true", "yes", "on"):
            issues.append("SERENA_OFFLINE_MODE environment variable not set")
        
        offline_deps_dir = os.environ.get("SERENA_OFFLINE_DEPS_DIR")
        if not offline_deps_dir:
            issues.append("SERENA_OFFLINE_DEPS_DIR environment variable not set")
        
        if issues:
            logger.error("Offline mode verification failed:")
            for issue in issues:
                logger.error(f"  - {issue}")
            return False
        else:
            logger.info("✅ Offline mode verification passed!")
            return True
    
    def enable_offline_mode(self) -> None:
        """Enable offline mode by applying all patches."""
        logger.info("Enabling offline mode...")
        
        try:
            # Step 1: Create backups
            self.create_backups()
            
            # Step 2: Patch core files
            self.patch_file_utils()
            self.patch_runtime_dependencies()
            
            # Step 3: Patch language server implementations
            self.patch_language_servers()
            
            # Step 4: Create environment setup scripts
            self.create_environment_setup()
            
            logger.info("✅ Offline mode enabled successfully!")
            logger.info("Run the verification to ensure everything is working:")
            logger.info(f"  python {__file__} --verify")
            
        except Exception as e:
            logger.error(f"Failed to enable offline mode: {e}")
            logger.error("Attempting to restore backups...")
            try:
                self.restore_backups()
                logger.info("Backups restored successfully")
            except Exception as restore_error:
                logger.error(f"Failed to restore backups: {restore_error}")
            raise
    
    def disable_offline_mode(self) -> None:
        """Disable offline mode by restoring original files."""
        logger.info("Disabling offline mode...")
        
        try:
            # Restore original files
            self.restore_backups()
            
            # Remove environment setup scripts
            windows_setup = self.serena_root / "setup_offline_mode.bat"
            unix_setup = self.serena_root / "setup_offline_mode.sh"
            
            if windows_setup.exists():
                windows_setup.unlink()
            if unix_setup.exists():
                unix_setup.unlink()
            
            # Remove backup directory
            if self.backup_dir.exists():
                shutil.rmtree(self.backup_dir)
            
            logger.info("✅ Offline mode disabled successfully!")
            logger.info("Don't forget to unset environment variables:")
            logger.info("  SERENA_OFFLINE_MODE")
            logger.info("  SERENA_OFFLINE_DEPS_DIR")
            
        except Exception as e:
            logger.error(f"Failed to disable offline mode: {e}")
            raise
    
    def get_status(self) -> Dict[str, Union[bool, str, List[str]]]:
        """Get current offline mode status."""
        status = {
            "offline_mode_enabled": False,
            "files_patched": [],
            "files_not_patched": [],
            "offline_deps_available": False,
            "offline_deps_path": None,
            "environment_vars": {},
            "missing_dependencies": []
        }
        
        # Check environment variables
        status["environment_vars"] = {
            "SERENA_OFFLINE_MODE": os.environ.get("SERENA_OFFLINE_MODE"),
            "SERENA_OFFLINE_DEPS_DIR": os.environ.get("SERENA_OFFLINE_DEPS_DIR")
        }
        
        offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "").lower()
        status["offline_mode_enabled"] = offline_mode in ("1", "true", "yes", "on")
        
        # Check patched files
        files_to_check = [
            ("ls_utils.py", self.ls_utils_path),
            ("common.py", self.common_path)
        ]
        
        for name, path in files_to_check:
            if path.exists():
                with open(path, 'r') as f:
                    content = f.read()
                    if "SERENA_OFFLINE_MODE" in content:
                        status["files_patched"].append(name)
                    else:
                        status["files_not_patched"].append(name)
            else:
                status["files_not_patched"].append(f"{name} (missing)")
        
        # Check offline dependencies
        if self.offline_deps_dir and self.offline_deps_dir.exists():
            status["offline_deps_available"] = True
            status["offline_deps_path"] = str(self.offline_deps_dir)
            
            # Check specific dependencies
            required_deps = [
                "manifest.json",
                "gradle/gradle-8.14.2-bin.zip",
                "java/vscode-java",
                "csharp/dotnet-runtime", 
                "al/extension"
            ]
            
            for dep in required_deps:
                dep_path = self.offline_deps_dir / dep
                if not dep_path.exists():
                    status["missing_dependencies"].append(dep)
        
        return status
    
    def print_status(self) -> None:
        """Print current offline mode status in a readable format."""
        status = self.get_status()
        
        print("\n" + "="*60)
        print("SERENA OFFLINE MODE STATUS")
        print("="*60)
        
        # Environment
        print(f"🌐 Offline Mode Enabled: {'✅ Yes' if status['offline_mode_enabled'] else '❌ No'}")
        print(f"📁 Serena Root: {self.serena_root}")
        
        # Environment Variables
        print("\n📋 Environment Variables:")
        for var, value in status["environment_vars"].items():
            print(f"   {var}: {value or 'Not set'}")
        
        # File Patches
        print(f"\n🔧 Patched Files ({len(status['files_patched'])}):")
        for file in status["files_patched"]:
            print(f"   ✅ {file}")
        
        if status["files_not_patched"]:
            print(f"\n❌ Non-patched Files ({len(status['files_not_patched'])}):")
            for file in status["files_not_patched"]:
                print(f"   ❌ {file}")
        
        # Offline Dependencies
        print(f"\n💾 Offline Dependencies: {'✅ Available' if status['offline_deps_available'] else '❌ Not Available'}")
        if status["offline_deps_path"]:
            print(f"   Path: {status['offline_deps_path']}")
        
        if status["missing_dependencies"]:
            print(f"\n❌ Missing Dependencies ({len(status['missing_dependencies'])}):")
            for dep in status["missing_dependencies"]:
                print(f"   ❌ {dep}")
        
        # Summary
        print("\n" + "="*60)
        if status["offline_mode_enabled"] and not status["files_not_patched"] and not status["missing_dependencies"]:
            print("🎉 OFFLINE MODE FULLY CONFIGURED")
        elif status["offline_mode_enabled"]:
            print("⚠️  OFFLINE MODE PARTIALLY CONFIGURED")
        else:
            print("🔗 ONLINE MODE ACTIVE")
        print("="*60 + "\n")


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Configure Serena for offline mode",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Enable offline mode with auto-detected dependencies
  python scripts/offline_config.py --enable
  
  # Enable with specific dependencies directory
  python scripts/offline_config.py --enable --offline-deps-dir ./offline_deps
  
  # Disable offline mode (restore original files)
  python scripts/offline_config.py --disable
  
  # Check current status
  python scripts/offline_config.py --status
  
  # Verify offline mode setup
  python scripts/offline_config.py --verify

Environment Variables:
  SERENA_OFFLINE_MODE=1           # Enable offline mode
  SERENA_OFFLINE_DEPS_DIR         # Path to offline dependencies directory
        """
    )
    
    parser.add_argument(
        "--enable",
        action="store_true",
        help="Enable offline mode by patching Serena files"
    )
    
    parser.add_argument(
        "--disable", 
        action="store_true",
        help="Disable offline mode by restoring original files"
    )
    
    parser.add_argument(
        "--status",
        action="store_true",
        help="Show current offline mode status"
    )
    
    parser.add_argument(
        "--verify",
        action="store_true",
        help="Verify offline mode setup"
    )
    
    parser.add_argument(
        "--serena-root",
        help="Path to Serena installation root (auto-detect if not specified)"
    )
    
    parser.add_argument(
        "--offline-deps-dir",
        help="Path to offline dependencies directory"
    )
    
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Set logging level"
    )
    
    args = parser.parse_args()
    
    # Set log level
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    try:
        # Initialize modifier
        modifier = OfflineConfigModifier(
            serena_root=args.serena_root,
            offline_deps_dir=args.offline_deps_dir
        )
        
        # Execute requested action
        if args.enable:
            if not modifier.offline_deps_dir:
                logger.error("No offline dependencies directory found. Please:")
                logger.error("1. Run the offline dependencies downloader first")
                logger.error("2. Set SERENA_OFFLINE_DEPS_DIR environment variable")
                logger.error("3. Use --offline-deps-dir parameter")
                sys.exit(1)
            
            modifier.enable_offline_mode()
            
        elif args.disable:
            modifier.disable_offline_mode()
            
        elif args.verify:
            success = modifier.verify_offline_setup()
            sys.exit(0 if success else 1)
            
        elif args.status:
            modifier.print_status()
            
        else:
            # Default to showing status
            modifier.print_status()
            
    except OfflineConfigError as e:
        logger.error(f"Configuration error: {e}")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        logger.debug("Full traceback:", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()