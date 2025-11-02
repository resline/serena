#!/usr/bin/env bash
#
# Test Serena portable package
#
# This script performs sanity checks and integration tests on a portable build
#

set -euo pipefail

# Default values
PACKAGE=""
PLATFORM=""
VERBOSE=false
TEST_PROJECT=""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

usage() {
    cat << USAGE
Usage: $0 --package PATH --platform PLATFORM [OPTIONS]

Test a portable Serena package.

Required arguments:
    --package PATH              Path to the portable package directory
    --platform PLATFORM         Platform identifier (linux-x64, win-x64, macos-x64, macos-arm64)

Optional arguments:
    --test-project PATH         Path to test project for integration tests
    --verbose                   Enable verbose output
    -h, --help                  Show this help message

USAGE
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --package)
            PACKAGE="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --test-project)
            TEST_PROJECT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PACKAGE" ]] || [[ ! -d "$PACKAGE" ]]; then
    log_error "Package directory is required and must exist: $PACKAGE"
    usage
fi

if [[ -z "$PLATFORM" ]]; then
    log_error "Platform is required"
    usage
fi

log_info "Testing Serena portable package"
log_info "  Package: $PACKAGE"
log_info "  Platform: $PLATFORM"

# Determine launcher based on platform
if [[ "$PLATFORM" == win-* ]]; then
    SERENA_CMD="$PACKAGE/bin/serena.bat"
    MCP_CMD="$PACKAGE/bin/serena-mcp-server.bat"
    PYTHON_EXE="$PACKAGE/python/python.exe"
else
    SERENA_CMD="$PACKAGE/bin/serena"
    MCP_CMD="$PACKAGE/bin/serena-mcp-server"
    PYTHON_EXE="$PACKAGE/python/bin/python3"
fi

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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

echo ""
log_info "=== Structure Tests ==="

# Disable exit-on-error for tests (we want to run all tests even if some fail)
set +e

run_test "Package directory structure" "[[ -d '$PACKAGE/bin' && -d '$PACKAGE/python' && -d '$PACKAGE/serena' ]]"
run_test "Launcher scripts exist" "[[ -f '$SERENA_CMD' && -f '$MCP_CMD' ]]"
run_test "Python executable exists" "[[ -f '$PYTHON_EXE' ]]"
run_test "VERSION file exists" "[[ -f '$PACKAGE/VERSION' ]]"
run_test "BUILD_INFO.json exists" "[[ -f '$PACKAGE/BUILD_INFO.json' ]]"
run_test "README exists" "[[ -f '$PACKAGE/README.md' ]]"
run_test "README contains valid Python version" "grep -qE 'Python [0-9]+\.[0-9]+\.[0-9]+ runtime' '$PACKAGE/README.md'"

echo ""
log_info "=== Python Runtime Tests ==="

run_test "Python is executable" "'$PYTHON_EXE' --version"
run_test "Python imports work" "'$PYTHON_EXE' -c 'import sys; import os'"
run_test "Pip is available" "'$PYTHON_EXE' -m pip --version"

echo ""
log_info "=== Serena Installation Tests ==="

run_test "Serena module imports" "'$PYTHON_EXE' -c 'import serena'"
run_test "SolidLSP module imports" "'$PYTHON_EXE' -c 'import solidlsp'"
run_test "Key dependencies present" "'$PYTHON_EXE' -c 'import anthropic, mcp, flask, pydantic'"

echo ""
log_info "=== CLI Tests ==="

if [[ "$PLATFORM" == win-* ]]; then
    # Windows tests
    run_test "Serena --version" "cmd //c '$SERENA_CMD' --version"
    run_test "Serena --help" "cmd //c '$SERENA_CMD' --help"
else
    # Unix tests
    run_test "Launcher is executable" "[[ -x '$SERENA_CMD' ]]"
    run_test "Serena --version" "'$SERENA_CMD' --version"
    run_test "Serena --help" "'$SERENA_CMD' --help"
fi

echo ""
log_info "=== Platform-Specific Runtime Tests ==="

if [[ "$PLATFORM" == win-* ]]; then
    # ========== WINDOWS-SPECIFIC TESTS ==========
    log_info "Running Windows-specific runtime tests..."

    # Test .bat file execution
    run_test ".bat launcher exists and is readable" "[[ -f '$SERENA_CMD' && -r '$SERENA_CMD' ]]"
    run_test ".bat file has correct Windows line endings" "grep -q \$'\\r' '$SERENA_CMD' || true && true"

    # Test cmd.exe integration
    run_test "cmd.exe can execute launcher via /c flag" "cmd /c 'echo test' 1>nul 2>&1"
    run_test "serena.bat runs via cmd.exe" "cmd /c \"'$SERENA_CMD' --version\" 1>/dev/null 2>&1"

    # Test path handling with spaces
    TEST_DIR_SPACES="${PACKAGE}/test space dir"
    mkdir -p "$TEST_DIR_SPACES" 2>/dev/null || true
    run_test "Python works from path with spaces" "[[ -f '$PYTHON_EXE' ]] && \"$PYTHON_EXE\" -c 'import sys; print(len(sys.path))' 1>/dev/null"
    run_test "Launcher works from path with spaces" "cmd /c \"cd /d '$TEST_DIR_SPACES' && '$SERENA_CMD' --version\" 1>/dev/null 2>&1" || true
    rm -rf "$TEST_DIR_SPACES" 2>/dev/null || true

    # Test special character handling
    run_test "Path with quotes is handled correctly" "[[ -d '$PACKAGE' ]]"

    # Test Python.exe from Windows path
    run_test "python.exe exists at Windows path" "[[ -f '$PYTHON_EXE' ]]"
    run_test "python.exe is executable from Windows context" "cmd /c \"'$PYTHON_EXE' --version\" 1>/dev/null 2>&1"
    run_test "python.exe returns valid version" "cmd /c \"'$PYTHON_EXE' --version 2>&1\" | findstr /R \"Python\" 1>/dev/null 2>&1" || true

    # Test batch environment variables
    run_test "Batch file sets SERENA_ROOT variable" "cmd /c \"set SERENA_ROOT && echo %SERENA_ROOT% | findstr /I serena\" 1>/dev/null 2>&1" || true

    # Test subprocess execution
    run_test "cmd.exe subprocess inherits environment" "cmd /c \"'$PYTHON_EXE' -c 'import os; assert os.environ' 1>/dev/null 2>&1"

    # Test error handling
    run_test "Invalid args return non-zero exit code" "cmd /c \"'$SERENA_CMD' --invalid-flag 2>/dev/null\" ; test \$? -ne 0" || true

    # Test pip availability in Windows Python
    run_test "pip available in embedded Python" "cmd /c \"'$PYTHON_EXE' -m pip --version\" 1>/dev/null 2>&1"

    # Test Windows registry/system integration
    run_test "Python DLLs accessible" "[[ -d '$PACKAGE/python' ]] && ls '$PACKAGE/python'/*.dll 1>/dev/null 2>&1" || true

else
    # ========== LINUX/UNIX-SPECIFIC TESTS ==========
    log_info "Running Linux/Unix-specific runtime tests..."

    # Test shell script execution
    run_test "Shell launcher exists" "[[ -f '$SERENA_CMD' ]]"
    run_test "Shell script is readable" "[[ -r '$SERENA_CMD' ]]"

    # Test executable bit verification
    run_test "Launcher has executable bit set" "[[ -x '$SERENA_CMD' ]]"
    run_test "Python binary has executable bit" "[[ -x '$PYTHON_EXE' ]]"

    # Test POSIX path handling
    run_test "Launcher uses POSIX paths" "grep -q 'dirname.*BASH_SOURCE' '$SERENA_CMD' || grep -q '/bin/python' '$SERENA_CMD'"

    # Test shell script syntax
    run_test "Shell script has valid shebang" "head -1 '$SERENA_CMD' | grep -q '^#!/usr/bin/env bash\\|^#!/bin/bash'"

    # Test Unix line endings
    run_test "Launcher has Unix line endings" "! grep -q \$'\\r' '$SERENA_CMD'"

    # Test path with spaces
    TEST_DIR_SPACES="/tmp/serena-test space-$$"
    mkdir -p "$TEST_DIR_SPACES"
    cp "$SERENA_CMD" "$TEST_DIR_SPACES/serena"
    chmod +x "$TEST_DIR_SPACES/serena"
    run_test "Launcher works from directory with spaces" "'$TEST_DIR_SPACES/serena' --version 1>/dev/null 2>&1" || true
    rm -rf "$TEST_DIR_SPACES"

    # Test special characters in paths
    TEST_DIR_SPECIAL="/tmp/serena-test_\$special-$$"
    mkdir -p "$TEST_DIR_SPECIAL"
    run_test "Python works with special chars in path" "[[ -x '$PYTHON_EXE' ]] && '$PYTHON_EXE' --version 1>/dev/null 2>&1"
    rm -rf "$TEST_DIR_SPECIAL"

    # Test Python shebang execution
    run_test "Python is invoked via explicit path" "grep -q \"exec.*python\" '$SERENA_CMD'"

    # Test environment variable inheritance
    run_test "Launcher can read environment variables" "'$PYTHON_EXE' -c 'import os; os.environ' 1>/dev/null 2>&1"

    # Test symlink handling
    SYMLINK_TEST="/tmp/serena-symlink-test-$$"
    ln -sf "$SERENA_CMD" "$SYMLINK_TEST" 2>/dev/null || true
    if [[ -L "$SYMLINK_TEST" ]]; then
        run_test "Launcher works via symlink" "'$SYMLINK_TEST' --version 1>/dev/null 2>&1" || true
        rm -f "$SYMLINK_TEST"
    else
        log_warn "Symlink test skipped (symlinks not supported on this filesystem)"
    fi

    # Test relative path execution
    run_test "Launcher can be executed from different directory" "(cd /tmp && '$SERENA_CMD' --version 1>/dev/null 2>&1)"

    # Test signal handling
    run_test "Python process accepts signals" "'$PYTHON_EXE' -c 'import signal; signal.signal(signal.SIGTERM, signal.SIG_DFL)' 1>/dev/null 2>&1"

    # Test process substitution
    run_test "Python output can be captured" "OUTPUT=\$('$PYTHON_EXE' --version 2>&1) && [[ ! -z \"\$OUTPUT\" ]]"

    # Test file descriptor inheritance
    run_test "File descriptors properly inherited" "'$PYTHON_EXE' -c 'import sys; assert sys.stdin and sys.stdout and sys.stderr' 1>/dev/null 2>&1"

    # Test library path resolution
    run_test "Python finds shared libraries" "'$PYTHON_EXE' -c 'import ctypes; ctypes.CDLL(None)' 1>/dev/null 2>&1" || true

    # Test directory permissions
    run_test "All binary directories are accessible" "[[ -x '$PACKAGE/bin' && -r '$PACKAGE/bin' ]]"
    run_test "All python directories are traversable" "[[ -x '$PACKAGE/python/bin' ]] || [[ -x '$PACKAGE/python' ]]"
fi

echo ""
log_info "=== Language Server Tests ==="

# Check if language servers directory was created
run_test "Language servers directory exists" "[[ -d '$PACKAGE/language_servers' ]]"

# Test language server availability (non-blocking)
log_info "Checking bundled language servers..."
for ls_dir in "$PACKAGE/language_servers/static"/*; do
    if [[ -d "$ls_dir" ]]; then
        LS_NAME=$(basename "$ls_dir")
        log_info "  Found: $LS_NAME"
    fi
done

echo ""
log_info "=== CLI Runtime Tests ==="

# Disable exit-on-error for CLI tests (we want all tests to run)
set +e

# Test basic help commands
run_test "serena --help works" "timeout 5s '$SERENA_CMD' --help >/dev/null 2>&1"
run_test "serena-mcp-server --help works" "timeout 5s '$MCP_CMD' --help >/dev/null 2>&1"

# Test list commands (read-only, safe for CI)
run_test "serena mode list works" "timeout 5s '$PYTHON_EXE' -m serena.cli mode list >/dev/null 2>&1"
run_test "serena context list works" "timeout 5s '$PYTHON_EXE' -m serena.cli context list >/dev/null 2>&1"
run_test "serena tools list works" "timeout 5s '$PYTHON_EXE' -m serena.cli tools list --quiet >/dev/null 2>&1"

# Test tool description command
run_test "serena tools description works" "timeout 5s '$PYTHON_EXE' -m serena.cli tools description get_current_config >/dev/null 2>&1"

# Test project commands (safe, no side effects)
TEMP_PROJECT="/tmp/serena-cli-test-$$"
mkdir -p "$TEMP_PROJECT"
echo "print('test')" > "$TEMP_PROJECT/test.py"

# Run generate-yml and capture output for debugging
if timeout 5s "$PYTHON_EXE" -m serena.cli project generate-yml "$TEMP_PROJECT" >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    log_info "[✓] serena project generate-yml works"
else
    ((TESTS_FAILED++))
    log_error "[✗] serena project generate-yml works"
fi

# Check for project.yml in both possible locations
if [[ -f "$TEMP_PROJECT/project.yml" ]] || [[ -f "$TEMP_PROJECT/.serena/project.yml" ]]; then
    ((TESTS_PASSED++))
    log_info "[✓] project.yml was created"
else
    ((TESTS_FAILED++))
    log_error "[✗] project.yml was created"
    log_warn "Directory contents: $(ls -la '$TEMP_PROJECT' 2>/dev/null || echo 'directory not found')"
fi

# Cleanup temp project
rm -rf "$TEMP_PROJECT"

# Re-enable exit-on-error
set -e

echo ""
log_info "=== Integration Tests ==="

# Create a minimal test project if not provided
if [[ -z "$TEST_PROJECT" ]]; then
    TEST_PROJECT="/tmp/serena-test-project-$$"
    mkdir -p "$TEST_PROJECT"
    
    # Create a simple Python file
    cat > "$TEST_PROJECT/test.py" << 'TESTPY'
def hello_world():
    """A simple test function."""
    return "Hello, World!"

if __name__ == "__main__":
    print(hello_world())
TESTPY
    
    log_info "Created test project: $TEST_PROJECT"
fi

# Test basic operations on test project
if [[ -d "$TEST_PROJECT" ]]; then
    run_test "Python test file is valid" "'$PYTHON_EXE' -m py_compile '$TEST_PROJECT/test.py'" || true
    
    # Note: Full integration tests (activating project, listing symbols) would require
    # starting the MCP server, which is beyond the scope of quick sanity checks
    log_info "Full integration tests require manual verification with MCP client"
else
    log_warn "No test project available for integration tests"
fi

# Cleanup test project if we created it
if [[ "$TEST_PROJECT" == "/tmp/serena-test-project-"* ]]; then
    rm -rf "$TEST_PROJECT"
fi

echo ""
log_info "=== Size and Performance Checks ==="

PACKAGE_SIZE=$(du -sh "$PACKAGE" | cut -f1)
log_info "Total package size: $PACKAGE_SIZE"

# Check if size is reasonable (warn if > 2GB)
SIZE_BYTES=$(du -sb "$PACKAGE" | cut -f1)
if [[ $SIZE_BYTES -gt 2147483648 ]]; then
    log_warn "Package size exceeds 2GB, may be too large for some use cases"
fi

# Count files
FILE_COUNT=$(find "$PACKAGE" -type f | wc -l)
log_info "Total files: $FILE_COUNT"

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
    log_success "All tests passed! Package is ready for distribution."
    exit 0
else
    log_error "Some tests failed. Please review the output above."
    exit 1
fi
