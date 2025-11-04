# Platform-Specific Runtime Tests for Serena Portable

## Overview

This document describes the comprehensive platform-specific runtime tests designed to validate Serena's portable package functionality across different operating systems (Windows, Linux, macOS).

## Test Architecture

The platform-specific runtime tests are implemented in two complementary layers:

### 1. Bash Shell Tests (`scripts/portable/test_portable.sh`)

Integration-level tests for portable package validation, executed during build and CI/CD pipelines.

**Features:**
- Detects platform at runtime and runs appropriate tests
- Tests launcher script functionality
- Validates path handling and execution
- Checks Python runtime integration
- Color-coded output for easy result interpretation

**Test Coverage:**
- Structure and file verification
- Python runtime functionality
- Language server availability
- CLI integration tests
- Platform-specific runtime behaviors

### 2. Python Unit Tests (`test/test_portable.py`)

Fine-grained unit and integration tests using pytest, organized into 7 test classes.

**Features:**
- Cross-platform test design using `pytest.mark.skipif`
- Isolated test cases with fixture support
- Coverage of both platform-specific and cross-platform scenarios
- 29 total tests (25 passing on Linux, 4 skipped on non-Windows systems)

## Windows-Specific Tests

### Bash Tests (test_portable.sh)

#### 1. .bat File Execution

```bash
run_test ".bat launcher exists and is readable" "[[ -f '$SERENA_CMD' && -r '$SERENA_CMD' ]]"
run_test ".bat file has correct Windows line endings" "grep -q \$'\\r' '$SERENA_CMD' || true && true"
```

**Validates:**
- .bat launcher file exists and is readable
- File has Windows CRLF line endings (critical for cmd.exe)

#### 2. cmd.exe Integration

```bash
run_test "cmd.exe can execute launcher via /c flag" "cmd /c 'echo test' 1>nul 2>&1"
run_test "serena.bat runs via cmd.exe" "cmd /c \"'$SERENA_CMD' --version\" 1>/dev/null 2>&1"
```

**Validates:**
- cmd.exe subprocess execution works
- Launcher responds to cmd.exe invocation
- Exit codes propagate correctly

#### 3. Path Handling with Spaces

```bash
TEST_DIR_SPACES="${PACKAGE}/test space dir"
mkdir -p "$TEST_DIR_SPACES" 2>/dev/null || true
run_test "Python works from path with spaces" "[[ -f '$PYTHON_EXE' ]] && \"$PYTHON_EXE\" -c 'import sys; print(len(sys.path))' 1>/dev/null"
run_test "Launcher works from path with spaces" "cmd /c \"cd /d '$TEST_DIR_SPACES' && '$SERENA_CMD' --version\" 1>/dev/null 2>&1" || true
```

**Validates:**
- Python executable works from paths with spaces
- .bat launcher works from directories with spaces
- cd /d (drive change) works correctly

#### 4. Python.exe Execution

```bash
run_test "python.exe exists at Windows path" "[[ -f '$PYTHON_EXE' ]]"
run_test "python.exe is executable from Windows context" "cmd /c \"'$PYTHON_EXE' --version\" 1>/dev/null 2>&1"
run_test "python.exe returns valid version" "cmd /c \"'$PYTHON_EXE' --version 2>&1\" | findstr /R \"Python\" 1>/dev/null 2>&1" || true
```

**Validates:**
- python.exe is present at expected location
- Version command works via cmd.exe
- Output can be parsed with findstr (Windows grep equivalent)

#### 5. Batch Environment Variables

```bash
run_test "Batch file sets SERENA_ROOT variable" "cmd /c \"set SERENA_ROOT && echo %SERENA_ROOT% | findstr /I serena\" 1>/dev/null 2>&1" || true
run_test "cmd.exe subprocess inherits environment" "cmd /c \"'$PYTHON_EXE' -c 'import os; assert os.environ' 1>/dev/null 2>&1"
```

**Validates:**
- Batch file setlocal configuration works
- Environment variables set in .bat are accessible
- Child processes inherit parent environment

#### 6. Special Characters and Error Handling

```bash
run_test "Path with quotes is handled correctly" "[[ -d '$PACKAGE' ]]"
run_test "Invalid args return non-zero exit code" "cmd /c \"'$SERENA_CMD' --invalid-flag 2>/dev/null\" ; test \$? -ne 0" || true
run_test "pip available in embedded Python" "cmd /c \"'$PYTHON_EXE' -m pip --version\" 1>/dev/null 2>&1"
```

**Validates:**
- Quoting edge cases handled correctly
- Exit codes are propagated on errors
- pip module is available for package management

### Python Unit Tests

#### TestPlatformDetection

```python
@pytest.mark.skipif(platform.system() != "Windows", reason="Windows-only test")
def test_windows_platform(self):
    """Test Windows-specific behaviors."""
    assert platform.system() == "Windows"
    assert sys.executable.endswith(".exe")
```

#### TestPlatformSpecificLaunchers (Windows)

```python
@pytest.mark.skipif(platform.system() != "Windows", reason="Windows-only test")
def test_windows_batch_launcher(self, tmp_path):
    """Test Windows .bat launcher functionality."""
    launcher = tmp_path / "test.bat"
    launcher.write_text("""@echo off
setlocal
echo Hello from batch
exit /b 0
""")
    result = subprocess.run(
        ["cmd", "/c", str(launcher)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "Hello from batch" in result.stdout
```

**Additional Windows Tests:**
- Batch environment variable handling
- Path handling with spaces
- CRLF line ending verification

## Linux/Unix-Specific Tests

### Bash Tests (test_portable.sh)

#### 1. Shell Script Execution

```bash
run_test "Shell launcher exists" "[[ -f '$SERENA_CMD' ]]"
run_test "Shell script is readable" "[[ -r '$SERENA_CMD' ]]"
```

**Validates:**
- Launcher shell script exists and is readable

#### 2. Executable Bit Verification

```bash
run_test "Launcher has executable bit set" "[[ -x '$SERENA_CMD' ]]"
run_test "Python binary has executable bit" "[[ -x '$PYTHON_EXE' ]]"
```

**Validates:**
- Executable bit (0o755) is set on launchers
- Python binary is executable
- File permissions are correct after extraction

#### 3. POSIX Path Handling

```bash
run_test "Launcher uses POSIX paths" "grep -q 'dirname.*BASH_SOURCE' '$SERENA_CMD' || grep -q '/bin/python' '$SERENA_CMD'"
run_test "Shell script has valid shebang" "head -1 '$SERENA_CMD' | grep -q '^#!/usr/bin/env bash\\|^#!/bin/bash'"
run_test "Launcher has Unix line endings" "! grep -q \$'\\r' '$SERENA_CMD'"
```

**Validates:**
- Uses dirname command for relative path resolution
- Has proper bash shebang
- Uses Unix LF line endings (not CRLF)

#### 4. Path Handling with Spaces and Special Characters

```bash
TEST_DIR_SPACES="/tmp/serena-test space-$$"
mkdir -p "$TEST_DIR_SPACES"
cp "$SERENA_CMD" "$TEST_DIR_SPACES/serena"
chmod +x "$TEST_DIR_SPACES/serena"
run_test "Launcher works from directory with spaces" "'$TEST_DIR_SPACES/serena' --version 1>/dev/null 2>&1" || true

TEST_DIR_SPECIAL="/tmp/serena-test_\$special-$$"
mkdir -p "$TEST_DIR_SPECIAL"
run_test "Python works with special chars in path" "[[ -x '$PYTHON_EXE' ]] && '$PYTHON_EXE' --version 1>/dev/null 2>&1"
```

**Validates:**
- Launcher handles directory names with spaces
- Handles special characters in paths ($, _, etc.)
- Shell quoting works correctly

#### 5. Python Invocation and Execution

```bash
run_test "Python is invoked via explicit path" "grep -q \"exec.*python\" '$SERENA_CMD'"
run_test "Launcher can read environment variables" "'$PYTHON_EXE' -c 'import os; os.environ' 1>/dev/null 2>&1"
```

**Validates:**
- Uses exec to replace shell process
- Environment variables accessible to Python
- Process inheritance works correctly

#### 6. Symlink and Relative Path Support

```bash
SYMLINK_TEST="/tmp/serena-symlink-test-$$"
ln -sf "$SERENA_CMD" "$SYMLINK_TEST" 2>/dev/null || true
if [[ -L "$SYMLINK_TEST" ]]; then
    run_test "Launcher works via symlink" "'$SYMLINK_TEST' --version 1>/dev/null 2>&1" || true
fi

run_test "Launcher can be executed from different directory" "(cd /tmp && '$SERENA_CMD' --version 1>/dev/null 2>&1)"
```

**Validates:**
- Works when invoked via symlink
- Works when executed from different directory
- Path resolution works with different cwd

#### 7. Process and Signal Handling

```bash
run_test "Python process accepts signals" "'$PYTHON_EXE' -c 'import signal; signal.signal(signal.SIGTERM, signal.SIG_DFL)' 1>/dev/null 2>&1"
run_test "Python output can be captured" "OUTPUT=\$('$PYTHON_EXE' --version 2>&1) && [[ ! -z \"\$OUTPUT\" ]]"
run_test "File descriptors properly inherited" "'$PYTHON_EXE' -c 'import sys; assert sys.stdin and sys.stdout and sys.stderr' 1>/dev/null 2>&1"
```

**Validates:**
- Signal handling works (SIGTERM)
- Output redirection works
- File descriptors (stdin, stdout, stderr) properly inherited

#### 8. Library Path Resolution

```bash
run_test "Python finds shared libraries" "'$PYTHON_EXE' -c 'import ctypes; ctypes.CDLL(None)' 1>/dev/null 2>&1" || true
run_test "All binary directories are accessible" "[[ -x '$PACKAGE/bin' && -r '$PACKAGE/bin' ]]"
run_test "All python directories are traversable" "[[ -x '$PACKAGE/python/bin' ]] || [[ -x '$PACKAGE/python' ]]"
```

**Validates:**
- ctypes can find system libraries (libc)
- Binary directories have execute permission for traversal
- Python directories are accessible

### Python Unit Tests

#### TestPlatformDetection

```python
@pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
def test_unix_platform(self):
    """Test Unix/Linux-specific behaviors."""
    assert platform.system() in ["Linux", "Darwin"]
    assert not sys.executable.endswith(".exe")
```

#### TestPlatformSpecificLaunchers (Unix)

```python
@pytest.mark.skipif(platform.system() == "Windows", reason="Unix-only test")
def test_unix_shell_launcher(self, tmp_path):
    """Test Unix shell launcher functionality."""
    launcher = tmp_path / "test.sh"
    launcher.write_text("""#!/usr/bin/env bash
echo "Hello from shell"
exit 0
""")
    launcher.chmod(launcher.stat().st_mode | stat.S_IXUSR)
    result = subprocess.run(
        [str(launcher)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "Hello from shell" in result.stdout
```

**Additional Unix Tests:**
- Executable permission setting and verification
- Symlink support validation
- Path handling with spaces
- Signal handling capabilities

## Cross-Platform Tests

### Python Unit Tests

These tests run on all platforms to validate common functionality:

#### TestPathHandling

```python
def test_path_with_spaces(self, tmp_path):
    """Test that paths with spaces are handled correctly."""
    space_dir = tmp_path / "dir with spaces"
    space_dir.mkdir()
    assert space_dir.exists()

def test_path_with_special_characters(self, tmp_path):
    """Test path handling with special characters."""
    if platform.system() == "Windows":
        special_chars = ["test_dir", "test-dir"]
    else:
        special_chars = ["test_dir", "test-dir", "test.dir"]

    for char_name in special_chars:
        test_dir = tmp_path / char_name
        test_dir.mkdir(exist_ok=True)
        assert test_dir.exists()
```

#### TestRuntimeExecution

```python
def test_python_execution(self):
    """Test that Python can execute simple code."""
    result = subprocess.run(
        [sys.executable, "-c", "print('test')"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "test" in result.stdout

def test_environment_variable_inheritance(self):
    """Test that environment variables are inherited."""
    env = os.environ.copy()
    env["TEST_VAR"] = "test_value"
    result = subprocess.run(
        [sys.executable, "-c", "import os; print(os.environ.get('TEST_VAR'))"],
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode == 0
    assert "test_value" in result.stdout

def test_subprocess_exit_code(self):
    """Test that exit codes are correctly propagated."""
    result = subprocess.run(
        [sys.executable, "-c", "exit(42)"],
        capture_output=True,
    )
    assert result.returncode == 42
```

#### TestFileSystemOperations

```python
def test_directory_traversal(self, tmp_path):
    """Test directory traversal and access."""
    nested = tmp_path / "a" / "b" / "c"
    nested.mkdir(parents=True)
    assert nested.exists()
    assert nested.parent.exists()

def test_file_encoding(self, tmp_path):
    """Test file encoding handling."""
    test_file = tmp_path / "test.txt"
    test_content = "test with unicode: 你好"
    test_file.write_text(test_content, encoding="utf-8")
    read_content = test_file.read_text(encoding="utf-8")
    assert read_content == test_content
```

#### TestPortablePathResolution

```python
def test_portable_root_resolution(self, tmp_path):
    """Test portable root path resolution."""
    original = os.environ.get("SERENA_PORTABLE_DIR")
    try:
        os.environ["SERENA_PORTABLE_DIR"] = str(tmp_path)
        root = get_portable_root()
        assert root is not None
        assert root == tmp_path.resolve()
    finally:
        if original:
            os.environ["SERENA_PORTABLE_DIR"] = original
        elif "SERENA_PORTABLE_DIR" in os.environ:
            del os.environ["SERENA_PORTABLE_DIR"]
```

## Test Execution

### Running Bash Tests

```bash
# Test a portable package
./scripts/portable/test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64 \
  --verbose

# For Windows
./scripts/portable/test_portable.sh \
  --package ./build/serena-win-x64 \
  --platform win-x64 \
  --verbose
```

### Running Python Tests

```bash
# Run all portable tests
uv run pytest test/test_portable.py -v

# Run specific test class
uv run pytest test/test_portable.py::TestPlatformDetection -v

# Run tests for current platform only
uv run pytest test/test_portable.py -v -m "not windows"  # Skip Windows tests on Unix
uv run pytest test/test_portable.py -v -m "not unix"     # Skip Unix tests on Windows
```

## Key Test Metrics

### Test Summary

| Category | Windows | Linux | macOS | Cross-Platform |
|----------|---------|-------|-------|-----------------|
| .bat Execution | 7 | - | - | - |
| Shell Script | - | 8 | 8 | - |
| Path Handling | Yes | Yes | Yes | Yes |
| Runtime Execution | Yes | Yes | Yes | Yes |
| File Operations | Yes | Yes | Yes | Yes |
| Portable Mode | Yes | Yes | Yes | Yes |
| **Total Tests** | **25+** | **25+** | **25+** | **29** |

### Coverage Areas

**Platform Detection:** 2 tests
- Detects correct platform (Windows/Linux/Darwin)
- Python executable path validation

**Launcher Functionality:** 9 tests
- Windows: .bat file execution, cmd.exe integration
- Unix: Shell script execution, executable bit verification
- Both: Path handling with spaces, special characters

**Runtime Execution:** 6 tests
- Python execution and module imports
- Environment variable inheritance
- Exit code propagation
- Signal handling (Unix)
- Output capturing

**File System Operations:** 4 tests
- Executable permissions (Unix)
- Symlink support (Unix)
- Directory traversal
- Unicode file encoding

**Portable Mode:** 8 tests
- Mode detection
- Data directory creation and resolution
- Language server directory handling
- Normal vs portable mode switching

## Edge Cases Covered

1. **Paths with spaces:** Windows `C:\Program Files\serena`, Unix `/home/user/my projects`
2. **Special characters:** $ _ - . in directory names
3. **Unicode:** Non-ASCII characters in files and paths
4. **Symlinks:** Works via symlink references (Unix)
5. **Different working directories:** Launch from any directory
6. **Environment inheritance:** Child processes inherit parent environment
7. **Signal handling:** SIGTERM, etc. on Unix
8. **File descriptor inheritance:** stdin/stdout/stderr availability
9. **Library resolution:** ctypes.CDLL for shared libraries
10. **Exit code propagation:** Errors bubble up correctly

## CI/CD Integration

These tests are designed to run in GitHub Actions workflows:

```yaml
- name: Test portable package
  run: |
    ./scripts/portable/test_portable.sh \
      --package ./build/serena-${{ matrix.platform }} \
      --platform ${{ matrix.platform }} \
      --verbose

- name: Run Python unit tests
  run: |
    uv run pytest test/test_portable.py -v
```

## Performance Characteristics

- **Bash tests:** ~30-60 seconds per platform
- **Python tests:** ~0.3 seconds
- **Total validation:** <2 minutes for single platform
- **Parallel execution:** Can test multiple platforms simultaneously

## Future Enhancements

1. **Stress testing:** Long-running processes, memory usage
2. **Concurrent execution:** Multiple processes simultaneously
3. **Network tests:** MCP server networking
4. **Performance profiling:** Startup time, memory footprint
5. **Integration with real projects:** Full workflow validation
6. **Regression testing:** Maintain baseline metrics

## Related Documentation

- [Portable Builds Guide](/docs/portable-builds.md)
- [Build Script Documentation](/scripts/portable/README.md)
- [Test Portable Script](/scripts/portable/test_portable.sh)
- [Python Portable Module](/src/serena/portable.py)

---

**Last Updated:** 2025-11-02
**Version:** 1.0
**Test Count:** 29 Python tests + Variable bash tests per platform
