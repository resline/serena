# Serena Agent - Enhanced Windows Installer System

## Executive Summary

The enhanced Serena Agent installer represents a comprehensive solution for professional Windows distribution, integrating seamlessly with the portable distribution system while providing enterprise-grade installation capabilities. This document provides an overview of all components, usage instructions, and implementation details.

---

## What's New in Enhanced Installer

### 🎯 Key Enhancements

1. **Portable Distribution Integration**
   - Works directly with portable ZIP files or extracted folders
   - No need for separate installer builds
   - Consistent packaging across portable and installer distributions

2. **Tier-Based Language Server Selection**
   - **Minimal**: Core functionality only (~150 MB)
   - **Essential**: Python, TypeScript, Go, Rust (~250 MB) - **Default**
   - **Complete**: + Java, C#, Lua, Bash (~400 MB)
   - **Full**: All 28+ languages (~650 MB)

3. **User Configuration Management**
   - Automatic `~/.serena/` directory initialization
   - Default configuration file generation
   - Settings preservation during upgrades
   - Optional removal during uninstall

4. **Enhanced Build System**
   - Automatic NSIS download if not present
   - Integrated code signing support
   - Comprehensive validation and testing
   - Detailed build logging

5. **Professional UI/UX**
   - Dedicated tier selection page
   - Hierarchical component tree
   - Real-time disk space validation
   - Detailed installation progress
   - Multi-language support (EN, DE, FR, ES)

6. **Enterprise Features**
   - Silent installation with INI configuration
   - User-level installation fallback
   - Upgrade detection and migration
   - Comprehensive registry integration
   - Windows Defender exclusion support

---

## File Structure

```
scripts/installer/
├── serena-installer.nsi                    # Original NSIS installer script
├── serena-installer-enhanced.nsi           # NEW: Enhanced installer with portable integration
├── FileAssociation.nsh                     # File association helper macros
│
├── build-installer.bat                     # Original batch build script
├── build-installer.ps1                     # Original PowerShell build script
├── build-installer-enhanced.ps1            # NEW: Enhanced build script with auto-NSIS download
│
├── test-installer.ps1                      # Installer validation and testing script
├── silent-install.ini                      # Silent installation configuration template
├── silent-install.bat                      # Silent installation wrapper
│
├── README.md                               # Basic installer documentation
├── INSTALLER-OVERVIEW.md                   # Comprehensive installer system overview
├── INSTALLER-UI-DESIGN.md                  # NEW: UI mockups and user experience design
├── INSTALL-UNINSTALL-FLOW.md               # NEW: Installation and uninstallation flow diagrams
├── INSTALLER-TESTING-CHECKLIST.md          # NEW: Comprehensive testing checklist
├── ENHANCED-INSTALLER-SUMMARY.md           # NEW: This file - complete summary
│
└── output/                                 # Generated installers (not in repo)
    └── serena-installer-0.1.4.exe
```

---

## Quick Start Guide

### Prerequisites

1. **Build Portable Distribution First**
   ```powershell
   cd scripts/build-windows
   .\build-portable.ps1 -Tier essential -Clean
   ```

2. **Install NSIS (Optional)**
   - Download from: https://nsis.sourceforge.io/
   - Or let build script auto-download with `-DownloadNSIS`

### Basic Build

```powershell
cd scripts/installer

# Build with essential tier (recommended)
.\build-installer-enhanced.ps1 -PortablePath "..\..\dist\serena-portable" -Tier essential

# Build with full language server suite
.\build-installer-enhanced.ps1 -PortablePath "..\..\dist\serena-portable" -Tier full

# Auto-download NSIS if not present
.\build-installer-enhanced.ps1 -PortablePath "..\..\dist\serena-portable" -Tier essential -DownloadNSIS
```

### Advanced Build with Code Signing

```powershell
# Build and sign installer
.\build-installer-enhanced.ps1 `
    -PortablePath "..\..\dist\serena-portable" `
    -Tier essential `
    -Sign `
    -CertificatePath "C:\Certs\code-signing.p12" `
    -CertificatePassword (ConvertTo-SecureString "password" -AsPlainText -Force) `
    -Clean `
    -Verbose
```

### Testing

```powershell
# Basic validation
.\test-installer.ps1 -InstallerPath "output\serena-installer-0.1.4.exe" -TestMode basic

# Full test suite
.\test-installer.ps1 -InstallerPath "output\serena-installer-0.1.4.exe" -TestMode full -CleanupAfter
```

---

## Installation Options

### Interactive Installation

**Double-click installer or run:**
```batch
serena-installer-0.1.4.exe
```

**User Experience:**
1. Language selection (EN, DE, FR, ES)
2. Welcome page with requirements
3. License agreement (MIT)
4. **Tier selection** (Minimal, Essential, Complete, Full)
5. Component selection with size estimates
6. Directory selection with disk space validation
7. Start Menu folder configuration
8. Installation progress with detailed logging
9. Completion with launch options

### Silent Installation

**Basic silent install:**
```batch
serena-installer-0.1.4.exe /S
```

**Custom directory:**
```batch
serena-installer-0.1.4.exe /S /D=C:\Custom\Path
```

**With INI configuration:**
```batch
serena-installer-0.1.4.exe /S /INI=custom-config.ini
```

**Example INI Configuration:**
```ini
[General]
InstallDir=C:\Program Files\Serena Agent
LanguageServerTier=essential
InstallType=full
StartMenuFolder=Serena Agent

[Components]
Core=1
LanguageServers=1
UserConfig=1
Shortcuts=1
AddToPath=1
FileAssociations=1
DefenderExclusions=0

[Options]
InstallMode=system
ShowProgress=0
AcceptLicense=1
LaunchAfterInstall=0
```

### User-Level Installation

When admin privileges not available:

1. Installer detects lack of admin rights
2. Offers user-level installation
3. Installs to: `%LOCALAPPDATA%\Serena Agent`
4. Uses HKCU registry keys
5. Modifies user PATH only

---

## Component Details

### Core Components (Required) - ~150 MB

```
C:\Program Files\Serena Agent\
├── serena.exe                    # Main CLI application
├── serena-mcp-server.exe         # MCP server for AI agents
├── index-project.exe             # Project indexing utility
├── LICENSE                       # MIT license
├── README.txt                    # Windows-specific readme
├── _internal\                    # Python runtime and dependencies
│   ├── python311.dll
│   ├── library.zip
│   └── [many other files]
├── logs\                         # Log directory
└── temp\                         # Temporary files
```

### Language Servers (Optional, Tier-Based)

**Essential Tier (~100 MB):**
```
language-servers\
├── pyright\                      # Python
├── typescript-language-server\   # TypeScript/JavaScript
├── gopls\                        # Go
└── rust-analyzer\                # Rust
```

**Complete Tier (+150 MB):**
```
language-servers\
├── [Essential tier servers]
├── eclipse-jdtls\                # Java
├── omnisharp\                    # C#
├── lua-language-server\          # Lua
└── bash-language-server\         # Bash
```

**Full Tier (+250 MB):**
```
language-servers\
├── [Complete tier servers]
└── [20+ additional language servers]
    ├── clangd\                   # C/C++
    ├── clojure-lsp\              # Clojure
    ├── erlang-ls\                # Erlang
    ├── kotlin-language-server\   # Kotlin
    └── [many others]
```

### User Configuration Directory

```
C:\Users\[Username]\.serena\
├── serena_config.yml             # User configuration
├── memories\                     # Project memories
│   └── [project-specific memory files]
└── projects\                     # Project configurations
    └── [project-specific configs]
```

**Default Configuration File:**
```yaml
# Serena Agent Configuration
# Version: 0.1.4

installation:
  path: C:\Program Files\Serena Agent
  version: 0.1.4
  language_server_tier: essential

# Add your custom configuration below
```

### Shortcuts and Integration

**Start Menu:**
```
Start Menu\Programs\Serena Agent\
├── Serena Agent.lnk
├── Serena MCP Server.lnk
├── Serena Configuration.lnk
├── Serena Documentation.lnk
└── Uninstall Serena Agent.lnk
```

**Desktop:**
```
Desktop\
└── Serena Agent.lnk
```

**System Integration:**
- PATH environment variable (optional)
- .serena file association
- Windows Defender exclusions (optional, requires admin)

### Registry Entries

**Uninstall Information:**
```
HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Serena Agent\
├── DisplayName: "Serena Agent 0.1.4"
├── UninstallString: "C:\Program Files\Serena Agent\uninst.exe"
├── InstallLocation: "C:\Program Files\Serena Agent"
├── DisplayVersion: "0.1.4"
├── Publisher: "Oraios AI"
├── URLInfoAbout: "https://github.com/oraios/serena"
├── LanguageServerTier: "essential"
├── EstimatedSize: [calculated]
├── NoModify: 1
└── NoRepair: 1
```

**Application Path:**
```
HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\serena.exe\
└── (Default): "C:\Program Files\Serena Agent\serena.exe"
```

---

## Upgrade and Migration

### Upgrade Detection

When installing over existing version:

1. **Detect Previous Installation**
   - Check registry uninstall key
   - Read previous version
   - Locate install directory

2. **User Confirmation**
   ```
   A previous version (0.1.3) is installed at:
   C:\Program Files\Serena Agent

   Do you want to upgrade the existing installation?

   Note: Your user configuration in ~/.serena/ will be preserved.

   [Yes - Upgrade] [No - Fresh Install]
   ```

3. **Upgrade Process**
   - Backup user configuration
   - Remove old binaries
   - Install new version
   - Restore/migrate settings
   - Update registry

### Configuration Migration

- `~/.serena/` directory always preserved
- Configuration file version updated
- New default settings added
- Custom values retained
- Deprecated settings warned

---

## Uninstallation

### Interactive Uninstall

Launch uninstaller:
- Start Menu → Serena Agent → Uninstall
- Control Panel → Programs and Features
- Direct: `C:\Program Files\Serena Agent\uninst.exe`

**Uninstall Process:**

1. **Confirmation Dialog**
   - Shows installation details
   - Lists components to remove
   - Asks about user configuration

2. **User Configuration Choice**
   ```
   Your configuration directory contains:
   C:\Users\John\.serena\

   • Project configurations
   • Memory database
   • Custom settings

   ☐ Also remove user configuration directory
      (This will delete all your project configurations)

   [Cancel] [Uninstall]
   ```

3. **Removal Process**
   - Stop running processes
   - Remove shortcuts
   - Remove system integration
   - Remove application files
   - Remove user config (if selected)
   - Clean registry
   - Refresh system

### Silent Uninstall

```batch
"C:\Program Files\Serena Agent\uninst.exe" /S
```

- Removes all components
- Deletes user configuration
- No user prompts
- Exit code 0 on success

---

## Language Server Tier Selection Guide

### Tier Comparison

| Feature | Minimal | Essential | Complete | Full |
|---------|---------|-----------|----------|------|
| **Size** | 150 MB | 250 MB | 400 MB | 650 MB |
| **Languages** | 0 | 4 | 8 | 28+ |
| **Install Time** | 1-2 min | 2-3 min | 3-5 min | 5-10 min |
| **Use Case** | CLI only | Modern dev | Enterprise | Maximum coverage |

### When to Choose Each Tier

**Minimal:**
- Using Serena only for CLI/MCP operations
- Minimum disk space available
- Language servers not needed
- Fastest installation

**Essential (Default):**
- Modern web development (TypeScript, Python)
- Systems programming (Go, Rust)
- Balanced size and functionality
- **Recommended for most users**

**Complete:**
- Enterprise polyglot development
- Java, C#, Lua, Bash support needed
- More comprehensive language coverage
- Good balance for teams

**Full:**
- Maximum language support required
- 28+ programming languages
- Specialized or legacy languages
- Development tool vendors
- Maximum disk space available

### Language Server Capabilities

Each language server provides:
- **Autocomplete**: Context-aware code completion
- **Diagnostics**: Real-time error and warning detection
- **Go-to-definition**: Navigate to symbol definitions
- **Find references**: Locate all usages of symbols
- **Hover documentation**: Inline help and type information
- **Code actions**: Quick fixes and refactorings
- **Formatting**: Automatic code formatting
- **Rename**: Safe symbol renaming across files

---

## Troubleshooting

### Common Issues

**Issue: NSIS not found**
```
ERROR: NSIS (makensis) not found in PATH
```
**Solution:**
- Install NSIS from https://nsis.sourceforge.io/
- Or use `-DownloadNSIS` flag to auto-download

**Issue: Portable distribution not found**
```
ERROR: Portable distribution not found: dist/serena-portable
```
**Solution:**
```powershell
# Build portable distribution first
cd scripts/build-windows
.\build-portable.ps1 -Tier essential
cd ../installer
.\build-installer-enhanced.ps1 -PortablePath "..\..\dist\serena-portable" -Tier essential
```

**Issue: Insufficient disk space**
```
Insufficient disk space. At least 500MB required.
```
**Solution:**
- Free up disk space
- Choose smaller tier (Minimal or Essential)
- Install to different drive

**Issue: Installation fails with "Access Denied"**
```
Error opening file for writing
```
**Solution:**
- Run installer as Administrator
- Or accept user-level installation
- Check antivirus is not blocking

**Issue: Windows Defender flags installer**
```
Windows protected your PC
```
**Solution:**
- This is SmartScreen warning for unsigned apps
- Click "More info" → "Run anyway"
- Or digitally sign the installer

**Issue: Language servers not found**
```
Language server not found: pyright
```
**Solution:**
- Reinstall with correct tier selected
- Verify language-servers directory exists
- Check PATH includes language server directories

---

## Build Script Parameters

### build-installer-enhanced.ps1 Parameters

```powershell
.\build-installer-enhanced.ps1 `
    -PortablePath <path>           # Path to portable dist (ZIP or folder)
    -Tier <minimal|essential|      # Language server tier
          complete|full>
    -Configuration <Release|Debug> # Build configuration
    -Clean                         # Clean previous builds
    -Sign                          # Sign installer (requires cert)
    -CertificatePath <path>        # Code signing certificate
    -CertificatePassword <secure>  # Certificate password
    -Verbose                       # Detailed output
    -DownloadNSIS                  # Auto-download NSIS
    -ValidateOnly                  # Only validate prerequisites
```

### Examples

**Standard build:**
```powershell
.\build-installer-enhanced.ps1 -PortablePath ".\dist\serena-portable" -Tier essential
```

**Clean build with verbose output:**
```powershell
.\build-installer-enhanced.ps1 `
    -PortablePath "C:\Build\serena-portable.zip" `
    -Tier complete `
    -Clean `
    -Verbose
```

**Production build with signing:**
```powershell
.\build-installer-enhanced.ps1 `
    -PortablePath ".\dist\serena-portable" `
    -Tier essential `
    -Sign `
    -CertificatePath "C:\Certs\code-sign.p12" `
    -CertificatePassword $securePassword `
    -Clean
```

**Validate only (no build):**
```powershell
.\build-installer-enhanced.ps1 `
    -PortablePath ".\dist\serena-portable" `
    -Tier essential `
    -ValidateOnly
```

---

## Enterprise Deployment

### Group Policy Deployment

```powershell
# Copy installer to network share
Copy-Item "serena-installer-0.1.4.exe" "\\server\software\Serena\"

# Create deployment script
$script = @"
\\server\software\Serena\serena-installer-0.1.4.exe /S /INI=\\server\software\Serena\corporate-config.ini
"@

# Deploy via GPO Computer Startup Scripts
```

### SCCM/Intune Deployment

**Detection Method:**
```powershell
# Check registry for installation
$regPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Serena Agent"
if (Test-Path $regPath) {
    $version = (Get-ItemProperty $regPath).DisplayVersion
    if ($version -eq "0.1.4") { exit 0 }
}
exit 1
```

**Install Command:**
```batch
serena-installer-0.1.4.exe /S /INI=corporate-config.ini
```

**Uninstall Command:**
```batch
"C:\Program Files\Serena Agent\uninst.exe" /S
```

### Network Installation Server

```powershell
# Set up web server for installations
# Clients download and install silently

$url = "https://software.company.com/serena/serena-installer-0.1.4.exe"
$installer = "$env:TEMP\serena-installer.exe"
$config = "$env:TEMP\serena-config.ini"

# Download installer
Invoke-WebRequest -Uri $url -OutFile $installer

# Download configuration
Invoke-WebRequest -Uri "$url/../config.ini" -OutFile $config

# Install silently
Start-Process -FilePath $installer -ArgumentList "/S", "/INI=$config" -Wait

# Cleanup
Remove-Item $installer, $config
```

---

## Testing Strategy

### Manual Testing

Use comprehensive checklist:
- [INSTALLER-TESTING-CHECKLIST.md](INSTALLER-TESTING-CHECKLIST.md)

Key test scenarios:
1. Fresh installation (all tiers)
2. Upgrade installation
3. Silent installation
4. User-level installation
5. Uninstallation
6. Multi-language support
7. Platform compatibility (Win 10/11)

### Automated Testing

```powershell
# Run automated test suite
.\test-installer.ps1 `
    -InstallerPath "output\serena-installer-0.1.4.exe" `
    -TestMode full `
    -CleanupAfter `
    -Verbose
```

**Test Coverage:**
- Prerequisites validation
- File integrity
- Installation process
- Registry entries
- Shortcuts creation
- System integration
- Uninstallation
- Silent installation

---

## Release Checklist

### Pre-Release

- [ ] Build portable distribution for all tiers
- [ ] Test portable distribution
- [ ] Build installer for each tier
- [ ] Sign installer (production only)
- [ ] Run full test suite
- [ ] Verify on clean Windows 10/11 VMs
- [ ] Test silent installation
- [ ] Test upgrade from previous version
- [ ] Review documentation

### Release

- [ ] Tag release in git
- [ ] Upload installer to distribution channels
- [ ] Update website/documentation
- [ ] Announce release
- [ ] Monitor for issues

### Post-Release

- [ ] Monitor support channels
- [ ] Track installation metrics
- [ ] Collect user feedback
- [ ] Address critical issues
- [ ] Plan next release

---

## FAQ

**Q: Can I install both portable and installer versions?**
A: Yes, but they will be separate installations. The portable version won't interfere with the installed version if in different directories.

**Q: Can I change language server tier after installation?**
A: Yes, run the installer again and select "Upgrade" to add more language servers, or download them manually.

**Q: What happens to my config during upgrade?**
A: User configuration in `~/.serena/` is always preserved during upgrades. Application files are replaced.

**Q: Can I install without administrator privileges?**
A: Yes, the installer offers user-level installation to `%LOCALAPPDATA%\Serena Agent` when admin rights are unavailable.

**Q: How do I add Serena to PATH?**
A: Select "Add to PATH" component during installation, or manually add install directory to PATH.

**Q: Why is the installer so large?**
A: The installer bundles Python runtime, dependencies, and language servers. Choose a smaller tier to reduce size.

**Q: Can I customize the silent installation?**
A: Yes, create a custom INI file and use `/INI=config.ini` parameter.

**Q: How do I uninstall completely?**
A: Run uninstaller and check "Also remove user configuration" to delete everything including `~/.serena/`.

**Q: Does the installer modify system files?**
A: No, it only installs to its own directory and adds registry entries, shortcuts, and optional PATH entry.

**Q: Can I install on Windows Server?**
A: Yes, Windows Server 2019+ is supported with the same installation process.

---

## Support and Contributing

### Getting Help

- **Documentation**: https://github.com/oraios/serena
- **Issues**: https://github.com/oraios/serena/issues
- **Discussions**: https://github.com/oraios/serena/discussions

### Contributing

See [CLAUDE.md](../../CLAUDE.md) for development guidelines.

### Reporting Installer Issues

When reporting installer issues, include:
- Windows version and edition
- Installation method (interactive/silent)
- Selected tier and components
- Error messages and screenshots
- Installation log (if available)

---

## License

This installer and all components are licensed under the MIT License. See [LICENSE](../../LICENSE) for details.

---

## Conclusion

The enhanced Serena Agent installer provides a professional, user-friendly installation experience while maintaining flexibility for enterprise deployments. The tier-based language server selection and portable distribution integration ensure efficient installations tailored to user needs.

For questions or issues, please refer to the project documentation or open an issue on GitHub.

**Version:** 0.1.4
**Last Updated:** 2025-01-16
**Author:** Oraios AI
