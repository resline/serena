# Windows Language Server Bundle - Quick Reference

## 📦 Essential Tier Language Servers

| # | Language Server | Type | Size | Download URL |
|---|----------------|------|------|--------------|
| 1 | **Pyright** | npm | 15MB | https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz |
| 2 | **TypeScript LS** | npm | 8MB | https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz |
| 3 | **rust-analyzer** | binary | 15MB | https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.gz |
| 4 | **gopls** | binary | 20MB | https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip |
| 5 | **Lua LS** | binary | 12MB | https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip |
| 6 | **Marksman** | binary | 8MB | https://github.com/artempyanykh/marksman/releases/download/2024-12-18/marksman-windows-x64.exe |

**Runtime**: Node.js 20.11.1 (28MB) - https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip

---

## 🚀 Quick Start

```powershell
# Create bundle (default: x64, includes Node.js)
.\bundle-language-servers-windows.ps1

# Create ARM64 bundle
.\bundle-language-servers-windows.ps1 -Architecture arm64

# Force re-download
.\bundle-language-servers-windows.ps1 -Force
```

---

## 📁 Bundle Structure (180-200 MB)

```
serena-ls-bundle/
├── language_servers/
│   ├── python/           # Pyright (15MB)
│   ├── typescript/       # TypeScript LS (10MB)
│   ├── rust/             # rust-analyzer (15MB)
│   ├── go/               # gopls (20MB)
│   ├── lua/              # Lua LS (12MB)
│   └── markdown/         # Marksman (8MB)
├── runtimes/
│   └── nodejs/           # Node.js 20.11.1 (60MB)
├── bundle-manifest.json
└── INSTALLATION.md
```

---

## ✅ Verification Commands

```powershell
# Node.js
.\runtimes\nodejs\node.exe --version

# Pyright
.\runtimes\nodejs\node.exe .\language_servers\python\node_modules\pyright\langserver.index.js --version

# TypeScript LS
.\runtimes\nodejs\node.exe .\language_servers\typescript\node_modules\typescript-language-server\lib\cli.js --version

# rust-analyzer
.\language_servers\rust\rust-analyzer.exe --version

# gopls
.\language_servers\go\gopls.exe version

# Lua LS
.\language_servers\lua\bin\lua-language-server.exe --version

# Marksman
.\language_servers\markdown\marksman.exe --version
```

---

## 🎯 Architecture Support

| Server | x64 | ARM64 | Notes |
|--------|-----|-------|-------|
| Pyright | ✅ | ✅ | Via Node.js |
| TypeScript LS | ✅ | ✅ | Via Node.js |
| rust-analyzer | ✅ | ✅ | Native support |
| gopls | ✅ | ✅ | Native support |
| Lua LS | ✅ | ⚠️ | x64 emulation |
| Marksman | ✅ | ⚠️ | x64 emulation |

---

## 🛠️ Script Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-OutputDir` | string | `.\serena-ls-bundle` | Output directory |
| `-Architecture` | string | `x64` | x64 or arm64 |
| `-IncludeNodeJS` | bool | `true` | Include Node.js |
| `-Force` | switch | `false` | Force re-download |
| `-SkipChecksums` | switch | `false` | Skip verification |

---

## 📊 Download URLs by Architecture

### x64
```
rust-analyzer:  https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-pc-windows-msvc.gz
gopls:          https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_amd64.zip
lua-ls:         https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-win32-x64.zip
marksman:       https://github.com/artempyanykh/marksman/releases/download/2024-12-18/marksman-windows-x64.exe
nodejs:         https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-x64.zip
```

### ARM64
```
rust-analyzer:  https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-aarch64-pc-windows-msvc.gz
gopls:          https://github.com/golang/tools/releases/download/gopls/v0.20.0/gopls_v0.20.0_windows_arm64.zip
lua-ls:         (uses x64)
marksman:       (uses x64)
nodejs:         https://nodejs.org/dist/v20.11.1/node-v20.11.1-win-arm64.zip
```

---

## 💾 Size Estimates

| Component | Compressed | Extracted |
|-----------|-----------|-----------|
| Node.js | 28 MB | 60 MB |
| Pyright | 5 MB | 15 MB |
| TypeScript LS | 3 MB | 10 MB |
| rust-analyzer | 8 MB | 15 MB |
| gopls | 20 MB | 20 MB |
| Lua LS | 12 MB | 12 MB |
| Marksman | 8 MB | 8 MB |
| **Total** | **~84 MB** | **~180 MB** |

---

## 🔧 Serena Configuration

```yaml
# .serena/project.yml
languageServers:
  python:
    command:
      - "path/to/bundle/runtimes/nodejs/node.exe"
      - "path/to/bundle/language_servers/python/node_modules/pyright/langserver.index.js"
      - "--stdio"

  typescript:
    command:
      - "path/to/bundle/runtimes/nodejs/node.exe"
      - "path/to/bundle/language_servers/typescript/node_modules/typescript-language-server/lib/cli.js"
      - "--stdio"

  rust:
    command: ["path/to/bundle/language_servers/rust/rust-analyzer.exe"]

  go:
    command: ["path/to/bundle/language_servers/go/gopls.exe"]

  lua:
    command: ["path/to/bundle/language_servers/lua/bin/lua-language-server.exe"]

  markdown:
    command: ["path/to/bundle/language_servers/markdown/marksman.exe", "server"]
```

---

## 🚨 Troubleshooting

| Problem | Solution |
|---------|----------|
| npm not recognized | Include Node.js: `-IncludeNodeJS $true` |
| Wrong architecture | Specify: `-Architecture arm64` |
| Checksum fails | Re-download: `-Force` |
| Large size | Expected (includes Node.js runtime) |

---

## 📚 Documentation

- **Complete Guide**: `BUNDLE-WINDOWS-GUIDE.md`
- **Summary**: `BUNDLE-SUMMARY.md`
- **Script**: `bundle-language-servers-windows.ps1`
- **Quick Ref**: `BUNDLE-QUICK-REF.md` (this file)

---

## ⏱️ Performance

- **Download Time**: 1-15 minutes (depends on connection)
- **Bundle Creation**: 3-5 minutes (with npm installs)
- **Final Size**: 180-200 MB

---

## ✨ Features

✅ Offline installation
✅ Portable (no system changes)
✅ x64 and ARM64 support
✅ Progress indicators
✅ Error handling & retry
✅ Checksum verification
✅ Auto-generated manifest
✅ Installation guide included

---

**Version**: 1.0.0 | **Created**: 2025-01-16 | **Script**: PowerShell 5.1+
