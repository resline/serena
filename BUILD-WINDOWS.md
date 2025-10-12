# Building Serena for Windows

This guide covers building Serena Windows portable packages with bundled language servers and runtimes.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Build Tiers](#build-tiers)
- [Build Parameters](#build-parameters)
- [Architecture Support](#architecture-support)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [CI/CD Integration](#cicd-integration)

## Overview

Serena supports building self-contained Windows portable packages with:

- **Standalone executable** - Single .exe file with Python runtime embedded
- **Bundled language servers** - Pre-configured LSP servers for offline use
- **Portable runtimes** - Node.js and .NET runtimes included when needed
- **Multiple tiers** - Choose the right size/feature balance
- **Architecture support** - Native builds for x64 and ARM64

### Build System Features

- Fully automated GitHub Actions workflow
- Parallel language server downloads
- Intelligent caching for faster builds
- Quality checks (formatting, linting, type checking)
- Comprehensive documentation and installers

## Prerequisites

### Required Software

1. **Python 3.11.x** (NOT 3.12 or higher)
   - Download: https://www.python.org/downloads/
   - Verify: `python --version`

2. **UV Package Manager** (latest version)
   - Install: `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`
   - Verify: `uv --version`

3. **PyInstaller 6.11.1** (installed automatically)

### System Requirements

- **OS**: Windows 10 (1809+), Windows 11, or Windows Server 2019/2022
- **Architecture**: x64 or ARM64
- **RAM**: 8 GB minimum, 16 GB recommended
- **Disk Space**:
  - Minimal tier: 5 GB
  - Essential tier: 10 GB
  - Complete tier: 15 GB
  - Full tier: 25 GB

### Optional Software

- **Git for Windows** - For version control
- **NSIS** - For creating installers (not required for portable bundles)

For detailed requirements, see [scripts/windows-build-requirements.txt](scripts/windows-build-requirements.txt).

## Quick Start

### Three-Command Build

```powershell
# 1. Clone and navigate to repository
git clone https://github.com/oraios/serena.git
cd serena

# 2. Create virtual environment and install dependencies
uv venv
uv pip install -e ".[dev]"
uv pip install pyinstaller==6.11.1

# 3. Run build (PowerShell)
.\scripts\build-windows\build-portable.ps1 -Tier essential -Architecture x64
```

The build output will be in the `dist/` directory.

### Using GitHub Actions (Recommended)

The easiest way to build is using the automated GitHub Actions workflow:

1. Go to **Actions** tab in GitHub
2. Select **Build Windows Portable** workflow
3. Click **Run workflow**
4. Choose:
   - **Bundle tier**: essential, complete, or full (or "all" for all tiers)
   - **Architecture**: x64, arm64, or both
5. Wait for build to complete
6. Download artifacts from the workflow run

## Build Tiers

Serena offers four build tiers to balance size and functionality:

### Minimal

**Size**: ~50 MB | **Build Time**: 5-8 minutes

- Core Serena functionality only
- No bundled language servers
- Users download servers separately
- Best for: Minimal footprint, custom server setup

### Essential

**Size**: ~280 MB | **Build Time**: 15-20 minutes

- Most popular language servers bundled
- Includes Node.js runtime
- **Languages**: Python, TypeScript/JavaScript, Rust, Go, Java
- Best for: Most developers, common languages

**Language Servers**:
- Pyright (Python)
- typescript-language-server (TypeScript/JavaScript)
- rust-analyzer (Rust)
- gopls (Go)
- Eclipse JDT LS (Java)

### Complete

**Size**: ~420 MB | **Build Time**: 25-30 minutes

- Essential + additional popular servers
- Includes Node.js and .NET runtimes
- **Languages**: All essential + C#, Lua, Bash, PHP
- Best for: Polyglot developers

**Additional Language Servers**:
- Microsoft C# Language Server (Roslyn-based)
- lua-language-server
- bash-language-server
- Intelephense (PHP)

### Full

**Size**: ~720 MB | **Build Time**: 40-50 minutes

- All 28+ supported language servers
- Includes experimental and legacy servers
- Complete offline development environment
- Best for: Maximum compatibility, offline use

**Additional Language Servers**:
- clangd (C/C++)
- terraform-ls (Terraform)
- zls (Zig)
- clojure-lsp (Clojure)
- kotlin-language-server (Kotlin)
- ruby-lsp (Ruby)
- r-language-server (R)
- dart-language-server (Dart)
- Plus experimental servers: OmniSharp, Solargraph, Jedi, vtsls

For complete language server details, see [scripts/build-config.json](scripts/build-config.json).

## Build Parameters

### PowerShell Build Script

```powershell
.\scripts\build-windows\build-portable.ps1 `
    -Tier <minimal|essential|complete|full> `
    -Architecture <x64|arm64> `
    [-Debug] `
    [-SkipQualityChecks] `
    [-SkipTests]
```

**Parameters**:
- `-Tier`: Bundle tier (default: essential)
- `-Architecture`: Target architecture (default: x64)
- `-Debug`: Enable PyInstaller debug mode
- `-SkipQualityChecks`: Skip formatting/linting checks
- `-SkipTests`: Skip test suite (default in CI)

### Python Build Script

```powershell
uv run python scripts/build_windows_portable.py `
    --tier essential `
    --arch x64 `
    --debug `
    --skip-checks
```

### Environment Variables

```powershell
$env:SERENA_PORTABLE_BUILD = "1"           # Enable portable mode
$env:SERENA_BUNDLE_TIER = "essential"      # Override tier
$env:SERENA_ARCH = "x64"                   # Override architecture
$env:RUNTIMES_DIR = "C:\build\runtimes"    # Custom runtimes directory
$env:UV_CONCURRENT_DOWNLOADS = "10"        # Parallel downloads
```

## Architecture Support

### x64 (AMD64)

- **Full native support** for all language servers
- **Compatible with**: Windows 10 x64, Windows 11 x64, Windows Server 2019/2022
- **Python version**: Install x64 Python 3.11 from python.org

### ARM64

- **Native support** for 16 language servers
- **Emulation support** for 5 additional servers (excellent performance)
- **Compatible with**: Windows 11 ARM64 (Surface Pro X, etc.)
- **Python version**: Install ARM64 Python 3.11 from python.org

**ARM64 Language Server Support**:
- **Native**: rust-analyzer, pyright, gopls, typescript-language-server, csharp-language-server, bash-language-server, terraform-ls, zls, and more
- **Emulated**: clangd, eclipse-jdtls, lua-language-server, clojure-lsp, omnisharp
- **Unsupported**: nixd, sourcekit-lsp (Swift), erlang-ls (require manual setup)

Windows 11 ARM64 provides excellent x64 emulation with minimal performance impact (typically 5-10% CPU overhead).

## Advanced Usage

### Custom Language Server Configuration

Edit `scripts/build-windows/language-servers-manifest.json` to:
- Change language server versions
- Add new language servers
- Modify download URLs
- Update runtime dependencies

### Build Configuration

Edit `scripts/build-config.json` to:
- Modify tier definitions
- Add/remove language servers from tiers
- Change PyInstaller parameters
- Update quality check commands

### Manual Language Server Setup

Pre-download language servers to speed up builds:

```powershell
# Create directories
New-Item -ItemType Directory -Force -Path "build\language_servers"

# Download servers manually
# Example: rust-analyzer
Invoke-WebRequest -Uri "https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.zip" -OutFile "build\language_servers\rust-analyzer.zip"
Expand-Archive "build\language_servers\rust-analyzer.zip" -DestinationPath "build\language_servers\rust-analyzer"
```

### Offline Builds

For completely offline builds:

1. Pre-download all dependencies:
   ```powershell
   uv pip download -r pyproject.toml -d build/packages
   ```

2. Pre-download language servers (see above)

3. Pre-download runtimes:
   ```powershell
   .\scripts\build-windows\download-runtimes.ps1 -RuntimeTier complete -Architecture x64 -OutputPath build\runtimes
   ```

4. Run build with `--no-index` flag (advanced)

### Custom PyInstaller Configuration

The build uses optimized PyInstaller settings defined in `scripts/build-config.json`:

- **One-file mode**: Single executable
- **Console mode**: Shows output for debugging
- **Optimization level 2**: Better performance
- **No UPX**: Faster builds, no compression
- **Excluded modules**: tkinter, matplotlib, PIL, numpy, pandas
- **Hidden imports**: All Serena modules and dependencies

To modify, edit `buildParameters.pyinstaller` in `build-config.json`.

## Troubleshooting

### Common Issues

#### 1. "Python 3.11 not found"

**Solution**:
- Download Python 3.11 from python.org
- Ensure "Add to PATH" is checked during installation
- Restart terminal after installation
- Verify: `python --version`

#### 2. "uv command not found"

**Solution**:
```powershell
# Install UV via PowerShell
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"

# Or via pip
pip install uv

# Verify
uv --version
```

#### 3. "PyInstaller fails with ImportError"

**Solution**:
- Ensure all hidden imports are in `build-config.json`
- Install Windows-specific packages:
  ```powershell
  uv pip install pywin32 pywin32-ctypes
  ```
- Try debug mode: `-Debug` flag

#### 4. "Language server not found in bundle"

**Solution**:
- Check tier includes the server in `build-config.json`
- Verify download succeeded (check logs)
- Manual download to `build/language_servers/`

#### 5. "Insufficient disk space"

**Solution**:
- Clean temporary files: `Remove-Item -Recurse -Force build, dist`
- Use smaller tier (minimal or essential)
- Increase disk space (see requirements)

#### 6. "Quality checks fail"

**Solution**:
```powershell
# Run formatting
uv run poe format

# Run linting
uv run poe lint

# Run type checking
uv run mypy src/serena

# Or skip checks during build
-SkipQualityChecks
```

#### 7. "ARM64 build fails on x64 machine"

**Solution**:
- Install Python 3.11 ARM64 version
- Or build on ARM64 hardware/VM
- Or use GitHub Actions (handles architecture automatically)

### Build Logs

Build logs are saved to:
- `build/pyinstaller_stdout.log` - PyInstaller output
- `build/pyinstaller_stderr.log` - PyInstaller errors
- `build/build.log` - General build log

### Verbose Output

Enable verbose logging:
```powershell
$env:PYINSTALLER_LOG_LEVEL = "DEBUG"
.\scripts\build-windows\build-portable.ps1 -Tier essential -Debug
```

### Getting Help

- **Build issues**: Check [scripts/windows-build-requirements.txt](scripts/windows-build-requirements.txt)
- **Language server issues**: See [scripts/build-windows/language-servers-manifest.json](scripts/build-windows/language-servers-manifest.json)
- **Report bugs**: https://github.com/oraios/serena/issues
- **Project docs**: [CLAUDE.md](CLAUDE.md)

## CI/CD Integration

### GitHub Actions Workflow

The repository includes a complete GitHub Actions workflow at `.github/workflows/windows-portable.yml`:

**Features**:
- Matrix builds for multiple tiers and architectures
- Parallel language server downloads
- Intelligent caching (dependencies, language servers, runtimes)
- Quality checks (formatting, linting, type checking)
- Automatic artifact upload
- Release creation on tags

**Triggering Builds**:

1. **Manual trigger**:
   - Go to Actions > Build Windows Portable > Run workflow
   - Select tier and architecture
   - Click "Run workflow"

2. **On release**:
   - Create a GitHub release
   - Workflow automatically builds and uploads artifacts

3. **On tag push**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

### Custom CI/CD Pipeline

For custom CI/CD systems (Azure DevOps, GitLab CI, Jenkins), use this template:

```yaml
# Example: Azure Pipelines
jobs:
- job: BuildWindows
  pool:
    vmImage: 'windows-2022'
  strategy:
    matrix:
      Essential_x64:
        tier: 'essential'
        arch: 'x64'
      Complete_x64:
        tier: 'complete'
        arch: 'x64'
  steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.11'
      architecture: '$(arch)'

  - script: |
      pip install uv
      uv venv
      uv pip install -e ".[dev]"
      uv pip install pyinstaller==6.11.1
    displayName: 'Install dependencies'

  - powershell: |
      .\scripts\build-windows\build-portable.ps1 -Tier $(tier) -Architecture $(arch)
    displayName: 'Build portable package'

  - task: PublishBuildArtifacts@1
    inputs:
      pathToPublish: 'dist'
      artifactName: 'serena-windows-$(arch)-$(tier)'
```

### Docker Builds (Advanced)

For containerized builds:

```dockerfile
# Dockerfile.windows
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Install Python 3.11
RUN Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe -OutFile python-installer.exe
RUN Start-Process python-installer.exe -ArgumentList '/quiet', 'InstallAllUsers=1', 'PrependPath=1' -Wait

# Install UV
RUN pip install uv

# Copy source
WORKDIR C:\build
COPY . .

# Build
RUN uv venv
RUN uv pip install -e ".[dev]"
RUN uv pip install pyinstaller==6.11.1
RUN .\scripts\build-windows\build-portable.ps1 -Tier essential -Architecture x64

# Output is in C:\build\dist
```

## Build Artifacts

### Output Files

After a successful build, you'll find in `dist/`:

1. **Executable**: `serena-windows-{arch}-{tier}-{version}.exe`
   - Standalone executable (45-650 MB depending on tier)
   - Can be run directly without installation

2. **Bundle ZIP**: `serena-windows-{arch}-{tier}-{version}-bundle.zip`
   - Complete distribution package
   - Includes executable, documentation, installers
   - Contents:
     - `bin/serena.exe` - Main executable
     - `README.md` - Project readme
     - `LICENSE` - License file
     - `docs/` - Additional documentation
     - `examples/` - Usage examples
     - `install.bat` - Batch installer
     - `install.ps1` - PowerShell installer

3. **Build Manifest**: `build-manifest-{arch}-{tier}.json`
   - Build metadata, versions, checksums
   - Used for verification and debugging

### Installation

**Option 1: Portable Use**
```powershell
# Extract bundle
Expand-Archive serena-windows-x64-essential-*.zip -DestinationPath C:\Serena

# Run directly
C:\Serena\bin\serena.exe --version
```

**Option 2: Install to System**
```powershell
# Extract bundle
Expand-Archive serena-windows-x64-essential-*.zip -DestinationPath C:\Temp\Serena

# Run installer (adds to PATH)
C:\Temp\Serena\install.ps1

# Use from anywhere
serena --version
```

**Option 3: Manual PATH Setup**
```powershell
# Copy executable
Copy-Item serena.exe C:\Users\YourName\AppData\Local\Serena\

# Add to PATH (PowerShell as Admin)
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
$path += ";C:\Users\YourName\AppData\Local\Serena"
[Environment]::SetEnvironmentVariable('Path', $path, 'User')
```

## Additional Resources

- **Build Configuration**: [scripts/build-config.json](scripts/build-config.json)
- **Language Servers Manifest**: [scripts/build-windows/language-servers-manifest.json](scripts/build-windows/language-servers-manifest.json)
- **Requirements**: [scripts/windows-build-requirements.txt](scripts/windows-build-requirements.txt)
- **Bundle Guides**:
  - [scripts/BUNDLE-WINDOWS-GUIDE.md](scripts/BUNDLE-WINDOWS-GUIDE.md) - Comprehensive guide
  - [scripts/BUNDLE-SUMMARY.md](scripts/BUNDLE-SUMMARY.md) - Quick reference
  - [scripts/BUNDLE-QUICK-REF.md](scripts/BUNDLE-QUICK-REF.md) - Command reference
- **Project Documentation**: [CLAUDE.md](CLAUDE.md)

## Contributing

To contribute to the build system:

1. Test changes locally first
2. Update relevant configuration files
3. Run quality checks: `uv run poe format && uv run poe lint`
4. Submit pull request with:
   - Description of changes
   - Test results on x64 and/or ARM64
   - Updated documentation if needed

## License

This build system is part of the Serena project and follows the same license.
See [LICENSE](LICENSE) for details.
