# CLI Runtime Tests - Detailed Specifications

## Test Specifications Reference

This document provides detailed specifications for each CLI runtime test, including exact command execution steps, validation criteria, and expected outputs.

---

## Category 1: Help Commands

### Test 1.1: Serena --help

**Identifier**: `CLI_HELP_001`

**Purpose**: Verify the main Serena CLI help output is accessible and properly formatted.

**Command Execution**:
```bash
timeout 5 "$SERENA_CMD" --help
```

**Execution Flow**:
1. Invoke Serena launcher with `--help` flag
2. Capture stdout and stderr
3. Wait for response (max 5 seconds)
4. Validate output

**Success Criteria**:
- Exit code: `0`
- Output contains: `"Serena CLI commands"` (exact substring)
- Output contains: `"usage:"` or `"Usage:"` (case-insensitive)
- Output contains at least one subcommand reference: `mode`, `context`, `tools`, `project`, `config`, or `prompts`
- Output is non-empty (at least 50 characters)

**Validation Regex**:
```regex
(?s).*Serena CLI commands.*usage.*
```

**Expected Output Format**:
```
Usage: serena [OPTIONS] COMMAND [ARGS]...

  Serena CLI commands. You can run `<command> --help` for more info on each command.

Options:
  --help  Show this message and exit.

Commands:
  context      Manage Serena contexts...
  config       Manage Serena configuration.
  mode         Manage Serena modes...
  project      Manage Serena projects...
  prompts      Commands related to Serena's prompts...
  tools        Commands related to Serena's tools...
```

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| Launcher not executable | File permissions | Exit code != 0 |
| Module import error | Missing dependency | "ModuleNotFoundError" in stderr |
| Syntax error | Broken code | "SyntaxError" in stderr |
| Timeout | Infinite loop or hang | Command exceeds 5s |

**Platform-Specific Notes**:
- **Unix**: Direct execution of shell script
- **Windows**: Via `cmd.exe` batch file (`serena.bat`)
- **macOS**: May require executable permission with `chmod +x`

**Typical Duration**: 0.5-1.0 seconds

**Performance Threshold**: Should complete in < 2 seconds

---

### Test 1.2: serena-mcp-server --help

**Identifier**: `CLI_HELP_002`

**Purpose**: Verify the MCP server launcher help is accessible.

**Command Execution**:
```bash
timeout 5 "$MCP_CMD" --help
```

**Execution Flow**:
1. Invoke MCP server launcher with `--help` flag
2. Capture all output
3. Wait for response (max 5 seconds)
4. Validate output is non-empty

**Success Criteria**:
- Exit code: `0`
- Output is non-empty (at least 1 character)
- Output line count: > 0
- Output contains help-related text (e.g., "help", "usage", "options", "starts", "server")

**Validation Check**:
```bash
# Count non-empty lines
output_lines=$(timeout 5 "$MCP_CMD" --help 2>&1 | wc -l)
[[ $output_lines -gt 0 ]]
```

**Expected Output Contains**:
- "help" (lowercase)
- or "Starts the Serena MCP server"
- or "Options:" with parameters listed

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| No output | Broken launcher | Line count = 0 |
| Error output | Launcher failure | Exit code != 0 AND output contains "error" |
| Corrupted output | Encoding issue | Non-UTF8 output |

**Platform-Specific Notes**:
- **Windows**: Batch file execution with `cmd.exe` wrapper
- **Unix**: Direct shell script execution
- Output may be slightly different from `--help` on `serena` due to entrypoint differences

**Typical Duration**: 1-2 seconds

---

### Test 1.3: serena --version

**Identifier**: `CLI_HELP_003`

**Purpose**: Verify version information is available and properly formatted.

**Command Execution**:
```bash
timeout 5 "$SERENA_CMD" --version
```

**Execution Flow**:
1. Invoke Serena with `--version` flag
2. Capture stdout
3. Parse version string
4. Validate semantic versioning format

**Success Criteria**:
- Exit code: `0`
- Output contains semantic version (X.Y.Z format)
- Version format matches regex: `[0-9]+\.[0-9]+\.[0-9]+`
- Version is reasonable (e.g., >= 0.0.1, < 999.999.999)

**Validation Regex**:
```regex
([0-9]+\.[0-9]+\.[0-9]+)
```

**Expected Output Format**:
```
0.1.4
```
or
```
serena, version 0.1.4
```

**Version Parsing**:
```bash
version=$(timeout 5 "$SERENA_CMD" --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
# Verify version is valid
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
```

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| No version | Code removed | No output |
| Invalid format | Version parsing broken | Regex doesn't match |
| Stale version | Build not updated | Version < expected |

**Platform-Specific Notes**:
- Version should be consistent with `pyproject.toml` version field
- Same version on all platforms for same build

**Typical Duration**: 0.5-1.0 seconds

**Version Consistency Check**:
Verify version from CLI matches package version:
```bash
EXPECTED_VERSION="0.1.4"
CLI_VERSION=$("$SERENA_CMD" --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
[[ "$CLI_VERSION" == "$EXPECTED_VERSION" ]]
```

---

## Category 2: List Commands

### Test 2.1: serena mode list

**Identifier**: `CLI_LIST_001`

**Purpose**: Verify mode discovery and listing functionality.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli mode list
```

**Execution Flow**:
1. Invoke Python interpreter with `serena.cli` module
2. Execute `mode list` subcommand
3. Capture all output
4. Validate format and content

**Success Criteria**:
- Exit code: `0`
- Output is non-empty
- Line count: >= 3 (at least 3 modes expected)
- Each line contains mode name and source indicator

**Output Format Validation**:
```bash
# Each line should match: "mode_name    (internal)" or "mode_name    (at /path/to/file.yml)"
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli mode list 2>&1)
echo "$output" | grep -qE '[a-z_]+\s+\((internal|at .+\.yml)\)'
```

**Expected Output**:
```
planning              (internal)
editing               (internal)
interactive           (internal)
one-shot              (internal)
```

**Field Validation**:
- Mode name: alphanumeric + underscore, lowercase
- Source: "(internal)" or "(at /path/to/file.yml)"
- Proper spacing/alignment

**Expected Modes** (minimum required):
- `planning` - internal mode for planning
- `editing` - internal mode for editing
- At least one more internal mode

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| No modes | Config loading failed | Output is empty |
| Corrupted output | Parsing error | Unexpected format |
| Missing internal modes | Installation incomplete | Expected modes not present |

**Configuration Path Validation**:
Modes are loaded from:
- Internal: `{PACKAGE}/serena/contexts_and_modes/modes/`
- User: `~/.serena/modes/` (if set)

**Typical Duration**: 2-3 seconds

**Performance Threshold**: < 5 seconds

---

### Test 2.2: serena context list

**Identifier**: `CLI_LIST_002`

**Purpose**: Verify context discovery and listing functionality.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli context list
```

**Execution Flow**:
1. Invoke Python with serena.cli module
2. Execute `context list` subcommand
3. Capture output
4. Validate contexts are listed

**Success Criteria**:
- Exit code: `0`
- Output is non-empty
- Line count: >= 2 (at least 2 contexts expected)
- Each line contains context name and source

**Output Format Validation**:
```bash
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli context list 2>&1)
echo "$output" | grep -qE '[a-z_-]+\s+\((internal|at .+\.yml)\)'
```

**Expected Output**:
```
agent                 (internal)
desktop-app           (internal)
ide-assistant         (internal)
```

**Expected Contexts** (minimum required):
- `agent` - agent/CLI context
- `desktop-app` - desktop application context
- `ide-assistant` - IDE assistant context

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| Missing contexts | Installation incomplete | Expected contexts not in output |
| Format error | Parsing broken | Unexpected line format |
| Permission error | File access denied | Error message in stderr |

**Typical Duration**: 2-3 seconds

---

### Test 2.3: serena tools list --quiet

**Identifier**: `CLI_LIST_003`

**Purpose**: Verify tool discovery with quiet (names only) output.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools list --quiet
```

**Execution Flow**:
1. Invoke Python with serena.cli module
2. Execute `tools list --quiet`
3. Capture tool names only
4. Validate expected tools are present

**Success Criteria**:
- Exit code: `0`
- Output is non-empty
- Contains at least 2 tool names
- Each line is a single tool name (no descriptions)

**Output Format**:
Each line contains only a tool name (no extra formatting):
```
activate_project
find_symbol
search_pattern
get_symbols_overview
...
```

**Expected Core Tools** (must be present):
- `activate_project` - activate projects
- `find_symbol` - locate symbols in code
- `search_pattern` - search for patterns

**Output Validation**:
```bash
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli tools list --quiet 2>&1)
echo "$output" | grep -q 'activate_project'
echo "$output" | grep -q 'find_symbol'
```

**Tool Count Validation**:
- Minimum tools: 5
- Recommended tools: 10+
- No duplicates in output

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| No tools | Tool registry empty | Output is empty |
| Unexpected format | Description output | Output contains parentheses or descriptions |
| Missing core tools | Installation incomplete | Expected tools not in output |

**Typical Duration**: 3-5 seconds

---

### Test 2.4: serena tools list --all

**Identifier**: `CLI_LIST_004`

**Purpose**: Verify extended tool listing includes optional tools.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools list --all
```

**Execution Flow**:
1. Invoke Python with serena.cli module
2. Execute `tools list --all`
3. Capture verbose output with descriptions
4. Validate tool information is present

**Success Criteria**:
- Exit code: `0`
- Output is non-empty
- Output line count > quiet output line count
- Includes tool names and descriptions
- Indicates tool types (enabled/optional)

**Output Format**:
```
activate_project
  Activates a project based on the project name or path.

find_symbol
  Searches for symbols in the codebase matching a given name or pattern.
  Parameters:
    - symbol_name: The symbol to find
    - ...

[Additional tools...]
```

**Output Validation**:
```bash
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli tools list --all 2>&1)
# Should have more content than quiet output
output_lines=$(echo "$output" | wc -l)
quiet_lines=$(timeout 10 "$PYTHON_EXE" -m serena.cli tools list --quiet 2>&1 | wc -l)
[[ $output_lines -gt $quiet_lines ]]
```

**Content Validation**:
- Contains tool names (alphabetically ordered)
- Contains descriptions (non-empty)
- Proper formatting and spacing

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| No additional tools | Optional tools disabled | Same output as quiet |
| Format error | Description parsing broken | Unexpected formatting |
| Missing descriptions | Tool metadata incomplete | Empty description sections |

**Typical Duration**: 3-5 seconds

---

## Category 3: Tool Description Commands

### Test 3.1: serena tools description find_symbol

**Identifier**: `CLI_DESC_001`

**Purpose**: Verify tool description retrieval for find_symbol tool.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools description find_symbol
```

**Execution Flow**:
1. Initialize Serena agent and tool registry
2. Load tool definition for find_symbol
3. Format tool description via MCP factory
4. Output formatted description

**Success Criteria**:
- Exit code: `0`
- Output contains tool name: `find_symbol`
- Output contains description text (non-empty, > 50 characters)
- Output contains parameter information
- Matches regex: `(find_symbol|locate|search)` (case-insensitive)

**Output Validation**:
```bash
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli tools description find_symbol 2>&1)
echo "$output" | grep -qiE '(find_symbol|locate|search)'
[[ ${#output} -gt 50 ]]
```

**Expected Output Contains**:
- Tool name: "find_symbol"
- Brief description (1-2 sentences about finding symbols)
- Parameters section listing:
  - `symbol_name` - the symbol to find
  - `relative_path` - optional file path restriction
  - Other relevant parameters
- Return type information
- Example usage (optional)

**Output Structure**:
```
Tool: find_symbol

Description:
Searches for symbols in the codebase matching a given name or pattern. Returns
detailed information about each matching symbol including its location, type, and
source code.

Parameters:
- symbol_name (string): Name of the symbol to find
- relative_path (string, optional): Restrict search to specific file
- include_body (boolean, optional): Include source code body
- ...

Returns:
Array of symbol objects with location and metadata
```

**Keyword Validation**:
Must contain at least one of: `find`, `locate`, `search`, `symbol`, `discover`

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| Tool not found | Tool registry incomplete | "not found" in error message |
| No description | Tool metadata missing | Output is empty |
| Wrong tool | Name resolution error | Different tool name in output |
| Format error | MCP factory broken | Malformed output |

**Agent Initialization**:
This test triggers full agent initialization including:
- Configuration loading
- Tool registry instantiation
- LSP language server preparation (may download server)

**Typical Duration**: 4-6 seconds

**Performance Threshold**: < 10 seconds (may download LSP on first run)

---

### Test 3.2: serena tools description activate_project

**Identifier**: `CLI_DESC_002`

**Purpose**: Verify tool description retrieval for activate_project tool.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools description activate_project
```

**Execution Flow**:
Similar to Test 3.1, loads and describes the activate_project tool.

**Success Criteria**:
- Exit code: `0`
- Output contains: `activate_project`
- Output contains description (> 50 characters)
- Matches regex: `(activate|project)` (case-insensitive)

**Output Validation**:
```bash
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli tools description activate_project 2>&1)
echo "$output" | grep -qiE '(activate|project)'
[[ ${#output} -gt 50 ]]
```

**Expected Output Contains**:
- Tool name: "activate_project"
- Description about activating projects
- Parameters:
  - `project_name_or_path` - project identifier
  - Other configuration options
- Information about project context switching

**Keyword Validation**:
Must contain at least one of: `activate`, `project`, `switch`, `select`

**Typical Duration**: 4-6 seconds

---

### Test 3.3: serena tools description --context agent

**Identifier**: `CLI_DESC_003`

**Purpose**: Verify tool description with context-specific modifications.

**Command Execution**:
```bash
timeout 10 "$PYTHON_EXE" -m serena.cli tools description search_pattern --context agent
```

**Execution Flow**:
1. Load specified context ("agent")
2. Initialize agent with context
3. Retrieve tool description (may differ from default)
4. Output formatted description

**Success Criteria**:
- Exit code: `0`
- Command accepts `--context` flag (no argument error)
- Output is non-empty
- Output does not contain error keywords: "error", "not found", "unrecognized"

**Output Validation**:
```bash
output=$(timeout 10 "$PYTHON_EXE" -m serena.cli tools description search_pattern \
  --context agent 2>&1)
! echo "$output" | grep -qiE '(error|not found|unrecognized)'
[[ ${#output} -gt 0 ]]
```

**Context Validation**:
- Context "agent" must be recognized
- Tool description may include context-specific modifications
- Output format should be consistent with non-context version

**Parameter Verification**:
- `--context` flag is accepted
- Valid context names work: `agent`, `desktop-app`, `ide-assistant`
- Invalid context names produce error (graceful handling)

**Failure Modes**:
| Mode | Cause | Detection |
|------|-------|-----------|
| Context not found | Invalid context name | "not found" error |
| Tool not in context | Tool disabled in context | "not available" message |
| Flag not recognized | CLI parsing error | "unrecognized arguments" |
| Timeout | Context initialization slow | Command exceeds 10s |

**Context-Aware Description**:
Some tools may have context-specific descriptions:
- Different parameter availability
- Changed descriptions
- Added/removed capabilities

**Typical Duration**: 4-6 seconds (context loading + agent init)

---

## Test Execution Matrix

| Test ID | Category | Command | Timeout | Min Duration | Max Duration |
|---------|----------|---------|---------|--------------|--------------|
| CLI_HELP_001 | Help | `serena --help` | 5s | 0.5s | 2s |
| CLI_HELP_002 | Help | `serena-mcp-server --help` | 5s | 1s | 3s |
| CLI_HELP_003 | Help | `serena --version` | 5s | 0.5s | 2s |
| CLI_LIST_001 | List | `mode list` | 10s | 2s | 5s |
| CLI_LIST_002 | List | `context list` | 10s | 2s | 5s |
| CLI_LIST_003 | List | `tools list --quiet` | 10s | 3s | 5s |
| CLI_LIST_004 | List | `tools list --all` | 10s | 3s | 5s |
| CLI_DESC_001 | Desc | `tools description find_symbol` | 10s | 4s | 8s |
| CLI_DESC_002 | Desc | `tools description activate_project` | 10s | 4s | 8s |
| CLI_DESC_003 | Desc | `tools description --context agent` | 10s | 4s | 8s |

---

## Validation Checklist

For each test, verify:

- [ ] Command syntax is correct for platform
- [ ] Timeout value is appropriate
- [ ] Success criteria are achievable
- [ ] Failure detection is reliable
- [ ] Expected output format is documented
- [ ] Platform-specific notes are considered
- [ ] Error messages are helpful
- [ ] Test is non-destructive
- [ ] No external dependencies required
- [ ] Output can be parsed reliably

---

## Debugging Failed Tests

### Enable Verbose Output

```bash
run_test_verbose() {
    local test_name="$1"
    local cmd="$2"

    echo "Test: $test_name"
    echo "Command: $cmd"
    echo "Output:"
    eval "$cmd" 2>&1
    echo "Exit code: $?"
}

# Usage
run_test_verbose "Serena help" \
  "timeout 5 '$SERENA_CMD' --help"
```

### Capture Full Output

```bash
# Save output to file for inspection
timeout 10 "$PYTHON_EXE" -m serena.cli mode list 2>&1 | tee /tmp/test_output.txt
# View with
cat /tmp/test_output.txt | od -c  # hex dump
cat /tmp/test_output.txt | wc -l  # line count
```

### Test Individual Steps

```bash
# Check if files exist
[[ -f "$SERENA_CMD" ]] && echo "Launcher exists" || echo "Launcher missing"

# Check if executable
[[ -x "$SERENA_CMD" ]] && echo "Executable" || echo "Not executable"

# Run without timeout
"$SERENA_CMD" --help

# Check Python import
"$PYTHON_EXE" -c "import serena; print('Import OK')"
```

---

## Performance Profiling

### Measure Test Duration

```bash
measure_test() {
    local cmd="$1"
    local start=$(date +%s%N)
    eval "$cmd" > /dev/null 2>&1
    local end=$(date +%s%N)
    local duration=$((($end - $start) / 1000000))  # milliseconds
    echo "Duration: ${duration}ms"
}

measure_test "timeout 10 '$PYTHON_EXE' -m serena.cli tools list --quiet"
```

### Profile Slow Tests

```bash
# Use Python profiler for slow commands
"$PYTHON_EXE" -m cProfile -s cumulative \
  -m serena.cli tools description find_symbol
```

---

## References

- [CLI Runtime Tests Design](/root/repo/docs/cli-runtime-tests-design.md)
- [CLI Runtime Tests Integration](/root/repo/docs/cli-runtime-tests-integration.md)
- [CLI Implementation](/root/repo/src/serena/cli.py)
- [Tool Registry](/root/repo/src/serena/tools/)
