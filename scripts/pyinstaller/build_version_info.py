#!/usr/bin/env python3
"""
Build Windows Version Info for Serena PyInstaller Build

This script reads the version from pyproject.toml and generates a Windows version_info.txt
file from the template for use with PyInstaller.

Usage:
    python build_version_info.py [--output version_info.txt]
    
The script will:
1. Parse pyproject.toml to extract version and project information
2. Load the version_info_template.txt template
3. Replace template variables with actual values
4. Write the generated version_info.txt file
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any

try:
    import tomllib  # Python 3.11+
except ImportError:
    try:
        import tomli as tomllib  # fallback for older Python
    except ImportError:
        print("Error: tomllib (Python 3.11+) or tomli package required")
        sys.exit(1)


def parse_version(version_string: str) -> Dict[str, int]:
    """Parse semantic version string into components.
    
    Args:
        version_string: Version in format "major.minor.patch" or "major.minor.patch-suffix"
        
    Returns:
        Dictionary with major, minor, and patch version numbers
        
    Raises:
        ValueError: If version string format is invalid
    """
    # Remove any pre-release or build metadata
    clean_version = version_string.split('-')[0].split('+')[0]
    
    # Match semantic version pattern
    version_pattern = r'^(\d+)\.(\d+)\.(\d+)$'
    match = re.match(version_pattern, clean_version)
    
    if not match:
        raise ValueError(f"Invalid version format: {version_string}. Expected format: major.minor.patch")
    
    major, minor, patch = match.groups()
    return {
        'major': int(major),
        'minor': int(minor),
        'patch': int(patch)
    }


def load_pyproject_toml(pyproject_path: Path) -> Dict[str, Any]:
    """Load and parse pyproject.toml file.
    
    Args:
        pyproject_path: Path to pyproject.toml file
        
    Returns:
        Parsed TOML data as dictionary
        
    Raises:
        FileNotFoundError: If pyproject.toml doesn't exist
        ValueError: If TOML parsing fails
    """
    if not pyproject_path.exists():
        raise FileNotFoundError(f"pyproject.toml not found at: {pyproject_path}")
    
    try:
        with open(pyproject_path, 'rb') as f:
            return tomllib.load(f)
    except Exception as e:
        raise ValueError(f"Failed to parse pyproject.toml: {e}")


def load_template(template_path: Path) -> str:
    """Load version info template file.
    
    Args:
        template_path: Path to version_info_template.txt
        
    Returns:
        Template content as string
        
    Raises:
        FileNotFoundError: If template file doesn't exist
    """
    if not template_path.exists():
        raise FileNotFoundError(f"Template not found at: {template_path}")
    
    return template_path.read_text(encoding='utf-8')


def generate_version_info(pyproject_path: Path, template_path: Path, output_path: Path) -> None:
    """Generate version_info.txt from template and pyproject.toml.
    
    Args:
        pyproject_path: Path to pyproject.toml
        template_path: Path to version_info_template.txt
        output_path: Path where version_info.txt will be written
        
    Raises:
        Various exceptions if files can't be read or written
    """
    # Load project data
    pyproject_data = load_pyproject_toml(pyproject_path)
    project = pyproject_data.get('project', {})
    
    # Extract version information
    version_string = project.get('version')
    if not version_string:
        raise ValueError("No version found in pyproject.toml [project] section")
    
    print(f"Found version: {version_string}")
    
    # Parse version components
    version_components = parse_version(version_string)
    
    # Load template
    template_content = load_template(template_path)
    
    # Prepare replacement variables
    current_year = datetime.now().year
    replacements = {
        'MAJOR_VERSION': str(version_components['major']),
        'MINOR_VERSION': str(version_components['minor']),
        'PATCH_VERSION': str(version_components['patch']),
        'VERSION_STRING': version_string,
        'YEAR': str(current_year)
    }
    
    # Perform template substitution
    version_info_content = template_content
    for placeholder, value in replacements.items():
        version_info_content = version_info_content.replace(f'{{{placeholder}}}', value)
    
    # Write output file
    output_path.write_text(version_info_content, encoding='utf-8')
    
    print(f"Generated version info at: {output_path}")
    print(
        f"Version: {version_string} ({version_components['major']}.{version_components['minor']}.{version_components['patch']}.0)"
    )
    print(f"Copyright year: {current_year}")


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate Windows version_info.txt for Serena PyInstaller build"
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=Path('version_info.txt'),
        help='Output path for generated version_info.txt (default: version_info.txt)'
    )
    parser.add_argument(
        '--pyproject',
        type=Path,
        default=Path('../../pyproject.toml'),
        help='Path to pyproject.toml (default: ../../pyproject.toml)'
    )
    parser.add_argument(
        '--template',
        type=Path,
        default=Path('version_info_template.txt'),
        help='Path to template file (default: version_info_template.txt)'
    )
    
    args = parser.parse_args()
    
    try:
        generate_version_info(args.pyproject, args.template, args.output)
        print("\nSuccess! You can now use the generated version_info.txt with PyInstaller.")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()