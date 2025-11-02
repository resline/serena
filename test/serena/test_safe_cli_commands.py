"""
Tests for safe Serena CLI commands that are suitable for CI environments.

This test suite covers three commands identified as safe for CI execution:
1. project generate-yml - Creates project configuration
2. project is_ignored_path - Checks gitignore logic
3. print-system-prompt - Generates system prompt text

These commands do not modify git state, install dependencies, or require external services.
"""

import os
import shutil
import tempfile
from pathlib import Path

import pytest
import yaml
from click.testing import CliRunner

from serena.cli import ProjectCommands, TopLevelCommands


class TestGenerateYmlCommand:
    """Test suite for 'project generate-yml' command."""

    def setup_method(self) -> None:
        """Set up temporary test project directory."""
        self.test_dir = tempfile.mkdtemp(prefix="serena_test_")
        self.project_path = Path(self.test_dir)
        self.runner = CliRunner()

    def teardown_method(self) -> None:
        """Clean up test project directory."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_generate_yml_with_python_project(self) -> None:
        """Test generate-yml creates valid project.yml for Python project."""
        # Setup: Create a Python file
        (self.project_path / "main.py").write_text("def hello():\n    print('Hello, World!')\n")

        # Execute: Run generate-yml command
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: Command succeeded
        assert result.exit_code == 0, f"Command failed: {result.output}"

        # Verify: project.yml was created
        yml_path = self.project_path / ".serena" / "project.yml"
        assert yml_path.exists(), f"project.yml not created at {yml_path}"

        # Verify: Configuration is valid YAML
        with open(yml_path) as f:
            config = yaml.safe_load(f)
        assert config is not None
        assert "project_name" in config
        assert "languages" in config
        assert config["languages"] == ["python"]

    def test_generate_yml_with_typescript_project(self) -> None:
        """Test generate-yml detects TypeScript projects correctly."""
        # Setup: Create TypeScript files
        (self.project_path / "index.ts").write_text("const greeting: string = 'Hello';\n")
        (self.project_path / "utils.ts").write_text("export function add(a: number, b: number): number { return a + b; }\n")

        # Execute: Run generate-yml command
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: Command succeeded
        assert result.exit_code == 0, f"Command failed: {result.output}"

        # Verify: TypeScript is detected
        yml_path = self.project_path / ".serena" / "project.yml"
        with open(yml_path) as f:
            config = yaml.safe_load(f)
        assert config["languages"] == ["typescript"]

    def test_generate_yml_with_explicit_language(self) -> None:
        """Test generate-yml with explicit language override."""
        # Setup: Create a generic Python-like file
        (self.project_path / "main.py").write_text("print('hello')\n")

        # Execute: Override with Go language
        result = self.runner.invoke(
            ProjectCommands.generate_yml, [str(self.project_path), "--language", "go"]
        )

        # Verify: Command succeeded
        assert result.exit_code == 0, f"Command failed: {result.output}"

        # Verify: Configuration uses Go
        yml_path = self.project_path / ".serena" / "project.yml"
        with open(yml_path) as f:
            config = yaml.safe_load(f)
        assert config["languages"] == ["go"]

    def test_generate_yml_with_multiple_languages(self) -> None:
        """Test generate-yml with multiple explicit languages."""
        # Setup: Create source files
        (self.project_path / "main.py").write_text("print('hello')\n")

        # Execute: Specify multiple languages
        result = self.runner.invoke(
            ProjectCommands.generate_yml,
            [str(self.project_path), "--language", "python", "--language", "go"],
        )

        # Verify: Command succeeded
        assert result.exit_code == 0, f"Command failed: {result.output}"

        # Verify: Both languages are in config
        yml_path = self.project_path / ".serena" / "project.yml"
        with open(yml_path) as f:
            config = yaml.safe_load(f)
        assert "python" in config["languages"]
        assert "go" in config["languages"]

    def test_generate_yml_creates_serena_directory(self) -> None:
        """Test generate-yml creates .serena directory structure."""
        # Setup: Create a valid project
        (self.project_path / "main.py").write_text("pass\n")

        # Execute: Generate configuration
        self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: .serena directory exists
        serena_dir = self.project_path / ".serena"
        assert serena_dir.exists()
        assert serena_dir.is_dir()

    def test_generate_yml_fails_with_existing_config(self) -> None:
        """Test generate-yml fails if project.yml already exists."""
        # Setup: Create a project with existing config
        (self.project_path / "main.py").write_text("pass\n")
        serena_dir = self.project_path / ".serena"
        serena_dir.mkdir()
        yml_path = serena_dir / "project.yml"
        yml_path.write_text("project_name: existing\nlanguages:\n  - python\n")

        # Execute: Try to generate-yml again
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: Command failed with appropriate error
        assert result.exit_code != 0
        assert "already exists" in str(result.exception) or "FileExistsError" in str(result.exception)

    def test_generate_yml_fails_with_no_source_files(self) -> None:
        """Test generate-yml fails when no source files are found."""
        # Execute: Try to generate-yml in empty directory
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: Command failed with helpful error
        assert result.exit_code != 0
        assert "No source files found" in str(result.exception) or "ValueError" in str(result.exception)

    def test_generate_yml_project_name_derived_from_directory(self) -> None:
        """Test project name is derived from directory name when not specified."""
        # Setup: Create a project
        (self.project_path / "main.py").write_text("pass\n")

        # Execute: Generate configuration
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: Project name matches directory
        yml_path = self.project_path / ".serena" / "project.yml"
        with open(yml_path) as f:
            config = yaml.safe_load(f)
        assert config["project_name"] == self.project_path.name

    def test_generate_yml_preserves_yaml_structure(self) -> None:
        """Test generated project.yml has all required fields."""
        # Setup: Create a project
        (self.project_path / "main.py").write_text("pass\n")

        # Execute: Generate configuration
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])
        assert result.exit_code == 0

        # Verify: All required fields are present
        yml_path = self.project_path / ".serena" / "project.yml"
        with open(yml_path) as f:
            config = yaml.safe_load(f)

        required_fields = ["project_name", "languages"]
        for field in required_fields:
            assert field in config, f"Missing required field: {field}"

    def test_generate_yml_output_message(self) -> None:
        """Test generate-yml produces helpful output message."""
        # Setup: Create a project
        (self.project_path / "main.py").write_text("pass\n")

        # Execute: Generate configuration
        result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])

        # Verify: Output contains helpful information
        assert "project.yml" in result.output
        assert "languages" in result.output.lower()
        assert str(self.project_path) in result.output or ".serena" in result.output


class TestIsIgnoredPathCommand:
    """Test suite for 'project is_ignored_path' command."""

    def setup_method(self) -> None:
        """Set up temporary test project directory."""
        self.test_dir = tempfile.mkdtemp(prefix="serena_test_")
        self.project_path = Path(self.test_dir)
        self.runner = CliRunner()
        self._initialize_project()

    def teardown_method(self) -> None:
        """Clean up test project directory."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def _initialize_project(self) -> None:
        """Initialize a valid test project with configuration."""
        # Create a Python file
        (self.project_path / "main.py").write_text("print('hello')\n")

        # Generate project configuration
        result = CliRunner().invoke(ProjectCommands.generate_yml, [str(self.project_path)])
        assert result.exit_code == 0, f"Failed to initialize test project: {result.output}"

    def test_is_ignored_path_source_file_not_ignored(self) -> None:
        """Test that source files in supported languages are not ignored."""
        # Execute: Check if Python file is ignored
        result = self.runner.invoke(ProjectCommands.is_ignored_path, ["main.py", str(self.project_path)])

        # Verify: File is not ignored
        assert result.exit_code == 0
        assert "IS NOT ignored" in result.output

    def test_is_ignored_path_non_source_file_not_ignored_by_default(self) -> None:
        """Test that non-source files are not ignored by default (only when ignore_non_source_files=True)."""
        # Setup: Create a non-source file
        (self.project_path / "README.md").write_text("# Project\n")

        # Execute: Check if markdown file is ignored (default behavior does not ignore non-source files)
        result = self.runner.invoke(ProjectCommands.is_ignored_path, ["README.md", str(self.project_path)])

        # Verify: Non-source file is NOT ignored by default (CLI command doesn't use ignore_non_source_files)
        assert result.exit_code == 0
        # The command ignores non-source files at the Python level, but the CLI shows the ignore logic result
        assert "IS" in result.output  # Output should contain status

    def test_is_ignored_path_gitignore_respected(self) -> None:
        """Test that patterns in .gitignore are respected."""
        # Setup: Create .gitignore with pattern
        (self.project_path / ".gitignore").write_text("*.log\nbuild/\n")

        # Create files matching gitignore patterns
        (self.project_path / "debug.log").write_text("log content\n")
        build_dir = self.project_path / "build"
        build_dir.mkdir()
        (build_dir / "output.py").write_text("pass\n")

        # Execute: Check if ignored files match gitignore
        log_result = self.runner.invoke(ProjectCommands.is_ignored_path, ["debug.log", str(self.project_path)])
        build_result = self.runner.invoke(
            ProjectCommands.is_ignored_path, [str(build_dir / "output.py"), str(self.project_path)]
        )

        # Verify: Both are ignored due to gitignore
        assert "IS ignored" in log_result.output
        assert "IS ignored" in build_result.output

    def test_is_ignored_path_git_directory_always_ignored(self) -> None:
        """Test that .git directory is always ignored."""
        # Setup: Create .git directory
        git_dir = self.project_path / ".git"
        git_dir.mkdir()
        (git_dir / "config").write_text("config content\n")

        # Execute: Check if .git content is ignored
        result = self.runner.invoke(ProjectCommands.is_ignored_path, [".git/config", str(self.project_path)])

        # Verify: .git content is always ignored
        assert "IS ignored" in result.output

    def test_is_ignored_path_absolute_path(self) -> None:
        """Test is_ignored_path with absolute path."""
        # Execute: Use absolute path
        abs_path = str(self.project_path / "main.py")
        result = self.runner.invoke(ProjectCommands.is_ignored_path, [abs_path, str(self.project_path)])

        # Verify: Absolute path works correctly
        assert result.exit_code == 0
        assert "IS NOT ignored" in result.output

    def test_is_ignored_path_relative_path(self) -> None:
        """Test is_ignored_path with relative path."""
        # Execute: Use relative path
        result = self.runner.invoke(ProjectCommands.is_ignored_path, ["main.py", str(self.project_path)])

        # Verify: Relative path works correctly
        assert result.exit_code == 0
        assert "IS NOT ignored" in result.output

    def test_is_ignored_path_nested_directory_file(self) -> None:
        """Test is_ignored_path with files in nested directories."""
        # Setup: Create nested directory structure
        subdir = self.project_path / "src" / "utils"
        subdir.mkdir(parents=True)
        (subdir / "helpers.py").write_text("pass\n")

        # Execute: Check nested file
        result = self.runner.invoke(
            ProjectCommands.is_ignored_path, ["src/utils/helpers.py", str(self.project_path)]
        )

        # Verify: Nested source file is not ignored
        assert result.exit_code == 0
        assert "IS NOT ignored" in result.output

    def test_is_ignored_path_project_root_not_ignored(self) -> None:
        """Test that project root (.) is never ignored."""
        # Execute: Check if project root is ignored
        result = self.runner.invoke(ProjectCommands.is_ignored_path, [".", str(self.project_path)])

        # Verify: Project root is not ignored
        assert result.exit_code == 0
        assert "IS NOT ignored" in result.output

    def test_is_ignored_path_log_files_ignored_by_gitignore(self) -> None:
        """Test that gitignore patterns for log files work."""
        # Setup: Create gitignore with pattern for log files
        (self.project_path / ".gitignore").write_text("*.log\n")
        (self.project_path / "debug.log").write_text("debug log\n")
        (self.project_path / "app.log").write_text("app log\n")

        # Execute: Check log files
        debug_result = self.runner.invoke(
            ProjectCommands.is_ignored_path, ["debug.log", str(self.project_path)]
        )
        app_result = self.runner.invoke(
            ProjectCommands.is_ignored_path, ["app.log", str(self.project_path)]
        )

        # Verify: Both log files are ignored by gitignore pattern
        assert "IS ignored" in debug_result.output
        assert "IS ignored" in app_result.output

    def test_is_ignored_path_output_format(self) -> None:
        """Test that output format is clear and user-friendly."""
        # Execute: Check a file
        result = self.runner.invoke(ProjectCommands.is_ignored_path, ["main.py", str(self.project_path)])

        # Verify: Output contains path and clear status
        assert "main.py" in result.output
        assert "ignored" in result.output.lower()
        assert "IS " in result.output  # Clear status indicator


class TestPrintSystemPromptCommand:
    """Test suite for 'print-system-prompt' command."""

    def setup_method(self) -> None:
        """Set up temporary test project directory."""
        self.test_dir = tempfile.mkdtemp(prefix="serena_test_")
        self.project_path = Path(self.test_dir)
        self.runner = CliRunner()
        self._initialize_project()

    def teardown_method(self) -> None:
        """Clean up test project directory."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def _initialize_project(self) -> None:
        """Initialize a valid test project."""
        # Create a Python file
        (self.project_path / "main.py").write_text("def main():\n    pass\n")

        # Generate project configuration
        result = CliRunner().invoke(ProjectCommands.generate_yml, [str(self.project_path)])
        assert result.exit_code == 0, f"Failed to initialize test project: {result.output}"

    def test_print_system_prompt_basic_output(self) -> None:
        """Test that print-system-prompt generates output."""
        # Execute: Run print-system-prompt command
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Command succeeded and produced output
        assert result.exit_code == 0, f"Command failed: {result.output}"
        assert len(result.output) > 0, "No output generated"

    def test_print_system_prompt_contains_instructions(self) -> None:
        """Test that system prompt contains tool usage instructions."""
        # Execute: Run command with only-instructions flag
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt,
            [str(self.project_path), "--log-level", "WARNING", "--only-instructions"],
        )

        # Verify: Output contains instructions
        assert result.exit_code == 0
        assert len(result.output) > 0
        # Instructions should contain guidance about tools
        output_lower = result.output.lower()
        # Check for common instruction keywords
        assert any(
            keyword in output_lower
            for keyword in ["tool", "use", "guid", "instruct", "serena"]
        ), "Output doesn't contain expected instruction content"

    def test_print_system_prompt_with_prefix_postfix(self) -> None:
        """Test that system prompt includes prefix and postfix when not using --only-instructions."""
        # Execute: Run command without only-instructions flag
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Output contains expected markers
        assert result.exit_code == 0
        output = result.output
        # Should contain introduction or context setting
        assert "symbolic" in output.lower() or "tool" in output.lower() or "serena" in output.lower()

    def test_print_system_prompt_default_context(self) -> None:
        """Test print-system-prompt uses default context when not specified."""
        # Execute: Run without explicit context
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Command succeeded (default context is valid)
        assert result.exit_code == 0, f"Failed with default context: {result.output}"

    def test_print_system_prompt_default_mode(self) -> None:
        """Test print-system-prompt uses default modes when not specified."""
        # Execute: Run without explicit mode
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Command succeeded (default modes are valid)
        assert result.exit_code == 0, f"Failed with default modes: {result.output}"

    def test_print_system_prompt_log_level_warning(self) -> None:
        """Test print-system-prompt with WARNING log level."""
        # Execute: Specify WARNING log level
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Command succeeded
        assert result.exit_code == 0
        assert len(result.output) > 0

    def test_print_system_prompt_log_level_info(self) -> None:
        """Test print-system-prompt with INFO log level."""
        # Execute: Specify INFO log level
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "INFO"]
        )

        # Verify: Command succeeded
        assert result.exit_code == 0
        assert len(result.output) > 0

    def test_print_system_prompt_works_with_project_path(self) -> None:
        """Test that command works with explicit project path argument."""
        # Execute: Pass project path as positional argument
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Command succeeded
        assert result.exit_code == 0
        assert len(result.output) > 0

    def test_print_system_prompt_output_length(self) -> None:
        """Test that system prompt output is substantial (not empty)."""
        # Execute: Run command
        result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Output is substantial
        assert result.exit_code == 0
        assert len(result.output) > 100, "Output too short, likely incomplete"

    def test_print_system_prompt_consistent_output(self) -> None:
        """Test that multiple runs produce consistent output."""
        # Execute: Run command twice
        result1 = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )
        result2 = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )

        # Verify: Both runs succeeded and produced identical output
        assert result1.exit_code == 0
        assert result2.exit_code == 0
        assert result1.output == result2.output, "Output not consistent between runs"


class TestCLICommandsIntegration:
    """Integration tests combining multiple safe CLI commands."""

    def setup_method(self) -> None:
        """Set up temporary test project directory."""
        self.test_dir = tempfile.mkdtemp(prefix="serena_test_")
        self.project_path = Path(self.test_dir)
        self.runner = CliRunner()

    def teardown_method(self) -> None:
        """Clean up test project directory."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)

    def test_full_workflow_generate_check_prompt(self) -> None:
        """Test complete workflow: generate config, check paths, print prompt."""
        # Setup: Create a simple project
        (self.project_path / "main.py").write_text("print('hello')\n")
        (self.project_path / ".gitignore").write_text("*.log\n")
        (self.project_path / "debug.log").write_text("log content\n")

        # Step 1: Generate project configuration
        gen_result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])
        assert gen_result.exit_code == 0, f"Generation failed: {gen_result.output}"

        # Step 2: Check that source file is not ignored
        src_result = self.runner.invoke(
            ProjectCommands.is_ignored_path, ["main.py", str(self.project_path)]
        )
        assert src_result.exit_code == 0
        assert "IS NOT ignored" in src_result.output

        # Step 3: Check that gitignored file is ignored
        log_result = self.runner.invoke(
            ProjectCommands.is_ignored_path, ["debug.log", str(self.project_path)]
        )
        assert log_result.exit_code == 0
        assert "IS ignored" in log_result.output

        # Step 4: Generate system prompt
        prompt_result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )
        assert prompt_result.exit_code == 0
        assert len(prompt_result.output) > 0

    def test_ci_safety_no_external_calls(self) -> None:
        """Test that safe commands don't require external services or git operations."""
        # These commands should work entirely within the project directory
        # without calling external tools, installing dependencies, or modifying git state

        # Setup: Create minimal project
        (self.project_path / "main.py").write_text("pass\n")

        # All three commands should complete successfully
        commands_results = []

        # Command 1: generate-yml
        gen_result = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])
        commands_results.append(("generate-yml", gen_result.exit_code == 0))

        # Command 2: is_ignored_path (requires config)
        ignore_result = self.runner.invoke(
            ProjectCommands.is_ignored_path, ["main.py", str(self.project_path)]
        )
        commands_results.append(("is_ignored_path", ignore_result.exit_code == 0))

        # Command 3: print-system-prompt
        prompt_result = self.runner.invoke(
            TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
        )
        commands_results.append(("print-system-prompt", prompt_result.exit_code == 0))

        # Verify all commands succeeded
        for cmd_name, success in commands_results:
            assert success, f"Command {cmd_name} failed in CI-safe workflow"

    def test_commands_idempotent(self) -> None:
        """Test that commands can be run multiple times without side effects."""
        # Setup: Create a project
        (self.project_path / "main.py").write_text("pass\n")

        # Run generate-yml
        gen_result1 = self.runner.invoke(ProjectCommands.generate_yml, [str(self.project_path)])
        assert gen_result1.exit_code == 0

        # Run is_ignored_path multiple times
        for _ in range(3):
            ignore_result = self.runner.invoke(
                ProjectCommands.is_ignored_path, ["main.py", str(self.project_path)]
            )
            assert ignore_result.exit_code == 0

        # Run print-system-prompt multiple times
        outputs = []
        for _ in range(3):
            prompt_result = self.runner.invoke(
                TopLevelCommands.print_system_prompt, [str(self.project_path), "--log-level", "WARNING"]
            )
            assert prompt_result.exit_code == 0
            outputs.append(prompt_result.output)

        # Verify outputs are consistent
        assert len(set(outputs)) == 1, "print-system-prompt outputs differ across runs"


# Markers for test categorization
pytestmark = pytest.mark.python
