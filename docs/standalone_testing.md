# Standalone Build Testing

This document describes the testing infrastructure for Serena's standalone executable builds.

## Overview

Standalone builds are tested to ensure that:
- The executable starts without errors
- All bundled resources are accessible (contexts, modes, templates, icons)
- Path handling works correctly in frozen/PyInstaller mode
- CLI commands function properly
- Environment variables are respected
- Configuration operations work

## Test Types

We provide two testing approaches:

### 1. Standalone Test Script (`scripts/test_standalone.py`)

A comprehensive Python script that can be run independently to test a standalone executable.

**Features:**
- Works without pytest
- Detailed test output with pass/fail status
- JSON output option for CI/CD integration
- Can test any executable by path

**Usage:**
```bash
# Test the built executable
python scripts/test_standalone.py dist/serena-mcp-server

# With JSON output for CI
python scripts/test_standalone.py dist/serena-mcp-server --json-output results.json

# Windows
python scripts/test_standalone.py dist/serena-mcp-server.exe
```

**Test Categories:**
- Basic functionality (--help, startup)
- Resource accessibility (contexts, modes, tools, prompts)
- Path handling (frozen mode, REPO_ROOT, _serena_pkg_path)
- Configuration (env vars, config file operations)
- Project commands (create, index)
- Error handling (invalid commands, graceful failures)

### 2. Pytest Tests (`test/test_standalone.py`)

Pytest-based tests for integration with the existing test suite.

**Features:**
- Integrates with pytest test discovery
- Uses pytest fixtures and markers
- Automatic executable discovery
- Skip if executable not found

**Usage:**
```bash
# Run standalone tests (auto-discovers executable)
pytest test/test_standalone.py -v

# Specify executable explicitly
pytest test/test_standalone.py -v --standalone-exe=dist/serena-mcp-server

# Run with specific marker
pytest -m standalone -v

# Set via environment variable
export SERENA_STANDALONE_EXE=dist/serena-mcp-server
pytest test/test_standalone.py -v
```

**Executable Discovery Order:**
1. `--standalone-exe` pytest option
2. `SERENA_STANDALONE_EXE` environment variable
3. `dist/serena-mcp-server` (Linux/macOS)
4. `dist/serena-mcp-server.exe` (Windows)

## Test Coverage

### Basic Functionality Tests
- ✓ `--help` command displays usage
- ✓ Executable starts without import errors
- ✓ No PyInstaller path handling errors
- ✓ Version information available

### Resource Accessibility Tests
- ✓ Contexts are bundled and loadable
- ✓ Modes are bundled and loadable
- ✓ Tools registry is accessible
- ✓ Tool descriptions can be retrieved
- ✓ Prompt templates are bundled
- ✓ Default context loads successfully

### Path Handling Tests
- ✓ `REPO_ROOT` is set correctly in frozen mode
- ✓ `_serena_pkg_path()` works in frozen mode
- ✓ Resource paths resolve correctly
- ✓ sys._MEIPASS is handled properly

### Configuration Tests
- ✓ `SERENA_STANDALONE` environment variable (true/1)
- ✓ HOME directory can be overridden
- ✓ Config file operations work

### Project Commands Tests
- ✓ Project subcommands available
- ✓ `project create --help` works
- ✓ `project index --help` works

### Error Handling Tests
- ✓ Invalid commands fail gracefully
- ✓ Invalid options fail gracefully
- ✓ Helpful error messages displayed

## CI/CD Integration

### GitHub Actions Workflow

The standalone build workflow (`.github/workflows/build-standalone.yml`) includes test steps:

```yaml
- name: Test executable (comprehensive)
  shell: bash
  run: |
    python scripts/test_standalone.py ./dist/serena-mcp-server --json-output test-results.json

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ matrix.platform }}
    path: test-results.json
```

### Adding Tests to Workflow

Update the build jobs in `.github/workflows/build-standalone.yml`:

**Replace:**
```yaml
- name: Test executable
  shell: bash
  run: |
    ./dist/serena-mcp-server --help || echo "Help command executed"
```

**With:**
```yaml
- name: Test executable (comprehensive)
  shell: bash
  run: |
    # Platform-specific executable name
    if [[ "${{ runner.os }}" == "Windows" ]]; then
      EXE="./dist/serena-mcp-server.exe"
    else
      EXE="./dist/serena-mcp-server"
      chmod +x "$EXE"
    fi

    # Run comprehensive tests
    python scripts/test_standalone.py "$EXE" --json-output test-results.json

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results-${{ runner.os }}
    path: test-results.json
    retention-days: ${{ needs.setup.outputs.retention-days }}
```

## Local Testing Workflow

### Quick Test
```bash
# Build and test in one go
pyinstaller serena.spec --clean
python scripts/test_standalone.py dist/serena-mcp-server
```

### Development Testing
```bash
# Build
pyinstaller serena.spec --clean

# Run specific test categories
pytest test/test_standalone.py::test_help_command -v
pytest test/test_standalone.py::test_contexts_are_bundled -v

# Run all standalone tests
pytest -m standalone -v
```

### Testing Different Platforms

**Linux:**
```bash
pyinstaller serena.spec --clean
python scripts/test_standalone.py dist/serena-mcp-server
```

**macOS:**
```bash
pyinstaller serena.spec --clean
python scripts/test_standalone.py dist/serena-mcp-server
```

**Windows:**
```powershell
pyinstaller serena.spec --clean
python scripts/test_standalone.py dist/serena-mcp-server.exe
```

## Debugging Failed Tests

### View Detailed Output
```bash
# Standalone script shows detailed errors
python scripts/test_standalone.py dist/serena-mcp-server

# Pytest with verbose output
pytest test/test_standalone.py -v -s
```

### Check JSON Results
```bash
python scripts/test_standalone.py dist/serena-mcp-server --json-output results.json
cat results.json | jq '.results[] | select(.status != "PASSED")'
```

### Test Individual Commands
```bash
# Test a specific command manually
./dist/serena-mcp-server --help
./dist/serena-mcp-server context list
./dist/serena-mcp-server tools list -q
```

### Common Issues

**Import Errors:**
- Check `hiddenimports` in `serena.spec`
- Verify all language servers are listed
- Ensure third-party dependencies are included

**Resource Not Found:**
- Check `datas` section in `serena.spec`
- Verify resource paths in `src/serena/constants.py`
- Test `_serena_pkg_path()` function

**Path Handling:**
- Verify `_get_repo_root_path()` in `constants.py`
- Check frozen mode detection: `getattr(sys, "frozen", False)`
- Ensure sys._MEIPASS is handled correctly

## Extending Tests

### Adding New Tests

**To standalone script (`scripts/test_standalone.py`):**
```python
def test_my_new_feature(self):
    """Test description."""
    result = self.run_command(["my-command", "--option"])
    self.assert_exit_code(result, 0)
    self.assert_in_output(result, "expected text")

# Register in run_all_tests():
self.test("My new feature", self.test_my_new_feature)
```

**To pytest tests (`test/test_standalone.py`):**
```python
@pytest.mark.standalone
def test_my_new_feature(run_exe):
    """Test description."""
    result = run_exe(["my-command", "--option"])
    assert result.returncode == 0
    assert "expected text" in result.stdout
```

### Testing New Resources

When adding new bundled resources:

1. Update `serena.spec` to include the resource
2. Add test to verify resource is accessible
3. Test in both development and frozen modes

Example:
```python
@pytest.mark.standalone
def test_new_resource_bundled(run_exe):
    """Test that new resource is accessible."""
    result = run_exe(["command-that-uses-resource"])
    assert result.returncode == 0
    assert "resource loaded" in result.stdout
```

## Test Maintenance

### When to Update Tests

- **New CLI commands**: Add tests for new subcommands
- **New resources**: Add bundling verification tests
- **New environment variables**: Add configuration tests
- **Path handling changes**: Update path-related tests
- **Error message changes**: Update error handling tests

### Test Review Checklist

- [ ] All tests pass on Linux
- [ ] All tests pass on macOS
- [ ] All tests pass on Windows
- [ ] New features have corresponding tests
- [ ] Tests run in reasonable time (< 2 minutes total)
- [ ] Error messages are helpful
- [ ] JSON output format is stable

## Performance Considerations

### Test Execution Time

Current test suite runs in approximately:
- Standalone script: ~30-60 seconds
- Pytest tests: ~20-40 seconds

### Optimization Tips

1. **Use short timeouts**: Most commands complete in < 5 seconds
2. **Batch related tests**: Group similar commands together
3. **Skip slow tests in PR validation**: Use markers to skip optional tests
4. **Cache test results**: Reuse results for repeated tests

## References

- PyInstaller docs: https://pyinstaller.org/
- Serena build spec: `serena.spec`
- Constants and paths: `src/serena/constants.py`
- Standalone settings: `src/solidlsp/settings.py`
- Build workflow: `.github/workflows/build-standalone.yml`
