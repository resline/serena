# CLI Runtime Tests - Quick Reference Guide

## TL;DR - Quick Start

Copy implementation and add 2 lines to `test_portable.sh`:

```bash
# Source the library
source "$SCRIPT_DIR/cli-runtime-tests.sh"

# Add this section in tests
if [[ "$PLATFORM" == win-* ]]; then
    test_cli_suite_windows
else
    test_cli_suite
fi
```

Done! Tests will verify CLI commands are working.

---

## All Tests at a Glance

### Help Commands (3 tests, ~3-5 seconds)
```
serena --help              ✓ Help output present
serena-mcp-server --help   ✓ Help output present
serena --version           ✓ Version format X.Y.Z
```

### List Commands (4 tests, ~12-20 seconds)
```
mode list                  ✓ At least 3 modes listed
context list               ✓ At least 2 contexts listed
tools list --quiet         ✓ Core tools present
tools list --all           ✓ Optional tools included
```

### Tool Descriptions (3 tests, ~12-18 seconds)
```
tools description find_symbol        ✓ Tool info retrieved
tools description activate_project   ✓ Tool info retrieved
tools description --context agent    ✓ Context parameter works
```

**Total Suite Time**: ~30-40 seconds (all pass), ~60+ seconds (with timeouts)

---

## Files Overview

| File | Lines | Purpose |
|------|-------|---------|
| `cli-runtime-tests.sh` | 350 | Reusable test library |
| `cli-runtime-tests-design.md` | 450 | Architecture & design |
| `cli-runtime-tests-specs.md` | 800 | Detailed specifications |
| `cli-runtime-tests-integration.md` | 600 | Integration guide |
| `cli-runtime-tests-summary.md` | 400 | Executive summary |
| `cli-runtime-tests-quick-ref.md` | 200 | This file |

---

## Test Matrix

```
TEST_ID          CATEGORY   COMMAND                           TIMEOUT  DURATION
---              ---        ---                               ---      ---
CLI_HELP_001     Help       serena --help                     5s       0.5-1s
CLI_HELP_002     Help       serena-mcp-server --help          5s       1-2s
CLI_HELP_003     Help       serena --version                  5s       0.5-1s
CLI_LIST_001     List       mode list                         10s      2-3s
CLI_LIST_002     List       context list                      10s      2-3s
CLI_LIST_003     List       tools list --quiet                10s      3-5s
CLI_LIST_004     List       tools list --all                  10s      3-5s
CLI_DESC_001     Desc       tools description find_symbol     10s      4-6s
CLI_DESC_002     Desc       tools description activate_proj   10s      4-6s
CLI_DESC_003     Desc       tools description --context agent 10s      4-6s
```

---

## Integration in 5 Steps

### Step 1: Copy Library
```bash
cp scripts/portable/cli-runtime-tests.sh scripts/portable/
```

### Step 2: Source in test_portable.sh
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cli-runtime-tests.sh"
```

### Step 3: Add Test Section
```bash
echo ""
log_info "=== CLI Runtime Tests ==="

if validate_cli_environment; then
    if [[ "$PLATFORM" == win-* ]]; then
        test_cli_suite_windows
    else
        test_cli_suite
    fi
fi
```

### Step 4: Verify Variables Set
Ensure these are defined before test execution:
```bash
SERENA_CMD="$PACKAGE/bin/serena"
MCP_CMD="$PACKAGE/bin/serena-mcp-server"
PYTHON_EXE="$PACKAGE/python/bin/python3"
```

### Step 5: Run Tests
```bash
./test_portable.sh --package ./serena-build --platform linux-x64
```

---

## Expected Output

### Success
```
[INFO] === CLI Runtime Tests ===
[INFO] Test: Serena help command
[✓] Serena help command
[INFO] Test: MCP server help command
[✓] MCP server help command
...
[INFO] All CLI tests completed successfully
```

### Failure Example
```
[INFO] === CLI Runtime Tests ===
[INFO] Test: Serena help command
[✗] Serena help command
Output:
/bin/bash: /path/to/serena: No such file or directory
```

---

## Debugging Commands

```bash
# Source library and set variables
SERENA_CMD="./bin/serena"
MCP_CMD="./bin/serena-mcp-server"
PYTHON_EXE="./python/bin/python3"

# Test individual commands
timeout 5 "$SERENA_CMD" --help
timeout 10 "$PYTHON_EXE" -m serena.cli mode list
timeout 10 "$PYTHON_EXE" -m serena.cli tools description find_symbol

# Check file existence
ls -la "$SERENA_CMD"
ls -la "$PYTHON_EXE"

# Check executability
file "$SERENA_CMD"
test -x "$SERENA_CMD" && echo "Executable"
```

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| SERENA_CMD not set | Variable undefined | Set before sourcing library |
| "command not found" | Path wrong | Verify file exists with `ls` |
| Timeouts | System slow | Increase timeout in function calls |
| Empty output | Command failed | Add error output with `2>&1` |
| Windows fails | Using Unix test | Use `test_cli_suite_windows` |

---

## Safety Guarantees

- **No files created**: Temp files cleaned up
- **No modifications**: Read-only operations
- **No network**: Completely offline
- **No dependencies**: Uses bundled Python/tools
- **No side effects**: Failed tests don't affect system

---

## Key Features

✅ **Non-destructive**: No side effects
✅ **Fast**: 30-40 seconds total
✅ **Safe**: Timeout-protected
✅ **Cross-platform**: Works on Windows/Linux/macOS
✅ **Simple**: 2-line integration
✅ **Complete**: 10 tests, 3 categories
✅ **Documented**: 4 detailed guides

---

## Test What?

| Component | Test | Verified? |
|-----------|------|-----------|
| CLI Entry Points | --help flags | ✅ Yes |
| Python Runtime | --version output | ✅ Yes |
| Module Imports | List commands | ✅ Yes |
| Configuration | List commands | ✅ Yes |
| Tool Registry | tools list | ✅ Yes |
| Agent Init | Tool descriptions | ✅ Yes |
| Output Format | All commands | ✅ Yes |

---

## Platform Notes

### Linux/macOS
```bash
# Direct execution
timeout 5 "$SERENA_CMD" --help

# Python module
timeout 10 "$PYTHON_EXE" -m serena.cli mode list
```

### Windows
```bash
# Via cmd.exe for batch files
cmd //c timeout /t 5 /nobreak && "$SERENA_CMD" --help

# Python works same
cmd //c "$PYTHON_EXE" -m serena.cli mode list
```

---

## Performance Tips

```bash
# Pre-warm Python (optional, 5-10 seconds faster)
timeout 30 "$PYTHON_EXE" -c "import serena; import solidlsp"

# Run in parallel (advanced, needs synchronization)
test_help_commands &
test_list_commands &
test_tool_description_commands &
wait

# Skip slow tests (development)
export SKIP_TOOL_DESCRIPTIONS=true
test_help_commands
test_list_commands
```

---

## CI/CD Examples

### GitHub Actions
```yaml
- name: Test Portable CLI
  run: |
    ./scripts/portable/test_portable.sh \
      --package ./serena-build \
      --platform linux-x64
```

### GitLab CI
```yaml
test:portable:cli:
  script:
    - ./scripts/portable/test_portable.sh --package ./serena-build --platform linux-x64
  timeout: 5 minutes
```

---

## Reference Documents

| Document | Use For |
|----------|---------|
| `cli-runtime-tests-design.md` | Understanding architecture |
| `cli-runtime-tests-specs.md` | Test details & validation |
| `cli-runtime-tests-integration.md` | Integration instructions |
| `cli-runtime-tests-summary.md` | Executive overview |
| `cli-runtime-tests-quick-ref.md` | Quick lookup (this file) |

---

## Important Variables

Must be set before running tests:

```bash
SERENA_CMD="$PACKAGE/bin/serena"           # Main launcher
MCP_CMD="$PACKAGE/bin/serena-mcp-server"   # MCP launcher
PYTHON_EXE="$PACKAGE/python/bin/python3"   # Python executable
PLATFORM="linux-x64"                       # Platform ID
VERBOSE="false"                            # Optional, for debug
```

---

## Quick Commands

```bash
# View all available test functions
grep "^test_" scripts/portable/cli-runtime-tests.sh

# Count total tests
grep "^run_test" scripts/portable/cli-runtime-tests.sh | wc -l

# Test with verbose output
./test_portable.sh --package ./build --verbose

# Test specific platform
./test_portable.sh --package ./build --platform win-x64

# Skip CLI tests
SKIP_CLI_TESTS=true ./test_portable.sh --package ./build
```

---

## Success Criteria Summary

**All 10 tests must:**
- ✅ Exit with code 0
- ✅ Complete within timeout
- ✅ Produce non-empty output
- ✅ Match expected patterns
- ✅ Work on all platforms

---

## Need More?

- Design philosophy? → `cli-runtime-tests-design.md`
- Test details? → `cli-runtime-tests-specs.md`
- Integration help? → `cli-runtime-tests-integration.md`
- Big picture? → `cli-runtime-tests-summary.md`
