# Serena Build Scripts

This directory contains build automation scripts for creating production-ready portable distributions of Serena.

## Windows Portable Build System

### Master Build Script: `build-windows-portable.ps1`

Complete CI/CD-ready build automation that orchestrates all stages of creating a Windows portable package.

**Features:**
- Environment validation (Python 3.11, uv, PyInstaller)
- Dependency installation with uv sync
- Automated testing (type-check, lint, pytest)
- Language server bundling
- PyInstaller executable creation
- Directory structure generation
- Comprehensive documentation
- ZIP archive with checksums
- Detailed build manifest

**Usage:**

```powershell
# Default build (essential tier, x64, with tests)
.\scripts\build-windows-portable.ps1

# Full build with all language servers
.\scripts\build-windows-portable.ps1 -Tier full -Clean

# Fast development build (no tests, no language servers)
.\scripts\build-windows-portable.ps1 -SkipTests -SkipLanguageServers -NoArchive

# ARM64 build
.\scripts\build-windows-portable.ps1 -Architecture arm64

# Custom version and output directory
.\scripts\build-windows-portable.ps1 -Version "0.2.0-beta" -OutputDir "C:\builds"
```

**Parameters:**
- `-Tier <minimal|essential|complete|full>` - Language server bundle tier
- `-Version <string>` - Version string (auto-detected from pyproject.toml if not specified)
- `-OutputDir <path>` - Output directory (default: dist/windows)
- `-Architecture <x64|arm64>` - Target architecture
- `-Clean` - Remove previous builds
- `-SkipTests` - Skip type-checking, linting, and tests
- `-SkipLanguageServers` - Skip language server bundling
- `-NoArchive` - Skip ZIP creation
- `-NoChecksums` - Skip SHA256 checksum generation
- `-Verbose` - Enable verbose logging

**Output Structure:**
```
dist/windows/
├── serena-portable-v{VERSION}-windows-{ARCH}-{TIER}/
│   ├── bin/                    # Executables and Python runtime
│   │   ├── serena-mcp-server.exe
│   │   ├── serena.exe
│   │   ├── index-project.exe
│   │   └── _internal/          # PyInstaller bundle
│   ├── language_servers/       # LSP servers
│   ├── config/                 # Configuration examples
│   ├── docs/                   # Documentation
│   ├── scripts/                # Launcher scripts
│   ├── INSTALL.md             # Installation guide
│   └── BUILD-MANIFEST.json    # Build metadata
├── serena-portable-*.zip      # Compressed archive
├── serena-portable-*.zip.sha256  # Checksum
└── build-manifest.json        # Top-level build info
```

**Build Stages:**
1. Environment Validation - Check prerequisites
2. Dependency Installation - Install with uv sync
3. Test Execution - Run type-check, lint, pytest
4. Language Server Bundling - Bundle LSP servers
5. PyInstaller Build - Create executables
6. Directory Structure Creation - Set up package layout
7. File Copying - Copy artifacts, docs, configs
8. ZIP Archive Creation - Compress package
9. Checksum Generation - Create SHA256 checksums
10. Build Manifest Generation - Generate metadata

**Logging:**
- Console output with color-coded messages
- Detailed log file: `build.log` in project root
- Build manifest with statistics: `build-manifest.json`

### Language Server Bundler: `bundle-language-servers-windows.ps1`

Downloads and bundles language servers for offline Windows installation.

**Usage:**

```powershell
# Bundle essential tier language servers
.\scripts\bundle-language-servers-windows.ps1

# Custom output directory and architecture
.\scripts\bundle-language-servers-windows.ps1 -OutputDir "C:\ls-bundle" -Architecture arm64

# Force re-download and skip checksums
.\scripts\bundle-language-servers-windows.ps1 -Force -SkipChecksums
```

**Bundled Language Servers (Essential Tier):**
- Python (Pyright) - npm package
- TypeScript Language Server - npm package
- rust-analyzer - GitHub binary
- gopls (Go) - GitHub binary
- Lua Language Server - GitHub binary
- Marksman (Markdown) - GitHub binary
- Node.js 20.11.1 portable runtime

**Output:**
```
serena-ls-bundle/
├── language_servers/
│   ├── python/
│   ├── typescript/
│   ├── rust/
│   ├── go/
│   ├── lua/
│   └── markdown/
├── runtimes/
│   └── nodejs/
├── bundle-manifest.json
└── INSTALLATION.md
```

## PyInstaller Configuration

### Spec File: `pyinstaller/serena-windows.spec`

Comprehensive PyInstaller specification for Windows builds.

**Key Features:**
- ONEDIR mode (required for LSP subprocess compatibility)
- Three separate executables (serena-mcp-server, serena, index-project)
- Comprehensive hidden imports (170+ modules)
- Data file bundling (resources, configs, language servers)
- Windows metadata (version info, icon)
- Optimized exclusions for reduced size

**Environment Variables:**
- `PROJECT_ROOT` - Project root directory
- `LANGUAGE_SERVERS_DIR` - Path to language server bundle
- `RUNTIMES_DIR` - Path to portable runtimes
- `SERENA_VERSION` - Version string
- `SERENA_BUILD_TIER` - Language server tier

**Build with spec file directly:**
```powershell
$env:PROJECT_ROOT = "C:\path\to\serena"
$env:SERENA_VERSION = "0.1.4"
pyinstaller scripts\pyinstaller\serena-windows.spec
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Windows Portable

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python 3.11
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install uv
        run: pip install uv

      - name: Build Windows Portable
        run: |
          .\scripts\build-windows-portable.ps1 -Tier full -Clean

      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: windows-portable
          path: dist/windows/*.zip
```

### Azure DevOps Pipeline

```yaml
trigger:
  tags:
    include:
      - v*

pool:
  vmImage: 'windows-latest'

steps:
- task: UsePythonVersion@0
  inputs:
    versionSpec: '3.11'

- powershell: |
    pip install uv
    .\scripts\build-windows-portable.ps1 -Tier essential -Clean
  displayName: 'Build Windows Portable'

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: 'dist/windows'
    artifactName: 'windows-portable'
```

## Development Workflow

### Testing the Build System

```powershell
# Fast test build (no tests, no language servers, no archive)
.\scripts\build-windows-portable.ps1 -SkipTests -SkipLanguageServers -NoArchive

# Test with language servers but no archive
.\scripts\build-windows-portable.ps1 -SkipTests -NoArchive

# Full test build
.\scripts\build-windows-portable.ps1 -Clean
```

### Debugging Build Issues

1. **Check build.log** - Detailed log in project root
2. **Check build-manifest.json** - Build metadata and statistics
3. **Run with -Verbose** - Enable debug logging
4. **Test individual stages** - Run scripts manually

### Modifying the Build

**To add a new build stage:**
1. Add stage name to `$StageNames` array
2. Create function with `Write-StageHeader`
3. Add function call to `Start-Build`
4. Update `$TotalStages` count

**To customize package contents:**
1. Modify `Copy-BuildArtifacts` function
2. Update `New-InstallationGuide` documentation
3. Adjust directory structure in `New-PortableStructure`

**To add new language servers:**
1. Update `bundle-language-servers-windows.ps1`
2. Add to tier definitions
3. Update documentation

## Requirements

### Build Machine Requirements
- Windows 10/11 (x64 or ARM64)
- PowerShell 5.1 or higher
- Python 3.11 (not 3.12+)
- uv package manager
- PyInstaller (auto-installed)
- 2+ GB free disk space
- Internet connection (for first-time language server downloads)

### Target System Requirements
- Windows 10/11 (x64 or ARM64)
- No Python installation required
- No internet connection required (with bundled language servers)
- ~200-500 MB disk space (depending on tier)

## Troubleshooting

### Build Fails at Environment Validation
- Ensure Python 3.11 is installed and in PATH
- Install uv: `pip install uv`
- Verify PowerShell version: `$PSVersionTable.PSVersion`

### Build Fails at PyInstaller Stage
- Check PyInstaller spec file exists
- Verify all source files are present
- Check build.log for detailed errors

### Language Server Bundling Fails
- Language server bundle is optional
- Build continues without bundled servers
- Servers can be downloaded on first use

### ZIP Creation Fails
- Check disk space
- Verify write permissions
- Try without compression: `-NoArchive`

### Tests Fail
- Run tests manually: `uv run poe test`
- Skip tests for development: `-SkipTests`

## License

These build scripts are part of Serena and licensed under the MIT License.

## Support

For issues with the build system:
1. Check build.log for detailed errors
2. Review build-manifest.json for build statistics
3. Open an issue at: https://github.com/oraios/serena/issues
