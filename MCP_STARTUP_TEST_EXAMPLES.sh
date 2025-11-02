#!/usr/bin/env bash
#
# MCP Server Startup Test - Practical Examples
#
# This file contains ready-to-use examples for different scenarios
# Copy/paste snippets from this file into your test scripts
#

# ============================================================================
# EXAMPLE 1: Basic Startup Test (Minimal)
# ============================================================================
# Use this for simple CI pipelines that just need to verify server starts

basic_mcp_startup_test() {
    local mcp_cmd="${1:-serena-mcp-server}"
    local timeout_secs=10
    local startup_log="/tmp/mcp_test_$$.log"

    echo "[TEST] Starting MCP server..."

    # Start with timeout and capture output
    if ! timeout $timeout_secs "$mcp_cmd" \
        --transport stdio \
        --log-level INFO \
        > "$startup_log" 2>&1 &
    then
        echo "[FAIL] Could not execute MCP server"
        return 1
    fi

    local server_pid=$!
    echo "[TEST] Server PID: $server_pid"

    # Wait for initialization or timeout
    sleep 2

    # Check if server logged initialization
    if grep -q "Initializing\|Starting\|setup complete" "$startup_log"; then
        echo "[PASS] Server initialized successfully"
        kill $server_pid 2>/dev/null || true
        rm -f "$startup_log"
        return 0
    else
        echo "[FAIL] Server did not initialize"
        cat "$startup_log"
        kill -9 $server_pid 2>/dev/null || true
        rm -f "$startup_log"
        return 1
    fi
}

# Usage:
# basic_mcp_startup_test
# or with custom command:
# basic_mcp_startup_test "path/to/serena-mcp-server"


# ============================================================================
# EXAMPLE 2: Comprehensive Test with Diagnostics
# ============================================================================
# Use this for detailed testing with error reporting

comprehensive_mcp_startup_test() {
    local mcp_cmd="${1:-serena-mcp-server}"
    local platform="${2:-linux-x64}"

    echo "=========================================="
    echo "MCP Server Startup Test - Comprehensive"
    echo "=========================================="
    echo "Platform: $platform"
    echo "Command: $mcp_cmd"
    echo ""

    # Check if command exists
    if ! command -v "$mcp_cmd" &>/dev/null; then
        echo "[FAIL] MCP command not found: $mcp_cmd"
        echo "Please ensure serena-mcp-server is in PATH"
        return 1
    fi

    echo "[INFO] Command found at: $(which "$mcp_cmd")"
    echo ""

    # Check MCP command help
    echo "[TEST] Verifying MCP command..."
    if ! "$mcp_cmd" --help > /dev/null 2>&1; then
        echo "[FAIL] MCP command help failed"
        return 1
    fi
    echo "[PASS] MCP command is functional"
    echo ""

    # Start server with logging
    local startup_log="/tmp/mcp_startup_$(date +%s)_$$.log"
    echo "[TEST] Starting server (log: $startup_log)..."

    if ! timeout 15s "$mcp_cmd" \
        --transport stdio \
        --log-level DEBUG \
        > "$startup_log" 2>&1 &
    then
        echo "[FAIL] Failed to start server"
        return 1
    fi

    local server_pid=$!
    echo "[INFO] Server PID: $server_pid"
    echo ""

    # Monitor initialization
    echo "[TEST] Waiting for server initialization..."
    local init_found=false
    local error_found=false
    local elapsed=0

    while [[ $elapsed -lt 5 ]]; do
        # Check for initialization
        if grep -qE "Initializing|Starting|setup complete" "$startup_log"; then
            init_found=true
            break
        fi

        # Check for errors
        if grep -qE "FATAL|Traceback|ModuleNotFoundError" "$startup_log"; then
            error_found=true
            break
        fi

        sleep 0.2
        ((elapsed++))
    done

    echo ""
    echo "[ANALYSIS] Startup Log Contents:"
    echo "--- Log File Start ---"
    head -20 "$startup_log"
    echo "--- Log File End ---"
    echo ""

    # Cleanup
    echo "[CLEANUP] Terminating server..."
    kill -TERM $server_pid 2>/dev/null || true
    sleep 1
    kill -9 $server_pid 2>/dev/null || true

    # Report results
    echo "=========================================="
    if [[ "$error_found" == "true" ]]; then
        echo "[FAIL] Errors detected during startup"
        grep -E "Error|Exception" "$startup_log" | head -5
        rm -f "$startup_log"
        return 1
    elif [[ "$init_found" == "true" ]]; then
        echo "[PASS] Server initialized successfully"
        rm -f "$startup_log"
        return 0
    else
        echo "[FAIL] No initialization signal detected (timeout)"
        rm -f "$startup_log"
        return 1
    fi
}

# Usage:
# comprehensive_mcp_startup_test
# comprehensive_mcp_startup_test "path/to/mcp-server" "linux-x64"


# ============================================================================
# EXAMPLE 3: Test with Port Binding Verification
# ============================================================================
# Use this when testing HTTP/SSE transports

port_binding_test() {
    local mcp_cmd="${1:-serena-mcp-server}"
    local port="${2:-8000}"
    local timeout_secs=10

    echo "[TEST] Testing port binding on port $port..."

    # Start server with HTTP transport
    local startup_log="/tmp/mcp_port_test_$$.log"
    if ! timeout $timeout_secs "$mcp_cmd" \
        --transport streamable-http \
        --port $port \
        --log-level INFO \
        > "$startup_log" 2>&1 &
    then
        echo "[FAIL] Could not start server"
        return 1
    fi

    local server_pid=$!

    # Wait for port to become available
    echo "[TEST] Waiting for port to be listening..."
    local elapsed=0
    while [[ $elapsed -lt 5 ]]; do
        if command -v ss &>/dev/null; then
            if ss -tlnp 2>/dev/null | grep -q ":$port"; then
                echo "[PASS] Port $port is listening"
                kill $server_pid 2>/dev/null || true
                rm -f "$startup_log"
                return 0
            fi
        elif command -v netstat &>/dev/null; then
            if netstat -tlnp 2>/dev/null | grep -q ":$port"; then
                echo "[PASS] Port $port is listening"
                kill $server_pid 2>/dev/null || true
                rm -f "$startup_log"
                return 0
            fi
        fi
        sleep 0.5
        ((elapsed++))
    done

    echo "[FAIL] Port $port not listening after timeout"
    kill -9 $server_pid 2>/dev/null || true
    rm -f "$startup_log"
    return 1
}

# Usage:
# port_binding_test "serena-mcp-server" 8000


# ============================================================================
# EXAMPLE 4: Stress Test - Multiple Restarts
# ============================================================================
# Use this to verify stability across multiple startups

stress_test_multiple_restarts() {
    local mcp_cmd="${1:-serena-mcp-server}"
    local iterations="${2:-5}"

    echo "=========================================="
    echo "MCP Server Stress Test - Multiple Restarts"
    echo "=========================================="
    echo "Command: $mcp_cmd"
    echo "Iterations: $iterations"
    echo ""

    local pass_count=0
    local fail_count=0

    for i in $(seq 1 $iterations); do
        echo "[ITERATION $i/$iterations] Starting..."

        local startup_log="/tmp/mcp_stress_${i}_$$.log"

        # Start and shutdown
        if ! timeout 8s "$mcp_cmd" \
            --transport stdio \
            --log-level WARNING \
            > "$startup_log" 2>&1 &
        then
            echo "[FAIL] Could not start server"
            ((fail_count++))
            rm -f "$startup_log"
            continue
        fi

        local server_pid=$!
        local result=1

        # Check initialization
        sleep 1
        if grep -q "Initializing\|Starting" "$startup_log"; then
            result=0
            ((pass_count++))
            echo "[PASS] Iteration $i succeeded"
        else
            ((fail_count++))
            echo "[FAIL] Iteration $i failed"
        fi

        # Cleanup
        kill -9 $server_pid 2>/dev/null || true
        rm -f "$startup_log"

        sleep 0.5
    done

    echo ""
    echo "=========================================="
    echo "Results: $pass_count passed, $fail_count failed"
    echo "=========================================="

    [[ $fail_count -eq 0 ]]
}

# Usage:
# stress_test_multiple_restarts "serena-mcp-server" 5


# ============================================================================
# EXAMPLE 5: Test with Project Initialization
# ============================================================================
# Use this to verify server initializes with a project

project_initialization_test() {
    local mcp_cmd="${1:-serena-mcp-server}"
    local project_path="${2:-.}"

    echo "[TEST] Testing MCP server with project: $project_path"

    if [[ ! -d "$project_path" ]]; then
        echo "[FAIL] Project directory not found: $project_path"
        return 1
    fi

    local startup_log="/tmp/mcp_project_test_$$.log"

    # Start with project
    if ! timeout 15s "$mcp_cmd" \
        --project "$project_path" \
        --transport stdio \
        --log-level INFO \
        > "$startup_log" 2>&1 &
    then
        echo "[FAIL] Could not start server with project"
        return 1
    fi

    local server_pid=$!

    # Wait for initialization
    sleep 2

    # Verify initialization
    if grep -q "Initializing\|Starting\|setup complete" "$startup_log"; then
        if ! grep -qE "Error|Fatal" "$startup_log"; then
            echo "[PASS] Server initialized successfully with project"
            kill $server_pid 2>/dev/null || true
            rm -f "$startup_log"
            return 0
        fi
    fi

    echo "[FAIL] Server failed to initialize with project"
    cat "$startup_log" | head -20
    kill -9 $server_pid 2>/dev/null || true
    rm -f "$startup_log"
    return 1
}

# Usage:
# project_initialization_test "serena-mcp-server" "/path/to/project"


# ============================================================================
# EXAMPLE 6: CI Integration - Return Proper Exit Codes
# ============================================================================
# Use this in CI/CD to ensure proper pass/fail reporting

ci_mcp_startup_test() {
    local mcp_cmd="${1:-serena-mcp-server}"
    local platform="${2:-linux}"

    # Run test
    if basic_mcp_startup_test "$mcp_cmd"; then
        echo "::set-output name=test_status::PASS"  # GitHub Actions
        exit 0
    else
        echo "::set-output name=test_status::FAIL"  # GitHub Actions
        exit 1
    fi
}

# Usage in GitHub Actions:
# - name: Test MCP Startup
#   run: |
#     source examples.sh
#     ci_mcp_startup_test "serena-mcp-server" "linux"


# ============================================================================
# EXAMPLE 7: Parallel Tests - Test Multiple Platforms
# ============================================================================
# Use this to test multiple platform builds in parallel

parallel_platform_tests() {
    local test_dir="${1:-.}"
    local platforms=("linux-x64" "win-x64" "macos-x64")

    echo "Testing multiple platforms in parallel..."

    for platform in "${platforms[@]}"; do
        local pkg_dir="$test_dir/serena-portable-$platform"
        if [[ -d "$pkg_dir" ]]; then
            (
                echo "[PLATFORM: $platform] Starting test..."
                if "$pkg_dir/bin/serena-mcp-server" --version >/dev/null 2>&1; then
                    echo "[PLATFORM: $platform] PASS"
                else
                    echo "[PLATFORM: $platform] FAIL"
                fi
            ) &
        fi
    done

    # Wait for all tests
    wait
    echo "All platform tests completed"
}

# Usage:
# parallel_platform_tests "./build"


# ============================================================================
# EXAMPLE 8: Health Check - Verify Server Health After Startup
# ============================================================================
# Use this for more sophisticated health verification

health_check_test() {
    local mcp_cmd="${1:-serena-mcp-server}"

    echo "[TEST] Running health check..."

    # Start server
    local startup_log="/tmp/mcp_health_$$.log"
    if ! timeout 15s "$mcp_cmd" \
        --transport stdio \
        --log-level INFO \
        > "$startup_log" 2>&1 &
    then
        echo "[FAIL] Could not start server"
        return 1
    fi

    local server_pid=$!

    # Wait for full initialization
    sleep 3

    # Check 1: Process still running
    if ! kill -0 $server_pid 2>/dev/null; then
        echo "[FAIL] Server process terminated unexpectedly"
        return 1
    fi
    echo "[CHECK] Server process running: OK"

    # Check 2: Log file exists and has content
    if [[ ! -s "$startup_log" ]]; then
        echo "[FAIL] No log output detected"
        kill -9 $server_pid 2>/dev/null || true
        return 1
    fi
    echo "[CHECK] Log output detected: OK"

    # Check 3: No error messages
    if grep -qE "FATAL|ERROR|Exception" "$startup_log"; then
        echo "[FAIL] Error messages detected in logs"
        kill -9 $server_pid 2>/dev/null || true
        rm -f "$startup_log"
        return 1
    fi
    echo "[CHECK] No error messages: OK"

    # Check 4: Initialization messages present
    if grep -q "Initializing\|Starting" "$startup_log"; then
        echo "[CHECK] Initialization messages: OK"
    else
        echo "[WARN] No initialization messages (server may be slow)"
    fi

    # Cleanup
    kill $server_pid 2>/dev/null || true
    rm -f "$startup_log"

    echo "[PASS] Health check completed successfully"
    return 0
}

# Usage:
# health_check_test "serena-mcp-server"


# ============================================================================
# DEMONSTRATION - Run this script to see examples in action
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "MCP Server Startup Test - Examples"
    echo "===================================="
    echo ""
    echo "Available examples:"
    echo "  1. basic_mcp_startup_test"
    echo "  2. comprehensive_mcp_startup_test"
    echo "  3. port_binding_test"
    echo "  4. stress_test_multiple_restarts"
    echo "  5. project_initialization_test"
    echo "  6. ci_mcp_startup_test"
    echo "  7. parallel_platform_tests"
    echo "  8. health_check_test"
    echo ""
    echo "Source this file and call a function:"
    echo "  source MCP_STARTUP_TEST_EXAMPLES.sh"
    echo "  basic_mcp_startup_test"
    echo ""
    echo "Or copy the function you need into your test script."
fi
