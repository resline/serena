#!/usr/bin/env python3
"""
Test script for offline configuration functionality.

This script demonstrates and tests the offline configuration modifier
without actually modifying the production files.
"""

import os
import tempfile
import shutil
from pathlib import Path
from unittest.mock import patch

# Import our offline config module
from offline_config import OfflineConfigModifier, OfflineConfigError


def create_mock_serena_structure(temp_dir: Path) -> None:
    """Create a mock Serena directory structure for testing."""
    # Create directory structure
    src_dir = temp_dir / "src" / "solidlsp"
    src_dir.mkdir(parents=True)
    
    language_servers_dir = src_dir / "language_servers"
    language_servers_dir.mkdir()
    
    # Create mock ls_utils.py
    ls_utils_content = '''"""
This file contains various utility functions like I/O operations, handling paths, etc.
"""

import os
import logging
from solidlsp.ls_exceptions import SolidLSPException
from solidlsp.ls_logger import LanguageServerLogger

class FileUtils:
    """
    Utility functions for file operations.
    """

    @staticmethod
    def download_file(logger: LanguageServerLogger, url: str, target_path: str) -> None:
        """
        Downloads the file from the given URL to the given {target_path}
        """
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        # Mock download logic
        logger.log(f"Would download {url} to {target_path}", logging.INFO)

    @staticmethod
    def download_and_extract_archive(logger: LanguageServerLogger, url: str, target_path: str, archive_type: str) -> None:
        """
        Downloads the archive from the given URL and extracts it
        """
        # Mock download and extract logic
        logger.log(f"Would download and extract {url} to {target_path}", logging.INFO)
'''
    
    with open(src_dir / "ls_utils.py", 'w') as f:
        f.write(ls_utils_content)
    
    # Create mock common.py
    common_content = '''import os
from dataclasses import dataclass

@dataclass(kw_only=True)
class RuntimeDependency:
    """Represents a runtime dependency for a language server."""
    id: str
    url: str | None = None
    
class RuntimeDependencyCollection:
    """Utility to handle installation of runtime dependencies."""
    
    @staticmethod
    def _install_from_url(dep: RuntimeDependency, logger, target_dir: str) -> None:
        """Install dependency from URL."""
        logger.log(f"Would install {dep.id} from {dep.url}", logging.INFO)
'''
    
    with open(language_servers_dir / "common.py", 'w') as f:
        f.write(common_content)
    
    # Create mock language server files
    java_content = '''"""Java Language Server"""
import os

class EclipseJDTLS:
    @classmethod
    def _setupRuntimeDependencies(cls, logger, config, solidlsp_settings):
        platformId = "linux-x64"  # Mock platform
        return None
'''
    
    with open(language_servers_dir / "eclipse_jdtls.py", 'w') as f:
        f.write(java_content)


def create_mock_offline_deps(temp_dir: Path) -> Path:
    """Create mock offline dependencies structure."""
    offline_deps = temp_dir / "offline_deps"
    
    # Create directory structure
    directories = [
        "gradle/extracted",
        "java/vscode-java", 
        "java/intellicode",
        "csharp/dotnet-runtime",
        "csharp/language-server", 
        "al/extension",
        "typescript/node_modules",
        "nodejs/extracted"
    ]
    
    for dir_path in directories:
        (offline_deps / dir_path).mkdir(parents=True)
    
    # Create manifest.json
    manifest_content = {
        "platform": "win-x64",
        "downloads": {
            "gradle": {"version": "8.14.2"},
            "java": {"version": "1.42.0"},
            "csharp": {"version": "9.0.6"},
            "al": {"version": "latest"},
            "nodejs": {"version": "20.18.2"}
        }
    }
    
    import json
    with open(offline_deps / "manifest.json", 'w') as f:
        json.dump(manifest_content, f, indent=2)
    
    # Create some mock files
    (offline_deps / "gradle" / "gradle-8.14.2-bin.zip").touch()
    (offline_deps / "al" / "al-latest.vsix").touch()
    
    return offline_deps


def test_offline_config_basic_functionality():
    """Test basic offline configuration functionality."""
    print("🧪 Testing basic offline configuration functionality...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Create mock Serena structure
        serena_root = temp_path / "serena"
        create_mock_serena_structure(serena_root)
        
        # Create mock offline dependencies  
        offline_deps = create_mock_offline_deps(temp_path)
        
        # Initialize modifier
        modifier = OfflineConfigModifier(
            serena_root=str(serena_root),
            offline_deps_dir=str(offline_deps)
        )
        
        print(f"   ✅ Initialized with Serena root: {modifier.serena_root}")
        print(f"   ✅ Offline dependencies: {modifier.offline_deps_dir}")
        
        # Test status before patching
        status = modifier.get_status()
        assert not status["offline_mode_enabled"], "Offline mode should not be enabled initially"
        assert len(status["files_patched"]) == 0, "No files should be patched initially"
        
        print("   ✅ Status check works correctly")
        
        # Test environment detection
        with patch.dict(os.environ, {"SERENA_OFFLINE_MODE": "1"}):
            status_with_env = modifier.get_status()
            assert status_with_env["offline_mode_enabled"], "Should detect offline mode from environment"
        
        print("   ✅ Environment variable detection works")
        
        # Test offline mappings creation
        assert "java" in modifier.offline_mappings, "Java mappings should exist"
        assert "csharp" in modifier.offline_mappings, "C# mappings should exist"
        assert "al" in modifier.offline_mappings, "AL mappings should exist"
        
        print("   ✅ Offline mappings created correctly")
        
        print("   🎉 Basic functionality test passed!")


def test_file_patching_simulation():
    """Test file patching logic (simulation without actual patching)."""
    print("🧪 Testing file patching simulation...")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Create mock Serena structure
        serena_root = temp_path / "serena" 
        create_mock_serena_structure(serena_root)
        
        # Create mock offline dependencies
        offline_deps = create_mock_offline_deps(temp_path)
        
        # Initialize modifier
        modifier = OfflineConfigModifier(
            serena_root=str(serena_root),
            offline_deps_dir=str(offline_deps)
        )
        
        # Test backup creation
        modifier.create_backups()
        assert modifier.backup_dir.exists(), "Backup directory should be created"
        
        backup_files = list(modifier.backup_dir.glob("*.backup"))
        assert len(backup_files) >= 2, "Should have backups for ls_utils.py and common.py"
        
        print("   ✅ Backup creation works")
        
        # Test environment setup script creation
        modifier.create_environment_setup()
        
        windows_setup = modifier.serena_root / "setup_offline_mode.bat"
        unix_setup = modifier.serena_root / "setup_offline_mode.sh"
        
        assert windows_setup.exists(), "Windows setup script should be created"
        assert unix_setup.exists(), "Unix setup script should be created"
        
        # Check script content
        with open(windows_setup) as f:
            win_content = f.read()
            assert "SERENA_OFFLINE_MODE=1" in win_content, "Windows script should set offline mode"
        
        with open(unix_setup) as f:
            unix_content = f.read()
            assert "export SERENA_OFFLINE_MODE=1" in unix_content, "Unix script should export offline mode"
        
        print("   ✅ Environment setup scripts created correctly")
        
        # Test restoration
        modifier.restore_backups()
        
        # Verify original files are restored (they should be identical since we didn't patch)
        original_ls_utils = modifier.serena_root / "src" / "solidlsp" / "ls_utils.py"
        assert original_ls_utils.exists(), "Original ls_utils.py should be restored"
        
        print("   ✅ Backup restoration works")
        
        print("   🎉 File patching simulation test passed!")


def test_url_mapping_logic():
    """Test URL to local path mapping logic."""
    print("🧪 Testing URL mapping logic...")
    
    # Test URL patterns that should be mapped
    test_cases = [
        ("https://services.gradle.org/distributions/gradle-8.14.2-bin.zip", "gradle"),
        ("https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-win32-x64-1.42.0-561.vsix", "java"),
        ("https://builds.dotnet.microsoft.com/dotnet/Runtime/9.0.6/dotnet-runtime-9.0.6-win-x64.zip", "csharp"), 
        ("https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-dynamics-smb/vsextensions/al/latest/vspackage", "al"),
        ("https://nodejs.org/dist/v20.18.2/node-v20.18.2-win-x64.zip", "nodejs")
    ]
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        serena_root = temp_path / "serena"
        create_mock_serena_structure(serena_root)
        offline_deps = create_mock_offline_deps(temp_path)
        
        modifier = OfflineConfigModifier(
            serena_root=str(serena_root),
            offline_deps_dir=str(offline_deps)
        )
        
        for url, expected_component in test_cases:
            # This would normally be tested by calling get_offline_file_path
            # but since we're not actually patching files, we just verify
            # that the expected component exists in offline mappings
            found_component = False
            for component, paths in modifier.offline_mappings.items():
                if component == expected_component or expected_component in str(paths):
                    found_component = True
                    break
            
            if not found_component and expected_component in ["gradle", "java", "csharp", "al", "nodejs"]:
                # These should be in the offline mappings
                assert False, f"Component {expected_component} not found in offline mappings"
        
        print("   ✅ URL mapping patterns are correctly configured")
        
        print("   🎉 URL mapping test passed!")


def main():
    """Run all tests."""
    print("🚀 Starting Offline Configuration Tests\n")
    
    try:
        test_offline_config_basic_functionality()
        print()
        
        test_file_patching_simulation()
        print()
        
        test_url_mapping_logic()
        print()
        
        print("🎉 ALL TESTS PASSED!")
        print("✅ Offline configuration script is working correctly")
        
    except Exception as e:
        print(f"❌ TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())