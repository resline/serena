# Serena Windows PyInstaller Build Resources

This directory contains the Windows-specific resources needed for creating PyInstaller builds of Serena with proper version information and icon support.

## Files Overview

### Core Build Files
- **`serena.spec`** - Main PyInstaller specification file for building Serena
- **`build_version_info.py`** - Script to generate Windows version information from pyproject.toml
- **`version_info_template.txt`** - Template for Windows version resource information

### Generated Files  
- **`version_info.txt`** - Generated Windows version info (created by build_version_info.py)

### Documentation
- **`ICON_README.md`** - Instructions for adding Windows icon support
- **`README.md`** - This file

## Quick Start

### 1. Generate Version Information
Before building, generate the Windows version information:

```bash
cd scripts/pyinstaller
python3 build_version_info.py
```

This creates `version_info.txt` with the current version from `pyproject.toml`.

### 2. Add Icon (Optional)
For a professional appearance, add an icon file:
- Create or obtain a `.ico` file
- Save it as `scripts/pyinstaller/serena.ico`
- See `ICON_README.md` for detailed instructions

### 3. Build with PyInstaller
```bash
cd scripts/pyinstaller
pyinstaller serena.spec
```

The build will automatically use:
- Version information from `version_info.txt` (if present)
- Icon from `serena.ico` (if present)

## Build Customization

### Version Information Template
The `version_info_template.txt` contains placeholders that are replaced by `build_version_info.py`:

- `{MAJOR_VERSION}`, `{MINOR_VERSION}`, `{PATCH_VERSION}` - Version components
- `{VERSION_STRING}` - Full version string (e.g., "0.1.4")
- `{YEAR}` - Current year for copyright

### Build Script Options
```bash
# Generate to custom location
python3 build_version_info.py --output custom_version.txt

# Use different pyproject.toml
python3 build_version_info.py --pyproject /path/to/pyproject.toml

# Use different template
python3 build_version_info.py --template custom_template.txt
```

## Build Process Integration

### Manual Build
1. `python3 build_version_info.py` - Generate version info
2. `pyinstaller serena.spec` - Build executable

### Automated Build Script
Consider creating a build script that:
1. Automatically generates version info
2. Checks for icon presence  
3. Runs PyInstaller build
4. Validates output

### CI/CD Integration
For automated builds:
```yaml
# Example GitHub Actions step
- name: Generate Windows version info
  run: |
    cd scripts/pyinstaller
    python build_version_info.py
    
- name: Build Windows executable
  run: |
    cd scripts/pyinstaller
    pyinstaller serena.spec
```

## Output Structure

The PyInstaller build creates:
- **Directory build**: `dist/serena-mcp-server/` (when ONEFILE=False)
- **Single executable**: `dist/serena-mcp-server.exe` (when ONEFILE=True)

Multiple executables are created:
- `serena-mcp-server.exe` - Main MCP server
- `serena.exe` - CLI interface
- `index-project.exe` - Project indexing tool

## Version Information Details

The generated version information includes:
- **Company**: Oraios AI
- **Product**: Serena Coding Agent  
- **Description**: AI-powered development toolkit with MCP server
- **Version**: Automatically extracted from pyproject.toml
- **Copyright**: Current year with Oraios AI
- **Website**: GitHub repository link

This information appears in:
- Windows File Properties dialog
- Task Manager details
- Digital signature information (if signed)

## Troubleshooting

### Common Issues
1. **Missing version_info.txt**: Run `build_version_info.py` first
2. **Version parsing error**: Check pyproject.toml version format
3. **Template not found**: Ensure version_info_template.txt exists
4. **Icon not showing**: Verify serena.ico is in the correct location

### Build Verification
After building, verify:
- Executable runs correctly
- Version information displays properly in Windows
- Icon appears in file explorer and taskbar
- All language servers are included and functional

For more details on the build process, see the comprehensive comments in `serena.spec`.