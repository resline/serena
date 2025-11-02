# CLI Runtime Tests Integration Guide

## Overview

This guide explains how to integrate the CLI runtime test suite into `test_portable.sh`.

## Quick Integration

### Step 1: Source the CLI Tests Module

Add this near the top of `test_portable.sh`, after variable definitions:

```bash
# Source CLI runtime tests
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cli-runtime-tests.sh"
```

### Step 2: Add Test Execution Section

Add this section in the test execution area (suggested location: after Python runtime tests):

```bash
echo ""
log_info "=== CLI Runtime Tests ==="

# Validate CLI environment before running tests
if validate_cli_environment; then
    # Determine if running on Windows or Unix-like system
    if [[ "$PLATFORM" == win-* ]]; then
        test_cli_suite_windows
    else
        test_cli_suite
    fi
    print_cli_test_summary
else
    log_warn "CLI environment validation failed, skipping CLI tests"
fi
```

## Complete Integration Example

Here's how the CLI test section fits into the overall `test_portable.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

# ... existing setup code ...

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; return 1; }

run_test() {
    local test_name="$1"
    local test_cmd="$2"

    ((TESTS_TOTAL++))
    log_info "Test: $test_name"

    if [[ "$VERBOSE" == "true" ]]; then
        echo "  Command: $test_cmd"
    fi

    if eval "$test_cmd" > /tmp/test_output_$$ 2>&1; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        [[ "$VERBOSE" == "true" ]] && cat /tmp/test_output_$$
        rm -f /tmp/test_output_$$
        return 0
    else
        log_error "$test_name"
        ((TESTS_FAILED++))
        echo "Output:"
        cat /tmp/test_output_$$
        rm -f /tmp/test_output_$$
        return 1
    fi
}

# Source CLI runtime tests module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cli-runtime-tests.sh"

# ... rest of setup ...

echo ""
log_info "=== Structure Tests ==="

set +e

# ... existing structure tests ...

echo ""
log_info "=== Python Runtime Tests ==="

# ... existing python tests ...

# NEW: CLI Runtime Tests Section
echo ""
log_info "=== CLI Runtime Tests ==="

if validate_cli_environment; then
    if [[ "$PLATFORM" == win-* ]]; then
        test_cli_suite_windows
    else
        test_cli_suite
    fi
    print_cli_test_summary
else
    log_warn "CLI environment validation failed, skipping CLI tests"
fi

# ... rest of tests ...

echo ""
log_info "=== Test Summary ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total tests:  $TESTS_TOTAL"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
else
    echo "Failed:       $TESTS_FAILED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_success "All tests passed!"
    exit 0
else
    log_error "Some tests failed."
    exit 1
fi
```

## Customization

### Running Only Specific Test Categories

If you want to run only certain categories:

```bash
# Only help commands
test_help_commands

# Only list commands
test_list_commands

# Only tool descriptions
test_tool_description_commands
```

### Skipping CLI Tests

To skip CLI tests (e.g., for faster builds):

```bash
echo ""
log_info "=== CLI Runtime Tests ==="

if [[ "${SKIP_CLI_TESTS:-false}" == "true" ]]; then
    log_warn "Skipping CLI tests (SKIP_CLI_TESTS=true)"
else
    if validate_cli_environment; then
        if [[ "$PLATFORM" == win-* ]]; then
            test_cli_suite_windows
        else
            test_cli_suite
        fi
    else
        log_warn "CLI environment validation failed"
    fi
fi
```

### Adjusting Timeouts

To use different timeout values, modify the function directly or create a wrapper:

```bash
# In test_portable.sh after sourcing cli-runtime-tests.sh

# Override with longer timeouts (useful for slower systems)
export SERENA_CLI_TIMEOUT=15
export MCP_CLI_TIMEOUT=15
export TOOL_CLI_TIMEOUT=15
```

Then modify `cli-runtime-tests.sh` to use these variables:

```bash
timeout ${SERENA_CLI_TIMEOUT:-5} "$SERENA_CMD" --help
```

## Expected Test Output

### Successful Run

```
[INFO] === CLI Runtime Tests ===
[INFO] Test: Serena help command
[✓] Serena help command
[INFO] Test: MCP server help command
[✓] MCP server help command
[INFO] Test: Serena version output
[✓] Serena version output
[INFO] Test: Mode list command
[✓] Mode list command
[INFO] Test: Context list command
[✓] Context list command
[INFO] Test: Tools list command
[✓] Tools list command
[INFO] Test: Tools list with all tools
[✓] Tools list with all tools
[INFO] Test: Tool description for find_symbol
[✓] Tool description for find_symbol
[INFO] Test: Tool description for activate_project
[✓] Tool description for activate_project
[INFO] Test: Tool description with context parameter
[✓] Tool description with context parameter
[INFO] === CLI Test Summary ===
CLI tests provide verification of:
  - Command entry points are accessible
  - Help system is functional
  - Configuration system is initialized
  - Tool registry is operational
  - Output formatting is correct
  - No external dependencies required

[INFO] All CLI tests completed successfully
```

### Failed Test Example

```
[INFO] Test: Serena help command
[✗] Serena help command
Output:
/bin/bash: /path/to/serena: No such file or directory
```

## Troubleshooting

### Issue: "SERENA_CMD not set"

**Cause**: `cli-runtime-tests.sh` was sourced before `SERENA_CMD` was defined.

**Solution**: Source the module after setting command variables:

```bash
# Set command variables
SERENA_CMD="$PACKAGE/bin/serena"
MCP_CMD="$PACKAGE/bin/serena-mcp-server"
PYTHON_EXE="$PACKAGE/python/bin/python3"

# Then source the module
source "$SCRIPT_DIR/cli-runtime-tests.sh"
```

### Issue: Tests timeout frequently

**Cause**: System is slow or Python modules are being compiled on first run.

**Solution**: Increase timeout values or pre-warm the Python environment:

```bash
# Pre-warm Python and import key modules
log_info "Pre-warming Python environment..."
timeout 30 "$PYTHON_EXE" -c "import serena; import solidlsp" 2>&1 || true

# Now run tests with default timeouts
test_cli_suite
```

### Issue: Windows tests fail with "findstr" not found

**Cause**: Running on a non-Windows system or `cmd.exe` not available.

**Solution**: Ensure `PLATFORM` variable is correctly set and you're on Windows:

```bash
if [[ "$PLATFORM" == win-* ]]; then
    test_cli_suite_windows
else
    test_cli_suite
fi
```

### Issue: "grep: command not found" on Windows

**Cause**: Using Unix test functions on Windows without proper shell.

**Solution**: Either use `test_cli_suite_windows` or ensure grep is available:

```bash
# In test_portable.sh
if command -v grep &> /dev/null; then
    test_cli_suite
else
    test_cli_suite_windows
fi
```

## Advanced Configuration

### Custom Test Function

Create custom test functions based on the template:

```bash
test_custom_command() {
    echo ""
    log_info "=== Custom CLI Tests ==="

    # Test pattern: timeout + command + grep validation
    run_test "My custom test" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli my_command 2>&1 | \
         grep -q 'expected output'"
}
```

### Conditional Test Execution

Run different tests based on configuration:

```bash
echo ""
log_info "=== CLI Runtime Tests ==="

if validate_cli_environment; then
    if [[ "$PLATFORM" == win-* ]]; then
        test_cli_suite_windows
    else
        test_cli_suite
    fi

    # Run additional tests only for standard language set
    if [[ "${LANGUAGE_SET:-standard}" == "standard" ]]; then
        test_custom_command
    fi

    print_cli_test_summary
else
    log_warn "CLI environment validation failed"
fi
```

## Performance Optimization

### Parallel Test Execution

For faster testing on multi-core systems, run test categories in parallel:

```bash
# In test_portable.sh, after sourcing cli-runtime-tests.sh

(test_help_commands) &
(test_list_commands) &
(test_tool_description_commands) &

wait
```

**Note**: Requires synchronization of `TESTS_PASSED` and `TESTS_FAILED` counters.

### Selective Test Execution

Skip slower tests during development:

```bash
export SKIP_TOOL_DESCRIPTIONS=true

test_help_commands
test_list_commands

if [[ "${SKIP_TOOL_DESCRIPTIONS:-false}" != "true" ]]; then
    test_tool_description_commands
fi
```

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Test CLI Runtime
  run: |
    ./scripts/portable/test_portable.sh \
      --package ./serena-build \
      --platform linux-x64 \
      --verbose
  timeout-minutes: 10
```

### GitLab CI Example

```yaml
test:cli:
  script:
    - ./scripts/portable/test_portable.sh --package ./serena-build --platform linux-x64
  timeout: 10 minutes
```

## Validation Checklist

Before using in production:

- [ ] All test functions are properly exported
- [ ] Timeout values are appropriate for your systems
- [ ] Platform detection logic is correct
- [ ] Error handling is sufficient
- [ ] Output format is as expected
- [ ] No external dependencies are required
- [ ] Tests work on both Windows and Unix systems
- [ ] Test suite completes within acceptable time

## References

- [CLI Runtime Tests Design](/root/repo/docs/cli-runtime-tests-design.md)
- [test_portable.sh](/root/repo/scripts/portable/test_portable.sh)
- [CLI Runtime Tests Implementation](/root/repo/scripts/portable/cli-runtime-tests.sh)
