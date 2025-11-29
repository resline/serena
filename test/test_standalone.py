"""
Pytest tests for standalone executable builds.

These tests verify that standalone builds work correctly when run in CI/CD.
They test basic functionality and path handling.

Usage:
    pytest test/test_standalone.py -v
    pytest test/test_standalone.py -v --standalone-exe=dist/serena-mcp-server

Note: These tests require a standalone executable to be built first.
Run `pyinstaller serena.spec --clean` to build before testing.
"""

import os
import subprocess
import tempfile
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def standalone_exe(request) -> Path:
    """Fixture providing path to standalone executable."""

    def get_executable() -> Path | None:
        """
        Find the standalone executable to test.

        Search order:
        1. --standalone-exe pytest option
        2. SERENA_STANDALONE_EXE environment variable
        3. dist/serena-mcp-server (Linux/macOS)
        4. dist/serena-mcp-server.exe (Windows)

        Returns None if no executable is found.
        """
        # Check pytest option
        exe_path = request.config.getoption("--standalone-exe", default=None)
        if exe_path:
            path = Path(exe_path)
            if path.exists():
                return path

        # Check environment variable
        env_exe = os.environ.get("SERENA_STANDALONE_EXE")
        if env_exe:
            path = Path(env_exe)
            if path.exists():
                return path

        # Check default locations
        repo_root = Path(__file__).parent.parent
        candidates = [
            repo_root / "dist" / "serena-mcp-server",
            repo_root / "dist" / "serena-mcp-server.exe",
        ]

        for candidate in candidates:
            if candidate.exists():
                return candidate

        return None

    exe = get_executable()
    if exe is None:
        pytest.skip("Standalone executable not found. Build it with: pyinstaller serena.spec --clean")
    return exe


@pytest.fixture
def run_exe(standalone_exe: Path):
    """Fixture providing a function to run the standalone executable."""

    def _run(args: list[str], timeout: int = 30, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        cmd = [str(standalone_exe)] + args
        full_env = os.environ.copy()
        if env:
            full_env.update(env)

        return subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=full_env,
        )

    return _run


# =============================================================================
# BASIC FUNCTIONALITY TESTS
# =============================================================================


@pytest.mark.standalone
def test_help_command(run_exe):
    """Test --help shows usage information."""
    result = run_exe(["--help"])
    assert result.returncode == 0
    assert "serena mcp server" in result.stdout.lower()
    assert "--project" in result.stdout
    assert "--context" in result.stdout
    assert "--mode" in result.stdout


@pytest.mark.standalone
def test_executable_starts_without_import_errors(run_exe):
    """Test executable starts without Python import errors."""
    result = run_exe(["--help"], timeout=10)
    assert result.returncode == 0
    assert "ModuleNotFoundError" not in result.stderr
    assert "ImportError" not in result.stderr


@pytest.mark.standalone
def test_no_python_path_errors(run_exe):
    """Test that frozen path handling works (no _MEIPASS errors)."""
    result = run_exe(["--help"])
    assert result.returncode == 0
    assert "_MEIPASS" not in result.stderr
    # No PyInstaller-specific errors visible to user
    error_indicators = [
        "ModuleNotFoundError",
        "ImportError",
        "FileNotFoundError",
        "No module named",
        "cannot import name",
    ]
    for indicator in error_indicators:
        assert indicator not in result.stderr, f"Found '{indicator}' in stderr"


# =============================================================================
# PATH HANDLING TESTS
# =============================================================================


@pytest.mark.standalone
def test_frozen_mode_detection(run_exe):
    """Test that frozen mode is detected correctly."""
    result = run_exe(["--help"])
    assert result.returncode == 0
    # No errors about PyInstaller internals
    assert "_MEIPASS" not in result.stderr


# =============================================================================
# CONFIGURATION AND ENVIRONMENT TESTS
# =============================================================================


@pytest.mark.standalone
def test_standalone_mode_env_var_true(run_exe):
    """Test SERENA_STANDALONE=true environment variable."""
    result = run_exe(["--help"], env={"SERENA_STANDALONE": "true"})
    assert result.returncode == 0


@pytest.mark.standalone
def test_standalone_mode_env_var_1(run_exe):
    """Test SERENA_STANDALONE=1 environment variable."""
    result = run_exe(["--help"], env={"SERENA_STANDALONE": "1"})
    assert result.returncode == 0


@pytest.mark.standalone
def test_home_directory_override(run_exe):
    """Test that HOME directory can be overridden."""
    with tempfile.TemporaryDirectory() as tmpdir:
        env = {
            "HOME": tmpdir,
            "USERPROFILE": tmpdir,  # Windows
        }
        result = run_exe(["--help"], env=env)
        assert result.returncode == 0


# =============================================================================
# CLI OPTIONS TESTS
# =============================================================================


@pytest.mark.standalone
def test_cli_options_present(run_exe):
    """Test all expected CLI options are present."""
    result = run_exe(["--help"])
    assert result.returncode == 0

    expected_options = [
        "--project",
        "--context",
        "--mode",
        "--transport",
        "--host",
        "--port",
        "--help",
    ]

    for option in expected_options:
        assert option in result.stdout, f"Option '{option}' not found in help"


@pytest.mark.standalone
def test_transport_options_documented(run_exe):
    """Test that transport protocol options are documented."""
    result = run_exe(["--help"])
    assert result.returncode == 0
    assert "stdio" in result.stdout.lower()


# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================


@pytest.mark.standalone
def test_invalid_option_fails_gracefully(run_exe):
    """Test invalid options produce helpful errors."""
    result = run_exe(["--nonexistent-option-xyz"])
    assert result.returncode != 0
    assert "error" in result.stderr.lower() or "no such option" in result.stderr.lower()


# =============================================================================
# PYTEST CONFIGURATION
# =============================================================================


def pytest_addoption(parser):
    """Add custom pytest options."""
    parser.addoption(
        "--standalone-exe",
        action="store",
        default=None,
        help="Path to standalone executable to test",
    )


def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "standalone: tests for standalone executable builds (requires built executable)")
