# Windows Portable Package Build System

**Production-ready CI/CD-capable build automation for Serena MCP Windows portable packages.**

## Quick Start

```powershell
# Navigate to this directory
cd scripts/build-windows

# Run a standard build
.\build-windows-portable.ps1 -Tier essential -Clean
```

That's it! The script will:
1. Validate your environment
2. Install dependencies
3. Run tests
4. Download language servers
5. Build executables with PyInstaller
6. Create package directory
7. Copy all files
8. Create ZIP archive
9. Generate checksums
10. Create build manifest

**Build time:** 6-8 minutes (essential tier, first run)

## What This System Does

This automated build system creates self-contained Windows portable packages of Serena MCP that can run from any directory without installation.

### Features

- **10 automated build stages** with comprehensive error handling
- **4 language server tiers** (minimal, essential, complete, full)
- **Multi-architecture support** (x64, x86, ARM64)
- **Parallel operations** for faster builds
- **Comprehensive logging** with detailed progress reporting
- **Build manifests** with complete metadata tracking
- **Checksum generation** for integrity verification
- **CI/CD ready** with examples for GitHub Actions, Azure Pipelines, and Jenkins

## Prerequisites

| Software | Version | Required | Purpose |
|----------|---------|----------|---------|
| **Python** | 3.11.x | ✓ Yes | Runtime environment |
| **uv** | Latest | ✓ Yes | Package management |
| **PowerShell** | 5.1+ | ✓ Yes | Build automation |
| Node.js | 20.x | Optional | For TS/JS language servers |
| Git | Latest | Optional | Version detection |

**System Requirements:**
- Windows 10 (1903+) or Windows 11
- 8GB RAM (16GB recommended)
- 5-15 GB free disk space (tier-dependent)

**Installation:**
```powershell
# Install Python 3.11
# Download from: https://www.python.org/downloads/

# Install uv (PowerShell)
irm https://astral.sh/uv/install.ps1 | iex

# Verify installations
python --version    # Should show Python 3.11.x
uv --version        # Should show uv version
```

## Usage

### Basic Usage

```powershell
# Essential tier (recommended for most users)
.\build-windows-portable.ps1 -Tier essential -Clean
```

### Advanced Usage

```powershell
# Complete tier with custom output directory
.\build-windows-portable.ps1 `
    -Tier complete `
    -Version "1.0.0" `
    -OutputDir "C:\builds\serena" `
    -Clean

# Full tier for ARM64
.\build-windows-portable.ps1 `
    -Tier full `
    -Architecture arm64

# Quick development build (minimal, skip tests)
.\build-windows-portable.ps1 `
    -Tier minimal `
    -SkipTests `
    -NoArchive
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Tier` | Required | - | Language server tier: minimal, essential, complete, full |
| `-Version` | Optional | Auto-detect | Override version string |
| `-OutputDir` | Optional | dist\windows | Build output directory |
| `-Architecture` | Optional | x64 | Target architecture: x64, x86, arm64 |
| `-Clean` | Switch | Off | Remove previous build artifacts |
| `-SkipTests` | Switch | Off | Skip test execution (not recommended) |
| `-SkipLanguageServers` | Switch | Off | Skip language server downloads |
| `-NoArchive` | Switch | Off | Don't create ZIP archive |
| `-Parallel` | Optional | 4 | Number of parallel operations |

## Language Server Tiers

| Tier | Languages | Size | Build Time | Use Case |
|------|-----------|------|------------|----------|
| **minimal** | None | ~150 MB | ~3-4 min | Testing, minimal deployments |
| **essential** | Python, TS, Go, C# | ~400 MB | ~6-8 min | **Recommended** for most users |
| **complete** | + Java, Rust, Kotlin, Clojure | ~700 MB | ~10-12 min | Multi-language projects |
| **full** | All 28+ languages | ~1.5 GB | ~15-20 min | Maximum language support |

## Output Structure

```
dist/windows/
├── serena-portable-v0.1.4-windows-x64-essential/    # Package directory
│   ├── bin/                                          # Executables
│   │   ├── serena-mcp-server.exe                    # Main MCP server
│   │   ├── serena.exe                               # CLI interface
│   │   └── index-project.exe                        # Project indexing
│   ├── config/                                       # Configuration files
│   ├── docs/                                         # Documentation
│   ├── language_servers/                            # Language servers (tier-dependent)
│   ├── scripts/                                      # Helper scripts
│   ├── serena-portable.bat                          # Launcher script
│   └── VERSION.txt                                  # Version information
├── serena-portable-v0.1.4-windows-x64-essential.zip # ZIP archive
├── serena-portable-v0.1.4-windows-x64-essential.zip.sha256  # Checksum
├── build.log                                        # Build log
├── build-manifest-20250112-143022.json             # Build manifest (timestamped)
└── build-manifest-latest.json                       # Build manifest (latest)
```

## Build Stages

The build process consists of 10 automated stages:

1. **Environment Validation** (~3s) - Verify Python 3.11, uv, system requirements
2. **Dependency Resolution** (~30s) - Install Python packages and PyInstaller
3. **Tests Execution** (~120s) - Run type checks, linting, and core tests
4. **Language Server Bundling** (~90s) - Download and extract language servers
5. **PyInstaller Build** (~180s) - Build 3 executables with PyInstaller
6. **Directory Structure** (~1s) - Create package directory structure
7. **File Copying** (~15s) - Copy executables, configs, docs
8. **Archive Creation** (~30s) - Create ZIP archive with compression
9. **Checksum Generation** (~5s) - Generate SHA256 checksums
10. **Manifest Generation** (~1s) - Create build manifest JSON

**Total Time:** ~6-8 minutes (essential tier, cached dependencies)

## Build Time & Size Estimates

### By Tier (First Run)

| Tier | Build Time | Directory Size | Archive Size |
|------|-----------|----------------|--------------|
| **Minimal** | 3-4 min | 150 MB | 80 MB |
| **Essential** | 6-8 min | 400 MB | 200 MB |
| **Complete** | 10-12 min | 700 MB | 350 MB |
| **Full** | 15-20 min | 1.5 GB | 750 MB |

### By Tier (Cached)

| Tier | Build Time | Details |
|------|-----------|---------|
| **Minimal** | ~2 min | No language servers |
| **Essential** | 3-4 min | Cached downloads |
| **Complete** | 4-5 min | Cached downloads |
| **Full** | 6-8 min | Cached downloads |

## Testing the Build

After building, test with the included test script:

```powershell
.\test-portable.ps1 -PackagePath "dist\windows\serena-portable-v0.1.4-windows-x64-essential"
```

**Manual testing:**
```powershell
# Navigate to package directory
cd dist\windows\serena-portable-v0.1.4-windows-x64-essential

# Test executables
.\bin\serena-mcp-server.exe --version
.\bin\serena.exe --version
.\bin\index-project.exe --version

# Test launcher
.\serena-portable.bat --help
```

## Build Manifest

Every build generates a detailed JSON manifest:

```json
{
  "build_id": "20250112-143022",
  "version": "0.1.4",
  "tier": "essential",
  "architecture": "x64",
  "build_duration_seconds": 485.7,
  "stages": {
    "1_environment_validation": { "status": "completed", "duration_seconds": 2.5 },
    "5_pyinstaller_build": { "status": "completed", "duration_seconds": 180.6 }
  },
  "package": {
    "name": "serena-portable-v0.1.4-windows-x64-essential",
    "dir_size_mb": 380.5,
    "archive_size_mb": 156.2
  },
  "checksums": {
    "archive": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6...",
    "serena-mcp-server.exe": "b2c3d4e5f6g7h8..."
  }
}
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Build Windows Portable
on: [push, workflow_dispatch]

jobs:
  build:
    runs-on: windows-latest
    strategy:
      matrix:
        tier: [essential, complete, full]

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install uv
        run: irm https://astral.sh/uv/install.ps1 | iex

      - name: Build
        run: |
          cd scripts/build-windows
          .\build-windows-portable.ps1 -Tier ${{ matrix.tier }} -Clean

      - uses: actions/upload-artifact@v4
        with:
          name: serena-portable-${{ matrix.tier }}
          path: dist/windows/*.zip
```

See **BUILD-GUIDE.md** for Azure Pipelines and Jenkins examples.

## Troubleshooting

### Common Issues

**Problem:** "Python 3.11 required"
```powershell
# Check Python version
python --version

# Install Python 3.11 from: https://www.python.org/downloads/
```

**Problem:** "uv not found"
```powershell
# Install uv
irm https://astral.sh/uv/install.ps1 | iex

# Restart PowerShell
```

**Problem:** "Path too long"
```powershell
# Use shorter output directory
.\build-windows-portable.ps1 -Tier essential -OutputDir "C:\build"
```

**Problem:** Build fails during PyInstaller
```powershell
# Check build log
Get-Content dist\windows\build.log -Tail 50

# Run manually with verbose output
cd [repo-root]
uv run pyinstaller scripts/pyinstaller/serena.spec --log-level DEBUG
```

See **BUILD-GUIDE.md** for comprehensive troubleshooting.

## Documentation

| Document | Purpose |
|----------|---------|
| **README.md** (this file) | Quick start and overview |
| **BUILD-GUIDE.md** | Comprehensive build guide with detailed instructions |
| **DIRECTORY-STRUCTURE.md** | Package directory structure template |
| **TESTING-CHECKLIST.md** | 150+ test validation checks |
| **build-manifest-schema.json** | JSON schema for build manifests |
| **DELIVERABLES.md** | Complete documentation of deliverables |

## Development

### Project Structure

```
scripts/build-windows/
├── build-windows-portable.ps1      # Master build script
├── download-language-servers.ps1   # Language server downloader
├── download-runtimes.ps1           # Runtime downloader (optional)
├── test-portable.ps1               # Build testing script
├── serena-portable.bat             # Launcher script template
├── launcher-config.json            # Launcher configuration template
├── language-servers-manifest.json  # Language server definitions
│
├── README.md                       # This file
├── BUILD-GUIDE.md                  # Comprehensive build guide
├── DIRECTORY-STRUCTURE.md          # Structure documentation
├── TESTING-CHECKLIST.md            # Testing checklist
├── build-manifest-schema.json      # Manifest schema
└── DELIVERABLES.md                 # Deliverables summary
```

### Making Changes

1. Update `build-windows-portable.ps1` for new features
2. Update documentation to match
3. Update `build-manifest-schema.json` if manifest changes
4. Test with all tiers before committing
5. Update version in script header

## Support

### Getting Help

1. Check build log: `dist/windows/build.log`
2. Check manifest: `dist/windows/build-manifest-latest.json`
3. Review **BUILD-GUIDE.md** troubleshooting section
4. Check **TESTING-CHECKLIST.md** for validation

### Reporting Issues

When reporting build issues, include:
- Build log: `dist/windows/build.log`
- Build manifest: `dist/windows/build-manifest-latest.json`
- Command used
- Error messages
- System information (OS version, Python version, uv version)

## Performance Tips

1. **Use caching:** Dependencies and downloads are cached between builds
2. **Use parallel operations:** Increase `-Parallel` for faster downloads
3. **Skip tests in development:** Use `-SkipTests` for faster iteration
4. **Use minimal tier for testing:** Faster builds when testing build system
5. **Use `-NoArchive` for development:** Skip compression during iteration

## Best Practices

### Production Builds

```powershell
# Always use -Clean for production builds
.\build-windows-portable.ps1 -Tier essential -Clean

# Don't skip tests in production
# DON'T use -SkipTests for releases

# Always verify checksums
Get-Content dist\windows\*.sha256
```

### Development Builds

```powershell
# Use minimal tier for fast iteration
.\build-windows-portable.ps1 -Tier minimal -SkipTests -NoArchive

# Test with essential tier before release
.\build-windows-portable.ps1 -Tier essential
```

### CI/CD Builds

```powershell
# Use clean builds
.\build-windows-portable.ps1 -Tier essential -Clean

# Cache dependencies between runs
# Generate artifacts for all tiers
# Upload manifests for traceability
```

## Version History

- **v1.0.0** (2025-01-12) - Initial release
  - 10-stage automated build process
  - 4 language server tiers
  - Multi-architecture support
  - Comprehensive documentation
  - CI/CD integration examples

## License

This build system is part of Serena MCP and follows the same license (MIT).

## Authors

- Serena Development Team
- Build automation by Claude Code

## Contributing

When contributing to the build system:

1. Test all tiers before submitting
2. Update documentation for any changes
3. Maintain backward compatibility
4. Follow PowerShell best practices
5. Update version history

---

**Need More Detail?** See **BUILD-GUIDE.md** for comprehensive documentation.

**Ready to Build?** Run: `.\build-windows-portable.ps1 -Tier essential -Clean`

**Questions?** Check the troubleshooting section in **BUILD-GUIDE.md**.
