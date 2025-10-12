================================================================================
  SERENA MCP PORTABLE - WINDOWS QUICK START GUIDE
================================================================================

WHAT IS SERENA MCP PORTABLE?

Serena is a powerful coding agent toolkit that works directly with your
codebase. It provides IDE-like tools for AI assistants (like Claude Code and
Claude Desktop) to understand and edit code using symbols and language
structure, not just text.

The Portable version runs on Windows without installation, system-wide
configuration, or admin rights. Everything you need is included in one
self-contained package.


SYSTEM REQUIREMENTS

- Windows 10 (version 1809+) or Windows 11
- Architecture: x64 (64-bit Intel/AMD) or ARM64 (Windows on ARM)
- Memory: 4GB RAM recommended (2GB minimum)
- Storage: 50MB-800MB depending on bundle tier
- Optional: Internet for language server downloads (if not pre-bundled)


QUICK START (3 STEPS)

Step 1: EXTRACT
   Extract the ZIP file to any folder you prefer:
   - Desktop: C:\Users\YourName\Desktop\serena-portable
   - Documents: C:\Users\YourName\Documents\serena-portable
   - USB Drive: E:\serena-portable
   - Network Share: \\server\tools\serena-portable

Step 2: RUN FIRST-RUN.BAT
   Double-click first-run.bat in the extracted folder.
   This will:
   - Add Serena to your PATH (for Command Prompt)
   - Test the installation
   - Create necessary configuration files

   If you see a "Windows protected your PC" warning:
   - Click "More info"
   - Click "Run anyway"

   Or right-click first-run.bat and select "Run as administrator"

Step 3: TEST
   Open a NEW Command Prompt or PowerShell window and type:

   serena --version

   You should see version information. Now you're ready to use Serena!


HOW TO USE WITH CLAUDE CODE

From your project directory in Command Prompt:

   claude mcp add serena -- serena start-mcp-server --context ide-assistant --project %cd%

Then in Claude Code, say: "Read Serena's initial instructions"


HOW TO USE WITH CLAUDE DESKTOP

1. Open Claude Desktop
2. Go to: File > Settings > Developer > MCP Servers > Edit Config
3. Add this to the JSON file:

{
    "mcpServers": {
        "serena": {
            "command": "serena",
            "args": ["start-mcp-server", "--context", "desktop-app"]
        }
    }
}

4. Save and restart Claude Desktop
5. In a new chat, say: "Activate the project C:\path\to\your\code"


BUNDLE TIERS EXPLAINED

Choose what was included in your download:

MINIMAL (~50MB)
  - Core Serena features only
  - No language servers included
  - Best for: Testing or custom setups

ESSENTIAL (~200MB) - RECOMMENDED
  - Language servers: Python, TypeScript/JavaScript, Rust, Go
  - Best for: Most developers and common languages

COMPLETE (~500MB)
  - Essential + Java, C#, Lua, Bash
  - Best for: Full-stack and enterprise development

FULL (~800MB)
  - All 24+ supported language servers
  - Best for: Multi-language projects and enterprises


WHERE FILES ARE STORED

User data and configuration:
  %USERPROFILE%\.serena\
  (Example: C:\Users\YourName\.serena\)

Logs:
  %USERPROFILE%\.serena\logs\

Project-specific settings:
  YourProject\.serena\


TROUBLESHOOTING TOP 3 ISSUES

Issue 1: "serena: command not found"
Solution: Close and reopen your terminal after installation.
          Or run first-run.bat again to add to PATH.

Issue 2: Windows SmartScreen warning when running
Solution: Click "More info" then "Run anyway"
          Or right-click and "Run as administrator"

Issue 3: Antivirus blocking serena.exe
Solution: Add exception in your antivirus software:
          - Windows Defender: Settings > Virus & threat protection >
            Manage settings > Exclusions > Add exclusion
          - Add the serena-portable folder


IMPORTANT TIP FOR GIT USERS

To avoid line ending issues on Windows, configure git:

   git config --global core.autocrlf true


WHERE TO GET HELP

For detailed guides, see these files in the installation:
- WINDOWS-QUICKSTART.md - Detailed setup and usage
- WINDOWS-TROUBLESHOOTING.md - Common problems and solutions
- WINDOWS-INTEGRATION.md - IDE and tool integration

Online Resources:
- GitHub: https://github.com/oraios/serena
- Issues: https://github.com/oraios/serena/issues
- Full README: See README.md in the installation folder


NEXT STEPS

1. Test with your first project:
   serena project activate C:\path\to\your\project

2. Index large projects for better performance:
   serena project index C:\path\to\your\project

3. Configure your preferred AI client (Claude Code or Claude Desktop)

4. Read WINDOWS-QUICKSTART.md for detailed usage examples


SYSTEM PATHS QUICK REFERENCE

Installation: Where you extracted Serena
User Config: %USERPROFILE%\.serena\serena_config.yml
Logs: %USERPROFILE%\.serena\logs\
Project Config: YourProject\.serena\project.yml


LICENSE

Serena is free and open-source software. See LICENSE file for details.


CREDITS

Built with love by Oraios AI
https://oraios-ai.de/


================================================================================
  Thank you for using Serena MCP Portable!
  Version: 1.0 | Platform: Windows 10/11 (x64/ARM64)
  Last Updated: 2025-01-16
================================================================================
