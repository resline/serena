# CLI Runtime Tests Design for test_portable.sh

## Overview

This document outlines a design for safe CLI runtime tests that can be executed within portable builds to verify command execution and output, without requiring external dependencies or creating side effects.

## Design Principles

1. **Safety First**: All tests must be non-destructive and isolated
2. **No External Dependencies**: Tests should not require network access, external tools, or system configuration
3. **Real Command Execution**: Tests verify actual CLI behavior, not just file existence
4. **Platform Awareness**: Special handling for Windows (batch scripts) vs Unix (shell scripts)
5. **Timeout Protection**: All commands execute with reasonable timeouts to prevent hangs
6. **Portable Mode Support**: Tests operate within the portable build environment

---

## Test Categories

### Category 1: Help Commands

Help commands are safe to execute and provide direct verification that the CLI is functional.

#### Test 1.1: serena --help

**Description**: Verify the main Serena CLI help output works and contains expected content.

**Bash Command** (Unix):
```bash
timeout 5 "$SERENA_CMD" --help
```

**Bash Command** (Windows):
```bash
cmd //c timeout /t 5 /nobreak && "$SERENA_CMD" --help
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains: "Serena CLI commands"
- Output contains: "usage:" or "Usage:"
- Output contains at least one subcommand (e.g., "mode", "context", "tools")

**Platform Considerations**:
- Windows: Uses `cmd //c` to properly handle batch files
- Linux/macOS: Direct execution of shell script
- Timeout: 5 seconds (help should respond quickly)

**Test Implementation**:
```bash
run_test "Serena help command" \
  "timeout 5 '$SERENA_CMD' --help | grep -q 'Serena CLI commands' && \
   timeout 5 '$SERENA_CMD' --help | grep -qE 'usage:|Usage:' && \
   timeout 5 '$SERENA_CMD' --help | grep -qE '(mode|context|tools)'"
```

---

#### Test 1.2: serena-mcp-server --help

**Description**: Verify the MCP server launcher help output works.

**Bash Command** (Unix):
```bash
timeout 5 "$MCP_CMD" --help
```

**Bash Command** (Windows):
```bash
cmd //c timeout /t 5 /nobreak && "$MCP_CMD" --help
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains help text (either help summary or "Starts the Serena MCP server")
- Output is not empty

**Platform Considerations**:
- Windows batch file handling same as above
- Timeout: 5 seconds

**Test Implementation**:
```bash
run_test "MCP server help command" \
  "timeout 5 '$MCP_CMD' --help 2>&1 | wc -l | grep -qvE '^0$'"
```

---

#### Test 1.3: serena --version

**Description**: Verify version output is available and properly formatted.

**Bash Command** (Unix):
```bash
timeout 5 "$SERENA_CMD" --version
```

**Bash Command** (Windows):
```bash
cmd //c "$SERENA_CMD" --version
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains version number (matches semantic versioning pattern: X.Y.Z)

**Platform Considerations**:
- Windows: Same timeout/execution approach
- Timeout: 5 seconds

**Test Implementation**:
```bash
run_test "Serena version output" \
  "timeout 5 '$SERENA_CMD' --version | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'"
```

---

### Category 2: List Commands

List commands display available items without making modifications. All are safe to execute.

#### Test 2.1: serena mode list

**Description**: Verify mode listing works and returns expected output format.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli mode list
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli mode list
```

**Expected Success Criteria**:
- Exit code: 0
- Output is not empty (contains at least one mode)
- Output contains "(internal)" or "(at" to indicate mode sources

**Platform Considerations**:
- Must use Python executable directly since we're in portable mode
- Timeout: 10 seconds (may need to initialize language servers)
- Output format: "mode_name (internal)" or "mode_name (at path/to/file.yml)"

**Test Implementation**:
```bash
run_test "Mode list command" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli mode list 2>&1 | wc -l | grep -qvE '^0$'"
```

---

#### Test 2.2: serena context list

**Description**: Verify context listing works and returns expected output format.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli context list
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli context list
```

**Expected Success Criteria**:
- Exit code: 0
- Output is not empty (contains at least one context)
- Output contains "(internal)" or "(at" to indicate context sources
- Common contexts: "agent", "desktop-app", "ide-assistant"

**Platform Considerations**:
- Same as mode list
- Timeout: 10 seconds

**Test Implementation**:
```bash
run_test "Context list command" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli context list 2>&1 | wc -l | grep -qvE '^0$'"
```

---

#### Test 2.3: serena tools list

**Description**: Verify tool listing works and displays available tools.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools list --quiet
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli tools list --quiet
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains tool names (one per line)
- Output is not empty
- Common tools appear: "activate_project", "find_symbol", "search_pattern"

**Platform Considerations**:
- Using `--quiet` flag to get simple tool name listing
- Timeout: 10 seconds
- Each line should be a single tool name

**Test Implementation**:
```bash
run_test "Tools list command" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools list --quiet 2>&1 | grep -qE '(activate_project|find_symbol)'"
```

---

#### Test 2.4: serena tools list --all

**Description**: Verify extended tool listing with optional tools.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools list --all
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli tools list --all
```

**Expected Success Criteria**:
- Exit code: 0
- Output is not empty
- Output includes optional tools marker or descriptions
- Output length > quiet output length (includes more tools)

**Platform Considerations**:
- Timeout: 10 seconds
- More verbose output than --quiet flag

**Test Implementation**:
```bash
run_test "Tools list with all tools" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools list --all 2>&1 | wc -l | grep -qvE '^0$'"
```

---

### Category 3: Tool Description Commands

Tool description commands fetch and display tool-specific documentation. Safe and informative.

#### Test 3.1: serena tools description (find_symbol)

**Description**: Verify tool description output for a core tool.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools description find_symbol
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli tools description find_symbol
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains tool name: "find_symbol"
- Output contains description text (non-empty)
- Output may include parameter information

**Platform Considerations**:
- Must handle tool initialization (may take longer)
- Timeout: 10 seconds
- Windows/Unix: Same execution approach

**Test Implementation**:
```bash
run_test "Tool description for find_symbol" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools description find_symbol 2>&1 | \
   grep -qE '(find_symbol|Find symbol|locate)'"
```

---

#### Test 3.2: serena tools description (activate_project)

**Description**: Verify tool description for another core tool.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools description activate_project
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli tools description activate_project
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains tool name: "activate_project"
- Output contains description text

**Platform Considerations**:
- Timeout: 10 seconds
- Same as other description commands

**Test Implementation**:
```bash
run_test "Tool description for activate_project" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools description activate_project 2>&1 | \
   grep -qE '(activate_project|Activates)'"
```

---

#### Test 3.3: serena tools description --context

**Description**: Verify tool description can be retrieved for a specific context.

**Bash Command** (Unix):
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools description search_pattern --context agent
```

**Bash Command** (Windows):
```bash
cmd //c "$PYTHON_EXE" -m serena.cli tools description search_pattern --context agent
```

**Expected Success Criteria**:
- Exit code: 0
- Output contains tool description
- Context parameter is accepted (no argument error)

**Platform Considerations**:
- Timeout: 10 seconds (context loading may take time)
- Windows/Unix: Same approach

**Test Implementation**:
```bash
run_test "Tool description with context parameter" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools description search_pattern \
   --context agent 2>&1 | grep -qvE '(error|not found|unrecognized)'"
```

---

## Test Execution Structure

### Enhanced run_test Function

The existing `run_test` function in `test_portable.sh` should be used, but with enhanced error handling:

```bash
run_test_cli() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_pattern="$3"
    local timeout_seconds="${4:-10}"

    ((TESTS_TOTAL++))

    log_info "Test: $test_name"

    if [[ "$VERBOSE" == "true" ]]; then
        echo "  Command: $test_cmd"
    fi

    # Execute with timeout
    local output
    if output=$(eval "$test_cmd" 2>&1) && \
       [[ -n "$expected_pattern" ]] && \
       echo "$output" | grep -qE "$expected_pattern"; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        [[ "$VERBOSE" == "true" ]] && echo "$output"
        return 0
    elif [[ -z "$expected_pattern" ]] && \
         eval "$test_cmd" > /dev/null 2>&1; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name"
        ((TESTS_FAILED++))
        echo "Output:"
        echo "$output"
        return 1
    fi
}
```

### Test Execution Order

```
1. Help Commands (fastest, most reliable)
   - serena --help
   - serena-mcp-server --help
   - serena --version

2. List Commands (moderate complexity)
   - mode list
   - context list
   - tools list

3. Tool Description Commands (most complex, slowest)
   - tools description find_symbol
   - tools description activate_project
   - tools description with context
```

---

## Safety Considerations

### No Side Effects

All tests listed above:
- Do not create files (except temporary test output captured in memory)
- Do not modify project state
- Do not require external network access
- Do not install or download packages
- Do not modify system configuration

### Timeout Protection

All commands execute with timeouts:
- Help/Version commands: 5-10 seconds
- List commands: 10 seconds (LSP initialization)
- Description commands: 10 seconds

### Error Handling

Tests catch and report:
- Non-zero exit codes
- Empty/missing output
- Timeout violations
- Process crashes

### Windows Compatibility

- Use `cmd //c` wrapper for batch files
- Handle path separators (forward vs backslash)
- Timeout handling differs: use `timeout /t N /nobreak` for Windows
- Escape special characters appropriately

---

## Integration with test_portable.sh

### Add CLI Test Section

```bash
echo ""
log_info "=== CLI Runtime Tests ==="

# Test functions assume:
# - $SERENA_CMD is set to launcher script path
# - $MCP_CMD is set to mcp server launcher path
# - $PYTHON_EXE is set to python executable path
# - $PACKAGE contains portable package directory

# Help commands
run_test "Serena help command" \
  "timeout 5 '$SERENA_CMD' --help | grep -q 'Serena CLI commands'"

run_test "MCP server help command" \
  "timeout 5 '$MCP_CMD' --help 2>&1 | wc -l | grep -qvE '^0$'"

run_test "Serena version output" \
  "timeout 5 '$SERENA_CMD' --version | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'"

# List commands
run_test "Mode list command" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli mode list 2>&1 | wc -l | grep -qvE '^0$'"

run_test "Context list command" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli context list 2>&1 | wc -l | grep -qvE '^0$'"

run_test "Tools list command" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools list --quiet 2>&1 | \
   grep -qE '(activate_project|find_symbol)'"

# Tool description commands
run_test "Tool description for find_symbol" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools description find_symbol 2>&1 | \
   grep -qE '(find_symbol|locate)'"

run_test "Tool description for activate_project" \
  "timeout 10 '$PYTHON_EXE' -m serena.cli tools description activate_project 2>&1 | \
   grep -qE '(activate_project|Activate)'"
```

---

## Expected Outcomes

### Success Indicators

When all tests pass:
- Serena CLI is properly installed and functional
- All command entry points are accessible
- Help system is working
- Configuration system is initialized
- Tool registry is functional
- Output formatting is correct

### Failure Scenarios

Tests will fail if:
- CLI entry points are broken
- Python modules are missing
- Dependencies are incomplete
- Output formatting is wrong
- Commands timeout unexpectedly

---

## Performance Characteristics

| Test | Timeout | Typical Duration | Notes |
|------|---------|-----------------|-------|
| serena --help | 5s | 0.5-1s | Fastest, no initialization |
| serena --version | 5s | 0.5-1s | No module loading |
| serena-mcp-server --help | 5s | 1-2s | Batch file overhead |
| mode list | 10s | 2-3s | Config loading |
| context list | 10s | 2-3s | Config loading |
| tools list --quiet | 10s | 3-5s | Tool registry initialization |
| tools description | 10s | 4-6s | Full agent initialization |

**Total Suite Duration**: ~30-40 seconds (with timeouts, will be faster if all pass)

---

## Future Enhancements

1. **Add Project Commands**
   - `serena project generate-yml` on test project
   - Verify config file generation

2. **Add Context/Mode Switching**
   - Test `--context` and `--mode` flags
   - Verify context-aware tool descriptions

3. **Add Output Validation**
   - Schema validation for JSON output
   - Format consistency checks

4. **Performance Benchmarking**
   - Track command execution times
   - Identify regressions

5. **Extended Tool Testing**
   - Test with actual test project
   - Verify symbol finding capabilities
   - Integration tests with MCP server startup

---

## References

- [Portable Builds Documentation](/root/repo/docs/portable-builds.md)
- [CLI Implementation](/root/repo/src/serena/cli.py)
- [Tool Registry](/root/repo/src/serena/tools/)
- [Portable Mode Support](/root/repo/src/serena/portable.py)
- [Test Portable Script](/root/repo/scripts/portable/test_portable.sh)

