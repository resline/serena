#!/usr/bin/env python3
"""
Serena Custom Build Generator

Interactive tool to create customized Serena standalone builds
with selected language server support.

Usage:
    # Interactive mode (default)
    python scripts/build_custom_serena.py

    # Use a preset
    python scripts/build_custom_serena.py --preset standard

    # Load from config file
    python scripts/build_custom_serena.py --config my_build.json

    # Save selections to config
    python scripts/build_custom_serena.py --save-config my_build.json

    # Dry run to preview
    python scripts/build_custom_serena.py --dry-run

    # Override platform
    python scripts/build_custom_serena.py --platform win-x64

    # Skip PyInstaller build (just bundle language servers)
    python scripts/build_custom_serena.py --no-pyinstaller
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# Language server categories and metadata
LANGUAGE_CATEGORIES = {
    "Web Development": {
        "typescript": {"name": "TypeScript/JavaScript", "size_mb": 0, "requires": []},
        "php": {"name": "PHP", "size_mb": 0, "requires": []},
        "yaml": {"name": "YAML", "size_mb": 0, "requires": []},
        "bash": {"name": "Bash/Shell", "size_mb": 0, "requires": []},
    },
    "Systems Programming": {
        "clangd": {"name": "C/C++ (Clangd)", "size_mb": 100, "requires": []},
        "rust-analyzer": {"name": "Rust", "size_mb": 20, "requires": []},
        "gopls": {"name": "Go", "size_mb": 30, "requires": ["go-toolchain"]},
    },
    "JVM Languages": {
        "jdtls": {"name": "Java (Eclipse JDTLS)", "size_mb": 150, "requires": []},
        "kotlin-ls": {"name": "Kotlin", "size_mb": 85, "requires": ["jdtls"]},
        "gradle": {"name": "Gradle (Java builds)", "size_mb": 50, "requires": ["jdtls"]},
    },
    "Infrastructure": {
        "terraform-ls": {"name": "Terraform", "size_mb": 50, "requires": []},
    },
    "Other Languages": {
        "dart": {"name": "Dart", "size_mb": 200, "requires": []},
        "lua-ls": {"name": "Lua", "size_mb": 5, "requires": []},
    },
}

# Flatten for easier lookup
ALL_LANGUAGE_SERVERS = {}
for category, servers in LANGUAGE_CATEGORIES.items():
    for ls_id, info in servers.items():
        ALL_LANGUAGE_SERVERS[ls_id] = {**info, "category": category}

# Predefined presets
PRESETS = {
    "minimal": {
        "name": "Minimal",
        "description": "No bundled language servers (download on demand)",
        "languages": [],
    },
    "standard": {
        "name": "Standard",
        "description": "Most common languages (C++, Rust, Lua, Terraform, Dart)",
        "languages": ["clangd", "rust-analyzer", "lua-ls", "terraform-ls", "dart"],
    },
    "full": {
        "name": "Full",
        "description": "All language servers including Java and Go",
        "languages": [
            "clangd",
            "terraform-ls",
            "dart",
            "rust-analyzer",
            "lua-ls",
            "jdtls",
            "gradle",
            "kotlin-ls",
            "gopls",
        ],
    },
    "web": {
        "name": "Web Development",
        "description": "Languages for web development",
        "languages": ["typescript", "php", "yaml", "bash"],
    },
    "systems": {
        "name": "Systems Programming",
        "description": "C++, Rust, and Go for systems development",
        "languages": ["clangd", "rust-analyzer", "gopls"],
    },
    "jvm": {
        "name": "JVM Languages",
        "description": "Java, Kotlin, and Gradle support",
        "languages": ["jdtls", "kotlin-ls", "gradle"],
    },
}


@dataclass
class BuildConfig:
    """Configuration for a custom Serena build."""

    languages: list[str] = field(default_factory=list)
    platform: str | None = None
    output_dir: str = "./language_servers"
    run_pyinstaller: bool = True
    pyinstaller_args: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "languages": self.languages,
            "platform": self.platform,
            "output_dir": self.output_dir,
            "run_pyinstaller": self.run_pyinstaller,
            "pyinstaller_args": self.pyinstaller_args,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> BuildConfig:
        return cls(
            languages=data.get("languages", []),
            platform=data.get("platform"),
            output_dir=data.get("output_dir", "./language_servers"),
            run_pyinstaller=data.get("run_pyinstaller", True),
            pyinstaller_args=data.get("pyinstaller_args", []),
        )


def clear_screen() -> None:
    """Clear the terminal screen (optional, for better UX)."""
    # Simple implementation - could be improved with platform detection
    print("\n" * 2)


def print_header(text: str) -> None:
    """Print a formatted header."""
    print("\n" + "=" * 70)
    print(f"  {text}")
    print("=" * 70)


def print_section(text: str) -> None:
    """Print a section divider."""
    print("\n" + "-" * 70)
    print(f"  {text}")
    print("-" * 70)


def get_input(prompt: str, default: str = "") -> str:
    """Get user input with optional default."""
    if default:
        response = input(f"{prompt} [{default}]: ").strip()
        return response if response else default
    return input(f"{prompt}: ").strip()


def get_yes_no(prompt: str, default: bool = False) -> bool:
    """Get yes/no input from user."""
    default_str = "Y/n" if default else "y/N"
    while True:
        response = input(f"{prompt} [{default_str}]: ").strip().lower()
        if not response:
            return default
        if response in ("y", "yes"):
            return True
        if response in ("n", "no"):
            return False
        print("Please enter 'y' or 'n'")


def select_preset() -> str | None:
    """Let user select a preset or choose custom."""
    print_section("Select a Build Preset")
    print("\nAvailable presets:\n")

    options = list(PRESETS.keys()) + ["custom"]
    for i, preset_id in enumerate(options, 1):
        if preset_id == "custom":
            print(f"{i}. Custom - Choose your own languages")
        else:
            preset = PRESETS[preset_id]
            size_mb = calculate_size(preset["languages"])
            print(f"{i}. {preset['name']} - {preset['description']}")
            print(f"   Languages: {', '.join(preset['languages']) if preset['languages'] else 'None (download on demand)'}")
            print(f"   Estimated size: ~{size_mb} MB\n")

    while True:
        try:
            choice = input(f"\nSelect preset (1-{len(options)}): ").strip()
            if not choice:
                continue
            idx = int(choice) - 1
            if 0 <= idx < len(options):
                selected = options[idx]
                return None if selected == "custom" else selected
            print(f"Please enter a number between 1 and {len(options)}")
        except ValueError:
            print("Please enter a valid number")


def select_custom_languages() -> list[str]:
    """Interactive language selection by category."""
    print_section("Custom Language Selection")
    print("\nSelect languages to bundle (grouped by category):")
    print("Enter language numbers separated by commas (e.g., 1,3,5)")
    print("Or press Enter to skip a category\n")

    selected_languages = []
    language_list = []

    # Display categories and collect selections
    for category, servers in LANGUAGE_CATEGORIES.items():
        print(f"\n{category}:")
        print("-" * len(category))

        category_langs = []
        for ls_id, info in servers.items():
            num = len(language_list) + 1
            language_list.append(ls_id)
            category_langs.append(num)

            size_info = f"~{info['size_mb']} MB" if info["size_mb"] > 0 else "included"
            requires_info = f" (requires: {', '.join(info['requires'])})" if info["requires"] else ""
            print(f"  {num}. {info['name']} - {size_info}{requires_info}")

        # Get selections for this category
        while True:
            response = input(f"\nSelect from {category} (e.g., {category_langs[0]},{category_langs[-1]}): ").strip()

            if not response:
                break

            try:
                selections = [int(x.strip()) for x in response.split(",")]
                invalid = [s for s in selections if s < 1 or s > len(language_list)]
                if invalid:
                    print(f"Invalid selections: {invalid}. Please try again.")
                    continue

                for sel in selections:
                    ls_id = language_list[sel - 1]
                    if ls_id not in selected_languages:
                        selected_languages.append(ls_id)

                break
            except ValueError:
                print("Invalid input. Please enter comma-separated numbers.")

    return selected_languages


def validate_selections(languages: list[str]) -> tuple[list[str], list[str]]:
    """Validate language selections and check dependencies.

    Returns:
        Tuple of (valid_languages, warnings)

    """
    warnings = []
    validated = list(languages)

    # Check for missing dependencies
    for ls_id in languages:
        if ls_id not in ALL_LANGUAGE_SERVERS:
            warnings.append(f"Unknown language server: {ls_id}")
            validated.remove(ls_id)
            continue

        info = ALL_LANGUAGE_SERVERS[ls_id]
        for req in info.get("requires", []):
            if req == "go-toolchain":
                warnings.append(f"Warning: {ls_id} requires Go toolchain to be installed on your system")
            elif req not in validated:
                warnings.append(f"Adding required dependency: {req} (required by {ls_id})")
                validated.append(req)

    return validated, warnings


def calculate_size(languages: list[str]) -> int:
    """Calculate estimated total size in MB."""
    return sum(ALL_LANGUAGE_SERVERS.get(ls_id, {}).get("size_mb", 0) for ls_id in languages)


def display_build_summary(config: BuildConfig) -> None:
    """Display a summary of the build configuration."""
    print_section("Build Configuration Summary")

    print(f"\nPlatform: {config.platform or 'auto-detect'}")
    print(f"Output directory: {config.output_dir}")
    print(f"Run PyInstaller: {'Yes' if config.run_pyinstaller else 'No'}")

    if config.languages:
        print(f"\nSelected language servers ({len(config.languages)}):")
        total_size = 0
        for ls_id in config.languages:
            if ls_id in ALL_LANGUAGE_SERVERS:
                info = ALL_LANGUAGE_SERVERS[ls_id]
                size_mb = info.get("size_mb", 0)
                total_size += size_mb
                size_str = f"~{size_mb} MB" if size_mb > 0 else "included"
                print(f"  - {info['name']} ({ls_id}): {size_str}")
        print(f"\nEstimated total size: ~{total_size} MB")
    else:
        print("\nNo language servers selected (minimal build)")
        print("Language servers will be downloaded on demand when first used")


def save_config(config: BuildConfig, filepath: str) -> None:
    """Save build configuration to JSON file."""
    config_path = Path(filepath)
    with open(config_path, "w") as f:
        json.dump(config.to_dict(), f, indent=2)
    print(f"\nConfiguration saved to: {config_path.resolve()}")


def load_config(filepath: str) -> BuildConfig:
    """Load build configuration from JSON file."""
    config_path = Path(filepath)
    if not config_path.exists():
        print(f"Error: Config file not found: {filepath}")
        sys.exit(1)

    with open(config_path) as f:
        data = json.load(f)

    return BuildConfig.from_dict(data)


def run_bundle_language_servers(config: BuildConfig, dry_run: bool = False) -> int:
    """Execute bundle_language_servers.py with the configuration.

    Returns:
        Exit code from the bundle script

    """
    print_section("Bundling Language Servers")

    script_path = Path(__file__).parent / "bundle_language_servers.py"
    if not script_path.exists():
        print(f"Error: bundle_language_servers.py not found at {script_path}")
        return 1

    cmd = [sys.executable, str(script_path)]

    # Add arguments
    if config.platform:
        cmd.extend(["--platform", config.platform])

    cmd.extend(["--output-dir", config.output_dir])

    if dry_run:
        cmd.append("--dry-run")

    cmd.append("--verbose")

    # Add specific language servers if selected
    if config.languages:
        cmd.append("--ls")
        cmd.extend(config.languages)

    print(f"\nExecuting: {' '.join(cmd)}\n")

    try:
        result = subprocess.run(cmd, check=False)
        return result.returncode
    except Exception as e:
        print(f"Error running bundle script: {e}")
        return 1


def run_pyinstaller(config: BuildConfig, dry_run: bool = False) -> int:
    """Execute PyInstaller to build standalone executable.

    Returns:
        Exit code from PyInstaller

    """
    print_section("Building Standalone Executable with PyInstaller")

    if dry_run:
        print("\n[DRY RUN] Would run PyInstaller with:")
        print(f"  - Language servers bundled in: {config.output_dir}")
        if config.pyinstaller_args:
            print(f"  - Additional args: {' '.join(config.pyinstaller_args)}")
        return 0

    # Basic PyInstaller command
    # Note: This is a placeholder - adjust according to actual PyInstaller spec
    cmd = [
        "pyinstaller",
        "--onefile",
        "--name",
        "serena",
        "--add-data",
        f"{config.output_dir}:language_servers",
    ]

    # Add any additional user-specified args
    cmd.extend(config.pyinstaller_args)

    # Add main script (adjust path as needed)
    main_script = Path(__file__).parent.parent / "src" / "serena" / "__main__.py"
    if main_script.exists():
        cmd.append(str(main_script))
    else:
        print(f"Warning: Main script not found at {main_script}")
        print("Please specify the entry point manually")
        return 1

    print(f"\nExecuting: {' '.join(cmd)}\n")
    print("Note: This may take several minutes...\n")

    try:
        result = subprocess.run(cmd, check=False)
        return result.returncode
    except FileNotFoundError:
        print("\nError: PyInstaller not found. Install it with:")
        print("  pip install pyinstaller")
        return 1
    except Exception as e:
        print(f"Error running PyInstaller: {e}")
        return 1


def interactive_build() -> BuildConfig:
    """Run interactive build configuration."""
    print_header("Serena Custom Build Generator")

    # Step 1: Preset or custom
    preset = select_preset()

    if preset:
        languages = PRESETS[preset]["languages"].copy()
        print(f"\nSelected preset: {PRESETS[preset]['name']}")
    else:
        languages = select_custom_languages()

    # Step 2: Validate selections
    languages, warnings = validate_selections(languages)

    if warnings:
        print("\n" + "\n".join(warnings))

    # Step 3: Platform selection
    print_section("Platform Configuration")
    print("\nTarget platform (leave empty for auto-detection):")
    print("Options: linux-x64, linux-arm64, win-x64, win-arm64, osx-x64, osx-arm64")
    platform = get_input("Platform", "auto-detect")
    if platform == "auto-detect":
        platform = None

    # Step 4: Output directory
    output_dir = get_input("Output directory", "./language_servers")

    # Step 5: PyInstaller
    run_pyinstaller = get_yes_no("Run PyInstaller after bundling?", default=False)

    config = BuildConfig(
        languages=languages,
        platform=platform,
        output_dir=output_dir,
        run_pyinstaller=run_pyinstaller,
    )

    # Display summary
    display_build_summary(config)

    return config


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Interactive generator for custom Serena standalone builds",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    parser.add_argument(
        "--preset",
        type=str,
        choices=list(PRESETS.keys()),
        help="Use a predefined preset instead of interactive selection",
    )
    parser.add_argument(
        "--config",
        type=str,
        help="Load build configuration from JSON file",
    )
    parser.add_argument(
        "--save-config",
        type=str,
        help="Save configuration to JSON file (for reproducible builds)",
    )
    parser.add_argument(
        "--platform",
        type=str,
        help="Override platform (linux-x64, win-x64, osx-x64, osx-arm64)",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        help="Override output directory for language servers",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview what would be built without actually building",
    )
    parser.add_argument(
        "--no-pyinstaller",
        action="store_true",
        help="Skip PyInstaller build (only bundle language servers)",
    )
    parser.add_argument(
        "--list-presets",
        action="store_true",
        help="List available presets and exit",
    )
    parser.add_argument(
        "--list-languages",
        action="store_true",
        help="List all available language servers and exit",
    )

    args = parser.parse_args()

    # Handle info commands
    if args.list_presets:
        print_header("Available Presets")
        for preset_id, preset in PRESETS.items():
            print(f"\n{preset_id}:")
            print(f"  Name: {preset['name']}")
            print(f"  Description: {preset['description']}")
            print(f"  Languages: {', '.join(preset['languages']) if preset['languages'] else 'None'}")
            print(f"  Size: ~{calculate_size(preset['languages'])} MB")
        return 0

    if args.list_languages:
        print_header("Available Language Servers")
        for category, servers in LANGUAGE_CATEGORIES.items():
            print(f"\n{category}:")
            for ls_id, info in servers.items():
                size_str = f"~{info['size_mb']} MB" if info["size_mb"] > 0 else "included"
                req_str = f" (requires: {', '.join(info['requires'])})" if info["requires"] else ""
                print(f"  {ls_id}: {info['name']} - {size_str}{req_str}")
        return 0

    # Load or create configuration
    if args.config:
        config = load_config(args.config)
        print(f"Loaded configuration from: {args.config}")
    elif args.preset:
        preset = PRESETS[args.preset]
        config = BuildConfig(languages=preset["languages"].copy())
        print(f"Using preset: {preset['name']}")
    else:
        config = interactive_build()

    # Apply command-line overrides
    if args.platform:
        config.platform = args.platform
    if args.output_dir:
        config.output_dir = args.output_dir
    if args.no_pyinstaller:
        config.run_pyinstaller = False

    # Validate configuration
    config.languages, warnings = validate_selections(config.languages)
    if warnings:
        print("\n" + "\n".join(warnings))

    # Display final summary
    if not args.config and not args.preset:
        display_build_summary(config)

    # Save config if requested
    if args.save_config:
        save_config(config, args.save_config)

    # If only saving config (no other action requested), exit here
    save_only = args.save_config and not args.dry_run and not args.config
    if save_only:
        print("\nConfiguration saved. Run with --config to use this configuration.")
        return 0

    # Confirm before proceeding (only in truly interactive mode)
    if not args.dry_run and not args.config and not args.preset and not args.save_config:
        if not get_yes_no("\nProceed with build?", default=True):
            print("Build cancelled.")
            return 0

    # Step 1: Bundle language servers
    result = run_bundle_language_servers(config, dry_run=args.dry_run)
    if result != 0:
        print("\nLanguage server bundling failed!")
        return result

    # Step 2: Run PyInstaller if requested
    if config.run_pyinstaller:
        result = run_pyinstaller(config, dry_run=args.dry_run)
        if result != 0:
            print("\nPyInstaller build failed!")
            return result

    # Success!
    print_section("Build Complete!")

    if not args.dry_run:
        print(f"\nLanguage servers bundled in: {Path(config.output_dir).resolve()}")
        if config.run_pyinstaller:
            print("Standalone executable created in: ./dist/")
        print("\nYour custom Serena build is ready!")
    else:
        print("\n[DRY RUN] No files were created")

    return 0


if __name__ == "__main__":
    sys.exit(main())
