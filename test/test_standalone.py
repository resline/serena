"""
Pytest tests for standalone executable builds.

These tests verify that standalone builds work correctly when run in CI/CD.
They test basic functionality, resource accessibility, and path handling.

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
    assert "Starts the Serena MCP server" in result.stdout
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
    assert "PyInstaller" not in result.stderr  # No PyInstaller-specific errors


# =============================================================================
# RESOURCE ACCESSIBILITY TESTS
# =============================================================================


@pytest.mark.standalone
def test_contexts_are_bundled(run_exe):
    """Test that context resources are bundled and accessible."""
    result = run_exe(["context", "list"])
    assert result.returncode == 0
    assert "desktop-app" in result.stdout.lower()


@pytest.mark.standalone
def test_modes_are_bundled(run_exe):
    """Test that mode resources are bundled and accessible."""
    result = run_exe(["mode", "list"])
    assert result.returncode == 0
    assert "interactive" in result.stdout.lower()
    assert "editing" in result.stdout.lower()


@pytest.mark.standalone
def test_tools_are_available(run_exe):
    """Test that tools can be listed (tool registry works)."""
    result = run_exe(["tools", "list", "-q"])
    assert result.returncode == 0
    assert len(result.stdout.strip()) > 0


@pytest.mark.standalone
def test_tool_descriptions_accessible(run_exe):
    """Test that tool descriptions can be retrieved."""
    result = run_exe(["tools", "description", "FindSymbol"])
    assert result.returncode == 0
    assert len(result.stdout.strip()) > 0


@pytest.mark.standalone
def test_prompt_templates_bundled(run_exe):
    """Test that prompt templates are accessible."""
    result = run_exe(["prompts", "list"])
    assert result.returncode == 0
    assert len(result.stdout.strip()) > 0


@pytest.mark.standalone
def test_default_context_loads(run_exe):
    """Test that the default context can be loaded successfully."""
    result = run_exe(["tools", "list", "-q"])
    assert result.returncode == 0
    # If context failed to load, would see an error
    assert "error" not in result.stderr.lower()


# =============================================================================
# PATH HANDLING TESTS
# =============================================================================


@pytest.mark.standalone
def test_repo_root_path_frozen_mode(run_exe):
    """Test REPO_ROOT is set correctly in frozen mode."""
    # If REPO_ROOT is wrong, context/mode loading would fail
    result = run_exe(["context", "list"])
    assert result.returncode == 0

    result = run_exe(["mode", "list"])
    assert result.returncode == 0


@pytest.mark.standalone
def test_serena_pkg_path_frozen_mode(run_exe):
    """Test _serena_pkg_path works in frozen mode."""
    # Resources use _serena_pkg_path, so if it's wrong, these would fail
    result = run_exe(["prompts", "list"])
    assert result.returncode == 0


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
# PROJECT COMMANDS TESTS
# =============================================================================


@pytest.mark.standalone
def test_project_commands_available(run_exe):
    """Test project subcommands are available."""
    result = run_exe(["project", "--help"])
    assert result.returncode == 0
    assert "create" in result.stdout.lower()
    assert "index" in result.stdout.lower()


@pytest.mark.standalone
def test_project_create_help(run_exe):
    """Test project create command help."""
    result = run_exe(["project", "create", "--help"])
    assert result.returncode == 0
    assert "--name" in result.stdout
    assert "--language" in result.stdout


# =============================================================================
# ERROR HANDLING TESTS
# =============================================================================


@pytest.mark.standalone
def test_invalid_command_fails_gracefully(run_exe):
    """Test invalid commands produce helpful errors."""
    result = run_exe(["nonexistent-command"])
    assert result.returncode != 0
    # Should have some error message
    assert len(result.stderr) > 0 or "no such" in result.stdout.lower()


@pytest.mark.standalone
def test_invalid_option_fails_gracefully(run_exe):
    """Test invalid options produce helpful errors."""
    result = run_exe(["--nonexistent-option"])
    assert result.returncode != 0


# =============================================================================
# COMMAND INTEGRATION TESTS
# =============================================================================


@pytest.mark.standalone
def test_context_mode_interaction(run_exe):
    """Test that context and mode commands work together."""
    # List contexts
    result = run_exe(["context", "list"])
    assert result.returncode == 0

    # List modes
    result = run_exe(["mode", "list"])
    assert result.returncode == 0

    # Both should work without conflicts


@pytest.mark.standalone
def test_tools_with_context(run_exe):
    """Test tools work with context specification."""
    result = run_exe(["tools", "list", "-q"])
    assert result.returncode == 0
    tools_output = result.stdout

    # Should list multiple tools
    assert len(tools_output.strip().split("\n")) > 1


@pytest.mark.standalone
def test_multiple_subcommands(run_exe):
    """Test that multiple different subcommands work."""
    commands = [
        ["context", "list"],
        ["mode", "list"],
        ["tools", "list", "-q"],
        ["prompts", "list"],
        ["project", "--help"],
    ]

    for cmd in commands:
        result = run_exe(cmd)
        assert result.returncode == 0, f"Command failed: {' '.join(cmd)}"


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
