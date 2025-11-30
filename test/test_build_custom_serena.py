"""Tests for scripts/build_custom_serena.py"""

import json
import subprocess
import sys
from pathlib import Path

import pytest


@pytest.fixture
def script_path() -> Path:
    """Path to build_custom_serena.py script."""
    return Path(__file__).parent.parent / "scripts" / "build_custom_serena.py"


@pytest.fixture
def temp_config(tmp_path: Path) -> Path:
    """Create a temporary config file path."""
    return tmp_path / "test_config.json"


def run_script(script_path: Path, args: list[str]) -> tuple[int, str, str]:
    """Run the script with given arguments.

    Returns:
        Tuple of (returncode, stdout, stderr)

    """
    cmd = [sys.executable, str(script_path)] + args
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.returncode, result.stdout, result.stderr


def test_script_exists(script_path: Path) -> None:
    """Test that the script file exists."""
    assert script_path.exists(), f"Script not found at {script_path}"


def test_help_output(script_path: Path) -> None:
    """Test that --help works."""
    returncode, stdout, stderr = run_script(script_path, ["--help"])
    assert returncode == 0
    assert "Interactive generator for custom Serena standalone builds" in stdout
    assert "--preset" in stdout
    assert "--config" in stdout
    assert "--save-config" in stdout


def test_list_presets(script_path: Path) -> None:
    """Test --list-presets command."""
    returncode, stdout, stderr = run_script(script_path, ["--list-presets"])
    assert returncode == 0
    assert "Available Presets" in stdout
    assert "minimal:" in stdout
    assert "standard:" in stdout
    assert "full:" in stdout
    assert "web:" in stdout
    assert "systems:" in stdout
    assert "jvm:" in stdout


def test_list_languages(script_path: Path) -> None:
    """Test --list-languages command."""
    returncode, stdout, stderr = run_script(script_path, ["--list-languages"])
    assert returncode == 0
    assert "Available Language Servers" in stdout
    assert "Web Development:" in stdout
    assert "Systems Programming:" in stdout
    assert "JVM Languages:" in stdout
    assert "clangd:" in stdout
    assert "rust-analyzer:" in stdout
    assert "gopls:" in stdout


def test_preset_minimal_save_config(script_path: Path, temp_config: Path) -> None:
    """Test saving minimal preset to config file."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "minimal", "--save-config", str(temp_config)])

    # Should succeed and save config
    assert returncode == 0, f"Script failed with stderr: {stderr}"
    assert temp_config.exists(), "Config file was not created"
    assert "Configuration saved" in stdout

    # Verify config contents
    with open(temp_config) as f:
        config = json.load(f)

    assert config["languages"] == []
    assert config["platform"] is None
    assert config["output_dir"] == "./language_servers"
    assert "run_pyinstaller" in config


def test_preset_standard_save_config(script_path: Path, temp_config: Path) -> None:
    """Test saving standard preset to config file."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "standard", "--save-config", str(temp_config)])

    assert returncode == 0
    assert temp_config.exists()

    with open(temp_config) as f:
        config = json.load(f)

    # Standard preset should include common languages
    assert "clangd" in config["languages"]
    assert "rust-analyzer" in config["languages"]
    assert "lua-ls" in config["languages"]
    assert "terraform-ls" in config["languages"]
    assert "dart" in config["languages"]


def test_preset_full_save_config(script_path: Path, temp_config: Path) -> None:
    """Test saving full preset to config file."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "full", "--save-config", str(temp_config)])

    assert returncode == 0
    assert temp_config.exists()

    with open(temp_config) as f:
        config = json.load(f)

    # Full preset should include all languages
    expected_languages = [
        "clangd",
        "terraform-ls",
        "dart",
        "rust-analyzer",
        "lua-ls",
        "jdtls",
        "gradle",
        "kotlin-ls",
        "gopls",
    ]
    for lang in expected_languages:
        assert lang in config["languages"], f"Missing {lang} in full preset"


def test_preset_web_save_config(script_path: Path, temp_config: Path) -> None:
    """Test saving web preset to config file."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "web", "--save-config", str(temp_config)])

    assert returncode == 0
    with open(temp_config) as f:
        config = json.load(f)

    # Web preset languages
    assert "typescript" in config["languages"]
    assert "php" in config["languages"]
    assert "yaml" in config["languages"]
    assert "bash" in config["languages"]


def test_preset_systems_save_config(script_path: Path, temp_config: Path) -> None:
    """Test saving systems preset to config file."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "systems", "--save-config", str(temp_config)])

    assert returncode == 0
    with open(temp_config) as f:
        config = json.load(f)

    # Systems preset languages
    assert "clangd" in config["languages"]
    assert "rust-analyzer" in config["languages"]
    assert "gopls" in config["languages"]


def test_preset_jvm_save_config(script_path: Path, temp_config: Path) -> None:
    """Test saving JVM preset to config file."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "jvm", "--save-config", str(temp_config)])

    assert returncode == 0
    with open(temp_config) as f:
        config = json.load(f)

    # JVM preset languages
    assert "jdtls" in config["languages"]
    assert "kotlin-ls" in config["languages"]
    assert "gradle" in config["languages"]


def test_load_config(script_path: Path, temp_config: Path) -> None:
    """Test loading config from file."""
    # First create a config
    config_data = {
        "languages": ["clangd", "rust-analyzer"],
        "platform": "linux-x64",
        "output_dir": "./test_output",
        "run_pyinstaller": False,
        "pyinstaller_args": [],
    }

    with open(temp_config, "w") as f:
        json.dump(config_data, f)

    # Now try to load it (with dry-run to avoid actual build)
    returncode, stdout, stderr = run_script(script_path, ["--config", str(temp_config), "--dry-run"])

    # Script should load config and show it's being used
    assert "Loaded configuration from" in stdout
    assert "[DRY RUN]" in stdout


def test_platform_override(script_path: Path, temp_config: Path) -> None:
    """Test platform override functionality."""
    returncode, stdout, stderr = run_script(
        script_path,
        [
            "--preset",
            "minimal",
            "--platform",
            "win-x64",
            "--save-config",
            str(temp_config),
        ],
    )

    assert returncode == 0
    with open(temp_config) as f:
        config = json.load(f)

    assert config["platform"] == "win-x64"


def test_output_dir_override(script_path: Path, temp_config: Path) -> None:
    """Test output directory override."""
    returncode, stdout, stderr = run_script(
        script_path,
        [
            "--preset",
            "minimal",
            "--output-dir",
            "./custom_output",
            "--save-config",
            str(temp_config),
        ],
    )

    assert returncode == 0
    with open(temp_config) as f:
        config = json.load(f)

    assert config["output_dir"] == "./custom_output"


def test_no_pyinstaller_flag(script_path: Path, temp_config: Path) -> None:
    """Test --no-pyinstaller flag."""
    returncode, stdout, stderr = run_script(
        script_path,
        ["--preset", "minimal", "--no-pyinstaller", "--save-config", str(temp_config)],
    )

    assert returncode == 0
    with open(temp_config) as f:
        config = json.load(f)

    assert config["run_pyinstaller"] is False


def test_config_json_format(script_path: Path, temp_config: Path) -> None:
    """Test that saved config is valid JSON with expected structure."""
    returncode, stdout, stderr = run_script(script_path, ["--preset", "standard", "--save-config", str(temp_config)])

    assert returncode == 0

    # Should be valid JSON
    with open(temp_config) as f:
        config = json.load(f)

    # Verify expected keys
    required_keys = [
        "languages",
        "platform",
        "output_dir",
        "run_pyinstaller",
        "pyinstaller_args",
    ]
    for key in required_keys:
        assert key in config, f"Missing required key: {key}"

    # Verify types
    assert isinstance(config["languages"], list)
    assert isinstance(config["output_dir"], str)
    assert isinstance(config["run_pyinstaller"], bool)
    assert isinstance(config["pyinstaller_args"], list)


def test_example_config_file_exists() -> None:
    """Test that example config file exists and is valid."""
    example_config = Path(__file__).parent.parent / "scripts" / "example_build_config.json"
    assert example_config.exists(), "Example config file not found"

    # Should be valid JSON
    with open(example_config) as f:
        config = json.load(f)

    # Verify it has expected structure
    assert "languages" in config
    assert "platform" in config
    assert isinstance(config["languages"], list)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
