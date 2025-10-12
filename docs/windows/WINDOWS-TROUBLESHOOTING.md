# Serena MCP Portable - Windows Troubleshooting Guide

Comprehensive troubleshooting for common Windows issues.

## Table of Contents

- [Installation Issues](#installation-issues)
- [SmartScreen and Security Warnings](#smartscreen-and-security-warnings)
- [Antivirus False Positives](#antivirus-false-positives)
- [Permission Errors](#permission-errors)
- [Missing DLLs and Runtime Errors](#missing-dlls-and-runtime-errors)
- [Language Server Issues](#language-server-issues)
- [Port Conflicts](#port-conflicts)
- [Path and Environment Issues](#path-and-environment-issues)
- [Runtime Conflicts](#runtime-conflicts)
- [Firewall Issues](#firewall-issues)
- [Performance Issues](#performance-issues)
- [Logs and Diagnostics](#logs-and-diagnostics)
- [Decision Trees](#decision-trees)

## Installation Issues

### Issue: "Cannot find serena.exe"

**Symptoms:**
- `first-run.bat` reports "serena.exe not found"
- Double-clicking `serena.exe` does nothing

**Causes:**
- Incomplete extraction from ZIP
- Antivirus quarantined the file
- Corrupted download

**Solutions:**

1. **Check if file exists:**
   ```cmd
   dir serena.exe
   ```

2. **Re-extract the ZIP file:**
   - Delete the extracted folder
   - Re-download the ZIP if needed
   - Extract again, ensuring "Extract All" completes

3. **Check antivirus quarantine:**
   - Open Windows Security
   - Go to "Virus & threat protection"
   - Click "Protection history"
   - Look for `serena.exe` in quarantine
   - Restore and allow

4. **Verify download integrity:**
   - Check file size matches the release notes
   - Download from official GitHub releases only

### Issue: "Extraction Failed" or "Corrupted Archive"

**Symptoms:**
- ZIP extraction stops with error
- "The compressed (zipped) folder is invalid"

**Solutions:**

1. **Re-download the file:**
   - Clear browser cache
   - Download again from official source
   - Use a different browser if issue persists

2. **Use a different extraction tool:**
   - Windows built-in: Right-click > "Extract All"
   - 7-Zip: https://www.7-zip.org/
   - WinRAR: https://www.win-rar.com/

3. **Check disk space:**
   ```cmd
   wmic logicaldisk get caption,freespace,size
   ```
   Ensure you have enough free space (at least 2x the ZIP size)

### Issue: Installation to Program Files Fails

**Symptoms:**
- Access denied errors
- "You need permission to perform this action"

**Cause:**
`C:\Program Files` requires administrator rights

**Solution:**

**DO NOT** install to `C:\Program Files` or `C:\Program Files (x86)`

**Install to user directory instead:**
- `C:\Users\YourName\Documents\serena-portable`
- `C:\Users\YourName\AppData\Local\serena-portable`
- Any location in your user profile

**If you must use a system location:**
1. Right-click `first-run.bat`
2. Select "Run as administrator"
3. Approve UAC prompt

## SmartScreen and Security Warnings

### Issue: "Windows protected your PC" SmartScreen Warning

**Symptoms:**

When running `first-run.bat` or `serena.exe`, you see:

```
Windows protected your PC
Microsoft Defender SmartScreen prevented an unrecognized app from starting.
Running this app might put your PC at risk.
```

**Why this happens:**

Windows SmartScreen blocks unsigned executables from unknown publishers. Serena is open-source and not code-signed (code signing certificates cost $200-500/year).

**This is a FALSE POSITIVE. Serena is safe.**

**Solutions:**

**Option 1: Click through SmartScreen (Recommended)**

1. Click "More info"
2. Click "Run anyway" button that appears
3. Approve any UAC prompt if requested

**Option 2: Run as Administrator**

1. Right-click `first-run.bat` or `serena.exe`
2. Select "Run as administrator"
3. Approve UAC prompt

**Option 3: Disable SmartScreen (Not Recommended)**

Only for advanced users who understand the security implications:

1. Press `Win + R`
2. Type `ms-settings:windowsdefender`
3. Go to "App & browser control"
4. Under "Check apps and files", select "Warn" or "Off"

**Re-enable after installation!**

**Option 4: Add to SmartScreen Whitelist**

Using Group Policy (Windows Pro/Enterprise):

1. Press `Win + R`, type `gpedit.msc`
2. Navigate to: Computer Configuration > Administrative Templates > Windows Components > File Explorer
3. Enable "Configure Windows Defender SmartScreen"
4. Set to "Warn"

### Issue: "This app can't run on your PC"

**Symptoms:**
- Dialog says app is incompatible with Windows version
- Message about ARM64 vs x64 architecture

**Causes:**
- Downloaded wrong architecture (x64 vs ARM64)
- Corrupted executable

**Solutions:**

1. **Check your Windows architecture:**
   ```cmd
   echo %PROCESSOR_ARCHITECTURE%
   ```
   - `AMD64` or `x86_64` = Need x64 build
   - `ARM64` = Need ARM64 build

2. **Download correct version:**
   - x64: `serena-windows-x64-*.zip`
   - ARM64: `serena-windows-arm64-*.zip`

3. **Check Windows version:**
   ```cmd
   winver
   ```
   Serena requires Windows 10 version 1809 or later

## Antivirus False Positives

### Issue: Antivirus Blocks or Quarantines serena.exe

**Symptoms:**
- Installation completes but `serena.exe` missing
- Antivirus alert about "suspicious behavior"
- "Access denied" when running Serena

**Why this happens:**

PyInstaller-packaged executables are often flagged as suspicious because:
- They unpack Python runtime at startup
- They create temporary files
- Malware authors sometimes use PyInstaller

**This is a FALSE POSITIVE. Serena is open-source and safe.**

**Solutions:**

### Windows Defender

1. **Add Exclusion:**
   - Open Windows Security
   - Go to "Virus & threat protection"
   - Click "Manage settings"
   - Under "Exclusions", click "Add or remove exclusions"
   - Click "Add an exclusion" > "Folder"
   - Select the serena-portable folder

2. **Restore from Quarantine:**
   - Windows Security > "Virus & threat protection"
   - Click "Protection history"
   - Find `serena.exe`
   - Click "Actions" > "Restore"
   - Click "Actions" > "Allow on device"

### Third-Party Antivirus Software

**Norton, McAfee, Kaspersky, Avast, AVG, Bitdefender:**

Each has similar steps:

1. Open antivirus application
2. Go to Settings/Options
3. Find "Exclusions" or "Exceptions"
4. Add folder or file exclusion for serena-portable directory
5. Restore file from quarantine if already blocked

**Specific Instructions:**

**Norton:**
- Settings > Antivirus > Scans and Risks > Exclusions > Configure
- Add the serena-portable folder

**McAfee:**
- Settings > Real-Time Scanning > Excluded Files
- Add the serena-portable folder

**Kaspersky:**
- Settings > Additional > Threats and Exclusions > Exclusions
- Add the serena-portable folder

**Avast/AVG:**
- Settings > General > Exclusions
- Add the serena-portable folder

**Bitdefender:**
- Settings > Antivirus > Advanced > Manage exceptions
- Add the serena-portable folder

### Corporate/Enterprise Antivirus

**Symptoms:**
- Exclusions are grayed out
- Cannot modify security settings
- Managed by IT policy

**Solution:**

Contact your IT department and request:

```
Please add an exclusion for the Serena MCP Portable toolkit:

Folder: C:\Users\[username]\Documents\serena-portable
Executable: serena.exe
Reason: Development tool, open-source, required for work
GitHub: https://github.com/oraios/serena
```

Provide them with:
- This documentation
- Link to Serena's GitHub repository
- Explanation of business need

## Permission Errors

### Issue: "Access is denied" Errors

**Symptoms:**
```
Error: Access is denied
Cannot write to C:\...
Permission denied
```

**Causes:**
- Installing to protected directory
- User lacks write permissions
- File/folder is read-only
- Locked by another process

**Solutions:**

1. **Check installation location:**
   - Move to user directory: `C:\Users\YourName\Documents\serena-portable`
   - Avoid: `C:\Program Files`, `C:\Windows`, system root

2. **Check folder permissions:**
   ```cmd
   icacls "serena-portable"
   ```
   Should show `(F)` (Full control) for your user

   Fix permissions:
   ```cmd
   icacls "serena-portable" /grant %USERNAME%:F /T
   ```

3. **Remove read-only attribute:**
   ```cmd
   attrib -r "serena-portable\*.*" /s /d
   ```

4. **Check for file locks:**
   ```cmd
   openfiles /query | findstr serena
   ```

   Or use [Process Explorer](https://docs.microsoft.com/sysinternals/downloads/process-explorer) to find locking processes

5. **Run as administrator (last resort):**
   - Right-click `first-run.bat`
   - "Run as administrator"
   - Approve UAC prompt

### Issue: Cannot Create Files in .serena Directory

**Symptoms:**
```
Error: Cannot create directory %USERPROFILE%\.serena
Permission denied writing to C:\Users\YourName\.serena
```

**Solutions:**

1. **Check user profile permissions:**
   ```cmd
   icacls "%USERPROFILE%"
   ```

2. **Create directory manually:**
   ```cmd
   mkdir "%USERPROFILE%\.serena"
   mkdir "%USERPROFILE%\.serena\logs"
   mkdir "%USERPROFILE%\.serena\language_servers"
   ```

3. **Use alternative location:**
   Set environment variable:
   ```cmd
   set SERENA_HOME=C:\Users\%USERNAME%\Documents\.serena
   ```

   Make permanent:
   ```cmd
   setx SERENA_HOME "C:\Users\%USERNAME%\Documents\.serena"
   ```

## Missing DLLs and Runtime Errors

### Issue: "VCRUNTIME140.dll was not found"

**Symptoms:**
```
The code execution cannot proceed because VCRUNTIME140.dll was not found.
```

**Cause:**
Missing Microsoft Visual C++ Redistributable

**Solution:**

**Install Visual C++ Redistributables:**

1. **Automatic (Recommended):**
   ```cmd
   winget install Microsoft.VCRedist.2015+.x64
   ```

2. **Manual Download:**
   - Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
   - Run installer
   - Restart computer

3. **For ARM64 Windows:**
   ```cmd
   winget install Microsoft.VCRedist.2015+.x64
   winget install Microsoft.VCRedist.2015+.arm64
   ```
   (Both needed for x64 emulation)

### Issue: "MSVCP140.dll is missing"

**Same as VCRUNTIME140.dll** - install Visual C++ Redistributable

### Issue: "Python39.dll not found" or Similar

**Cause:**
Corrupted PyInstaller bundle or incomplete extraction

**Solutions:**

1. **Re-extract the ZIP:**
   - Delete existing folder
   - Extract fresh copy from ZIP

2. **Re-download if issue persists:**
   - Download from official GitHub releases
   - Verify file size

3. **Check for antivirus interference:**
   - Temporarily disable antivirus
   - Extract and add exclusion
   - Re-enable antivirus

### Issue: "Application failed to initialize properly (0xc0000142)"

**Causes:**
- Corrupted system files
- Incompatible Windows version
- Missing system updates

**Solutions:**

1. **Run System File Checker:**
   ```cmd
   sfc /scannow
   ```
   (Requires administrator)

2. **Install Windows Updates:**
   - Settings > Update & Security > Windows Update
   - Install all available updates
   - Restart

3. **Run DISM:**
   ```cmd
   DISM /Online /Cleanup-Image /RestoreHealth
   ```
   (Requires administrator and internet)

## Language Server Issues

### Issue: Language Server Not Starting

**Symptoms:**
- Tool calls fail with "Language server not available"
- Logs show "Failed to start language server"
- Timeout errors

**Solutions:**

### Check Language Server Logs

```cmd
type "%USERPROFILE%\.serena\logs\lsp\python.log"
type "%USERPROFILE%\.serena\logs\lsp\typescript.log"
```

### Common Causes and Fixes

**1. Missing Runtime Dependencies:**

| Language | Required Runtime | Install Command |
|----------|-----------------|-----------------|
| TypeScript/JavaScript | Node.js 20+ | `winget install OpenJS.NodeJS` |
| Java | Java 17+ | `winget install Microsoft.OpenJDK.17` |
| Kotlin | Java 17+ | Same as Java |
| C# | .NET 8.0+ | `winget install Microsoft.DotNet.SDK.8` |
| Ruby | Ruby 3+ | Download from https://rubyinstaller.org/ |
| Go | (Optional) | `winget install GoLang.Go` |
| Rust | (Optional) | Download from https://rustup.rs/ |

**2. Language Server Not Downloaded:**

```cmd
# Check what's installed
dir "%USERPROFILE%\.serena\language_servers"

# Force re-download (if Serena supports it)
serena install-language-servers --force
```

**3. Port Already in Use:**

Each language server may use ports. Check:
```cmd
netstat -ano | findstr LISTENING
```

**4. Firewall Blocking Local Connections:**

Add firewall rule:
```cmd
netsh advfirewall firewall add rule name="Serena LSP" dir=in action=allow program="%USERPROFILE%\Documents\serena-portable\serena.exe" enable=yes
```

### Issue: Python Language Server Fails

**Specific Solutions:**

1. **Check Pyright installation:**
   ```cmd
   where pyright
   ```

2. **Check Node.js (Pyright requires it):**
   ```cmd
   node --version
   ```
   Should show v20 or later

3. **Reinstall Pyright:**
   ```cmd
   npm install -g pyright
   ```

### Issue: TypeScript Language Server Fails

**Specific Solutions:**

1. **Check typescript-language-server:**
   ```cmd
   npx typescript-language-server --version
   ```

2. **Reinstall:**
   ```cmd
   npm install -g typescript-language-server typescript
   ```

### Issue: Java Language Server Extremely Slow

**Cause:**
Eclipse JDT.LS requires significant memory and initialization time

**Solutions:**

1. **Increase Java heap size:**
   Set environment variable:
   ```cmd
   set JAVA_TOOL_OPTIONS=-Xmx2048m
   ```

2. **Pre-index projects:**
   First startup is always slow. Subsequent starts are faster.

3. **Use SSD storage:**
   Move projects to SSD if on HDD

4. **Wait longer:**
   Initial startup can take 30-60 seconds

## Port Conflicts

### Issue: "Port already in use" Error

**Symptoms:**
```
Error: Address already in use: 127.0.0.1:24282
Cannot bind to port 24282
```

**Cause:**
Another application or Serena instance using the same port

**Solutions:**

### Check What's Using the Port

```cmd
netstat -ano | findstr :24282
```

Output shows:
```
TCP    127.0.0.1:24282    0.0.0.0:0    LISTENING    12345
```

The last number (12345) is the Process ID (PID)

Find the process:
```cmd
tasklist | findstr 12345
```

### Option 1: Stop the Conflicting Process

```cmd
taskkill /PID 12345 /F
```

### Option 2: Use a Different Port

```cmd
serena start-mcp-server --port 24283
```

Or set environment variable:
```cmd
set SERENA_PORT=24283
serena start-mcp-server
```

### Option 3: Close Previous Serena Instances

```cmd
taskkill /IM serena.exe /F
```

### Common Port Conflicts

| Port | Common User | Solution |
|------|-------------|----------|
| 24282 | Serena default | Use --port flag |
| 8000 | Other web servers | Check IIS, Apache, Python SimpleHTTPServer |
| 3000 | Node.js development | Check npm/node processes |
| 5000 | Flask/ASP.NET | Check Python/dotnet processes |

## Path and Environment Issues

### Issue: "serena: command not found" After Installation

**Symptoms:**
```
'serena' is not recognized as an internal or external command,
operable program or batch file.
```

**Causes:**
- PATH not updated
- Terminal not restarted
- Installation directory not in PATH

**Solutions:**

### Solution 1: Restart Terminal

**Most common fix:**
1. Close **all** Command Prompt and PowerShell windows
2. Open a **NEW** window
3. Try again: `serena --version`

### Solution 2: Check PATH

```cmd
echo %PATH%
```

Look for serena-portable directory in the output.

If missing, add manually:

### Solution 3: Add to PATH (User Level)

```cmd
# Temporary (current session only)
set PATH=%PATH%;C:\Users\%USERNAME%\Documents\serena-portable

# Permanent (using setx)
setx PATH "%PATH%;C:\Users\%USERNAME%\Documents\serena-portable"
```

**Or use GUI:**
1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Click "Environment Variables"
3. Under "User variables", select "Path", click "Edit"
4. Click "New"
5. Add: `C:\Users\YourName\Documents\serena-portable`
6. Click "OK" on all dialogs
7. Close and reopen terminal

### Solution 4: Use Full Path

```cmd
C:\Users\%USERNAME%\Documents\serena-portable\serena.exe --version
```

### Solution 5: Run from Installation Directory

```cmd
cd C:\Users\%USERNAME%\Documents\serena-portable
serena --version
```

### Issue: Environment Variables Not Persisting

**Symptoms:**
- `set VARIABLE=value` works in current session
- But disappears after closing terminal

**Cause:**
`set` command is temporary

**Solution:**

**Use `setx` for permanent variables:**
```cmd
setx SERENA_LOG_LEVEL DEBUG
```

**Or use PowerShell:**
```powershell
[Environment]::SetEnvironmentVariable("SERENA_LOG_LEVEL", "DEBUG", "User")
```

**Or use GUI:**
1. `Win + R` > `sysdm.cpl`
2. "Environment Variables"
3. Under "User variables", click "New"
4. Add variable name and value

## Runtime Conflicts

### Issue: Node.js Version Conflict

**Symptoms:**
- Language servers fail with Node.js errors
- "Unsupported Node.js version"

**Cause:**
Multiple Node.js versions installed or too old version

**Solutions:**

1. **Check Node.js version:**
   ```cmd
   node --version
   ```
   Should be v20 or later

2. **Update Node.js:**
   ```cmd
   winget upgrade OpenJS.NodeJS
   ```

3. **Use nvm-windows (for multiple versions):**
   - Download from: https://github.com/coreybutler/nvm-windows
   - Install and use:
   ```cmd
   nvm install 20
   nvm use 20
   ```

### Issue: Python Version Conflict

**Symptoms:**
- Multiple Python versions causing confusion
- `python` command opens wrong version

**Solutions:**

1. **Check Python versions:**
   ```cmd
   where python
   ```

2. **Use py launcher:**
   ```cmd
   py -3.11 --version
   ```

3. **Modify PATH order:**
   - Open "Environment Variables"
   - In "Path", move desired Python to top

### Issue: Java Version Conflict

**Symptoms:**
- Wrong Java version used
- "Unsupported class file version"

**Solutions:**

1. **Check Java version:**
   ```cmd
   java -version
   ```

2. **Set JAVA_HOME:**
   ```cmd
   setx JAVA_HOME "C:\Program Files\Java\jdk-17"
   setx PATH "%JAVA_HOME%\bin;%PATH%"
   ```

3. **Use specific Java:**
   ```cmd
   "C:\Program Files\Java\jdk-17\bin\java.exe" -version
   ```

## Firewall Issues

### Issue: Windows Firewall Blocking Serena

**Symptoms:**
- Connection timeouts
- "Unable to connect to MCP server"
- Firewall prompts appearing

**Solutions:**

### Allow Through Firewall (GUI)

1. Open Windows Security
2. Go to "Firewall & network protection"
3. Click "Allow an app through firewall"
4. Click "Change settings"
5. Click "Allow another app"
6. Browse to `serena.exe`
7. Check "Private" and "Public" (or just "Private")
8. Click "Add"

### Allow Through Firewall (Command Line)

```cmd
netsh advfirewall firewall add rule name="Serena MCP" dir=in action=allow program="%USERPROFILE%\Documents\serena-portable\serena.exe" enable=yes
```

### Check Firewall Rules

```cmd
netsh advfirewall firewall show rule name=all | findstr Serena
```

### Corporate Firewall

**Issue:**
Managed firewall blocks local connections

**Solutions:**

1. **Request IT exception** for:
   - Application: serena.exe
   - Ports: 24282 (default), 8000-9000 range
   - Direction: Inbound
   - Scope: Local subnet only

2. **Use alternative ports** if some are allowed

3. **Use stdio transport** instead of HTTP:
   ```cmd
   serena start-mcp-server --transport stdio
   ```
   (No network ports needed)

## Performance Issues

### Issue: Slow Language Server Startup

**Symptoms:**
- First project activation takes minutes
- Tools timeout
- High CPU usage during startup

**Causes:**
- Large project size
- First-time indexing
- Slow storage (HDD)
- Insufficient RAM

**Solutions:**

1. **Pre-index projects:**
   ```cmd
   serena project index "C:\path\to\project" --timeout 300
   ```

2. **Use SSD storage:**
   - Move projects to SSD
   - Set temp directory to SSD:
   ```cmd
   set TEMP=D:\SSD\temp
   set TMP=D:\SSD\temp
   ```

3. **Increase timeout:**
   ```cmd
   set SERENA_LSP_TIMEOUT=120
   ```

4. **Close other applications** to free RAM

5. **Exclude from antivirus scanning:**
   - Add project directory to antivirus exclusions
   - Especially important for large codebases

### Issue: High Memory Usage

**Symptoms:**
- Serena using >2GB RAM
- System slows down
- Out of memory errors

**Solutions:**

1. **Check language servers:**
   ```cmd
   tasklist | findstr serena
   tasklist | findstr java
   tasklist | findstr node
   ```

2. **Limit concurrent language servers:**
   Edit config:
   ```yaml
   max_concurrent_ls: 2
   ```

3. **Close unused language servers:**
   - Only activate projects you're working on
   - Restart Serena to clear memory

4. **Increase system RAM** or **close other applications**

### Issue: Slow File Operations

**Symptoms:**
- File searches take long time
- Symbol lookups are slow

**Solutions:**

1. **Exclude unnecessary files:**
   Edit project `.serena\project.yml`:
   ```yaml
   exclude_patterns:
     - "**/node_modules/**"
     - "**/__pycache__/**"
     - "**/venv/**"
     - "**/vendor/**"
     - "**/*.min.js"
     - "**/build/**"
     - "**/dist/**"
   ```

2. **Index the project:**
   ```cmd
   serena project index "C:\path\to\project"
   ```

3. **Use SSD storage**

4. **Reduce max_file_size** in project config:
   ```yaml
   indexing:
     max_file_size: 500000  # 500KB instead of 1MB
   ```

## Logs and Diagnostics

### Log File Locations

```
%USERPROFILE%\.serena\logs\
├── mcp_server.log              # Main MCP server log
├── agent.log                   # Agent operations log
├── lsp\                        # Language server logs
│   ├── python.log
│   ├── typescript.log
│   ├── java.log
│   └── ...
├── tools\                      # Tool execution logs
│   ├── find_symbol.log
│   └── ...
└── indexing.log               # Project indexing logs
```

### Viewing Logs

**Command Prompt:**
```cmd
type "%USERPROFILE%\.serena\logs\mcp_server.log"
type "%USERPROFILE%\.serena\logs\lsp\python.log"
```

**PowerShell (with filtering):**
```powershell
Get-Content "$env:USERPROFILE\.serena\logs\mcp_server.log" | Select-String "ERROR"
Get-Content "$env:USERPROFILE\.serena\logs\lsp\python.log" -Tail 50
```

**Real-time monitoring:**
```cmd
powershell -c "Get-Content '%USERPROFILE%\.serena\logs\mcp_server.log' -Wait"
```

### Enable Debug Logging

**Temporary (current session):**
```cmd
set SERENA_LOG_LEVEL=DEBUG
serena start-mcp-server --log-level DEBUG
```

**Permanent:**
Edit `%USERPROFILE%\.serena\serena_config.yml`:
```yaml
log_level: DEBUG
log_lsp_communication: true
```

### Generate Diagnostic Report

```cmd
# System information
systeminfo > serena-diag.txt

# Serena version
serena --version >> serena-diag.txt

# Environment variables
set | findstr SERENA >> serena-diag.txt

# Recent errors
type "%USERPROFILE%\.serena\logs\mcp_server.log" | findstr ERROR >> serena-diag.txt

# Port usage
netstat -ano | findstr LISTENING >> serena-diag.txt
```

### Web Dashboard

Access logs via web interface:
```
http://localhost:24282/dashboard/index.html
```

Features:
- Real-time log viewing
- Tool usage statistics
- Language server status
- Ability to shut down Serena

## Decision Trees

### "Serena Won't Start" Decision Tree

```
Serena won't start
├─ Does serena.exe exist?
│  ├─ NO → Re-extract ZIP or check antivirus quarantine
│  └─ YES → Continue
│
├─ Does double-clicking serena.exe show SmartScreen warning?
│  ├─ YES → Click "More info" > "Run anyway"
│  └─ NO → Continue
│
├─ Does running serena.exe show any error?
│  ├─ "VCRUNTIME140.dll missing" → Install Visual C++ Redistributable
│  ├─ "Application failed to initialize" → Run SFC /scannow, install Windows updates
│  ├─ "Access denied" → Move to user directory, check permissions
│  └─ No error but nothing happens → Check Task Manager for process, check antivirus
│
└─ Does `serena --version` work from Command Prompt?
   ├─ NO "command not found" → Add to PATH, restart terminal
   └─ YES → Serena is working!
```

### "Language Server Won't Start" Decision Tree

```
Language server won't start
├─ Check logs: %USERPROFILE%\.serena\logs\lsp\[language].log
│
├─ Are there errors about missing executables?
│  ├─ YES → Install required runtime (Node.js, Java, .NET, etc.)
│  └─ NO → Continue
│
├─ Are there timeout errors?
│  ├─ YES → Increase timeout, check system resources
│  └─ NO → Continue
│
├─ Are there port conflict errors?
│  ├─ YES → Use different port, kill conflicting process
│  └─ NO → Continue
│
├─ Are there permission errors?
│  ├─ YES → Check firewall, check folder permissions
│  └─ NO → Continue
│
└─ Try restart language server via Claude/tool
   └─ If still fails → Report issue with full logs
```

### "Can't Activate Project" Decision Tree

```
Can't activate project
├─ Does project directory exist?
│  ├─ NO → Check path, use absolute path
│  └─ YES → Continue
│
├─ Does user have read access to directory?
│  ├─ NO → Check permissions (icacls)
│  └─ YES → Continue
│
├─ Is directory a valid project (contains code files)?
│  ├─ NO → Serena needs actual code files
│  └─ YES → Continue
│
├─ Does .serena\project.yml get created?
│  ├─ NO → Check write permissions
│  └─ YES → Continue
│
├─ Are there errors in mcp_server.log?
│  ├─ Language server errors → Fix language server first
│  ├─ Permission errors → Fix permissions
│  └─ Timeout errors → Increase timeout for large projects
│
└─ Try: serena project generate-yml "path"
   └─ If still fails → Check detailed logs
```

---

## Getting Further Help

If you've tried these solutions and still have issues:

1. **Check GitHub Issues:**
   https://github.com/oraios/serena/issues
   - Search for similar problems
   - Check closed issues for solutions

2. **Gather Information:**
   - Serena version: `serena --version`
   - Windows version: `winver`
   - Error messages (full text)
   - Relevant logs from `%USERPROFILE%\.serena\logs\`

3. **Report Issue:**
   - Create new GitHub issue
   - Include system information
   - Include error messages and logs
   - Describe steps to reproduce

4. **Community Help:**
   - GitHub Discussions: https://github.com/oraios/serena/discussions

---

**Serena MCP Portable - Windows Troubleshooting Guide**
Version: 1.0 | Last Updated: 2025-01-16
For updates: https://github.com/oraios/serena
