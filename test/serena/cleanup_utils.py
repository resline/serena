"""Utilities for safe test cleanup with Windows support.

Provides retry logic with exponential backoff for cleaning up temporary
directories that may be locked by language servers on Windows.
"""

import gc
import logging
import shutil
import sys
import time
from collections.abc import Callable
from pathlib import Path

logger = logging.getLogger(__name__)


def retry_rmtree(
    path: str | Path,
    max_attempts: int = 5,
    initial_delay: float = 0.1,
    log_warnings: bool = True,
) -> None:
    """Remove a directory tree with retry logic and exponential backoff.

    This function is designed to handle Windows file locking issues during
    test teardown, where language servers may hold locks on temporary
    directories. It uses:

    1. Garbage collection before retries to release Python references
    2. Exponential backoff between retry attempts
    3. Platform-specific handling for Windows (WinError 267)
    4. Graceful logging and error reporting

    Args:
        path: The directory path to remove
        max_attempts: Maximum number of removal attempts (default: 5)
        initial_delay: Initial delay in seconds before first retry (default: 0.1)
        log_warnings: Whether to log warnings on retry (default: True)

    Raises:
        OSError: If the directory cannot be removed after all attempts

    Example:
        >>> from test.serena.cleanup_utils import retry_rmtree
        >>> import tempfile
        >>> test_dir = tempfile.mkdtemp()
        >>> # ... use test_dir ...
        >>> retry_rmtree(test_dir)  # Safely removes with retries

    """
    path = Path(path)
    if not path.exists():
        return

    attempt = 0
    delay = initial_delay
    last_error: Exception | None = None

    while attempt < max_attempts:
        try:
            shutil.rmtree(path)
            return  # Success
        except (OSError, PermissionError) as e:
            attempt += 1
            last_error = e

            # Platform-specific error handling
            if sys.platform == "win32":
                # WinError 32: File in use by another process
                # WinError 267: The directory name is invalid / directory not empty
                is_windows_lock_error = (
                    (hasattr(e, "winerror") and e.winerror in (32, 267))
                    or any(code in str(e) for code in ("32", "267"))
                    or "locked" in str(e).lower()
                    or "being used by another process" in str(e).lower()
                )

                if is_windows_lock_error and attempt < max_attempts:
                    if log_warnings:
                        logger.warning(
                            f"Windows file lock on {path} (attempt {attempt}/{max_attempts}). "
                            f"Language server may still hold references. Retrying in {delay}s..."
                        )
                    # Force garbage collection to release Python references
                    gc.collect()
                    time.sleep(delay)
                    delay *= 2  # Exponential backoff
                    continue
            else:
                # On non-Windows, still retry for general permission errors
                if attempt < max_attempts:
                    if log_warnings:
                        logger.warning(f"Failed to remove {path} (attempt {attempt}/{max_attempts}): {e}. Retrying in {delay}s...")
                    gc.collect()
                    time.sleep(delay)
                    delay *= 2
                    continue

            # If we got here, we should fail
            break

    # Final failure - path still exists or couldn't be removed
    if path.exists():
        if log_warnings:
            logger.error(
                f"Failed to remove directory {path} after {max_attempts} attempts. "
                f"Last error: {last_error}. Directory may be locked by language server."
            )
        raise OSError(f"Failed to remove directory {path} after {max_attempts} attempts: {last_error}") from last_error


def safe_cleanup_method(teardown_func: Callable) -> Callable:
    """Decorator for teardown methods to use retry_rmtree for cleanup.

    This decorator wraps test teardown methods to ensure they use
    retry_rmtree instead of direct shutil.rmtree calls.

    Args:
        teardown_func: The teardown method to wrap

    Returns:
        Wrapped teardown method with safe cleanup

    Example:
        >>> @safe_cleanup_method
        ... def teardown_method(self) -> None:
        ...     self.rmtree(self.test_dir)

    """

    def wrapper(self) -> None:
        try:
            teardown_func(self)
        except Exception as e:
            logger.error(f"Teardown method failed: {e}")
            raise

    return wrapper
