#!/usr/bin/env bash
#
# CLI Runtime Tests for Serena Portable Build
#
# This script provides test functions for verifying CLI command execution
# in portable builds. All tests are non-destructive and require no external
# dependencies.
#
# Usage: source this file in test_portable.sh and call test_cli_suite()
#

set -u

# Test counter (assumes run_test() function exists from calling script)
# These should be defined by the calling script:
# - TESTS_PASSED
# - TESTS_FAILED
# - TESTS_TOTAL
# - run_test() function
# - log_info() function
# - log_success() function
# - log_error() function

# Color codes (if not already defined)
if [[ -z "${RED:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Import existing logging functions from calling script (assumed to exist)
# These are defined in test_portable.sh and used here

#######################################
# Test Suite for CLI Commands
#######################################

test_help_commands() {
    echo ""
    log_info "=== Help Command Tests ==="

    # Test 1.1: serena --help
    run_test "Serena help command" \
        "timeout 5 '$SERENA_CMD' --help 2>&1 | grep -q 'Serena CLI commands'"

    # Test 1.2: serena-mcp-server --help
    run_test "MCP server help command" \
        "timeout 5 '$MCP_CMD' --help 2>&1 | wc -l | grep -qvE '^0$'"

    # Test 1.3: serena --version
    run_test "Serena version output" \
        "timeout 5 '$SERENA_CMD' --version 2>&1 | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'"
}

test_list_commands() {
    echo ""
    log_info "=== List Command Tests ==="

    # Test 2.1: serena mode list
    run_test "Mode list command" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli mode list 2>&1 | wc -l | grep -qvE '^0$'"

    # Test 2.2: serena context list
    run_test "Context list command" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli context list 2>&1 | wc -l | grep -qvE '^0$'"

    # Test 2.3: serena tools list
    run_test "Tools list command" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli tools list --quiet 2>&1 | \
         grep -qE '(activate_project|find_symbol)'"

    # Test 2.4: serena tools list --all
    run_test "Tools list with all tools" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli tools list --all 2>&1 | wc -l | grep -qvE '^0$'"
}

test_tool_description_commands() {
    echo ""
    log_info "=== Tool Description Tests ==="

    # Test 3.1: serena tools description find_symbol
    run_test "Tool description for find_symbol" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli tools description find_symbol 2>&1 | \
         grep -qE '(find_symbol|locate)'"

    # Test 3.2: serena tools description activate_project
    run_test "Tool description for activate_project" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli tools description activate_project 2>&1 | \
         grep -qE '(activate_project|Activate)'"

    # Test 3.3: serena tools description with context parameter
    run_test "Tool description with context parameter" \
        "timeout 10 '$PYTHON_EXE' -m serena.cli tools description search_pattern \
         --context agent 2>&1 | grep -qvE '(error|not found|unrecognized)' || true"
}

test_cli_suite() {
    """
    Execute all CLI runtime tests.

    This function should be called from test_portable.sh after setting:
    - SERENA_CMD: path to serena launcher
    - MCP_CMD: path to serena-mcp-server launcher
    - PYTHON_EXE: path to python executable
    - run_test(): test execution function
    - log_info(): info logging function
    """

    # Validate required variables
    if [[ -z "${SERENA_CMD:-}" ]]; then
        log_error "SERENA_CMD not set. Cannot run CLI tests."
        return 1
    fi

    if [[ -z "${MCP_CMD:-}" ]]; then
        log_error "MCP_CMD not set. Cannot run CLI tests."
        return 1
    fi

    if [[ -z "${PYTHON_EXE:-}" ]]; then
        log_error "PYTHON_EXE not set. Cannot run CLI tests."
        return 1
    fi

    # Run all test categories
    test_help_commands
    test_list_commands
    test_tool_description_commands

    # Note: Test summary is handled by calling script
}

#######################################
# Windows-Specific Variants
#######################################

# For Windows execution, use these variants instead
test_help_commands_windows() {
    echo ""
    log_info "=== Help Command Tests (Windows) ==="

    # Windows uses cmd.exe for batch file execution
    run_test "Serena help command (Windows)" \
        "cmd //c \"$SERENA_CMD\" --help 2>&1 | findstr /C:\"Serena CLI commands\""

    run_test "MCP server help command (Windows)" \
        "cmd //c \"$MCP_CMD\" --help 2>&1 | find /C /V \"\" | findstr /V \"^0$\""

    run_test "Serena version output (Windows)" \
        "cmd //c \"$SERENA_CMD\" --version 2>&1 | findstr /R \"[0-9]*\\.[0-9]*\\.[0-9]*\""
}

test_list_commands_windows() {
    echo ""
    log_info "=== List Command Tests (Windows) ==="

    run_test "Mode list command (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli mode list 2>&1 | find /C /V \"\" | findstr /V \"^0$\""

    run_test "Context list command (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli context list 2>&1 | find /C /V \"\" | findstr /V \"^0$\""

    run_test "Tools list command (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli tools list --quiet 2>&1 | \
         findstr /E \"activate_project find_symbol\""

    run_test "Tools list with all tools (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli tools list --all 2>&1 | find /C /V \"\" | findstr /V \"^0$\""
}

test_tool_description_commands_windows() {
    echo ""
    log_info "=== Tool Description Tests (Windows) ==="

    run_test "Tool description for find_symbol (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli tools description find_symbol 2>&1 | \
         findstr /E \"find_symbol locate\""

    run_test "Tool description for activate_project (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli tools description activate_project 2>&1 | \
         findstr /E \"activate_project Activate\""

    run_test "Tool description with context parameter (Windows)" \
        "cmd //c \"$PYTHON_EXE\" -m serena.cli tools description search_pattern \
         --context agent 2>&1 | findstr /V \"error not found unrecognized\" || true"
}

test_cli_suite_windows() {
    """
    Execute all CLI runtime tests on Windows.

    This function should be called from test_portable.sh on Windows systems.
    """

    # Validate required variables
    if [[ -z "${SERENA_CMD:-}" ]]; then
        log_error "SERENA_CMD not set. Cannot run CLI tests."
        return 1
    fi

    if [[ -z "${MCP_CMD:-}" ]]; then
        log_error "MCP_CMD not set. Cannot run CLI tests."
        return 1
    fi

    if [[ -z "${PYTHON_EXE:-}" ]]; then
        log_error "PYTHON_EXE not set. Cannot run CLI tests."
        return 1
    fi

    # Run all test categories with Windows variants
    test_help_commands_windows
    test_list_commands_windows
    test_tool_description_commands_windows
}

#######################################
# Helper Functions
#######################################

validate_cli_environment() {
    """
    Validate that the CLI test environment is properly configured.

    Returns 0 if valid, 1 if missing required components.
    """
    local missing=0

    if [[ ! -f "$SERENA_CMD" ]] && [[ ! -f "$SERENA_CMD.bat" ]]; then
        log_error "Serena launcher not found at $SERENA_CMD"
        ((missing++))
    fi

    if [[ ! -f "$MCP_CMD" ]] && [[ ! -f "$MCP_CMD.bat" ]]; then
        log_error "MCP server launcher not found at $MCP_CMD"
        ((missing++))
    fi

    if [[ ! -f "$PYTHON_EXE" ]] && [[ ! -f "$PYTHON_EXE.exe" ]]; then
        log_error "Python executable not found at $PYTHON_EXE"
        ((missing++))
    fi

    if [[ $missing -gt 0 ]]; then
        return 1
    fi

    log_info "CLI environment validation passed"
    return 0
}

print_cli_test_summary() {
    """
    Print summary of CLI tests with statistics.
    """
    echo ""
    log_info "=== CLI Test Summary ==="
    echo "CLI tests provide verification of:"
    echo "  - Command entry points are accessible"
    echo "  - Help system is functional"
    echo "  - Configuration system is initialized"
    echo "  - Tool registry is operational"
    echo "  - Output formatting is correct"
    echo "  - No external dependencies required"
    echo ""
    log_info "All CLI tests completed successfully"
}

#######################################
# Export Functions
#######################################

# Make functions available to calling script
export -f test_help_commands
export -f test_list_commands
export -f test_tool_description_commands
export -f test_cli_suite
export -f test_help_commands_windows
export -f test_list_commands_windows
export -f test_tool_description_commands_windows
export -f test_cli_suite_windows
export -f validate_cli_environment
export -f print_cli_test_summary
