# Safe MCP Server Startup Test Design for CI Environment

## Overview

This document provides a complete design for testing MCP server startup safely in CI/CD environments. The test must handle an indefinite-running server with proper timeout/signal handling on both Linux and Windows.

## Key Challenges & Solutions

### Challenge 1: Server Runs Indefinitely
**Problem**: `serena-mcp-server` runs continuously, blocking the test.

**Solution**: Use OS-specific timeout mechanisms with process lifecycle management:
- **Linux**: Use `timeout` command with SIGTERM/SIGKILL escalation
- **Windows**: Use `taskkill` command or PowerShell timeout wrapper
- Capture startup success before timeout occurs

### Challenge 2: Cross-Platform Compatibility
**Problem**: Unix and Windows have different process handling, signal mechanisms, and shell syntax.

**Solution**: Detect platform and use appropriate commands:
```bash
if [[ "$PLATFORM" == win-* ]]; then
    # Windows-specific commands (cmd.exe, taskkill)
else
    # Unix-specific commands (timeout, kill)
fi
```

### Challenge 3: Detecting Successful Initialization
**Problem**: Hard to know when server is "ready" vs just started.

**Solution**: Monitor multiple signals of readiness:
1. **Process running check**: Server process is active
2. **Log monitoring**: Check for initialization messages in stderr
3. **Port binding check**: Verify port is listening (for SSE/HTTP transports)
4. **Health endpoint check**: Probe health endpoint if available
5. **Startup log patterns**: Look for specific "ready" messages

### Challenge 4: Capturing and Analyzing Logs
**Problem**: Need to distinguish startup errors from normal operation.

**Solution**: Implement tiered logging capture:
1. **Real-time stderr capture**: Redirect to temp file during startup phase
2. **Log file monitoring**: Check serena logs directory for initialization logs
3. **Pattern-based filtering**: Extract relevant startup information
4. **Error detection**: Look for FATAL, ERROR, exception patterns

### Challenge 5: Clean Process Termination
**Problem**: Orphaned processes consuming resources in CI.

**Solution**: Multi-stage shutdown with cleanup:
1. Send SIGTERM (graceful)
2. Wait briefly for shutdown
3. Force SIGKILL if needed
4. Verify process cleanup
5. Report cleanup status

## Detailed Design

### 1. Server Startup with Timeout

#### Unix/Linux Approach
```bash
# Start server with 10-second initialization timeout
# Use process substitution to capture stderr
timeout 10 "$MCP_CMD" \
    --transport stdio \
    --log-level INFO \
    > "$STARTUP_LOG" 2>&1 &
SERVER_PID=$!

# Wait for startup completion (max 5 seconds)
STARTUP_TIMEOUT=5
STARTUP_START=$(date +%s)
while [[ $(( $(date +%s) - STARTUP_START )) -lt $STARTUP_TIMEOUT ]]; do
    # Check if startup completed
    if grep -q "MCP server lifetime setup complete" "$STARTUP_LOG" 2>/dev/null; then
        STARTUP_SUCCESS=true
        break
    fi
    sleep 0.1
done
```

**Key Points**:
- `timeout 10` ensures process dies after 10 seconds
- `&` backgrounding allows test to continue
- Capture PID for manual cleanup if needed
- Poll stderr log for startup completion markers
- Non-blocking check with small sleep intervals

#### Windows Approach
```batch
REM Start server in background with timeout wrapper
REM Use START /B for background execution
setlocal enabledelayedexpansion

set STARTUP_LOG=%TEMP%\mcp_startup_%RANDOM%.log
set SERVER_PID=0

REM Start server process and get its PID via tasklist
start "Serena MCP" /B ^
    "%MCP_CMD%" ^
    --transport stdio ^
    --log-level INFO ^
    > "%STARTUP_LOG%" 2>&1

REM Note: Windows START command doesn't return PID directly
REM We'll use timeout wrapper instead
timeout /t 10 /nobreak > nul 2>&1 & taskkill /FI "WINDOWTITLE eq Serena MCP" /T /F > nul 2>&1
```

**Alternative Windows Approach** (More reliable):
```batch
REM Use PowerShell for better timeout + PID handling
powershell -NoProfile -Command "^
    $process = Start-Process '%MCP_CMD%' `
        -ArgumentList '--transport', 'stdio', '--log-level', 'INFO' `
        -RedirectStandardOutput '%STARTUP_LOG%' `
        -RedirectStandardError '%STARTUP_LOG%' `
        -PassThru; `
    $startTime = Get-Date; `
    while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds(5)) { `
        if ((Get-Content '%STARTUP_LOG%' -ErrorAction SilentlyContinue) -match 'MCP server lifetime setup complete') { `
            Write-Host 'Server ready'; `
            Break; `
        } `
        Start-Sleep -Milliseconds 100; `
    } `
    $process.Id | Out-File '%SERVER_PID_FILE%'; `
    Start-Sleep -Seconds 5; `
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue"
```

### 2. Verifying Successful Initialization

#### Key Initialization Signals
```bash
verify_startup_success() {
    local log_file="$1"
    local max_wait="${2:-5}"
    local elapsed=0

    # Pattern 1: Check for successful initialization log entry
    if grep -E "Initializing Serena MCP server|Starting MCP server|MCP server lifetime setup complete" "$log_file" 2>/dev/null; then
        return 0
    fi

    # Pattern 2: Check for absence of fatal errors during startup
    if grep -E "FATAL|Fatal Error|Traceback.*File.*line|ModuleNotFoundError" "$log_file" 2>/dev/null; then
        echo "ERROR: Fatal error detected in startup logs"
        return 1
    fi

    # Pattern 3: No "ERROR" in first N lines (startup phase)
    local first_error_line=$(grep -n "^\[ERROR\]" "$log_file" 2>/dev/null | head -1 | cut -d: -f1)
    if [[ ! -z "$first_error_line" ]] && [[ $first_error_line -lt 20 ]]; then
        echo "ERROR: Early error in startup phase (line $first_error_line)"
        return 1
    fi

    return 0
}
```

#### Port-Based Verification (for SSE/HTTP)
```bash
verify_port_listening() {
    local port="${1:-8000}"
    local timeout="${2:-5}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if command -v netstat &> /dev/null; then
            if netstat -tlnp 2>/dev/null | grep -q ":$port"; then
                return 0
            fi
        elif command -v ss &> /dev/null; then
            if ss -tlnp 2>/dev/null | grep -q ":$port"; then
                return 0
            fi
        fi
        sleep 0.5
        ((elapsed+=1))
    done

    return 1
}
```

### 3. Log Capture and Analysis

#### Capture Strategy
```bash
# Setup logging infrastructure
STARTUP_PHASE_LOG="/tmp/mcp_startup_$$.log"
FULL_LOG="/tmp/mcp_full_$$.log"
SERENA_LOG_DIR="$HOME/.serena/logs"  # or portable equivalent

# Start server with dual logging
{
    # Capture stderr in real-time
    "$MCP_CMD" \
        --transport stdio \
        --log-level INFO \
        2>&1
} | tee "$STARTUP_PHASE_LOG" > "$FULL_LOG" &

SERVER_PID=$!

# Monitor startup phase
monitor_startup_logs() {
    local log_file="$1"
    local timeout="${2:-5}"
    local start_time=$(date +%s)

    while [[ $(( $(date +%s) - start_time )) -lt $timeout ]]; do
        # Print any new lines
        tail -f "$log_file" 2>/dev/null &
        TAIL_PID=$!

        # Check for completion
        if grep -q "MCP server lifetime setup complete\|listening on\|Transport.*connected" "$log_file" 2>/dev/null; then
            kill $TAIL_PID 2>/dev/null || true
            return 0
        fi

        sleep 0.2
        kill $TAIL_PID 2>/dev/null || true
    done

    return 1
}
```

#### Log Analysis
```bash
analyze_startup_logs() {
    local log_file="$1"
    local report="/tmp/mcp_startup_report_$$.txt"

    {
        echo "=== MCP Server Startup Analysis ==="
        echo "Timestamp: $(date)"
        echo ""

        echo "--- Initialization Messages ---"
        grep "Initializing\|Starting\|setup complete" "$log_file" || echo "No initialization messages found"
        echo ""

        echo "--- Error Messages (if any) ---"
        grep -E "\[ERROR\]|Exception|Traceback" "$log_file" || echo "No errors detected"
        echo ""

        echo "--- Warning Messages (if any) ---"
        grep "\[WARN\]" "$log_file" || echo "No warnings detected"
        echo ""

        echo "--- Module Import Checks ---"
        grep -E "import serena|import solidlsp|import mcp" "$log_file" || echo "No import logs found"
        echo ""

        echo "--- First 30 lines (startup context) ---"
        head -30 "$log_file"
        echo ""

        echo "--- Last 10 lines (final state) ---"
        tail -10 "$log_file"

    } > "$report"

    cat "$report"
    echo "Report saved to: $report"
}
```

### 4. Clean Process Termination

#### Unix/Linux Cleanup
```bash
cleanup_server_process() {
    local pid="$1"
    local grace_period="${2:-2}"

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        echo "Process $pid not running or invalid"
        return 0
    fi

    echo "Cleaning up server process (PID: $pid)..."

    # Stage 1: SIGTERM (graceful shutdown)
    echo "  Sending SIGTERM..."
    kill -TERM "$pid" 2>/dev/null || true

    # Wait for graceful shutdown
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt $grace_period ]]; do
        sleep 0.5
        ((waited+=1))
    done

    # Stage 2: SIGKILL (force kill) if still running
    if kill -0 "$pid" 2>/dev/null; then
        echo "  Process did not shutdown gracefully, sending SIGKILL..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi

    # Verify cleanup
    if kill -0 "$pid" 2>/dev/null; then
        echo "  ERROR: Failed to terminate process $pid"
        return 1
    fi

    echo "  Process terminated successfully"
    return 0
}
```

#### Windows Cleanup
```batch
REM Windows process cleanup
set SERVER_PID=%1
set GRACE_PERIOD=%2
if "%GRACE_PERIOD%"=="" set GRACE_PERIOD=2

if "%SERVER_PID%"=="" (
    echo No PID provided
    exit /b 0
)

echo Cleaning up server process (PID: %SERVER_PID%)...

REM Stage 1: Request graceful shutdown
echo   Sending termination request...
taskkill /PID %SERVER_PID% /T 2>nul

REM Wait for shutdown
timeout /t %GRACE_PERIOD% /nobreak >nul 2>&1

REM Stage 2: Force kill if still running
taskkill /PID %SERVER_PID% /F /T 2>nul

REM Verify cleanup
tasklist /FI "PID eq %SERVER_PID%" 2>nul | find /I "python" >nul
if %ERRORLEVEL%==0 (
    echo ERROR: Failed to terminate process %SERVER_PID%
    exit /b 1
)

echo   Process terminated successfully
exit /b 0
```

### 5. Platform-Specific Considerations

#### Linux/macOS Considerations
1. **Signal Handling**: Use SIGTERM for graceful, SIGKILL for forced termination
2. **Process Groups**: backgrounded processes form job groups; use `kill -TERM -$$` to signal group
3. **Log Location**: Typically `~/.serena/logs/` or `~/.solidlsp/logs/`
4. **Port Checking**: Use `ss`, `netstat`, or `/proc/net/tcp`
5. **Shell**: Standard bash available, supports `timeout` command
6. **Temp Files**: Use `/tmp` for temporary logs

#### Windows Considerations
1. **Command Lines**: Batch files and PowerShell have different syntax
2. **Process Management**: `taskkill` doesn't return PID; use `tasklist` or PowerShell
3. **Path Separators**: Use backslashes and quote paths with spaces
4. **Signal Handling**: No POSIX signals; use `taskkill` or `Stop-Process`
5. **Port Checking**: Use `netstat -an` or PowerShell `Get-NetTCPConnection`
6. **Log Location**: Typically `%APPDATA%\.serena\logs\` in portable mode: `portable\data\logs\`
7. **Batch Limitations**: Use PowerShell for complex operations
8. **Output Redirection**: Batch uses `2>&1` for stderr capture

## Complete Test Implementation

### Bash Script Template

```bash
#!/usr/bin/env bash
# mcp_server_startup_test.sh - Safe MCP server startup test

set -euo pipefail

# Configuration
PLATFORM="${1:-linux-x64}"
MCP_CMD="${2:-serena-mcp-server}"
TEST_TIMEOUT=15
STARTUP_TIMEOUT=5
GRACE_PERIOD=2
STARTUP_LOG="/tmp/mcp_startup_$$.log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; return 1; }

# Helper: Verify startup success
verify_startup_success() {
    local log_file="$1"

    # Check for fatal errors
    if grep -E "FATAL|Fatal Error|Traceback|ModuleNotFoundError" "$log_file" 2>/dev/null; then
        log_error "Fatal error during startup"
        return 1
    fi

    # Check for initialization markers
    if grep -E "Initializing Serena MCP|Starting MCP server" "$log_file" 2>/dev/null; then
        log_success "Server initialization started"
        return 0
    fi

    return 1
}

# Helper: Cleanup process
cleanup_process() {
    local pid="$1"

    if ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    log_info "Terminating server process (PID: $pid)..."
    kill -TERM "$pid" 2>/dev/null || true

    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt $GRACE_PERIOD ]]; do
        sleep 0.5
        ((waited+=1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        log_info "Force killing process..."
        kill -KILL "$pid" 2>/dev/null || true
    fi

    sleep 0.5
    ! kill -0 "$pid" 2>/dev/null
}

# Main test
main() {
    log_info "Testing MCP Server Startup"
    log_info "Platform: $PLATFORM"
    log_info "Command: $MCP_CMD"

    # Start server
    log_info "Starting server..."
    if ! timeout $TEST_TIMEOUT "$MCP_CMD" \
        --transport stdio \
        --log-level INFO \
        > "$STARTUP_LOG" 2>&1 &
    then
        log_error "Failed to start server"
        cat "$STARTUP_LOG"
        return 1
    fi

    SERVER_PID=$!
    log_info "Server PID: $SERVER_PID"

    # Wait for initialization
    log_info "Waiting for server initialization (max ${STARTUP_TIMEOUT}s)..."
    local start_time=$(date +%s)
    local success=false

    while [[ $(( $(date +%s) - start_time )) -lt $STARTUP_TIMEOUT ]]; do
        if verify_startup_success "$STARTUP_LOG"; then
            success=true
            break
        fi
        sleep 0.1
    done

    # Cleanup
    cleanup_process "$SERVER_PID" || true

    # Report
    if [[ "$success" == "true" ]]; then
        log_success "MCP server startup test passed"
        rm -f "$STARTUP_LOG"
        return 0
    else
        log_error "MCP server failed to initialize"
        echo "--- Startup Log ---"
        cat "$STARTUP_LOG"
        rm -f "$STARTUP_LOG"
        return 1
    fi
}

main "$@"
```

### Integration with test_portable.sh

Add this section to `test_portable.sh` after the "CLI Tests" section:

```bash
echo ""
log_info "=== MCP Server Startup Tests ==="

# Function to test MCP startup
test_mcp_startup() {
    local mcp_cmd="$1"
    local platform="$2"
    local test_name="MCP Server Startup ($platform)"

    log_info "Test: $test_name"

    # Create temporary log file
    local startup_log="/tmp/mcp_startup_test_$$_$RANDOM.log"
    local test_result=1

    # Platform-specific startup
    if [[ "$platform" == win-* ]]; then
        # Windows startup with timeout
        (timeout 10s cmd //c "$mcp_cmd" \
            --transport stdio \
            --log-level INFO \
            > "$startup_log" 2>&1) &
        local server_pid=$!

        # Wait for initialization signal
        sleep 2

        # Check logs for success markers
        if grep -q "Initializing\|Starting MCP server" "$startup_log" 2>/dev/null; then
            test_result=0
        fi

        # Cleanup
        taskkill /PID $server_pid /F /T 2>/dev/null || true
    else
        # Unix startup with timeout
        (timeout 10s "$mcp_cmd" \
            --transport stdio \
            --log-level INFO \
            > "$startup_log" 2>&1) &
        local server_pid=$!

        # Wait for initialization (max 5 seconds)
        local elapsed=0
        while [[ $elapsed -lt 5 ]]; do
            if grep -q "Initializing\|Starting MCP server" "$startup_log" 2>/dev/null; then
                test_result=0
                break
            fi
            sleep 0.1
            ((elapsed++))
        done

        # Cleanup
        kill -TERM $server_pid 2>/dev/null || true
        sleep 1
        kill -KILL $server_pid 2>/dev/null || true
    fi

    # Verify no fatal errors in logs
    if grep -E "FATAL|Traceback|ModuleNotFoundError|ImportError" "$startup_log" 2>/dev/null; then
        test_result=1
    fi

    # Report result
    if [[ $test_result -eq 0 ]]; then
        log_success "$test_name"
        ((TESTS_PASSED++))
    else
        log_error "$test_name"
        echo "Startup log:"
        cat "$startup_log"
        ((TESTS_FAILED++))
    fi

    # Cleanup log
    rm -f "$startup_log"
}

# Run MCP startup tests
if [[ "$PLATFORM" == win-* ]]; then
    test_mcp_startup "$MCP_CMD" "$PLATFORM" || true
else
    test_mcp_startup "$MCP_CMD" "$PLATFORM" || true
fi
```

## Expected Output

### Success Case
```
[INFO] Testing MCP Server Startup
[INFO] Platform: linux-x64
[INFO] Command: serena-mcp-server
[INFO] Starting server...
[INFO] Server PID: 12345
[INFO] Waiting for server initialization (max 5s)...
[✓] MCP server startup test passed
```

### Failure Case
```
[INFO] Testing MCP Server Startup
[INFO] Platform: linux-x64
[INFO] Command: serena-mcp-server
[INFO] Starting server...
[INFO] Server PID: 12345
[INFO] Waiting for server initialization (max 5s)...
[✗] MCP server failed to initialize
--- Startup Log ---
Traceback (most recent call last):
  File "serena/cli.py", line 172, in start_mcp_server
    factory = SerenaMCPFactorySingleProcess(...)
ImportError: No module named 'mcp'
```

## Environment Variables

For portable builds, set before testing:
```bash
# Tell Serena to use portable directories
export SERENA_PORTABLE_DIR="/path/to/portable/package"

# Control logging
export LOG_LEVEL=INFO

# Optional: Skip language server downloads
export SOLIDLSP_NO_AUTO_DOWNLOAD=1
```

## Monitoring & Debugging Tips

1. **Check live logs while server runs**:
   ```bash
   tail -f ~/.serena/logs/mcp*.log
   ```

2. **Test with verbose logging**:
   ```bash
   serena-mcp-server --log-level DEBUG
   ```

3. **Verify port binding**:
   ```bash
   ss -tlnp | grep python  # Linux
   netstat -ano | findstr python  # Windows
   ```

4. **Check module availability**:
   ```bash
   python -c "import serena; import mcp; import solidlsp"
   ```

5. **Inspect process tree**:
   ```bash
   pstree -p <parent_pid>  # Show all children
   ```

## Summary Table

| Aspect | Linux/macOS | Windows |
|--------|------------|---------|
| **Start with timeout** | `timeout 10s cmd &` | `taskkill /PID /T /F` |
| **Get process PID** | `$!` | `Get-Process` + `Id` |
| **Check running** | `kill -0 $pid` | `tasklist /FI "PID eq X"` |
| **Send signal** | `kill -TERM/-KILL` | `taskkill /PID` |
| **Monitor logs** | `tail -f` | `Get-Content -Wait` |
| **Log location** | `~/.serena/logs/` | `%APPDATA%\.serena\logs\` |
| **Port check** | `ss`/`netstat -tlnp` | `netstat -ano` |

## References

- MCP Server Implementation: `/root/repo/src/serena/mcp.py`
- CLI Entry Point: `/root/repo/src/serena/cli.py`
- Existing Test Script: `/root/repo/scripts/portable/test_portable.sh`
- Python Test Suite: `/root/repo/test/test_portable.py`
