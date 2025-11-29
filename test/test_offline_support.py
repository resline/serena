"""
Tests for offline support in language servers.

These tests verify that:
1. Language servers correctly detect and use bundled resources
2. Fallback behavior works correctly when bundled resources aren't available
3. The bundled LS path resolution works on all platforms

Usage:
    pytest test/test_offline_support.py -v
    pytest test/test_offline_support.py -v -m offline
"""

import os
import sys
import tempfile
from pathlib import Path
from unittest import mock

import pytest

from solidlsp.language_servers.common import (
    get_bundled_npm_package_path,
    get_node_npm_paths,
    verify_node_npm_available,
)
from solidlsp.settings import SolidLSPSettings

# =============================================================================
# FIXTURES
# =============================================================================


@pytest.fixture
def temp_bundled_dir():
    """Create a temporary directory structure simulating bundled language servers."""
    with tempfile.TemporaryDirectory() as tmpdir:
        # Create bundled language server structure
        ls_dir = Path(tmpdir) / "language_servers"
        ls_dir.mkdir()

        # Create ts-lsp with fake executable
        ts_lsp = ls_dir / "ts-lsp" / "node_modules" / ".bin"
        ts_lsp.mkdir(parents=True)
        ts_exec = ts_lsp / "typescript-language-server"
        ts_exec.touch()
        ts_exec.chmod(0o755)

        # Create yaml-lsp with fake executable
        yaml_lsp = ls_dir / "yaml-lsp" / "node_modules" / ".bin"
        yaml_lsp.mkdir(parents=True)
        yaml_exec = yaml_lsp / "yaml-language-server"
        yaml_exec.touch()
        yaml_exec.chmod(0o755)

        # Create bash-lsp with fake executable
        bash_lsp = ls_dir / "bash-lsp" / "node_modules" / ".bin"
        bash_lsp.mkdir(parents=True)
        bash_exec = bash_lsp / "bash-language-server"
        bash_exec.touch()
        bash_exec.chmod(0o755)

        # Create php-lsp with fake executable
        php_lsp = ls_dir / "php-lsp" / "node_modules" / ".bin"
        php_lsp.mkdir(parents=True)
        php_exec = php_lsp / "intelephense"
        php_exec.touch()
        php_exec.chmod(0o755)

        # Create vts-lsp with fake executable
        vts_lsp = ls_dir / "vts-lsp" / "node_modules" / ".bin"
        vts_lsp.mkdir(parents=True)
        vts_exec = vts_lsp / "vtsls"
        vts_exec.touch()
        vts_exec.chmod(0o755)

        yield tmpdir


@pytest.fixture
def temp_node_dir():
    """Create a temporary directory with fake Node.js binary."""
    with tempfile.TemporaryDirectory() as tmpdir:
        node_dir = Path(tmpdir) / "node"
        node_dir.mkdir()

        # Create fake node binary
        node_name = "node.exe" if sys.platform == "win32" else "node"
        node_exec = node_dir / node_name
        node_exec.touch()
        node_exec.chmod(0o755)

        # Create fake npm binary
        npm_name = "npm.cmd" if sys.platform == "win32" else "npm"
        npm_exec = node_dir / npm_name
        npm_exec.touch()
        npm_exec.chmod(0o755)

        yield tmpdir


@pytest.fixture
def bundled_settings(temp_bundled_dir, temp_node_dir):
    """Create SolidLSPSettings with bundled resources."""
    ls_dir = str(Path(temp_bundled_dir) / "language_servers")
    node_dir = Path(temp_node_dir) / "node"
    node_name = "node.exe" if sys.platform == "win32" else "node"
    node_path = str(node_dir / node_name)

    settings = SolidLSPSettings(
        standalone_mode=True,
        bundled_ls_dir=ls_dir,
        bundled_node_path=node_path,
        allow_download_fallback=False,
    )
    return settings


@pytest.fixture
def non_bundled_settings():
    """Create SolidLSPSettings without bundled resources."""
    settings = SolidLSPSettings(
        standalone_mode=False,
        bundled_ls_dir=None,
        bundled_node_path=None,
        allow_download_fallback=True,
    )
    return settings


# =============================================================================
# BUNDLED PATH RESOLUTION TESTS
# =============================================================================


@pytest.mark.offline
class TestBundledPathResolution:
    """Tests for bundled npm package path resolution."""

    def test_get_bundled_npm_package_path_typescript(self, bundled_settings):
        """Test finding bundled TypeScript language server."""
        path = get_bundled_npm_package_path(
            bundled_settings,
            package_dir_name="ts-lsp",
            binary_name="typescript-language-server",
        )
        assert path is not None
        assert "ts-lsp" in path
        assert "typescript-language-server" in path

    def test_get_bundled_npm_package_path_yaml(self, bundled_settings):
        """Test finding bundled YAML language server."""
        path = get_bundled_npm_package_path(
            bundled_settings,
            package_dir_name="yaml-lsp",
            binary_name="yaml-language-server",
        )
        assert path is not None
        assert "yaml-lsp" in path
        assert "yaml-language-server" in path

    def test_get_bundled_npm_package_path_bash(self, bundled_settings):
        """Test finding bundled Bash language server."""
        path = get_bundled_npm_package_path(
            bundled_settings,
            package_dir_name="bash-lsp",
            binary_name="bash-language-server",
        )
        assert path is not None
        assert "bash-lsp" in path

    def test_get_bundled_npm_package_path_php(self, bundled_settings):
        """Test finding bundled PHP language server (Intelephense)."""
        path = get_bundled_npm_package_path(
            bundled_settings,
            package_dir_name="php-lsp",
            binary_name="intelephense",
        )
        assert path is not None
        assert "php-lsp" in path

    def test_get_bundled_npm_package_path_vts(self, bundled_settings):
        """Test finding bundled VTS language server."""
        path = get_bundled_npm_package_path(
            bundled_settings,
            package_dir_name="vts-lsp",
            binary_name="vtsls",
        )
        assert path is not None
        assert "vts-lsp" in path

    def test_get_bundled_npm_package_path_not_found(self, bundled_settings):
        """Test returns None for non-existent package."""
        path = get_bundled_npm_package_path(
            bundled_settings,
            package_dir_name="nonexistent-lsp",
            binary_name="nonexistent-server",
        )
        assert path is None

    def test_get_bundled_npm_package_path_no_bundled_dir(self, non_bundled_settings):
        """Test returns None when bundled_ls_dir is not set."""
        path = get_bundled_npm_package_path(
            non_bundled_settings,
            package_dir_name="ts-lsp",
            binary_name="typescript-language-server",
        )
        assert path is None


# =============================================================================
# NODE.JS PATH RESOLUTION TESTS
# =============================================================================


@pytest.mark.offline
class TestNodePathResolution:
    """Tests for Node.js and npm path resolution."""

    def test_get_node_npm_paths_with_bundled(self, bundled_settings):
        """Test finding bundled Node.js and npm."""
        node_path, npm_path = get_node_npm_paths(bundled_settings)
        assert node_path is not None
        assert "node" in node_path

    def test_get_node_npm_paths_without_bundled(self, non_bundled_settings):
        """Test fallback to system Node.js when bundled not available."""
        # This test may find system node or return None depending on environment
        node_path, npm_path = get_node_npm_paths(non_bundled_settings)
        # Just verify the function doesn't crash
        # The result depends on whether Node.js is installed on the system

    def test_verify_node_npm_available_with_bundled(self, bundled_settings):
        """Test verification passes with bundled Node.js."""
        node_path, npm_path = verify_node_npm_available(bundled_settings)
        assert node_path is not None
        assert npm_path is not None

    def test_verify_node_npm_available_fails_in_strict_offline(self):
        """Test verification fails in strict offline mode without bundled Node.js."""
        settings = SolidLSPSettings(
            standalone_mode=True,
            bundled_ls_dir=None,
            bundled_node_path=None,
            allow_download_fallback=False,
        )
        with pytest.raises(AssertionError) as exc_info:
            verify_node_npm_available(settings)
        assert "Node.js not found" in str(exc_info.value)


# =============================================================================
# SETTINGS INITIALIZATION TESTS
# =============================================================================


@pytest.mark.offline
class TestSettingsInitialization:
    """Tests for SolidLSPSettings initialization."""

    def test_standalone_mode_from_env_true(self):
        """Test standalone mode detection from environment variable."""
        with mock.patch.dict(os.environ, {"SERENA_STANDALONE": "true"}):
            # Need to re-evaluate the default factory
            from solidlsp.settings import _is_standalone_mode

            assert _is_standalone_mode() is True

    def test_standalone_mode_from_env_1(self):
        """Test standalone mode detection from environment variable (1)."""
        with mock.patch.dict(os.environ, {"SERENA_STANDALONE": "1"}):
            from solidlsp.settings import _is_standalone_mode

            assert _is_standalone_mode() is True

    def test_standalone_mode_from_env_yes(self):
        """Test standalone mode detection from environment variable (yes)."""
        with mock.patch.dict(os.environ, {"SERENA_STANDALONE": "yes"}):
            from solidlsp.settings import _is_standalone_mode

            assert _is_standalone_mode() is True

    def test_standalone_mode_from_env_false(self):
        """Test standalone mode is false when env var is not set."""
        with mock.patch.dict(os.environ, {"SERENA_STANDALONE": ""}):
            from solidlsp.settings import _is_standalone_mode

            assert _is_standalone_mode() is False

    def test_bundled_ls_dir_from_env(self):
        """Test bundled LS dir detection from environment variable."""
        with tempfile.TemporaryDirectory() as tmpdir:
            with mock.patch.dict(os.environ, {"SERENA_BUNDLED_LS_DIR": tmpdir}):
                from solidlsp.settings import _get_bundled_ls_dir

                result = _get_bundled_ls_dir()
                assert result == tmpdir

    def test_bundled_node_from_env(self, temp_node_dir):
        """Test bundled Node.js detection from environment variable."""
        node_dir = Path(temp_node_dir) / "node"
        node_name = "node.exe" if sys.platform == "win32" else "node"
        node_path = str(node_dir / node_name)

        with mock.patch.dict(os.environ, {"SERENA_BUNDLED_NODE": node_path}):
            from solidlsp.settings import _get_bundled_node_path

            result = _get_bundled_node_path()
            assert result == node_path


# =============================================================================
# INTEGRATION TESTS WITH LANGUAGE SERVERS
# =============================================================================


@pytest.mark.offline
class TestLanguageServerOfflineIntegration:
    """Integration tests for language server offline support."""

    def test_typescript_ls_uses_bundled_path(self, bundled_settings):
        """Test TypeScript LS setup finds bundled executable."""
        from solidlsp.language_servers.typescript_language_server import TypeScriptLanguageServer
        from solidlsp.ls_config import Language, LanguageServerConfig

        config = LanguageServerConfig(code_language=Language.TYPESCRIPT)

        # Mock the platform check
        with mock.patch("solidlsp.language_servers.typescript_language_server.PlatformUtils.get_platform_id") as mock_platform:
            from solidlsp.ls_utils import PlatformId

            mock_platform.return_value = PlatformId.LINUX_x64

            cmd = TypeScriptLanguageServer._setup_runtime_dependencies(config, bundled_settings)

            assert "ts-lsp" in cmd[0]
            assert "--stdio" in cmd

    def test_yaml_ls_uses_bundled_path(self, bundled_settings):
        """Test YAML LS setup finds bundled executable."""
        from solidlsp.language_servers.yaml_language_server import YamlLanguageServer
        from solidlsp.ls_config import Language, LanguageServerConfig

        config = LanguageServerConfig(code_language=Language.YAML)

        cmd = YamlLanguageServer._setup_runtime_dependencies(config, bundled_settings)

        assert "yaml-lsp" in cmd
        assert "--stdio" in cmd

    def test_bash_ls_uses_bundled_path(self, bundled_settings):
        """Test Bash LS setup finds bundled executable."""
        from solidlsp.language_servers.bash_language_server import BashLanguageServer
        from solidlsp.ls_config import Language, LanguageServerConfig

        config = LanguageServerConfig(code_language=Language.BASH)

        cmd = BashLanguageServer._setup_runtime_dependencies(config, bundled_settings)

        assert "bash-lsp" in cmd
        assert "start" in cmd

    def test_intelephense_uses_bundled_path(self, bundled_settings):
        """Test Intelephense (PHP) setup finds bundled executable."""
        from solidlsp.language_servers.intelephense import Intelephense
        from solidlsp.ls_utils import PlatformId

        with mock.patch("solidlsp.language_servers.intelephense.PlatformUtils.get_platform_id") as mock_platform:
            mock_platform.return_value = PlatformId.LINUX_x64

            cmd = Intelephense._setup_runtime_dependencies(bundled_settings)

            assert "php-lsp" in cmd[0]
            assert "--stdio" in cmd

    def test_vts_ls_uses_bundled_path(self, bundled_settings):
        """Test VTS LS setup finds bundled executable."""
        from solidlsp.language_servers.vts_language_server import VtsLanguageServer
        from solidlsp.ls_config import Language, LanguageServerConfig
        from solidlsp.ls_utils import PlatformId

        config = LanguageServerConfig(code_language=Language.TYPESCRIPT)

        with mock.patch("solidlsp.language_servers.vts_language_server.PlatformUtils.get_platform_id") as mock_platform:
            mock_platform.return_value = PlatformId.LINUX_x64

            cmd = VtsLanguageServer._setup_runtime_dependencies(config, bundled_settings)

            assert "vts-lsp" in cmd
            assert "--stdio" in cmd


# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================


@pytest.mark.offline
class TestOfflineErrorHandling:
    """Tests for error handling in offline mode."""

    def test_typescript_ls_fails_gracefully_in_strict_offline(self):
        """Test TypeScript LS raises clear error in strict offline mode without bundled resources."""
        from solidlsp.language_servers.typescript_language_server import TypeScriptLanguageServer
        from solidlsp.ls_config import Language, LanguageServerConfig
        from solidlsp.ls_utils import PlatformId

        settings = SolidLSPSettings(
            standalone_mode=True,
            bundled_ls_dir=None,
            bundled_node_path=None,
            allow_download_fallback=False,
        )
        config = LanguageServerConfig(code_language=Language.TYPESCRIPT)

        with mock.patch("solidlsp.language_servers.typescript_language_server.PlatformUtils.get_platform_id") as mock_platform:
            mock_platform.return_value = PlatformId.LINUX_x64

            with pytest.raises(FileNotFoundError) as exc_info:
                TypeScriptLanguageServer._setup_runtime_dependencies(config, settings)

            assert "not found" in str(exc_info.value).lower()
            assert "download is disabled" in str(exc_info.value).lower()

    def test_yaml_ls_fails_gracefully_in_strict_offline(self):
        """Test YAML LS raises clear error in strict offline mode without bundled resources."""
        from solidlsp.language_servers.yaml_language_server import YamlLanguageServer
        from solidlsp.ls_config import Language, LanguageServerConfig

        settings = SolidLSPSettings(
            standalone_mode=True,
            bundled_ls_dir=None,
            bundled_node_path=None,
            allow_download_fallback=False,
        )
        config = LanguageServerConfig(code_language=Language.YAML)

        with pytest.raises(FileNotFoundError) as exc_info:
            YamlLanguageServer._setup_runtime_dependencies(config, settings)

        assert "not found" in str(exc_info.value).lower()
        assert "download is disabled" in str(exc_info.value).lower()


# =============================================================================
# PYTEST CONFIGURATION
# =============================================================================


def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "offline: tests for offline/bundled language server support")
