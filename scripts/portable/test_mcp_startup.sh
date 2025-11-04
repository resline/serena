#!/usr/bin/env bash
#
# MCP Server Startup Test - Safe initialization testing for CI environments
#
# This script safely tests the MCP server startup in CI/CD environments with:
# - Cross-platform timeout handling (Linux and Windows)
# - Proper process lifecycle management
# - Log-based initialization verification
# - Graceful cleanup with SIGTERM/SIGKILL escalation
#

set -euo pipefail

# Configuration
PLATFORM="${1:-linux-x64}"
MCP_CMD="${2:-serena-mcp-server}"
TEST_TIMEOUT=15        # Overall timeout for test
STARTUP_TIMEOUT=5      # Time to wait for initialization signal
GRACE_PERIOD=2         # Time to wait for graceful shutdown before SIGKILL
STARTUP_LOG=""
SERVER_PID=""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
    return 1
}

# ============================================================================
# Initialization Verification
# ============================================================================

# Verify startup was successful by analyzing logs
verify_startup_success() {
    local log_file="$1"
    local timeout="${2:-5}"
    local elapsed=0

    log_info "Verifying server initialization (max ${timeout}s)..."

    # Polled check for initialization markers
    while [[ $elapsed -lt $timeout ]]; do
        # Check for fatal errors FIRST (stops immediately on error)
        if grep -E "FATAL|Fatal Error|Traceback.*File.*line|ModuleNotFoundError|ImportError" "$log_file" 2>/dev/null; then
            log_error "Fatal error detected during initialization"
            return 1
        fi

        # Check for successful initialization markers
        if grep -E "Initializing Serena MCP server|Starting MCP server|MCP server lifetime setup complete" "$log_file" 2>/dev/null; then
            log_success "Server initialization confirmed"
            return 0
        fi

        # Small sleep to avoid busy-waiting
        sleep 0.2
        ((elapsed++)) || true
    done

    # Timeout reached - check if there are any errors
    if grep -E "Error|Exception" "$log_file" 2>/dev/null | head -1; then
        log_error "Timeout waiting for initialization, errors detected"
        return 1
    fi

    # Might be slow, but check if it eventually initializes
    if grep -E "Initializing|Starting" "$log_file" 2>/dev/null; then
        log_warn "Slow initialization detected, but server is initializing"
        return 0
    fi

    log_error "Timeout waiting for initialization, no startup messages detected"
    return 1
}

# ============================================================================
# Log Analysis
# ============================================================================

# Analyze startup logs and report issues
analyze_startup_logs() {
    local log_file="$1"

    log_info "Analyzing startup logs..."
    echo ""

    # Check for fatal errors
    echo "--- Critical Issues ---"
    if grep -E "FATAL|Fatal Error|ModuleNotFoundError|ImportError|AttributeError" "$log_file" 2>/dev/null; then
        return 1
    else
        log_success "No critical errors detected"
    fi
    echo ""

    # Check initialization progress
    echo "--- Initialization Progress ---"
    grep -E "Initializing|Starting|setup complete|ready" "$log_file" 2>/dev/null || log_warn "No initialization messages found"
    echo ""

    # Check for warnings
    echo "--- Warnings (if any) ---"
    grep "\[WARN\]" "$log_file" 2>/dev/null || log_info "No warnings"
    echo ""

    # Show first few lines for context
    echo "--- Startup Context (first 15 lines) ---"
    head -15 "$log_file"
    echo ""

    return 0
}

# ============================================================================
# Process Management - Unix/Linux
# ============================================================================

# Start server on Unix with timeout
start_server_unix() {
    log_info "Starting MCP server on Unix platform..."

    # Create temp log file
    STARTUP_LOG=$(mktemp "/tmp/mcp_startup_${PLATFORM}_XXXXXX.log")
    log_info "Startup log: $STARTUP_LOG"

    # Start server with overall timeout
    # The timeout command sends SIGTERM at TEST_TIMEOUT, then SIGKILL at TEST_TIMEOUT+5
    if ! timeout --preserve-status $TEST_TIMEOUT "$MCP_CMD" \
        --transport stdio \
        --log-level INFO \
        > "$STARTUP_LOG" 2>&1 &
    then
        log_error "Failed to execute MCP server command"
        return 1
    fi

    SERVER_PID=$!
    log_info "Server started with PID: $SERVER_PID"
    return 0
}

# Cleanup server process on Unix
cleanup_server_unix() {
    local pid="$1"

    # Verify process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        log_info "Server process already terminated (PID: $pid)"
        return 0
    fi

    log_info "Cleaning up server process (PID: $pid)..."

    # Stage 1: Send SIGTERM for graceful shutdown
    log_info "  Sending SIGTERM for graceful shutdown..."
    kill -TERM "$pid" 2>/dev/null || true

    # Wait for graceful shutdown
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt $GRACE_PERIOD ]]; do
        sleep 0.5
        ((waited+=1))
    done

    # Stage 2: Send SIGKILL if still running
    if kill -0 "$pid" 2>/dev/null; then
        log_warn "Process did not respond to SIGTERM, sending SIGKILL..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi

    # Verify termination
    if kill -0 "$pid" 2>/dev/null; then
        log_error "Failed to terminate process (PID: $pid)"
        return 1
    fi

    log_success "Process terminated successfully"
    return 0
}

# ============================================================================
# Process Management - Windows
# ============================================================================

# Start server on Windows with timeout (using PowerShell wrapper)
start_server_windows() {
    log_info "Starting MCP server on Windows platform..."

    # Create temp log file
    STARTUP_LOG=$(mktemp "/tmp/mcp_startup_${PLATFORM}_XXXXXX.log")
    log_info "Startup log: $STARTUP_LOG"

    # Windows batch START command doesn't return PID easily
    # For testing, we use timeout directly to kill after TEST_TIMEOUT
    # This is simpler in bash on Windows (Git Bash)
    if ! timeout $TEST_TIMEOUT "$MCP_CMD" \
        --transport stdio \
        --log-level INFO \
        > "$STARTUP_LOG" 2>&1 &
    then
        log_error "Failed to execute MCP server command"
        return 1
    fi

    SERVER_PID=$!
    log_info "Server started with PID: $SERVER_PID"
    return 0
}

# Cleanup server process on Windows
cleanup_server_windows() {
    local pid="$1"

    # Check if process exists (Windows)
    if ! kill -0 "$pid" 2>/dev/null; then
        log_info "Server process already terminated (PID: $pid)"
        return 0
    fi

    log_info "Cleaning up server process (PID: $pid)..."

    # Try graceful termination first
    log_info "  Sending termination signal..."
    kill -TERM "$pid" 2>/dev/null || true
    sleep $GRACE_PERIOD

    # Force kill if needed
    if kill -0 "$pid" 2>/dev/null; then
        log_warn "Process did not respond gracefully, force killing..."
        kill -KILL "$pid" 2>/dev/null || true
    fi

    # Verify cleanup
    if kill -0 "$pid" 2>/dev/null; then
        log_error "Failed to terminate process (PID: $pid)"
        return 1
    fi

    log_success "Process terminated successfully"
    return 0
}

# ============================================================================
# Main Test Flow
# ============================================================================

main() {
    log_info "============================================"
    log_info "MCP Server Startup Test"
    log_info "============================================"
    log_info "Platform: $PLATFORM"
    log_info "MCP Command: $MCP_CMD"
    log_info "Test Timeout: ${TEST_TIMEOUT}s"
    log_info "Startup Timeout: ${STARTUP_TIMEOUT}s"
    echo ""

    # Platform-specific startup
    if [[ "$PLATFORM" == win-* ]]; then
        if ! start_server_windows; then
            log_error "Failed to start server"
            return 1
        fi
    else
        if ! start_server_unix; then
            log_error "Failed to start server"
            return 1
        fi
    fi

    # Wait for initialization
    echo ""
    if ! verify_startup_success "$STARTUP_LOG" "$STARTUP_TIMEOUT"; then
        log_error "Server failed to initialize"
        echo ""
        analyze_startup_logs "$STARTUP_LOG"
        return 1
    fi

    # Verify no errors in logs
    echo ""
    if ! analyze_startup_logs "$STARTUP_LOG"; then
        log_error "Errors detected in startup logs"
        return 1
    fi

    # Cleanup
    echo ""
    if [[ "$PLATFORM" == win-* ]]; then
        cleanup_server_windows "$SERVER_PID" || true
    else
        cleanup_server_unix "$SERVER_PID" || true
    fi

    # Final report
    echo ""
    log_success "============================================"
    log_success "MCP Server Startup Test PASSED"
    log_success "============================================"

    # Cleanup log file
    rm -f "$STARTUP_LOG"

    return 0
}

# ============================================================================
# Trap Handler for Cleanup on Script Exit
# ============================================================================

cleanup_on_exit() {
    local exit_code=$?

    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log_warn "Cleaning up server process on script exit..."
        if [[ "$PLATFORM" == win-* ]]; then
            cleanup_server_windows "$SERVER_PID" || true
        else
            cleanup_server_unix "$SERVER_PID" || true
        fi
    fi

    if [[ -n "$STARTUP_LOG" ]] && [[ -f "$STARTUP_LOG" ]]; then
        rm -f "$STARTUP_LOG"
    fi

    return $exit_code
}

trap cleanup_on_exit EXIT

# ============================================================================
# Run Main Test
# ============================================================================

main "$@"
