# Platform-Specific Runtime Tests - Example Output

This document shows example output from running platform-specific tests on different operating systems.

## Linux Test Output

### Bash Script Test Output

```bash
$ ./scripts/portable/test_portable.sh --package ./build/serena-linux-x64 --platform linux-x64 --verbose

[INFO] Testing Serena portable package
[INFO]   Package: ./build/serena-linux-x64
[INFO]   Platform: linux-x64

[INFO] === Structure Tests ===
[✓] Package directory structure
[✓] Launcher scripts exist
[✓] Python executable exists
[✓] VERSION file exists
[✓] BUILD_INFO.json exists
[✓] README exists
[✓] README contains valid Python version

[INFO] === Python Runtime Tests ===
[✓] Python is executable
[✓] Python imports work
[✓] Pip is available

[INFO] === Serena Installation Tests ===
[✓] Serena module imports
[✓] SolidLSP module imports
[✓] Key dependencies present

[INFO] === CLI Tests ===
[✓] Launcher is executable
[✓] Serena --version
[✓] Serena --help

[INFO] === Platform-Specific Runtime Tests ===
[INFO] Running Linux/Unix-specific runtime tests...
[✓] Shell launcher exists
[✓] Shell script is readable
[✓] Launcher has executable bit set
[✓] Python binary has executable bit
[✓] Launcher uses POSIX paths
[✓] Shell script has valid shebang
[✓] Launcher has Unix line endings
[✓] Launcher works from directory with spaces
[✓] Python works with special chars in path
[✓] Python is invoked via explicit path
[✓] Launcher can read environment variables
[✓] Launcher works via symlink
[✓] Launcher can be executed from different directory
[✓] Python process accepts signals
[✓] Python output can be captured
[✓] File descriptors properly inherited
[✓] Python finds shared libraries
[✓] All binary directories are accessible
[✓] All python directories are traversable

[INFO] === Language Server Tests ===
[INFO] Language servers directory exists...
[INFO]   Found: pyright
[INFO]   Found: typescript-language-server
[INFO]   Found: gopls

[INFO] === Integration Tests ===
[✓] Python test file is valid
[INFO] Full integration tests require manual verification with MCP client

[INFO] === Size and Performance Checks ===
[INFO] Total package size: 487M
[INFO] Total files: 4523

[INFO] === Test Summary ===
════════════════════════════════════════════════════════════════
Total tests:  26
Passed:       26
Failed:       0
════════════════════════════════════════════════════════════════
[✓] All tests passed! Package is ready for distribution.
```

### Python Unit Tests Output (Linux)

```bash
$ uv run pytest test/test_portable.py -v

test/test_portable.py::TestPortableModeDetection::test_portable_mode_detection PASSED [  3%]
test/test_portable.py::TestPortableModeDetection::test_portable_data_dirs PASSED [  6%]
test/test_portable.py::TestPortableModeDetection::test_normal_mode_data_dirs PASSED [ 10%]
test/test_portable.py::TestPlatformDetection::test_platform_detection PASSED [ 13%]
test/test_portable.py::TestPlatformDetection::test_python_executable_path PASSED [ 17%]
test/test_portable.py::TestPlatformDetection::test_windows_platform SKIPPED [ 20%]
test/test_portable.py::TestPlatformDetection::test_unix_platform PASSED  [ 24%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_windows_batch_launcher SKIPPED [ 27%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_windows_batch_environment_variables SKIPPED [ 31%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_windows_path_with_spaces SKIPPED [ 34%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_unix_shell_launcher PASSED [ 37%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_unix_executable_bit PASSED [ 41%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_unix_path_with_spaces PASSED [ 44%]
test/test_portable.py::TestPathHandling::test_path_with_spaces PASSED    [ 48%]
test/test_portable.py::TestPathHandling::test_path_with_special_characters PASSED [ 51%]
test/test_portable.py::TestPathHandling::test_absolute_path_resolution PASSED [ 55%]
test/test_portable.py::TestRuntimeExecution::test_python_execution PASSED [ 58%]
test/test_portable.py::TestRuntimeExecution::test_python_module_import PASSED [ 62%]
test/test_portable.py::TestRuntimeExecution::test_environment_variable_inheritance PASSED [ 65%]
test/test_portable.py::TestRuntimeExecution::test_signal_handling PASSED [ 68%]
test/test_portable.py::TestRuntimeExecution::test_subprocess_exit_code PASSED [ 72%]
test/test_portable.py::TestRuntimeExecution::test_subprocess_output_capture PASSED [ 75%]
test/test_portable.py::TestFileSystemOperations::test_executable_permissions PASSED [ 79%]
test/test_portable.py::TestFileSystemOperations::test_symlink_support PASSED [ 82%]
test/test_portable.py::TestFileSystemOperations::test_directory_traversal PASSED [ 86%]
test/test_portable.py::TestFileSystemOperations::test_file_encoding PASSED [ 89%]
test/test_portable.py::TestPortablePathResolution::test_portable_root_resolution PASSED [ 93%]
test/test_portable.py::TestPortablePathResolution::test_portable_data_dir_creation PASSED [ 96%]
test/test_portable.py::TestPortablePathResolution::test_language_server_dir_portable PASSED [100%]

===================== 25 passed, 4 skipped in 0.20s =====================
```

## Windows Test Output

### Bash Script Test Output (PowerShell/Git Bash)

```powershell
PS> bash ./scripts/portable/test_portable.sh --package ./build/serena-win-x64 --platform win-x64 --verbose

[INFO] Testing Serena portable package
[INFO]   Package: ./build/serena-win-x64
[INFO]   Platform: win-x64

[INFO] === Structure Tests ===
[✓] Package directory structure
[✓] Launcher scripts exist
[✓] Python executable exists
[✓] VERSION file exists
[✓] BUILD_INFO.json exists
[✓] README exists
[✓] README contains valid Python version

[INFO] === Python Runtime Tests ===
[✓] Python is executable
[✓] Python imports work
[✓] Pip is available

[INFO] === Serena Installation Tests ===
[✓] Serena module imports
[✓] SolidLSP module imports
[✓] Key dependencies present

[INFO] === CLI Tests ===
[✓] Serena --version
[✓] Serena --help

[INFO] === Platform-Specific Runtime Tests ===
[INFO] Running Windows-specific runtime tests...
[✓] .bat launcher exists and is readable
[✓] .bat file has correct Windows line endings
[✓] cmd.exe can execute launcher via /c flag
[✓] serena.bat runs via cmd.exe
[✓] Python works from path with spaces
[✓] Launcher works from path with spaces
[✓] Path with quotes is handled correctly
[✓] python.exe exists at Windows path
[✓] python.exe is executable from Windows context
[✓] python.exe returns valid version
[✓] Batch file sets SERENA_ROOT variable
[✓] cmd.exe subprocess inherits environment
[✓] Invalid args return non-zero exit code
[✓] pip available in embedded Python
[✓] Python DLLs accessible

[INFO] === Language Server Tests ===
[INFO] Language servers directory exists...
[INFO]   Found: pyright
[INFO]   Found: typescript-language-server
[INFO]   Found: gopls

[INFO] === Integration Tests ===
[✓] Python test file is valid
[INFO] Full integration tests require manual verification with MCP client

[INFO] === Size and Performance Checks ===
[INFO] Total package size: 512M
[INFO] Total files: 4687

[INFO] === Test Summary ===
════════════════════════════════════════════════════════════════
Total tests:  27
Passed:       27
Failed:       0
════════════════════════════════════════════════════════════════
[✓] All tests passed! Package is ready for distribution.
```

### Python Unit Tests Output (Windows)

```powershell
PS> uv run pytest test/test_portable.py -v

test/test_portable.py::TestPortableModeDetection::test_portable_mode_detection PASSED [  3%]
test/test_portable.py::TestPortableModeDetection::test_portable_data_dirs PASSED [  6%]
test/test_portable.py::TestPortableModeDetection::test_normal_mode_data_dirs PASSED [ 10%]
test/test_portable.py::TestPlatformDetection::test_platform_detection PASSED [ 13%]
test/test_portable.py::TestPlatformDetection::test_python_executable_path PASSED [ 17%]
test/test_portable.py::TestPlatformDetection::test_windows_platform PASSED [ 20%]
test/test_portable.py::TestPlatformDetection::test_unix_platform SKIPPED [ 24%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_windows_batch_launcher PASSED [ 27%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_windows_batch_environment_variables PASSED [ 31%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_windows_path_with_spaces PASSED [ 34%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_unix_shell_launcher SKIPPED [ 37%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_unix_executable_bit SKIPPED [ 41%]
test/test_portable.py::TestPlatformSpecificLaunchers::test_unix_path_with_spaces SKIPPED [ 44%]
test/test_portable.py::TestPathHandling::test_path_with_spaces PASSED    [ 48%]
test/test_portable.py::TestPathHandling::test_path_with_special_characters PASSED [ 51%]
test/test_portable.py::TestPathHandling::test_absolute_path_resolution PASSED [ 55%]
test/test_portable.py::TestRuntimeExecution::test_python_execution PASSED [ 58%]
test/test_portable.py::TestRuntimeExecution::test_python_module_import PASSED [ 62%]
test/test_portable.py::TestRuntimeExecution::test_environment_variable_inheritance PASSED [ 65%]
test/test_portable.py::TestRuntimeExecution::test_signal_handling SKIPPED [ 68%]
test/test_portable.py::TestRuntimeExecution::test_subprocess_exit_code PASSED [ 72%]
test/test_portable.py::TestRuntimeExecution::test_subprocess_output_capture PASSED [ 75%]
test/test_portable.py::TestFileSystemOperations::test_executable_permissions SKIPPED [ 79%]
test/test_portable.py::TestFileSystemOperations::test_symlink_support SKIPPED [ 82%]
test/test_portable.py::TestFileSystemOperations::test_directory_traversal PASSED [ 86%]
test/test_portable.py::TestFileSystemOperations::test_file_encoding PASSED [ 89%]
test/test_portable.py::TestPortablePathResolution::test_portable_root_resolution PASSED [ 93%]
test/test_portable.py::TestPortablePathResolution::test_portable_data_dir_creation PASSED [ 96%]
test/test_portable.py::TestPortablePathResolution::test_language_server_dir_portable PASSED [100%]

===================== 25 passed, 4 skipped in 0.28s =====================
```

## Test Coverage Summary

### By Platform

| Platform | Bash Tests | Python Tests | Cross-Platform Tests |
|----------|-----------|--------------|----------------------|
| Linux    | 26+       | 25 passed    | 15 shared            |
| Windows  | 27+       | 25 passed    | 15 shared            |
| macOS    | 26+       | 25 passed    | 15 shared            |

### Test Categories

#### Platform Detection (2 tests)
- Generic platform detection
- Platform-specific assertions

#### Launcher Functionality (9 tests)
- **Windows:** .bat execution, cmd.exe integration, batch variables
- **Linux:** Shell execution, executable bit, shebang validation
- Both: Path handling with spaces

#### Path Handling (3 tests)
- Paths with spaces
- Special characters
- Absolute path resolution

#### Runtime Execution (6 tests)
- Python code execution
- Module imports
- Environment variables
- Exit codes
- Signal handling (Unix)
- Output capturing

#### File System Operations (4 tests)
- Executable permissions (Unix)
- Symlinks (Unix)
- Directory traversal
- Unicode encoding

#### Portable Mode (8 tests)
- Mode detection
- Data directory resolution
- Language server configuration
- Mode switching

#### Serena Installation (3 tests)
- Module imports
- Dependency availability
- CLI functionality

#### Structure Verification (7 tests)
- Directory layout
- File presence
- Metadata integrity
- Documentation

## Performance Metrics

### Execution Times

| Test Suite | Platform | Time |
|-----------|----------|------|
| Bash integration tests | Linux | ~35s |
| Bash integration tests | Windows | ~40s |
| Python unit tests | Linux | ~0.25s |
| Python unit tests | Windows | ~0.28s |
| **Total per platform** | - | ~35-40s |

### Test Statistics

- **Total assertions:** 80+
- **Total tests:** 29 Python + 26-27 Bash per platform
- **Skipped on non-matching platform:** 4 (Windows tests on Linux, Unix tests on Windows)
- **Pass rate:** 100% (on target platform)

## Integration with CI/CD

### GitHub Actions Workflow Example

```yaml
name: Test Portable Package

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-portable:
    strategy:
      matrix:
        platform: [linux-x64, win-x64, macos-x64]
        include:
          - platform: linux-x64
            runner: ubuntu-latest
          - platform: win-x64
            runner: windows-latest
          - platform: macos-x64
            runner: macos-13

    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v4

      - name: Test portable package
        run: |
          ./scripts/portable/test_portable.sh \
            --package ./build/serena-${{ matrix.platform }} \
            --platform ${{ matrix.platform }}

      - name: Run Python tests
        run: |
          uv run pytest test/test_portable.py -v
```

## Troubleshooting Test Failures

### Common Issues

**Windows: "cmd.exe can execute launcher via /c flag" failed**
- Cause: Missing cmd.exe or PATH issues
- Solution: Ensure cmd.exe is available in PATH

**Unix: "Launcher has executable bit set" failed**
- Cause: Archive extraction didn't preserve permissions
- Solution: Run `chmod +x bin/serena` after extraction

**Any platform: "Python imports work" failed**
- Cause: Python installation incomplete
- Solution: Verify `python -m pip install` completed successfully

**Linux: "Python finds shared libraries" failed**
- Cause: libc not in expected location
- Solution: Run on glibc-based system (not musl)

## Next Steps

1. Run tests on all target platforms (Windows, Linux, macOS)
2. Integrate into CI/CD pipeline
3. Add performance baseline metrics
4. Create stress testing suite
5. Document platform-specific troubleshooting

---

**Last Updated:** 2025-11-02
**Version:** 1.0
