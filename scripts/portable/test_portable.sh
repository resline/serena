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
