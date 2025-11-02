# CI-Safe Command Test Design

## Overview

This document describes the comprehensive test suite for Serena CLI commands that are safe for continuous integration (CI) environments. These commands do not modify git state, install external dependencies, or require external services.

## Safe Commands Identified

Team 1 analysis identified three commands safe for CI execution:

1. **`project generate-yml`** - Generates project configuration
2. **`project is_ignored_path`** - Checks gitignore logic
3. **`print-system-prompt`** - Generates system prompt text

## Test Suite Location

**File**: `/root/repo/test/serena/test_safe_cli_commands.py`

**Test Classes**: 4 main test classes with 33 test cases total

```
├── TestGenerateYmlCommand (10 tests)
├── TestIsIgnoredPathCommand (10 tests)
├── TestPrintSystemPromptCommand (10 tests)
└── TestCLICommandsIntegration (3 tests)
```

## Test Design Principles

### 1. Isolation

Each test:
- Creates its own temporary test project directory
- Cleans up resources in `teardown_method()`
- Never modifies the actual Serena codebase
- Uses Click's `CliRunner` for command invocation without side effects

### 2. Reproducibility

Tests are:
- Deterministic and order-independent
- Not dependent on system state or external services
- Self-contained with all necessary setup
- Idempotent (can be run multiple times with same results)

### 3. CI Safety

All tests:
- Run entirely within temporary directories
- Don't require git initialization or operations
- Don't install or download dependencies
- Don't call external tools or APIs
- Complete quickly (full suite runs in ~3 seconds)

## Detailed Test Coverage

### Class 1: TestGenerateYmlCommand

Tests the `serena project generate-yml` command.

#### Test Cases

| Test | Purpose | Setup | Validation |
|------|---------|-------|-----------|
| `test_generate_yml_with_python_project` | Basic Python project detection | Create `main.py` | YAML created, `languages: [python]` |
| `test_generate_yml_with_typescript_project` | TypeScript detection | Create `*.ts` files | `languages: [typescript]` detected |
| `test_generate_yml_with_explicit_language` | Language override flag | Add `--language go` | Override works correctly |
| `test_generate_yml_with_multiple_languages` | Multiple language support | Add `--language python --language go` | Both languages included |
| `test_generate_yml_creates_serena_directory` | Directory structure | Generate config | `.serena/` directory exists |
| `test_generate_yml_fails_with_existing_config` | Duplicate prevention | Existing `project.yml` | Command fails with FileExistsError |
| `test_generate_yml_fails_with_no_source_files` | Empty directory handling | Empty project dir | Command fails with ValueError |
| `test_generate_yml_project_name_derived_from_directory` | Name inference | No explicit name | Uses directory name |
| `test_generate_yml_preserves_yaml_structure` | Config completeness | Generate config | All required fields present |
| `test_generate_yml_output_message` | User-friendly output | Generate config | Output contains helpful info |

#### Key Validations

- Command exit code is 0
- `project.yml` file created at `.serena/project.yml`
- YAML is valid and parseable
- All required fields present (project_name, languages)
- Error messages are helpful

### Class 2: TestIsIgnoredPathCommand

Tests the `serena project is_ignored_path` command.

#### Test Cases

| Test | Purpose | Setup | Validation |
|------|---------|-------|-----------|
| `test_is_ignored_path_source_file_not_ignored` | Source file detection | Create `main.py` | File shows "IS NOT ignored" |
| `test_is_ignored_path_non_source_file_not_ignored_by_default` | Non-source handling | Create `README.md` | Output shows status correctly |
| `test_is_ignored_path_gitignore_respected` | Gitignore integration | Create `.gitignore` with patterns | Matching files are ignored |
| `test_is_ignored_path_git_directory_always_ignored` | Security: .git protection | Create `.git/config` | `.git/` always ignored |
| `test_is_ignored_path_absolute_path` | Path format support | Use absolute paths | Works with absolute paths |
| `test_is_ignored_path_relative_path` | Path format support | Use relative paths | Works with relative paths |
| `test_is_ignored_path_nested_directory_file` | Nested path handling | Create `src/utils/helpers.py` | Correctly evaluates nested files |
| `test_is_ignored_path_project_root_not_ignored` | Root safety | Check `.` | Project root never ignored |
| `test_is_ignored_path_log_files_ignored_by_gitignore` | Pattern matching | Create `*.log` pattern | Log files properly ignored |
| `test_is_ignored_path_output_format` | User interface | Check any file | Output is clear and readable |

#### Key Validations

- Command exit code is 0
- Output contains clear status: "IS ignored" or "IS NOT ignored"
- Respects `.gitignore` patterns
- Handles both absolute and relative paths
- Never ignores project root

### Class 3: TestPrintSystemPromptCommand

Tests the `serena print-system-prompt` command.

#### Test Cases

| Test | Purpose | Setup | Validation |
|------|---------|-------|-----------|
| `test_print_system_prompt_basic_output` | Basic functionality | Valid project | Command succeeds, output generated |
| `test_print_system_prompt_contains_instructions` | Instructions presence | Use `--only-instructions` | Output contains tool guidance |
| `test_print_system_prompt_with_prefix_postfix` | Complete context | Default flags | Output includes context setting |
| `test_print_system_prompt_default_context` | Context handling | No context flag | Uses default context |
| `test_print_system_prompt_default_mode` | Mode handling | No mode flag | Uses default modes |
| `test_print_system_prompt_log_level_warning` | Log level support | `--log-level WARNING` | Command succeeds |
| `test_print_system_prompt_log_level_info` | Log level support | `--log-level INFO` | Command succeeds |
| `test_print_system_prompt_works_with_project_path` | Positional argument | Pass project path | Works with argument |
| `test_print_system_prompt_output_length` | Output substantiality | Generate prompt | Output > 100 chars (not empty) |
| `test_print_system_prompt_consistent_output` | Idempotency | Run twice | Same output both times |

#### Key Validations

- Command exit code is 0
- Non-empty output (minimum 100 characters)
- Contains instruction/tool-related content
- Consistent across multiple runs
- Respects log level parameter

### Class 4: TestCLICommandsIntegration

Tests command interactions and CI workflows.

#### Test Cases

| Test | Purpose | Sequence | Validation |
|------|---------|----------|-----------|
| `test_full_workflow_generate_check_prompt` | Complete workflow | 1. Generate config 2. Check paths 3. Print prompt | All steps succeed |
| `test_ci_safety_no_external_calls` | CI environment safety | Run all 3 commands | No external calls required |
| `test_commands_idempotent` | Idempotency | Run commands multiple times | Same results, no side effects |

#### Key Validations

- All commands complete successfully
- Commands work in sequence
- No external dependencies required
- Repeated execution produces consistent results

## Running the Tests

### Run All Tests

```bash
uv run pytest test/serena/test_safe_cli_commands.py -v
```

### Run Specific Test Class

```bash
uv run pytest test/serena/test_safe_cli_commands.py::TestGenerateYmlCommand -v
```

### Run Specific Test

```bash
uv run pytest test/serena/test_safe_cli_commands.py::TestGenerateYmlCommand::test_generate_yml_with_python_project -v
```

### Run with Coverage

```bash
uv run pytest test/serena/test_safe_cli_commands.py --cov=serena.cli --cov-report=term-missing
```

## Test Execution Flow

### For Each Test Method

```
1. setup_method()
   ├─ Create temporary directory (tempfile.mkdtemp)
   └─ Initialize CliRunner for command invocation

2. Test Execution
   ├─ Setup test data (create files, config)
   ├─ Invoke CLI command
   └─ Validate results

3. teardown_method()
   └─ Delete temporary directory (shutil.rmtree)
```

### Complete Test Suite Execution

```
1. Collect all tests (33 tests)
2. Run tests sequentially
3. Each test is isolated and independent
4. Print results summary
5. Exit with code 0 (all pass) or non-zero (failures)
```

## Expected Test Output

```
============================= test session starts ==============================
platform linux -- Python 3.11.14, pytest-8.4.1, pluggy-1.6.0
rootdir: /root/repo
configfile: pyproject.toml

test/serena/test_safe_cli_commands.py::TestGenerateYmlCommand::test_generate_yml_with_python_project PASSED [  3%]
test/serena/test_safe_cli_commands.py::TestGenerateYmlCommand::test_generate_yml_with_typescript_project PASSED [  6%]
...
test/serena/test_safe_cli_commands.py::TestCLICommandsIntegration::test_commands_idempotent PASSED [100%]

======================== 33 passed in 2.87s ========================
```

## CI Integration

### GitHub Actions Example

```yaml
name: Safe CLI Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: astral-sh/setup-uv@v1
      - run: uv run pytest test/serena/test_safe_cli_commands.py -v
```

### Benefits for CI

- Fast execution (~3 seconds)
- No external dependencies
- No git operations
- Deterministic results
- Early feedback on CLI changes
- Safe for pull request testing

## Failure Modes and Diagnostics

### Common Test Failures

| Failure | Cause | Resolution |
|---------|-------|-----------|
| FileNotFoundError on .serena/project.yml | generate-yml didn't create config | Check ProjectConfig.autogenerate() |
| "IS ignored" mismatch | Gitignore pattern logic | Verify pathspec matching |
| Output assertion fails | CLI output format changed | Update assertions |
| Exit code non-zero | Command raised exception | Check Click error handling |

### Debugging Tests

```bash
# Run single test with full output
uv run pytest test/serena/test_safe_cli_commands.py::TestGenerateYmlCommand::test_generate_yml_with_python_project -vv -s

# Show print statements and logs
uv run pytest test/serena/test_safe_cli_commands.py -v --capture=no

# Run with traceback
uv run pytest test/serena/test_safe_cli_commands.py -v --tb=long
```

## Extending the Test Suite

### Adding New Tests

1. Choose appropriate test class or create new class
2. Follow naming convention: `test_<command>_<scenario>`
3. Implement `setup_method()` for initialization
4. Use `self.runner.invoke()` for CLI commands
5. Assert exit code and output
6. Cleanup happens automatically in `teardown_method()`

### Example: New Test Template

```python
def test_new_scenario(self) -> None:
    """Test description."""
    # Setup: Create test data
    (self.project_path / "example.py").write_text("pass\n")

    # Execute: Run command
    result = self.runner.invoke(
        ProjectCommands.command_name,
        [str(self.project_path), "--option", "value"]
    )

    # Verify: Check results
    assert result.exit_code == 0
    assert "expected text" in result.output
```

## Performance Characteristics

- **Total Suite Time**: ~3 seconds
- **Per-Test Average**: ~90ms
- **Slowest Test**: print-system-prompt tests (~200ms)
- **Fastest Test**: is_ignored_path checks (~20ms)
- **Parallelization**: Can run with `-n auto` pytest-xdist

## Maintenance Notes

### Test Dependencies

- Python 3.11+
- pytest
- click (for CliRunner)
- pyyaml (for config validation)
- ruamel.yaml (for YAML comment preservation)

### When to Update Tests

- CLI command signatures change
- Output format modifications
- New language support added
- Gitignore logic changes
- Project configuration structure updates

### Related Files

- `/root/repo/src/serena/cli.py` - CLI command definitions
- `/root/repo/src/serena/config/serena_config.py` - Configuration classes
- `/root/repo/src/serena/project.py` - Project class with is_ignored_path

## Success Criteria for CI

All tests must:
- ✅ Exit with code 0
- ✅ Complete within 10 seconds
- ✅ Not modify git state
- ✅ Not require external services
- ✅ Not install dependencies
- ✅ Produce consistent results
- ✅ Clean up all temporary files

## References

- [Click Testing Documentation](https://click.palletsprojects.com/testing/)
- [Pytest Documentation](https://docs.pytest.org/)
- [Serena CLI Implementation](../../src/serena/cli.py)
