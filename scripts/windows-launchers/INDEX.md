# Windows Launcher Scripts - File Index

This directory contains all Windows launcher scripts and documentation for Serena MCP Portable.

## Quick Navigation

### For Users
- **[USAGE.md](USAGE.md)** - Quick start guide and common commands
- **[README.md](README.md)** - Complete user documentation

### For Developers
- **[INTEGRATION.md](INTEGRATION.md)** - Build system integration guide
- **[SUMMARY.md](SUMMARY.md)** - Project overview and statistics

## File Listing

### Entry Point Launchers (Batch)
| File | Size | Purpose |
|------|------|---------|
| `serena.bat` | 4.7 KB | Launch Serena CLI (Command Prompt) |
| `serena-mcp-server.bat` | 4.9 KB | Launch MCP server (Command Prompt) |
| `index-project.bat` | 4.9 KB | Launch indexing tool (Command Prompt, deprecated) |

### Entry Point Launchers (PowerShell)
| File | Size | Purpose |
|------|------|---------|
| `serena.ps1` | 5.1 KB | Launch Serena CLI (PowerShell) |
| `serena-mcp-server.ps1` | 5.3 KB | Launch MCP server (PowerShell) |
| `index-project.ps1` | 5.3 KB | Launch indexing tool (PowerShell, deprecated) |

### Setup Scripts
| File | Size | Purpose |
|------|------|---------|
| `first-run.bat` | 8.3 KB | First-time setup (Command Prompt) |
| `first-run.ps1` | 10 KB | First-time setup (PowerShell) |

### Verification Scripts
| File | Size | Purpose |
|------|------|---------|
| `verify-installation.bat` | 11 KB | Health check (Command Prompt) |
| `verify-installation.ps1` | 15 KB | Health check (PowerShell) |

### Documentation
| File | Size | Purpose |
|------|------|---------|
| `README.md` | 12 KB | Complete user documentation |
| `USAGE.md` | 2.6 KB | Quick start guide |
| `INTEGRATION.md` | 11 KB | Build system integration |
| `SUMMARY.md` | 9 KB | Project overview |
| `INDEX.md` | This file | Directory index |

## Total Project Size

- **Scripts:** 70 KB (12 files)
- **Documentation:** 46 KB (5 files)
- **Total:** 116 KB (17 files)

## Usage Workflow

### First-Time Setup
```
1. Read USAGE.md for quick start
2. Run first-run.bat or first-run.ps1
3. Verify with verify-installation
```

### Daily Use
```
1. Use serena.bat or serena.ps1 for CLI
2. Use serena-mcp-server for MCP server
3. Run verify-installation if issues occur
```

### Development
```
1. Read INTEGRATION.md for build setup
2. Copy scripts to dist/ directory
3. Test with verify-installation
4. Package for distribution
```

## File Dependencies

### Launcher Scripts
- Depend on: PyInstaller executables (*.exe)
- Create: Environment variables, directories
- Modify: User PATH (optional)

### Setup Scripts
- Depend on: Launcher scripts, resource templates
- Create: Directory structure, configuration files
- Modify: User PATH (optional)

### Verification Scripts
- Depend on: Launcher scripts, executables
- Create: Diagnostic reports
- Modify: Nothing (read-only operations)

## Maintenance Checklist

### When Updating Scripts
- [ ] Update version references (if any)
- [ ] Test on clean Windows system
- [ ] Verify batch and PowerShell consistency
- [ ] Update documentation if behavior changes
- [ ] Test with new PyInstaller build
- [ ] Update SUMMARY.md statistics

### When Adding New Features
- [ ] Update both .bat and .ps1 versions
- [ ] Update README.md with new features
- [ ] Update USAGE.md if user-facing
- [ ] Update INTEGRATION.md if build-related
- [ ] Add to verification script if testable
- [ ] Update this INDEX.md

### Before Release
- [ ] All scripts tested
- [ ] Documentation reviewed
- [ ] SUMMARY.md updated
- [ ] File sizes updated in INDEX.md
- [ ] README examples work
- [ ] Integration guide tested

## Script Relationships

```
User
├── first-run.bat/ps1 (initial setup)
│   ├── Creates .serena-portable/
│   ├── Copies config files
│   └── Calls verify-installation
│
├── serena.bat/ps1 (main CLI)
│   ├── Sets environment variables
│   ├── Detects bundled runtimes
│   └── Launches serena.exe
│
├── serena-mcp-server.bat/ps1 (MCP server)
│   ├── Sets environment variables
│   ├── Detects bundled runtimes
│   └── Launches serena-mcp-server.exe
│
└── verify-installation.bat/ps1 (health check)
    ├── Tests all executables
    ├── Verifies directory structure
    └── Reports status
```

## Environment Variables Set

All launcher scripts set these variables:

```
SERENA_PORTABLE=1
SERENA_HOME=<install_dir>\.serena-portable
SERENA_CONFIG_DIR=<install_dir>\.serena-portable
SERENA_CACHE_DIR=<install_dir>\.serena-portable\cache
SERENA_LOG_DIR=<install_dir>\.serena-portable\logs
SERENA_TEMP_DIR=<install_dir>\.serena-portable\temp
NODE_PATH=<install_dir>\runtimes\nodejs (if bundled)
DOTNET_ROOT=<install_dir>\runtimes\dotnet (if bundled)
JAVA_HOME=<install_dir>\runtimes\java (if bundled)
PATH=<modified to include above>
```

## Testing Matrix

| Script | Windows 10 | Windows 11 | CMD | PowerShell 5.1 | PowerShell 7+ |
|--------|-----------|-----------|-----|---------------|--------------|
| serena.bat | ✅ | ✅ | ✅ | ✅ | ✅ |
| serena.ps1 | ✅ | ✅ | ❌ | ✅ | ✅ |
| serena-mcp-server.bat | ✅ | ✅ | ✅ | ✅ | ✅ |
| serena-mcp-server.ps1 | ✅ | ✅ | ❌ | ✅ | ✅ |
| index-project.bat | ✅ | ✅ | ✅ | ✅ | ✅ |
| index-project.ps1 | ✅ | ✅ | ❌ | ✅ | ✅ |
| first-run.bat | ✅ | ✅ | ✅ | ✅ | ✅ |
| first-run.ps1 | ✅ | ✅ | ❌ | ✅ | ✅ |
| verify-installation.bat | ✅ | ✅ | ✅ | ✅ | ✅ |
| verify-installation.ps1 | ✅ | ✅ | ❌ | ✅ | ✅ |

## Getting Help

### User Questions
- Check **USAGE.md** for common commands
- Check **README.md** troubleshooting section
- Run `verify-installation.ps1 -Verbose` for diagnostics

### Developer Questions
- Check **INTEGRATION.md** for build integration
- Check **SUMMARY.md** for design decisions
- Review script comments for implementation details

### Reporting Issues
When reporting issues, include:
1. Output of `verify-installation.ps1 -Verbose`
2. Windows version (run `winver`)
3. PowerShell version (run `$PSVersionTable`)
4. Error message or unexpected behavior
5. Steps to reproduce

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-12 | Initial release |
|  |  | - All launcher scripts |
|  |  | - Setup and verification scripts |
|  |  | - Complete documentation |

## License

These scripts are part of the Serena project and are licensed under the MIT License.

## Contact

For questions, issues, or contributions related to these scripts:
- Open an issue on the Serena GitHub repository
- Tag with `windows-launcher` label
- Include relevant diagnostics from verification script
