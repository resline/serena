# Portable Build Workflows

This document describes the GitHub Actions workflows for building portable Serena packages for Linux and Windows.

## Overview

The portable build system consists of three workflows:

1. **`portable-build-linux.yml`** - Linux x64 portable build
2. **`portable-build-windows.yml`** - Windows x64 portable build
3. **`portable-release.yml`** - Release orchestrator

## Architecture

```
portable-release.yml (Orchestrator)
│
├─► build-linux (calls portable-build-linux.yml)
│   ├── Cache layers (Python, Language Servers, UV)
│   ├── Build portable package
│   ├── Test package
│   ├── Create TAR.GZ archive
│   └── Upload artifact
│
├─► build-windows (calls portable-build-windows.yml)
│   ├── Cache layers (Python, Language Servers, UV)
│   ├── Build portable package
│   ├── Test package
│   ├── Create ZIP archive
│   └── Upload artifact
│
├─► generate-manifest
│   ├── Download artifacts from successful builds
│   ├── Generate latest.json manifest
│   └── Upload manifest artifact
│
└─► upload-to-release
    ├── Download all artifacts
    └── Upload to GitHub release
```

## Workflows

### portable-build-linux.yml

**Purpose**: Build Linux x64 portable package

**Triggers**:
- `workflow_call` from orchestrator
- `workflow_dispatch` for standalone testing

**Inputs**:
- `version` (required): Version string for the build
- `language_set` (optional): minimal/standard/full (default: standard)
- `skip_tests` (optional): Skip integration tests (default: false)
- `cache_version` (optional): Cache version identifier (default: v3)

**Outputs**:
- `artifact_name`: Name of uploaded artifact
- `archive_path`: Archive filename
- `checksum`: SHA256 checksum

**Build Process**:
1. Download Python Build Standalone (indygreg)
2. Create virtual environment with UV
3. Build portable package using `build_portable.sh`
4. Run integration tests (optional)
5. Create TAR.GZ archive
6. Generate SHA256 checksum
7. Upload artifacts

**Cost**: 1x multiplier (most cost-effective)
**Estimated Time**: 20-25 minutes with warm cache

### portable-build-windows.yml

**Purpose**: Build Windows x64 portable package

**Triggers**:
- `workflow_call` from orchestrator
- `workflow_dispatch` for standalone testing

**Inputs**: Same as Linux workflow

**Outputs**: Same as Linux workflow

**Build Process**:
1. Download Python embedded from python.org
2. Create virtual environment with UV
3. Build portable package using `build_portable.sh` (via Git Bash)
4. Run integration tests (optional)
5. Create ZIP archive using PowerShell
6. Generate SHA256 checksum
7. Upload artifacts

**Cost**: 2x multiplier (twice Linux cost)
**Estimated Time**: 25-30 minutes with warm cache

**Windows-Specific Features**:
- Uses PowerShell for Python download
- Uses `Compress-Archive` for ZIP creation
- Uses `Get-FileHash` for SHA256 checksum
- Git Bash for build/test scripts

### portable-release.yml

**Purpose**: Orchestrate multi-platform builds and release

**Triggers**:
- `release.published` - Automatic on GitHub release
- `push.tags.v*.*.*` - On version tags
- `workflow_dispatch` - Manual trigger

**Inputs**:
- `platform_filter`: all/linux/windows (default: all)
- `language_set`: minimal/standard/full (default: standard)
- `skip_tests`: Skip integration tests (default: false)
- `release_tag`: Override release tag (optional)

**Jobs**:

1. **prepare-release**: Determine version and configuration
2. **build-linux**: Call Linux build workflow (parallel)
3. **build-windows**: Call Windows build workflow (parallel)
4. **generate-manifest**: Create latest.json with both platforms
5. **upload-to-release**: Upload all artifacts to GitHub release

**Features**:
- Parallel platform builds for faster releases
- Graceful degradation (partial releases if one platform fails)
- Unified manifest generation
- Automatic GitHub release upload

## Usage

### Automatic Release

Create a GitHub release and workflows will automatically build all platforms:

```bash
gh release create v0.1.5 --title "v0.1.5" --notes "Release notes"
```

### Manual Build (All Platforms)

```bash
gh workflow run portable-release.yml \
  -f platform_filter=all \
  -f language_set=standard \
  -f skip_tests=false
```

### Linux-Only Build

```bash
gh workflow run portable-build-linux.yml \
  -f version=v0.1.5-dev \
  -f language_set=minimal \
  -f skip_tests=true
```

### Windows-Only Build

```bash
gh workflow run portable-build-windows.yml \
  -f version=v0.1.5-dev \
  -f language_set=standard \
  -f skip_tests=false
```

## Caching Strategy

All workflows use a 3-layer caching strategy:

### Layer 1: Python Runtime
- **Path**: `${{ runner.temp }}/python-embedded`
- **Key**: `python-embedded-{OS}-{ARCH}-{VERSION}-{CACHE_VERSION}`
- **Hit Rate**: ~95%
- **Size**: ~100 MB (Linux), ~50 MB (Windows)

### Layer 2: Language Servers
- **Path**: `~/.serena/language_servers/static`
- **Key**: `language-servers-portable-{OS}-{ARCH}-{LANG_SET}-{CACHE_VERSION}`
- **Hit Rate**: ~80%
- **Size**: 100-500 MB depending on language set
- **Restore Keys**: Falls back to other language sets or OS

### Layer 3: UV Virtualenv
- **Path**: `.venv`
- **Key**: `uv-venv-portable-{OS}-{PY_VERSION}-{UV_LOCK_HASH}-{CACHE_VERSION}`
- **Hit Rate**: ~70%
- **Size**: ~200 MB
- **Restore Keys**: Falls back to same OS and Python version

### Cache Invalidation

To invalidate all caches, increment `CACHE_VERSION` in workflow env:

```yaml
env:
  CACHE_VERSION: 'v4'  # Changed from v3
```

## Cost Optimization

### Runner Costs
- **Linux**: 1x multiplier = 1 billable minute per minute
- **Windows**: 2x multiplier = 2 billable minutes per minute

### Typical Build Costs (Standard Set, Warm Cache)
- **Linux**: ~20 min = 20 billable minutes
- **Windows**: ~25 min = 50 billable minutes
- **Total**: ~70 billable minutes per full release

### Cost-Saving Strategies
1. **Use minimal language set** for development: Saves ~30% time
2. **Skip tests** during development: Saves ~25% time
3. **Build single platform** for testing: Saves 50-70% time
4. **Leverage cache warmup**: Pre-populate caches weekly

Example cost-optimized development build:
```bash
gh workflow run portable-build-linux.yml \
  -f version=v0.1.5-dev \
  -f language_set=minimal \
  -f skip_tests=true
# Cost: ~12 billable minutes
```

## Artifacts

Each build produces:

### Linux
- `serena-linux-x64-{version}.tar.gz` - Compressed package
- `serena-linux-x64-{version}.tar.gz.sha256` - SHA256 checksum

### Windows
- `serena-windows-x64-{version}.zip` - Compressed package
- `serena-windows-x64-{version}.zip.sha256` - SHA256 checksum

### Manifest
- `latest.json` - Unified manifest with metadata for all platforms

### Artifact Retention
- Build artifacts: 30 days
- Manifest: 90 days

## Manifest Format

The `latest.json` manifest contains:

```json
{
  "version": "v0.1.5",
  "released_at": "2025-10-31T12:00:00Z",
  "language_config": "standard",
  "platforms": {
    "serena-linux-x64": {
      "filename": "serena-linux-x64-v0.1.5.tar.gz",
      "size": 180000000,
      "sha256": "abc123...",
      "download_url": "https://github.com/..."
    },
    "serena-windows-x64": {
      "filename": "serena-windows-x64-v0.1.5.zip",
      "size": 185000000,
      "sha256": "def456...",
      "download_url": "https://github.com/..."
    }
  }
}
```

## Troubleshooting

### Build Failures

**Cache Issues**:
```bash
# Invalidate caches by changing version
# Edit workflow file: CACHE_VERSION: 'v4'
```

**Python Download Failures**:
- Retry the workflow (transient network issues)
- Check if python.org or GitHub releases are accessible

**Test Failures**:
- Check test logs in workflow output
- Run tests locally: `./scripts/portable/test_portable.sh`
- Skip tests if non-critical: `-f skip_tests=true`

### Windows-Specific Issues

**PowerShell Errors**:
- Check if using `pwsh` (PowerShell Core) not `powershell`
- Verify PowerShell commands are compatible with PowerShell Core

**Archive Creation Fails**:
- Ensure using `Compress-Archive` not 7z
- Check file paths don't contain special characters

### Partial Releases

If one platform fails but the other succeeds:
- Manifest will only include successful platform
- Release will be created with available artifacts
- Check workflow logs to diagnose failed platform

## Monitoring

### GitHub Actions Summary

Each workflow provides a detailed summary showing:
- Build configuration (version, language set, platform)
- Cache hit rates
- Build duration
- Artifact information

### Cost Tracking

Monitor billable minutes in:
- Repository Settings → Billing → Actions
- Check monthly usage and limits

## Maintenance

### Weekly Tasks
- Review cache hit rates in workflow summaries
- Clean up old workflow runs (Settings → Actions → General)

### Monthly Tasks
- Review and update Python version if needed
- Update language server versions
- Review total billable minutes usage

### When to Update
- **Python version**: Update `PYTHON_VERSION` and `PYTHON_PATCH_VERSION`
- **Language servers**: Automatic via build script
- **Dependencies**: Update `uv.lock` triggers cache rebuild

## Migration from Old Workflow

The new workflows replace the monolithic `portable-build.yml`. Key differences:

**Old System** (portable-build.yml):
- Single workflow with matrix strategy
- All platforms in one file
- Platform-specific logic with conditionals

**New System** (portable-build-{linux,windows}.yml + portable-release.yml):
- Separate workflows per platform
- `workflow_call` for reusability
- Orchestrator for coordination

**Migration Steps**:
1. ✅ New workflows created and tested
2. ⏳ Run both systems in parallel initially
3. ⏳ Deprecate old workflow after validation
4. ⏳ Update documentation and links

## Future Enhancements

Potential improvements:
- Add macOS ARM and Intel builds
- Implement matrix strategy for language sets
- Add build result notifications (Slack, Discord)
- Create reusable workflow for cache warmup
- Add performance benchmarking
- Implement automated release notes generation
