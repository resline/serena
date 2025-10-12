# Serena Windows PyInstaller Spec File - Quick Reference

## File Location
- **Production Spec**: `/root/repo/serena-windows.spec`
- **Development Spec**: `/root/repo/scripts/pyinstaller/serena-windows.spec`

## Build Instructions

### Basic Build (Recommended)
```bash
# Navigate to project root
cd /root/repo

# Run PyInstaller with the spec file
pyinstaller serena-windows.spec
```

### Build with Custom Paths
```bash
# Windows PowerShell
$env:LANGUAGE_SERVERS_DIR = "C:\custom\path\language_servers"
$env:RUNTIMES_DIR = "C:\custom\path\runtimes"
pyinstaller serena-windows.spec

# Windows CMD
SET LANGUAGE_SERVERS_DIR=C:\custom\path\language_servers
SET RUNTIMES_DIR=C:\custom\path\runtimes
pyinstaller serena-windows.spec
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_ROOT` | Spec file directory | Root of Serena project |
| `LANGUAGE_SERVERS_DIR` | `build/language_servers` | Downloaded LSP servers |
| `RUNTIMES_DIR` | `build/runtimes` | Portable Node.js/.NET/Java |
| `SERENA_VERSION` | `0.1.4` | Version string |
| `SERENA_BUILD_TIER` | `essential` | Build tier level |

## Key Features

### ✓ Production Ready
- **295+ hidden imports** covering all dynamic modules
- **24 language servers** fully supported
- **3 entry points**: serena-mcp-server.exe, serena.exe, index-project.exe
- **ONEDIR mode** for subprocess compatibility
- **Windows optimized** with proper API integration

### ✓ Comprehensive Coverage
- All Serena core modules
- All SolidLSP language server implementations
- Complete MCP protocol support
- External dependencies (requests, pydantic, anthropic, etc.)
- Windows-specific APIs (win32api, pywin32, etc.)
- Python standard library modules

### ✓ Data Files Bundled
- Serena resources (configs, templates, dashboard)
- Language servers (if provided)
- Portable runtimes (if provided)
- Tiktoken cache (optional)

## Output Structure

```
dist/serena-windows/
├── serena-mcp-server.exe   # Main MCP server
├── serena.exe              # CLI interface
├── index-project.exe       # Project indexing
├── _internal/              # Python runtime (~150MB)
├── serena/resources/       # Configs and templates
├── language_servers/       # LSP servers (optional, ~500MB-2GB)
└── runtimes/              # Portable runtimes (optional, ~300MB-1GB)
```

## Validation

Run this to verify the spec file:
```python
python3 -m py_compile serena-windows.spec
```

## Troubleshooting

### Missing Dependencies
If PyInstaller complains about missing modules:
1. Check that all dependencies are installed: `pip install -r requirements.txt`
2. Verify hidden imports in the spec file
3. Add missing modules to appropriate import list

### Subprocess Errors
If language servers fail to start:
1. Verify ONEDIR mode is enabled (not ONEFILE)
2. Check that `subprocess_util` is included
3. Ensure `_internal/` directory exists in output

### Large Bundle Size
To reduce size:
1. Don't bundle language servers (download on demand)
2. Don't bundle portable runtimes
3. Minimal build: ~150MB
4. Full build with runtimes: ~3GB

## Advanced Configuration

### Modifying Hidden Imports
Edit the spec file and add modules to appropriate sections:
```python
serena_imports = [
    # Add new serena modules here
]

external_imports = [
    # Add new external dependencies here
]
```

### Changing Build Mode
**WARNING**: Only use ONEDIR mode for Serena!
```python
ONEDIR = True  # REQUIRED - DO NOT CHANGE
ONEFILE = False  # Language servers need ONEDIR
```

### Optimizations
```python
STRIP_BINARIES = True   # Remove debug symbols
USE_UPX = False         # Keep disabled for Windows Defender
```

## Requirements

- Python 3.11 (not 3.12+)
- PyInstaller >= 5.0
- Windows 10/11 (for building Windows executables)
- All project dependencies installed

## Support

For issues or questions:
1. Check `/root/repo/scripts/pyinstaller/WINDOWS-BUILD-GUIDE.md`
2. Review `/root/repo/scripts/pyinstaller/BUILD-DELIVERABLES.md`
3. Examine build logs in `build/` and `dist/` directories

---

**Last Updated**: 2025-10-12  
**Spec File Version**: Production v1.0  
**Author**: Serena Development Team / Anthropic Claude Code
