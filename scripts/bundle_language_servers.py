#!/usr/bin/env python3
"""
Script to download and bundle binary language servers for offline/standalone builds.

This script downloads the language server binaries for the specified platforms
and prepares them for bundling with PyInstaller builds.

Supported language servers (default):
- Clangd (C/C++) - ~100 MB
- Terraform-LS (Terraform) - ~50 MB
- Dart SDK (Dart) - ~200 MB
- Rust Analyzer (Rust) - ~20 MB
- Lua Language Server (Lua) - ~5 MB

Optional language servers (with --include-java):
- Eclipse JDTLS (Java) - ~150 MB
- Gradle (Java build tool) - ~50 MB
- Kotlin Language Server (Kotlin) - ~85 MB

Optional language servers (with --include-go):
- Gopls (Go) - ~30 MB (requires Go toolchain to build)

Usage:
    python scripts/bundle_language_servers.py [OPTIONS]

Options:
    --platform PLATFORM   Target platform (linux-x64, win-x64, osx-x64, osx-arm64)
                         Default: auto-detect current platform
    --output-dir DIR      Output directory for bundled LS (default: ./language_servers)
    --include-java        Include Eclipse JDTLS, Gradle, and Kotlin LS (adds ~285MB)
    --include-go          Include Gopls (requires Go toolchain, adds ~30MB)
    --dry-run            Show what would be downloaded without downloading
    --verbose            Enable verbose output
    --ls ID [ID ...]      Only bundle specific language servers by ID
"""

from __future__ import annotations

import argparse
import logging
import os
import platform
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from solidlsp.ls_utils import FileUtils, PlatformUtils

log = logging.getLogger(__name__)


@dataclass
class LanguageServerBundle:
    """Defines a language server to bundle."""

    id: str
    name: str
    description: str
    platforms: dict[str, dict[str, Any]]
    estimated_size_mb: int
    optional: bool = False


# Language server definitions with download URLs for each platform
LANGUAGE_SERVERS: list[LanguageServerBundle] = [
    LanguageServerBundle(
        id="clangd",
        name="Clangd",
        description="C/C++ language server",
        estimated_size_mb=100,
        platforms={
            "linux-x64": {
                "url": "https://github.com/clangd/clangd/releases/download/19.1.2/clangd-linux-19.1.2.zip",
                "archive_type": "zip",
                "binary_path": "clangd_19.1.2/bin/clangd",
                "target_dir": "clangd",
            },
            "win-x64": {
                "url": "https://github.com/clangd/clangd/releases/download/19.1.2/clangd-windows-19.1.2.zip",
                "archive_type": "zip",
                "binary_path": "clangd_19.1.2/bin/clangd.exe",
                "target_dir": "clangd",
            },
            "osx-x64": {
                "url": "https://github.com/clangd/clangd/releases/download/19.1.2/clangd-mac-19.1.2.zip",
                "archive_type": "zip",
                "binary_path": "clangd_19.1.2/bin/clangd",
                "target_dir": "clangd",
            },
            "osx-arm64": {
                "url": "https://github.com/clangd/clangd/releases/download/19.1.2/clangd-mac-19.1.2.zip",
                "archive_type": "zip",
                "binary_path": "clangd_19.1.2/bin/clangd",
                "target_dir": "clangd",
            },
        },
    ),
    LanguageServerBundle(
        id="terraform-ls",
        name="Terraform-LS",
        description="Terraform language server",
        estimated_size_mb=50,
        platforms={
            "linux-x64": {
                "url": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_linux_amd64.zip",
                "archive_type": "zip",
                "binary_path": "terraform-ls",
                "target_dir": "terraform-ls",
            },
            "linux-arm64": {
                "url": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_linux_arm64.zip",
                "archive_type": "zip",
                "binary_path": "terraform-ls",
                "target_dir": "terraform-ls",
            },
            "win-x64": {
                "url": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_windows_amd64.zip",
                "archive_type": "zip",
                "binary_path": "terraform-ls.exe",
                "target_dir": "terraform-ls",
            },
            "osx-x64": {
                "url": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_darwin_amd64.zip",
                "archive_type": "zip",
                "binary_path": "terraform-ls",
                "target_dir": "terraform-ls",
            },
            "osx-arm64": {
                "url": "https://releases.hashicorp.com/terraform-ls/0.36.5/terraform-ls_0.36.5_darwin_arm64.zip",
                "archive_type": "zip",
                "binary_path": "terraform-ls",
                "target_dir": "terraform-ls",
            },
        },
    ),
    LanguageServerBundle(
        id="dart",
        name="Dart SDK",
        description="Dart language server (via Dart SDK)",
        estimated_size_mb=200,
        platforms={
            "linux-x64": {
                "url": "https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.1/sdk/dartsdk-linux-x64-release.zip",
                "archive_type": "zip",
                "binary_path": "dart-sdk/bin/dart",
                "target_dir": "dart",
            },
            "win-x64": {
                "url": "https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.1/sdk/dartsdk-windows-x64-release.zip",
                "archive_type": "zip",
                "binary_path": "dart-sdk/bin/dart.exe",
                "target_dir": "dart",
            },
            "win-arm64": {
                "url": "https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.1/sdk/dartsdk-windows-arm64-release.zip",
                "archive_type": "zip",
                "binary_path": "dart-sdk/bin/dart.exe",
                "target_dir": "dart",
            },
            "osx-x64": {
                "url": "https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.1/sdk/dartsdk-macos-x64-release.zip",
                "archive_type": "zip",
                "binary_path": "dart-sdk/bin/dart",
                "target_dir": "dart",
            },
            "osx-arm64": {
                "url": "https://storage.googleapis.com/dart-archive/channels/stable/release/3.7.1/sdk/dartsdk-macos-arm64-release.zip",
                "archive_type": "zip",
                "binary_path": "dart-sdk/bin/dart",
                "target_dir": "dart",
            },
        },
    ),
    LanguageServerBundle(
        id="jdtls",
        name="Eclipse JDTLS",
        description="Java language server (Eclipse JDT Language Server)",
        estimated_size_mb=150,
        optional=True,
        platforms={
            "linux-x64": {
                "url": "https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-linux-x64-1.42.0-561.vsix",
                "archive_type": "zip",
                "binary_path": "extension/jre/21.0.7-linux-x86_64/bin/java",
                "target_dir": "jdtls",
                # Additional paths needed for JDTLS
                "extra_paths": {
                    "jre_home": "extension/jre/21.0.7-linux-x86_64",
                    "lombok_jar": "extension/lombok/lombok-1.18.36.jar",
                    "launcher_jar": "extension/server/plugins/org.eclipse.equinox.launcher_1.7.0.v20250424-1814.jar",
                    "config_dir": "extension/server/config_linux",
                },
            },
            "win-x64": {
                "url": "https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-win32-x64-1.42.0-561.vsix",
                "archive_type": "zip",
                "binary_path": "extension/jre/21.0.7-win32-x86_64/bin/java.exe",
                "target_dir": "jdtls",
                "extra_paths": {
                    "jre_home": "extension/jre/21.0.7-win32-x86_64",
                    "lombok_jar": "extension/lombok/lombok-1.18.36.jar",
                    "launcher_jar": "extension/server/plugins/org.eclipse.equinox.launcher_1.7.0.v20250424-1814.jar",
                    "config_dir": "extension/server/config_win",
                },
            },
            "osx-x64": {
                "url": "https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-darwin-x64-1.42.0-561.vsix",
                "archive_type": "zip",
                "binary_path": "extension/jre/21.0.7-macosx-x86_64/bin/java",
                "target_dir": "jdtls",
                "extra_paths": {
                    "jre_home": "extension/jre/21.0.7-macosx-x86_64",
                    "lombok_jar": "extension/lombok/lombok-1.18.36.jar",
                    "launcher_jar": "extension/server/plugins/org.eclipse.equinox.launcher_1.7.0.v20250424-1814.jar",
                    "config_dir": "extension/server/config_mac",
                },
            },
            "osx-arm64": {
                "url": "https://github.com/redhat-developer/vscode-java/releases/download/v1.42.0/java-darwin-arm64-1.42.0-561.vsix",
                "archive_type": "zip",
                "binary_path": "extension/jre/21.0.7-macosx-aarch64/bin/java",
                "target_dir": "jdtls",
                "extra_paths": {
                    "jre_home": "extension/jre/21.0.7-macosx-aarch64",
                    "lombok_jar": "extension/lombok/lombok-1.18.36.jar",
                    "launcher_jar": "extension/server/plugins/org.eclipse.equinox.launcher_1.7.0.v20250424-1814.jar",
                    "config_dir": "extension/server/config_mac_arm",
                },
            },
        },
    ),
    # Gradle is needed for Java projects with JDTLS
    LanguageServerBundle(
        id="gradle",
        name="Gradle",
        description="Gradle build tool (required for Java JDTLS)",
        estimated_size_mb=50,
        optional=True,
        platforms={
            # Gradle is platform-agnostic (Java-based)
            "linux-x64": {
                "url": "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip",
                "archive_type": "zip",
                "binary_path": "gradle-8.14.2/bin/gradle",
                "target_dir": "gradle",
            },
            "linux-arm64": {
                "url": "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip",
                "archive_type": "zip",
                "binary_path": "gradle-8.14.2/bin/gradle",
                "target_dir": "gradle",
            },
            "win-x64": {
                "url": "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip",
                "archive_type": "zip",
                "binary_path": "gradle-8.14.2/bin/gradle.bat",
                "target_dir": "gradle",
            },
            "osx-x64": {
                "url": "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip",
                "archive_type": "zip",
                "binary_path": "gradle-8.14.2/bin/gradle",
                "target_dir": "gradle",
            },
            "osx-arm64": {
                "url": "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip",
                "archive_type": "zip",
                "binary_path": "gradle-8.14.2/bin/gradle",
                "target_dir": "gradle",
            },
        },
    ),
    # Rust Analyzer - Rust language server
    LanguageServerBundle(
        id="rust-analyzer",
        name="Rust Analyzer",
        description="Rust language server",
        estimated_size_mb=20,
        platforms={
            "linux-x64": {
                "url": "https://github.com/rust-lang/rust-analyzer/releases/download/2025-11-24/rust-analyzer-x86_64-unknown-linux-gnu.gz",
                "archive_type": "gz",
                "binary_path": "rust-analyzer",
                "target_dir": "rust-analyzer",
            },
            "win-x64": {
                "url": "https://github.com/rust-lang/rust-analyzer/releases/download/2025-11-24/rust-analyzer-x86_64-pc-windows-msvc.zip",
                "archive_type": "zip",
                "binary_path": "rust-analyzer.exe",
                "target_dir": "rust-analyzer",
            },
            "osx-x64": {
                "url": "https://github.com/rust-lang/rust-analyzer/releases/download/2025-11-24/rust-analyzer-x86_64-apple-darwin.gz",
                "archive_type": "gz",
                "binary_path": "rust-analyzer",
                "target_dir": "rust-analyzer",
            },
            "osx-arm64": {
                "url": "https://github.com/rust-lang/rust-analyzer/releases/download/2025-11-24/rust-analyzer-aarch64-apple-darwin.gz",
                "archive_type": "gz",
                "binary_path": "rust-analyzer",
                "target_dir": "rust-analyzer",
            },
        },
    ),
    # Lua Language Server
    LanguageServerBundle(
        id="lua-ls",
        name="Lua Language Server",
        description="Lua language server",
        estimated_size_mb=5,
        platforms={
            "linux-x64": {
                "url": "https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-linux-x64.tar.gz",
                "archive_type": "gztar",  # shutil.unpack_archive format
                "binary_path": "bin/lua-language-server",
                "target_dir": "lua-ls",
            },
            "win-x64": {
                "url": "https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip",
                "archive_type": "zip",
                "binary_path": "bin/lua-language-server.exe",
                "target_dir": "lua-ls",
            },
            "osx-x64": {
                "url": "https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-darwin-x64.tar.gz",
                "archive_type": "gztar",  # shutil.unpack_archive format
                "binary_path": "bin/lua-language-server",
                "target_dir": "lua-ls",
            },
            "osx-arm64": {
                "url": "https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-darwin-arm64.tar.gz",
                "archive_type": "gztar",  # shutil.unpack_archive format
                "binary_path": "bin/lua-language-server",
                "target_dir": "lua-ls",
            },
        },
    ),
    # Kotlin Language Server (JVM-based, requires Java)
    LanguageServerBundle(
        id="kotlin-ls",
        name="Kotlin Language Server",
        description="Kotlin language server (requires Java runtime)",
        estimated_size_mb=85,
        optional=True,  # Requires Java, bundled with --include-java
        platforms={
            # Kotlin LS is platform-agnostic (JVM-based), same ZIP for all platforms
            "linux-x64": {
                "url": "https://github.com/fwcd/kotlin-language-server/releases/download/1.3.13/server.zip",
                "archive_type": "zip",
                "binary_path": "server/bin/kotlin-language-server",
                "target_dir": "kotlin-ls",
            },
            "win-x64": {
                "url": "https://github.com/fwcd/kotlin-language-server/releases/download/1.3.13/server.zip",
                "archive_type": "zip",
                "binary_path": "server/bin/kotlin-language-server.bat",
                "target_dir": "kotlin-ls",
            },
            "osx-x64": {
                "url": "https://github.com/fwcd/kotlin-language-server/releases/download/1.3.13/server.zip",
                "archive_type": "zip",
                "binary_path": "server/bin/kotlin-language-server",
                "target_dir": "kotlin-ls",
            },
            "osx-arm64": {
                "url": "https://github.com/fwcd/kotlin-language-server/releases/download/1.3.13/server.zip",
                "archive_type": "zip",
                "binary_path": "server/bin/kotlin-language-server",
                "target_dir": "kotlin-ls",
            },
        },
    ),
    # Gopls - Go language server (build from source)
    # Note: gopls does not provide pre-built binaries, so we use the source-based approach
    LanguageServerBundle(
        id="gopls",
        name="Gopls",
        description="Go language server (built from source, requires Go toolchain)",
        estimated_size_mb=30,
        optional=True,  # Requires Go toolchain, bundled with --include-go
        platforms={
            "linux-x64": {
                "url": "build-from-source:golang.org/x/tools/gopls@v0.20.0",
                "archive_type": "go-install",  # Special marker for go install
                "binary_path": "gopls",
                "target_dir": "gopls",
            },
            "win-x64": {
                "url": "build-from-source:golang.org/x/tools/gopls@v0.20.0",
                "archive_type": "go-install",
                "binary_path": "gopls.exe",
                "target_dir": "gopls",
            },
            "osx-x64": {
                "url": "build-from-source:golang.org/x/tools/gopls@v0.20.0",
                "archive_type": "go-install",
                "binary_path": "gopls",
                "target_dir": "gopls",
            },
            "osx-arm64": {
                "url": "build-from-source:golang.org/x/tools/gopls@v0.20.0",
                "archive_type": "go-install",
                "binary_path": "gopls",
                "target_dir": "gopls",
            },
        },
    ),
]


def get_current_platform() -> str:
    """Get the current platform identifier."""
    try:
        return PlatformUtils.get_platform_id().value
    except Exception:
        # Fallback detection
        system = platform.system().lower()
        machine = platform.machine().lower()

        if system == "linux":
            if machine in ("x86_64", "amd64"):
                return "linux-x64"
            elif machine in ("aarch64", "arm64"):
                return "linux-arm64"
        elif system == "darwin":
            if machine in ("x86_64", "amd64"):
                return "osx-x64"
            elif machine in ("arm64", "aarch64"):
                return "osx-arm64"
        elif system == "windows":
            if machine in ("x86_64", "amd64"):
                return "win-x64"
            elif machine in ("arm64", "aarch64"):
                return "win-arm64"

        raise ValueError(f"Unsupported platform: {system}-{machine}")


def download_language_server(
    ls_bundle: LanguageServerBundle,
    platform_id: str,
    output_dir: Path,
    dry_run: bool = False,
) -> bool:
    """Download and extract a language server for the specified platform.

    Returns True if successful, False otherwise.
    """
    if platform_id not in ls_bundle.platforms:
        log.warning(f"  {ls_bundle.name}: No binary available for platform {platform_id}")
        return False

    config = ls_bundle.platforms[platform_id]
    url = config["url"]
    archive_type = config["archive_type"]
    target_dir = output_dir / config["target_dir"]
    binary_path = target_dir / config["binary_path"]

    log.info(f"  {ls_bundle.name}:")
    log.info(f"    URL: {url}")
    log.info(f"    Target: {target_dir}")
    log.info(f"    Estimated size: ~{ls_bundle.estimated_size_mb} MB")

    if dry_run:
        log.info("    [DRY RUN] Would download and extract")
        return True

    # Check if already downloaded
    if binary_path.exists():
        log.info(f"    Already exists at {binary_path}")
        return True

    try:
        # Create target directory
        target_dir.mkdir(parents=True, exist_ok=True)

        # Special handling for go-install (build from source)
        if archive_type == "go-install":
            if not url.startswith("build-from-source:"):
                log.error("    Invalid URL format for go-install. Expected 'build-from-source:' prefix")
                return False

            # Extract package path from URL (e.g., "golang.org/x/tools/gopls@v0.20.0")
            package = url.split("build-from-source:", 1)[1]
            log.info(f"    Building from source: {package}")

            # Check if Go is installed
            try:
                go_version_result = subprocess.run(
                    ["go", "version"],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                if go_version_result.returncode != 0:
                    raise FileNotFoundError("Go not found")
                log.info(f"    Using {go_version_result.stdout.strip()}")
            except FileNotFoundError:
                log.error("    Go toolchain not found. Please install Go from https://golang.org/")
                log.error("    Gopls must be built from source as no pre-built binaries are available.")
                return False

            # Build the binary for the target platform
            log.info(f"    Building gopls for {platform_id}...")

            # Determine GOOS and GOARCH from platform_id
            platform_map = {
                "linux-x64": ("linux", "amd64"),
                "linux-arm64": ("linux", "arm64"),
                "win-x64": ("windows", "amd64"),
                "win-arm64": ("windows", "arm64"),
                "osx-x64": ("darwin", "amd64"),
                "osx-arm64": ("darwin", "arm64"),
            }

            if platform_id not in platform_map:
                log.error(f"    Unsupported platform for go-install: {platform_id}")
                return False

            goos, goarch = platform_map[platform_id]

            # Build with cross-compilation
            env = os.environ.copy()
            env["GOOS"] = goos
            env["GOARCH"] = goarch
            env["CGO_ENABLED"] = "0"  # Disable CGO for static binary

            build_result = subprocess.run(
                ["go", "build", "-o", str(binary_path), package],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

            if build_result.returncode != 0:
                log.error(f"    Build failed: {build_result.stderr}")
                return False

            log.info("    Build completed successfully")

        else:
            # Download and extract (existing logic)
            log.info("    Downloading...")

            # For .gz files (single binary compressed), extract directly to binary path
            # For other archives, extract to target directory
            if archive_type == "gz":
                FileUtils.download_and_extract_archive(url, str(binary_path), archive_type)
            else:
                FileUtils.download_and_extract_archive(url, str(target_dir), archive_type)

        # Verify binary exists
        if not binary_path.exists():
            log.error(f"    Binary not found after extraction: {binary_path}")
            return False

        # Make binary executable on Unix
        if not platform_id.startswith("win"):
            os.chmod(binary_path, 0o755)
            log.info(f"    Set executable permissions on {binary_path}")

        log.info(f"    Successfully downloaded to {target_dir}")
        return True

    except Exception as e:
        log.error(f"    Failed to download: {e}")
        return False


def create_manifest(output_dir: Path, platform_id: str, downloaded: list[str]) -> None:
    """Create a manifest file with bundled LS information."""
    manifest_path = output_dir / "MANIFEST.txt"
    with open(manifest_path, "w") as f:
        f.write("Bundled Language Servers for Serena\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Platform: {platform_id}\n")
        f.write("Generated by: bundle_language_servers.py\n\n")
        f.write("Included language servers:\n")
        for ls_id in downloaded:
            f.write(f"  - {ls_id}\n")
        f.write("\nFor offline usage, set SERENA_STANDALONE=1\n")
    log.info(f"Created manifest at {manifest_path}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download and bundle binary language servers for offline builds.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--platform",
        type=str,
        default=None,
        help="Target platform (linux-x64, win-x64, osx-x64, osx-arm64). Default: auto-detect",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="./language_servers",
        help="Output directory for bundled LS (default: ./language_servers)",
    )
    parser.add_argument(
        "--include-java",
        action="store_true",
        help="Include Eclipse JDTLS, Gradle, and Kotlin LS (adds ~285MB)",
    )
    parser.add_argument(
        "--include-go",
        action="store_true",
        help="Include Gopls - requires Go toolchain (adds ~30MB)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be downloaded without downloading",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )
    parser.add_argument(
        "--ls",
        type=str,
        nargs="+",
        help="Specific language servers to bundle (e.g., --ls clangd terraform-ls)",
    )

    args = parser.parse_args()

    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(message)s",
    )

    # Determine platform
    platform_id = args.platform or get_current_platform()
    log.info(f"Target platform: {platform_id}")

    # Setup output directory
    output_dir = Path(args.output_dir).resolve()
    log.info(f"Output directory: {output_dir}")

    if not args.dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)

    # Filter language servers to bundle
    servers_to_bundle: list[LanguageServerBundle] = []

    if args.ls:
        # Specific servers requested
        requested_ids = set(args.ls)
        for ls_bundle in LANGUAGE_SERVERS:
            if ls_bundle.id in requested_ids:
                servers_to_bundle.append(ls_bundle)
                requested_ids.discard(ls_bundle.id)
        if requested_ids:
            log.error(f"Unknown language servers: {', '.join(requested_ids)}")
            log.info(f"Available: {', '.join(ls.id for ls in LANGUAGE_SERVERS)}")
            return 1
    else:
        # Default: bundle all non-optional, plus optional based on flags
        java_servers = {"jdtls", "gradle", "kotlin-ls"}
        go_servers = {"gopls"}
        for ls_bundle in LANGUAGE_SERVERS:
            if (
                not ls_bundle.optional
                or (args.include_java and ls_bundle.id in java_servers)
                or (args.include_go and ls_bundle.id in go_servers)
            ):
                servers_to_bundle.append(ls_bundle)

    # Calculate estimated total size
    total_size_mb = sum(ls.estimated_size_mb for ls in servers_to_bundle if platform_id in ls.platforms)
    log.info(f"\nLanguage servers to bundle ({len(servers_to_bundle)}):")
    log.info(f"Estimated total size: ~{total_size_mb} MB\n")

    # Download each language server
    downloaded: list[str] = []
    failed: list[str] = []

    for ls_bundle in servers_to_bundle:
        success = download_language_server(ls_bundle, platform_id, output_dir, args.dry_run)
        if success:
            downloaded.append(ls_bundle.id)
        else:
            if not ls_bundle.optional:
                failed.append(ls_bundle.id)

    # Create manifest
    if not args.dry_run and downloaded:
        create_manifest(output_dir, platform_id, downloaded)

    # Summary
    log.info("")
    log.info("=" * 40)
    log.info("Summary:")
    log.info(f"  Downloaded: {len(downloaded)} language servers")
    if downloaded:
        log.info(f"    {', '.join(downloaded)}")
    if failed:
        log.info(f"  Failed: {len(failed)} language servers")
        log.info(f"    {', '.join(failed)}")
        return 1

    if args.dry_run:
        log.info("\n[DRY RUN] No files were downloaded")
    else:
        log.info(f"\nBundled language servers are ready at: {output_dir}")
        log.info("Include this directory in your PyInstaller build for offline support.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
