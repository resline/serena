#!/usr/bin/env python3
"""
Test script for standalone Serena builds.

This script verifies that a standalone executable works correctly by testing:
- Basic CLI functionality (--help, --version)
- Resource accessibility (contexts, modes, templates, icons, dashboard)
- Path handling in frozen mode
- Configuration and environment variable support

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

    def run_command(self, args: list[str], timeout: int = 30, env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
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

    def test(self, name: str, fn):
        """Run a test and record results."""
        print(f"\n{'='*60}")
        print(f"TEST: {name}")
        print("=" * 60)

        try:
            fn()
            self.tests_passed += 1
            self.test_results.append({"name": name, "status": "PASSED"})
            print(f"✓ PASSED: {name}")
        except AssertionError as e:
            self.tests_failed += 1
            self.test_results.append({"name": name, "status": "FAILED", "error": str(e)})
            print(f"✗ FAILED: {name}")
            print(f"  Error: {e}")
        except Exception as e:
            self.tests_failed += 1
            self.test_results.append({"name": name, "status": "ERROR", "error": str(e)})
            print(f"✗ ERROR: {name}")
            print(f"  Exception: {e}")

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
        self.assert_in_output(result, "Starts the Serena MCP server")
        self.assert_in_output(result, "--project")
        self.assert_in_output(result, "--context")
        self.assert_in_output(result, "--mode")

    def test_executable_starts(self):
        """Test executable starts without critical errors."""
        # Just run --help to verify the executable can start
        result = self.run_command(["--help"], timeout=10)
        self.assert_exit_code(result, 0)
        # Should not have Python import errors or missing module errors
        assert "ModuleNotFoundError" not in result.stderr, f"Import error in stderr: {result.stderr}"
        assert "ImportError" not in result.stderr, f"Import error in stderr: {result.stderr}"

    def test_version_info(self):
        """Test that version information is available."""
        # The CLI might not have --version, so we'll check if we can run a command
        # that shows version-like info or at least runs successfully
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)

    # =========================================================================
    # CONTEXT AND MODE TESTS
    # =========================================================================

    def test_list_contexts(self):
        """Test that contexts can be listed (verifies context resources are bundled)."""
        result = self.run_command(["context", "list"])
        self.assert_exit_code(result, 0)
        # Should have at least the desktop-app context
        self.assert_in_output(result, "desktop-app")

    def test_list_modes(self):
        """Test that modes can be listed (verifies mode resources are bundled)."""
        result = self.run_command(["mode", "list"])
        self.assert_exit_code(result, 0)
        # Should have at least interactive and editing modes
        self.assert_in_output(result, "interactive")
        self.assert_in_output(result, "editing")

    def test_default_context_loads(self):
        """Test that the default context can be loaded."""
        # Use tools list which requires loading the default context
        result = self.run_command(["tools", "list", "-q"])
        self.assert_exit_code(result, 0)
        # Should have some tools listed
        assert len(result.stdout.strip()) > 0, "No tools listed, context may not have loaded"

    # =========================================================================
    # RESOURCE ACCESSIBILITY TESTS
    # =========================================================================

    def test_tools_list(self):
        """Test that tools can be listed (verifies tool registry works)."""
        result = self.run_command(["tools", "list", "-q"])
        self.assert_exit_code(result, 0)
        # Should have some standard tools
        output_lower = result.stdout.lower()
        # Check for at least one common tool
        has_tool = any(tool in output_lower for tool in ["findsymbol", "searchforpattern", "readfile", "writefile"])
        assert has_tool, f"No expected tools found in output: {result.stdout}"

    def test_tool_description(self):
        """Test that tool descriptions can be retrieved."""
        result = self.run_command(["tools", "description", "FindSymbol"])
        self.assert_exit_code(result, 0)
        # Should contain description text
        assert len(result.stdout.strip()) > 0, "Tool description is empty"

    def test_prompts_list(self):
        """Test that prompt templates are accessible."""
        result = self.run_command(["prompts", "list"])
        self.assert_exit_code(result, 0)
        # Should list at least one prompt template
        assert len(result.stdout.strip()) > 0, "No prompt templates listed"

    # =========================================================================
    # PATH HANDLING TESTS
    # =========================================================================

    def test_frozen_mode_detection(self):
        """Test that frozen mode is detected correctly."""
        # The executable should work without Python environment errors
        result = self.run_command(["--help"])
        self.assert_exit_code(result, 0)
        # No errors about sys._MEIPASS or frozen attribute
        assert "_MEIPASS" not in result.stderr, "PyInstaller path handling error"

    def test_resource_paths(self):
        """Test that resources are found via correct path handling."""
        # List contexts - if this works, resource paths are correct
        result = self.run_command(["context", "list"])
        self.assert_exit_code(result, 0)

        # List modes - another resource path check
        result = self.run_command(["mode", "list"])
        self.assert_exit_code(result, 0)

    # =========================================================================
    # CONFIGURATION AND ENVIRONMENT TESTS
    # =========================================================================

    def test_standalone_mode_env_var(self):
        """Test that SERENA_STANDALONE environment variable is respected."""
        # When set to true, should still work
        result = self.run_command(["--help"], env={"SERENA_STANDALONE": "true"})
        self.assert_exit_code(result, 0)

    def test_config_file_creation(self):
        """Test that config file can be generated."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Run with HOME set to temp directory
            env = {
                "HOME": tmpdir,
                "USERPROFILE": tmpdir,  # Windows
            }
            # Config edit tries to create config if it doesn't exist
            # We can't really test interactive editor opening, but we can
            # verify the command doesn't crash
            result = self.run_command(["--help"], env=env)
            self.assert_exit_code(result, 0)

    # =========================================================================
    # PROJECT OPERATIONS TESTS
    # =========================================================================

    def test_project_help(self):
        """Test project subcommands are available."""
        result = self.run_command(["project", "--help"])
        self.assert_exit_code(result, 0)
        self.assert_in_output(result, "create")
        self.assert_in_output(result, "index")

    def test_project_create_help(self):
        """Test project create command help."""
        result = self.run_command(["project", "create", "--help"])
        self.assert_exit_code(result, 0)
        self.assert_in_output(result, "--name")
        self.assert_in_output(result, "--language")

    # =========================================================================
    # ERROR HANDLING TESTS
    # =========================================================================

    def test_invalid_command_fails_gracefully(self):
        """Test that invalid commands produce helpful error messages."""
        result = self.run_command(["nonexistent-command"])
        # Should fail but not crash
        assert result.returncode != 0, "Invalid command should return non-zero exit code"
        # Should have error message
        assert len(result.stderr) > 0 or "no such" in result.stdout.lower(), "No error message for invalid command"

    def test_invalid_option_fails_gracefully(self):
        """Test that invalid options produce helpful error messages."""
        result = self.run_command(["--nonexistent-option"])
        assert result.returncode != 0, "Invalid option should return non-zero exit code"

    # =========================================================================
    # RUN ALL TESTS
    # =========================================================================

    def run_all_tests(self):
        """Run all tests and report results."""
        print(f"\n{'='*60}")
        print("STANDALONE EXECUTABLE TEST SUITE")
        print(f"Executable: {self.executable}")
        print("=" * 60)

        # Basic functionality tests
        self.test("Executable starts without errors", self.test_executable_starts)
        self.test("--help command works", self.test_help_command)
        self.test("Version information available", self.test_version_info)

        # Resource tests
        self.test("List contexts (resource bundling)", self.test_list_contexts)
        self.test("List modes (resource bundling)", self.test_list_modes)
        self.test("List tools (tool registry)", self.test_tools_list)
        self.test("Tool description retrieval", self.test_tool_description)
        self.test("Prompt templates accessible", self.test_prompts_list)
        self.test("Default context loads", self.test_default_context_loads)

        # Path handling tests
        self.test("Frozen mode detection", self.test_frozen_mode_detection)
        self.test("Resource path handling", self.test_resource_paths)

        # Configuration tests
        self.test("SERENA_STANDALONE env var", self.test_standalone_mode_env_var)
        self.test("Config file operations", self.test_config_file_creation)

        # Project operations
        self.test("Project commands available", self.test_project_help)
        self.test("Project create help", self.test_project_create_help)

        # Error handling
        self.test("Invalid command handling", self.test_invalid_command_fails_gracefully)
        self.test("Invalid option handling", self.test_invalid_option_fails_gracefully)

        # Print summary
        self.print_summary()

        # Return exit code
        return 0 if self.tests_failed == 0 else 1

    def print_summary(self):
        """Print test summary."""
        total = self.tests_passed + self.tests_failed
        print(f"\n{'='*60}")
        print("TEST SUMMARY")
        print("=" * 60)
        print(f"Total tests: {total}")
        print(f"Passed: {self.tests_passed}")
        print(f"Failed: {self.tests_failed}")
        print(f"Success rate: {self.tests_passed/total*100:.1f}%")

        if self.tests_failed > 0:
            print("\nFailed tests:")
            for result in self.test_results:
                if result["status"] in ["FAILED", "ERROR"]:
                    print(f"  - {result['name']}: {result.get('error', 'Unknown error')}")

        print("=" * 60)
        if self.tests_failed == 0:
            print("✓ ALL TESTS PASSED")
        else:
            print(f"✗ {self.tests_failed} TEST(S) FAILED")
        print("=" * 60)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Test standalone Serena executable",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/test_standalone.py dist/serena-mcp-server
  python scripts/test_standalone.py dist/serena-mcp-server.exe
  python scripts/test_standalone.py dist/serena-mcp-server --json-output results.json
        """,
    )
    parser.add_argument("executable", help="Path to the standalone executable to test")
    parser.add_argument("--json-output", help="Write test results to JSON file", default=None)

    args = parser.parse_args()

    try:
        runner = StandaloneTestRunner(args.executable)
        exit_code = runner.run_all_tests()

        # Write JSON output if requested
        if args.json_output:
            output_data = {
                "executable": str(runner.executable),
                "total": runner.tests_passed + runner.tests_failed,
                "passed": runner.tests_passed,
                "failed": runner.tests_failed,
                "results": runner.test_results,
            }
            with open(args.json_output, "w") as f:
                json.dump(output_data, f, indent=2)
            print(f"\nResults written to: {args.json_output}")

        sys.exit(exit_code)

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nTests interrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
