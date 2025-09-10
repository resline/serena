# Serena Agent Windows Installer - Complete Solution

## Overview

This directory contains a comprehensive Windows installer solution for Serena Agent, built using NSIS (Nullsoft Scriptable Install System). The installer provides enterprise-grade functionality with modern UI, multiple installation options, and professional deployment capabilities.

## Key Features

### 🎨 Modern Professional UI
- Modern UI 2 with branded graphics and consistent styling
- Multi-language support (English, German, French, Spanish)
- Professional wizard-style installation flow
- Custom branding and corporate identity support

### 📦 Flexible Installation Options
- **Full Installation**: Complete feature set with all components
- **Core Installation**: Minimal installation for basic functionality  
- **Custom Installation**: User-selectable components and advanced options
- **Silent Installation**: Unattended deployment for enterprise environments

### 🔧 Advanced Components
- **Core Components**: Essential Serena Agent executables and libraries
- **Language Servers**: Pre-integrated language server binaries for multi-language support
- **Start Menu Integration**: Professional shortcuts and documentation links
- **PATH Environment**: Optional system PATH integration for command-line access
- **File Associations**: `.serena` file type registration with shell integration
- **Windows Defender**: Optional performance exclusions for better runtime performance

### 🏢 Enterprise Features
- **User vs System Installation**: Automatic privilege detection with fallback options
- **Upgrade Detection**: Preserves settings and configuration during version updates
- **Registry Integration**: Complete Windows registry integration for proper uninstall support
- **Code Signing Support**: Infrastructure for digital certificate signing
- **Silent Deployment**: INI-based configuration for automated enterprise rollouts

## File Structure

```
scripts/installer/
├── serena-installer.nsi          # Main NSIS installer script
├── FileAssociation.nsh           # File association helper macros
├── build-installer.bat           # Windows batch build script
├── build-installer.ps1           # PowerShell build script (advanced)
├── silent-install.ini            # Silent installation configuration
├── silent-install.bat            # Silent installation wrapper
├── test-installer.ps1            # Installer validation and testing
├── README.md                     # Comprehensive documentation
├── INSTALLER-OVERVIEW.md          # This overview document
└── output/                       # Generated installer output directory
```

## Quick Start

### Prerequisites
1. Install NSIS from https://nsis.sourceforge.io/
2. Build Serena portable distribution: `scripts/build-windows/build-portable.ps1`
3. Ensure `makensis.exe` is in system PATH

### Build Installer
```powershell
# PowerShell (Recommended)
cd scripts/installer
.\build-installer.ps1

# Or with advanced options
.\build-installer.ps1 -Clean -Verbose -Sign -CertificatePath "cert.p12"
```

```batch
# Windows Batch
cd scripts\installer
build-installer.bat
```

### Deploy Silently
```batch
# Enterprise deployment
serena-installer-0.1.4.exe /S /INI=silent-install.ini

# Or use helper script
silent-install.bat
```

### Test Installer
```powershell
# Validate installer functionality
.\test-installer.ps1 -TestMode full
```

## Technical Architecture

### NSIS Script Structure
The main installer script (`serena-installer.nsi`) is organized into logical sections:

1. **Header Configuration**: Product metadata, version info, and UI settings
2. **Multi-language Support**: String definitions for internationalization
3. **Installation Functions**: User privilege detection, upgrade handling, prerequisites
4. **Component Sections**: Modular installation components with dependency management
5. **Registry Management**: Windows integration and uninstall support
6. **Uninstaller Logic**: Complete removal with registry cleanup

### Build System
The build system provides multiple interfaces:

- **PowerShell Script**: Advanced build with error handling, code signing, and validation
- **Batch Script**: Simple build for basic scenarios
- **Manual NSIS**: Direct makensis execution for development

### Testing Framework
Comprehensive testing validates:

- Installer file integrity and digital signatures
- Silent installation and uninstallation processes  
- Registry entries and file associations
- Component selection and upgrade scenarios
- Cross-platform compatibility (Windows 10/11)

## Installation Process Flow

### Interactive Installation
1. **Welcome Screen**: Professional branding and product introduction
2. **License Agreement**: MIT license acceptance with legal text
3. **Component Selection**: Visual component chooser with descriptions
4. **Directory Selection**: Installation path with disk space validation
5. **Start Menu Configuration**: Customizable start menu folder
6. **Installation Progress**: Real-time progress with detailed status
7. **Completion**: Launch options and documentation links

### Silent Installation
1. **Configuration Loading**: INI-based parameter loading
2. **Prerequisite Validation**: System requirements and permissions
3. **Component Installation**: Automated component deployment
4. **Registry Configuration**: Windows integration setup
5. **Verification**: Installation validation and logging

## Component Details

### Core Components (Required)
- `serena.exe` - Main Serena Agent executable
- `serena-mcp-server.exe` - MCP server for AI agent integration
- `index-project.exe` - Project indexing utility
- Runtime libraries and Python dependencies
- License and documentation files

### Language Servers (Optional)
- Pre-downloaded language server binaries
- Multi-language development environment support
- Automatic LSP configuration and integration
- 16+ programming language support

### Windows Integration (Optional)
- Start menu shortcuts and program groups
- Desktop shortcuts with proper icons
- `.serena` file type registration
- Windows Explorer context menu integration
- System PATH environment variable updates

### Performance Optimization (Optional)
- Windows Defender exclusions for better performance
- Antivirus compatibility improvements
- Runtime performance optimization
- Resource usage minimization

## Registry Integration

### Installation Registry Keys
```
HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Serena Agent
├── DisplayName: "Serena Agent 0.1.4"
├── UninstallString: "C:\Program Files\Serena Agent\uninst.exe"
├── InstallLocation: "C:\Program Files\Serena Agent"
├── DisplayVersion: "0.1.4"
├── Publisher: "Oraios AI"
├── EstimatedSize: [calculated size]
└── ...
```

### Application Path Registration
```
HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\serena.exe
└── (Default): "C:\Program Files\Serena Agent\serena.exe"
```

### File Association Registration
```
HKLM\Software\Classes\.serena
├── (Default): "SerenaProject"
└── Content Type: "application/x-serena-project"

HKLM\Software\Classes\SerenaProject
├── (Default): "Serena Project File"
├── DefaultIcon: "C:\Program Files\Serena Agent\serena.exe,0"
└── shell\open\command: "C:\Program Files\Serena Agent\serena.exe" "%1"
```

## Security and Code Signing

### Code Signing Infrastructure
The installer includes complete infrastructure for code signing:

```powershell
# Automated signing during build
.\build-installer.ps1 -Sign -CertificatePath "certificate.p12" -CertificatePassword "password"
```

### Security Features
- Digital signature validation support
- Certificate authority verification
- Timestamp server integration for long-term validity
- Installer integrity verification
- Windows SmartScreen compatibility

## Deployment Scenarios

### Development Environment
```powershell
# Quick development build
.\build-installer.ps1 -Clean
```

### Enterprise Deployment  
```powershell
# Corporate deployment with signing
.\build-installer.ps1 -Sign -CertificatePath "corporate-cert.p12" -CertificatePassword $SecurePassword

# Mass deployment
for computer in $ComputerList {
    Copy-Item "serena-installer-0.1.4.exe" "\\$computer\c$\temp\"
    Invoke-Command -ComputerName $computer -ScriptBlock {
        Start-Process "C:\temp\serena-installer-0.1.4.exe" -ArgumentList "/S", "/INI=corporate-config.ini" -Wait
    }
}
```

### Cloud Distribution
```powershell
# Build and upload to distribution channels
.\build-installer.ps1 -Sign -Verbose
# Upload to S3, CDN, or software distribution platform
```

## Localization and Internationalization

### Supported Languages
- English (default)
- German (Deutsch)
- French (Français)  
- Spanish (Español)

### Adding New Languages
1. Add language to NSIS script: `!insertmacro MUI_LANGUAGE "NewLanguage"`
2. Define translated strings for all `LangString` entries
3. Test with target locale and cultural preferences
4. Update documentation and user guides

### Cultural Considerations
- Date/time format localization
- Currency and numeric formatting
- Directory structure conventions
- Registry key localization where appropriate

## Troubleshooting and Support

### Common Build Issues
- **NSIS not found**: Install NSIS and add to PATH
- **Distribution files missing**: Run `build-portable.ps1` first
- **Permission errors**: Run as administrator or use user-level installation
- **Code signing failures**: Verify certificate validity and password

### Installation Issues  
- **Insufficient permissions**: Use administrator account or user-level installation
- **Antivirus interference**: Add temporary exclusions or use Windows Defender exclusions
- **Previous version conflicts**: Uninstall previous version or use upgrade detection
- **Disk space**: Ensure minimum 500MB available space

### Runtime Issues
- **Missing dependencies**: Verify complete distribution build
- **PATH not updated**: Manual PATH configuration or system restart
- **File associations not working**: Registry permissions or conflicting applications
- **Performance issues**: Configure Windows Defender exclusions

## Quality Assurance

### Automated Testing
```powershell
# Comprehensive installer testing
.\test-installer.ps1 -TestMode full -CleanupAfter -Verbose
```

### Test Coverage
- Installation file integrity and digital signatures
- Silent and interactive installation processes
- Component selection and customization options
- Upgrade and downgrade scenarios
- Uninstallation and cleanup verification
- Registry integration and Windows compatibility
- Multi-user and multi-system testing

### Continuous Integration
The installer can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Build Installer
  run: |
    scripts/installer/build-installer.ps1 -Clean -Verbose
    
- name: Test Installer  
  run: |
    scripts/installer/test-installer.ps1 -TestMode full -CleanupAfter
    
- name: Sign Installer
  run: |
    scripts/installer/build-installer.ps1 -Sign -CertificatePath ${{ secrets.CODE_SIGN_CERT }}
```

## Future Enhancements

### Planned Features
- **Automatic Updates**: Built-in update mechanism with delta patches
- **Plugin System**: Modular component architecture for extensions
- **Configuration Wizard**: Post-installation configuration assistant
- **Diagnostic Tools**: Built-in troubleshooting and diagnostic utilities
- **Integration Packs**: IDE and editor integration packages

### Enterprise Enhancements
- **Group Policy Templates**: Active Directory integration and policy management
- **MSI Package**: Windows Installer package for enterprise deployment
- **SCCM Integration**: System Center Configuration Manager support
- **Network Installation**: Centralized deployment with network shares
- **License Management**: Corporate license key validation and tracking

---

This installer system represents a professional, enterprise-ready solution for distributing Serena Agent on Windows platforms. It combines modern UI design, comprehensive functionality, and enterprise deployment capabilities to provide a seamless installation experience for all user types.