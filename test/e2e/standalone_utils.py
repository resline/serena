"""Utilities for testing standalone builds.

This module provides helper classes and functions for testing Serena standalone
executables in E2E scenarios.
"""

import os
import shutil
import subprocess
import tempfile
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from solidlsp.ls_config import Language


class StandaloneTestEnv:
    """Manages test environment for standalone executables.

    This class provides utilities for running standalone Serena executables
    and creating test projects.

    Example:
        ```python
        env = StandaloneTestEnv(Path("dist/serena-portable-windows-x64-essential"))

        # Run command
        result = env.run_command("serena", ["--version"])
        assert result.returncode == 0

        # Create test project
        with env.temporary_project(Language.PYTHON) as project:
            # Use project for testing
            pass
        ```

    """

    def __init__(self, build_dir: Path, tier: str = "essential"):
        """Initialize standalone test environment.

        Args:
            build_dir: Path to standalone build directory
            tier: Build tier (minimal, essential, complete, full)

        Raises:
            ValueError: If build directory doesn't exist

        """
        self.build_dir = build_dir
        self.tier = tier
        self.bin_dir = build_dir / "bin"

        if not self.build_dir.exists():
            raise ValueError(f"Build directory not found: {build_dir}")

        if not self.bin_dir.exists():
            raise ValueError(f"Bin directory not found: {self.bin_dir}")

    def get_executable_path(self, name: str) -> Path:
        """Get path to executable.

        Args:
            name: Executable name (without .exe extension)

        Returns:
            Path to executable

        Raises:
            FileNotFoundError: If executable doesn't exist

        """
        if os.name == "nt":
            exe_name = f"{name}.exe"
        else:
            exe_name = name

        exe_path = self.bin_dir / exe_name

        if not exe_path.exists():
            raise FileNotFoundError(f"Executable not found: {exe_path}")

        return exe_path

    def verify_executables_exist(self) -> dict[str, bool]:
        """Verify all expected executables are present.

        Returns:
            Dictionary mapping executable names to existence status

        """
        expected = ["serena", "serena-mcp-server", "index-project"]

        results: dict[str, bool] = {}
        for name in expected:
            try:
                self.get_executable_path(name)
                results[name] = True
            except FileNotFoundError:
                results[name] = False

        return results

    def run_command(
        self,
        exe: str,
        args: list[str],
        timeout: float = 30,
        **kwargs: Any,
    ) -> subprocess.CompletedProcess[str]:
        """Run executable command.

        Args:
            exe: Executable name (without .exe extension)
            args: Command arguments
            timeout: Timeout in seconds
            **kwargs: Additional arguments for subprocess.run

        Returns:
            Completed process result

        Raises:
            FileNotFoundError: If executable doesn't exist
            subprocess.TimeoutExpired: If command times out

        """
        exe_path = self.get_executable_path(exe)

        return subprocess.run(
            [str(exe_path), *args],
            timeout=timeout,
            capture_output=True,
            text=True,
            **kwargs,
        )

    def start_mcp_server(self, **kwargs: Any) -> subprocess.Popen[bytes]:
        """Start MCP server as subprocess.

        Args:
            **kwargs: Additional arguments for server (passed as command line args)

        Returns:
            Running subprocess

        Raises:
            FileNotFoundError: If serena-mcp-server executable doesn't exist

        """
        exe_path = self.get_executable_path("serena-mcp-server")

        # Build command line arguments
        cmd = [str(exe_path)]
        for key, value in kwargs.items():
            if isinstance(value, bool):
                if value:
                    cmd.append(f"--{key.replace('_', '-')}")
            else:
                cmd.extend([f"--{key.replace('_', '-')}", str(value)])

        return subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    @contextmanager
    def temporary_project(self, language: Language) -> Iterator[Path]:
        """Create temporary test project.

        Args:
            language: Programming language for project

        Yields:
            Path to temporary project directory

        Example:
            ```python
            with env.temporary_project(Language.PYTHON) as project:
                # Project contains sample Python files
                assert (project / "main.py").exists()
            # Project is automatically cleaned up
            ```

        """
        temp_dir = Path(tempfile.mkdtemp())

        try:
            # Try to copy existing test repo
            resources_dir = Path(__file__).parent.parent / "resources" / "repos"
            src_dir = resources_dir / language.value / "test_repo"

            if src_dir.exists():
                # Copy existing test repository
                project_dir = temp_dir / "project"
                shutil.copytree(src_dir, project_dir)

                # Wait for Windows filesystem (prevent file lock issues)
                if os.name == "nt":
                    time.sleep(0.1)

                yield project_dir
            else:
                # Create minimal project
                project_dir = temp_dir / "project"
                project_dir.mkdir()

                # Create basic files based on language
                if language == Language.PYTHON:
                    (project_dir / "main.py").write_text("def main():\n    pass\n")
                    (project_dir / "utils.py").write_text("def helper():\n    return 42\n")

                elif language == Language.GO:
                    (project_dir / "main.go").write_text("package main\n\nfunc main() {}\n")
                    (project_dir / "utils.go").write_text("package main\n\nfunc helper() int {\n\treturn 42\n}\n")

                elif language == Language.TYPESCRIPT:
                    (project_dir / "main.ts").write_text("function main() {}\n")
                    (project_dir / "utils.ts").write_text("export function helper(): number {\n\treturn 42;\n}\n")

                elif language == Language.RUST:
                    (project_dir / "main.rs").write_text("fn main() {}\n")
                    (project_dir / "lib.rs").write_text("pub fn helper() -> i32 {\n    42\n}\n")

                elif language == Language.JAVA:
                    (project_dir / "Main.java").write_text("public class Main {\n    public static void main(String[] args) {}\n}\n")

                else:
                    # Generic file
                    (project_dir / f"main.{language.value}").write_text("// Sample file\n")

                yield project_dir

        finally:
            # Clean up temporary directory
            shutil.rmtree(temp_dir, ignore_errors=True)


def verify_build_structure(build_dir: Path) -> dict[str, bool]:
    """Verify standalone build has expected structure.

    Args:
        build_dir: Path to build directory

    Returns:
        Dictionary mapping components to existence status

    """
    checks = {
        "bin_dir": (build_dir / "bin").is_dir(),
        "config_dir": (build_dir / "config").is_dir(),
        "docs_dir": (build_dir / "docs").is_dir(),
        "language_servers_dir": (build_dir / "language_servers").is_dir(),
        "launcher_script": (build_dir / "serena-portable.bat").is_file(),
        "version_file": (build_dir / "VERSION.txt").is_file(),
        "readme": (build_dir / "README.md").is_file(),
    }

    return checks


def get_bundled_language_servers(build_dir: Path) -> list[str]:
    """Get list of bundled language servers.

    Args:
        build_dir: Path to build directory

    Returns:
        List of language server names

    """
    ls_dir = build_dir / "language_servers"

    if not ls_dir.exists():
        return []

    return [d.name for d in ls_dir.iterdir() if d.is_dir()]
