# Serena Agent - Windows Installer

This directory contains the NSIS installer scripts and build tools for creating a professional Windows installer for Serena Agent.

## Files

- `serena-installer.nsi` - Main NSIS installer script
- `build-installer.bat` - Windows batch build script
- `build-installer.ps1` - PowerShell build script with advanced features
- `README.md` - This documentation file

## Prerequisites

### Required Software

1. **NSIS (Nullsoft Scriptable Install System)**
   - Download from: https://nsis.sourceforge.io/
   - Minimum version: 3.0
   - Ensure `makensis.exe` is in your system PATH

2. **Windows SDK (for code signing)**
   - Required only if you plan to sign the installer
   - Provides `signtool.exe` for code signing

### Required Files

Before building the installer, ensure you have:

1. **Distribution Files**: Built using `scripts/build-windows/build-portable.ps1`
2. **Language Servers** (optional): Downloaded language server binaries
3. **Certificate** (optional): Code signing certificate for release builds

## Building the Installer

### Method 1: Using PowerShell Script (Recommended)

```powershell
# Basic build
.\build-installer.ps1

# Clean build with verbose output
.\build-installer.ps1 -Clean -Verbose

# Build with code signing
.\build-installer.ps1 -Sign -CertificatePath "C:\path\to\cert.p12" -CertificatePassword "password"
```

### Method 2: Using Batch Script

```batch
# Simple build
build-installer.bat
```

### Method 3: Manual NSIS Build

```batch
# Navigate to installer directory
cd scripts\installer

# Build manually (after copying dist files)
makensis /V3 serena-installer.nsi
```

## Installer Features

### Modern UI Components

- **Welcome Page**: Professional welcome screen with branding
- **License Agreement**: MIT license display and acceptance
- **Component Selection**: Choose installation components
- **Directory Selection**: Custom installation directory
- **Start Menu Configuration**: Configurable start menu folder
- **Installation Progress**: Real-time installation feedback
- **Finish Page**: Launch options and documentation links

### Installation Types

1. **Full Installation** (Default)
   - Core components
   - Language servers
   - Start menu shortcuts
   - File associations

2. **Core Installation** (Minimal)
   - Core components only
   - Essential shortcuts

3. **Custom Installation**
   - User-selectable components
   - Advanced options (PATH, Windows Defender exclusions)

### Components

#### Core Components (Required)
- Serena Agent executable (`serena.exe`)
- MCP Server executable (`serena-mcp-server.exe`)
- Index project utility (`index-project.exe`)
- License and documentation files
- Runtime libraries and dependencies

#### Language Servers (Optional)
- Pre-downloaded language server binaries
- Multi-language development support
- Automatic configuration

#### Start Menu Shortcuts (Optional)
- Application shortcuts
- Documentation links
- Uninstaller shortcut
- Desktop shortcut

#### PATH Integration (Optional)
- Adds Serena to system/user PATH
- Command-line access from anywhere
- Environment variable updates

#### File Associations (Optional)
- Associates `.serena` files with Serena Agent
- Custom file icons
- Shell integration

#### Windows Defender Exclusions (Optional)
- Performance optimization
- Reduces false positive detections
- Requires administrator privileges

### Advanced Features

#### Multi-Language Support
- English (default)
- German
- French  
- Spanish
- Extensible language system

#### Installation Modes
- **System-wide**: Requires administrator privileges
- **User-only**: Current user installation when admin rights unavailable
- **Upgrade Detection**: Preserves settings during upgrades

#### Security Features
- Digital signature support (code signing)
- Certificate validation
- Integrity checks

#### Enterprise Features
- Silent installation support
- Registry-based configuration
- Centralized deployment ready
- Unattended installation options

## Configuration

### Environment Variables

The installer respects these environment variables:

- `SERENA_INSTALL_DIR` - Override default installation directory
- `SERENA_SKIP_PATH` - Skip PATH modification (set to "1")
- `SERENA_SKIP_ASSOC` - Skip file associations (set to "1")

### Registry Keys

#### Installation Information
- `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Serena Agent`
- `HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\serena.exe`

#### User Preferences
- `HKCU\Software\Oraios AI\Serena Agent`

#### File Associations
- `HKLM\Software\Classes\.serena`
- `HKLM\Software\Classes\SerenaProject`

## Code Signing

For distribution releases, the installer should be digitally signed:

### Automatic Signing (PowerShell)

```powershell
.\build-installer.ps1 -Sign -CertificatePath "cert.p12" -CertificatePassword "password"
```

### Manual Signing

```batch
signtool sign /f "certificate.p12" /p "password" /t http://timestamp.verisign.com/scripts/timstamp.dll "serena-installer-0.1.4.exe"
```

### Certificate Requirements

- **Code Signing Certificate**: From a trusted CA (Digicert, GlobalSign, etc.)
- **Timestamp Server**: For long-term signature validity
- **Certificate Format**: P12/PFX with private key

## Troubleshooting

### Common Issues

#### NSIS Not Found
```
ERROR: NSIS (makensis) not found in PATH
```
**Solution**: Install NSIS and add to PATH, or specify full path to makensis.exe

#### Distribution Files Missing
```
ERROR: Distribution directory not found
```
**Solution**: Build portable distribution first using `build-portable.ps1`

#### Insufficient Permissions
```
Error opening file for writing
```
**Solution**: Run build script as Administrator or use user-level installation

#### Windows Defender Exclusions Fail
```
Warning: Could not add Windows Defender exclusion
```
**Solution**: Run installer as Administrator, or manually add exclusions

### Build Process Issues

1. **Check Prerequisites**: Verify NSIS installation and PATH
2. **Verify Distribution**: Ensure `dist/` directory contains all required files
3. **Clean Build**: Use `-Clean` flag to remove previous build artifacts
4. **Verbose Output**: Use `-Verbose` flag for detailed build information

### Runtime Issues

1. **Missing Dependencies**: Ensure all runtime libraries are included in distribution
2. **Permission Errors**: Install with appropriate privileges for selected components
3. **Antivirus Interference**: Add Windows Defender exclusions during installation

## Customization

### Branding

Modify these defines in `serena-installer.nsi`:
- `PRODUCT_NAME` - Application name
- `PRODUCT_VERSION` - Version string
- `PRODUCT_PUBLISHER` - Company name
- `PRODUCT_WEB_SITE` - Website URL

### Icons and Graphics

Replace these resources:
- `MUI_ICON` - Installation icon
- `MUI_UNICON` - Uninstaller icon  
- `MUI_HEADERIMAGE_BITMAP` - Header image
- `MUI_WELCOMEFINISHPAGE_BITMAP` - Wizard images

### Components

Add new components by:
1. Defining new section in installer script
2. Adding component descriptions
3. Updating installation types
4. Implementing uninstaller support

### Languages

Add new languages by:
1. Including language file: `!insertmacro MUI_LANGUAGE "NewLanguage"`
2. Adding translated strings for all `LangString` definitions
3. Testing with target locale

## Testing

### Test Scenarios

1. **Fresh Installation**: Clean system without previous version
2. **Upgrade Installation**: Install over existing version
3. **Component Selection**: Test all component combinations
4. **User vs System**: Test both installation modes
5. **Uninstallation**: Verify complete removal
6. **Silent Installation**: Test unattended installation

### Test Environments

- Windows 10 (minimum supported version)
- Windows 11
- Windows Server 2019/2022
- Different user privilege levels
- Various antivirus software configurations

## Distribution

### Release Process

1. Build portable distribution
2. Test installer on clean systems
3. Code sign installer executable
4. Verify digital signature
5. Upload to distribution channels
6. Update documentation and release notes

### File Naming Convention

`serena-installer-{version}.exe`

Example: `serena-installer-0.1.4.exe`

## Support

For installer-related issues:

1. Check build logs for error messages
2. Verify system requirements and prerequisites
3. Test on clean virtual machine
4. Review Windows Event Logs for installation errors
5. Contact development team with detailed error information

## License

This installer script is released under the MIT License, same as the Serena Agent project.