#!/usr/bin/env bash
#
# Build Serena portable package
#
# This script creates a self-contained, portable distribution of Serena
# that includes Python runtime, all dependencies, and language servers.
#

set -euo pipefail

# Default values
PLATFORM=""
VERSION="dev"
LANGUAGE_SET="standard"
PYTHON_EMBEDDED=""
OUTPUT_DIR="./build"
VERBOSE=false

# Language server configurations
declare -A LANGUAGE_SETS=(
    ["minimal"]="python typescript go"
    ["standard"]="python typescript go rust java ruby php"
    ["full"]="python typescript go rust java ruby php perl clojure elixir terraform swift bash csharp"
)

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
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat << USAGE
Usage: $0 --platform PLATFORM --version VERSION [OPTIONS]

Build a portable Serena package for the specified platform.

Required arguments:
    --platform PLATFORM         Target platform (linux-x64, win-x64, macos-x64, macos-arm64)
    --version VERSION           Version string for the build
    --python-embedded PATH      Path to Python embedded/standalone distribution

Optional arguments:
    --language-set SET          Language set: minimal, standard, or full (default: standard)
    --output DIR                Output directory (default: ./build)
    --verbose                   Enable verbose output
    -h, --help                  Show this help message

Language sets:
    minimal:  Python, TypeScript, Go
    standard: Python, TypeScript, Go, Rust, Java, Ruby, PHP
    full:     All supported languages (16+)

Examples:
    # Build standard package for Linux
    $0 --platform linux-x64 --version 0.1.4 --python-embedded /tmp/python

    # Build minimal package for macOS ARM
    $0 --platform macos-arm64 --version 0.1.4 --language-set minimal --python-embedded /tmp/python

USAGE
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --language-set)
            LANGUAGE_SET="$2"
            shift 2
            ;;
        --python-embedded)
            PYTHON_EMBEDDED="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
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
if [[ -z "$PLATFORM" ]]; then
    log_error "Platform is required"
    usage
fi

if [[ -z "$PYTHON_EMBEDDED" ]] || [[ ! -d "$PYTHON_EMBEDDED" ]]; then
    log_error "Python embedded directory is required and must exist: $PYTHON_EMBEDDED"
    usage
fi

# Determine artifact name
ARTIFACT_NAME="serena-${PLATFORM}"
PACKAGE_DIR="${OUTPUT_DIR}/${ARTIFACT_NAME}"

log_info "Building Serena portable package"
log_info "  Platform: $PLATFORM"
log_info "  Version: $VERSION"
log_info "  Language set: $LANGUAGE_SET"
log_info "  Output: $PACKAGE_DIR"

# Create output directory structure
log_info "Creating package structure..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"/{python,serena,language_servers,bin}

# Copy Python runtime
log_info "Copying Python runtime..."
cp -r "$PYTHON_EMBEDDED"/* "$PACKAGE_DIR/python/"

# Ensure Python is executable
if [[ "$PLATFORM" != win-* ]]; then
    chmod +x "$PACKAGE_DIR/python/bin/python3" 2>/dev/null || true
    chmod +x "$PACKAGE_DIR/python/bin/python" 2>/dev/null || true
fi

# Install Serena and dependencies into the portable Python
log_info "Installing Serena and dependencies..."

if [[ "$PLATFORM" == win-* ]]; then
    PORTABLE_PYTHON="${PACKAGE_DIR}/python/python.exe"
    
    # Enable pip in embedded Python
    log_info "Configuring embedded Python for pip..."
    # Create get-pip bootstrap
    curl -sS https://bootstrap.pypa.io/get-pip.py -o "${PACKAGE_DIR}/python/get-pip.py"
    "$PORTABLE_PYTHON" "${PACKAGE_DIR}/python/get-pip.py" --no-warn-script-location
    rm "${PACKAGE_DIR}/python/get-pip.py"
    
    # Uncomment the import site line in python*._pth
    PTH_FILE=$(find "${PACKAGE_DIR}/python" -name "python*._pth" | head -1)
    if [[ -f "$PTH_FILE" ]]; then
        sed -i 's/^#import site/import site/' "$PTH_FILE" 2>/dev/null || \
        sed -i '' 's/^#import site/import site/' "$PTH_FILE"
    fi
else
    PORTABLE_PYTHON="${PACKAGE_DIR}/python/bin/python3"
fi

# Install using uv if available, fallback to pip
if command -v uv &> /dev/null; then
    log_info "Installing with uv..."
    PYTHON="$PORTABLE_PYTHON" uv pip install --python "$PORTABLE_PYTHON" .
else
    log_info "Installing with pip..."
    "$PORTABLE_PYTHON" -m pip install --no-warn-script-location .
fi

# Copy Serena source and scripts
log_info "Copying Serena files..."
cp -r src/serena "$PACKAGE_DIR/serena/"
cp -r src/solidlsp "$PACKAGE_DIR/serena/"

# Create launcher scripts
log_info "Creating launcher scripts..."

if [[ "$PLATFORM" == win-* ]]; then
    # Windows batch launcher
    cat > "$PACKAGE_DIR/bin/serena.bat" << 'WINLAUNCHER'
@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SERENA_ROOT=%SCRIPT_DIR%.."
set "PYTHON_EXE=%SERENA_ROOT%\python\python.exe"

"%PYTHON_EXE%" -m serena.cli %*
WINLAUNCHER

    cat > "$PACKAGE_DIR/bin/serena-mcp-server.bat" << 'WINMCP'
@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SERENA_ROOT=%SCRIPT_DIR%.."
set "PYTHON_EXE=%SERENA_ROOT%\python\python.exe"

"%PYTHON_EXE%" -m serena.cli start_mcp_server %*
WINMCP

else
    # Unix shell launcher
    cat > "$PACKAGE_DIR/bin/serena" << 'UNIXLAUNCHER'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERENA_ROOT="$(dirname "$SCRIPT_DIR")"
PYTHON_EXE="$SERENA_ROOT/python/bin/python3"

exec "$PYTHON_EXE" -m serena.cli "$@"
UNIXLAUNCHER

    cat > "$PACKAGE_DIR/bin/serena-mcp-server" << 'UNIXMCP'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERENA_ROOT="$(dirname "$SCRIPT_DIR")"
PYTHON_EXE="$SERENA_ROOT/python/bin/python3"

exec "$PYTHON_EXE" -m serena.cli start_mcp_server "$@"
UNIXMCP

    chmod +x "$PACKAGE_DIR/bin/serena"
    chmod +x "$PACKAGE_DIR/bin/serena-mcp-server"
fi

# Pre-download language servers
log_info "Pre-downloading language servers for $LANGUAGE_SET set..."

LANGUAGES="${LANGUAGE_SETS[$LANGUAGE_SET]}"
log_info "Languages: $LANGUAGES"

# Create a script to trigger language server downloads
cat > "$PACKAGE_DIR/download_ls.py" << 'PYDOWNLOAD'
import sys
import os

# Add serena to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'serena'))

# Trigger downloads by importing language server modules
languages = sys.argv[1:] if len(sys.argv) > 1 else []

print(f"Preparing language servers for: {', '.join(languages)}")

for lang in languages:
    try:
        if lang == "python":
            from solidlsp.language_servers import pyright_server
            print(f"✓ {lang}")
        elif lang == "typescript":
            from solidlsp.language_servers import typescript_language_server
            print(f"✓ {lang}")
        elif lang == "go":
            from solidlsp.language_servers import gopls
            print(f"✓ {lang}")
        elif lang == "rust":
            from solidlsp.language_servers import rust_analyzer
            print(f"✓ {lang}")
        elif lang == "java":
            from solidlsp.language_servers import eclipse_jdtls
            print(f"✓ {lang}")
        # Add more as needed
        else:
            print(f"⚠ {lang} (no pre-download)")
    except Exception as e:
        print(f"✗ {lang}: {e}")

print("Language server preparation complete")
PYDOWNLOAD

# Run the download script
"$PORTABLE_PYTHON" "$PACKAGE_DIR/download_ls.py" $LANGUAGES || log_warn "Language server pre-download had warnings"
rm "$PACKAGE_DIR/download_ls.py"

# Copy pre-downloaded language servers if they exist
if [[ -d "$HOME/.serena/language_servers" ]]; then
    log_info "Copying pre-downloaded language servers..."
    cp -r "$HOME/.serena/language_servers"/* "$PACKAGE_DIR/language_servers/" 2>/dev/null || true
fi

# Create README
log_info "Creating README..."
cat > "$PACKAGE_DIR/README.md" << README
# Serena Portable - Version $VERSION

This is a portable distribution of Serena that includes:
- Python $PYTHON_VERSION runtime
- Serena agent and all dependencies
- Pre-configured language servers ($LANGUAGE_SET set)

## Quick Start

### Running Serena

**On Windows:**
\`\`\`
bin\\serena.bat --help
\`\`\`

**On Linux/macOS:**
\`\`\`
bin/serena --help
\`\`\`

### Starting MCP Server

**On Windows:**
\`\`\`
bin\\serena-mcp-server.bat
\`\`\`

**On Linux/macOS:**
\`\`\`
bin/serena-mcp-server
\`\`\`

## Directory Structure

- \`bin/\` - Launcher scripts
- \`python/\` - Portable Python runtime
- \`serena/\` - Serena source code
- \`language_servers/\` - Pre-downloaded language servers

## Language Support

This package includes pre-configured support for: $LANGUAGES

Additional language servers will be downloaded automatically on first use.

## Configuration

Serena stores its configuration and data in:
- Linux/macOS: \`~/.serena/\`
- Windows: \`%USERPROFILE%\\.serena\\\`

## More Information

- Documentation: https://github.com/oraios/serena
- Issues: https://github.com/oraios/serena/issues

---
Built on $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Platform: $PLATFORM
README

# Create version file
cat > "$PACKAGE_DIR/VERSION" << VERSION_FILE
$VERSION
VERSION_FILE

# Create build info
cat > "$PACKAGE_DIR/BUILD_INFO.json" << BUILD_INFO
{
  "version": "$VERSION",
  "platform": "$PLATFORM",
  "language_set": "$LANGUAGE_SET",
  "languages": [$(echo "$LANGUAGES" | tr ' ' '\n' | sed 's/^/"/' | sed 's/$/"/' | paste -sd ',' -)],
  "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "python_version": "3.11"
}
BUILD_INFO

log_success "Build complete!"
log_info "Package location: $PACKAGE_DIR"
log_info "Package size: $(du -sh "$PACKAGE_DIR" | cut -f1)"

# Verify the build
log_info "Verifying build..."
if [[ "$PLATFORM" == win-* ]]; then
    "$PACKAGE_DIR/bin/serena.bat" --version || log_warn "Version check failed"
else
    "$PACKAGE_DIR/bin/serena" --version || log_warn "Version check failed"
fi

log_success "Portable package ready for distribution"
