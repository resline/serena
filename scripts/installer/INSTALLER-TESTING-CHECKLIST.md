# Serena Agent Installer - Testing Checklist

## Overview

This comprehensive testing checklist ensures the Serena Agent installer works correctly across all supported scenarios. Use this checklist for each release before distribution.

---

## Pre-Build Testing

### ☐ Build Environment Validation

- [ ] **NSIS Installation**
  - [ ] NSIS 3.0+ installed and in PATH
  - [ ] `makensis` command accessible
  - [ ] All required NSIS plugins available (EnVar, FileAssociation)

- [ ] **Portable Distribution Ready**
  - [ ] Portable ZIP/folder exists
  - [ ] Core executables present (serena.exe, serena-mcp-server.exe)
  - [ ] Language servers organized by tier
  - [ ] All dependencies included
  - [ ] Total size within expected range

- [ ] **Build Scripts**
  - [ ] build-installer-enhanced.ps1 executes without errors
  - [ ] Parameters work correctly (-Tier, -PortablePath, -Sign)
  - [ ] Auto-NSIS download works (if enabled)
  - [ ] Temp directory cleanup successful

---

## Installer Build Testing

### ☐ Basic Build Test

```powershell
# Build with essential tier
.\build-installer-enhanced.ps1 -PortablePath ".\dist\serena-portable" -Tier essential
```

- [ ] Build completes without errors
- [ ] Installer EXE created in output/ directory
- [ ] Installer size reasonable (~200-300 MB for essential)
- [ ] No leftover temp files

### ☐ All Tier Builds

Build installer for each tier and verify size:

- [ ] **Minimal Tier**
  ```powershell
  .\build-installer-enhanced.ps1 -Tier minimal -PortablePath "..."
  ```
  - [ ] Build succeeds
  - [ ] Size: ~150-180 MB

- [ ] **Essential Tier**
  ```powershell
  .\build-installer-enhanced.ps1 -Tier essential -PortablePath "..."
  ```
  - [ ] Build succeeds
  - [ ] Size: ~250-300 MB

- [ ] **Complete Tier**
  ```powershell
  .\build-installer-enhanced.ps1 -Tier complete -PortablePath "..."
  ```
  - [ ] Build succeeds
  - [ ] Size: ~400-450 MB

- [ ] **Full Tier**
  ```powershell
  .\build-installer-enhanced.ps1 -Tier full -PortablePath "..."
  ```
  - [ ] Build succeeds
  - [ ] Size: ~650-700 MB

### ☐ Code Signing Test (if certificate available)

```powershell
.\build-installer-enhanced.ps1 -Sign -CertificatePath "cert.p12" -Tier essential
```

- [ ] Signing completes successfully
- [ ] Digital signature valid
- [ ] Certificate details correct
- [ ] Timestamp server responsive

---

## Interactive Installation Testing

### ☐ Fresh Installation - Full Install

**Test on clean Windows 10/11 VM**

**Installation Steps:**

1. [ ] **Launch Installer**
   - [ ] Double-click installer EXE
   - [ ] UAC prompt appears (system install)
   - [ ] Modern UI displays correctly

2. [ ] **Language Selection**
   - [ ] Dialog appears with supported languages
   - [ ] Selection persists through install
   - [ ] All text displays in chosen language

3. [ ] **Welcome Page**
   - [ ] Product information correct
   - [ ] Version number matches
   - [ ] System requirements listed
   - [ ] Next button enabled

4. [ ] **License Agreement**
   - [ ] MIT license text displays correctly
   - [ ] Scrollable text area works
   - [ ] Acceptance checkbox required
   - [ ] Next disabled until accepted

5. [ ] **Tier Selection Page**
   - [ ] All four tiers displayed
   - [ ] Size estimates shown
   - [ ] Default (Essential) pre-selected
   - [ ] Descriptions clear and accurate

6. [ ] **Component Selection**
   - [ ] Component tree displays correctly
   - [ ] Size calculations accurate
   - [ ] Installation type dropdown works
   - [ ] Component descriptions shown
   - [ ] Disk space validation works
   - [ ] Hierarchical checkboxes work

7. [ ] **Directory Selection**
   - [ ] Default directory correct
   - [ ] Browse button functional
   - [ ] Disk space checked
   - [ ] Invalid paths rejected
   - [ ] Long paths warned

8. [ ] **Start Menu Folder**
   - [ ] Default folder name shown
   - [ ] Custom name entry works
   - [ ] Existing folders listed
   - [ ] Skip option available

9. [ ] **Installation Progress**
   - [ ] Progress bar updates smoothly
   - [ ] Status text describes operation
   - [ ] Detail log shows file-by-file
   - [ ] Time estimate accurate (if shown)
   - [ ] Cancel button works

10. [ ] **Completion Page**
    - [ ] Success message displayed
    - [ ] Installation summary accurate
    - [ ] Launch options available
    - [ ] Documentation link works
    - [ ] Website link opens correctly

**Post-Installation Verification:**

- [ ] **Files Installed**
  - [ ] Core executables present
    - [ ] serena.exe
    - [ ] serena-mcp-server.exe
    - [ ] index-project.exe
  - [ ] LICENSE file present
  - [ ] README.txt created with correct info
  - [ ] _internal directory with dependencies
  - [ ] Language servers in correct locations
  - [ ] Log directories created

- [ ] **User Configuration**
  - [ ] ~/.serena/ directory created
  - [ ] serena_config.yml generated
  - [ ] memories/ subdirectory present
  - [ ] projects/ subdirectory present
  - [ ] Configuration file has correct content

- [ ] **Shortcuts Created**
  - [ ] Start Menu folder exists
  - [ ] Main application shortcut
  - [ ] MCP Server shortcut
  - [ ] Configuration shortcut
  - [ ] Documentation shortcut
  - [ ] Uninstaller shortcut
  - [ ] Desktop shortcut (if selected)
  - [ ] All shortcuts launch correctly

- [ ] **Registry Entries**
  - [ ] Uninstall key: `HKLM\...\Uninstall\Serena Agent`
  - [ ] App path key: `HKLM\...\App Paths\serena.exe`
  - [ ] File association keys (if selected)
  - [ ] User preference keys
  - [ ] All values accurate

- [ ] **System Integration**
  - [ ] PATH updated (if selected)
    - [ ] System PATH for admin install
    - [ ] User PATH for user install
    - [ ] serena.exe accessible from cmd
  - [ ] File associations work
    - [ ] .serena files have Serena icon
    - [ ] Double-click opens with serena.exe
  - [ ] Windows Defender exclusions (if selected)
    - [ ] Path exclusion added
    - [ ] Process exclusions added

- [ ] **Application Functionality**
  - [ ] `serena --version` works
  - [ ] `serena --help` displays help
  - [ ] `serena-mcp-server` starts
  - [ ] Language servers accessible
  - [ ] Configuration file read correctly

### ☐ Fresh Installation - Minimal Install

Repeat above tests with:
- [ ] Minimal tier selected
- [ ] Minimal components
- [ ] User-level installation (no admin)
- [ ] Custom directory
- [ ] No PATH addition
- [ ] No Defender exclusions

### ☐ Fresh Installation - Custom Install

Test with:
- [ ] Complete tier
- [ ] Custom component selection
- [ ] Each component individually toggleable
- [ ] Mixed selections work correctly

---

## Upgrade Installation Testing

### ☐ Upgrade from Previous Version

**Prerequisites:**
- Install previous version (e.g., 0.1.3)
- Create some user configuration
- Add custom settings

**Test Steps:**

1. [ ] **Launch New Installer**
   - [ ] Previous installation detected
   - [ ] Version comparison shown
   - [ ] Upgrade dialog appears

2. [ ] **Accept Upgrade**
   - [ ] User config preservation mentioned
   - [ ] Same install directory used
   - [ ] Settings migration offered

3. [ ] **Upgrade Process**
   - [ ] Old version removed
   - [ ] New version installed
   - [ ] User config preserved
   - [ ] Custom settings retained

4. [ ] **Post-Upgrade Verification**
   - [ ] Application version updated
   - [ ] User config intact
   - [ ] Projects still accessible
   - [ ] Custom settings work
   - [ ] No duplicate shortcuts
   - [ ] Registry properly updated

### ☐ Downgrade Prevention

- [ ] Installing older over newer
- [ ] Warning displayed
- [ ] Option to reinstall or cancel
- [ ] Forced downgrade possible if desired

---

## Silent Installation Testing

### ☐ Basic Silent Install

```batch
serena-installer-0.1.4.exe /S
```

- [ ] Installs without UI
- [ ] Uses default settings
- [ ] Completes successfully
- [ ] Exit code 0 on success
- [ ] All files installed correctly

### ☐ Silent Install with Custom Directory

```batch
serena-installer-0.1.4.exe /S /D=C:\Custom\Serena
```

- [ ] Installs to specified directory
- [ ] Directory created if needed
- [ ] All components in correct location

### ☐ Silent Install with INI Configuration

Create test config:
```ini
[General]
InstallDir=C:\Program Files\Serena Agent
LanguageServerTier=complete
InstallType=full

[Components]
Core=1
LanguageServers=1
UserConfig=1
Shortcuts=1
AddToPath=1
FileAssociations=1
DefenderExclusions=0

[Options]
InstallMode=system
ShowProgress=0
AcceptLicense=1
LaunchAfterInstall=0
```

Run:
```batch
serena-installer-0.1.4.exe /S /INI=test-config.ini
```

- [ ] Configuration loaded correctly
- [ ] All specified components installed
- [ ] Settings applied as configured
- [ ] Log file created (if configured)

### ☐ Silent Install Error Handling

Test with:
- [ ] Insufficient disk space
- [ ] No admin privileges (when required)
- [ ] Invalid install directory
- [ ] Corrupted portable source
- [ ] Each returns proper error code
- [ ] Error logged appropriately

---

## Uninstallation Testing

### ☐ Interactive Uninstall

1. [ ] **Launch Uninstaller**
   - [ ] From Start Menu shortcut
   - [ ] From Control Panel
   - [ ] From uninst.exe directly

2. [ ] **Uninstall Confirmation**
   - [ ] Installation details shown
   - [ ] User config dialog appears
   - [ ] Component list displayed
   - [ ] Warnings clear

3. [ ] **User Config Choice**
   - [ ] **Option 1: Keep Config**
     - [ ] Application removed
     - [ ] ~/.serena/ preserved
     - [ ] Settings intact for reinstall

   - [ ] **Option 2: Remove Config**
     - [ ] Application removed
     - [ ] ~/.serena/ deleted
     - [ ] Complete removal

4. [ ] **Uninstall Progress**
   - [ ] Progress indicator shown
   - [ ] Operations logged
   - [ ] Completion message

5. [ ] **Post-Uninstall Verification**
   - [ ] Install directory removed
   - [ ] Shortcuts deleted
   - [ ] Start Menu folder removed
   - [ ] Desktop shortcut removed
   - [ ] PATH entry removed
   - [ ] File associations cleared
   - [ ] Defender exclusions removed
   - [ ] Registry entries cleaned
   - [ ] App path registration removed

### ☐ Silent Uninstall

```batch
"C:\Program Files\Serena Agent\uninst.exe" /S
```

- [ ] Uninstalls without UI
- [ ] Complete removal
- [ ] User config removed
- [ ] Exit code 0
- [ ] No leftover files

---

## User-Level Installation Testing

### ☐ Installation Without Admin

**Test on standard user account:**

1. [ ] **Launch Installer (No Admin)**
   - [ ] No UAC prompt
   - [ ] User install dialog appears
   - [ ] Alternative offered

2. [ ] **Accept User Install**
   - [ ] Installs to %LOCALAPPDATA%
   - [ ] User-level shortcuts
   - [ ] User PATH modified
   - [ ] HKCU registry keys used

3. [ ] **Verification**
   - [ ] Application works
   - [ ] Accessible only to user
   - [ ] No system-wide impact
   - [ ] User config in correct location

### ☐ User Install Limitations

- [ ] Cannot modify system PATH
- [ ] Cannot add Defender exclusions
- [ ] Cannot register system-wide file associations
- [ ] All limitations documented

---

## Multi-Language Testing

### ☐ Test Each Supported Language

For each language (English, German, French, Spanish):

- [ ] **Language Selection**
  - [ ] Language appears in list
  - [ ] Selection works

- [ ] **UI Translation**
  - [ ] All pages translated
  - [ ] Component descriptions translated
  - [ ] Error messages translated
  - [ ] Button text translated

- [ ] **Installation Success**
  - [ ] Completes in selected language
  - [ ] Shortcuts use correct language
  - [ ] Documentation appropriate

---

## Platform Testing

### ☐ Windows 10 (64-bit)

- [ ] **Version 21H2**
  - [ ] Installation succeeds
  - [ ] All features work

- [ ] **Version 22H2**
  - [ ] Installation succeeds
  - [ ] All features work

### ☐ Windows 11 (64-bit)

- [ ] **Version 21H2**
  - [ ] Installation succeeds
  - [ ] Modern UI renders correctly
  - [ ] All features work

- [ ] **Version 22H2+**
  - [ ] Installation succeeds
  - [ ] All features work

### ☐ Windows Server

- [ ] **Windows Server 2019**
  - [ ] Installation succeeds (if supported)
  - [ ] Core features work

- [ ] **Windows Server 2022**
  - [ ] Installation succeeds (if supported)
  - [ ] Core features work

---

## Edge Case Testing

### ☐ Installation Edge Cases

- [ ] **Disk Space**
  - [ ] Exactly sufficient space
  - [ ] Insufficient space (should fail gracefully)
  - [ ] Space freed during install (dynamic check)

- [ ] **Paths**
  - [ ] Very long install path (near 260 char limit)
  - [ ] Path with spaces
  - [ ] Path with special characters
  - [ ] Unicode characters in path
  - [ ] Network drive (UNC path)

- [ ] **Previous Installations**
  - [ ] Incomplete previous install
  - [ ] Corrupted previous install
  - [ ] Manual file deletion
  - [ ] Orphaned registry entries

- [ ] **System State**
  - [ ] Antivirus running (not Defender)
  - [ ] Low memory conditions
  - [ ] Slow disk I/O
  - [ ] Network instability (for downloads)

### ☐ Concurrent Operations

- [ ] Multiple installer instances
  - [ ] Second instance prevented or queued
  - [ ] Proper locking mechanism

- [ ] Application running during install/uninstall
  - [ ] Running process detected
  - [ ] User prompted to close
  - [ ] Retry mechanism works

### ☐ Interrupted Installation

- [ ] **Cancel During Install**
  - [ ] Rollback initiated
  - [ ] Partial files removed
  - [ ] Registry entries cleaned
  - [ ] Can reinstall successfully

- [ ] **System Crash/Reboot**
  - [ ] Incomplete install detected on next boot
  - [ ] Manual cleanup possible
  - [ ] Reinstall succeeds

---

## Security Testing

### ☐ Digital Signature (if signed)

- [ ] Certificate valid
- [ ] Timestamp server working
- [ ] Signature verified by Windows
- [ ] SmartScreen doesn't block
- [ ] Publisher information correct

### ☐ Windows Defender

- [ ] Installer not flagged as malware
- [ ] Application executables not flagged
- [ ] Exclusions work (if added)
- [ ] No false positives

### ☐ UAC Behavior

- [ ] UAC prompt appropriate (system install)
- [ ] No UAC for user install
- [ ] Elevated properly
- [ ] Credentials prompt works

---

## Performance Testing

### ☐ Installation Performance

- [ ] **Minimal Tier**
  - [ ] Completes in < 2 minutes

- [ ] **Essential Tier**
  - [ ] Completes in < 3 minutes

- [ ] **Complete Tier**
  - [ ] Completes in < 5 minutes

- [ ] **Full Tier**
  - [ ] Completes in < 10 minutes

### ☐ Uninstallation Performance

- [ ] Complete uninstall in < 1 minute
- [ ] Silent uninstall in < 30 seconds

### ☐ Resource Usage

- [ ] Installer CPU usage reasonable
- [ ] Memory usage under 500 MB
- [ ] Disk I/O not excessive
- [ ] No memory leaks

---

## Regression Testing

### ☐ Previous Issue Verification

Verify fixes for any previous installer bugs:

- [ ] Issue #XXX: [Description] - Fixed
- [ ] Issue #XXX: [Description] - Fixed
- [ ] Issue #XXX: [Description] - Fixed

### ☐ Core Functionality

After each test installation:

- [ ] `serena --version` shows correct version
- [ ] `serena --help` displays help
- [ ] `serena config edit` opens config
- [ ] `serena-mcp-server` starts without errors
- [ ] Language servers discoverable
- [ ] Project indexing works

---

## Automated Testing

### ☐ Use Test Script

```powershell
# Run automated installer tests
.\test-installer.ps1 -InstallerPath "output\serena-installer-0.1.4.exe" -TestMode full
```

- [ ] All automated tests pass
- [ ] Test report generated
- [ ] Logs reviewed
- [ ] No warnings or errors

---

## Documentation Review

### ☐ Installer Documentation

- [ ] README.md accurate
- [ ] INSTALLER-OVERVIEW.md complete
- [ ] INSTALLER-UI-DESIGN.md matches implementation
- [ ] INSTALL-UNINSTALL-FLOW.md correct
- [ ] This checklist comprehensive

### ☐ User-Facing Documentation

- [ ] Installation guide updated
- [ ] Troubleshooting section complete
- [ ] FAQ addresses common issues
- [ ] Screenshots/videos current

---

## Release Approval

### ☐ Final Approval Checklist

- [ ] All critical tests passed
- [ ] No P0/P1 bugs remain
- [ ] Known issues documented
- [ ] Release notes prepared
- [ ] Version numbers consistent
- [ ] Digital signature applied (if required)
- [ ] Distribution channels ready
- [ ] Support team informed

### ☐ Sign-Off

- [ ] **Developer:** _______________  Date: _______
- [ ] **QA Lead:** _______________    Date: _______
- [ ] **Product Manager:** _________  Date: _______

---

## Notes and Issues

Use this section to document any issues found during testing:

```
Issue #1: [Description]
- Severity: [Critical/High/Medium/Low]
- Status: [Open/In Progress/Fixed/Won't Fix]
- Notes: [Additional details]

Issue #2: [Description]
- Severity:
- Status:
- Notes:
```

---

## Test Execution Log

| Test Category | Date Tested | Tester | Result | Notes |
|---------------|-------------|---------|---------|-------|
| Pre-Build | | | | |
| Installer Build | | | | |
| Fresh Install | | | | |
| Upgrade Install | | | | |
| Silent Install | | | | |
| Uninstall | | | | |
| User-Level | | | | |
| Multi-Language | | | | |
| Platform Tests | | | | |
| Edge Cases | | | | |
| Security | | | | |
| Performance | | | | |
| Regression | | | | |

---

**Testing Status:** ☐ Not Started | ☐ In Progress | ☐ Completed | ☐ Approved

**Release Ready:** ☐ Yes | ☐ No | ☐ With Caveats

**Approval Date:** _____________
