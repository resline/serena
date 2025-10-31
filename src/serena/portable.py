"""
Portable mode detection and path management for Serena.

This module provides utilities for running Serena in portable mode, where all
configuration, data, and language servers are bundled within a single directory
structure. This enables running Serena on systems without installation or with
restricted permissions.

Portable mode is activated by setting the SERENA_PORTABLE_DIR environment variable
to point to the root of the portable installation directory.
"""

import os
from pathlib import Path
from typing import Optional


def is_portable_mode() -> bool:
    """
    Check if Serena is running in portable mode.

    Returns:
        bool: True if SERENA_PORTABLE_DIR environment variable is set, False otherwise.

    """
    return os.environ.get("SERENA_PORTABLE_DIR") is not None


def get_portable_root() -> Optional[Path]:
    """
    Get the portable installation root directory.

    Returns:
        Optional[Path]: Resolved path to the portable root directory if in portable mode,
                       None otherwise.

    """
    portable_dir = os.environ.get("SERENA_PORTABLE_DIR")
    if portable_dir:
        return Path(portable_dir).resolve()
    return None


def get_serena_data_dir() -> Path:
    """
    Get the Serena data directory (portable-aware).

    In portable mode, returns a directory within the portable package.
    Otherwise, returns the standard user home directory location.

    Returns:
        Path: Path to the Serena data directory. Creates the directory if it
             doesn't exist in portable mode.

    """
    if is_portable_mode():
        portable_root = get_portable_root()
        if portable_root:
            # Use data directory within portable package
            data_dir = portable_root / "data" / ".serena"
            data_dir.mkdir(parents=True, exist_ok=True)
            return data_dir

    # Default: user home directory
    return Path.home() / ".serena"


def get_solidlsp_data_dir() -> Path:
    """
    Get the SolidLSP data directory (portable-aware).

    In portable mode, returns a directory within the portable package.
    Otherwise, returns the standard user home directory location.

    Returns:
        Path: Path to the SolidLSP data directory. Creates the directory if it
             doesn't exist in portable mode.

    """
    if is_portable_mode():
        portable_root = get_portable_root()
        if portable_root:
            # Use data directory within portable package
            data_dir = portable_root / "data" / ".solidlsp"
            data_dir.mkdir(parents=True, exist_ok=True)
            return data_dir

    # Default: user home directory
    return Path.home() / ".solidlsp"


def get_language_server_dir() -> Path:
    """
    Get the pre-downloaded language server directory (portable-aware).

    In portable mode, returns the bundled language servers directory.
    Otherwise, returns the standard SolidLSP resources directory.

    Returns:
        Path: Path to the language server directory.

    """
    if is_portable_mode():
        portable_root = get_portable_root()
        if portable_root:
            # Use bundled language servers
            ls_dir = portable_root / "language_servers" / "static"
            if ls_dir.exists():
                return ls_dir

    # Default: SolidLSP resources directory
    return get_solidlsp_data_dir() / "language_servers" / "static"


def get_portable_paths() -> dict[str, Optional[Path]]:
    """
    Get all portable-mode paths.

    Returns:
        dict[str, Optional[Path]]: Dictionary containing all relevant portable paths:
            - portable_root: Root directory of portable installation (None if not portable)
            - serena_data: Serena data directory
            - solidlsp_data: SolidLSP data directory
            - language_servers: Language servers directory

    """
    return {
        "portable_root": get_portable_root(),
        "serena_data": get_serena_data_dir(),
        "solidlsp_data": get_solidlsp_data_dir(),
        "language_servers": get_language_server_dir(),
    }
