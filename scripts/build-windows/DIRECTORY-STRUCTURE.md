# Windows Portable Package Directory Structure

This document defines the standardized directory structure for Serena Windows portable packages.

## Complete Structure Template

```
serena-portable-v{VERSION}-windows-{ARCH}-{TIER}/
│
├── serena-portable.bat                 # Primary launcher script
├── VERSION.txt                         # Version and build information
│
├── bin/                                # Executable binaries
│   ├── serena-mcp-server.exe          # Main MCP server (primary entry point)
│   ├── serena.exe                     # CLI interface
│   └── index-project.exe              # Project indexing tool
│
├── config/                             # Configuration files
│   ├── launcher-config.json           # Launcher configuration
│   ├── default-context.yml            # Default context settings (optional)
│   └── default-modes.yml              # Default mode settings (optional)
│
├── docs/                               # Documentation
│   ├── README-PORTABLE.md             # Portable-specific documentation
│   ├── README.md                      # Main project README
│   ├── LICENSE                        # Project license
│   ├── CHANGELOG.md                   # Version changelog (optional)
│   └── QUICKSTART.md                  # Quick start guide (optional)
│
├── scripts/                            # Helper scripts
│   ├── setup-env.bat                  # Environment setup (optional)
│   ├── check-requirements.bat         # Requirements checker (optional)
│   └── update-language-servers.bat    # LS updater (optional)
│
├── language_servers/                   # Bundled language servers (tier-dependent)
│   ├── python/                        # Python language servers
│   │   └── pyright/
│   │       ├── package/
│   │       └── node_modules/
│   │
│   ├── typescript/                    # TypeScript language servers
│   │   └── typescript-language-server/
│   │
│   ├── go/                            # Go language server
│   │   └── gopls.exe
│   │
│   ├── csharp/                        # C# language server
│   │   └── csharp-ls.exe
│   │
│   ├── java/                          # Java language server (complete+ tiers)
│   │   └── eclipse.jdt.ls/
│   │
│   ├── rust/                          # Rust language server (complete+ tiers)
│   │   └── rust-analyzer.exe
│   │
│   ├── kotlin/                        # Kotlin language server (complete+ tiers)
│   │   └── server/
│   │
│   └── [other language servers depending on tier]
│
├── runtimes/                           # Portable runtime environments (optional)
│   ├── nodejs/                        # Node.js portable (for TS/JS servers)
│   │   ├── node.exe
│   │   ├── npm.cmd
│   │   └── node_modules/
│   │
│   ├── dotnet/                        # .NET runtime (for C# servers)
│   │   └── [.NET runtime files]
│   │
│   └── java/                          # Java runtime (for Java servers)
│       └── [JRE files]
│
└── .serena-portable/                   # User data directory (created on first run)
    ├── cache/                          # Cache directory
    │   ├── lsp/                       # Language server caches
    │   └── tools/                     # Tool caches
    │
    ├── logs/                           # Application logs
    │   ├── serena.log                 # Main application log
    │   ├── lsp/                       # Language server logs
    │   └── debug/                     # Debug logs
    │
    ├── backups/                        # Automatic backups
    │   └── [timestamped backups]
    │
    ├── config/                         # User configuration overrides
    │   ├── serena_config.yml          # User config
    │   └── projects/                  # Project-specific configs
    │
    └── memories/                       # Project memories (optional)
        └── [project-specific memories]
```

## Directory Descriptions

### Root Level

- **serena-portable.bat**: Main launcher that sets up the environment and starts Serena
- **VERSION.txt**: Human-readable version and build information

### bin/ (Executables)

All PyInstaller-built executables. These are self-contained single-file executables.

**Size estimates:**
- Each executable: ~40-50 MB (x64)
- Total: ~130-150 MB for 3 executables

### config/ (Configuration)

Static configuration files bundled with the distribution.

**Key files:**
- `launcher-config.json`: Controls launcher behavior (portable mode, paths, etc.)
- Optional context/mode YAML files for customization

### docs/ (Documentation)

User-facing documentation files.

**Included files:**
- Portable-specific README with setup instructions
- Main project README
- License information
- Optional quick start guide and changelog

### scripts/ (Helper Scripts)

Optional batch scripts for common tasks.

**Potential scripts:**
- Environment setup and validation
- Language server updates
- Configuration management
- Diagnostic tools

### language_servers/ (Language Servers)

Tier-dependent language server binaries and packages.

**Tier breakdown:**

| Tier | Languages | Approximate Size |
|------|-----------|-----------------|
| **minimal** | None | 0 MB |
| **essential** | Python, TypeScript, Go, C# | 200-300 MB |
| **complete** | + Java, Rust, Kotlin, Clojure | 500-700 MB |
| **full** | All 28+ supported languages | 1-2 GB |

**Per-language structure:**
```
language_servers/<language>/
├── [binary or package directory]
├── [additional dependencies]
└── [configuration files if needed]
```

### runtimes/ (Optional Runtimes)

Portable runtime environments for language servers that require them. This enables **true offline functionality**.

**Optional but recommended for:**
- Node.js (TypeScript, JavaScript, Bash LSs)
- .NET (C# language servers)
- Java (Java, Kotlin language servers)

**Size estimates:**
- Node.js portable: ~30-50 MB
- .NET runtime: ~50-100 MB
- Java JRE: ~80-150 MB

### .serena-portable/ (User Data)

Created automatically on first run. Stores all user-specific data, ensuring the package itself remains clean.

**Subdirectories:**
- **cache/**: Temporary files and language server caches
- **logs/**: Application and language server logs
- **backups/**: Automatic configuration backups
- **config/**: User configuration overrides
- **memories/**: Project-specific knowledge persistence

## Size Estimates by Tier

### Minimal Tier
```
Total: ~150-200 MB
- Executables: ~150 MB
- Config/Docs: ~1 MB
- Scripts: <1 MB
```

### Essential Tier (Recommended)
```
Total: ~350-500 MB
- Executables: ~150 MB
- Language Servers: 200-300 MB
- Config/Docs: ~1 MB
- Scripts: <1 MB
```

### Complete Tier
```
Total: ~650-850 MB
- Executables: ~150 MB
- Language Servers: 500-700 MB
- Config/Docs: ~1 MB
- Scripts: <1 MB
```

### Full Tier (All Languages)
```
Total: ~1.2-2.2 GB
- Executables: ~150 MB
- Language Servers: 1-2 GB
- Config/Docs: ~1 MB
- Scripts: <1 MB
```

### Full Tier + Runtimes (Maximum Offline)
```
Total: ~1.5-2.6 GB
- Executables: ~150 MB
- Language Servers: 1-2 GB
- Runtimes: ~150-280 MB
- Config/Docs: ~1 MB
- Scripts: <1 MB
```

## Archive Compression

ZIP archives typically achieve:
- **40-60% compression** for executables and binaries
- **70-80% compression** for text files and documentation
- **20-30% compression** for already-compressed language server packages

**Expected archive sizes:**
- Minimal: ~80-120 MB
- Essential: ~180-250 MB
- Complete: ~350-450 MB
- Full: ~650-900 MB
- Full + Runtimes: ~800-1.1 GB

## Path Length Considerations

Windows has a 260-character path limit (MAX_PATH) by default.

**Best practices:**
1. Extract to short paths: `C:\serena\` instead of `C:\Users\...\My Documents\...`
2. Avoid deeply nested project structures
3. Enable long path support in Windows 10+ if needed
4. Build script includes path length validation

## Portable Mode Environment Variables

When running in portable mode, these environment variables are set:

```batch
SERENA_PORTABLE=1
SERENA_HOME=%~dp0
SERENA_USER_DIR=%SERENA_HOME%\.serena-portable
SERENA_CACHE_DIR=%SERENA_USER_DIR%\cache
SERENA_LOG_DIR=%SERENA_USER_DIR%\logs
SERENA_CONFIG_DIR=%SERENA_USER_DIR%\config
PATH=%SERENA_HOME%\bin;%SERENA_HOME%\language_servers;%PATH%
```

## Verification Checklist

After building, verify the structure:

- [ ] All executables present in `bin/`
- [ ] Each executable is functional (run with `--version`)
- [ ] Language servers match the selected tier
- [ ] Configuration files are valid JSON/YAML
- [ ] Documentation is complete and accurate
- [ ] VERSION.txt contains correct information
- [ ] Launcher script sets environment correctly
- [ ] Total size matches tier expectations
- [ ] Archive extracts without errors
- [ ] No absolute paths in configuration files

## Customization Guidelines

For custom builds, maintain this structure and:

1. Add custom scripts to `scripts/` directory
2. Add custom configs to `config/` directory
3. Document customizations in `docs/CUSTOMIZATIONS.md`
4. Update VERSION.txt with custom build info
5. Ensure launcher script handles custom additions

## Migration from Previous Versions

When upgrading the portable package:

1. User data in `.serena-portable/` is preserved
2. Copy old `.serena-portable/` to new package directory
3. Update configuration files if schema changed
4. Check `docs/CHANGELOG.md` for breaking changes
5. Run `serena-portable.bat --verify` to validate

## Support and Issues

For issues related to directory structure or portable packaging:
- Check `logs/serena.log` for error messages
- Verify all paths are correct
- Ensure no absolute paths in configs
- Check Windows path length limits
- Review launcher script environment variables

Documentation version: 1.0.0
Last updated: 2025-01-12
