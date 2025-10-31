# Portable Build Quick Start Guide

**5-Minute Guide to Building and Distributing Serena Portable Packages**

## For Maintainers

### Trigger a Build

#### Option 1: GitHub Release (Automatic)
```bash
# Create and push a tag
git tag v0.1.5
git push origin v0.1.5

# Publish release on GitHub
# Portable builds start automatically
```

#### Option 2: Manual Workflow Dispatch
1. Go to GitHub → Actions → "Build Portable Packages"
2. Click "Run workflow"
3. Select options:
   - Platform: `all` (or specific platform)
   - Language set: `standard`
   - Upload to release: `true`
4. Click "Run workflow"

### Quick Commands

```bash
# Build locally (Linux example)
./scripts/portable/build_portable.sh \
  --platform linux-x64 \
  --version 0.1.5 \
  --language-set standard \
  --python-embedded /tmp/python \
  --output ./build

# Test the build
./scripts/portable/test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64

# Warm caches before release (saves 40% time)
# Go to GitHub → Actions → "Cache Warmup" → Run workflow
```

## For Users

### Download

1. Go to [Releases](https://github.com/oraios/serena/releases)
2. Download for your platform:
   - **Linux:** `serena-linux-x64-VERSION.tar.gz`
   - **Windows:** `serena-windows-x64-VERSION.zip`
   - **macOS Intel:** `serena-macos-x64-VERSION.tar.gz`
   - **macOS ARM:** `serena-macos-arm64-VERSION.tar.gz`

### Extract

```bash
# Linux/macOS
tar -xzf serena-linux-x64-v0.1.5.tar.gz
cd serena-linux-x64

# Windows: Use Explorer or 7-Zip
```

### Run

```bash
# Linux/macOS
./bin/serena --version
./bin/serena-mcp-server

# Windows
bin\serena.bat --version
bin\serena-mcp-server.bat
```

### Configure Claude Desktop

Add to Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "serena": {
      "command": "/path/to/serena-linux-x64/bin/serena-mcp-server",
      "args": []
    }
  }
}
```

## Common Scenarios

### Scenario 1: Quick Test Build (Linux Only)
**Use case:** Testing changes quickly

```yaml
Platform: ubuntu
Language set: minimal
Skip tests: true
Upload: false
```

**Time:** ~11 minutes
**Cost:** 11 billable minutes

### Scenario 2: Pre-Release Testing (All Platforms)
**Use case:** Testing before official release

```yaml
Platform: all
Language set: standard
Skip tests: false
Upload: false
```

**Time:** ~107 minutes
**Cost:** 664 billable minutes

### Scenario 3: Official Release (Full Build)
**Use case:** Public release

```yaml
Platform: all
Language set: standard
Skip tests: false
Upload: true
```

**Time:** ~107 minutes
**Cost:** 664 billable minutes
**Output:** Release artifacts with checksums

### Scenario 4: Emergency Hotfix
**Use case:** Quick fix release

```yaml
Platform: ubuntu  # Ship Linux first, others later
Language set: standard
Skip tests: true
Upload: true
```

**Time:** ~16 minutes
**Cost:** 16 billable minutes

## Troubleshooting

### Build Fails
```bash
# Check workflow logs in GitHub Actions
# Look for:
# - Download failures (Python, language servers)
# - Disk space issues
# - Test failures

# Quick fix: Run cache warmup
# Then retry build
```

### Package Won't Run
```bash
# Linux/macOS: Check permissions
chmod +x bin/serena
chmod +x bin/serena-mcp-server

# macOS: Remove quarantine
xattr -cr serena-macos-*/

# Windows: Check antivirus isn't blocking
```

### Missing Language Server
```bash
# Language servers download on first use
# Check logs at ~/.serena/language_servers/

# Manual fix: Re-run with that language
./bin/serena  # Will auto-download missing servers
```

## Cost Optimization

### During Development
- ✅ Use Linux for testing
- ✅ Use minimal language set
- ✅ Skip tests
- ✅ Don't upload to release

**Cost:** ~11 minutes per build

### Before Release
- ✅ Run cache warmup
- ✅ Test on all platforms
- ✅ Use standard language set
- ✅ Run full tests

**Cost:** ~664 minutes (with warm cache)

### For Release
- ✅ All platforms
- ✅ Standard or full language set
- ✅ Full tests
- ✅ Upload to release

**Cost:** 664-1044 minutes depending on language set

## Quick Reference

### Language Sets

| Set | Languages | Package Size | Use Case |
|-----|-----------|-------------|----------|
| minimal | Python, TS, Go | ~200MB | Quick testing |
| standard | + Rust, Java, Ruby, PHP | ~500MB | Most users |
| full | All 16+ languages | ~1.5GB | Power users |

### Platform Costs

| Platform | Multiplier | Free Minutes/Month |
|----------|-----------|-------------------|
| Linux | 1x | 2,000 |
| Windows | 2x | 1,000 |
| macOS | 10x | 200 |

### Build Times (with cache)

| Config | Linux | Windows | macOS | Total Billable |
|--------|-------|---------|-------|----------------|
| Minimal, skip tests | 11 min | 15 min | 17 min | 372 min |
| Standard, skip tests | 16 min | 21 min | 24 min | 482 min |
| Standard, full tests | 21 min | 27 min | 31 min | 664 min |
| Full, full tests | 33 min | 42 min | 49 min | 1,044 min |

## Important Files

```
.github/workflows/
├── portable-build.yml      # Main build workflow
└── cache-warmup.yml        # Cache warmup workflow

scripts/portable/
├── build_portable.sh       # Build script
└── test_portable.sh        # Test script

docs/
├── portable-builds.md           # Full documentation
├── portable-build-costs.md      # Cost analysis
└── portable-build-quickstart.md # This file
```

## Next Steps

1. **Read full documentation:** [portable-builds.md](./portable-builds.md)
2. **Understand costs:** [portable-build-costs.md](./portable-build-costs.md)
3. **Run cache warmup** before first build
4. **Test on Linux first** to validate changes
5. **Build all platforms** for release

## Support

- **Issues:** [GitHub Issues](https://github.com/oraios/serena/issues)
- **Discussions:** [GitHub Discussions](https://github.com/oraios/serena/discussions)

---

**Remember:** Always warm caches before important builds to save time and money!

Last updated: 2025-10-31
