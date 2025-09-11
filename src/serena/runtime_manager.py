"""
Runtime Manager for Serena Portable
Manages embedded portable runtimes (Node.js, .NET, Java) for offline functionality.
"""

import json
import logging
import os
import subprocess
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger(__name__)


@dataclass
class RuntimeInfo:
    """Information about an embedded runtime."""

    name: str
    path: Path
    executable: str
    version: str
    required_for: list[str]
    is_available: bool = False


class PortableRuntimeManager:
    """Manages portable runtime environments for offline operation."""

    def __init__(self) -> None:
        """Initialize the runtime manager."""
        self.app_dir = self._get_app_directory()
        self.runtimes_dir = self.app_dir / "runtimes"
        self.config_file = self.runtimes_dir / "runtime-config.json"
        self.offline_mode = os.environ.get("SERENA_OFFLINE_MODE", "0") == "1"
        self.runtimes: dict[str, RuntimeInfo] = {}

        # Initialize runtime information
        self._initialize_runtimes()

    def _get_app_directory(self) -> Path:
        """Get the application directory (handles PyInstaller bundle)."""
        if getattr(sys, "frozen", False):
            # Running in PyInstaller bundle
            if hasattr(sys, "_MEIPASS"):
                # PyInstaller >= 3.3
                return Path(sys._MEIPASS)  # type: ignore[attr-defined]
            else:
                # PyInstaller < 3.3
                return Path(os.path.dirname(sys.executable))
        else:
            # Running in normal Python environment
            return Path(__file__).parent.parent.parent

    def _initialize_runtimes(self) -> None:
        """Initialize runtime information from config or defaults."""
        # Default runtime definitions
        self.runtimes = {
            "nodejs": RuntimeInfo(
                name="Node.js",
                path=self.runtimes_dir / "nodejs",
                executable="node.exe" if sys.platform == "win32" else "node",
                version="20.11.1",
                required_for=[
                    "pyright",
                    "typescript-language-server",
                    "bash-language-server",
                    "intelephense",
                ],
                is_available=False,
            ),
            "dotnet": RuntimeInfo(
                name=".NET Runtime",
                path=self.runtimes_dir / "dotnet",
                executable="dotnet.exe" if sys.platform == "win32" else "dotnet",
                version="9.0.0",
                required_for=["csharp-language-server"],
                is_available=False,
            ),
            "java": RuntimeInfo(
                name="Java Runtime",
                path=self.runtimes_dir / "java",
                executable=os.path.join("bin", "java.exe" if sys.platform == "win32" else "java"),
                version="21",
                required_for=["eclipse-jdtls", "kotlin-language-server"],
                is_available=False,
            ),
        }

        # Load runtime config if available
        if self.config_file.exists():
            try:
                with open(self.config_file) as f:
                    config = json.load(f)
                    self._update_from_config(config)
            except Exception as e:  # pragma: no cover - non-critical
                logger.warning(f"Failed to load runtime config: {e}")

        # Check runtime availability
        self._check_runtime_availability()

    def _update_from_config(self, config: dict[str, Any]) -> None:
        """Update runtime information from configuration."""
        if "runtimes" in config:
            for runtime_name, runtime_config in config["runtimes"].items():
                if runtime_name in self.runtimes:
                    runtime = self.runtimes[runtime_name]
                    if "path" in runtime_config:
                        runtime.path = self.runtimes_dir / runtime_config["path"]
                    if "executable" in runtime_config:
                        runtime.executable = runtime_config["executable"]
                    if "version" in runtime_config:
                        runtime.version = runtime_config["version"]

    def _check_runtime_availability(self) -> None:
        """Check which runtimes are actually available."""
        for runtime in self.runtimes.values():
            exe_path = runtime.path / runtime.executable
            runtime.is_available = exe_path.exists()
            if runtime.is_available:
                logger.info("Portable %s found at: %s", runtime.name, exe_path)
            else:
                logger.debug("Portable %s not found at: %s", runtime.name, exe_path)

    def get_runtime_executable(self, runtime_name: str) -> Optional[str]:
        """Get the full path to a runtime executable if available."""
        runtime = self.runtimes.get(runtime_name)
        if not runtime or not runtime.is_available:
            return None
        exe_path = runtime.path / runtime.executable
        return str(exe_path) if exe_path.exists() else None

    def setup_runtime_environment(self, runtime_name: str) -> dict[str, str]:
        """Setup environment variables for a specific runtime."""
        env = os.environ.copy()
        runtime = self.runtimes.get(runtime_name)
        if not runtime or not runtime.is_available:
            return env

        if runtime_name == "nodejs":
            # Add Node.js to PATH
            node_bin = str(runtime.path)
            env["PATH"] = f"{node_bin}{os.pathsep}{env.get('PATH', '')}"
            # Set npm cache for offline packages
            npm_cache = self.runtimes_dir / "npm-cache"
            if npm_cache.exists():
                env["NODE_PATH"] = str(npm_cache)
                env["npm_config_cache"] = str(npm_cache)
                env["npm_config_offline"] = "true"
            logger.debug("Node.js environment configured with PATH: %s", node_bin)
        elif runtime_name == "dotnet":
            # Add .NET to PATH
            dotnet_bin = str(runtime.path)
            env["PATH"] = f"{dotnet_bin}{os.pathsep}{env.get('PATH', '')}"
            env["DOTNET_ROOT"] = str(runtime.path)
            env["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
            logger.debug(".NET environment configured with DOTNET_ROOT: %s", runtime.path)
        elif runtime_name == "java":
            # Add Java to PATH
            java_bin = str(runtime.path / "bin")
            env["PATH"] = f"{java_bin}{os.pathsep}{env.get('PATH', '')}"
            env["JAVA_HOME"] = str(runtime.path)
            logger.debug("Java environment configured with JAVA_HOME: %s", runtime.path)

        return env

    def find_npm_package(self, package_name: str) -> Optional[Path]:
        """Find an npm package in the offline cache."""
        npm_cache = self.runtimes_dir / "npm-cache"
        if not npm_cache.exists():
            return None

        # Check common locations for the package
        possible_paths = [
            npm_cache / package_name,
            npm_cache / package_name / "node_modules" / package_name,
            npm_cache / "node_modules" / package_name,
        ]
        for path in possible_paths:
            if path.exists():
                logger.debug("Found npm package %s at: %s", package_name, path)
                return path
        return None

    def get_npm_binary(self, package_name: str, binary_name: str) -> Optional[str]:
        """Get the path to an npm package binary."""
        package_path = self.find_npm_package(package_name)
        if not package_path:
            return None

        # Check for binary in common locations
        if sys.platform == "win32":
            binary_name = f"{binary_name}.cmd" if not binary_name.endswith(".cmd") else binary_name

        possible_paths = [
            package_path / "node_modules" / ".bin" / binary_name,
            package_path / ".bin" / binary_name,
            package_path / binary_name,
        ]
        for path in possible_paths:
            if path.exists():
                return str(path)
        return None

    def verify_runtime(self, runtime_name: str) -> bool:
        """Verify that a runtime is working correctly."""
        runtime = self.runtimes.get(runtime_name)
        if not runtime or not runtime.is_available:
            return False

        exe_path = runtime.path / runtime.executable
        try:
            if runtime_name == "nodejs":
                result = subprocess.run(
                    [str(exe_path), "--version"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                    check=False,
                )
                return result.returncode == 0 and "v" in result.stdout
            elif runtime_name == "dotnet":
                result = subprocess.run(
                    [str(exe_path), "--list-runtimes"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                    check=False,
                )
                return result.returncode == 0 and "Microsoft" in result.stdout
            elif runtime_name == "java":
                result = subprocess.run(
                    [str(exe_path), "-version"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                    check=False,
                )
                return result.returncode == 0
        except Exception as e:  # pragma: no cover - external process
            logger.error("Failed to verify %s: %s", runtime.name, e)
            return False

        return False

    def get_language_server_command(self, server_name: str) -> Optional[list[str]]:
        """Get the command to run a language server with portable runtime."""
        # Map language servers to their runtime requirements
        server_runtime_map = {
            "pyright": "nodejs",
            "typescript-language-server": "nodejs",
            "bash-language-server": "nodejs",
            "intelephense": "nodejs",
            "csharp-language-server": "dotnet",
            "eclipse-jdtls": "java",
            "kotlin-language-server": "java",
        }

        runtime_name = server_runtime_map.get(server_name)
        if not runtime_name:
            return None

        runtime_exe = self.get_runtime_executable(runtime_name)
        if not runtime_exe:
            return None

        # Build command based on server type
        if server_name == "pyright":
            # Check for offline pyright package
            pyright_bin = self.get_npm_binary("pyright", "pyright-langserver")
            if pyright_bin:
                return [runtime_exe, pyright_bin, "--stdio"]
            return [runtime_exe, "-m", "pyright.langserver", "--stdio"]
        if server_name == "typescript-language-server":
            tsls_bin = self.get_npm_binary("typescript-language-server", "typescript-language-server")
            if tsls_bin:
                return [runtime_exe, tsls_bin, "--stdio"]
        if server_name == "bash-language-server":
            bash_ls_bin = self.get_npm_binary("bash-language-server", "bash-language-server")
            if bash_ls_bin:
                return [runtime_exe, bash_ls_bin, "start"]
        if server_name == "csharp-language-server":
            # Assuming the C# language server DLL is bundled
            dll_path = self.app_dir / "language_servers" / "csharp" / "Microsoft.CodeAnalysis.LanguageServer.dll"
            if dll_path.exists():
                return [runtime_exe, str(dll_path), "--stdio"]
        if server_name == "eclipse-jdtls":
            # Java language server with launcher JAR
            launcher_jars = list(
                (self.app_dir / "language_servers" / "java" / "plugins").glob(
                    "org.eclipse.equinox.launcher_*.jar"
                )
            )
            if launcher_jars:
                return [
                    runtime_exe,
                    "-jar",
                    str(launcher_jars[0]),
                    "-configuration",
                    "config",
                    "-data",
                    "workspace",
                ]
        return None

    def is_offline_capable(self, server_name: str) -> bool:
        """Check if a language server can run offline with embedded runtimes."""
        command = self.get_language_server_command(server_name)
        return command is not None

    def get_status_report(self) -> dict[str, Any]:
        """Get a status report of all runtimes and their availability."""
        report: dict[str, Any] = {"offline_mode": self.offline_mode, "runtimes": {}, "language_servers": {}}

        # Runtime status
        for name, runtime in self.runtimes.items():
            report["runtimes"][name] = {
                "available": runtime.is_available,
                "version": runtime.version,
                "path": str(runtime.path) if runtime.is_available else None,
                "required_for": runtime.required_for,
                "verified": self.verify_runtime(name) if runtime.is_available else False,
            }

        # Language server offline capability
        servers = [
            "pyright",
            "typescript-language-server",
            "bash-language-server",
            "intelephense",
            "csharp-language-server",
            "eclipse-jdtls",
            "kotlin-language-server",
        ]
        for server in servers:
            report["language_servers"][server] = {
                "offline_capable": self.is_offline_capable(server),
                "command": self.get_language_server_command(server),
            }

        return report


@lru_cache(maxsize=1)
def get_runtime_manager() -> PortableRuntimeManager:
    """Get or create the cached runtime manager instance."""
    return PortableRuntimeManager()


def setup_offline_runtime(runtime_name: str) -> dict[str, str]:
    """Convenience function to setup a runtime environment."""
    manager = get_runtime_manager()
    return manager.setup_runtime_environment(runtime_name)


def get_offline_language_server_command(server_name: str) -> Optional[list[str]]:
    """Convenience function to get an offline language server command."""
    manager = get_runtime_manager()
    return manager.get_language_server_command(server_name)
