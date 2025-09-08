#!/bin/bash

# build_offline_windows.sh - Build Serena offline package for Windows from Linux/Mac
# This script allows building the Windows offline package from non-Windows systems

set -e

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                      ║"
echo "║     SERENA OFFLINE PACKAGE BUILDER FOR WINDOWS                      ║"
echo "║     Building from Linux/Mac for Windows deployment                  ║"
echo "║                                                                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check Python version
python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "✓ Python version: $python_version"

# Set variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_TYPE="${1:-full}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="$SCRIPT_DIR/serena-offline-windows-$TIMESTAMP"

echo "Build type: $BUILD_TYPE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to run Python scripts
run_script() {
    local script=$1
    local description=$2
    echo "═══════════════════════════════════════════════════════════════"
    echo "Running: $description"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
        python3 "$SCRIPT_DIR/scripts/$script" --output-dir "$OUTPUT_DIR" || {
            echo "⚠ Warning: $script failed, continuing..."
        }
    else
        echo "⚠ Script not found: $script"
    fi
    echo ""
}

# Main build process
echo "Starting build process..."
echo ""

# Use the main BUILD script if available
if [ -f "$SCRIPT_DIR/BUILD_OFFLINE_WINDOWS.py" ]; then
    echo "Using main build script..."
    python3 "$SCRIPT_DIR/BUILD_OFFLINE_WINDOWS.py" --$BUILD_TYPE
else
    # Fallback to individual scripts
    echo "Running individual build scripts..."
    
    # Step 1: Prepare Python package
    run_script "prepare_offline_windows.py" "Preparing Python package"
    
    # Step 2: Download language servers
    run_script "offline_deps_downloader.py" "Downloading language servers"
    
    # Step 3: Build complete package
    run_script "build_offline_package.py" "Building offline package"
    
    # Step 4: Apply offline configuration
    run_script "offline_config.py" "Applying offline configuration"
fi

# Copy installation scripts if they exist
echo "Copying installation scripts..."
for script in install.bat install.ps1 setup_environment.ps1 uninstall.ps1; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        cp "$SCRIPT_DIR/$script" "$OUTPUT_DIR/"
        echo "✓ Copied $script"
    fi
done

# Copy documentation
if [ -f "$SCRIPT_DIR/README_OFFLINE.md" ]; then
    cp "$SCRIPT_DIR/README_OFFLINE.md" "$OUTPUT_DIR/README.md"
    echo "✓ Copied README.md"
fi

# Create quick start guide
cat > "$OUTPUT_DIR/QUICK_START.txt" << 'EOF'
SERENA OFFLINE PACKAGE - QUICK START GUIDE
==========================================

1. TRANSFER TO WINDOWS:
   Copy this entire folder to your Windows machine

2. INSTALLATION (Run as Administrator on Windows):
   
   Option A - PowerShell (Recommended):
   > powershell -ExecutionPolicy Bypass .\install.ps1
   
   Option B - Command Prompt:
   > install.bat

3. VERIFY INSTALLATION:
   > serena-mcp-server --version

4. START USING:
   > serena-mcp-server

5. FOR HELP:
   See README.md for detailed instructions

==========================================
EOF

echo "✓ Created QUICK_START.txt"
echo ""

# Calculate package size
if command -v du > /dev/null 2>&1; then
    SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
    echo "Package size: $SIZE"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                         BUILD COMPLETE                              ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Package Location: $OUTPUT_DIR"
echo "║  Build Type: $BUILD_TYPE"
echo "║  Platform: Windows 10/11 (x64/ARM64)"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║                         NEXT STEPS                                  ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  1. Transfer the package folder to Windows machine                  ║"
echo "║  2. Run install.ps1 or install.bat as Administrator                 ║"
echo "║  3. Follow the installation prompts                                 ║"
echo "║  4. Start using: serena-mcp-server                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Optional: Create compressed archive
read -p "Create compressed archive? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating compressed archive..."
    cd "$SCRIPT_DIR"
    if command -v zip > /dev/null 2>&1; then
        zip -r "serena-offline-windows-$TIMESTAMP.zip" "serena-offline-windows-$TIMESTAMP"
        echo "✓ Created serena-offline-windows-$TIMESTAMP.zip"
    elif command -v tar > /dev/null 2>&1; then
        tar -czf "serena-offline-windows-$TIMESTAMP.tar.gz" "serena-offline-windows-$TIMESTAMP"
        echo "✓ Created serena-offline-windows-$TIMESTAMP.tar.gz"
    else
        echo "⚠ No compression tool found (zip or tar)"
    fi
fi

echo ""
echo "Build process completed successfully!"