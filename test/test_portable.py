"""Tests for portable mode functionality."""

import os
import platform
import stat
import subprocess
import sys
from pathlib import Path

import pytest

from serena.portable import (
    get_language_server_dir,
    get_portable_root,
    get_serena_data_dir,
    get_solidlsp_data_dir,
    is_portable_mode,
)


class TestPortableModeDetection:
    """Test portable mode detection functionality."""

    def test_portable_mode_detection(self):
        """Test portable mode is detected correctly."""
        # Save original state
        original = os.environ.get("SERENA_PORTABLE_DIR")

        try:
            # Without env var
            if "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]
            assert not is_portable_mode()

            # With env var
            os.environ["SERENA_PORTABLE_DIR"] = "/tmp/serena-portable"
            assert is_portable_mode()
            assert get_portable_root() == Path("/tmp/serena-portable")
        finally:
            # Restore original state
            if original:
                os.environ["SERENA_PORTABLE_DIR"] = original
            elif "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]

    def test_portable_data_dirs(self, tmp_path):
        """Test data directories in portable mode."""
        # Save original state
        original = os.environ.get("SERENA_PORTABLE_DIR")

        try:
            portable_dir = tmp_path / "serena-portable"
            portable_dir.mkdir()
            os.environ["SERENA_PORTABLE_DIR"] = str(portable_dir)

            serena_dir = get_serena_data_dir()
            assert str(serena_dir).startswith(str(portable_dir / "data"))

            solidlsp_dir = get_solidlsp_data_dir()
            assert str(solidlsp_dir).startswith(str(portable_dir / "data"))

            ls_dir = get_language_server_dir()
            assert "language_servers" in str(ls_dir)
            assert "static" in str(ls_dir)
        finally:
            # Restore original state
            if original:
                os.environ["SERENA_PORTABLE_DIR"] = original
            elif "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]

    def test_normal_mode_data_dirs(self):
        """Test data directories in normal mode."""
        # Save original state
        original = os.environ.get("SERENA_PORTABLE_DIR")

        try:
            # Ensure no portable mode
            if "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]

            serena_dir = get_serena_data_dir()
            assert ".serena" in str(serena_dir)

            solidlsp_dir = get_solidlsp_data_dir()
            assert ".solidlsp" in str(solidlsp_dir)
        finally:
            # Restore original state
            if original:
                os.environ["SERENA_PORTABLE_DIR"] = original


class TestPlatformDetection:
    """Test platform-specific detection and behavior."""

    def test_platform_detection(self):
        """Test that platform is correctly detected."""
        detected_platform = platform.system()
        assert detected_platform in ["Windows", "Linux", "Darwin"]

    def test_python_executable_path(self):
        """Test Python executable path is correct."""
        python_exe = sys.executable
        assert Path(python_exe).exists()
        assert python_exe.endswith(("python3", ".exe"))

    @pytest.mark.skipif(platform.system() != "Windows", reason="Windows-only test")
    def test_windows_platform(self):
        """Test Windows-specific behaviors."""
        assert platform.system() == "Windows"
        assert sys.executable.endswith(".exe")

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_unix_platform(self):
        """Test Unix/Linux-specific behaviors."""
        assert platform.system() in ["Linux", "Darwin"]
        assert not sys.executable.endswith(".exe")


class TestPlatformSpecificLaunchers:
    """Test platform-specific launcher scripts."""

    @pytest.mark.skipif(platform.system() != "Windows", reason="Windows-only test")
    def test_windows_batch_launcher(self, tmp_path):
        """Test Windows .bat launcher functionality."""
        launcher = tmp_path / "test.bat"
        launcher.write_text(
            """@echo off
setlocal
echo Hello from batch
exit /b 0
"""
        )

        result = subprocess.run(
            ["cmd", "/c", str(launcher)],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "Hello from batch" in result.stdout

    @pytest.mark.skipif(platform.system() != "Windows", reason="Windows-only test")
    def test_windows_batch_environment_variables(self, tmp_path):
        """Test that batch files can access environment variables."""
        launcher = tmp_path / "test.bat"
        launcher.write_text(
            """@echo off
setlocal
set "TEST_VAR=test_value"
echo %TEST_VAR%
"""
        )

        result = subprocess.run(
            ["cmd", "/c", str(launcher)],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "test_value" in result.stdout

    @pytest.mark.skipif(platform.system() != "Windows", reason="Windows-only test")
    def test_windows_path_with_spaces(self, tmp_path):
        """Test Windows path handling with spaces."""
        space_dir = tmp_path / "dir with spaces"
        space_dir.mkdir()
        launcher = space_dir / "test.bat"
        launcher.write_text(
            """@echo off
echo Test path
"""
        )

        result = subprocess.run(
            ["cmd", "/c", str(launcher)],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "Test path" in result.stdout

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_unix_shell_launcher(self, tmp_path):
        """Test Unix shell launcher functionality."""
        launcher = tmp_path / "test.sh"
        launcher.write_text(
            """#!/usr/bin/env bash
echo "Hello from shell"
exit 0
"""
        )
        launcher.chmod(launcher.stat().st_mode | stat.S_IXUSR)

        result = subprocess.run(
            [str(launcher)],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "Hello from shell" in result.stdout

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_unix_executable_bit(self, tmp_path):
        """Test that executables have proper permissions."""
        script = tmp_path / "test.sh"
        script.write_text("#!/bin/bash\necho test\n")

        # Initially not executable
        assert not (script.stat().st_mode & stat.S_IXUSR)

        # Make executable
        script.chmod(script.stat().st_mode | stat.S_IXUSR)
        assert script.stat().st_mode & stat.S_IXUSR

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_unix_path_with_spaces(self, tmp_path):
        """Test Unix path handling with spaces."""
        space_dir = tmp_path / "dir with spaces"
        space_dir.mkdir()
        launcher = space_dir / "test.sh"
        launcher.write_text(
            """#!/usr/bin/env bash
echo "Test path"
"""
        )
        launcher.chmod(launcher.stat().st_mode | stat.S_IXUSR)

        result = subprocess.run(
            [str(launcher)],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "Test path" in result.stdout


class TestPathHandling:
    """Test cross-platform path handling."""

    def test_path_with_spaces(self, tmp_path):
        """Test that paths with spaces are handled correctly."""
        space_dir = tmp_path / "dir with spaces"
        space_dir.mkdir()
        assert space_dir.exists()

    def test_path_with_special_characters(self, tmp_path):
        """Test path handling with special characters."""
        if platform.system() == "Windows":
            special_chars = ["test_dir", "test-dir"]
        else:
            special_chars = ["test_dir", "test-dir", "test.dir"]

        for char_name in special_chars:
            test_dir = tmp_path / char_name
            test_dir.mkdir(exist_ok=True)
            assert test_dir.exists()

    def test_absolute_path_resolution(self, tmp_path):
        """Test that paths are correctly resolved."""
        test_file = tmp_path / "test.txt"
        test_file.write_text("test")

        resolved = test_file.resolve()
        assert resolved.is_absolute()
        assert resolved.exists()


class TestRuntimeExecution:
    """Test runtime execution capabilities."""

    def test_python_execution(self):
        """Test that Python can execute simple code."""
        result = subprocess.run(
            [sys.executable, "-c", "print('test')"],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "test" in result.stdout

    def test_python_module_import(self):
        """Test that Python can import modules."""
        result = subprocess.run(
            [sys.executable, "-c", "import sys; import os"],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_environment_variable_inheritance(self):
        """Test that environment variables are inherited."""
        env = os.environ.copy()
        env["TEST_VAR"] = "test_value"

        result = subprocess.run(
            [sys.executable, "-c", "import os; print(os.environ.get('TEST_VAR'))"],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )
        assert result.returncode == 0
        assert "test_value" in result.stdout

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_signal_handling(self):
        """Test that processes handle signals correctly."""
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                "import signal; signal.signal(signal.SIGTERM, signal.SIG_DFL); print('ready')",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "ready" in result.stdout

    def test_subprocess_exit_code(self):
        """Test that exit codes are correctly propagated."""
        result = subprocess.run(
            [sys.executable, "-c", "exit(42)"],
            check=False,
            capture_output=True,
        )
        assert result.returncode == 42

    def test_subprocess_output_capture(self):
        """Test that subprocess output is correctly captured."""
        result = subprocess.run(
            [sys.executable, "-c", "import sys; print('stdout'); print('stderr', file=sys.stderr)"],
            check=False,
            capture_output=True,
            text=True,
        )
        assert "stdout" in result.stdout
        assert "stderr" in result.stderr


class TestFileSystemOperations:
    """Test file system operations in portable context."""

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_executable_permissions(self, tmp_path):
        """Test setting and verifying executable permissions."""
        script = tmp_path / "script.sh"
        script.write_text("#!/bin/bash\necho test\n")

        # Set executable
        script.chmod(0o755)

        # Verify it's executable
        assert script.stat().st_mode & stat.S_IXUSR

    @pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
    def test_symlink_support(self, tmp_path):
        """Test symlink handling on Unix systems."""
        original = tmp_path / "original.txt"
        original.write_text("test")

        link = tmp_path / "link.txt"
        link.symlink_to(original)

        assert link.is_symlink()
        assert link.resolve() == original.resolve()

    def test_directory_traversal(self, tmp_path):
        """Test directory traversal and access."""
        nested = tmp_path / "a" / "b" / "c"
        nested.mkdir(parents=True)

        assert nested.exists()
        assert nested.parent.exists()
        assert nested.parent.parent.exists()

    def test_file_encoding(self, tmp_path):
        """Test file encoding handling."""
        test_file = tmp_path / "test.txt"
        test_content = "test with unicode: 你好"
        test_file.write_text(test_content, encoding="utf-8")

        read_content = test_file.read_text(encoding="utf-8")
        assert read_content == test_content


class TestPortablePathResolution:
    """Test path resolution in portable mode."""

    def test_portable_root_resolution(self, tmp_path):
        """Test portable root path resolution."""
        original = os.environ.get("SERENA_PORTABLE_DIR")

        try:
            os.environ["SERENA_PORTABLE_DIR"] = str(tmp_path)
            root = get_portable_root()
            assert root is not None
            assert root == tmp_path.resolve()
        finally:
            if original:
                os.environ["SERENA_PORTABLE_DIR"] = original
            elif "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]

    def test_portable_data_dir_creation(self, tmp_path):
        """Test that portable data directories are created."""
        original = os.environ.get("SERENA_PORTABLE_DIR")

        try:
            portable_dir = tmp_path / "portable"
            portable_dir.mkdir()
            os.environ["SERENA_PORTABLE_DIR"] = str(portable_dir)

            data_dir = get_serena_data_dir()
            assert data_dir.exists()
            assert ".serena" in str(data_dir)
        finally:
            if original:
                os.environ["SERENA_PORTABLE_DIR"] = original
            elif "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]

    def test_language_server_dir_portable(self, tmp_path):
        """Test language server directory in portable mode."""
        original = os.environ.get("SERENA_PORTABLE_DIR")

        try:
            portable_dir = tmp_path / "portable"
            portable_dir.mkdir()
            os.environ["SERENA_PORTABLE_DIR"] = str(portable_dir)

            ls_dir = get_language_server_dir()
            assert "language_servers" in str(ls_dir)
        finally:
            if original:
                os.environ["SERENA_PORTABLE_DIR"] = original
            elif "SERENA_PORTABLE_DIR" in os.environ:
                del os.environ["SERENA_PORTABLE_DIR"]
