# Custom Serena Build Generator

The `build_custom_serena.py` script provides an interactive way to create customized Serena standalone builds with selected language server support.

## Quick Start

### Interactive Mode

Run the script without arguments for an interactive build experience:

```bash
python scripts/build_custom_serena.py
```

This will guide you through:
1. Selecting a preset or custom language selection
2. Choosing languages by category
3. Platform configuration
4. Output directory selection
5. PyInstaller execution options

### Using Presets

For quick builds, use one of the predefined presets:

```bash
# List available presets
python scripts/build_custom_serena.py --list-presets

# Use a preset
python scripts/build_custom_serena.py --preset standard
```

Available presets:
- **minimal**: No bundled language servers (download on demand) - 0 MB
- **standard**: Common languages (C++, Rust, Lua, Terraform, Dart) - ~375 MB
- **full**: All language servers including Java and Go - ~690 MB
- **web**: Web development languages (TypeScript, PHP, YAML, Bash) - ~0 MB
- **systems**: Systems programming (C++, Rust, Go) - ~150 MB
- **jvm**: JVM languages (Java, Kotlin, Gradle) - ~285 MB

### Configuration Files

Save and reuse build configurations with JSON config files:

```bash
# Save a configuration
python scripts/build_custom_serena.py --preset systems --save-config my_build.json

# Use a saved configuration
python scripts/build_custom_serena.py --config my_build.json

# Dry-run with a configuration
python scripts/build_custom_serena.py --config my_build.json --dry-run
```

Example configuration file:
```json
{
  "languages": ["clangd", "rust-analyzer", "gopls"],
  "platform": "linux-x64",
  "output_dir": "./language_servers",
  "run_pyinstaller": true,
  "pyinstaller_args": ["--clean", "--noconfirm"]
}
```

See `scripts/example_build_config.json` for a complete example.

## Available Language Servers

### Web Development (0 MB - bundled with Serena)
- **typescript**: TypeScript/JavaScript
- **php**: PHP
- **yaml**: YAML
- **bash**: Bash/Shell scripts

### Systems Programming
- **clangd**: C/C++ (~100 MB)
- **rust-analyzer**: Rust (~20 MB)
- **gopls**: Go (~30 MB, requires Go toolchain)

### JVM Languages
- **jdtls**: Java Eclipse JDTLS (~150 MB)
- **kotlin-ls**: Kotlin (~85 MB, requires jdtls)
- **gradle**: Gradle build tool (~50 MB, requires jdtls)

### Infrastructure
- **terraform-ls**: Terraform (~50 MB)

### Other Languages
- **dart**: Dart (~200 MB)
- **lua-ls**: Lua (~5 MB)

## Command-Line Options

### Information Commands

```bash
# Show help
python scripts/build_custom_serena.py --help

# List available presets
python scripts/build_custom_serena.py --list-presets

# List all available language servers
python scripts/build_custom_serena.py --list-languages
```

### Build Configuration

```bash
# Use a preset
--preset {minimal,standard,full,web,systems,jvm}

# Load configuration from file
--config CONFIG_FILE

# Save configuration to file
--save-config CONFIG_FILE

# Override platform
--platform {linux-x64,linux-arm64,win-x64,win-arm64,osx-x64,osx-arm64}

# Override output directory
--output-dir OUTPUT_DIR

# Preview build without executing
--dry-run

# Skip PyInstaller build (only bundle language servers)
--no-pyinstaller
```

## Usage Examples

### Example 1: Create a Web Development Build

```bash
# Interactive selection
python scripts/build_custom_serena.py --preset web --dry-run

# Review what will be built, then execute
python scripts/build_custom_serena.py --preset web
```

### Example 2: Cross-Platform Build

```bash
# Build for Windows from Linux
python scripts/build_custom_serena.py \
  --preset standard \
  --platform win-x64 \
  --output-dir ./windows_ls
```

### Example 3: Reproducible Builds

```bash
# Create configuration once
python scripts/build_custom_serena.py \
  --preset systems \
  --platform linux-x64 \
  --save-config production_build.json

# Reuse configuration for consistent builds
python scripts/build_custom_serena.py --config production_build.json

# Team members can use the same config
git add production_build.json
git commit -m "Add production build config"
```

### Example 4: Custom Language Selection

```bash
# Start interactive mode and select custom
python scripts/build_custom_serena.py

# Follow prompts to select specific languages
# Then save configuration for future use
```

### Example 5: Bundle Only (Skip PyInstaller)

```bash
# Just bundle language servers, don't create standalone executable
python scripts/build_custom_serena.py \
  --preset full \
  --no-pyinstaller
```

## How It Works

The build script performs the following steps:

1. **Configuration**: Collects build preferences (preset, custom selection, or config file)
2. **Validation**: Checks dependencies (e.g., Kotlin requires Java)
3. **Bundling**: Calls `bundle_language_servers.py` to download language servers
4. **PyInstaller** (optional): Creates standalone executable with bundled servers
5. **Summary**: Reports build status and output locations

## Dependencies

### Language Server Dependencies

Some language servers have special requirements:

- **gopls**: Requires Go toolchain to be installed (`go version` should work)
- **kotlin-ls**: Requires Java runtime (automatically bundled with jdtls)
- **gradle**: Requires Java runtime (automatically bundled with jdtls)

The script will warn you about missing dependencies and automatically include required dependencies.

### Build Dependencies

- Python 3.11+
- `bundle_language_servers.py` script (in same directory)
- PyInstaller (optional, for creating standalone executables)

## Output

### Language Servers

Bundled language servers are saved to the output directory (default: `./language_servers/`):

```
language_servers/
├── clangd/
│   └── bin/clangd
├── rust-analyzer/
│   └── rust-analyzer
├── lua-ls/
│   └── bin/lua-language-server
├── terraform-ls/
│   └── terraform-ls
└── MANIFEST.txt
```

### Standalone Executable

If PyInstaller is enabled, the standalone executable is created in `./dist/`:

```
dist/
└── serena          # or serena.exe on Windows
```

## Dry Run Mode

Test your configuration without downloading or building:

```bash
python scripts/build_custom_serena.py --preset full --dry-run
```

This will:
- Show which language servers would be bundled
- Display estimated download sizes
- Preview PyInstaller command
- Exit without downloading or building

## Troubleshooting

### Script fails with "Go toolchain not found"

If you selected `gopls`:
```bash
# Install Go from https://golang.org/
# Or on Ubuntu/Debian:
sudo apt-get install golang

# Verify installation
go version
```

### PyInstaller not found

```bash
# Install PyInstaller
pip install pyinstaller

# Or with uv
uv pip install pyinstaller
```

### Bundle script fails with import errors

Make sure you're running from the project root:
```bash
cd /path/to/serena
python scripts/build_custom_serena.py
```

## Advanced Usage

### Custom PyInstaller Arguments

Modify the config file to add custom PyInstaller arguments:

```json
{
  "languages": ["clangd", "rust-analyzer"],
  "platform": "linux-x64",
  "output_dir": "./language_servers",
  "run_pyinstaller": true,
  "pyinstaller_args": [
    "--clean",
    "--noconfirm",
    "--add-data", "extra_files:.",
    "--hidden-import", "my_module"
  ]
}
```

### Combining Presets

Start with a preset and modify the config:

```bash
# Save preset to file
python scripts/build_custom_serena.py --preset web --save-config web_base.json

# Edit web_base.json to add/remove languages
# Then build with modified config
python scripts/build_custom_serena.py --config web_base.json
```

## Integration with CI/CD

Use config files for reproducible builds in CI/CD pipelines:

```yaml
# .github/workflows/build.yml
- name: Build Serena
  run: |
    python scripts/build_custom_serena.py --config .ci/build_config.json

- name: Upload artifacts
  uses: actions/upload-artifact@v2
  with:
    name: serena-standalone
    path: dist/serena
```

## Related Scripts

- `bundle_language_servers.py`: Downloads and bundles language server binaries
- See main project README for development setup and contribution guidelines
