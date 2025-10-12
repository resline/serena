# Serena MCP - Windows Language Server Bundle Guide

## Overview

This guide documents the Windows x64/ARM64 language server bundling system for Serena MCP's Essential Tier. The bundling script creates a portable, offline-installable package containing all necessary language servers and runtimes.

---

## Essential Tier Language Servers

The Essential Tier includes 6 language servers covering the most popular programming languages:

### 1. **Pyright** - Python Language Server
- **Type**: npm package
- **Version**: 1.1.396
- **Download URL**: https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz
- **Size**: ~15 MB
- **Binary**: `pyright-langserver`
- **Requires**: Node.js 20.11.1+
- **Installation**: Via npm in bundle
- **Command**: `node.exe pyright-langserver --stdio`

### 2. **TypeScript Language Server**
- **Type**: npm package
- **Version**: 4.3.3
- **Download URL**: https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz
- **Size**: ~8 MB
- **Binary**: `typescript-language-server`
- **Requires**: Node.js 20.11.1+ and TypeScript 5.5.4
- **Additional Packages**: `typescript@5.5.4`
- **Command**: `node.exe typescript-language-server --stdio`

### 3. **rust-analyzer** - Rust Language Server
- **Type**: GitHub binary release
- **Version**: latest
- **Download URLs**:
  - x64: https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.gz
  - ARM64: https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-aarch64-pc-windows-msvc.gz
- **Size**: ~15 MB (compressed)
- **Binary**: `rust-analyzer.exe`
- **Archive**: gzip (.gz)
- **Command**: `rust-analyzer.exe`

### 4. **gopls** - Go Language Server
- **Type**: GitHub binary release
- **Version**: v0.20.0
- **Download URLs**:
  - x64: https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip
  - ARM64: https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_arm64.zip
- **Size**: ~20 MB
- **Binary**: `gopls.exe`
- **Archive**: zip
- **Command**: `gopls.exe`

### 5. **Lua Language Server**
- **Type**: GitHub binary release
- **Version**: 3.15.0
- **Download URLs**:
  - x64: https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip
  - ARM64: Not available (uses x64 with emulation)
- **Size**: ~12 MB
- **Binary**: `bin/lua-language-server.exe`
- **Archive**: zip
- **Command**: `bin\lua-language-server.exe`

### 6. **Marksman** - Markdown Language Server
- **Type**: GitHub binary release
- **Version**: 2024-12-18
- **Download URLs**:
  - x64: https://github.com/artempyanykh/marksman/releases/download/2024-12-18/marksman-windows-x64.exe
  - ARM64: Not available (uses x64 with emulation)
- **Size**: ~8 MB
- **Binary**: `marksman.exe`
- **Archive**: Direct executable
- **Command**: `marksman.exe server`

---

## Runtime Dependencies

### Node.js 20.11.1

Required for npm-based language servers (Pyright, TypeScript).

- **Version**: 20.11.1 LTS
- **Download URLs**:
  - x64: https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip
  - ARM64: https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-arm64.zip
- **Size**: ~28 MB
- **Includes**: node.exe, npm.cmd, npx.cmd
- **Archive**: zip
- **Checksum Type**: SHA256
- **Installation**: Extracted to `runtimes/nodejs/`

---

## Bundle Directory Structure

After running the bundling script, the following structure is created:

```
serena-ls-bundle/
├── language_servers/
│   ├── python/
│   │   ├── node_modules/
│   │   │   └── pyright/
│   │   │       ├── langserver.index.js
│   │   │       └── ...
│   │   └── package.json
│   │
│   ├── typescript/
│   │   ├── node_modules/
│   │   │   ├── typescript-language-server/
│   │   │   │   ├── lib/cli.js
│   │   │   │   └── ...
│   │   │   └── typescript/
│   │   │       └── ...
│   │   └── package.json
│   │
│   ├── rust/
│   │   └── rust-analyzer.exe
│   │
│   ├── go/
│   │   └── gopls.exe
│   │
│   ├── lua/
│   │   ├── bin/
│   │   │   └── lua-language-server.exe
│   │   ├── meta/
│   │   └── ...
│   │
│   └── markdown/
│       └── marksman.exe
│
├── runtimes/
│   └── nodejs/
│       ├── node.exe
│       ├── npm.cmd
│       ├── npx.cmd
│       └── node_modules/
│           └── npm/
│
├── bundle-manifest.json
├── INSTALLATION.md
└── (temp/ - cleaned up after completion)
```

---

## Bundle Manifest Schema

The `bundle-manifest.json` file contains metadata about the bundle:

```json
{
  "version": "1.0.0",
  "created": "2025-01-16T12:00:00Z",
  "architecture": "x64",
  "tier": "essential",
  "nodeJSVersion": "20.11.1",
  "languageServers": {
    "pyright": {
      "name": "Pyright (Python)",
      "language": "python",
      "version": "1.1.396",
      "type": "npm",
      "binary": "pyright-langserver",
      "path": "language_servers/python"
    },
    "typescript-language-server": {
      "name": "TypeScript Language Server",
      "language": "typescript",
      "version": "4.3.3",
      "type": "npm",
      "binary": "typescript-language-server",
      "path": "language_servers/typescript"
    },
    "rust-analyzer": {
      "name": "Rust Analyzer",
      "language": "rust",
      "version": "latest",
      "type": "binary",
      "binary": "rust-analyzer.exe",
      "path": "language_servers/rust"
    },
    "gopls": {
      "name": "gopls (Go)",
      "language": "go",
      "version": "v0.20.0",
      "type": "binary",
      "binary": "gopls.exe",
      "path": "language_servers/go"
    },
    "lua-language-server": {
      "name": "Lua Language Server",
      "language": "lua",
      "version": "3.15.0",
      "type": "binary",
      "binary": "bin/lua-language-server.exe",
      "path": "language_servers/lua"
    },
    "marksman": {
      "name": "Marksman (Markdown)",
      "language": "markdown",
      "version": "2024-12-18",
      "type": "binary",
      "binary": "marksman.exe",
      "path": "language_servers/markdown"
    }
  }
}
```

---

## Usage Instructions

### Basic Usage

```powershell
# Create bundle in default location (.\serena-ls-bundle)
.\bundle-language-servers-windows.ps1

# Specify custom output directory
.\bundle-language-servers-windows.ps1 -OutputDir "C:\MyBundle"

# Create ARM64 bundle
.\bundle-language-servers-windows.ps1 -Architecture arm64

# Force re-download of all files
.\bundle-language-servers-windows.ps1 -Force

# Skip checksum verification (not recommended)
.\bundle-language-servers-windows.ps1 -SkipChecksums

# Exclude Node.js runtime (for environments where Node.js is already available)
.\bundle-language-servers-windows.ps1 -IncludeNodeJS $false
```

### Script Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `OutputDir` | string | `.\serena-ls-bundle` | Directory to create the bundle in |
| `Architecture` | string | `x64` | Target architecture (x64 or arm64) |
| `IncludeNodeJS` | bool | `true` | Include portable Node.js runtime |
| `Force` | switch | `false` | Force re-download even if files exist |
| `SkipChecksums` | switch | `false` | Skip checksum verification |

---

## Verification Commands

After bundling, verify each language server:

### 1. Node.js Runtime
```powershell
.\serena-ls-bundle\runtimes\nodejs\node.exe --version
# Expected: v20.11.1

.\serena-ls-bundle\runtimes\nodejs\npm.cmd --version
# Expected: 10.x.x
```

### 2. Pyright
```powershell
.\serena-ls-bundle\runtimes\nodejs\node.exe `
  .\serena-ls-bundle\language_servers\python\node_modules\pyright\langserver.index.js `
  --version
# Expected: pyright 1.1.396
```

### 3. TypeScript Language Server
```powershell
.\serena-ls-bundle\runtimes\nodejs\node.exe `
  .\serena-ls-bundle\language_servers\typescript\node_modules\typescript-language-server\lib\cli.js `
  --version
# Expected: 4.3.3
```

### 4. rust-analyzer
```powershell
.\serena-ls-bundle\language_servers\rust\rust-analyzer.exe --version
# Expected: rust-analyzer <version>
```

### 5. gopls
```powershell
.\serena-ls-bundle\language_servers\go\gopls.exe version
# Expected: golang.org/x/tools/gopls v0.20.0
```

### 6. Lua Language Server
```powershell
.\serena-ls-bundle\language_servers\lua\bin\lua-language-server.exe --version
# Expected: 3.15.0
```

### 7. Marksman
```powershell
.\serena-ls-bundle\language_servers\markdown\marksman.exe --version
# Expected: marksman 2024-12-18
```

---

## Estimated Download Sizes

| Component | Size (Compressed) | Size (Extracted) |
|-----------|------------------|------------------|
| Node.js 20.11.1 | 28 MB | 60 MB |
| Pyright | 5 MB | 15 MB |
| TypeScript LS + TypeScript | 3 MB | 10 MB |
| rust-analyzer | 8 MB (gz) | 15 MB |
| gopls | 20 MB | 20 MB |
| Lua Language Server | 12 MB | 12 MB |
| Marksman | 8 MB | 8 MB |
| **Total** | **~84 MB** | **~140 MB** |

With additional npm overhead and node_modules, expect final bundle size: **~180-200 MB**

---

## Architecture Support

### x64 (AMD64)
- **Full Support**: All 6 language servers have native x64 binaries
- **Performance**: Native performance
- **Compatibility**: Windows 10+ (64-bit)

### ARM64 (AArch64)
- **Native Support**:
  - rust-analyzer ✓
  - gopls ✓
  - Pyright (via Node.js) ✓
  - TypeScript LS (via Node.js) ✓
- **x64 Emulation**:
  - Lua Language Server (uses x64 binary)
  - Marksman (uses x64 binary)
- **Performance**: Native for most, acceptable emulation for others
- **Compatibility**: Windows 11 ARM64

---

## Error Handling & Retry Logic

The script includes comprehensive error handling:

### Download Failures
- Automatic retry with exponential backoff
- Falls back to x64 if ARM64 binary not available
- Verifies file integrity after download

### Extraction Failures
- Validates archive before extraction
- Cleans up partial extractions on failure
- Provides detailed error messages

### npm Installation Failures
- Verifies Node.js availability before npm installs
- Uses `--no-save` to avoid package-lock conflicts
- Cleans up on failure

### Checksum Verification
- SHA256 checksums for all downloads (when available)
- Can be skipped with `-SkipChecksums` if needed
- Automatic cleanup of corrupted downloads

---

## Integration with Serena

### Configuration

Add to Serena's configuration file (`.serena/project.yml`):

```yaml
languageServers:
  python:
    command:
      - "C:\\path\\to\\serena-ls-bundle\\runtimes\\nodejs\\node.exe"
      - "C:\\path\\to\\serena-ls-bundle\\language_servers\\python\\node_modules\\pyright\\langserver.index.js"
      - "--stdio"

  typescript:
    command:
      - "C:\\path\\to\\serena-ls-bundle\\runtimes\\nodejs\\node.exe"
      - "C:\\path\\to\\serena-ls-bundle\\language_servers\\typescript\\node_modules\\typescript-language-server\\lib\\cli.js"
      - "--stdio"

  rust:
    command:
      - "C:\\path\\to\\serena-ls-bundle\\language_servers\\rust\\rust-analyzer.exe"

  go:
    command:
      - "C:\\path\\to\\serena-ls-bundle\\language_servers\\go\\gopls.exe"

  lua:
    command:
      - "C:\\path\\to\\serena-ls-bundle\\language_servers\\lua\\bin\\lua-language-server.exe"

  markdown:
    command:
      - "C:\\path\\to\\serena-ls-bundle\\language_servers\\markdown\\marksman.exe"
      - "server"
```

### Environment Variables (Optional)

For system-wide access:

```batch
REM Add Node.js to PATH
setx PATH "%PATH%;C:\path\to\serena-ls-bundle\runtimes\nodejs"

REM Add language servers to PATH
setx PATH "%PATH%;C:\path\to\serena-ls-bundle\language_servers\rust"
setx PATH "%PATH%;C:\path\to\serena-ls-bundle\language_servers\go"
```

---

## Troubleshooting

### Issue: "npm is not recognized"
**Solution**: Ensure Node.js is included in bundle or available in PATH

### Issue: "rust-analyzer.exe is not a valid Win32 application"
**Solution**: Re-download with correct architecture (x64 vs ARM64)

### Issue: Large bundle size
**Solution**: Bundle includes full Node.js runtime and dependencies. This is expected for offline installation.

### Issue: Checksum verification fails
**Solution**: Network corruption during download. Use `-Force` to re-download.

### Issue: Permission denied during extraction
**Solution**: Run PowerShell as Administrator or choose output directory with write permissions

---

## Advanced Usage

### Creating Distribution ZIP

```powershell
# After bundling
Compress-Archive -Path ".\serena-ls-bundle" -DestinationPath "serena-ls-bundle-essential-win-x64.zip"
```

### Updating Individual Language Server

```powershell
# Update only rust-analyzer
Remove-Item ".\serena-ls-bundle\language_servers\rust" -Recurse -Force
.\bundle-language-servers-windows.ps1 -Force
```

### Customizing for Specific Languages

Edit the `$EssentialLanguageServers` hashtable in the script to add/remove language servers.

---

## Dependencies

### Required
- PowerShell 5.1 or higher
- Windows 10 or higher
- Internet connection (for initial download)

### Optional
- `curl.exe` (faster downloads, included in Windows 10+)
- `tar.exe` (for .tar.gz archives, included in Windows 10+)

---

## Security Considerations

1. **Checksums**: Always verify checksums unless absolutely necessary to skip
2. **HTTPS**: All downloads use HTTPS URLs
3. **Official Sources**: Only downloads from official repositories (GitHub, npm registry, nodejs.org)
4. **No Elevated Privileges**: Script doesn't require administrator rights
5. **Isolated Installation**: Bundle is self-contained and doesn't modify system

---

## Future Enhancements

- [ ] Add .NET 9 runtime for C# language server
- [ ] Support for Java language server (Eclipse JDT-LS)
- [ ] Parallel downloads for faster bundling
- [ ] Resume capability for interrupted downloads
- [ ] Delta updates for existing bundles
- [ ] Automatic version checking and updates
- [ ] Code signing for executables

---

## License & Attribution

Language servers are provided by their respective maintainers:
- **Pyright**: Microsoft (MIT License)
- **TypeScript**: Microsoft (Apache-2.0)
- **rust-analyzer**: rust-lang (MIT/Apache-2.0)
- **gopls**: Google (BSD-3-Clause)
- **Lua Language Server**: LuaLS (MIT)
- **Marksman**: Artem Pyanykh (MIT)

---

## Version History

### v1.0.0 (2025-01-16)
- Initial release
- Support for 6 Essential Tier language servers
- Node.js 20.11.1 runtime
- x64 and ARM64 architecture support
- Comprehensive error handling
- Bundle manifest generation
- Installation guide creation

---

## Contact & Support

For issues or questions:
- GitHub Issues: [serena repository]
- Documentation: See CLAUDE.md for development setup
- Language Server Issues: Report to respective upstream projects
