# Serena Windows PyInstaller Build Guide

## Executive Summary

This guide covers the production-ready PyInstaller build for Windows 10/11 (x64 and ARM64). The build creates a portable, self-contained distribution that works offline and supports language server subprocesses.

**Critical Build Decision: ONEDIR Mode**
- We use **ONEDIR** (directory bundle) instead of ONEFILE
- **Reason**: Language servers spawn as subprocesses using `subprocess.Popen()`
- ONEFILE mode breaks subprocess functionality in frozen executables
- ONEDIR ensures `sys.executable` points to a valid executable path

## Table of Contents

1. [Build Configuration Files](#build-configuration-files)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Build Process Explained](#build-process-explained)
5. [Hidden Imports Analysis](#hidden-imports-analysis)
6. [Data Files Mapping](#data-files-mapping)
7. [Subprocess Compatibility](#subprocess-compatibility)
8. [Estimated Bundle Size](#estimated-bundle-size)
9. [Testing the Build](#testing-the-build)
10. [Troubleshooting](#troubleshooting)

---

## Build Configuration Files

### Primary Spec File: `serena-windows.spec`

**New production-ready spec file** with critical fixes:

```
scripts/pyinstaller/serena-windows.spec
```

**Key Differences from Original `serena.spec`:**

| Feature | Original (`serena.spec`) | New (`serena-windows.spec`) | Impact |
|---------|--------------------------|----------------------------|---------|
| **Build Mode** | ONEFILE=True | ONEDIR=True (COLLECT) | ✅ Fixes subprocess issues |
| **Hidden Imports** | 254 modules | 350+ modules | ✅ Catches more dynamic imports |
| **Windows Imports** | Basic win32 | Comprehensive win32com | ✅ Better Windows integration |
| **Data Files** | 2-4 entries | 4-5 entries + tiktoken | ✅ Complete offline support |
| **Documentation** | Minimal comments | Comprehensive inline docs | ✅ Maintainability |
| **Subprocess Notes** | Not mentioned | Explicit warnings/checks | ✅ Developer awareness |

### Supporting Files

1. **`version_info.txt`** - Windows executable metadata
2. **`build_version_info.py`** - Auto-generates version info from pyproject.toml
3. **`serena.ico`** - Windows executable icon (user-provided)
4. **`version_info_template.txt`** - Template for version metadata

---

## Prerequisites

### Required Software

| Software | Minimum Version | Purpose |
|----------|----------------|---------|
| **Python** | 3.11 (NOT 3.12+) | Serena requires exactly 3.11 |
| **PyInstaller** | 6.0+ | Executable bundling |
| **Windows SDK** | 10.0+ | Windows metadata embedding |
| **uv** | Latest | Python package management |

### Installation

```powershell
# 1. Install Python 3.11 from python.org
# Download: https://www.python.org/downloads/release/python-3119/

# 2. Install uv (Python package manager)
# Download: https://docs.astral.sh/uv/getting-started/installation/

# 3. Install project dependencies
cd C:\path\to\serena
uv venv
.venv\Scripts\activate
uv pip install -e .[dev]

# 4. Install PyInstaller
uv pip install pyinstaller>=6.0

# 5. Verify installations
python --version    # Should show 3.11.x
pyinstaller --version
```

---

## Quick Start

### Option 1: Using PowerShell Build Script (Recommended)

The easiest method - automated build with all bells and whistles:

```powershell
cd scripts\build-windows
.\build-portable.ps1 -Tier essential -Architecture x64
```

This automatically:
- Generates version info
- Downloads language servers
- Runs PyInstaller
- Creates complete portable package

### Option 2: Manual PyInstaller Build

For direct control over the build process:

```powershell
# Step 1: Navigate to project root
cd C:\path\to\serena

# Step 2: Set environment variables
$env:PROJECT_ROOT = (Get-Location).Path
$env:LANGUAGE_SERVERS_DIR = "build\language_servers"
$env:RUNTIMES_DIR = "build\runtimes"
$env:SERENA_VERSION = "0.1.4"
$env:SERENA_BUILD_TIER = "essential"

# Step 3: Generate Windows version info
cd scripts\pyinstaller
python build_version_info.py

# Step 4: Run PyInstaller
pyinstaller serena-windows.spec

# Output will be in: dist\serena-windows\
```

### Option 3: Minimal Test Build

Fastest build for testing (no language servers/runtimes):

```powershell
cd scripts\pyinstaller
$env:PROJECT_ROOT = (Resolve-Path ..\..).Path
python build_version_info.py
pyinstaller serena-windows.spec
```

---

## Build Process Explained

### Phase 1: Analysis

PyInstaller scans the code to find all dependencies:

```
[1/3] Analyzing serena-mcp-server entry point...
[2/3] Analyzing serena CLI entry point...
[3/3] Analyzing index-project entry point...
```

**What happens:**
- Static analysis of imports
- Detection of data files
- Identification of binary dependencies

**Common issues:**
- Dynamic imports missed → Fix: Add to `hidden_imports`
- Missing data files → Fix: Add to `datas`

### Phase 2: PYZ Creation

Compiles Python modules into compressed archives:

```python
pyz_mcp = PYZ(mcp_server_analysis.pure, mcp_server_analysis.zipped_data)
```

**Benefits:**
- Faster startup (pre-compiled bytecode)
- Reduced file count
- Better compression

### Phase 3: EXE Creation

Creates Windows executables:

```python
exe_mcp_server = EXE(
    pyz_mcp,
    mcp_server_analysis.scripts,
    name='serena-mcp-server',
    version=version_info,  # Windows metadata
    icon=icon,              # Executable icon
    console=True,           # Show console window
)
```

**Three executables created:**
1. `serena-mcp-server.exe` - Main MCP server
2. `serena.exe` - CLI interface (calls `serena.cli:main`)
3. `index-project.exe` - Project indexing (deprecated, calls `serena.cli:index_project`)

### Phase 4: COLLECT (Bundle Creation)

**CRITICAL PHASE** - Creates directory bundle:

```python
coll = COLLECT(
    exe_mcp_server,
    exe_serena,
    exe_index_project,
    mcp_server_analysis.binaries,
    mcp_server_analysis.zipfiles,
    mcp_server_analysis.datas,
    name='serena-windows',
)
```

**Output structure:**

```
dist/serena-windows/
├── serena-mcp-server.exe       # Main entry point (25-30 MB)
├── serena.exe                  # CLI wrapper (25-30 MB)
├── index-project.exe           # Indexing tool (25-30 MB)
├── _internal/                  # Python runtime & libraries (~150 MB)
│   ├── base_library.zip        # Standard library (compressed)
│   ├── python311.dll           # Python runtime
│   ├── *.pyd                   # Compiled extensions
│   └── ...
├── serena/                     # Application resources
│   └── resources/              # Configs, templates, dashboard
│       ├── config/
│       │   ├── contexts/
│       │   ├── modes/
│       │   └── prompt_templates/
│       ├── dashboard/          # Web dashboard assets
│       │   ├── index.html
│       │   ├── dashboard.js
│       │   └── *.png
│       ├── project.template.yml
│       └── serena_config.template.yml
├── language_servers/           # LSP servers (if bundled)
│   ├── pyright/
│   ├── rust-analyzer/
│   ├── gopls/
│   └── ...
└── runtimes/                   # Portable runtimes (if bundled)
    ├── nodejs/
    │   ├── node.exe
    │   └── ...
    ├── dotnet/
    └── java/
```

---

## Hidden Imports Analysis

### Why Hidden Imports Are Needed

PyInstaller's static analysis cannot detect:
1. **Dynamic imports** - `importlib.import_module()`
2. **Plugin systems** - Language server discovery
3. **Lazy imports** - Deferred module loading
4. **String-based imports** - `__import__('module_name')`

### Comprehensive Import List

#### Serena Core (30 modules)
```python
'serena.agent',
'serena.cli',
'serena.mcp',
'serena.project',
'serena.dashboard',
'serena.runtime_manager',  # NEW: Portable runtime support
# ... (see spec file for complete list)
```

#### SolidLSP (45 modules)
```python
'solidlsp.ls',
'solidlsp.ls_handler',
'solidlsp.language_servers.pyright_server',
'solidlsp.language_servers.gopls',
# ... ALL language servers included
```

#### External Dependencies (120+ modules)
```python
# MCP Protocol
'mcp.server.fastmcp',
'mcp.server.stdio',
'mcp.server.sse',

# Anthropic SDK
'anthropic.types',
'anthropic.resources',

# Configuration
'ruamel.yaml',
'jinja2.ext',
'click.core',

# Data validation
'pydantic',
'pydantic_core',

# Utilities
'psutil',
'tiktoken',
'tiktoken_ext.openai_public',  # NEW: Token counting

# Web framework
'flask.app',
'werkzeug.serving',
```

#### Windows-Specific (10 modules)
```python
'win32api',
'win32process',
'win32file',
'win32com.client',  # NEW: COM automation
'pywintypes',
```

### Testing Hidden Imports

After build, test for missing imports:

```powershell
cd dist\serena-windows
.\serena-mcp-server.exe --help

# Watch for ModuleNotFoundError
# If found, add to hidden_imports in spec file
```

---

## Data Files Mapping

### 1. Serena Resources (Required)

**Source:** `src/serena/resources/`
**Destination:** `serena/resources/`
**Size:** ~500 KB

**Contents:**
```
serena/resources/
├── config/
│   ├── contexts/               # Built-in contexts (5 files, ~15 KB)
│   ├── modes/                  # Built-in modes (6 files, ~20 KB)
│   ├── internal_modes/         # Special modes (1 file, ~5 KB)
│   └── prompt_templates/       # System prompts (2 files, ~10 KB)
├── dashboard/                  # Web UI (8 files, ~400 KB)
│   ├── index.html
│   ├── dashboard.js
│   ├── jquery.min.js
│   └── *.png                   # Icons
├── project.template.yml        # Project config template
└── serena_config.template.yml  # User config template
```

**Critical:** Without these files, Serena cannot start!

### 2. Language Servers (Optional, Recommended)

**Source:** `build/language_servers/` (downloaded separately)
**Destination:** `language_servers/`
**Size:** 45 MB (essential) to 250+ MB (full)

**Essential tier servers:**
```
language_servers/
├── pyright/                    # Python (~25 MB)
│   ├── langserver.index.js
│   └── node_modules/
├── rust-analyzer/              # Rust (~15 MB)
│   └── rust-analyzer.exe
├── gopls/                      # Go (~12 MB)
│   └── gopls.exe
└── typescript-language-server/ # TypeScript (~45 MB)
    ├── lib/
    └── node_modules/
```

**How to download:**
```powershell
cd scripts\build-windows
.\download-language-servers.ps1 -Tier essential -OutputDir ..\..\build\language_servers
```

### 3. Portable Runtimes (Optional, For Offline)

**Source:** `build/runtimes/` (downloaded separately)
**Destination:** `runtimes/`
**Size:** ~200-400 MB

**Contents:**
```
runtimes/
├── nodejs/                     # Node.js 20.x (~40 MB)
│   ├── node.exe
│   └── ...
├── dotnet/                     # .NET 9.0 (~150 MB)
│   ├── dotnet.exe
│   └── ...
└── java/                       # Java 21 (~200 MB)
    ├── bin/
    │   └── java.exe
    └── lib/
```

**Enables offline operation** for language servers requiring these runtimes.

### 4. Tiktoken Cache (Optional, Recommended)

**Source:** `tiktoken/_tiktoken_data/` (from tiktoken package)
**Destination:** `tiktoken/_tiktoken_data/`
**Size:** ~5 MB

**Purpose:** Token counting for AI model context management
**Benefit:** Avoids first-run download

---

## Subprocess Compatibility

### The Critical Issue: ONEFILE vs ONEDIR

**Problem with ONEFILE:**
```python
# In ONEFILE mode, sys.executable points to temporary extraction directory
# Language servers spawn as subprocesses and cannot find dependencies
subprocess.Popen(['pyright', '--stdio'])  # FAILS in ONEFILE
```

**Solution with ONEDIR:**
```python
# In ONEDIR mode, sys.executable points to actual .exe
# Subprocesses can access _internal/ directory for dependencies
subprocess.Popen(['pyright', '--stdio'])  # WORKS in ONEDIR
```

### How Serena Uses Subprocesses

**1. Language Server Spawning (`ls_handler.py`):**
```python
process = subprocess.Popen(
    [ls_executable, '--stdio'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    creationflags=subprocess.CREATE_NO_WINDOW  # Windows: hide window
)
```

**2. Runtime Detection (`runtime_manager.py`):**
```python
if getattr(sys, 'frozen', False):
    # Running in PyInstaller bundle
    app_dir = Path(sys._MEIPASS)  # ONEDIR: points to _internal/
```

**3. Shell Commands (`util/shell.py`):**
```python
process = subprocess.Popen(
    command,
    shell=True,
    **subprocess_kwargs()  # Uses CREATE_NO_WINDOW on Windows
)
```

### Testing Subprocess Functionality

```powershell
# Test 1: Verify sys.executable
cd dist\serena-windows
.\serena-mcp-server.exe

# In logs, check:
# sys.executable = C:\path\to\dist\serena-windows\serena-mcp-server.exe
# sys._MEIPASS = C:\path\to\dist\serena-windows\_internal

# Test 2: Language server spawn
cd dist\serena-windows
.\serena.exe project index C:\path\to\test\project

# Should successfully spawn language server subprocess

# Test 3: Runtime detection
.\serena.exe --version
# Should work without errors
```

---

## Estimated Bundle Size

### Breakdown by Component

| Component | Minimal | Essential | Complete | Full |
|-----------|---------|-----------|----------|------|
| **Python Runtime** | 50 MB | 50 MB | 50 MB | 50 MB |
| **Serena Core** | 80 MB | 80 MB | 80 MB | 80 MB |
| **Language Servers** | 0 MB | 45 MB | 120 MB | 250+ MB |
| **Portable Runtimes** | 0 MB | 0 MB | 200 MB | 400 MB |
| **Total** | **130 MB** | **175 MB** | **450 MB** | **780+ MB** |

### Size Optimization

**Already Implemented:**
- ✅ Binary stripping (`STRIP_BINARIES = True`)
- ✅ Module exclusions (numpy, pandas, torch, etc.)
- ✅ PYZ compression
- ✅ UPX disabled (causes antivirus flags)

**Future Optimizations:**
- Could use UPX on select binaries (risky)
- Could compress language_servers/ directory
- Could implement on-demand language server download

### Disk Space Requirements

**Build Process:**
- Source code: 50 MB
- Virtual environment: 200 MB
- Build directory: 500 MB
- Final dist: 130-780 MB
- **Total:** ~1.5 GB free space recommended

**Runtime (User):**
- Installation: 130-780 MB (depending on tier)
- Project caches: 10-100 MB per project
- Logs: 1-10 MB
- **Total:** ~200-900 MB

---

## Testing the Build

### Basic Functionality Tests

```powershell
cd dist\serena-windows

# Test 1: CLI help
.\serena.exe --help

# Test 2: Version check
.\serena.exe --version

# Test 3: Start MCP server
.\serena-mcp-server.exe --help

# Test 4: Project indexing (requires test project)
.\serena.exe project index C:\path\to\test\project

# Test 5: Tool listing
.\serena.exe tools list
```

### Advanced Tests

```powershell
# Test: Language server functionality
cd dist\serena-windows
.\serena.exe project index C:\path\to\python\project
# Should spawn pyright subprocess

# Test: Dashboard (if enabled)
.\serena-mcp-server.exe --transport sse --enable-web-dashboard true
# Open http://localhost:8000 in browser

# Test: Portable mode (if runtimes bundled)
$env:SERENA_OFFLINE_MODE = "1"
.\serena-mcp-server.exe --help
# Should use bundled Node.js/.NET/Java
```

### Automated Test Script

```powershell
# scripts\build-windows\test-portable.ps1
cd scripts\build-windows
.\test-portable.ps1 -BuildDir ..\..\dist\serena-windows
```

### Performance Benchmarks

**Expected Startup Times:**
- CLI help: < 1 second
- MCP server: 2-3 seconds
- Project indexing: 5-30 seconds (depends on project size)
- Language server spawn: 1-5 seconds

**Memory Usage:**
- Idle: ~150 MB
- Indexing: 300-500 MB
- With language server: 400-800 MB

---

## Troubleshooting

### Common Issues

#### 1. ModuleNotFoundError: No module named 'X'

**Cause:** Missing hidden import
**Solution:**
```python
# In serena-windows.spec, add to hidden_imports:
hidden_imports = [
    # ... existing imports
    'missing_module_name',
]
```

#### 2. FileNotFoundError: [Errno 2] No such file or directory

**Cause:** Missing data file
**Solution:**
```python
# In serena-windows.spec, add to datas:
datas = [
    # ... existing datas
    ('path/to/source', 'destination/in/bundle'),
]
```

#### 3. Language Server Not Found

**Symptoms:**
```
Error: Language server executable not found: pyright
```

**Solution:**
```powershell
# Option 1: Bundle language servers at build time
$env:LANGUAGE_SERVERS_DIR = "C:\path\to\language_servers"
pyinstaller serena-windows.spec

# Option 2: Download after deployment
cd dist\serena-windows
.\serena.exe tools list  # Will auto-download on first use
```

#### 4. Subprocess Spawn Failure

**Symptoms:**
```
OSError: [WinError 2] The system cannot find the file specified
```

**Cause:** ONEFILE mode or missing runtime

**Solution:**
- Verify using ONEDIR mode (check spec file)
- Bundle portable runtimes or install Node.js/Java/.NET

#### 5. Antivirus False Positive

**Symptoms:** Windows Defender quarantines .exe

**Solutions:**
1. **Add exception:**
   ```powershell
   Add-MpPreference -ExclusionPath "C:\path\to\dist\serena-windows"
   ```

2. **Code signing (recommended for distribution):**
   ```powershell
   # Requires code signing certificate
   signtool sign /f certificate.pfx /p password serena-mcp-server.exe
   ```

3. **Disable UPX** (already done in our spec)

#### 6. Missing Windows Metadata

**Symptoms:** File properties show no version info

**Solution:**
```powershell
cd scripts\pyinstaller
python build_version_info.py
pyinstaller serena-windows.spec
```

#### 7. Large Bundle Size

**If bundle is unexpectedly large (>1 GB):**

```powershell
# Analyze bundle contents
pyinstaller --log-level DEBUG serena-windows.spec > build.log

# Check for unexpected inclusions
findstr /i "numpy\|pandas\|torch" build.log

# Add to excludes in spec file if found
```

---

## Build Command Reference

### Full Build with All Options

```powershell
# Set all environment variables
$env:PROJECT_ROOT = (Get-Location).Path
$env:LANGUAGE_SERVERS_DIR = "build\language_servers"
$env:RUNTIMES_DIR = "build\runtimes"
$env:SERENA_VERSION = "0.1.4"
$env:SERENA_BUILD_TIER = "essential"

# Generate version info
cd scripts\pyinstaller
python build_version_info.py

# Build with PyInstaller
pyinstaller `
    --clean `
    --noconfirm `
    --log-level INFO `
    serena-windows.spec

# Output: dist\serena-windows\
```

### Quick Rebuild (Skip Clean)

```powershell
cd scripts\pyinstaller
pyinstaller --noconfirm serena-windows.spec
```

### Debug Build

```powershell
cd scripts\pyinstaller
pyinstaller `
    --clean `
    --noconfirm `
    --log-level DEBUG `
    serena-windows.spec > build-debug.log 2>&1
```

### Custom Output Directory

```powershell
cd scripts\pyinstaller
pyinstaller `
    --distpath C:\custom\output\dist `
    --workpath C:\custom\output\build `
    serena-windows.spec
```

---

## Next Steps

### For Development

1. **Test the build:**
   ```powershell
   scripts\build-windows\test-portable.ps1
   ```

2. **Iterate on spec file:**
   - Add missing imports
   - Include additional data files
   - Optimize bundle size

3. **Create icon:**
   - Place `serena.ico` in `scripts/pyinstaller/`
   - Use online converter: https://convertio.co/png-ico/

### For Distribution

1. **Create installer:**
   - Use Inno Setup: https://jrsoftware.org/isinfo.php
   - Or WiX Toolset: https://wixtoolset.org/

2. **Code signing:**
   - Obtain certificate from trusted CA
   - Sign all .exe files
   - Submit to Microsoft for reputation building

3. **Package for release:**
   ```powershell
   Compress-Archive `
       -Path dist\serena-windows\* `
       -DestinationPath serena-windows-v0.1.4-x64.zip
   ```

4. **Upload to GitHub:**
   - Create release on GitHub
   - Attach ZIP file
   - Update installation instructions

---

## Support

**Issues:** https://github.com/oraios/serena/issues
**Documentation:** https://github.com/oraios/serena/docs
**Build System:** See `docs/WINDOWS-PORTABLE-BUILD.md`

---

**Build Guide Version:** 1.0.0
**Last Updated:** 2025-01-12
**Tested On:** Windows 10 22H2, Windows 11 23H2
**Python Version:** 3.11.9
**PyInstaller Version:** 6.11.0
