"""Tests for portable mode functionality."""

import os
from pathlib import Path

from serena.portable import (
    get_language_server_dir,
    get_portable_root,
    get_serena_data_dir,
    get_solidlsp_data_dir,
    is_portable_mode,
)


def test_portable_mode_detection():
    """Test portable mode is detected correctly."""
    # Save original state
    original = os.environ.get("SERENA_PORTABLE_DIR")

    try:
        # Without env var
        if "SERENA_PORTABLE_DIR" in os.environ:
            del os.environ["SERENA_PORTABLE_DIR"]
        assert not is_portable_mode()

        # With env var
        os.environ["SERENA_PORTABLE_DIR"] = "/tmp/serena-portable"
        assert is_portable_mode()
        assert get_portable_root() == Path("/tmp/serena-portable")
    finally:
        # Restore original state
        if original:
            os.environ["SERENA_PORTABLE_DIR"] = original
        elif "SERENA_PORTABLE_DIR" in os.environ:
            del os.environ["SERENA_PORTABLE_DIR"]


def test_portable_data_dirs(tmp_path):
    """Test data directories in portable mode."""
    # Save original state
    original = os.environ.get("SERENA_PORTABLE_DIR")

    try:
        portable_dir = tmp_path / "serena-portable"
        portable_dir.mkdir()
        os.environ["SERENA_PORTABLE_DIR"] = str(portable_dir)

        serena_dir = get_serena_data_dir()
        assert str(serena_dir).startswith(str(portable_dir / "data"))

        solidlsp_dir = get_solidlsp_data_dir()
        assert str(solidlsp_dir).startswith(str(portable_dir / "data"))

        ls_dir = get_language_server_dir()
        assert "language_servers" in str(ls_dir)
        assert "static" in str(ls_dir)
    finally:
        # Restore original state
        if original:
            os.environ["SERENA_PORTABLE_DIR"] = original
        elif "SERENA_PORTABLE_DIR" in os.environ:
            del os.environ["SERENA_PORTABLE_DIR"]


def test_normal_mode_data_dirs():
    """Test data directories in normal mode."""
    # Save original state
    original = os.environ.get("SERENA_PORTABLE_DIR")

    try:
        # Ensure no portable mode
        if "SERENA_PORTABLE_DIR" in os.environ:
            del os.environ["SERENA_PORTABLE_DIR"]

        serena_dir = get_serena_data_dir()
        assert ".serena" in str(serena_dir)

        solidlsp_dir = get_solidlsp_data_dir()
        assert ".solidlsp" in str(solidlsp_dir)
    finally:
        # Restore original state
        if original:
            os.environ["SERENA_PORTABLE_DIR"] = original
