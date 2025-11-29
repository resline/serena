from __future__ import annotations

import logging
import os
import platform
import shutil
import subprocess
import sys
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, replace
from typing import TYPE_CHECKING, Any, cast

from solidlsp.ls_utils import FileUtils, PlatformUtils
from solidlsp.util.subprocess_util import subprocess_kwargs

if TYPE_CHECKING:
    from solidlsp.settings import SolidLSPSettings

log = logging.getLogger(__name__)


@dataclass(kw_only=True)
class RuntimeDependency:
    """Represents a runtime dependency for a language server."""

    id: str
    platform_id: str | None = None
    url: str | None = None
    archive_type: str | None = None
    binary_name: str | None = None
    command: str | list[str] | None = None
    package_name: str | None = None
    package_version: str | None = None
    extract_path: str | None = None
    description: str | None = None


class RuntimeDependencyCollection:
    """Utility to handle installation of runtime dependencies."""

    def __init__(self, dependencies: Sequence[RuntimeDependency], overrides: Iterable[Mapping[str, Any]] = ()) -> None:
        """Initialize the collection with a list of dependencies and optional overrides.

        :param dependencies: List of base RuntimeDependency instances. The combination of 'id' and 'platform_id' must be unique.
        :param overrides: List of dictionaries which represent overrides or additions to the base dependencies.
            Each entry must contain at least the 'id' key, and optionally 'platform_id' to uniquely identify the dependency to override.
        """
        self._id_and_platform_id_to_dep: dict[tuple[str, str | None], RuntimeDependency] = {}
        for dep in dependencies:
            dep_key = (dep.id, dep.platform_id)
            if dep_key in self._id_and_platform_id_to_dep:
                raise ValueError(f"Duplicate runtime dependency with id '{dep.id}' and platform_id '{dep.platform_id}':\n{dep}")
            self._id_and_platform_id_to_dep[dep_key] = dep

        for dep_values_override in overrides:
            override_key = cast(tuple[str, str | None], (dep_values_override["id"], dep_values_override.get("platform_id")))
            base_dep = self._id_and_platform_id_to_dep.get(override_key)
            if base_dep is None:
                new_runtime_dep = RuntimeDependency(**dep_values_override)
                self._id_and_platform_id_to_dep[override_key] = new_runtime_dep
            else:
                self._id_and_platform_id_to_dep[override_key] = replace(base_dep, **dep_values_override)

    def get_dependencies_for_platform(self, platform_id: str) -> list[RuntimeDependency]:
        return [d for d in self._id_and_platform_id_to_dep.values() if d.platform_id in (platform_id, "any", "platform-agnostic", None)]

    def get_dependencies_for_current_platform(self) -> list[RuntimeDependency]:
        return self.get_dependencies_for_platform(PlatformUtils.get_platform_id().value)

    def get_single_dep_for_current_platform(self, dependency_id: str | None = None) -> RuntimeDependency:
        deps = self.get_dependencies_for_current_platform()
        if dependency_id is not None:
            deps = [d for d in deps if d.id == dependency_id]
        if len(deps) != 1:
            raise RuntimeError(
                f"Expected exactly one runtime dependency for platform-{PlatformUtils.get_platform_id().value} and {dependency_id=}, found {len(deps)}"
            )
        return deps[0]

    def binary_path(self, target_dir: str) -> str:
        dep = self.get_single_dep_for_current_platform()
        if not dep.binary_name:
            return target_dir
        return os.path.join(target_dir, dep.binary_name)

    def install(self, target_dir: str) -> dict[str, str]:
        """Install all dependencies for the current platform into *target_dir*.

        Returns a mapping from dependency id to the resolved binary path.
        """
        os.makedirs(target_dir, exist_ok=True)
        results: dict[str, str] = {}
        for dep in self.get_dependencies_for_current_platform():
            if dep.url:
                self._install_from_url(dep, target_dir)
            if dep.command:
                self._run_command(dep.command, target_dir)
            if dep.binary_name:
                results[dep.id] = os.path.join(target_dir, dep.binary_name)
            else:
                results[dep.id] = target_dir
        return results

    @staticmethod
    def _run_command(command: str | list[str], cwd: str) -> None:
        kwargs = subprocess_kwargs()
        if not PlatformUtils.get_platform_id().is_windows():
            import pwd

            kwargs["user"] = pwd.getpwuid(os.getuid()).pw_name  # type: ignore

        is_windows = platform.system() == "Windows"
        if not isinstance(command, str) and not is_windows:
            # Since we are using the shell, we need to convert the command list to a single string
            # on Linux/macOS
            command = " ".join(command)

        log.info("Running command %s in '%s'", f"'{command}'" if isinstance(command, str) else command, cwd)

        completed_process = subprocess.run(
            command,
            shell=True,
            check=True,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            **kwargs,
        )  # type: ignore
        if completed_process.returncode != 0:
            log.warning("Command '%s' failed with return code %d", command, completed_process.returncode)
            log.warning("Command output:\n%s", completed_process.stdout)
        else:
            log.info(
                "Command completed successfully",
            )

    @staticmethod
    def _install_from_url(dep: RuntimeDependency, target_dir: str) -> None:
        if not dep.url:
            raise ValueError(f"Dependency {dep.id} has no URL")

        if dep.archive_type in ("gz", "binary") and dep.binary_name:
            dest = os.path.join(target_dir, dep.binary_name)
            FileUtils.download_and_extract_archive(dep.url, dest, dep.archive_type)
        else:
            FileUtils.download_and_extract_archive(dep.url, target_dir, dep.archive_type or "zip")


def quote_windows_path(path: str) -> str:
    """
    Quote a path for Windows command execution if needed.

    On Windows, paths need to be quoted for proper command execution.
    The function checks if the path is already quoted to avoid double-quoting.
    On other platforms, the path is returned unchanged.

    Args:
        path: The file path to potentially quote

    Returns:
        The quoted path on Windows (if not already quoted), unchanged path on other platforms

    """
    if platform.system() == "Windows":
        # Check if already quoted to avoid double-quoting
        if path.startswith('"') and path.endswith('"'):
            return path
        return f'"{path}"'
    return path


# =============================================================================
# Offline/Bundled Support for npm-based Language Servers
# =============================================================================


def get_bundled_npm_package_path(
    solidlsp_settings: "SolidLSPSettings",
    package_dir_name: str,
    binary_name: str,
) -> str | None:
    """
    Check if a bundled npm package exists in the bundled language servers directory.

    For standalone/offline builds, npm packages are pre-installed and bundled
    in the language_servers directory relative to the executable.

    Args:
        solidlsp_settings: The SolidLSP settings containing bundled_ls_dir path.
        package_dir_name: The directory name for the package (e.g., "ts-lsp", "yaml-lsp").
        binary_name: The name of the binary in node_modules/.bin/ (e.g., "typescript-language-server").

    Returns:
        The absolute path to the bundled executable if found, None otherwise.

    Example:
        # For TypeScript language server, the bundled path would be:
        # <bundled_ls_dir>/TypeScriptLanguageServer/ts-lsp/node_modules/.bin/typescript-language-server

    """
    bundled_ls_dir = solidlsp_settings.bundled_ls_dir
    if not bundled_ls_dir:
        return None

    # Construct the expected path: bundled_ls_dir/<package_dir_name>/node_modules/.bin/<binary_name>
    bundled_executable = os.path.join(bundled_ls_dir, package_dir_name, "node_modules", ".bin", binary_name)

    # Handle Windows executable extension
    if sys.platform == "win32" and not binary_name.endswith(".cmd"):
        bundled_executable_cmd = bundled_executable + ".cmd"
        if os.path.exists(bundled_executable_cmd):
            log.info(f"Found bundled npm package at {bundled_executable_cmd}")
            return bundled_executable_cmd

    if os.path.exists(bundled_executable):
        log.info(f"Found bundled npm package at {bundled_executable}")
        return bundled_executable

    return None


def get_node_npm_paths(solidlsp_settings: "SolidLSPSettings") -> tuple[str | None, str | None]:
    """
    Get paths to Node.js and npm, preferring bundled versions for standalone builds.

    This function checks in the following order:
    1. Bundled Node.js (from solidlsp_settings.bundled_node_path)
    2. System Node.js (via shutil.which)

    Returns:
        A tuple of (node_path, npm_path). Either can be None if not found.

    """
    node_path: str | None = None
    npm_path: str | None = None

    # 1. Check for bundled Node.js
    bundled_node = solidlsp_settings.bundled_node_path
    if bundled_node and os.path.isfile(bundled_node):
        node_path = bundled_node
        # npm should be in the same directory as node
        node_dir = os.path.dirname(bundled_node)
        if sys.platform == "win32":
            bundled_npm = os.path.join(node_dir, "npm.cmd")
        else:
            bundled_npm = os.path.join(node_dir, "npm")
        if os.path.isfile(bundled_npm):
            npm_path = bundled_npm
        else:
            # Try npm as a script that node can run
            npm_cli_path = os.path.join(node_dir, "lib", "node_modules", "npm", "bin", "npm-cli.js")
            if os.path.isfile(npm_cli_path):
                npm_path = npm_cli_path
        log.info(f"Using bundled Node.js: {node_path}")
        if npm_path:
            log.info(f"Using bundled npm: {npm_path}")

    # 2. Fall back to system Node.js if not in standalone mode or bundled not available
    if node_path is None and solidlsp_settings.allow_download_fallback:
        node_path = shutil.which("node")
        if node_path:
            log.debug(f"Using system Node.js: {node_path}")

    if npm_path is None and solidlsp_settings.allow_download_fallback:
        npm_path = shutil.which("npm")
        if npm_path:
            log.debug(f"Using system npm: {npm_path}")

    return node_path, npm_path


def verify_node_npm_available(solidlsp_settings: "SolidLSPSettings") -> tuple[str, str]:
    """
    Verify that Node.js and npm are available (bundled or system).

    This function first checks for bundled versions, then falls back to system versions
    if download fallback is allowed.

    Returns:
        A tuple of (node_path, npm_path).

    Raises:
        AssertionError: If Node.js or npm cannot be found.

    """
    node_path, npm_path = get_node_npm_paths(solidlsp_settings)

    if node_path is None:
        if solidlsp_settings.standalone_mode:
            raise AssertionError(
                "Node.js not found. Running in standalone mode but bundled Node.js is not available. "
                "Please use the 'full' variant of Serena standalone or install Node.js on your system."
            )
        raise AssertionError("Node.js is not installed or isn't in PATH. Please install Node.js and try again.")

    if npm_path is None:
        if solidlsp_settings.standalone_mode:
            raise AssertionError(
                "npm not found. Running in standalone mode but bundled npm is not available. "
                "Please use the 'full' variant of Serena standalone or install npm on your system."
            )
        raise AssertionError("npm is not installed or isn't in PATH. Please install npm and try again.")

    return node_path, npm_path


def get_npm_install_env(solidlsp_settings: "SolidLSPSettings") -> dict[str, str]:
    """
    Get environment variables for npm install commands when using bundled Node.js.

    When using bundled Node.js, we need to set PATH to include the bundled node directory
    so that npm can find the node executable.

    Returns:
        A dictionary of environment variables to use for npm commands.

    """
    env = os.environ.copy()

    bundled_node = solidlsp_settings.bundled_node_path
    if bundled_node and os.path.isfile(bundled_node):
        node_dir = os.path.dirname(bundled_node)
        # Prepend bundled node directory to PATH
        current_path = env.get("PATH", "")
        env["PATH"] = node_dir + os.pathsep + current_path
        log.debug(f"Added bundled Node.js to PATH: {node_dir}")

    return env
