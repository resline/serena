#!/usr/bin/env python3
"""
Serena Custom Build Generator - Precise Language Selection

Interactive tool to create customized Serena standalone builds
with precise selection of individual language servers.

Usage:
    # Interactive mode - select individual languages
    python scripts/build_custom_serena.py

    # Select specific languages directly
    python scripts/build_custom_serena.py --languages clangd,rust-analyzer,typescript

    # Use a preset as starting point
    python scripts/build_custom_serena.py --preset standard

    # List all available languages
    python scripts/build_custom_serena.py --list-languages

    # Load from config file
    python scripts/build_custom_serena.py --config my_build.json

    # Save selections to config
    python scripts/build_custom_serena.py --save-config my_build.json

    # Dry run to preview
    python scripts/build_custom_serena.py --dry-run

    # Override platform
    python scripts/build_custom_serena.py --platform win-x64
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# =============================================================================
# LANGUAGE SERVER REGISTRY - Complete list of all bundleable language servers
# =============================================================================

LANGUAGE_SERVERS = {
    # Binary language servers (downloadable pre-built binaries)
    "clangd": {
        "name": "C/C++ (Clangd)",
        "category": "Systems Programming",
        "type": "binary",
        "size_mb": 100,
        "version": "19.1.2",
        "dependencies": [],
        "description": "LLVM-based C/C++ language server",
    },
    "rust-analyzer": {
        "name": "Rust",
        "category": "Systems Programming",
        "type": "binary",
        "size_mb": 20,
        "version": "2025-11-24",
        "dependencies": [],
        "description": "Official Rust language server",
    },
    "gopls": {
        "name": "Go",
        "category": "Systems Programming",
        "type": "binary",
        "size_mb": 30,
        "version": "0.20.0",
        "dependencies": [],
        "build_requirement": "Go toolchain",
        "description": "Official Go language server (built from source)",
    },
    "jdtls": {
        "name": "Java (Eclipse JDTLS)",
        "category": "JVM Languages",
        "type": "binary",
        "size_mb": 150,
        "version": "1.42.0",
        "dependencies": [],
        "description": "Eclipse JDT Language Server with bundled Java 21 runtime",
    },
    "kotlin-ls": {
        "name": "Kotlin",
        "category": "JVM Languages",
        "type": "binary",
        "size_mb": 85,
        "version": "1.3.13",
        "dependencies": ["jdtls"],
        "description": "Kotlin language server (requires Java runtime)",
    },
    "gradle": {
        "name": "Gradle",
        "category": "JVM Languages",
        "type": "binary",
        "size_mb": 50,
        "version": "8.14.2",
        "dependencies": ["jdtls"],
        "description": "Gradle build tool for Java projects",
    },
    "terraform-ls": {
        "name": "Terraform",
        "category": "Infrastructure",
        "type": "binary",
        "size_mb": 50,
        "version": "0.36.5",
        "dependencies": [],
        "description": "HashiCorp Terraform language server",
    },
    "dart": {
        "name": "Dart",
        "category": "Other Languages",
        "type": "binary",
        "size_mb": 200,
        "version": "3.7.1",
        "dependencies": [],
        "description": "Dart SDK with language server",
    },
    "lua-ls": {
        "name": "Lua",
        "category": "Other Languages",
        "type": "binary",
        "size_mb": 5,
        "version": "3.15.0",
        "dependencies": [],
        "description": "Lua language server",
    },
    # npm-based language servers (require Node.js)
    "typescript": {
        "name": "TypeScript/JavaScript",
        "category": "Web Development",
        "type": "npm",
        "size_mb": 40,
        "version": "4.3.3",
        "dependencies": [],
        "requires_node": True,
        "npm_packages": ["typescript@5.5.4", "typescript-language-server@4.3.3"],
        "description": "TypeScript and JavaScript language server",
    },
    "yaml": {
        "name": "YAML",
        "category": "Web Development",
        "type": "npm",
        "size_mb": 5,
        "version": "1.19.2",
        "dependencies": [],
        "requires_node": True,
        "npm_packages": ["yaml-language-server@1.19.2"],
        "description": "YAML language server with schema support",
    },
    "bash": {
        "name": "Bash/Shell",
        "category": "Web Development",
        "type": "npm",
        "size_mb": 3,
        "version": "5.6.0",
        "dependencies": [],
        "requires_node": True,
        "npm_packages": ["bash-language-server@5.6.0"],
        "description": "Bash and shell script language server",
    },
    "php": {
        "name": "PHP (Intelephense)",
        "category": "Web Development",
        "type": "npm",
        "size_mb": 50,
        "version": "1.14.4",
        "dependencies": [],
        "requires_node": True,
        "npm_packages": ["intelephense@1.14.4"],
        "description": "PHP language server with intelligent code assistance",
    },
    "vts": {
        "name": "TypeScript (VSCode)",
        "category": "Web Development",
        "type": "npm",
        "size_mb": 15,
        "version": "0.2.9",
        "dependencies": [],
        "requires_node": True,
        "npm_packages": ["@vtsls/language-server@0.2.9"],
        "description": "VSCode TypeScript language features",
    },
    "pyright": {
        "name": "Python (Pyright)",
        "category": "Scripting",
        "type": "npm",
        "size_mb": 150,
        "version": "1.1.390",
        "dependencies": [],
        "requires_node": True,
        "npm_packages": ["pyright@1.1.390"],
        "description": "Microsoft Pyright - fast Python type checker and language server",
    },
}

# Categories for display organization
CATEGORIES = [
    "Systems Programming",
    "JVM Languages",
    "Web Development",
    "Infrastructure",
    "Scripting",
    "Other Languages",
]

# Predefined presets
PRESETS = {
    "minimal": {
        "name": "Minimal",
        "description": "No bundled language servers",
        "languages": [],
        "size_mb": 0,
    },
    "standard": {
        "name": "Standard",
        "description": "Default binary servers (C++, Rust, Lua, Terraform, Dart)",
        "languages": ["clangd", "rust-analyzer", "lua-ls", "terraform-ls", "dart"],
        "size_mb": 375,
    },
    "full": {
        "name": "Full",
        "description": "All binary servers including Java ecosystem",
        "languages": [
            "clangd",
            "rust-analyzer",
            "lua-ls",
            "terraform-ls",
            "dart",
            "jdtls",
            "gradle",
            "kotlin-ls",
        ],
        "size_mb": 660,
    },
    "web": {
        "name": "Web Development",
        "description": "TypeScript, PHP, YAML, Bash (requires Node.js)",
        "languages": ["typescript", "yaml", "bash", "php", "vts"],
        "size_mb": 113,
    },
    "systems": {
        "name": "Systems Programming",
        "description": "C++, Rust, Go",
        "languages": ["clangd", "rust-analyzer", "gopls"],
        "size_mb": 150,
    },
    "jvm": {
        "name": "JVM Languages",
        "description": "Java, Kotlin, Gradle",
        "languages": ["jdtls", "kotlin-ls", "gradle"],
        "size_mb": 285,
    },
    "complete": {
        "name": "Complete",
        "description": "ALL bundleable language servers",
        "languages": list(LANGUAGE_SERVERS.keys()),
        "size_mb": 803,
    },
}


# =============================================================================
# BUILD CONFIGURATION
# =============================================================================


@dataclass
class BuildConfig:
    """Configuration for a custom Serena build."""

    languages: list[str] = field(default_factory=list)
    platform: str = ""
    output_dir: str = "./language_servers"
    dry_run: bool = False
    skip_pyinstaller: bool = False
    pyinstaller_args: list[str] = field(default_factory=list)

    # Computed fields (set after resolution)
    resolved_languages: list[str] = field(default_factory=list)
    auto_added: list[str] = field(default_factory=list)
    size_breakdown: dict[str, int] = field(default_factory=dict)
    total_size_mb: int = 0
    requires_node: bool = False
    warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "languages": self.languages,
            "platform": self.platform,
            "output_dir": self.output_dir,
            "dry_run": self.dry_run,
            "skip_pyinstaller": self.skip_pyinstaller,
            "pyinstaller_args": self.pyinstaller_args,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "BuildConfig":
        """Create from dictionary."""
        return cls(
            languages=data.get("languages", []),
            platform=data.get("platform", ""),
            output_dir=data.get("output_dir", "./language_servers"),
            dry_run=data.get("dry_run", False),
            skip_pyinstaller=data.get("skip_pyinstaller", False),
            pyinstaller_args=data.get("pyinstaller_args", []),
        )


# =============================================================================
# DEPENDENCY RESOLUTION
# =============================================================================


def resolve_dependencies(languages: list[str]) -> tuple[list[str], list[str], list[str]]:
    """
    Resolve dependencies and validate language selection.

    Returns:
        (resolved_languages, auto_added_languages, warnings)

    """
    resolved = set(languages)
    auto_added = []
    warnings = []

    # Validate all languages exist
    for ls_id in list(resolved):
        if ls_id not in LANGUAGE_SERVERS:
            warnings.append(f"Unknown language server: '{ls_id}' (skipped)")
            resolved.discard(ls_id)

    # Resolve dependencies iteratively
    changed = True
    while changed:
        changed = False
        for ls_id in list(resolved):
            if ls_id not in LANGUAGE_SERVERS:
                continue
            deps = LANGUAGE_SERVERS[ls_id].get("dependencies", [])
            for dep in deps:
                if dep not in resolved and dep in LANGUAGE_SERVERS:
                    resolved.add(dep)
                    auto_added.append(dep)
                    warnings.append(f"Auto-added '{dep}' (required by '{ls_id}')")
                    changed = True

    # Check for special requirements
    for ls_id in resolved:
        ls_info = LANGUAGE_SERVERS.get(ls_id, {})
        if ls_info.get("build_requirement"):
            warnings.append(f"'{ls_id}' requires {ls_info['build_requirement']} to build")

    # Sort by category for consistent output
    def sort_key(ls_id: str) -> tuple[int, str]:
        cat = LANGUAGE_SERVERS.get(ls_id, {}).get("category", "ZZZ")
        try:
            cat_idx = CATEGORIES.index(cat)
        except ValueError:
            cat_idx = 999
        return (cat_idx, ls_id)

    resolved_list = sorted(resolved, key=sort_key)
    return resolved_list, auto_added, warnings


def calculate_size(languages: list[str]) -> tuple[int, dict[str, int]]:
    """
    Calculate total size and per-language breakdown.

    Returns:
        (total_size_mb, {language_id: size_mb})

    """
    breakdown = {}
    for ls_id in languages:
        if ls_id in LANGUAGE_SERVERS:
            breakdown[ls_id] = LANGUAGE_SERVERS[ls_id]["size_mb"]
    return sum(breakdown.values()), breakdown


def check_node_requirement(languages: list[str]) -> bool:
    """Check if any selected language requires Node.js."""
    for ls_id in languages:
        if LANGUAGE_SERVERS.get(ls_id, {}).get("requires_node", False):
            return True
    return False


# =============================================================================
# DISPLAY HELPERS
# =============================================================================


def print_header(title: str) -> None:
    """Print a formatted header."""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)


def print_section(title: str) -> None:
    """Print a section header."""
    print(f"\n{title}")
    print("-" * 70)


def display_languages_table(selected: set[str] | None = None) -> dict[int, str]:
    """
    Display all languages organized by category with selection markers.

    Returns:
        Mapping of index number to language ID

    """
    index_map = {}
    idx = 1

    for category in CATEGORIES:
        # Get languages in this category
        cat_languages = [(ls_id, info) for ls_id, info in LANGUAGE_SERVERS.items() if info["category"] == category]
        if not cat_languages:
            continue

        print(f"\n  {category}:")

        for ls_id, info in sorted(cat_languages, key=lambda x: x[1]["name"]):
            # Selection marker
            if selected is not None:
                marker = "[X]" if ls_id in selected else "[ ]"
            else:
                marker = "   "

            # Size display
            size_str = f"{info['size_mb']:3d} MB" if info["size_mb"] > 0 else "  npm  "

            # Type indicator
            type_str = info["type"][:3].upper()

            # Dependencies
            deps = info.get("dependencies", [])
            dep_str = f" (requires: {', '.join(deps)})" if deps else ""

            # Node requirement
            node_str = " [Node.js]" if info.get("requires_node") else ""

            print(f"    {marker} {idx:2d}. {info['name']:25} {size_str}  {type_str}{dep_str}{node_str}")
            index_map[idx] = ls_id
            idx += 1

    return index_map


def display_selection_summary(config: BuildConfig) -> None:
    """Display a summary of the current selection."""
    print_section("Selection Summary")

    if not config.resolved_languages:
        print("  No language servers selected")
        return

    # Group by category
    by_category: dict[str, list[str]] = {}
    for ls_id in config.resolved_languages:
        cat = LANGUAGE_SERVERS[ls_id]["category"]
        by_category.setdefault(cat, []).append(ls_id)

    # Display by category
    for category in CATEGORIES:
        if category not in by_category:
            continue
        print(f"\n  {category}:")
        for ls_id in by_category[category]:
            info = LANGUAGE_SERVERS[ls_id]
            auto = " (auto-added)" if ls_id in config.auto_added else ""
            print(f"    - {info['name']:25} {info['size_mb']:3d} MB{auto}")

    # Total
    print(f"\n  {'-' * 40}")
    print(f"  Total: {len(config.resolved_languages)} language servers, ~{config.total_size_mb} MB")

    if config.requires_node:
        print("  [!] Requires Node.js runtime (included in full variant)")

    # Warnings
    if config.warnings:
        print("\n  Notes:")
        for warning in config.warnings:
            print(f"    - {warning}")


def display_presets() -> None:
    """Display available presets."""
    print_header("Available Presets")
    print()

    for preset_id, preset in PRESETS.items():
        langs = preset["languages"]
        lang_str = ", ".join(langs[:5])
        if len(langs) > 5:
            lang_str += f", ... ({len(langs)} total)"
        elif not langs:
            lang_str = "(none)"

        print(f"  {preset_id:12} - {preset['name']}")
        print(f"               {preset['description']}")
        print(f"               Languages: {lang_str}")
        print(f"               Size: ~{preset['size_mb']} MB")
        print()


# =============================================================================
# INTERACTIVE SELECTION
# =============================================================================


def get_input(prompt: str, default: str = "") -> str:
    """Get user input with optional default."""
    if default:
        prompt = f"{prompt} [{default}]: "
    else:
        prompt = f"{prompt}: "

    try:
        value = input(prompt).strip()
        return value if value else default
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled.")
        sys.exit(0)


def get_yes_no(prompt: str, default: bool = True) -> bool:
    """Get yes/no input."""
    default_str = "Y/n" if default else "y/N"
    response = get_input(f"{prompt} ({default_str})", "y" if default else "n")
    return response.lower() in ("y", "yes", "1", "true")


def parse_selection_input(input_str: str, index_map: dict[int, str], current: set[str]) -> set[str] | None:
    """
    Parse user selection input.

    Supports:
        - Single numbers: "1", "5"
        - Ranges: "1-5", "3-7"
        - Comma-separated: "1,3,5", "1-3,7,9-11"
        - Toggle with '-': "-3" removes item 3
        - 'all' to select everything
        - 'none' to clear selection
        - Category shortcuts: 'c1' (toggle category 1)

    Returns:
        Updated selection set, or None on error

    """
    result = set(current)
    input_str = input_str.strip().lower()

    if input_str == "all":
        return set(index_map.values())

    if input_str == "none":
        return set()

    if input_str == "":
        return result

    try:
        for token in input_str.replace(" ", "").split(","):
            if not token:
                continue

            # Check for removal prefix
            remove = token.startswith("-")
            if remove:
                token = token[1:]

            # Range handling
            if "-" in token and not token.startswith("-"):
                parts = token.split("-")
                if len(parts) == 2:
                    start, end = int(parts[0]), int(parts[1])
                    for i in range(start, end + 1):
                        if i in index_map:
                            if remove:
                                result.discard(index_map[i])
                            else:
                                result.add(index_map[i])
                    continue

            # Single number
            idx = int(token)
            if idx in index_map:
                if remove:
                    result.discard(index_map[idx])
                else:
                    result.add(index_map[idx])

        return result

    except (ValueError, KeyError) as e:
        print(f"  Invalid input: {e}")
        return None


def interactive_language_selection(initial: set[str] | None = None) -> list[str]:
    """
    Interactive language selection with checkbox-style UI.

    Returns:
        List of selected language IDs

    """
    selected = set(initial) if initial else set()

    print_header("Language Server Selection")
    print(
        """
  Select languages by entering numbers, ranges, or commands:
    - Single: 1, 5, 12
    - Range: 1-5, 8-10
    - Multiple: 1,3,5-7,12
    - Remove: -3, -5-7
    - Select all: all
    - Clear: none
    - Finish: done (or press Enter with no input)
    """
    )

    while True:
        # Display current state
        print_section("Available Language Servers")
        index_map = display_languages_table(selected)

        # Show current selection summary
        if selected:
            resolved, auto_added, _ = resolve_dependencies(list(selected))
            total_size, _ = calculate_size(resolved)
            print(f"\n  Currently selected: {len(selected)} (+{len(auto_added)} dependencies) = ~{total_size} MB")
        else:
            print("\n  Currently selected: none")

        # Get input
        print()
        user_input = get_input("Enter selection (or 'done' to finish)")

        if user_input.lower() in ("done", "d", ""):
            if not selected:
                if get_yes_no("No languages selected. Continue anyway?", False):
                    break
            else:
                break

        if user_input.lower() in ("quit", "q", "exit"):
            print("Cancelled.")
            sys.exit(0)

        if user_input.lower() == "help":
            print(
                """
  Commands:
    1,2,3     - Toggle individual items
    1-5       - Toggle range
    -3        - Remove item 3
    all       - Select all
    none      - Clear all
    done      - Finish selection
    quit      - Exit without building
            """
            )
            continue

        # Parse and update selection
        new_selection = parse_selection_input(user_input, index_map, selected)
        if new_selection is not None:
            selected = new_selection

    return list(selected)


def select_preset() -> str | None:
    """Let user select a preset."""
    print_section("Select a Preset")
    print()

    presets_list = list(PRESETS.keys())
    for i, preset_id in enumerate(presets_list, 1):
        preset = PRESETS[preset_id]
        print(f"  {i}. {preset['name']:15} - {preset['description']} (~{preset['size_mb']} MB)")

    print(f"  {len(presets_list) + 1}. Custom selection")
    print()

    choice = get_input("Select option", "2")

    try:
        idx = int(choice)
        if 1 <= idx <= len(presets_list):
            return presets_list[idx - 1]
        elif idx == len(presets_list) + 1:
            return None  # Custom selection
    except ValueError:
        # Try by name
        if choice in PRESETS:
            return choice

    print("Invalid selection, using 'standard'")
    return "standard"


def interactive_build() -> BuildConfig:
    """Run interactive build configuration."""
    print_header("Serena Custom Build Generator")

    # Step 1: Preset or custom
    print("\n  How would you like to select languages?")
    print("  1. Use a preset")
    print("  2. Custom selection (choose individual languages)")
    print()

    choice = get_input("Select option", "1")

    if choice == "1":
        preset_id = select_preset()
        if preset_id:
            initial_langs = set(PRESETS[preset_id]["languages"])
            print(f"\n  Using preset '{preset_id}': {', '.join(initial_langs) or 'none'}")
            if get_yes_no("Modify this selection?", False):
                languages = interactive_language_selection(initial_langs)
            else:
                languages = list(initial_langs)
        else:
            languages = interactive_language_selection()
    else:
        languages = interactive_language_selection()

    # Resolve dependencies
    resolved, auto_added, warnings = resolve_dependencies(languages)
    total_size, size_breakdown = calculate_size(resolved)
    requires_node = check_node_requirement(resolved)

    # Create config
    config = BuildConfig(
        languages=languages,
        resolved_languages=resolved,
        auto_added=auto_added,
        size_breakdown=size_breakdown,
        total_size_mb=total_size,
        requires_node=requires_node,
        warnings=warnings,
    )

    # Show summary
    display_selection_summary(config)

    if not get_yes_no("\nProceed with this configuration?", True):
        print("Cancelled.")
        sys.exit(0)

    # Platform selection
    print_section("Platform Selection")
    platforms = ["linux-x64", "win-x64", "osx-x64", "osx-arm64", "auto"]
    print("  Available platforms:")
    for i, p in enumerate(platforms, 1):
        print(f"    {i}. {p}")
    print()

    platform_choice = get_input("Select platform", "auto")
    if platform_choice.isdigit() and 1 <= int(platform_choice) <= len(platforms):
        config.platform = platforms[int(platform_choice) - 1]
    elif platform_choice in platforms:
        config.platform = platform_choice
    else:
        config.platform = "auto"

    if config.platform == "auto":
        config.platform = ""  # Will be auto-detected

    # Build options
    config.dry_run = get_yes_no("Dry run (preview only)?", False)
    config.skip_pyinstaller = get_yes_no("Skip PyInstaller (bundle LS only)?", False)

    return config


# =============================================================================
# BUILD EXECUTION
# =============================================================================


def get_binary_languages(languages: list[str]) -> list[str]:
    """Filter to only binary language servers (not npm-based)."""
    return [ls_id for ls_id in languages if LANGUAGE_SERVERS.get(ls_id, {}).get("type") == "binary"]


def get_npm_languages(languages: list[str]) -> list[str]:
    """Filter to only npm-based language servers."""
    return [ls_id for ls_id in languages if LANGUAGE_SERVERS.get(ls_id, {}).get("type") == "npm"]


def build_bundle_command(config: BuildConfig, binary_languages: list[str]) -> list[str]:
    """Build the bundle_language_servers.py command for binary servers only."""
    script_path = Path(__file__).parent / "bundle_language_servers.py"

    cmd = [sys.executable, str(script_path)]
    cmd.extend(["--output-dir", config.output_dir])

    if config.platform:
        cmd.extend(["--platform", config.platform])

    if config.dry_run:
        cmd.append("--dry-run")

    cmd.append("--verbose")

    # Add specific binary languages only
    if binary_languages:
        cmd.append("--ls")
        cmd.extend(binary_languages)

    return cmd


def run_build(config: BuildConfig) -> int:
    """Execute the build process."""
    print_header("Building Serena Standalone")

    # Separate binary and npm languages
    binary_langs = get_binary_languages(config.resolved_languages)
    npm_langs = get_npm_languages(config.resolved_languages)

    # Step 1: Bundle binary language servers
    if binary_langs:
        print_section("Bundling Binary Language Servers")
        print(f"  Languages: {', '.join(binary_langs)}")

        bundle_cmd = build_bundle_command(config, binary_langs)
        print(f"  Executing: {' '.join(bundle_cmd)}")
        print()

        result = subprocess.run(bundle_cmd, check=False)
        if result.returncode != 0:
            print("\n  [ERROR] Bundling failed!")
            return result.returncode
    else:
        print_section("No Binary Language Servers Selected")
        print("  Skipping binary bundling step.")

    # Step 2: Handle npm-based language servers
    if npm_langs:
        print_section("npm-based Language Servers")
        print("  The following npm-based servers require Node.js bundling:")
        for ls_id in npm_langs:
            info = LANGUAGE_SERVERS[ls_id]
            packages = info.get("npm_packages", [])
            print(f"    - {info['name']}: {', '.join(packages)}")
        print()
        if config.dry_run:
            print("  [DRY RUN] npm packages would be installed in full variant build")
        else:
            print("  Note: npm packages are installed during full variant workflow build.")
            print("  Use --preset web with full variant for complete web development support.")

    # Step 2: Run PyInstaller (if not skipped)
    if not config.skip_pyinstaller and not config.dry_run:
        print_section("Building Executable with PyInstaller")

        spec_path = Path(__file__).parent.parent / "serena.spec"
        pyinstaller_cmd = ["pyinstaller", str(spec_path), "--clean"]
        pyinstaller_cmd.extend(config.pyinstaller_args)

        print(f"  Executing: {' '.join(pyinstaller_cmd)}")
        print()

        result = subprocess.run(pyinstaller_cmd, check=False)
        if result.returncode != 0:
            print("\n  [ERROR] PyInstaller failed!")
            return result.returncode

    print_header("Build Complete!")

    if config.dry_run:
        print("  [DRY RUN] No files were created")
    else:
        print(f"  Language servers bundled in: {config.output_dir}")
        if not config.skip_pyinstaller:
            print("  Executable created in: dist/")

    return 0


# =============================================================================
# CLI ENTRY POINT
# =============================================================================


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Serena Custom Build Generator - Precise Language Selection",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode
  python scripts/build_custom_serena.py

  # Select specific languages
  python scripts/build_custom_serena.py --languages clangd,rust-analyzer,jdtls

  # Use preset and add more languages
  python scripts/build_custom_serena.py --preset standard --languages gopls,typescript

  # List all available languages
  python scripts/build_custom_serena.py --list-languages

  # List presets
  python scripts/build_custom_serena.py --list-presets
        """,
    )

    parser.add_argument(
        "--languages",
        "-l",
        type=str,
        help="Comma-separated language server IDs (e.g., clangd,rust-analyzer,typescript)",
    )
    parser.add_argument(
        "--preset",
        "-p",
        type=str,
        choices=list(PRESETS.keys()),
        help="Use a preset as base selection",
    )
    parser.add_argument(
        "--platform",
        type=str,
        help="Target platform (linux-x64, win-x64, osx-x64, osx-arm64)",
    )
    parser.add_argument(
        "--output-dir",
        "-o",
        type=str,
        default="./language_servers",
        help="Output directory for bundled LS",
    )
    parser.add_argument(
        "--config",
        "-c",
        type=str,
        help="Load configuration from JSON file",
    )
    parser.add_argument(
        "--save-config",
        "-s",
        type=str,
        help="Save configuration to JSON file",
    )
    parser.add_argument(
        "--dry-run",
        "-n",
        action="store_true",
        help="Preview without downloading/building",
    )
    parser.add_argument(
        "--no-pyinstaller",
        action="store_true",
        help="Skip PyInstaller (bundle language servers only)",
    )
    parser.add_argument(
        "--list-languages",
        action="store_true",
        help="List all available language servers",
    )
    parser.add_argument(
        "--list-presets",
        action="store_true",
        help="List available presets",
    )
    parser.add_argument(
        "--interactive",
        "-i",
        action="store_true",
        help="Force interactive mode even with other arguments",
    )

    args = parser.parse_args()

    # Handle list commands
    if args.list_languages:
        print_header("Available Language Servers")
        display_languages_table()
        print(f"\n  Total: {len(LANGUAGE_SERVERS)} language servers")
        return 0

    if args.list_presets:
        display_presets()
        return 0

    # Build configuration
    config: BuildConfig

    if args.config:
        # Load from file
        config_path = Path(args.config)
        if not config_path.exists():
            print(f"Error: Config file not found: {args.config}")
            return 1

        with open(config_path) as f:
            config = BuildConfig.from_dict(json.load(f))
        print(f"Loaded configuration from: {args.config}")

    elif args.languages or args.preset:
        # CLI mode with explicit languages
        languages = []

        if args.preset:
            languages = list(PRESETS[args.preset]["languages"])
            print(f"Using preset '{args.preset}': {len(languages)} languages")

        if args.languages:
            additional = [ls.strip() for ls in args.languages.split(",")]
            languages.extend(additional)
            print(f"Added languages: {', '.join(additional)}")

        config = BuildConfig(
            languages=languages,
            platform=args.platform or "",
            output_dir=args.output_dir,
            dry_run=args.dry_run,
            skip_pyinstaller=args.no_pyinstaller,
        )

    elif args.interactive or sys.stdin.isatty():
        # Interactive mode
        config = interactive_build()

    else:
        # Non-interactive, no languages specified
        parser.print_help()
        return 1

    # Resolve dependencies
    if not config.resolved_languages:
        resolved, auto_added, warnings = resolve_dependencies(config.languages)
        total_size, size_breakdown = calculate_size(resolved)

        config.resolved_languages = resolved
        config.auto_added = auto_added
        config.warnings = warnings
        config.size_breakdown = size_breakdown
        config.total_size_mb = total_size
        config.requires_node = check_node_requirement(resolved)

    # Apply CLI overrides
    if args.platform:
        config.platform = args.platform
    if args.output_dir != "./language_servers":
        config.output_dir = args.output_dir
    if args.dry_run:
        config.dry_run = True
    if args.no_pyinstaller:
        config.skip_pyinstaller = True

    # Save config if requested
    if args.save_config:
        save_path = Path(args.save_config)
        with open(save_path, "w") as f:
            json.dump(config.to_dict(), f, indent=2)
        print(f"Configuration saved to: {args.save_config}")

        # If only saving config (with dry-run), show summary and exit without building
        if config.dry_run:
            display_selection_summary(config)
            print("\n  [DRY RUN] Configuration saved. No build executed.")
            return 0

    # Display summary for CLI mode
    if not args.interactive and (args.languages or args.preset or args.config):
        display_selection_summary(config)
        print()

    # Run build
    return run_build(config)


if __name__ == "__main__":
    sys.exit(main())
