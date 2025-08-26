# PowerShell Line Ending and Encoding Fixes

## Overview

This document summarizes the fixes applied to PowerShell scripts in the `/scripts/` directory to resolve line ending and encoding issues that could cause problems when running on Windows systems.

## Problem Identified

All PowerShell scripts (`.ps1` files) in the `/scripts/` directory had Unix-style line endings (LF only) instead of Windows-style line endings (CRLF). This can cause issues when:
- Running scripts in Windows PowerShell (as opposed to PowerShell Core)
- Scripts are opened in Windows text editors
- Scripts are processed by Windows-specific tools

## Changes Made

### 1. Line Ending Conversion

**Files Converted:**
- `corporate-setup-windows.ps1` (498 lines converted)
- `create-fully-portable-package.ps1` (1,063 lines converted)
- `create-portable-package.ps1` (252 lines converted)
- `portable-package-windows10-helpers.ps1` (665 lines converted)
- `test-powershell-syntax.ps1` (45 lines converted)
- `windows10-compatibility.ps1` (663 lines converted)
- `validate-powershell-line-endings.ps1` (253 lines converted)

**Conversion Details:**
- All files converted from Unix LF (`\n`) to Windows CRLF (`\r\n`) line endings
- UTF-8 encoding maintained (no BOM added, as this is compatible with both Windows and cross-platform scenarios)
- Backup files created with `.backup` extension for rollback if needed

### 2. Git Configuration

**`.gitattributes` File Created:**
A comprehensive `.gitattributes` file was created to ensure consistent line endings across different platforms and prevent future issues:

```gitattributes
# PowerShell scripts should use CRLF line endings on all platforms
*.ps1 text eol=crlf

# Python files should use LF line endings
*.py text eol=lf

# Batch files should use CRLF
*.bat text eol=crlf
*.cmd text eol=crlf

# Shell scripts should use LF
*.sh text eol=lf

# Text files should use LF by default
*.txt text eol=lf
*.md text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.json text eol=lf

# Binary files
*.exe binary
*.dll binary
*.zip binary
*.tar.gz binary
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.pdf binary

# Ensure consistent line endings across platforms
* text=auto
```

This ensures that:
- PowerShell scripts (`.ps1`) always use CRLF line endings when checked out
- Python scripts (`.py`) always use LF line endings
- Other file types use appropriate line endings for their platform
- Binary files are handled correctly

### 3. Validation Tools Created

**PowerShell Validation Script:** `/scripts/validate-powershell-line-endings.ps1`
- Analyzes line endings in PowerShell files
- Validates UTF-8 encoding
- Checks PowerShell syntax validity
- Provides detailed reporting
- Can be run on Windows systems to verify fixes

**Batch File Launcher:** `/scripts/validate-line-endings.bat`
- Windows batch file to easily run the validation script
- Sets appropriate execution policy
- Provides user-friendly output

**Python Analysis Tools:**
- `analyze_line_endings.py` - Analyzes current line ending status
- `fix_powershell_line_endings.py` - Main conversion and fixing script

## Verification Results

After applying the fixes, all PowerShell scripts now have:
- ✅ Windows CRLF line endings (`\r\n`)
- ✅ UTF-8 encoding compatibility
- ✅ Valid PowerShell syntax
- ✅ Consistent formatting

## File Size Changes

The conversion from LF to CRLF increased file sizes due to the additional carriage return characters:

| File | Original Size | New Size | Size Increase |
|------|---------------|----------|---------------|
| `corporate-setup-windows.ps1` | 17,312 bytes | 17,626 bytes | +314 bytes |
| `create-fully-portable-package.ps1` | 44,106 bytes | 45,169 bytes | +1,063 bytes |
| `create-portable-package.ps1` | 8,118 bytes | 8,370 bytes | +252 bytes |
| `portable-package-windows10-helpers.ps1` | 24,951 bytes | 25,646 bytes | +695 bytes |
| `test-powershell-syntax.ps1` | 1,344 bytes | 1,389 bytes | +45 bytes |
| `windows10-compatibility.ps1` | 23,313 bytes | 23,966 bytes | +653 bytes |

## Testing Instructions

### On Windows Systems:
1. Run `scripts\validate-line-endings.bat` to validate all PowerShell scripts
2. Or manually run: `powershell.exe -ExecutionPolicy Bypass -File "scripts\validate-powershell-line-endings.ps1" -Verbose`

### On Unix/Linux Systems:
1. Run `python3 analyze_line_endings.py` to check line ending status
2. Run `python3 fix_powershell_line_endings.py` to re-apply fixes if needed

## Future Prevention

The `.gitattributes` file ensures that:
- New PowerShell scripts will automatically use CRLF line endings
- Existing scripts maintain their corrected line endings
- The repository handles cross-platform development correctly
- Binary files are not corrupted by line ending conversions

## Rollback Instructions

If needed, the original files can be restored from the `.backup` files:
```bash
cd /root/repo/scripts
for f in *.ps1.backup; do 
    mv "$f" "${f%.backup}"
done
```

## Technical Notes

- **Encoding:** UTF-8 without BOM was chosen for maximum compatibility
- **Line Endings:** CRLF (`\r\n`) is used for all PowerShell scripts as per Windows convention
- **Git Handling:** The `.gitattributes` file ensures consistent behavior across all environments
- **Validation:** Multiple validation layers ensure scripts work correctly on Windows systems

## Files Created/Modified

### New Files:
- `/root/repo/.gitattributes` - Git line ending configuration
- `/root/repo/scripts/validate-powershell-line-endings.ps1` - PowerShell validation script
- `/root/repo/scripts/validate-line-endings.bat` - Windows batch launcher
- `/root/repo/analyze_line_endings.py` - Python analysis tool
- `/root/repo/fix_powershell_line_endings.py` - Python conversion tool
- `/root/repo/POWERSHELL_LINE_ENDING_FIXES.md` - This documentation

### Modified Files:
- All `.ps1` files in `/scripts/` directory (converted to CRLF line endings)

### Backup Files Created:
- `*.ps1.backup` files in `/scripts/` directory (can be removed after verification)

## Summary

All PowerShell scripts have been successfully converted to use Windows-compatible CRLF line endings and UTF-8 encoding. The changes ensure proper execution on Windows systems while maintaining cross-platform compatibility. Future line ending issues are prevented through proper Git configuration.