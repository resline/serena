# Serena Windows Portable - Quick Start Guide

Get Serena up and running on Windows in under 5 minutes! This guide covers building, installing, and using the portable Windows version of Serena.

## Prerequisites

### For Using Pre-built Portable Version
- **Windows 10/11** (x64 or ARM64)
- **No additional software required** - everything is bundled!

### For Building from Source
- **Windows 10/11** with PowerShell
- **Python 3.11** (not 3.12+ due to compatibility requirements)
- **UV package manager** - [Install UV](https://docs.astral.sh/uv/getting-started/installation/)
- **Git** for cloning the repository

## 🚀 Quick Start Options

### Option 1: Download Pre-built Release (Recommended)
1. Go to [Releases](https://github.com/oraios/serena/releases)
2. Download the appropriate bundle:
   - `serena-windows-x64-essential-*.zip` (most popular choice)
   - `serena-windows-arm64-essential-*.zip` (for ARM64 systems)
3. Extract the ZIP file
4. Run `install.bat` (Command Prompt) or `install.ps1` (PowerShell) as Administrator
5. Restart your terminal and verify: `serena --version`

### Option 2: Build via GitHub Actions
1. Go to the [Actions tab](https://github.com/oraios/serena/actions/workflows/windows-portable.yml)
2. Click "Run workflow"
3. Select your preferences:
   - **Bundle tier**: `essential` (recommended), `complete`, `minimal`, or `full`
   - **Architecture**: `x64`, `arm64`, or `both`
4. Download artifacts when complete

### Option 3: Build Locally
```bash
# Clone and build
git clone https://github.com/oraios/serena.git
cd serena
uv venv --python 3.11
.venv\Scripts\activate
uv pip install -e ".[dev]" pyinstaller==6.11.1

# Build portable executable
uv run serena build-portable --bundle-tier essential --arch x64
```

## 📦 Bundle Tiers Explained

Choose the right bundle for your needs:

| Tier | Size | Language Servers Included | Best For |
|------|------|--------------------------|----------|
| **minimal** | ~50MB | None | Testing, custom setups |
| **essential** | ~200MB | Python, TypeScript, Rust, Go | Most developers (recommended) |
| **complete** | ~500MB | Essential + Java, C#, Lua, Bash | Full-stack development |
| **full** | ~800MB | All 28+ supported languages | Enterprise/multi-language projects |

## 🎯 Common Use Cases & Examples

### 1. Supercharge Claude Code
From your project directory:
```bash
claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd%
```

### 2. Integrate with Claude Desktop
Add to your Claude Desktop config (`%APPDATA%\Claude\claude_desktop_config.json`):
```json
{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "desktop-app"]
        }
    }
}
```

### 3. Use with VSCode Extensions (Cline, Cursor, etc.)
Configure your MCP client with:
```json
{
    "command": "serena",
    "args": ["start-mcp-server", "--context", "ide-assistant"]
}
```

### 4. Quick Project Analysis
```bash
# Activate project and get overview
serena project activate C:\path\to\your\project
serena project index  # For better performance on large projects
```

## 🛠️ Troubleshooting Top 5 Issues

### 1. "serena: command not found"
**Solution**: Restart your terminal after installation. If still failing:
```bash
# Check if in PATH
echo %PATH% | findstr Serena

# Manual PATH addition
set PATH=%PATH%;%USERPROFILE%\AppData\Local\Serena\bin
```

### 2. Language Server Startup Errors
**Solution**: Try restarting the language server:
```bash
# In your MCP client, run:
restart_language_server
```

### 3. Permission Denied Errors
**Solution**: 
- Run installation scripts as Administrator
- Check antivirus isn't blocking the executable
- Ensure write permissions to `%USERPROFILE%\.serena`

### 4. Large Project Performance Issues
**Solution**: Always index your project first:
```bash
serena project index
```

### 5. Git Line Ending Issues
**Solution**: Configure git properly for Windows:
```bash
git config --global core.autocrlf true
```

## 📚 Next Steps

### Essential Reading
- [Main README](README.md) - Complete feature overview
- [CLAUDE.md](CLAUDE.md) - Development workflow and commands
- [Language Support Guide](.serena/memories/adding_new_language_support_guide.md)

### Configuration
- **Global config**: `%USERPROFILE%\.serena\serena_config.yml`
- **Project config**: `<project>\.serena\project.yml`
- **Contexts & Modes**: Customize behavior for different workflows

### Advanced Usage
- **Memory System**: Persistent project knowledge in `.serena/memories/`
- **Dashboard**: Web UI at `http://localhost:24282/dashboard/index.html`
- **Custom Contexts**: Create your own workflow configurations

## 🔧 For Developers

### Contributing to Serena

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/yourusername/serena.git
   cd serena
   ```

2. **Development Setup**:
   ```bash
   uv venv --python 3.11
   .venv\Scripts\activate
   uv pip install -e ".[dev]"
   ```

3. **Essential Commands**:
   ```bash
   uv run poe format      # Format code (BLACK + RUFF)
   uv run poe type-check  # Run mypy type checking
   uv run poe test        # Run tests
   uv run poe lint        # Check code style
   ```

4. **Testing Your Changes**:
   ```bash
   # Test specific language support
   uv run poe test -m "python or typescript"
   
   # Run Windows-specific tests
   uv run poe test -m "windows"
   ```

5. **Building Portable Version**:
   ```bash
   # Test local build
   uv run serena build-portable --bundle-tier minimal --test-only
   
   # Full build
   uv run serena build-portable --bundle-tier essential
   ```

### Adding New Language Support

1. Create language server adapter in `src/solidlsp/language_servers/`
2. Add to Language enum in `src/solidlsp/ls_config.py`
3. Update factory in `src/solidlsp/ls.py`
4. Add test repository in `test/resources/repos/<language>/`
5. Create test suite in `test/solidlsp/<language>/`
6. Update Windows portable workflow to include language server downloads

### Code Style Guidelines

- **Type Hints**: Required for all new code
- **Documentation**: Add docstrings for public APIs
- **Testing**: Include tests for new features
- **Formatting**: Use `uv run poe format` before committing

## 📞 Support & Community

- **Issues**: [GitHub Issues](https://github.com/oraios/serena/issues)
- **Discussions**: [GitHub Discussions](https://github.com/oraios/serena/discussions)
- **Documentation**: [Complete docs in README.md](README.md)

## 🚀 Ready to Start?

1. **Download** the essential bundle from releases
2. **Extract** and run the installer
3. **Configure** your preferred AI client (Claude Code/Desktop)
4. **Activate** your first project: "Activate project C:\path\to\your\code"
5. **Start coding** with enhanced AI assistance!

---

*Built with ❤️ by the Oraios AI team. Serena is open-source and free to use!*