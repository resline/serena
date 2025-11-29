"""
Defines settings for Solid-LSP
"""

import logging
import os
import pathlib
import sys
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any

from sensai.util.string import ToStringMixin

if TYPE_CHECKING:
    from solidlsp.ls_config import Language

log = logging.getLogger(__name__)


def _is_standalone_mode() -> bool:
    """Check if running in standalone/offline mode."""
    return os.environ.get("SERENA_STANDALONE", "").lower() in ("1", "true", "yes")


def _get_bundled_ls_dir() -> str | None:
    """
    Get the bundled language servers directory for standalone mode.

    Search order:
    1. SERENA_BUNDLED_LS_DIR environment variable
    2. Relative to executable: ./language_servers/ (for PyInstaller builds)
    3. None if not found
    """
    # Explicit env var
    env_path = os.environ.get("SERENA_BUNDLED_LS_DIR")
    if env_path and os.path.isdir(env_path):
        return env_path

    # Relative to executable (for PyInstaller/frozen builds)
    if getattr(sys, "frozen", False):
        exe_dir = pathlib.Path(sys.executable).parent
        bundled_path = exe_dir / "language_servers"
        if bundled_path.is_dir():
            return str(bundled_path)

    return None


def _get_bundled_node_path() -> str | None:
    """
    Get path to bundled Node.js if available.

    Search order:
    1. SERENA_BUNDLED_NODE environment variable
    2. Relative to executable: ./node/node[.exe] (for PyInstaller builds)
    3. None if not found (will use system Node.js)
    """
    # Explicit env var
    env_path = os.environ.get("SERENA_BUNDLED_NODE")
    if env_path and os.path.isfile(env_path):
        return env_path

    # Relative to executable (for PyInstaller/frozen builds)
    if getattr(sys, "frozen", False):
        exe_dir = pathlib.Path(sys.executable).parent
        node_name = "node.exe" if sys.platform == "win32" else "node"
        node_path = exe_dir / "node" / node_name
        if node_path.is_file():
            return str(node_path)

    return None


@dataclass
class SolidLSPSettings:
    solidlsp_dir: str = str(pathlib.Path.home() / ".solidlsp")
    """
    Path to the directory in which to store global Solid-LSP data (which is not project-specific)
    """
    project_data_relative_path: str = ".solidlsp"
    """
    Relative path within each project directory where Solid-LSP can store project-specific data, e.g. cache files.
    For instance, if this is ".solidlsp" and the project is located at "/home/user/myproject",
    then Solid-LSP will store project-specific data in "/home/user/myproject/.solidlsp".
    """
    ls_specific_settings: dict["Language", dict[str, Any]] = field(default_factory=dict)
    """
    Advanced configuration option allowing to configure language server implementation specific options.
    Have a look at the docstring of the constructors of the corresponding LS implementations within solidlsp to see which options are available.
    No documentation on options means no options are available.
    """

    # Standalone mode settings
    standalone_mode: bool = field(default_factory=_is_standalone_mode)
    """
    If True, prefer bundled language servers over downloading.
    Automatically set from SERENA_STANDALONE environment variable.
    """
    bundled_ls_dir: str | None = field(default_factory=_get_bundled_ls_dir)
    """
    Path to bundled language servers directory for standalone/offline mode.
    """
    bundled_node_path: str | None = field(default_factory=_get_bundled_node_path)
    """
    Path to bundled Node.js executable for standalone mode.
    Used by TypeScript, Bash, and other npm-based language servers.
    """
    allow_download_fallback: bool = True
    """
    If True and bundled LS not found, fall back to downloading.
    Set to False for strict offline mode.
    """

    def __post_init__(self) -> None:
        os.makedirs(str(self.solidlsp_dir), exist_ok=True)
        os.makedirs(str(self.ls_resources_dir), exist_ok=True)

        if self.standalone_mode:
            log.info("Running in standalone mode")
            if self.bundled_ls_dir:
                log.info("Bundled LS directory: %s", self.bundled_ls_dir)
            if self.bundled_node_path:
                log.info("Bundled Node.js: %s", self.bundled_node_path)

    @property
    def ls_resources_dir(self) -> str:
        return os.path.join(str(self.solidlsp_dir), "language_servers", "static")

    class CustomLSSettings(ToStringMixin):
        def __init__(self, settings: dict[str, Any] | None) -> None:
            self.settings = settings or {}

        def get(self, key: str, default_value: Any = None) -> Any:
            """
            Returns the custom setting for the given key or the default value if not set.
            If a custom value is set for the given key, the retrieval is logged.

            :param key: the key
            :param default_value: the default value to use if no custom value is set
            :return: the value
            """
            if key in self.settings:
                value = self.settings[key]
                log.info("Using custom LS setting %s for key '%s'", value, key)
            else:
                value = default_value
            return value

    def get_ls_specific_settings(self, language: "Language") -> CustomLSSettings:
        """
        Get the language server specific settings for the given language.

        :param language: The programming language.
        :return: A dictionary of settings for the language server.
        """
        return self.CustomLSSettings(self.ls_specific_settings.get(language))
