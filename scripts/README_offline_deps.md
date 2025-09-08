# Offline Dependencies Downloader

This script downloads all language server binaries and runtime dependencies needed for offline usage of Serena on Windows systems.

## What it downloads

### 1. Java Language Server (Eclipse JDTLS)
- **Gradle 8.14.2**: Build tool from https://services.gradle.org/distributions/gradle-8.14.2-bin.zip
- **VS Code Java Extension v1.42.0**: Contains JRE 21 and Eclipse JDTLS binaries
  - Windows x64: `java-win32-x64-1.42.0-561.vsix`
  - Windows ARM64: `java-win32-arm64-1.42.0-561.vsix`
- **IntelliCode Extension v1.2.30**: AI-assisted coding support from VS Code marketplace

### 2. C# Language Server (Microsoft.CodeAnalysis.LanguageServer)
- **.NET 9 Runtime**: Official runtime from Microsoft build servers
  - Windows x64: `dotnet-runtime-9.0.6-win-x64.zip`
  - Windows ARM64: `dotnet-runtime-9.0.6-win-arm64.zip`
- **Microsoft.CodeAnalysis.LanguageServer**: Official Roslyn language server from Azure NuGet feed
  - Version: `5.0.0-1.25329.6`
  - Platform-specific packages for win-x64 and win-arm64

### 3. AL Language Server
- **AL Extension**: Latest AL extension for Microsoft Dynamics 365 Business Central
  - Downloaded from VS Code marketplace: `ms-dynamics-smb.al`

### 4. TypeScript/JavaScript Language Server
- **TypeScript Compiler 5.5.4**: Official TypeScript compiler
- **TypeScript Language Server 4.3.3**: LSP server for TypeScript/JavaScript
- Downloaded as npm packages with full dependency tree

### 5. Node.js Runtime
- **Node.js v20.18.2**: JavaScript runtime for TypeScript language server
  - Windows x64: `node-v20.18.2-win-x64.zip`
  - Windows ARM64: `node-v20.18.2-win-arm64.zip`

## Usage

### Basic usage
```bash
python3 scripts/offline_deps_downloader.py
```

### Advanced usage
```bash
python3 scripts/offline_deps_downloader.py \
    --output-dir ./my_offline_deps \
    --platform win-arm64 \
    --resume \
    --create-manifest
```

### Command-line options

- `--output-dir DIR`: Output directory for downloads (default: `./offline_deps`)
- `--platform PLATFORM`: Target platform: `win-x64` or `win-arm64` (default: `win-x64`)
- `--resume`: Resume interrupted downloads (supports partial file resume)
- `--create-manifest`: Create `manifest.json` with download metadata

## Output Structure

The script creates the following directory structure:

```
offline_deps/
├── gradle/
│   ├── gradle-8.14.2-bin.zip
│   └── extracted/
│       └── gradle-8.14.2/
├── java/
│   ├── java-win32-x64-1.42.0-561.vsix
│   ├── vscode-java/
│   │   └── extension/
│   ├── vscodeintellicode-1.2.30.vsix
│   └── intellicode/
│       └── extension/
├── csharp/
│   ├── dotnet-runtime-9.0.6-win-x64.zip
│   ├── dotnet-runtime/
│   ├── Microsoft.CodeAnalysis.LanguageServer.win-x64.5.0.0-1.25329.6.nupkg
│   └── language-server/
├── al/
│   ├── al-latest.vsix
│   └── extension/
├── typescript/
│   ├── package.json
│   └── node_modules/
│       ├── typescript/
│       └── typescript-language-server/
├── nodejs/
│   ├── node-v20.18.2-win-x64.zip
│   └── extracted/
│       └── node-v20.18.2-win-x64/
└── manifest.json (if --create-manifest used)
```

## Manifest File

When using `--create-manifest`, the script generates a `manifest.json` file containing:

```json
{
  "platform": "win-x64",
  "created_at": "/path/to/working/directory", 
  "total_downloads": 6,
  "total_size_bytes": 1234567890,
  "total_size_mb": 1177.38,
  "downloads": {
    "gradle": {
      "url": "https://services.gradle.org/distributions/gradle-8.14.2-bin.zip",
      "archive": "/path/to/gradle-8.14.2-bin.zip",
      "extracted": "/path/to/extracted",
      "version": "8.14.2"
    },
    // ... other components
  }
}
```

## Prerequisites

- Python 3.6+ with `urllib`, `json`, `hashlib` (standard library)
- For TypeScript dependencies: Node.js and npm must be installed
- Internet connection for downloading

## Features

- **Progress tracking**: Shows download progress every 10MB
- **Resume support**: Can resume interrupted downloads using HTTP Range requests  
- **Checksum verification**: Verifies file integrity where checksums are available
- **Platform awareness**: Downloads correct platform-specific binaries
- **Proper extraction**: Handles ZIP, VSIX, and NUPKG archives correctly
- **Error handling**: Robust error handling with detailed logging
- **Manifest generation**: Creates metadata file for tracking downloads

## Troubleshooting

### Common Issues

1. **npm not found**: Install Node.js which includes npm
2. **Download timeouts**: Use `--resume` flag to continue interrupted downloads
3. **Disk space**: Ensure sufficient space (~2-3GB for all dependencies)
4. **Network issues**: Script includes retry logic and resume capability

### Log Output

The script provides detailed logging:
- INFO: Normal progress and success messages
- ERROR: Download failures and critical errors
- Progress updates every 10MB during downloads

### Using Downloaded Dependencies

After downloading, you can:
1. Copy the entire `offline_deps` directory to target Windows systems
2. Configure Serena to use local paths instead of downloading
3. Set environment variables pointing to local installations
4. Use the extracted binaries directly in language server configurations

## Size Expectations

Total download size varies by platform but expect:
- **Java components**: ~400-500MB (includes JRE)
- **C# components**: ~50-100MB
- **AL extension**: ~20-30MB  
- **TypeScript/Node.js**: ~50-100MB
- **Total**: ~600-800MB depending on platform and packages

The extracted size will be larger due to archive expansion.