# Windows Language Server Bundle - Summary

## Deliverables

### 1. PowerShell Bundling Script
**Location**: `/root/repo/scripts/bundle-language-servers-windows.ps1`

A complete, production-ready PowerShell script that:
- Downloads all Essential Tier language servers
- Bundles portable Node.js 20.11.1 runtime
- Creates organized directory structure
- Generates manifest and installation guide
- Includes comprehensive error handling and retry logic
- Supports both x64 and ARM64 architectures
- Provides progress indicators and colored output

**Size**: ~800 lines of PowerShell code

### 2. Comprehensive Guide
**Location**: `/root/repo/scripts/BUNDLE-WINDOWS-GUIDE.md`

Complete documentation including:
- Detailed language server specifications
- Download URLs and versions
- Runtime dependencies
- Directory structure
- Manifest schema
- Usage instructions
- Verification commands
- Troubleshooting guide

---

## Essential Tier Language Servers (6 Total)

### Binary Downloads (4 servers)

#### 1. **rust-analyzer**
```
x64:   https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.gz
arm64: https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-aarch64-pc-windows-msvc.gz
Size:  ~15 MB
```

#### 2. **gopls**
```
x64:   https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip
arm64: https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_arm64.zip
Size:  ~20 MB
```

#### 3. **Lua Language Server**
```
x64:   https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip
arm64: Uses x64 with emulation
Size:  ~12 MB
```

#### 4. **Marksman**
```
x64:   https://github.com/artempyanykh/marksman/releases/download/2024-12-18/marksman-windows-x64.exe
arm64: Uses x64 with emulation
Size:  ~8 MB
```

### npm Packages (2 servers)

#### 5. **Pyright**
```
URL:     https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz
Version: 1.1.396
Size:    ~15 MB
Command: node.exe pyright-langserver --stdio
```

#### 6. **TypeScript Language Server**
```
URL:     https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz
Version: 4.3.3
Size:    ~8 MB
Deps:    typescript@5.5.4
Command: node.exe typescript-language-server --stdio
```

---

## Runtime Dependencies

### Node.js 20.11.1 (Required for npm-based servers)
```
x64:   https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip
arm64: https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-arm64.zip
Size:  ~28 MB (compressed), ~60 MB (extracted)
```

---

## Bundle Structure

```
serena-ls-bundle/                    [~180-200 MB total]
│
├── language_servers/
│   ├── python/                      [~15 MB]
│   │   └── node_modules/pyright/
│   │
│   ├── typescript/                  [~10 MB]
│   │   └── node_modules/
│   │       ├── typescript-language-server/
│   │       └── typescript/
│   │
│   ├── rust/                        [~15 MB]
│   │   └── rust-analyzer.exe
│   │
│   ├── go/                          [~20 MB]
│   │   └── gopls.exe
│   │
│   ├── lua/                         [~12 MB]
│   │   └── bin/lua-language-server.exe
│   │
│   └── markdown/                    [~8 MB]
│       └── marksman.exe
│
├── runtimes/
│   └── nodejs/                      [~60 MB]
│       ├── node.exe
│       ├── npm.cmd
│       └── node_modules/npm/
│
├── bundle-manifest.json             [~2 KB]
├── INSTALLATION.md                  [~5 KB]
└── (temp/ - auto-cleaned)
```

---

## Size Breakdown

| Component | Compressed | Extracted | Notes |
|-----------|-----------|-----------|-------|
| Node.js 20.11.1 | 28 MB | 60 MB | Includes npm |
| Pyright | 5 MB | 15 MB | Via npm |
| TypeScript LS | 3 MB | 10 MB | Via npm |
| rust-analyzer | 8 MB | 15 MB | .gz compressed |
| gopls | 20 MB | 20 MB | .zip archive |
| Lua LS | 12 MB | 12 MB | .zip archive |
| Marksman | 8 MB | 8 MB | Single .exe |
| **Total** | **~84 MB** | **~140 MB** | + npm overhead |

**Final Bundle Size**: **180-200 MB** (includes node_modules and package files)

---

## Verification Commands

### Quick Test All Language Servers
```powershell
# Navigate to bundle directory
cd .\serena-ls-bundle

# Test Node.js
.\runtimes\nodejs\node.exe --version

# Test Pyright
.\runtimes\nodejs\node.exe .\language_servers\python\node_modules\pyright\langserver.index.js --version

# Test TypeScript LS
.\runtimes\nodejs\node.exe .\language_servers\typescript\node_modules\typescript-language-server\lib\cli.js --version

# Test rust-analyzer
.\language_servers\rust\rust-analyzer.exe --version

# Test gopls
.\language_servers\go\gopls.exe version

# Test Lua LS
.\language_servers\lua\bin\lua-language-server.exe --version

# Test Marksman
.\language_servers\markdown\marksman.exe --version
```

### Expected Output
```
v20.11.1                              # Node.js
pyright 1.1.396                       # Pyright
4.3.3                                 # TypeScript LS
rust-analyzer 0.3.xxxx-xxx           # rust-analyzer
golang.org/x/tools/gopls v0.20.0     # gopls
3.15.0                                # Lua LS
marksman 2024-12-18                   # Marksman
```

---

## Usage Examples

### Create Default Bundle
```powershell
.\bundle-language-servers-windows.ps1
```
Creates bundle in `.\serena-ls-bundle` with x64 binaries.

### Create ARM64 Bundle
```powershell
.\bundle-language-servers-windows.ps1 -Architecture arm64
```

### Custom Output Directory
```powershell
.\bundle-language-servers-windows.ps1 -OutputDir "C:\MyBundle"
```

### Force Re-download
```powershell
.\bundle-language-servers-windows.ps1 -Force
```

### Skip Checksums (faster, less safe)
```powershell
.\bundle-language-servers-windows.ps1 -SkipChecksums
```

### Without Node.js (if already available)
```powershell
.\bundle-language-servers-windows.ps1 -IncludeNodeJS $false
```

---

## Architecture Support

### x64 (Windows 10/11 64-bit)
✅ **All 6 language servers have native x64 binaries**
- rust-analyzer: Native x64
- gopls: Native x64
- Lua LS: Native x64
- Marksman: Native x64
- Pyright: Node.js (native x64)
- TypeScript LS: Node.js (native x64)

### ARM64 (Windows 11 ARM)
✅ **4 language servers with native ARM64**
- rust-analyzer: Native ARM64 ✓
- gopls: Native ARM64 ✓
- Pyright: Node.js ARM64 ✓
- TypeScript LS: Node.js ARM64 ✓

⚠️ **2 language servers using x64 emulation**
- Lua LS: x64 emulation (acceptable performance)
- Marksman: x64 emulation (acceptable performance)

---

## Key Features

### ✅ Implemented
- [x] Complete Essential Tier (6 language servers)
- [x] Portable Node.js 20.11.1 runtime
- [x] x64 and ARM64 architecture support
- [x] Automatic fallback to x64 for ARM64 when needed
- [x] Comprehensive error handling and retry logic
- [x] Progress indicators and colored output
- [x] Checksum verification (SHA256)
- [x] Bundle manifest generation (JSON)
- [x] Installation guide generation
- [x] Automatic cleanup of temp files
- [x] Force re-download option
- [x] Skip checksum option
- [x] Optional Node.js inclusion

### 📋 Future Enhancements
- [ ] Parallel downloads (faster bundling)
- [ ] Resume capability for interrupted downloads
- [ ] Delta updates for existing bundles
- [ ] .NET 9 runtime for C# language server
- [ ] Java language server (Eclipse JDT-LS)
- [ ] Automatic version checking
- [ ] Code signing for executables

---

## Error Handling

The script includes robust error handling for:

1. **Download Failures**
   - Network timeouts
   - HTTP errors (404, 500, etc.)
   - Disk space issues
   - Permission errors

2. **Extraction Failures**
   - Corrupted archives
   - Unsupported archive formats
   - Insufficient disk space

3. **npm Installation Failures**
   - Missing Node.js
   - Package resolution errors
   - Network issues

4. **Checksum Failures**
   - Corrupted downloads
   - Man-in-the-middle attacks
   - Automatic cleanup and retry

---

## Integration with Serena MCP

### Quick Setup
1. Run bundling script to create bundle
2. Copy bundle to target system
3. Update Serena configuration to point to bundle paths
4. Start Serena MCP

### Configuration Example
```yaml
# .serena/project.yml
languageServers:
  python:
    command:
      - "C:\\serena-ls-bundle\\runtimes\\nodejs\\node.exe"
      - "C:\\serena-ls-bundle\\language_servers\\python\\node_modules\\pyright\\langserver.index.js"
      - "--stdio"

  # ... (see BUNDLE-WINDOWS-GUIDE.md for complete config)
```

---

## Distribution

### Creating ZIP for Distribution
```powershell
# After bundling
Compress-Archive -Path ".\serena-ls-bundle" `
                 -DestinationPath "serena-ls-bundle-essential-win-x64.zip"
```

### Distribution Sizes
- **x64 Bundle ZIP**: ~80-100 MB (compressed)
- **ARM64 Bundle ZIP**: ~80-100 MB (compressed)
- **Extracted**: ~180-200 MB

---

## Prerequisites

### Required
- PowerShell 5.1 or higher (Windows 10+)
- Internet connection for initial download
- ~1 GB free disk space (for temporary files and bundle)

### Optional (Improves Performance)
- `curl.exe` - Faster downloads (included in Windows 10+)
- `tar.exe` - For .tar.gz extraction (included in Windows 10+)

---

## Security

✅ **Security Measures**
- All downloads via HTTPS
- SHA256 checksum verification
- Downloads from official sources only:
  - GitHub releases (rust-analyzer, gopls, lua-ls, marksman)
  - npm registry (pyright, typescript-ls)
  - nodejs.org (Node.js runtime)
- No elevated privileges required
- Self-contained installation (no system modifications)

---

## Testing

### Automated Testing
The script provides colored output for easy verification:
- 🟢 Green: Successful operations
- 🔴 Red: Errors and failures
- 🟡 Yellow: Warnings and fallbacks
- 🔵 Cyan: Informational messages
- 🟣 Magenta: Step headers

### Manual Verification
Use verification commands to test each language server after bundling.

---

## Performance

### Download Time (Estimates)
- Fast Connection (100 Mbps): ~1-2 minutes
- Medium Connection (10 Mbps): ~10-15 minutes
- Slow Connection (1 Mbps): ~90-120 minutes

### Bundle Creation Time
- With Node.js: ~3-5 minutes (includes npm installs)
- Without Node.js: ~1-2 minutes (binary downloads only)

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| npm not found | Ensure Node.js is included or available in PATH |
| Wrong architecture | Use `-Architecture arm64` or `-Architecture x64` |
| Checksum fails | Network corruption; use `-Force` to re-download |
| Permission denied | Run as Admin or choose directory with write permissions |
| Large bundle size | Expected for offline installation with full Node.js |
| Slow downloads | Use faster internet or consider pre-downloaded cache |

---

## Support & Documentation

- **Main Guide**: `/root/repo/scripts/BUNDLE-WINDOWS-GUIDE.md`
- **Script**: `/root/repo/scripts/bundle-language-servers-windows.ps1`
- **Existing Infrastructure**: `/root/repo/scripts/build-windows/download-language-servers.ps1`
- **Development Setup**: `/root/repo/CLAUDE.md`

---

## Credits

**Language Servers**:
- Pyright: Microsoft
- TypeScript LS: Microsoft
- rust-analyzer: Rust Language Team
- gopls: Google Go Team
- Lua Language Server: LuaLS Community
- Marksman: Artem Pyanykh

**Script Author**: Claude (Anthropic)
**Created**: 2025-01-16
**Version**: 1.0.0
