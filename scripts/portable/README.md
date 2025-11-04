# Portable Build Scripts

This directory contains scripts for building and testing Serena portable packages.

## Scripts

### `build_portable.sh`

Creates a self-contained portable distribution of Serena.

**Features:**
- Bundles Python runtime (embedded/standalone)
- Installs Serena and all dependencies
- Pre-downloads language servers
- Creates platform-specific launcher scripts
- Generates build metadata and documentation

**Usage:**
```bash
./build_portable.sh \
  --platform PLATFORM \
  --version VERSION \
  --python-embedded PATH \
  --language-set SET \
  --output DIR
```

**Example:**
```bash
./build_portable.sh \
  --platform linux-x64 \
  --version 0.1.5 \
  --python-embedded /tmp/python-embedded \
  --language-set standard \
  --output ./build
```

### `test_portable.sh`

Validates a portable package with comprehensive tests.

**Test Categories:**
- Structure verification
- Python runtime checks
- Serena installation validation
- CLI functionality tests
- Language server availability
- Integration tests (optional)

**Usage:**
```bash
./test_portable.sh \
  --package PATH \
  --platform PLATFORM \
  [--test-project PATH] \
  [--verbose]
```

**Example:**
```bash
./test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64 \
  --verbose
```

## Quick Start

### 1. Prepare Python Runtime

**Linux:**
```bash
curl -L -o python.tar.gz \
  https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-x86_64-unknown-linux-gnu-install_only.tar.gz
mkdir -p /tmp/python-embedded
tar -xzf python.tar.gz -C /tmp/python-embedded --strip-components=1
```

**macOS (ARM):**
```bash
curl -L -o python.tar.gz \
  https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-aarch64-apple-darwin-install_only.tar.gz
mkdir -p /tmp/python-embedded
tar -xzf python.tar.gz -C /tmp/python-embedded --strip-components=1
```

**Windows (PowerShell):**
```powershell
$url = "https://www.python.org/ftp/python/3.11.10/python-3.11.10-embed-amd64.zip"
Invoke-WebRequest -Uri $url -OutFile python.zip
Expand-Archive -Path python.zip -DestinationPath C:\temp\python-embedded
```

### 2. Build Package

```bash
./build_portable.sh \
  --platform linux-x64 \
  --version 0.1.5 \
  --python-embedded /tmp/python-embedded \
  --language-set standard \
  --output ./build
```

### 3. Test Package

```bash
./test_portable.sh \
  --package ./build/serena-linux-x64 \
  --platform linux-x64
```

### 4. Create Archive

```bash
cd ./build
tar -czf serena-linux-x64-0.1.5.tar.gz serena-linux-x64/
sha256sum serena-linux-x64-0.1.5.tar.gz > serena-linux-x64-0.1.5.tar.gz.sha256
```

## Directory Structure

After building, the portable package has this structure:

```
serena-{platform}/
├── bin/
│   ├── serena                    # Main CLI launcher
│   └── serena-mcp-server         # MCP server launcher
├── python/
│   ├── bin/python3               # Python interpreter (Unix)
│   ├── python.exe                # Python interpreter (Windows)
│   ├── lib/                      # Python standard library
│   └── site-packages/            # Installed packages
├── serena/
│   ├── serena/                   # Serena source
│   └── solidlsp/                 # SolidLSP source
├── language_servers/
│   └── static/                   # Pre-downloaded language servers
├── BUILD_INFO.json               # Build metadata
├── VERSION                       # Version string
└── README.md                     # User documentation
```

## Language Sets

### Minimal (~200MB)
Essential languages for most users:
- Python
- TypeScript/JavaScript
- Go

### Standard (~500MB)
Common languages for web and systems development:
- All minimal languages
- Rust
- Java
- Ruby
- PHP

### Full (~1.5GB)
All supported languages:
- All standard languages
- C#, Perl, Clojure, Elixir
- Terraform, Swift, Bash
- Zig, Lua, Nix, and more

## Platform Support

| Platform ID | Runner | Architecture | Python Source |
|------------|--------|--------------|---------------|
| linux-x64 | ubuntu-latest | x86_64 | Python Build Standalone |
| win-x64 | windows-latest | x86_64 | Python.org Embedded |
| macos-x64 | macos-13 | Intel x86_64 | Python Build Standalone |
| macos-arm64 | macos-14 | Apple Silicon | Python Build Standalone |

## Environment Variables

Both scripts respect these environment variables:

- `SERENA_HOME`: Override default Serena home directory
- `PYTHON_VERSION`: Override Python version (default: 3.11)
- `VERBOSE`: Enable verbose output (any non-empty value)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Missing dependencies |
| 4 | Build failed |
| 5 | Tests failed |

## Debugging

### Enable Verbose Output

```bash
# Set verbose flag
./build_portable.sh --verbose ...
./test_portable.sh --verbose ...

# Or use environment variable
VERBOSE=1 ./build_portable.sh ...
```

### Common Issues

**Issue:** Python embedded not found
```bash
# Solution: Verify path exists
ls -la /tmp/python-embedded/
# Should contain bin/ (Unix) or python.exe (Windows)
```

**Issue:** Language server download fails
```bash
# Solution: Pre-warm cache or check internet connection
# Verify ~/.serena/language_servers/ exists
```

**Issue:** Permission denied on launchers
```bash
# Solution: Make scripts executable
chmod +x build/serena-*/bin/*
```

**Issue:** Package size too large
```bash
# Solution: Use minimal or standard language set
./build_portable.sh --language-set minimal ...
```

## CI/CD Integration

These scripts are designed to work in GitHub Actions:

```yaml
- name: Build portable package
  run: |
    ./scripts/portable/build_portable.sh \
      --platform ${{ matrix.platform }} \
      --version ${{ needs.prepare.outputs.version }} \
      --language-set standard \
      --python-embedded ${{ runner.temp }}/python-embedded \
      --output ${{ runner.temp }}/build

- name: Test portable package
  run: |
    ./scripts/portable/test_portable.sh \
      --package ${{ runner.temp }}/build/serena-${{ matrix.platform }} \
      --platform ${{ matrix.platform }}
```

## Performance Tips

1. **Use cache:** Pre-download Python and language servers
2. **Parallel builds:** Build different platforms simultaneously
3. **Skip tests:** Use `--skip-tests` during development
4. **Minimal set:** Use `--language-set minimal` for faster builds
5. **Local cache:** Keep `~/.serena/language_servers/` populated

## Security Considerations

- **Checksums:** Always verify SHA256 checksums of downloads
- **HTTPS only:** All downloads use HTTPS
- **No secrets:** Scripts don't require or expose secrets
- **Read-only:** Test script doesn't modify system state
- **Sandboxed:** Portable packages are self-contained

## Related Documentation

- [Portable Builds Guide](../../docs/portable-builds.md)
- [Cost Estimation](../../docs/portable-build-costs.md)
- [Quick Start](../../docs/portable-build-quickstart.md)

## Contributing

When modifying these scripts:

1. Test on all platforms (Linux, Windows, macOS)
2. Update documentation
3. Verify CI/CD workflows still work
4. Test with minimal, standard, and full language sets
5. Check performance impact

## Support

For issues or questions:
- GitHub Issues: https://github.com/oraios/serena/issues
- Discussions: https://github.com/oraios/serena/discussions

---

Last updated: 2025-10-31
Version: 1.0
