from __future__ import annotations

import logging
import os
import platform
import shutil
import subprocess
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


def check_bundled_ls(
    settings: "SolidLSPSettings",
    ls_subdir: str,
    binary_relative_path: str,
) -> str | None:
    """
    Check if a bundled language server binary exists in the bundled LS directory.

    This function should be called before downloading a language server to use
    pre-bundled binaries in standalone/offline mode.

    Args:
        settings: SolidLSP settings containing bundled_ls_dir path
        ls_subdir: Subdirectory within bundled_ls_dir for this LS (e.g., "clangd", "terraform-ls")
        binary_relative_path: Path to the binary relative to ls_subdir (e.g., "clangd_19.1.2/bin/clangd")

    Returns:
        Full path to the bundled binary if it exists, None otherwise

    Example:
        >>> bundled_path = check_bundled_ls(settings, "clangd", "clangd_19.1.2/bin/clangd")
        >>> if bundled_path:
        ...     return bundled_path  # Use bundled binary
        >>> # Fall through to download logic

    """
    if not settings.bundled_ls_dir:
        return None

    bundled_path = os.path.join(settings.bundled_ls_dir, ls_subdir, binary_relative_path)

    if os.path.isfile(bundled_path):
        log.info(f"Found bundled language server at {bundled_path}")
        return bundled_path

    log.debug(f"Bundled language server not found at {bundled_path}")
    return None


def copy_bundled_ls_to_cache(
    settings: "SolidLSPSettings",
    ls_subdir: str,
    target_dir: str,
) -> bool:
    """
    Copy bundled language server files to the cache directory.

    This function copies the entire bundled LS subdirectory to the target cache
    directory, preserving the directory structure. This is useful when the LS
    expects to be in a specific location or needs write access to its directory.

    Args:
        settings: SolidLSP settings containing bundled_ls_dir path
        ls_subdir: Subdirectory within bundled_ls_dir for this LS (e.g., "clangd")
        target_dir: Target directory where the LS should be copied

    Returns:
        True if the copy was successful, False otherwise

    Example:
        >>> if copy_bundled_ls_to_cache(settings, "clangd", cache_dir):
        ...     # Use the cached copy
        ...     binary_path = os.path.join(cache_dir, "clangd_19.1.2/bin/clangd")

    """
    if not settings.bundled_ls_dir:
        return False

    bundled_source = os.path.join(settings.bundled_ls_dir, ls_subdir)

    if not os.path.isdir(bundled_source):
        log.debug(f"Bundled LS directory not found at {bundled_source}")
        return False

    try:
        # If target exists, check if it's already populated
        if os.path.exists(target_dir):
            # Check if there are any files - if so, assume it's already set up
            if any(os.scandir(target_dir)):
                log.debug(f"Target directory {target_dir} already has content, skipping copy")
                return True

        # Copy the bundled LS to target
        log.info(f"Copying bundled language server from {bundled_source} to {target_dir}")
        os.makedirs(target_dir, exist_ok=True)

        # Copy contents of bundled_source into target_dir
        for item in os.listdir(bundled_source):
            src = os.path.join(bundled_source, item)
            dst = os.path.join(target_dir, item)
            if os.path.isdir(src):
                if os.path.exists(dst):
                    shutil.rmtree(dst)
                shutil.copytree(src, dst)
            else:
                shutil.copy2(src, dst)

        log.info(f"Successfully copied bundled LS to {target_dir}")
        return True

    except Exception as e:
        log.warning(f"Failed to copy bundled LS: {e}")
        return False


def should_download_ls(settings: "SolidLSPSettings") -> bool:
    """
    Determine if language servers should be downloaded.

    In standalone mode with bundled LS available, downloading is skipped
    unless allow_download_fallback is True and the bundled LS is not found.

    Args:
        settings: SolidLSP settings

    Returns:
        True if downloading is allowed, False if it should be skipped

    """
    if settings.standalone_mode and settings.bundled_ls_dir:
        if not settings.allow_download_fallback:
            log.info("Standalone mode: download disabled, using bundled LS only")
            return False
    return True
