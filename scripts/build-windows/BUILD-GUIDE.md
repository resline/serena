# Windows Portable Build Guide

Complete guide for building Serena Windows portable packages using the automated build system.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Build Parameters](#build-parameters)
4. [Build Stages](#build-stages)
5. [Build Time Estimates](#build-time-estimates)
6. [Disk Space Requirements](#disk-space-requirements)
7. [Testing Checklist](#testing-checklist)
8. [Troubleshooting](#troubleshooting)
9. [CI/CD Integration](#cicd-integration)

## Prerequisites

### Required Software

| Software | Version | Purpose | Installation |
|----------|---------|---------|--------------|
| **Python** | 3.11.x | Runtime environment | [python.org](https://www.python.org/downloads/) |
| **uv** | Latest | Package management | [docs.astral.sh/uv](https://docs.astral.sh/uv/getting-started/installation/) |
| **PowerShell** | 5.1+ | Build automation | Included with Windows 10+ |
| **Git** | Latest | Version detection | [git-scm.com](https://git-scm.com/downloads) |

### Optional Software

| Software | Purpose | When Needed |
|----------|---------|-------------|
| **Node.js** | TypeScript/JS language servers | Essential+ tiers |
| **npm** | Node.js package management | Essential+ tiers |
| **.NET SDK** | C# language servers | Essential+ tiers |
| **Java JDK** | Java language servers | Complete+ tiers |

### System Requirements

- **OS**: Windows 10 (version 1903+) or Windows 11
- **RAM**: 8GB minimum, 16GB recommended
- **Disk Space**: See [Disk Space Requirements](#disk-space-requirements)
- **CPU**: Multi-core processor recommended (build uses parallel operations)
- **Network**: Required for dependency downloads (unless fully cached)

## Quick Start

### Basic Build (Recommended)

```powershell
# Navigate to build scripts directory
cd scripts/build-windows

# Build with essential tier (recommended for most users)
.\build-windows-portable.ps1 -Tier essential -Clean
```

### Production Build

```powershell
# Full production build with all checks
.\build-windows-portable.ps1 `
    -Tier complete `
    -Version "0.1.4" `
    -OutputDir "C:\builds\serena" `
    -Clean `
    -Architecture x64
```

### Development Build (Fast)

```powershell
# Quick build for testing (skips tests and archiving)
.\build-windows-portable.ps1 `
    -Tier minimal `
    -SkipTests `
    -NoArchive
```

## Build Parameters

### Required Parameters

#### `-Tier <string>`

Specifies which language servers to include.

**Options:**
- `minimal`: No language servers (smallest, ~150 MB)
- `essential`: Python, TypeScript, Go, C# (recommended, ~350 MB)
- `complete`: + Java, Rust, Kotlin, Clojure (~650 MB)
- `full`: All 28+ supported languages (~1.2 GB)

**Example:**
```powershell
-Tier essential
```

### Optional Parameters

#### `-Version <string>`

Override version string (default: auto-detected from pyproject.toml)

**Example:**
```powershell
-Version "1.0.0"
```

#### `-OutputDir <string>`

Build output directory (default: `dist\windows`)

**Example:**
```powershell
-OutputDir "C:\builds\serena"
```

**Note:** Use short paths to avoid Windows MAX_PATH (260 char) issues.

#### `-Architecture <string>`

Target architecture: `x64`, `x86`, or `arm64` (default: `x64`)

**Example:**
```powershell
-Architecture x64
```

**ARM64 Support:**
- Native ARM64 binaries where available
- Falls back to x64 with emulation for unsupported servers

#### `-Clean` (switch)

Remove previous build artifacts before starting.

**Example:**
```powershell
-Clean
```

**Effect:**
- Deletes previous PyInstaller dist/build directories
- Removes previous package directories
- Cleans temporary files

#### `-SkipTests` (switch)

Skip running tests before building (not recommended for production).

**Example:**
```powershell
-SkipTests
```

**Skips:**
- Type checking (mypy)
- Linting (ruff)
- Core test suite (pytest)

#### `-SkipLanguageServers` (switch)

Skip language server downloads (creates minimal package).

**Example:**
```powershell
-SkipLanguageServers
```

#### `-NoArchive` (switch)

Don't create ZIP archive (keep directory only).

**Example:**
```powershell
-NoArchive
```

**Use case:** Testing builds without the overhead of ZIP compression.

#### `-Parallel <int>`

Number of parallel operations (default: 4)

**Example:**
```powershell
-Parallel 8
```

**Affects:**
- Language server downloads
- File copying operations

## Build Stages

The build process consists of 10 automated stages:

### Stage 1: Environment Validation

**Duration:** ~2-5 seconds

**Actions:**
- Verify Python 3.11 is installed and in PATH
- Verify uv package manager is available
- Check optional tools (Node.js, npm, git)
- Validate system requirements
- Check available disk space

**Success Criteria:**
- Python 3.11.x detected
- uv is accessible
- At least 2 GB free disk space

### Stage 2: Dependency Resolution

**Duration:** ~30-60 seconds (first run), ~5-10 seconds (cached)

**Actions:**
- Verify pyproject.toml exists
- Extract version from pyproject.toml
- Install Windows dependencies (pywin32)
- Sync Python dependencies with uv
- Install PyInstaller

**Success Criteria:**
- All dependencies installed
- PyInstaller available

### Stage 3: Tests Execution

**Duration:** ~60-180 seconds (depends on test scope)

**Actions:**
- Run mypy type checking
- Run ruff linting
- Execute core test suite (Python, Go, TypeScript)

**Success Criteria:**
- Type checking passes (no errors)
- Linting passes
- Core tests pass

**Skip:** Use `-SkipTests` flag (not recommended for production)

### Stage 4: Language Server Bundling

**Duration:** ~60-300 seconds (depends on tier and network speed)

**Actions:**
- Execute download-language-servers.ps1
- Download language servers based on tier
- Extract archives
- Verify downloads

**Success Criteria:**
- All required language servers downloaded
- Files extracted successfully
- Total size matches expectations

**Skip:** Use `-SkipLanguageServers` or `-Tier minimal`

### Stage 5: PyInstaller Build

**Duration:** ~120-240 seconds

**Actions:**
- Set environment variables for PyInstaller
- Execute serena.spec
- Build 3 executables:
  - serena-mcp-server.exe
  - serena.exe
  - index-project.exe
- Verify all executables created

**Success Criteria:**
- All 3 executables built
- Each executable ~40-50 MB
- No PyInstaller errors

### Stage 6: Directory Structure Creation

**Duration:** ~1-2 seconds

**Actions:**
- Create package directory with version/tier naming
- Create subdirectories:
  - bin/
  - config/
  - docs/
  - scripts/
  - language_servers/

**Success Criteria:**
- All directories created
- Naming follows convention: `serena-portable-v{VERSION}-windows-{ARCH}-{TIER}`

### Stage 7: File Copying and Integration

**Duration:** ~10-60 seconds (depends on language server count)

**Actions:**
- Copy executables to bin/
- Copy language servers to language_servers/
- Copy configuration files to config/
- Copy documentation to docs/
- Copy launcher script to root
- Create VERSION.txt

**Success Criteria:**
- All files copied successfully
- No missing files
- Total file count matches expectations

### Stage 8: Archive Creation

**Duration:** ~30-120 seconds (depends on size and compression)

**Actions:**
- Create ZIP archive with optimal compression
- Calculate sizes (directory vs. archive)
- Compute compression ratio

**Success Criteria:**
- ZIP file created successfully
- Archive is valid and extractable
- Compression ratio 40-60% for binaries

**Skip:** Use `-NoArchive` flag

### Stage 9: Checksum Generation

**Duration:** ~5-15 seconds

**Actions:**
- Generate SHA256 checksum for archive
- Create .sha256 checksum file
- Generate checksums for executables
- Store in build manifest

**Success Criteria:**
- Archive checksum computed
- Checksum file created
- All executable checksums stored

### Stage 10: Build Manifest Generation

**Duration:** ~1-2 seconds

**Actions:**
- Finalize build metadata
- Add package information
- Write JSON manifest
- Create timestamped and "latest" versions

**Success Criteria:**
- Manifest JSON is valid
- All stage data captured
- Files created successfully

## Build Time Estimates

### By Tier (First Run, No Cache)

| Tier | Download | Build | Total | Notes |
|------|----------|-------|-------|-------|
| **Minimal** | 0s | ~180s | **~3-4 min** | No language servers |
| **Essential** | ~90s | ~240s | **~6-8 min** | 4 language servers |
| **Complete** | ~180s | ~300s | **~10-12 min** | 8 language servers |
| **Full** | ~300s | ~360s | **~15-20 min** | 28+ language servers |

### By Tier (Cached Dependencies)

| Tier | Download | Build | Total | Notes |
|------|----------|-------|-------|-------|
| **Minimal** | 0s | ~120s | **~2 min** | No language servers |
| **Essential** | ~30s | ~150s | **~3-4 min** | Cached downloads |
| **Complete** | ~60s | ~180s | **~4-5 min** | Cached downloads |
| **Full** | ~120s | ~240s | **~6-8 min** | Cached downloads |

### Stage-Level Time Breakdown (Essential Tier, Cached)

```
Stage 1:  Environment Validation          ~3s    (1%)
Stage 2:  Dependency Resolution          ~10s    (3%)
Stage 3:  Tests Execution               ~120s   (40%)
Stage 4:  Language Server Bundling       ~30s   (10%)
Stage 5:  PyInstaller Build             ~120s   (40%)
Stage 6:  Directory Structure             ~1s    (0%)
Stage 7:  File Copying                   ~15s    (5%)
Stage 8:  Archive Creation               ~30s   (10%)
Stage 9:  Checksum Generation             ~5s    (2%)
Stage 10: Manifest Generation             ~1s    (0%)
─────────────────────────────────────────────────
Total:                                  ~335s   (~6 min)
```

### Fast Development Build (SkipTests, NoArchive)

```
Stage 1:  Environment Validation          ~3s
Stage 2:  Dependency Resolution          ~10s
Stage 3:  Tests Execution              SKIPPED
Stage 4:  Language Server Bundling     SKIPPED  (minimal tier)
Stage 5:  PyInstaller Build             ~120s
Stage 6:  Directory Structure             ~1s
Stage 7:  File Copying                    ~5s
Stage 8:  Archive Creation             SKIPPED
Stage 9:  Checksum Generation             ~2s
Stage 10: Manifest Generation             ~1s
─────────────────────────────────────────────────
Total:                                  ~142s   (~2.5 min)
```

## Disk Space Requirements

### Build Process Requirements

| Stage | Temporary | Permanent | Notes |
|-------|-----------|-----------|-------|
| Dependencies | 500 MB | 200 MB | Python packages, uv cache |
| Language Servers | Variable | Variable | See tier breakdown |
| PyInstaller Build | 800 MB | 150 MB | Work files cleaned after |
| Final Package | Variable | Variable | Depends on tier |

### By Tier (Total Required During Build)

| Tier | Temp | Final Package | Final Archive | Total Peak |
|------|------|---------------|---------------|------------|
| **Minimal** | 1.5 GB | 150 MB | 80 MB | **~2 GB** |
| **Essential** | 2.0 GB | 400 MB | 200 MB | **~3 GB** |
| **Complete** | 2.5 GB | 700 MB | 350 MB | **~4 GB** |
| **Full** | 3.5 GB | 1.5 GB | 750 MB | **~6 GB** |

### Recommended Free Space

- **Minimal builds:** 5 GB free
- **Essential builds:** 8 GB free
- **Complete builds:** 10 GB free
- **Full builds:** 15 GB free
- **CI/CD builds:** 20 GB free (for multiple tiers)

### After Build Cleanup

With `-Clean` flag, temporary files are removed:
- PyInstaller build/ directory (~500 MB)
- Temporary stage directory (~200 MB)
- Download cache (optional, ~300 MB)

**Final disk usage:**
- Package directory: 150 MB - 1.5 GB (tier-dependent)
- Archive: 80 MB - 750 MB (tier-dependent)
- Build logs and manifests: <5 MB

## Testing Checklist

### Pre-Build Testing

- [ ] Python 3.11 is installed: `python --version`
- [ ] uv is available: `uv --version`
- [ ] Repository is clean: `git status`
- [ ] Tests pass locally: `uv run poe test`
- [ ] Sufficient disk space available

### Build Verification

- [ ] Build completes without errors
- [ ] All 10 stages show "COMPLETED" status
- [ ] Build manifest is generated
- [ ] Build log contains no errors

### Package Verification

- [ ] Package directory created with correct name
- [ ] All executables present in bin/:
  - [ ] serena-mcp-server.exe
  - [ ] serena.exe
  - [ ] index-project.exe
- [ ] Executables are functional:
  ```powershell
  .\bin\serena-mcp-server.exe --version
  .\bin\serena.exe --version
  .\bin\index-project.exe --version
  ```
- [ ] Language servers present (tier-dependent)
- [ ] Configuration files valid
- [ ] Documentation complete
- [ ] VERSION.txt accurate

### Archive Verification

- [ ] ZIP archive created
- [ ] Archive size reasonable (40-60% compression)
- [ ] SHA256 checksum file present
- [ ] Archive extracts without errors:
  ```powershell
  Expand-Archive -Path archive.zip -DestinationPath test-extract
  ```
- [ ] Extracted files identical to package directory

### Functional Testing

Use the included test script:

```powershell
.\test-portable.ps1 -PackagePath ".\dist\windows\serena-portable-v0.1.4-windows-x64-essential"
```

**Manual functional tests:**

1. **Launcher Test:**
   ```powershell
   cd [package-directory]
   .\serena-portable.bat --help
   ```
   - [ ] Launcher starts without errors
   - [ ] Help text displays correctly

2. **MCP Server Test:**
   ```powershell
   .\bin\serena-mcp-server.exe --help
   ```
   - [ ] Server shows available options
   - [ ] No missing dependency errors

3. **CLI Test:**
   ```powershell
   .\bin\serena.exe --version
   .\bin\serena.exe --help
   ```
   - [ ] Version matches build
   - [ ] Commands available

4. **Language Server Test** (tier-dependent):
   ```powershell
   # Check language servers are accessible
   dir language_servers\
   ```
   - [ ] Expected language servers present
   - [ ] Binaries are executable

5. **Portable Mode Test:**
   - [ ] Run from USB drive
   - [ ] .serena-portable/ directory created on first run
   - [ ] Logs written to portable directory
   - [ ] No writes to user home directory

### Integration Testing

- [ ] Start MCP server and connect client
- [ ] Index a test project
- [ ] Execute symbol search
- [ ] Execute file operations
- [ ] Test language server integration (tier-dependent)

### Performance Testing

- [ ] Startup time < 5 seconds
- [ ] MCP server responds to requests
- [ ] Language servers initialize correctly
- [ ] Memory usage reasonable (<2 GB idle)

### Compatibility Testing

Test on different Windows versions:
- [ ] Windows 10 (version 1903+)
- [ ] Windows 11
- [ ] Windows Server 2019/2022

Test different architectures (if built):
- [ ] x64 native
- [ ] ARM64 native or emulated

## Troubleshooting

### Common Issues

#### Build Fails: "Python 3.11 required"

**Cause:** Wrong Python version or not in PATH

**Solution:**
```powershell
# Check Python version
python --version

# If wrong version, install Python 3.11
# Download from: https://www.python.org/downloads/

# Verify PATH
$env:PATH -split ';' | Select-String python
```

#### Build Fails: "uv not found"

**Cause:** uv not installed or not in PATH

**Solution:**
```powershell
# Install uv (PowerShell)
irm https://astral.sh/uv/install.ps1 | iex

# Verify installation
uv --version

# Restart PowerShell to refresh PATH
```

#### Build Fails: "Type checking failed"

**Cause:** Code has type errors

**Solution:**
```powershell
# Run type checking locally
cd [repo-root]
uv run poe type-check

# Fix reported errors
# OR use -SkipTests (not recommended)
```

#### Build Fails: "PyInstaller failed"

**Cause:** Missing dependencies or spec file issues

**Solution:**
```powershell
# Check PyInstaller is installed
uv run pyinstaller --version

# Run PyInstaller manually with verbose output
cd [repo-root]
$env:PROJECT_ROOT = (Get-Location).Path
uv run pyinstaller scripts/pyinstaller/serena.spec --log-level DEBUG

# Check build output for specific errors
```

#### Build Fails: "Language server download failed"

**Cause:** Network issues or invalid URLs

**Solution:**
```powershell
# Test network connectivity
Test-NetConnection -ComputerName github.com -Port 443

# Run language server download separately
.\download-language-servers.ps1 -Tier essential -Force

# Check for specific server errors in output
```

#### Build Fails: "Path too long"

**Cause:** Windows MAX_PATH (260 char) limitation

**Solution:**
```powershell
# Use shorter output directory
.\build-windows-portable.ps1 -Tier essential -OutputDir "C:\build"

# OR enable long paths (Windows 10+)
# Run as Administrator:
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

#### Archive Creation Fails

**Cause:** Insufficient disk space or permissions

**Solution:**
```powershell
# Check available disk space
Get-PSDrive C | Select-Object Used,Free

# Check permissions on output directory
Get-Acl [output-dir]

# Try without archive
.\build-windows-portable.ps1 -Tier essential -NoArchive
```

### Debugging Build Issues

**Enable verbose logging:**

```powershell
# Build log is automatically created at:
# [OutputDir]/build.log

# Check log during build:
Get-Content [OutputDir]/build.log -Tail 50 -Wait
```

**Check build manifest:**

```powershell
# Manifest shows detailed stage information
Get-Content [OutputDir]/build-manifest-latest.json | ConvertFrom-Json | Format-List
```

**Manual stage execution:**

Run individual stages for debugging:

```powershell
# Test dependency resolution
cd [repo-root]
uv sync --all-extras

# Test PyInstaller
$env:PROJECT_ROOT = (Get-Location).Path
uv run pyinstaller scripts/pyinstaller/serena.spec

# Test language server download
cd scripts/build-windows
.\download-language-servers.ps1 -Tier essential -OutputDir temp-test
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Windows Portable

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-windows-portable:
    runs-on: windows-latest
    strategy:
      matrix:
        tier: [essential, complete, full]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install uv
        shell: powershell
        run: |
          irm https://astral.sh/uv/install.ps1 | iex
          echo "$env:USERPROFILE\.cargo\bin" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append

      - name: Setup Node.js (for language servers)
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Build portable package
        shell: powershell
        run: |
          cd scripts/build-windows
          .\build-windows-portable.ps1 -Tier ${{ matrix.tier }} -Clean

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: serena-portable-windows-${{ matrix.tier }}
          path: |
            dist/windows/*.zip
            dist/windows/*.sha256
            dist/windows/build-manifest-*.json

      - name: Create release (if tagged)
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/windows/*.zip
            dist/windows/*.sha256
```

### Azure Pipelines Example

```yaml
trigger:
  tags:
    include:
      - v*

pool:
  vmImage: 'windows-latest'

variables:
  PYTHON_VERSION: '3.11'

strategy:
  matrix:
    essential:
      tier: 'essential'
    complete:
      tier: 'complete'
    full:
      tier: 'full'

steps:
- task: UsePythonVersion@0
  inputs:
    versionSpec: '$(PYTHON_VERSION)'
  displayName: 'Use Python $(PYTHON_VERSION)'

- task: NodeTool@0
  inputs:
    versionSpec: '20.x'
  displayName: 'Use Node.js 20.x'

- powershell: |
    irm https://astral.sh/uv/install.ps1 | iex
  displayName: 'Install uv'

- powershell: |
    cd scripts/build-windows
    .\build-windows-portable.ps1 -Tier $(tier) -Clean -OutputDir "$(Build.ArtifactStagingDirectory)"
  displayName: 'Build Portable Package'

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: '$(Build.ArtifactStagingDirectory)'
    artifactName: 'serena-portable-$(tier)'
  displayName: 'Publish Artifacts'
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent {
        label 'windows'
    }

    parameters {
        choice(
            name: 'TIER',
            choices: ['essential', 'complete', 'full'],
            description: 'Language server tier'
        )
    }

    environment {
        PYTHON_HOME = 'C:\\Python311'
        PATH = "${PYTHON_HOME};${PYTHON_HOME}\\Scripts;${env.PATH}"
    }

    stages {
        stage('Setup') {
            steps {
                bat 'python --version'
                bat 'pip install uv'
                bat 'uv --version'
            }
        }

        stage('Build') {
            steps {
                dir('scripts/build-windows') {
                    bat """
                        powershell -ExecutionPolicy Bypass -File build-windows-portable.ps1 ^
                            -Tier ${params.TIER} ^
                            -Clean ^
                            -OutputDir "${env.WORKSPACE}\\dist"
                    """
                }
            }
        }

        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'dist/**/*.zip,dist/**/*.sha256,dist/**/build-manifest-*.json'
            }
        }
    }
}
```

### Best Practices for CI/CD

1. **Caching:** Cache dependencies between builds
   ```yaml
   - name: Cache uv dependencies
     uses: actions/cache@v3
     with:
       path: ~/.cache/uv
       key: uv-${{ hashFiles('pyproject.toml') }}
   ```

2. **Parallel Builds:** Build multiple tiers in parallel
   ```yaml
   strategy:
     matrix:
       tier: [essential, complete, full]
     max-parallel: 3
   ```

3. **Artifact Retention:** Keep builds for release
   ```yaml
   - uses: actions/upload-artifact@v4
     with:
       name: build-artifacts
       retention-days: 30
   ```

4. **Build Verification:** Run tests after build
   ```yaml
   - name: Test build
     run: |
       .\test-portable.ps1 -PackagePath "dist/windows/serena-portable-*"
   ```

5. **Manifest Validation:** Verify build manifest
   ```yaml
   - name: Validate manifest
     run: |
       $manifest = Get-Content dist/windows/build-manifest-latest.json | ConvertFrom-Json
       if ($manifest.build_status -ne "success") {
         throw "Build failed according to manifest"
       }
   ```

## Additional Resources

- **PyInstaller Documentation:** https://pyinstaller.org/
- **Windows Path Length:** https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
- **PowerShell Best Practices:** https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines

## Support

For build issues:
1. Check build log: `[OutputDir]/build.log`
2. Check manifest: `[OutputDir]/build-manifest-latest.json`
3. Review this guide's troubleshooting section
4. Open issue with build log and manifest attached

---

**Document Version:** 1.0.0
**Last Updated:** 2025-01-12
**Maintained By:** Serena Development Team
