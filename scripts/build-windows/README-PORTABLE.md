# Serena Portable for Windows

## Overview

Serena Portable is a self-contained version of the Serena coding agent toolkit that runs on Windows without requiring installation or system-wide configuration. This portable version includes all necessary components and can be run from any directory, making it ideal for:

- Development environments where you can't install software globally
- USB drive or network share deployment
- Testing and evaluation without system changes
- Environments with restricted permissions

## Quick Start

1. **Extract** the portable package to your desired location
2. **Run** `serena-portable.bat` to start Serena
3. **Follow** the on-screen prompts to begin using Serena

### Basic Usage

```batch
# Start Serena MCP server (default)
serena-portable.bat

# Start with specific project
serena-portable.bat start-mcp-server --project "C:\My Project"

# Show help
serena-portable.bat --help

# Check version
serena-portable.bat --version
```

## Package Contents

```
serena-portable/
├── serena-portable.bat          # Main launcher script
├── launcher-config.json         # Launcher configuration
├── README-PORTABLE.md          # This documentation
├── serena.exe                  # Main Serena executable (PyInstaller)
├── .serena-portable/           # Portable user data (created on first run)
│   ├── cache/                  # LSP and tool cache
│   ├── logs/                   # Application logs
│   ├── backups/               # Automatic backups
│   └── config/                # User configuration
└── language-servers/          # Bundled language servers (optional)
    ├── python/
    ├── javascript/
    ├── java/
    └── ...
```

## Installation Guide

### System Requirements

- **Operating System**: Windows 10 or later (x64)
- **Memory**: 4GB RAM recommended (2GB minimum)
- **Storage**: 500MB free space (more for projects and language servers)
- **Network**: Internet connection for language server downloads (optional)

### Installation Steps

1. **Download** the Serena Portable package from the releases page
2. **Extract** the ZIP file to your preferred location:
   - Desktop: `C:\Users\%USERNAME%\Desktop\serena-portable\`
   - Portable drive: `E:\serena-portable\`
   - Network share: `\\server\tools\serena-portable\`
3. **Test** the installation by running `serena-portable.bat --version`

### First Run Setup

1. Run `serena-portable.bat` for the first time
2. The launcher will create the `.serena-portable` directory
3. Language servers will be downloaded on-demand when needed
4. Configuration files will be initialized with defaults

## Configuration

### Launcher Configuration

The `launcher-config.json` file controls the portable launcher behavior. Key settings:

```json
{
  "serena": {
    "default_context": "desktop-app",
    "default_modes": ["interactive"],
    "auto_start_mcp_server": true
  },
  "environment": {
    "portable_mode": true,
    "user_directory": ".serena-portable"
  },
  "language_servers": {
    "download_on_demand": true,
    "cache_downloads": true
  }
}
```

### Serena Configuration

Create project-specific configurations in `.serena-portable/project.yml`:

```yaml
# Project configuration
project_name: "My Project"
language: python
root_directory: "C:\\MyProject"
include_patterns:
  - "**/*.py"
  - "**/*.js"
exclude_patterns:
  - "**/node_modules/**"
  - "**/__pycache__/**"
```

## Usage Guide

### Starting Serena

#### Default Mode (MCP Server)
```batch
serena-portable.bat
```

#### With Project
```batch
serena-portable.bat start-mcp-server --project "C:\MyProject"
```

#### With Custom Context and Mode
```batch
serena-portable.bat start-mcp-server --context agent --mode editing
```

#### Web Dashboard
```batch
serena-portable.bat start-mcp-server --transport sse --enable-web-dashboard
```

### Command Line Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--project` | Specify project directory | `--project "C:\MyCode"` |
| `--context` | Set Serena context | `--context desktop-app` |
| `--mode` | Set operational mode | `--mode interactive` |
| `--transport` | Communication protocol | `--transport stdio` |
| `--host` | Server host address | `--host 127.0.0.1` |
| `--port` | Server port number | `--port 8000` |
| `--log-level` | Logging verbosity | `--log-level DEBUG` |

### Working with Projects

1. **Create a new project**:
   ```batch
   serena-portable.bat project generate-yml "C:\MyProject"
   ```

2. **Index a project** (for better performance):
   ```batch
   serena-portable.bat project index "C:\MyProject"
   ```

3. **Health check**:
   ```batch
   serena-portable.bat project health-check "C:\MyProject"
   ```

## Language Server Support

Serena Portable supports 20+ programming languages with automatic language server management.

### Supported Languages

| Language | Server | Auto-Download | Notes |
|----------|---------|---------------|--------|
| Python | Pyright | ✓ | Full support |
| JavaScript/TypeScript | TypeScript LSP | ✓ | Node.js required |
| Java | Eclipse JDT.LS | ✓ | JVM required |
| Kotlin | Kotlin LSP | ✓ | JVM required |
| Go | gopls | ✓ | Full support |
| Rust | rust-analyzer | ✓ | Full support |
| C# | OmniSharp | ✓ | .NET required |
| PHP | Intelephense | ✓ | Full support |
| Ruby | Ruby LSP | ✓ | Ruby required |
| Swift | SourceKit-LSP | ✓ | macOS/Linux only |
| Clojure | clojure-lsp | ✓ | JVM required |
| Elixir | ElixirLS | ✓ | Elixir required |
| Terraform | terraform-ls | ✓ | Full support |
| Bash | bash-language-server | ✓ | Full support |
| R | R Language Server | ✓ | R required |
| Zig | ZLS | ✓ | Full support |
| Lua | lua-language-server | ✓ | Full support |
| Nix | nixd | ✓ | Full support |
| Dart | Dart LSP | ✓ | Dart SDK required |
| Erlang | Erlang LS | ✓ | Erlang required |
| AL | AL Language Server | ✓ | Business Central |

### Language Server Configuration

Language servers are configured automatically but can be customized in `launcher-config.json`:

```json
{
  "language_servers": {
    "configurations": {
      "python": {
        "server": "pyright",
        "executable": "pyright-langserver",
        "auto_download": true
      }
    }
  }
}
```

### Manual Language Server Setup

If automatic download fails, you can manually install language servers:

1. Create `language-servers\<language>` directory
2. Download and extract the language server
3. Update `launcher-config.json` with the correct executable path

## Troubleshooting

### Common Issues

#### 1. "Serena executable not found"

**Cause**: The PyInstaller executable is missing or in an unexpected location.

**Solution**:
- Ensure `serena.exe` exists in the portable directory
- Check alternative names: `serena-mcp-server.exe`, `serena-agent.exe`
- Rebuild the PyInstaller executable if necessary

#### 2. "Configuration file not found"

**Cause**: `launcher-config.json` is missing.

**Solution**:
- Restore the configuration file from backup
- Download a fresh portable package
- Create a minimal configuration file

#### 3. Language server fails to start

**Cause**: Missing dependencies or download failure.

**Solution**:
- Check internet connection for auto-download
- Verify required runtimes (Java, Node.js, .NET, etc.)
- Check language server logs in `.serena-portable\logs\`
- Try manual installation

#### 4. Project not recognized

**Cause**: Missing or invalid project configuration.

**Solution**:
```batch
# Generate project configuration
serena-portable.bat project generate-yml "C:\MyProject"

# Verify project structure
serena-portable.bat project health-check "C:\MyProject"
```

#### 5. Permission errors

**Cause**: Insufficient file system permissions.

**Solution**:
- Move portable directory to user profile
- Run as administrator (if necessary)
- Check antivirus software blocking files

#### 6. Port already in use

**Cause**: Another application using the same port.

**Solution**:
```batch
# Use different port
serena-portable.bat start-mcp-server --port 8001

# Check running processes
netstat -ano | findstr :8000
```

### Diagnostic Tools

#### Launcher Diagnostics
```batch
# Show configuration
serena-portable.bat --config

# View logs
type serena-launcher.log

# Test executable
serena-portable.bat --version
```

#### Serena Diagnostics
```batch
# Project health check  
serena-portable.bat project health-check "C:\MyProject"

# List available tools
serena-portable.bat tools list

# Check context and modes
serena-portable.bat context list
serena-portable.bat mode list
```

### Log Files

Important log locations:
- **Launcher logs**: `serena-launcher.log`
- **Application logs**: `.serena-portable\logs\mcp_*.log`
- **Language server logs**: `.serena-portable\logs\lsp\`
- **Project indexing**: `<project>\.serena\logs\indexing.txt`

### Debug Mode

Enable debug mode for detailed troubleshooting:

1. Edit `launcher-config.json`:
```json
{
  "advanced": {
    "debug_mode": true,
    "verbose_logging": true
  },
  "logging": {
    "level": "DEBUG",
    "log_lsp_communication": true
  }
}
```

2. Run with debug logging:
```batch
serena-portable.bat start-mcp-server --log-level DEBUG
```

## Performance Optimization

### Memory Usage

- **Default**: 2GB RAM limit
- **Large projects**: Increase in `launcher-config.json`
- **Memory monitoring**: Use Task Manager to monitor usage

### Cache Management

- **LSP cache**: `.serena-portable\cache\lsp\`
- **Tool cache**: `.serena-portable\cache\tools\`
- **Clear cache**: Delete cache directories (will rebuild)

### Project Indexing

Pre-index large projects for better performance:
```batch
serena-portable.bat project index "C:\LargeProject" --timeout 30
```

### Language Server Optimization

- **Preload**: Set `preload_language_servers: true` in config
- **Bundled**: Include language servers in portable package
- **Parallel**: Enable `parallel_operations: true` for faster processing

## Security Considerations

### File System Access

Serena Portable has configurable file system restrictions:

```json
{
  "security": {
    "restrict_file_access": false,
    "allowed_file_extensions": [".py", ".js", ".ts"],
    "blocked_directories": ["System32", "Windows"]
  }
}
```

### Network Security

- **Local only**: Default binds to `127.0.0.1`
- **Firewall**: Configure Windows Firewall if needed  
- **Proxy**: Supports system proxy settings

### Code Execution

- **Sandboxing**: Optional sandbox mode available
- **Code execution**: Can be disabled in configuration
- **Trust boundaries**: Respect project boundaries

## Advanced Configuration

### Custom Contexts

Create custom contexts in `.serena-portable\contexts\`:

```yaml
# custom-context.yml
name: "My Custom Context" 
description: "Specialized context for my workflow"
tools:
  - FindSymbolTool
  - EditSymbolTool
  - SearchForPatternTool
settings:
  max_file_size: 1000000
  timeout: 30
```

### Custom Modes

Create custom modes in `.serena-portable\modes\`:

```yaml
# custom-mode.yml  
name: "My Custom Mode"
description: "Specialized mode for code review"
phases:
  - name: "analysis"
    tools: ["GetSymbolsOverviewTool", "FindReferencingSymbolsTool"]
  - name: "editing"  
    tools: ["EditSymbolTool", "CreateFileTool"]
```

### Environment Variables

Set custom environment variables:

```json
{
  "environment": {
    "variables": {
      "MY_CUSTOM_VAR": "value",
      "PROJECT_ROOT": "%SERENA_PORTABLE_ROOT%\\projects"
    }
  }
}
```

## Integration

### IDE Integration

#### Visual Studio Code
1. Install MCP extension
2. Configure connection to Serena MCP server
3. Point to `serena-portable.bat start-mcp-server`

#### Other IDEs
Use the MCP protocol to connect any compatible IDE or tool.

### CI/CD Integration

```batch
# In build scripts
call serena-portable.bat project health-check "%PROJECT_DIR%"
if %ERRORLEVEL% neq 0 exit /b 1
```

### Automation Scripts

```batch
@echo off
rem Automated code analysis
serena-portable.bat start-mcp-server --project "%1" --mode analysis
```

## Backup and Recovery

### Automatic Backups

Configured in `launcher-config.json`:

```json
{
  "backup": {
    "auto_backup": true,
    "backup_interval_hours": 24,
    "max_backups": 7,
    "backup_directory": ".serena-portable/backups"
  }
}
```

### Manual Backup

```batch
# Backup user data
xcopy /E /I ".serena-portable" "backup\.serena-portable"

# Backup configuration
copy "launcher-config.json" "backup\launcher-config.json"
```

### Recovery

```batch  
# Restore from backup
xcopy /E /Y "backup\.serena-portable" ".serena-portable\"
copy /Y "backup\launcher-config.json" "launcher-config.json"
```

## Updates and Maintenance

### Checking for Updates

Currently, Serena Portable requires manual updates:

1. Download new portable package
2. Extract to temporary location
3. Copy `.serena-portable` directory from old installation
4. Copy any custom configurations
5. Test the new version
6. Replace old installation

### Maintenance Tasks

#### Weekly
- Check log file sizes
- Review performance metrics
- Update language servers if needed

#### Monthly  
- Clean old cache files
- Review and cleanup backups
- Update project configurations

#### As Needed
- Update Serena Portable package
- Reconfigure language servers
- Optimize project settings

## FAQ

### General Questions

**Q: Can I run multiple instances of Serena Portable?**
A: Yes, but they need different port numbers. Use `--port` to specify different ports.

**Q: Can I move the portable installation to another computer?**
A: Yes, just copy the entire directory. Language servers may need to be re-downloaded.

**Q: Does Serena Portable work on Windows 11?**
A: Yes, it's compatible with Windows 10 and later versions.

**Q: Can I use Serena Portable on a USB drive?**
A: Yes, but performance may be slower depending on USB speed.

### Technical Questions

**Q: How do I add support for a custom language?**
A: Create a custom language server configuration in `launcher-config.json` and provide the executable.

**Q: Can I use custom Python interpreters?**
A: Yes, set `custom_python_path` in the advanced configuration section.

**Q: How do I debug language server issues?**
A: Enable debug logging and check `.serena-portable\logs\lsp\` for language server logs.

**Q: Can I run Serena Portable without internet access?**
A: Yes, if language servers are pre-bundled. Otherwise, initial setup requires internet.

### Configuration Questions

**Q: How do I change the default project location?**
A: Set environment variables or use `--project` argument with full paths.

**Q: Can I disable the web dashboard?**
A: Yes, set `enable_web_dashboard: false` in `launcher-config.json`.

**Q: How do I increase memory limits?**
A: Modify `max_memory_mb` in the performance section of `launcher-config.json`.

## Support and Resources

### Documentation
- **Main Documentation**: See project README.md
- **MCP Protocol**: [Model Context Protocol](https://spec.modelcontextprotocol.io/)
- **Language Servers**: [LSP Specification](https://microsoft.github.io/language-server-protocol/)

### Community
- **Issues**: Report bugs on the project repository
- **Discussions**: Join community discussions  
- **Contributions**: See CONTRIBUTING.md for development guidelines

### Professional Support
Contact Oraios AI for enterprise support and custom deployments.

---

**Version**: Serena Portable 1.0  
**Last Updated**: 2025-09-10  
**Compatibility**: Windows 10+ (x64)