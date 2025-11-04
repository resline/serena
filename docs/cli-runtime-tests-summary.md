# CLI Runtime Tests - Executive Summary

## Overview

This comprehensive test suite design provides safe, non-destructive CLI runtime tests for verifying Serena portable builds. The tests verify actual command execution and functionality, not just file existence, while maintaining strict safety constraints and cross-platform compatibility.

## Key Deliverables

### 1. **Design Document** - `/root/repo/docs/cli-runtime-tests-design.md`
Comprehensive design outlining:
- Test principles and philosophy
- 10 specific test cases across 3 categories
- Detailed success criteria for each test
- Platform-specific considerations
- Safety guarantees and timeout protection
- Integration guidance

### 2. **Implementation Library** - `/root/repo/scripts/portable/cli-runtime-tests.sh`
Reusable Bash library providing:
- Test functions for all 10 test cases
- Automatic platform detection (Windows/Unix)
- Helper functions for environment validation
- Logging and reporting utilities
- Export functions for sourcing in other scripts

### 3. **Integration Guide** - `/root/repo/docs/cli-runtime-tests-integration.md`
Practical integration instructions including:
- Quick integration steps (2 lines of code)
- Complete example showing full integration
- Customization options
- Troubleshooting guide
- CI/CD examples
- Performance optimization tips

### 4. **Detailed Specifications** - `/root/repo/docs/cli-runtime-tests-specs.md`
Precise test specifications with:
- Test identifier and purpose for each test
- Exact command execution steps
- Success/failure criteria with regex patterns
- Expected output format and examples
- Platform-specific notes
- Performance thresholds
- Debugging guidance
- Test execution matrix

---

## Test Categories Summary

### Category 1: Help Commands (3 tests)
Verify CLI launcher functionality and basic accessibility.

| Test | Command | Duration | Timeout |
|------|---------|----------|---------|
| Serena --help | `serena --help` | 0.5-1s | 5s |
| MCP Server --help | `serena-mcp-server --help` | 1-2s | 5s |
| Version Output | `serena --version` | 0.5-1s | 5s |

**Purpose**: Fastest, most basic verification of command entry points

### Category 2: List Commands (4 tests)
Verify configuration system and tool registry discovery.

| Test | Command | Duration | Timeout |
|------|---------|----------|---------|
| Mode List | `mode list` | 2-3s | 10s |
| Context List | `context list` | 2-3s | 10s |
| Tools List (quiet) | `tools list --quiet` | 3-5s | 10s |
| Tools List (all) | `tools list --all` | 3-5s | 10s |

**Purpose**: Verify configuration loading and registry initialization

### Category 3: Tool Description (3 tests)
Verify agent initialization and tool metadata retrieval.

| Test | Command | Duration | Timeout |
|------|---------|----------|---------|
| Find Symbol Description | `tools description find_symbol` | 4-6s | 10s |
| Activate Project Description | `tools description activate_project` | 4-6s | 10s |
| Context-Aware Description | `tools description --context agent` | 4-6s | 10s |

**Purpose**: Comprehensive system verification including LSP initialization

---

## Safety Guarantees

All tests are designed with strict safety constraints:

### No Side Effects
- No files created or modified
- No network access required
- No external tool dependencies
- No system configuration changes
- No state modifications

### Failure Isolation
- Timeouts prevent hangs (5-10 seconds per test)
- Error handling captures output without side effects
- Temporary files cleaned up automatically
- No impact on system if tests fail

### Platform Independence
- Works on Linux, macOS, and Windows
- Auto-detects platform and adjusts commands
- Uses cross-platform timeout mechanisms
- Handles path separators appropriately

---

## Integration Checklist

To add CLI runtime tests to your portable build testing:

1. **Copy implementation file**
   ```bash
   cp scripts/portable/cli-runtime-tests.sh scripts/portable/
   ```

2. **Source the library** in `test_portable.sh`
   ```bash
   source "$SCRIPT_DIR/cli-runtime-tests.sh"
   ```

3. **Add test execution** after Python tests
   ```bash
   if [[ "$PLATFORM" == win-* ]]; then
       test_cli_suite_windows
   else
       test_cli_suite
   fi
   ```

4. **Done!** Tests will automatically run with proper platform detection

---

## Expected Test Coverage

### What Gets Tested

| Component | Test | Verification |
|-----------|------|--------------|
| CLI Entry Points | Help commands | Launcher scripts are functional |
| Python Installation | Help commands | Python runtime works |
| Module Imports | List commands | All dependencies installed |
| Configuration System | List commands | Config files properly set up |
| Tool Registry | List commands | Tools are registered |
| Agent Initialization | Description commands | Full system initialization works |
| LSP Integration | Description commands | Language servers accessible |
| Output Formatting | All commands | Output is properly formatted |

### What Is NOT Tested

- Actual symbol finding (requires project)
- File modifications (no project)
- Network operations (no external deps)
- Language server operation (only discovery)
- Full MCP server startup (no client needed)

---

## Performance Characteristics

### Individual Test Performance

**Fast Tests** (< 2s):
- Serena --help
- Serena --version

**Medium Tests** (2-5s):
- Mode/Context/Tools list commands

**Slow Tests** (4-8s):
- Tool descriptions (require agent init)

### Total Suite Duration

| Scenario | Duration |
|----------|----------|
| All tests pass (no timeouts) | 30-40 seconds |
| One test times out | 40-50 seconds |
| Multiple timeouts | 60+ seconds |

### Optimization Tips

1. Pre-warm Python environment
2. Run in parallel (with result aggregation)
3. Skip slow tests during development
4. Cache LSP downloads

---

## Example Usage

### In CI/CD Pipeline

```yaml
- name: Test Portable Package
  run: |
    ./scripts/portable/test_portable.sh \
      --package ./serena-build \
      --platform linux-x64 \
      --verbose
  timeout-minutes: 5
```

### Local Testing

```bash
# Extract portable build
tar -xzf serena-linux-x64-v0.1.4.tar.gz
cd serena-linux-x64

# Run all tests including CLI tests
../scripts/portable/test_portable.sh \
  --package . \
  --platform linux-x64 \
  --verbose
```

### Skip CLI Tests

```bash
# Bash
SKIP_CLI_TESTS=true ./test_portable.sh --package . --platform linux-x64

# Windows
set SKIP_CLI_TESTS=true
test_portable.bat --package . --platform win-x64
```

---

## Debugging

### View Full Output

```bash
# Run with verbose flag
./test_portable.sh --package ./build --verbose

# Or capture to file
./test_portable.sh --package ./build > test_results.txt 2>&1
```

### Run Single Test

```bash
# Source the library
source ./scripts/portable/cli-runtime-tests.sh

# Set variables
SERENA_CMD="./bin/serena"
MCP_CMD="./bin/serena-mcp-server"
PYTHON_EXE="./python/bin/python3"

# Run specific test
run_test "Serena help" \
  "timeout 5 '$SERENA_CMD' --help"
```

### Test Individual Commands

```bash
# Manual execution
./bin/serena --help
./bin/serena mode list
./python/bin/python3 -m serena.cli tools description find_symbol
```

---

## Documentation Files

| File | Purpose |
|------|---------|
| `cli-runtime-tests-design.md` | Architecture and high-level design |
| `cli-runtime-tests-specs.md` | Detailed test specifications |
| `cli-runtime-tests-integration.md` | Integration instructions and examples |
| `cli-runtime-tests.sh` | Reusable test library |
| `cli-runtime-tests-summary.md` | This file (executive summary) |

---

## Key Features

### Comprehensive Coverage
- 10 tests across 3 categories
- Tests actual command execution
- Validates output format and content
- Platform-aware test variants

### Safety First
- Non-destructive operations
- Timeout protection
- No external dependencies
- Isolated test execution

### Easy Integration
- Drop-in library design
- 2-line integration
- Automatic platform detection
- Compatible with existing test_portable.sh

### Production Ready
- Detailed specifications
- Error handling
- Performance metrics
- Troubleshooting guides

### Well Documented
- Design rationale
- Test specifications
- Integration examples
- Debugging tips

---

## Next Steps

1. **Review Design**
   - Read `cli-runtime-tests-design.md`
   - Understand test philosophy and approach

2. **Integrate Library**
   - Copy `cli-runtime-tests.sh` to `scripts/portable/`
   - Source in `test_portable.sh`
   - Add test execution call

3. **Test Integration**
   - Build portable package
   - Run with new CLI tests
   - Verify output format

4. **Optimize**
   - Adjust timeouts if needed
   - Pre-warm Python if necessary
   - Profile slow tests

5. **Deploy**
   - Add to CI/CD pipeline
   - Update build documentation
   - Monitor test results

---

## Future Enhancements

### Potential Improvements

1. **Extended Tool Testing**
   - Test with actual project files
   - Verify symbol finding works
   - Integration with test projects

2. **Performance Benchmarking**
   - Track execution times per test
   - Identify regressions
   - Alert on slowdowns

3. **Output Validation**
   - Schema validation for JSON output
   - Format consistency checks
   - Cross-platform output comparison

4. **Context/Mode Testing**
   - Test context switching
   - Verify mode activation
   - Test tool availability in contexts

5. **Project Configuration**
   - Generate test project.yml
   - Verify project activation
   - Test project-specific features

---

## Support and Issues

### Common Issues

**Tests timeout frequently**
- Increase timeout values
- Pre-warm Python environment
- Profile slow operations

**Platform detection fails**
- Ensure PLATFORM variable is set
- Check for win-* prefix on Windows
- Verify shell environment

**Commands not found**
- Verify SERENA_CMD/MCP_CMD paths
- Check file permissions
- Ensure launchers exist

### Getting Help

1. Check `cli-runtime-tests-integration.md` troubleshooting section
2. Review test output with `--verbose` flag
3. Run individual tests manually
4. Check `cli-runtime-tests-specs.md` for expected behavior

---

## Conclusion

This comprehensive CLI runtime test suite provides:
- **Safety**: Non-destructive, isolated test execution
- **Coverage**: 10 tests across 3 categories
- **Reliability**: Platform-aware, timeout-protected
- **Ease**: 2-line integration, minimal setup
- **Clarity**: Extensive documentation and specifications

The tests verify actual command execution and system functionality, ensuring portable builds are production-ready while maintaining strict safety constraints and requiring no external dependencies.

For detailed information, see:
- Design: `cli-runtime-tests-design.md`
- Specs: `cli-runtime-tests-specs.md`
- Integration: `cli-runtime-tests-integration.md`
