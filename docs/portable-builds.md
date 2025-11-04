# Portable Builds Documentation

This document describes the portable build system for Serena, which creates self-contained distributions that can run on systems without requiring Python or other dependencies to be pre-installed.

## Overview

The portable build system creates distributable packages that include:
- **Python Runtime**: Embedded Python 3.11 interpreter
- **Serena**: Complete Serena installation with all dependencies
- **Language Servers**: Pre-downloaded language servers based on configuration
- **Launcher Scripts**: Platform-specific scripts for easy execution

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [GitHub Actions Workflows](#github-actions-workflows)
4. [Build Configuration](#build-configuration)
5. [Cache Strategy](#cache-strategy)
6. [Testing](#testing)
7. [Cost Optimization](#cost-optimization)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### Triggering a Build

#### Via GitHub Release
When you publish a GitHub release, portable builds are automatically triggered for all platforms.

#### Via Workflow Dispatch
You can manually trigger builds from the GitHub Actions UI:

1. Go to **Actions** → **Build Portable Packages**
2. Click **Run workflow**
3. Configure options:
   - **platform_filter**: Which platforms to build (default: all)
   - **language_set**: minimal/standard/full (default: standard)
   - **include_all_languages**: Override to include all languages
   - **skip_tests**: Skip integration tests for faster builds
   - **upload_to_release**: Upload artifacts to GitHub release

#### Via Git Tag
Push a version tag:
```bash
git tag v0.1.5
git push origin v0.1.5
```

### Using Portable Builds

#### Download
Download the appropriate package for your platform from the GitHub release page:
- `serena-linux-x64-v0.1.4.tar.gz` - Linux (x86_64)
- `serena-windows-x64-v0.1.4.zip` - Windows (x86_64)
- `serena-macos-x64-v0.1.4.tar.gz` - macOS Intel
- `serena-macos-arm64-v0.1.4.tar.gz` - macOS Apple Silicon

#### Extract
```bash
# Linux/macOS
tar -xzf serena-linux-x64-v0.1.4.tar.gz
cd serena-linux-x64

# Windows
# Use Windows Explorer or 7-Zip to extract the .zip file
```

#### Run
```bash
# Linux/macOS
./bin/serena --help
./bin/serena-mcp-server

# Windows
bin\serena.bat --help
bin\serena-mcp-server.bat
```

## Architecture

### Directory Structure

```
serena-{platform}/
├── bin/
│   ├── serena                 # Main launcher (Unix)
│   ├── serena.bat             # Main launcher (Windows)
│   ├── serena-mcp-server      # MCP server launcher (Unix)
│   └── serena-mcp-server.bat  # MCP server launcher (Windows)
├── python/
│   ├── bin/                   # Python executables (Unix)
│   ├── lib/                   # Python standard library
│   ├── python.exe             # Python executable (Windows)
│   └── site-packages/         # Installed packages
├── serena/
│   └── ...                    # Serena source code
├── language_servers/
│   └── static/                # Pre-downloaded language servers
├── BUILD_INFO.json            # Build metadata
├── VERSION                    # Version string
└── README.md                  # Quick start guide
```

### Python Runtime Sources

- **Windows**: Official Python embedded distribution from python.org
- **Linux/macOS**: Python Build Standalone by Gregory Szorc (indygreg)
  - Fully self-contained
  - No system dependencies
  - Consistent across distributions

### Language Server Bundling

Language servers are organized in three tiers:

#### Minimal Set
Essential languages for most use cases:
- Python (pyright)
- TypeScript/JavaScript (typescript-language-server)
- Go (gopls)

#### Standard Set
Common languages for web and systems development:
- All minimal languages
- Rust (rust-analyzer)
- Java (Eclipse JDT-LS)
- Ruby (ruby-lsp)
- PHP (Intelephense)

#### Full Set
All supported languages (16+):
- All standard languages
- Perl, Clojure, Elixir, Terraform, Swift, Bash, C#, and more

## GitHub Actions Workflows

### Main Workflow: `portable-build.yml`

**Triggers:**
- Release published
- Workflow dispatch (manual)
- Git tags matching `v*.*.*`

**Jobs:**

1. **prepare-matrix**
   - Determines which platforms to build
   - Sets language configuration
   - Extracts version from tag or pyproject.toml

2. **build-portable**
   - Matrix job running on each platform
   - Downloads Python runtime
   - Installs Serena and dependencies
   - Pre-downloads language servers
   - Creates portable structure
   - Runs integration tests
   - Creates compressed archives
   - Generates SHA256 checksums

3. **generate-manifest**
   - Creates `latest.json` with metadata
   - Lists all available platforms
   - Includes checksums and download URLs
   - Enables auto-update systems

4. **build-summary**
   - Generates GitHub Actions summary
   - Reports build status
   - Shows estimated costs

**Timeouts:**
- Total workflow: 120 minutes
- Build step: 60 minutes per platform
- Test step: 30 minutes per platform

### Cache Workflow: `cache-warmup.yml`

**Purpose:** Pre-populate caches to speed up builds

**Triggers:**
- Workflow dispatch (manual)
- Scheduled: Weekly on Sundays at 00:00 UTC

**What it caches:**
- Python embedded runtimes for each platform
- Pre-downloaded language servers
- UV virtualenv with dependencies

**Benefits:**
- Reduces build time by 30-50%
- Saves GitHub Actions minutes
- Reduces external download failures

## Build Configuration

### Platform Matrix

| Platform ID | Runner | Architecture | Cost Multiplier |
|------------|--------|--------------|----------------|
| linux-x64 | ubuntu-latest | x86_64 | 1x |
| win-x64 | windows-latest | x86_64 | 2x |
| macos-x64 | macos-13 | Intel x86_64 | 10x |
| macos-arm64 | macos-14 | Apple Silicon | 10x |

### Language Set Configuration

Defined in `build_portable.sh`:

```bash
declare -A LANGUAGE_SETS=(
    ["minimal"]="python typescript go"
    ["standard"]="python typescript go rust java ruby php"
    ["full"]="python typescript go rust java ruby php perl clojure elixir terraform swift bash csharp"
)
```

### Workflow Inputs

All inputs are optional with sensible defaults:

- **platform_filter**: 
  - `all` (default) - Build for all platforms
  - `ubuntu` - Linux only
  - `windows` - Windows only
  - `macos-intel` - macOS Intel only
  - `macos-arm` - macOS ARM only
  - Comma-separated list: `ubuntu,windows`

- **language_set**:
  - `minimal` - ~200MB package
  - `standard` (default) - ~500MB package
  - `full` - ~1.5GB package

- **include_all_languages**: Boolean override for full set

- **skip_tests**: Skip integration tests (faster, but less verification)

- **upload_to_release**: Upload to GitHub release (default: true for releases)

## Cache Strategy

### Cache Layers

The system uses a layered caching strategy optimized for volatility:

#### Layer 1: Python Embedded Runtime
**Key:** `python-embedded-{os}-{arch}-{python_version}-{cache_version}`

**Contents:**
- Python interpreter and standard library
- Platform-specific (~50-150MB)

**Volatility:** Very low (changes only with Python version updates)

**Restore-keys:** None (exact match required)

#### Layer 2: Language Servers
**Key:** `language-servers-portable-{os}-{arch}-{language_config}-{cache_version}`

**Contents:**
- Pre-downloaded language server binaries
- Platform and language-set specific (~100-500MB)

**Volatility:** Low (changes when language servers update)

**Restore-keys:**
```yaml
restore-keys: |
  language-servers-portable-{os}-{arch}-
  language-servers-{os}-
```

#### Layer 3: UV Virtualenv
**Key:** `uv-venv-portable-{os}-{python_version}-{hash(uv.lock)}-{cache_version}`

**Contents:**
- Python packages installed by UV
- Changes with dependency updates

**Volatility:** Medium (changes with uv.lock updates)

**Restore-keys:**
```yaml
restore-keys: |
  uv-venv-portable-{os}-{python_version}-
```

#### Layer 4: Build Artifacts
**Key:** `build-{os}-{sha}`

**Contents:**
- Incremental build outputs
- Reused within same commit

**Volatility:** High (per-commit)

**Restore-keys:**
```yaml
restore-keys: |
  build-{os}-
```

### Cache Limits

GitHub Actions cache limits:
- **Total cache size:** 10GB per repository
- **Single cache entry:** No explicit limit
- **Retention:** 7 days of inactivity

### Cache Distribution Estimate

For standard configuration across all platforms:

| Layer | Size per Platform | Total (4 platforms) |
|-------|------------------|---------------------|
| Python Embedded | ~100MB | ~400MB |
| Language Servers | ~300MB | ~1.2GB |
| UV Virtualenv | ~200MB | ~800MB |
| Build Artifacts | ~100MB | ~400MB |
| **Total** | **~700MB** | **~2.8GB** |

This leaves ~7GB for other caches and CI workflows.

### Cache Warming

Run the cache warmup workflow:
- Before major releases
- After Python version updates
- After adding new language servers
- Weekly via scheduled run

Benefits:
- First build after cache: ~15-20 minutes
- Build without cache: ~30-40 minutes
- **Savings: 40-50% time reduction**

## Testing

### Test Levels

#### 1. Sanity Tests (Always)
Performed by `test_portable.sh`:
- Package structure verification
- File existence checks
- Python runtime validation
- Module import tests
- CLI command tests (--version, --help)

**Duration:** ~2-3 minutes

#### 2. Integration Tests (Configurable)
- Python file compilation
- Language server availability
- Basic project operations

**Duration:** ~10-15 minutes

**Skip with:** `skip_tests: true`

#### 3. Manual Tests (Recommended)
After downloading a release:
- Extract package
- Run `bin/serena --version`
- Start MCP server
- Connect from Claude Desktop
- Activate a test project
- List symbols, edit files

### Test Script Usage

```bash
# Basic test
./scripts/portable/test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64

# With test project
./scripts/portable/test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64 \
  --test-project /path/to/test/project

# Verbose output
./scripts/portable/test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64 \
  --verbose
```

## Cost Optimization

### GitHub Actions Minute Costs

**Free tier limits:**
- Linux: 2,000 minutes/month
- Windows: 1,000 minutes/month (2x multiplier)
- macOS: 200 minutes/month (10x multiplier)

### Cost per Build Scenario

Based on estimated build times:

#### Scenario 1: All Platforms, Standard Set, Full Tests
| Platform | Time | Raw Minutes | Billable Minutes |
|----------|------|-------------|------------------|
| Linux | 25 min | 25 | 25 |
| Windows | 30 min | 30 | 60 |
| macOS Intel | 35 min | 35 | 350 |
| macOS ARM | 35 min | 35 | 350 |
| **Total** | **125 min** | **125** | **785** |

#### Scenario 2: All Platforms, Standard Set, Skip Tests
| Platform | Time | Raw Minutes | Billable Minutes |
|----------|------|-------------|------------------|
| Linux | 18 min | 18 | 18 |
| Windows | 22 min | 22 | 44 |
| macOS Intel | 25 min | 25 | 250 |
| macOS ARM | 25 min | 25 | 250 |
| **Total** | **90 min** | **90** | **562** |

#### Scenario 3: Linux Only, Standard Set
| Platform | Time | Raw Minutes | Billable Minutes |
|----------|------|-------------|------------------|
| Linux | 25 min | 25 | 25 |

#### Scenario 4: All Platforms, Minimal Set, Skip Tests
| Platform | Time | Raw Minutes | Billable Minutes |
|----------|------|-------------|------------------|
| Linux | 15 min | 15 | 15 |
| Windows | 18 min | 18 | 36 |
| macOS Intel | 20 min | 20 | 200 |
| macOS ARM | 20 min | 20 | 200 |
| **Total** | **73 min** | **73** | **451** |

### Optimization Strategies

#### 1. Selective Platform Builds
For testing changes:
```bash
# Test on Linux first (cheapest)
platform_filter: ubuntu

# Then Windows
platform_filter: windows

# Finally macOS if needed
platform_filter: macos-intel,macos-arm
```

#### 2. Use Cache Warmup
- Run weekly to keep caches fresh
- Reduces build time by 40-50%
- One-time cost of ~200 minutes saves 200+ minutes on subsequent builds

#### 3. Skip Tests During Development
- Use `skip_tests: true` for rapid iterations
- Run full tests only for release candidates
- Saves ~30% of build time

#### 4. Minimal Language Set for Testing
- Use `language_set: minimal` during development
- Switch to `standard` or `full` only for releases
- Reduces package size and build time

#### 5. Schedule Wisely
- Avoid running all platforms simultaneously during development
- Save full matrix builds for actual releases
- Use workflow_dispatch for targeted builds

### Monthly Budget Planning

**Conservative estimate for a project with:**
- 4 releases per month (full builds)
- 10 development builds (Linux only)
- 4 cache warmup runs

| Activity | Builds | Minutes | Billable |
|----------|--------|---------|----------|
| Releases (all platforms) | 4 | 360 | 2,248 |
| Dev builds (Linux) | 10 | 250 | 250 |
| Cache warmup (all) | 4 | 80 | 400 |
| **Total** | **18** | **690** | **2,898** |

**Cost breakdown:**
- Linux: ~500 minutes (within free tier)
- Windows: ~700 minutes (within free tier)
- macOS: ~2,100 minutes (exceeds free tier by ~1,900 minutes)

**Optimization:** Use Linux for most dev builds, reserve macOS for releases.

## Troubleshooting

### Build Failures

#### Python Download Failed
**Symptoms:** Download timeout or 404 error

**Solutions:**
1. Check Python version in workflow matches available releases
2. Verify URLs in build script
3. Use cache warmup to pre-download
4. Check GitHub Actions network status

#### Language Server Download Failed
**Symptoms:** Missing language servers in package

**Solutions:**
1. Check language server URLs in `src/solidlsp/language_servers/`
2. Verify platform compatibility
3. Pre-warm cache to catch issues early
4. Review language server logs in build output

#### Out of Disk Space
**Symptoms:** Build fails with disk space error

**Solutions:**
1. Clean up old caches manually
2. Use smaller language set
3. Remove build artifacts after each platform
4. GitHub runners typically have 14GB available

#### Test Failures
**Symptoms:** Tests fail but build succeeded

**Solutions:**
1. Check platform-specific issues (e.g., Windows path separators)
2. Verify launcher script permissions (Unix)
3. Review test output for specific failures
4. Try skip_tests temporarily to isolate issue

### Cache Issues

#### Cache Not Restoring
**Symptoms:** Build downloads everything despite cache

**Solutions:**
1. Check cache key format matches
2. Verify cache wasn't evicted (7-day retention)
3. Check cache size limits (10GB total)
4. Run cache warmup workflow

#### Stale Cache
**Symptoms:** Build uses outdated dependencies

**Solutions:**
1. Increment `CACHE_VERSION` in workflows
2. Run cache warmup with `force_refresh: true`
3. Update cache keys to include version numbers

#### Cache Eviction
**Symptoms:** Frequent cache misses despite recent builds

**Solutions:**
1. Monitor cache size in Settings → Actions → Caches
2. Remove unused caches manually
3. Optimize cache strategy to prioritize frequently-used layers
4. Consider reducing number of cached combinations

### Runtime Issues

#### Package Won't Start
**Symptoms:** Launcher fails immediately

**Solutions:**
1. Verify extracted directory structure
2. Check file permissions (Unix: `chmod +x bin/serena`)
3. Verify Python runtime for platform (ARM vs Intel on macOS)
4. Check for antivirus interference (Windows)

#### Import Errors
**Symptoms:** Module not found errors

**Solutions:**
1. Verify package was built with correct Python version
2. Check that dependencies were installed in portable Python
3. Review BUILD_INFO.json for build configuration
4. Try running `python -m pip list` in portable Python

#### Language Server Not Working
**Symptoms:** LSP features unavailable

**Solutions:**
1. Check `~/.serena/language_servers/` directory
2. Verify language server downloaded for platform
3. Check language server logs
4. Manually download missing language server
5. Verify language is in selected language set

### Platform-Specific Issues

#### Windows: "python.exe is not recognized"
**Solution:** Ensure python._pth file has `import site` uncommented

#### macOS: "serena cannot be opened because the developer cannot be verified"
**Solution:** 
```bash
xattr -cr serena-macos-*/
# Or right-click → Open → Open anyway
```

#### Linux: GLIBC version errors
**Solution:** Use Python Build Standalone builds which are self-contained

## Advanced Topics

### Custom Language Server Configuration

To include additional language servers:

1. Modify `LANGUAGE_SETS` in `build_portable.sh`
2. Add download logic in `download_ls.py` section
3. Test with minimal set first
4. Update documentation

### Cross-Platform Development

To test portable builds locally:

```bash
# Build
./scripts/portable/build_portable.sh \
  --platform linux-x64 \
  --version dev \
  --language-set minimal \
  --python-embedded /tmp/python \
  --output ./local-build

# Test
./scripts/portable/test_portable.sh \
  --package ./local-build/serena-linux-x64 \
  --platform linux-x64 \
  --verbose
```

### CI/CD Integration

Integrate portable builds into your workflow:

```yaml
# Example: Build on every push to main
on:
  push:
    branches: [main]

jobs:
  quick-build:
    uses: ./.github/workflows/portable-build.yml
    with:
      platform_filter: ubuntu
      language_set: minimal
      skip_tests: true
      upload_to_release: false
```

## Best Practices

1. **Always use cache warmup before major releases**
2. **Test Linux builds first** (fastest and cheapest)
3. **Use minimal language set for development** iterations
4. **Reserve full builds for actual releases**
5. **Monitor GitHub Actions minutes usage** monthly
6. **Document any custom language server additions**
7. **Version your cache** with CACHE_VERSION
8. **Keep Python version consistent** across all builds
9. **Test portable packages on clean systems** before release
10. **Include SHA256 checksums** in all releases

## Related Documentation

- [GitHub Actions Cache Documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Python Build Standalone](https://github.com/indygreg/python-build-standalone)
- [UV Package Manager](https://github.com/astral-sh/uv)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)

## Support

For issues or questions:
- GitHub Issues: https://github.com/oraios/serena/issues
- Discussions: https://github.com/oraios/serena/discussions

---

Last updated: 2025-10-31
Version: 1.0
