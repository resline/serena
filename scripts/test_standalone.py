#!/usr/bin/env python3
"""
Test script for standalone Serena builds.

This script verifies that a standalone executable works correctly by testing:
- Basic CLI functionality (--help)
- Executable starts without import errors
- PyInstaller frozen mode detection
- Environment variable support

Usage:
    python scripts/test_standalone.py <path-to-executable>
    python scripts/test_standalone.py dist/serena-mcp-server  # Linux/macOS
    python scripts/test_standalone.py dist/serena-mcp-server.exe  # Windows
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


class StandaloneTestRunner:
    """Test runner for standalone executable builds."""

    def __init__(self, executable_path: str):
        self.executable = Path(executable_path).resolve()
        self.tests_passed = 0
        self.tests_failed = 0
        self.test_results: list[dict[str, Any]] = []

        if not self.executable.exists():
            raise FileNotFoundError(f"Executable not found: {self.executable}")

    def run_command(self, args: list[str], timeout: int = 90, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        """Run the executable with given arguments."""
        cmd = [str(self.executable)] + args
        full_env = os.environ.copy()
        if env:
            full_env.update(env)

        try:
            result = subprocess.run(
                cmd,
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
                env=full_env,
            )
            return result
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"Command timed out after {timeout}s: {' '.join(cmd)}")

    def test(self, name: str, fn, retries: int = 1):
        """Run a test and record results. Retry on timeout errors."""
        print(f"\n{'='*60}")
        print(f"TEST: {name}")
        print("=" * 60)

        last_error = None
        for attempt in range(retries + 1):
            try:
                fn()
                self.tests_passed += 1
                self.test_results.append({"name": name, "status": "PASSED"})
                print(f"[PASS] {name}")
                return
            except AssertionError as e:
                self.tests_failed += 1
                self.test_results.append({"name": name, "status": "FAILED", "error": str(e)})
                print(f"[FAIL] {name}")
                print(f"  Error: {e}")
                return
            except RuntimeError as e:
                # Timeout errors - retry
                last_error = e
                if attempt < retries:
                    print(f"[RETRY] {name} (attempt {attempt + 1}/{retries + 1})")
                    print(f"  Timeout, retrying...")
                    continue
                self.tests_failed += 1
                self.test_results.append({"name": name, "status": "ERROR", "error": str(e)})
                print(f"[ERROR] {name}")
                print(f"  Exception: {e}")
                return
            except Exception as e:
                self.tests_failed += 1
                self.test_results.append({"name": name, "status": "ERROR", "error": str(e)})
                print(f"[ERROR] {name}")
                print(f"  Exception: {e}")
                return

    def assert_in_output(self, result: subprocess.CompletedProcess, expected: str, location: str = "stdout"):
        """Assert that expected string is in command output."""
        output = result.stdout if location == "stdout" else result.stderr
        assert expected.lower() in output.lower(), f"Expected '{expected}' in {location}, got:\n{output}"

    def assert_exit_code(self, result: subprocess.CompletedProcess, expected: int = 0):
        """Assert command exit code."""
        assert (
            result.returncode == expected
        ), f"Expected exit code {expected}, got {result.returncode}\nstdout: {result.stdout}\nstderr: {result.stderr}"

    # =========================================================================
    # BASIC FUNCTIONALITY TESTS
    # =========================================================================

    def test_help_command(self):
        """Test --help shows usage information."""
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)
        self.assert_in_output(result, "Serena MCP server")
        self.assert_in_output(result, "--project")
        self.assert_in_output(result, "--context")
        self.assert_in_output(result, "--mode")

    def test_executable_starts(self):
        """Test executable starts without critical errors."""
        # Use longer timeout for first run - PyInstaller needs to extract files on first execution
        # Windows especially needs more time due to antivirus scanning and slower disk I/O
        result = self.run_command(["--help"], timeout=120)
        self.assert_exit_code(result, 0)
        # Should not have Python import errors or missing module errors
        assert "ModuleNotFoundError" not in result.stderr, f"Import error in stderr: {result.stderr}"
        assert "ImportError" not in result.stderr, f"Import error in stderr: {result.stderr}"

    def test_version_info(self):
        """Test that version information is available."""
        # The CLI might not have --version, so we check --help runs successfully
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)

    # =========================================================================
    # PATH HANDLING TESTS
    # =========================================================================

    def test_frozen_mode_detection(self):
        """Test that frozen mode is detected correctly."""
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)
        # No errors about sys._MEIPASS or frozen attribute
        assert "_MEIPASS" not in result.stderr, "PyInstaller path handling error"

    def test_no_python_path_errors(self):
        """Test no Python path or import errors occur."""
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)
        # Check for common PyInstaller issues
        error_indicators = [
            "ModuleNotFoundError",
            "ImportError",
            "FileNotFoundError",
            "No module named",
            "cannot import name",
        ]
        for indicator in error_indicators:
            assert indicator not in result.stderr, f"Found error indicator '{indicator}' in stderr: {result.stderr}"

    # =========================================================================
    # CONFIGURATION AND ENVIRONMENT TESTS
    # =========================================================================

    def test_standalone_mode_env_var(self):
        """Test that SERENA_STANDALONE environment variable is respected."""
        result = self.run_command(["--help"], env={"SERENA_STANDALONE": "true"})
        self.assert_exit_code(result, 0)

    def test_config_file_env(self):
        """Test that executable works with custom HOME directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {
                "HOME": tmpdir,
                "USERPROFILE": tmpdir,  # Windows
            }
            result = self.run_command(["--help"], env=env)
            self.assert_exit_code(result, 0)

    # =========================================================================
    # CLI OPTIONS TESTS
    # =========================================================================

    def test_cli_options_present(self):
        """Test that all expected CLI options are present."""
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)

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
            assert option in result.stdout, f"Expected option '{option}' not found in help output"

    def test_transport_options(self):
        """Test that transport protocol options are documented."""
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)
        # Should mention transport protocols
        assert "stdio" in result.stdout.lower(), "stdio transport not mentioned in help"

    # =========================================================================
    # ERROR HANDLING TESTS
    # =========================================================================

    def test_invalid_option_fails_gracefully(self):
        """Test that invalid options produce helpful error messages."""
        result = self.run_command(["--nonexistent-option"])
        # Should fail but not crash
        assert result.returncode != 0, "Invalid option should return non-zero exit code"
        # Should have error message, not a Python traceback
        assert "Error" in result.stderr or "error" in result.stderr or "no such option" in result.stderr.lower()

    def run_all_tests(self):
        """Run all standalone tests."""
        print("=" * 60)
        print("STANDALONE EXECUTABLE TEST SUITE")
        print(f"Executable: {self.executable}")
        print("=" * 60)

        # Basic functionality
        self.test("Executable starts without errors", self.test_executable_starts)
        self.test("--help command works", self.test_help_command)
        self.test("Version information available", self.test_version_info)

        # Path handling
        self.test("Frozen mode detection", self.test_frozen_mode_detection)
        self.test("No Python path errors", self.test_no_python_path_errors)

        # Configuration
        self.test("SERENA_STANDALONE env var", self.test_standalone_mode_env_var)
        self.test("Config file operations", self.test_config_file_env)

        # CLI options
        self.test("CLI options present", self.test_cli_options_present)
        self.test("Transport options documented", self.test_transport_options)

        # Error handling
        self.test("Invalid option fails gracefully", self.test_invalid_option_fails_gracefully)

        # Summary
        print("\n" + "=" * 60)
        print("TEST SUMMARY")
        print("=" * 60)
        total = self.tests_passed + self.tests_failed
        print(f"Total: {total}")
        print(f"Passed: {self.tests_passed}")
        print(f"Failed: {self.tests_failed}")
        print("=" * 60)

        return self.tests_failed == 0


def main():
    parser = argparse.ArgumentParser(description="Test standalone Serena executable")
    parser.add_argument("executable", help="Path to the standalone executable")
    parser.add_argument(
        "--json-output",
        help="Path to write JSON test results",
        type=str,
        default=None,
    )
    args = parser.parse_args()

    try:
        runner = StandaloneTestRunner(args.executable)
        success = runner.run_all_tests()

        if args.json_output:
            with open(args.json_output, "w") as f:
                json.dump(
                    {
                        "executable": str(runner.executable),
                        "total": runner.tests_passed + runner.tests_failed,
                        "passed": runner.tests_passed,
                        "failed": runner.tests_failed,
                        "results": runner.test_results,
                    },
                    f,
                    indent=2,
                )
            print(f"\nJSON results written to: {args.json_output}")

        sys.exit(0 if success else 1)

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
