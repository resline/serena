# Integration Guide - Windows Launcher Scripts

This document describes how to integrate the Windows launcher scripts into the Serena portable build system.

## Overview

The Windows launcher scripts in this directory are designed to be included in the final portable distribution package. They provide a user-friendly interface to the PyInstaller-built executables.

## Build System Integration

### Step 1: Copy Scripts to Build Output

During the portable build process, copy all launcher scripts to the distribution directory:

**PowerShell (in build-portable.ps1):**
```powershell
# Copy launcher scripts
$LauncherScriptsDir = Join-Path $PROJECT_ROOT "scripts\windows-launchers"
$DistDir = Join-Path $BUILD_DIR "dist"

Write-Host "Copying launcher scripts..." -ForegroundColor Cyan
Copy-Item -Path "$LauncherScriptsDir\*.bat" -Destination $DistDir -Force
Copy-Item -Path "$LauncherScriptsDir\*.ps1" -Destination $DistDir -Force
Copy-Item -Path "$LauncherScriptsDir\README.md" -Destination $DistDir -Force
Copy-Item -Path "$LauncherScriptsDir\USAGE.md" -Destination $DistDir -Force
```

**Bash (in build-portable.sh):**
```bash
# Copy launcher scripts
LAUNCHER_SCRIPTS_DIR="$PROJECT_ROOT/scripts/windows-launchers"
DIST_DIR="$BUILD_DIR/dist"

echo "Copying launcher scripts..."
cp "$LAUNCHER_SCRIPTS_DIR"/*.bat "$DIST_DIR/"
cp "$LAUNCHER_SCRIPTS_DIR"/*.ps1 "$DIST_DIR/"
cp "$LAUNCHER_SCRIPTS_DIR"/README.md "$DIST_DIR/"
cp "$LAUNCHER_SCRIPTS_DIR"/USAGE.md "$DIST_DIR/"
```

### Step 2: Package Structure

Ensure the final package has this structure:

```
SerenaPortable-v0.1.4-windows-x64/
├── serena.exe                      # From PyInstaller
├── serena-mcp-server.exe           # From PyInstaller
├── index-project.exe               # From PyInstaller
├── serena.bat                      # Launcher script
├── serena.ps1                      # Launcher script
├── serena-mcp-server.bat           # Launcher script
├── serena-mcp-server.ps1           # Launcher script
├── index-project.bat               # Launcher script
├── index-project.ps1               # Launcher script
├── first-run.bat                   # Setup script
├── first-run.ps1                   # Setup script
├── verify-installation.bat         # Verification script
├── verify-installation.ps1         # Verification script
├── README.md                       # User documentation
├── USAGE.md                        # Quick reference
├── _internal/                      # PyInstaller internals
│   └── serena/
│       └── resources/              # Default configs
├── language_servers/               # Language server directory (empty or pre-populated)
└── runtimes/                       # Optional bundled runtimes
    ├── nodejs/
    ├── dotnet/
    └── java/
```

### Step 3: Update Build Script

Modify your existing build script to include launcher scripts:

**Example: scripts/build-windows/build-portable.ps1**

```powershell
# ... existing build code ...

# After PyInstaller build completes
Write-Host ""
Write-Host "=== Installing Launcher Scripts ===" -ForegroundColor Cyan

$LauncherScriptsDir = Join-Path $PROJECT_ROOT "scripts\windows-launchers"
$DistDir = "dist"  # PyInstaller output directory

# Copy launcher scripts
$LauncherFiles = @(
    "serena.bat",
    "serena.ps1",
    "serena-mcp-server.bat",
    "serena-mcp-server.ps1",
    "index-project.bat",
    "index-project.ps1",
    "first-run.bat",
    "first-run.ps1",
    "verify-installation.bat",
    "verify-installation.ps1",
    "README.md",
    "USAGE.md"
)

foreach ($File in $LauncherFiles) {
    $SourcePath = Join-Path $LauncherScriptsDir $File
    $DestPath = Join-Path $DistDir $File

    if (Test-Path $SourcePath) {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Host "  Copied: $File" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: $File not found" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Launcher Scripts Installed ===" -ForegroundColor Green
```

### Step 4: ZIP Package Creation

When creating the final ZIP package, ensure launcher scripts are at the root level:

```powershell
# Create ZIP package
$ZipFileName = "SerenaPortable-v$SERENA_VERSION-windows-x64.zip"
$ZipPath = Join-Path $BUILD_DIR $ZipFileName

Write-Host "Creating ZIP package: $ZipFileName" -ForegroundColor Cyan

# Use 7zip or Compress-Archive
Compress-Archive -Path "$DistDir\*" -DestinationPath $ZipPath -Force

Write-Host "Package created: $ZipPath" -ForegroundColor Green
```

## Testing Integration

### Automated Testing

Add these tests to your CI/CD pipeline:

```powershell
# Test 1: Verify all launcher scripts are present
Write-Host "Testing launcher script presence..." -ForegroundColor Cyan

$RequiredScripts = @(
    "serena.bat", "serena.ps1",
    "serena-mcp-server.bat", "serena-mcp-server.ps1",
    "first-run.bat", "first-run.ps1",
    "verify-installation.bat", "verify-installation.ps1"
)

foreach ($Script in $RequiredScripts) {
    $ScriptPath = Join-Path $DistDir $Script
    if (Test-Path $ScriptPath) {
        Write-Host "  [PASS] $Script" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Script missing" -ForegroundColor Red
        exit 1
    }
}

# Test 2: Verify launcher scripts are executable
Write-Host "Testing launcher script executability..." -ForegroundColor Cyan

# Test batch script
$TestOutput = & "$DistDir\serena.bat" --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] serena.bat is functional" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] serena.bat returned error" -ForegroundColor Red
    exit 1
}

# Test PowerShell script
$TestOutput = & "$DistDir\serena.ps1" --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [PASS] serena.ps1 is functional" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] serena.ps1 returned error" -ForegroundColor Red
    exit 1
}

# Test 3: Run verification script
Write-Host "Running installation verification..." -ForegroundColor Cyan
& "$DistDir\verify-installation.ps1" -Verbose
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] Verification failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All integration tests passed!" -ForegroundColor Green
```

### Manual Testing

1. **Extract package to test directory:**
   ```powershell
   Expand-Archive -Path SerenaPortable-v0.1.4-windows-x64.zip -DestinationPath C:\Test\Serena
   cd C:\Test\Serena
   ```

2. **Run first-run script:**
   ```powershell
   .\first-run.ps1
   ```

3. **Test basic functionality:**
   ```powershell
   .\serena.ps1 --version
   .\serena.ps1 --help
   .\serena.ps1 tools list
   ```

4. **Run verification:**
   ```powershell
   .\verify-installation.ps1 -Verbose
   ```

5. **Test from different directory:**
   ```powershell
   cd C:\
   C:\Test\Serena\serena.ps1 --version
   ```

## GitHub Actions Integration

Add to your `.github/workflows/windows-portable.yml`:

```yaml
- name: Copy Launcher Scripts
  run: |
    Write-Host "Copying Windows launcher scripts..." -ForegroundColor Cyan
    $LauncherScriptsDir = "scripts/windows-launchers"
    $DistDir = "dist"

    Copy-Item -Path "$LauncherScriptsDir/*.bat" -Destination $DistDir -Force
    Copy-Item -Path "$LauncherScriptsDir/*.ps1" -Destination $DistDir -Force
    Copy-Item -Path "$LauncherScriptsDir/README.md" -Destination $DistDir -Force
    Copy-Item -Path "$LauncherScriptsDir/USAGE.md" -Destination $DistDir -Force
  shell: pwsh

- name: Test Launcher Scripts
  run: |
    Write-Host "Testing launcher scripts..." -ForegroundColor Cyan

    # Test basic functionality
    ./dist/serena.bat --version
    ./dist/serena.ps1 --version

    # Run verification
    ./dist/verify-installation.ps1 -Verbose
  shell: pwsh
```

## Version Management

When releasing a new version:

1. **Update version in launcher scripts** (if version is hardcoded anywhere)
2. **Update README.md** with new version number in examples
3. **Test all launchers** with the new executable versions
4. **Update CHANGELOG.md** to mention launcher script improvements

## Customization for Different Tiers

If you have multiple build tiers (minimal, essential, complete, full):

### Minimal Tier
- Include all launcher scripts
- No bundled runtimes
- Empty `language_servers/` directory

### Essential Tier
- Include all launcher scripts
- Bundle Node.js runtime only
- Pre-install Python and TypeScript language servers

### Complete Tier
- Include all launcher scripts
- Bundle Node.js and .NET runtimes
- Pre-install common language servers (Python, TypeScript, JavaScript, C#, Go)

### Full Tier
- Include all launcher scripts
- Bundle all runtimes (Node.js, .NET, Java)
- Pre-install all language servers

The launcher scripts automatically detect and use bundled runtimes regardless of tier.

## Troubleshooting Build Issues

### Issue: Launcher scripts not included in ZIP

**Solution:** Ensure `Copy-Item` commands run after PyInstaller and before ZIP creation.

### Issue: Scripts have Unix line endings

**Solution:** Convert to Windows line endings during build:
```powershell
Get-ChildItem -Path "$DistDir\*.bat" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace "`n", "`r`n"
    Set-Content $_.FullName -Value $content -NoNewline
}
```

### Issue: PowerShell scripts not executing

**Solution:** Check execution policy in README and include bypass instructions.

### Issue: Launcher can't find executable

**Solution:** Verify executables are at root level of `dist/` directory, not in subdirectories.

## Release Checklist

Before releasing a portable package:

- [ ] All launcher scripts copied to dist/
- [ ] README.md and USAGE.md included
- [ ] First-run script tested on clean Windows system
- [ ] Verification script passes all tests
- [ ] Launchers work from root directory
- [ ] Launchers work from subdirectory
- [ ] Launchers work from external directory (via PATH)
- [ ] All executables launch successfully
- [ ] Environment variables set correctly
- [ ] Bundled runtimes detected (if applicable)
- [ ] Language servers directory created
- [ ] Configuration files copied on first-run
- [ ] ZIP package structure correct
- [ ] ZIP package size reasonable
- [ ] Package tested on Windows 10 and Windows 11

## Maintenance

### Regular Updates

- Review launcher scripts quarterly for improvements
- Update documentation when new features added
- Test with each PyInstaller version upgrade
- Monitor user feedback for issues
- Update error messages based on common problems

### Future Enhancements

Potential improvements for future versions:

1. **GUI launcher** - Windows Forms or WPF wrapper
2. **Update checker** - Automatic update detection
3. **Installer option** - Convert portable to installed version
4. **Shortcut creator** - Desktop and Start Menu shortcuts
5. **Uninstaller** - Clean removal script
6. **Diagnostics tool** - Advanced troubleshooting
7. **Language server manager** - GUI for installing/removing language servers

## Support

For build system issues:
- Check build logs in `build/logs/`
- Review PyInstaller warnings
- Test on clean Windows VM
- Compare against previous working builds

For launcher script issues:
- Test in isolation (copy to separate directory)
- Check Windows version compatibility
- Verify PowerShell version
- Test with both Command Prompt and PowerShell

## Additional Resources

- PyInstaller Documentation: https://pyinstaller.org/
- Windows Batch Scripting: https://ss64.com/nt/
- PowerShell Documentation: https://docs.microsoft.com/powershell/
- Portable Application Standards: https://portableapps.com/
