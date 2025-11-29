"""
Tests for bundled language server functionality (offline/standalone mode).
"""

from __future__ import annotations

import tempfile
from pathlib import Path

from solidlsp.language_servers.common import (
    check_bundled_ls,
    copy_bundled_ls_to_cache,
    should_download_ls,
)
from solidlsp.settings import SolidLSPSettings


class TestCheckBundledLS:
    """Tests for check_bundled_ls function."""

    def test_returns_none_when_bundled_ls_dir_not_set(self) -> None:
        """Should return None when bundled_ls_dir is not configured."""
        settings = SolidLSPSettings(bundled_ls_dir=None)
        result = check_bundled_ls(settings, "clangd", "clangd_19.1.2/bin/clangd")
        assert result is None

    def test_returns_path_when_bundled_binary_exists(self) -> None:
        """Should return full path when bundled binary exists."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create mock bundled LS structure
            bundled_dir = Path(tmpdir) / "language_servers"
            binary_path = bundled_dir / "clangd" / "clangd_19.1.2" / "bin" / "clangd"
            binary_path.parent.mkdir(parents=True)
            binary_path.touch()

            settings = SolidLSPSettings(bundled_ls_dir=str(bundled_dir))
            result = check_bundled_ls(settings, "clangd", "clangd_19.1.2/bin/clangd")

            assert result == str(binary_path)

    def test_returns_none_when_bundled_binary_not_exists(self) -> None:
        """Should return None when bundled binary doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            bundled_dir = Path(tmpdir) / "language_servers"
            bundled_dir.mkdir(parents=True)

            settings = SolidLSPSettings(bundled_ls_dir=str(bundled_dir))
            result = check_bundled_ls(settings, "clangd", "clangd_19.1.2/bin/clangd")

            assert result is None

    def test_works_with_windows_binary_path(self) -> None:
        """Should work with Windows-style binary names."""
        with tempfile.TemporaryDirectory() as tmpdir:
            bundled_dir = Path(tmpdir) / "language_servers"
            binary_path = bundled_dir / "clangd" / "clangd_19.1.2" / "bin" / "clangd.exe"
            binary_path.parent.mkdir(parents=True)
            binary_path.touch()

            settings = SolidLSPSettings(bundled_ls_dir=str(bundled_dir))
            result = check_bundled_ls(settings, "clangd", "clangd_19.1.2/bin/clangd.exe")

            assert result == str(binary_path)


class TestCopyBundledLSToCache:
    """Tests for copy_bundled_ls_to_cache function."""

    def test_returns_false_when_bundled_ls_dir_not_set(self) -> None:
        """Should return False when bundled_ls_dir is not configured."""
        settings = SolidLSPSettings(bundled_ls_dir=None)

        with tempfile.TemporaryDirectory() as tmpdir:
            result = copy_bundled_ls_to_cache(settings, "clangd", tmpdir)
            assert result is False

    def test_returns_false_when_bundled_source_not_exists(self) -> None:
        """Should return False when bundled source directory doesn't exist."""
        with tempfile.TemporaryDirectory() as tmpdir:
            bundled_dir = Path(tmpdir) / "language_servers"
            bundled_dir.mkdir(parents=True)

            settings = SolidLSPSettings(bundled_ls_dir=str(bundled_dir))
            result = copy_bundled_ls_to_cache(settings, "nonexistent", str(Path(tmpdir) / "cache"))

            assert result is False

    def test_copies_bundled_files_to_target(self) -> None:
        """Should copy bundled files to target directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create mock bundled LS
            bundled_dir = Path(tmpdir) / "language_servers"
            bundled_ls = bundled_dir / "clangd"
            (bundled_ls / "bin").mkdir(parents=True)
            (bundled_ls / "bin" / "clangd").write_text("mock binary")
            (bundled_ls / "lib").mkdir()
            (bundled_ls / "lib" / "libfoo.so").write_text("mock lib")

            # Target cache directory
            target_dir = Path(tmpdir) / "cache" / "clangd"

            settings = SolidLSPSettings(bundled_ls_dir=str(bundled_dir))
            result = copy_bundled_ls_to_cache(settings, "clangd", str(target_dir))

            assert result is True
            assert (target_dir / "bin" / "clangd").exists()
            assert (target_dir / "lib" / "libfoo.so").exists()

    def test_skips_copy_when_target_has_content(self) -> None:
        """Should skip copy when target directory already has content."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create mock bundled LS
            bundled_dir = Path(tmpdir) / "language_servers"
            bundled_ls = bundled_dir / "clangd"
            bundled_ls.mkdir(parents=True)
            (bundled_ls / "new_file.txt").write_text("new content")

            # Create target with existing content
            target_dir = Path(tmpdir) / "cache" / "clangd"
            target_dir.mkdir(parents=True)
            (target_dir / "existing_file.txt").write_text("existing content")

            settings = SolidLSPSettings(bundled_ls_dir=str(bundled_dir))
            result = copy_bundled_ls_to_cache(settings, "clangd", str(target_dir))

            # Should return True (content exists) but not overwrite
            assert result is True
            assert (target_dir / "existing_file.txt").exists()
            # New file should NOT be copied
            assert not (target_dir / "new_file.txt").exists()


class TestShouldDownloadLS:
    """Tests for should_download_ls function."""

    def test_returns_true_in_normal_mode(self) -> None:
        """Should return True when not in standalone mode."""
        settings = SolidLSPSettings(standalone_mode=False)
        assert should_download_ls(settings) is True

    def test_returns_true_when_standalone_without_bundled_dir(self) -> None:
        """Should return True in standalone mode without bundled_ls_dir."""
        settings = SolidLSPSettings(standalone_mode=True, bundled_ls_dir=None)
        assert should_download_ls(settings) is True

    def test_returns_true_when_standalone_with_fallback_allowed(self) -> None:
        """Should return True in standalone mode with allow_download_fallback=True."""
        with tempfile.TemporaryDirectory() as tmpdir:
            settings = SolidLSPSettings(standalone_mode=True, bundled_ls_dir=tmpdir, allow_download_fallback=True)
            assert should_download_ls(settings) is True

    def test_returns_false_when_standalone_without_fallback(self) -> None:
        """Should return False in standalone mode with allow_download_fallback=False."""
        with tempfile.TemporaryDirectory() as tmpdir:
            settings = SolidLSPSettings(standalone_mode=True, bundled_ls_dir=tmpdir, allow_download_fallback=False)
            assert should_download_ls(settings) is False


class TestBundleLSScript:
    """Tests for bundle_language_servers.py script."""

    def test_script_exists(self) -> None:
        """Verify the bundle script exists."""
        script_path = Path(__file__).parent.parent.parent / "scripts" / "bundle_language_servers.py"
        assert script_path.exists(), f"Script not found at {script_path}"

    def test_script_can_be_imported(self) -> None:
        """Verify the script can be imported."""
        import sys

        script_dir = str(Path(__file__).parent.parent.parent / "scripts")
        sys.path.insert(0, script_dir)
        try:
            # Just verify it can be imported without errors
            import bundle_language_servers

            assert hasattr(bundle_language_servers, "LANGUAGE_SERVERS")
            assert hasattr(bundle_language_servers, "download_language_server")
        finally:
            sys.path.remove(script_dir)

    def test_dry_run_does_not_download(self) -> None:
        """Verify dry-run mode doesn't download anything."""
        import subprocess
        import sys

        script_path = Path(__file__).parent.parent.parent / "scripts" / "bundle_language_servers.py"

        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                [
                    sys.executable,
                    str(script_path),
                    "--dry-run",
                    "--output-dir",
                    tmpdir,
                    "--ls",
                    "clangd",
                ],
                check=False,
                capture_output=True,
                text=True,
            )

            # Should succeed
            assert result.returncode == 0, f"Script failed: {result.stderr}"

            # Should not create any directories (except output-dir itself)
            output_dir = Path(tmpdir)
            subdirs = list(output_dir.iterdir())
            assert len(subdirs) == 0, f"Dry-run created files: {subdirs}"
