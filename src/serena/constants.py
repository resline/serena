import sys
from pathlib import Path


def _get_serena_pkg_path() -> Path:
    """
    Return the path to the serena package directory.
    Handles both normal Python execution and PyInstaller frozen builds.
    """
    if getattr(sys, "frozen", False):
        # Running as PyInstaller bundle - resources are in _MEIPASS
        return Path(sys._MEIPASS) / "serena"  # type: ignore[attr-defined]
    return Path(__file__).parent.resolve()


def _get_repo_root_path() -> Path:
    """Return the repository root path (only meaningful in development mode)."""
    if getattr(sys, "frozen", False):
        # In frozen mode, return the directory containing the executable
        return Path(sys.executable).parent.resolve()
    return Path(__file__).parent.parent.parent.resolve()


_repo_root_path = _get_repo_root_path()
_serena_pkg_path = _get_serena_pkg_path()

SERENA_MANAGED_DIR_NAME = ".serena"

# TODO: Path-related constants should be moved to SerenaPaths; don't add further constants here.
REPO_ROOT = str(_repo_root_path)
PROMPT_TEMPLATES_DIR_INTERNAL = str(_serena_pkg_path / "resources" / "config" / "prompt_templates")
SERENAS_OWN_CONTEXT_YAMLS_DIR = str(_serena_pkg_path / "resources" / "config" / "contexts")
"""The contexts that are shipped with the Serena package, i.e. the default contexts."""
SERENAS_OWN_MODE_YAMLS_DIR = str(_serena_pkg_path / "resources" / "config" / "modes")
"""The modes that are shipped with the Serena package, i.e. the default modes."""
INTERNAL_MODE_YAMLS_DIR = str(_serena_pkg_path / "resources" / "config" / "internal_modes")
"""Internal modes, never overridden by user modes."""
SERENA_DASHBOARD_DIR = str(_serena_pkg_path / "resources" / "dashboard")
SERENA_ICON_DIR = str(_serena_pkg_path / "resources" / "icons")

DEFAULT_SOURCE_FILE_ENCODING = "utf-8"
"""The default encoding assumed for project source files."""
DEFAULT_CONTEXT = "desktop-app"
DEFAULT_MODES = ("interactive", "editing")

SERENA_FILE_ENCODING = "utf-8"
"""The encoding used for Serena's own files, such as configuration files and memories."""

PROJECT_TEMPLATE_FILE = str(_serena_pkg_path / "resources" / "project.template.yml")
SERENA_CONFIG_TEMPLATE_FILE = str(_serena_pkg_path / "resources" / "serena_config.template.yml")

SERENA_LOG_FORMAT = "%(levelname)-5s %(asctime)-15s [%(threadName)s] %(name)s:%(funcName)s:%(lineno)d - %(message)s"
