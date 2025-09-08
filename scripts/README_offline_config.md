# Offline Configuration Script for Serena

## Overview

The `offline_config.py` script transforms a Serena installation to work in offline mode by patching the codebase to use locally cached dependencies instead of downloading from the internet.

## Features

### Core Functionality
- **Smart File Patching**: Modifies `FileUtils` and `RuntimeDependency` classes to check for offline cache before downloading
- **Language Server Support**: Patches Java, C#, AL, and TypeScript language servers for offline operation
- **Environment Detection**: Auto-detects offline mode via `SERENA_OFFLINE_MODE` environment variable
- **Path Mapping**: Maps online URLs to local file paths for all supported language servers
- **Backup & Restore**: Creates backups of original files and can restore them for online mode

### Language Server Support

| Language | Components | Offline Dependencies |
|----------|------------|---------------------|
| **Java** | Eclipse JDTLS, Gradle, IntelliCode | VS Code Java Extension, Gradle 8.14.2, IntelliCode |
| **C#** | Microsoft.CodeAnalysis.LanguageServer | .NET 9 Runtime, Language Server NuGet package |
| **AL** | AL Language Server | VS Code AL Extension |
| **TypeScript** | TypeScript Language Server | Node.js Runtime, npm packages |

### Windows Path Handling
- Proper path quoting for Windows command execution
- Handles Windows-specific executable extensions (.exe)
- Support for both forward and backward slashes

## Usage

### Enable Offline Mode

```bash
# Enable with auto-detected dependencies
python scripts/offline_config.py --enable

# Enable with specific dependencies directory  
python scripts/offline_config.py --enable --offline-deps-dir /path/to/offline_deps

# Enable with custom Serena root
python scripts/offline_config.py --enable --serena-root /path/to/serena --offline-deps-dir /path/to/deps
```

### Disable Offline Mode

```bash
# Restore original files
python scripts/offline_config.py --disable
```

### Check Status

```bash
# Show current offline mode status
python scripts/offline_config.py --status
```

### Verify Setup

```bash
# Verify offline mode is working correctly
python scripts/offline_config.py --verify
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SERENA_OFFLINE_MODE` | Enable offline mode | `1`, `true`, `yes`, `on` |
| `SERENA_OFFLINE_DEPS_DIR` | Path to offline dependencies | `/path/to/offline_deps` |

## Directory Structure

The script expects offline dependencies in this structure:

```
offline_deps/
├── manifest.json                      # Download metadata
├── gradle/
│   └── extracted/
│       └── gradle-8.14.2/            # Gradle installation
├── java/
│   ├── vscode-java/                   # VS Code Java Extension  
│   └── intellicode/                   # IntelliCode Extension
├── csharp/
│   ├── dotnet-runtime/                # .NET 9 Runtime
│   └── language-server/               # C# Language Server
├── al/
│   └── extension/                     # AL Extension
├── typescript/
│   └── node_modules/                  # TypeScript packages
└── nodejs/
    └── extracted/                     # Node.js Runtime
```

## File Modifications

### Core Files Modified
- `src/solidlsp/ls_utils.py` - Adds offline cache checking to `FileUtils`
- `src/solidlsp/language_servers/common.py` - Adds offline support to `RuntimeDependency`

### Language Server Files (Optional)
- `src/solidlsp/language_servers/eclipse_jdtls.py` - Java offline paths
- `src/solidlsp/language_servers/csharp_language_server.py` - C# offline paths  
- `src/solidlsp/language_servers/al_language_server.py` - AL offline paths

### Generated Files
- `setup_offline_mode.bat` - Windows environment setup
- `setup_offline_mode.sh` - Unix environment setup
- `.serena_offline_backups/` - Backup directory

## Key Functions

### Offline Cache Functions (Added to `ls_utils.py`)

```python
def check_offline_cache() -> Optional[str]:
    """Check if offline cache directory is available"""

def get_offline_file_path(url: str, logger: LanguageServerLogger) -> Optional[str]:
    """Map URL to local file path in offline mode"""
    
def copy_local_file_to_target(local_path: str, target_path: str, logger: LanguageServerLogger) -> None:
    """Copy local file/directory to target location"""
```

### URL to Local Path Mappings

| URL Pattern | Local Path |
|-------------|------------|
| `gradle-8.14.2-bin.zip` | `offline_deps/gradle/gradle-8.14.2-bin.zip` |
| `java-` (VS Code Extension) | `offline_deps/java/` |
| `dotnet-runtime-9.0.6` | `offline_deps/csharp/` |
| `Microsoft.CodeAnalysis.LanguageServer` | `offline_deps/csharp/` |
| `/al/` (AL Extension) | `offline_deps/al/al-latest.vsix` |
| `nodejs.org` | `offline_deps/nodejs/` |

## Integration with Installer

The script can be imported and used by installation scripts:

```python
from scripts.offline_config import OfflineConfigModifier

# During installation
modifier = OfflineConfigModifier(serena_root="/install/path", offline_deps_dir="/deps/path")
modifier.enable_offline_mode()

# Verification
if modifier.verify_offline_setup():
    print("Offline mode configured successfully")
```

## Error Handling

- **Automatic Backup**: All original files are backed up before modification
- **Rollback on Failure**: If patching fails, original files are restored
- **Verification**: Built-in verification ensures all dependencies are available
- **Logging**: Comprehensive logging to `offline_config.log`

## Troubleshooting

### Common Issues

1. **Missing Dependencies**: Ensure `offline_deps_downloader.py` has run successfully
2. **Permission Errors**: Run with appropriate permissions for file modification
3. **Path Issues**: Use absolute paths for `--offline-deps-dir`
4. **Environment Variables**: Ensure variables are set in current shell session

### Debug Mode

```bash
python scripts/offline_config.py --status --log-level DEBUG
```

### Manual Restoration

If automated restoration fails, manually copy files from `.serena_offline_backups/`:

```bash
cp .serena_offline_backups/*.backup src/solidlsp/
```

## Security Considerations

- Only modifies files within the Serena installation directory
- Creates backups before any modifications
- Does not require elevated privileges (unless installation is in system directory)
- Validates all paths before modification

## Compatibility

- **Python**: 3.8+
- **Platforms**: Windows, Linux, macOS
- **Serena**: Compatible with current architecture
- **Dependencies**: Uses only Python standard library