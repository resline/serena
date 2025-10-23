"""E2E tests for standalone executables.

This module tests the basic functionality of standalone Serena executables:
- serena.exe
- serena-mcp-server.exe
- index-project.exe
"""

import os
import time

import pytest

from test.e2e.standalone_utils import StandaloneTestEnv, verify_build_structure


@pytest.mark.e2e
@pytest.mark.standalone
class TestStandaloneExecutables:
    """Tests for standalone executable basic functionality."""

    def test_all_executables_exist(self, standalone_env: StandaloneTestEnv) -> None:
        """Verify all expected executables are present."""
        results = standalone_env.verify_executables_exist()

        assert results["serena"], "serena executable not found"
        assert results["serena-mcp-server"], "serena-mcp-server executable not found"
        assert results["index-project"], "index-project executable not found"

    def test_build_structure(self, standalone_env: StandaloneTestEnv) -> None:
        """Verify standalone build has expected directory structure."""
        checks = verify_build_structure(standalone_env.build_dir)

        assert checks["bin_dir"], "bin/ directory not found"
        assert checks["config_dir"], "config/ directory not found"
        assert checks["docs_dir"], "docs/ directory not found"
        assert checks["version_file"], "VERSION.txt not found"

    def test_serena_exe_help(self, standalone_env: StandaloneTestEnv) -> None:
        """Test serena.exe --help returns usage information."""
        result = standalone_env.run_command("serena", ["--help"])

        assert result.returncode == 0, f"Command failed: {result.stderr}"
        assert "Usage:" in result.stdout or "usage:" in result.stdout.lower()
        assert "serena" in result.stdout.lower()

    def test_serena_exe_version(self, standalone_env: StandaloneTestEnv) -> None:
        """Test serena.exe --version returns version information."""
        result = standalone_env.run_command("serena", ["--version"])

        assert result.returncode == 0, f"Command failed: {result.stderr}"

        # Version should be in format X.Y.Z
        output = result.stdout.strip()
        assert len(output) > 0, "Version output is empty"

        # Should contain digits
        assert any(c.isdigit() for c in output), "Version output contains no digits"

    def test_serena_mcp_server_exe_help(self, standalone_env: StandaloneTestEnv) -> None:
        """Test serena-mcp-server.exe --help shows help text."""
        result = standalone_env.run_command("serena-mcp-server", ["--help"])

        assert result.returncode == 0, f"Command failed: {result.stderr}"
        assert "mcp" in result.stdout.lower() or "server" in result.stdout.lower()

    def test_index_project_exe_help(self, standalone_env: StandaloneTestEnv) -> None:
        """Test index-project.exe --help shows help text."""
        result = standalone_env.run_command("index-project", ["--help"])

        assert result.returncode == 0, f"Command failed: {result.stderr}"
        assert "project" in result.stdout.lower() or "index" in result.stdout.lower()

    def test_serena_exe_no_args(self, standalone_env: StandaloneTestEnv) -> None:
        """Test serena.exe with no args shows help or error."""
        result = standalone_env.run_command("serena", [])

        # Should either show help (exit 0) or error with usage (exit non-zero)
        # Either is acceptable
        assert result.returncode in [0, 1, 2], f"Unexpected return code: {result.returncode}"

        # Should produce some output
        output = result.stdout + result.stderr
        assert len(output) > 0, "No output produced"

    @pytest.mark.slow
    def test_serena_mcp_server_startup_time(self, standalone_env: StandaloneTestEnv) -> None:
        """Verify MCP server starts within acceptable time (5 seconds)."""
        start_time = time.time()

        # Start server process
        proc = standalone_env.start_mcp_server()

        try:
            # Wait a moment for startup
            time.sleep(2)

            elapsed = time.time() - start_time

            # Server should have started (not crashed immediately)
            assert proc.poll() is None, "Server crashed immediately after startup"

            # Startup should be quick
            assert elapsed < 5.0, f"Server startup took {elapsed:.2f}s (> 5s)"

        finally:
            # Clean up
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5)

    def test_executables_are_files(self, standalone_env: StandaloneTestEnv) -> None:
        """Verify executables are regular files (not directories)."""
        for exe_name in ["serena", "serena-mcp-server", "index-project"]:
            exe_path = standalone_env.get_executable_path(exe_name)
            assert exe_path.is_file(), f"{exe_name} is not a file"
            assert not exe_path.is_dir(), f"{exe_name} is a directory"

    @pytest.mark.skipif(os.name != "nt", reason="Windows-specific test")
    def test_executables_have_exe_extension_windows(self, standalone_env: StandaloneTestEnv) -> None:
        """On Windows, verify executables have .exe extension."""
        for exe_name in ["serena", "serena-mcp-server", "index-project"]:
            exe_path = standalone_env.get_executable_path(exe_name)
            assert exe_path.suffix == ".exe", f"{exe_name} doesn't have .exe extension"
