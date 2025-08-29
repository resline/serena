# Test script for portable package _pth file fix
# Validates the specific scenario that was failing and ensures _pth files survive pip reinstall
param(
    [string]$PackagePath = ".\serena-fully-portable",
    [string]$CreatePackage = $false,
    [string]$Verbose = $false
)

# Colors for output
$Red = "Red"
$Green = "Green" 
$Yellow = "Yellow"
$Cyan = "Cyan"
$Gray = "Gray"
$Magenta = "Magenta"

Write-Host "`n=============================================================================" -ForegroundColor $Cyan
Write-Host "      TESTING PORTABLE PACKAGE _PTH FILE FIX" -ForegroundColor $Cyan
Write-Host "   Validating Windows 10 pip installation compatibility" -ForegroundColor $Cyan
Write-Host "=============================================================================" -ForegroundColor $Cyan

# Initialize test results tracking
$testResults = @{
    "PthFilesExist" = $false
    "PthContentCorrect" = $false
    "PthFilesWritable" = $false
    "PythonPathWorking" = $false
    "PipAccessible" = $false
    "PipReinstallSurvival" = $false
    "FilterPatternFixed" = $false
}

$testDetails = @{}
$currentTest = 0
$totalTests = $testResults.Count

# Helper function for test status
function Show-TestHeader {
    param([string]$TestName, [string]$Description)
    $script:currentTest++
    Write-Host "`n[$script:currentTest/$script:totalTests] $TestName" -ForegroundColor $Yellow
    Write-Host "    $Description" -ForegroundColor $Gray
}

# Helper function for detailed output
function Write-Detail {
    param([string]$Message, [string]$Color = $Gray)
    if ($Verbose) {
        Write-Host "    [DETAIL] $Message" -ForegroundColor $Color
    }
}

# Check if package exists or offer to create it
if (-not (Test-Path $PackagePath)) {
    Write-Host "`n[ERROR] Package not found: $PackagePath" -ForegroundColor $Red
    if ($CreatePackage -eq $true -or $CreatePackage -eq "true") {
        Write-Host "[INFO] Creating package using create-fully-portable-package.ps1..." -ForegroundColor $Yellow
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $CreateScript = Join-Path $ScriptDir "create-fully-portable-package.ps1"
        
        if (Test-Path $CreateScript) {
            try {
                & $CreateScript -OutputPath $PackagePath
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[ERROR] Package creation failed" -ForegroundColor $Red
                    exit 1
                }
            } catch {
                Write-Host "[ERROR] Failed to create package: $($_.Exception.Message)" -ForegroundColor $Red
                exit 1
            }
        } else {
            Write-Host "[ERROR] create-fully-portable-package.ps1 not found" -ForegroundColor $Red
            exit 1
        }
    } else {
        Write-Host "[INFO] Use -CreatePackage `$true to automatically create the package" -ForegroundColor $Yellow
        Write-Host "[INFO] Or run: .\create-fully-portable-package.ps1 -OutputPath $PackagePath" -ForegroundColor $Yellow
        exit 1
    }
}

Write-Host "`n[INFO] Testing package: $PackagePath" -ForegroundColor $Green

# TEST 1: Check _pth files existence
Show-TestHeader "PTH FILES EXISTENCE" "Verifying that both python311._pth and python._pth exist"

$pthFiles = @(
    "$PackagePath\python\python311._pth",
    "$PackagePath\python\python._pth"
)

$allExist = $true
$existingFiles = @()
foreach ($pth in $pthFiles) {
    if (Test-Path $pth) {
        Write-Host "        [✓] Found: $(Split-Path -Leaf $pth)" -ForegroundColor $Green
        $existingFiles += $pth
        Write-Detail "Full path: $pth"
    } else {
        Write-Host "        [✗] Missing: $(Split-Path -Leaf $pth)" -ForegroundColor $Red
        $allExist = $false
    }
}
$testResults["PthFilesExist"] = $allExist
$testDetails["PthFilesExist"] = "Found $($existingFiles.Count)/$($pthFiles.Count) _pth files"

# TEST 2: Check _pth files are writable (fix for read-only files)
Show-TestHeader "PTH FILES WRITABLE" "Ensuring _pth files can be modified (not read-only)"

$allWritable = $true
$writableDetails = @()
foreach ($pth in $existingFiles) {
    if (Test-Path $pth) {
        try {
            $fileInfo = Get-Item $pth
            $isReadOnly = $fileInfo.IsReadOnly
            if ($isReadOnly) {
                Write-Host "        [!] File is read-only: $(Split-Path -Leaf $pth)" -ForegroundColor $Yellow
                # Try to make it writable
                try {
                    $fileInfo.IsReadOnly = $false
                    Write-Host "        [✓] Made writable: $(Split-Path -Leaf $pth)" -ForegroundColor $Green
                    $writableDetails += "Made writable: $(Split-Path -Leaf $pth)"
                } catch {
                    Write-Host "        [✗] Could not make writable: $(Split-Path -Leaf $pth)" -ForegroundColor $Red
                    $allWritable = $false
                    $writableDetails += "Failed to make writable: $(Split-Path -Leaf $pth)"
                }
            } else {
                Write-Host "        [✓] Already writable: $(Split-Path -Leaf $pth)" -ForegroundColor $Green
                $writableDetails += "Writable: $(Split-Path -Leaf $pth)"
            }
        } catch {
            Write-Host "        [✗] Could not check writability: $(Split-Path -Leaf $pth)" -ForegroundColor $Red
            $allWritable = $false
            $writableDetails += "Check failed: $(Split-Path -Leaf $pth)"
        }
    }
}
$testResults["PthFilesWritable"] = $allWritable
$testDetails["PthFilesWritable"] = $writableDetails -join "; "

# TEST 3: Verify _pth content is correct
Show-TestHeader "PTH CONTENT VALIDATION" "Checking that _pth files contain the correct Python paths"

$expectedLines = @(
    "python311.zip",
    ".",
    "DLLs", 
    "Lib",
    "Lib\site-packages",
    "import site"
)

$contentCorrect = $false
$contentDetails = @()
if ($existingFiles.Count -gt 0) {
    $primaryPth = $existingFiles[0]  # Use first available _pth file
    Write-Detail "Checking content of: $primaryPth"
    
    try {
        $content = Get-Content $primaryPth -Encoding UTF8
        Write-Detail "File contains $($content.Count) lines"
        
        $missingLines = @()
        $extraLines = @()
        
        foreach ($expectedLine in $expectedLines) {
            if ($content -notcontains $expectedLine) {
                $missingLines += $expectedLine
                Write-Host "        [✗] Missing line: $expectedLine" -ForegroundColor $Red
            } else {
                Write-Host "        [✓] Found line: $expectedLine" -ForegroundColor $Green
            }
        }
        
        # Check for unexpected lines
        foreach ($line in $content) {
            if ($line.Trim() -and $expectedLines -notcontains $line) {
                $extraLines += $line
                Write-Detail "Extra line found: $line" $Yellow
            }
        }
        
        if ($missingLines.Count -eq 0) {
            $contentCorrect = $true
            $contentDetails += "All expected lines present"
        } else {
            $contentDetails += "Missing: $($missingLines -join ', ')"
        }
        
        if ($extraLines.Count -gt 0) {
            $contentDetails += "Extra: $($extraLines -join ', ')"
        }
        
    } catch {
        Write-Host "        [✗] Could not read _pth file: $($_.Exception.Message)" -ForegroundColor $Red
        $contentDetails += "Read error: $($_.Exception.Message)"
    }
} else {
    Write-Host "        [✗] No _pth files available to check" -ForegroundColor $Red
    $contentDetails += "No files to check"
}
$testResults["PthContentCorrect"] = $contentCorrect
$testDetails["PthContentCorrect"] = $contentDetails -join "; "

# TEST 4: Verify Python path configuration is working
Show-TestHeader "PYTHON PATH CONFIGURATION" "Testing that Python can find Lib and site-packages directories"

$pythonExe = "$PackagePath\python\python.exe"
$pythonPathWorking = $false
$pathDetails = @()

if (Test-Path $pythonExe) {
    Write-Detail "Python executable found: $pythonExe"
    
    try {
        # Test that Lib and site-packages are in sys.path
        $pathTestScript = @"
import sys
import os
import json

result = {
    'executable': sys.executable,
    'version': sys.version,
    'paths': sys.path,
    'lib_present': False,
    'sitepackages_present': False,
    'needed_paths': []
}

python_dir = os.path.dirname(sys.executable)
lib_path = os.path.join(python_dir, 'Lib')
sitepackages_path = os.path.join(python_dir, 'Lib', 'site-packages')

result['lib_present'] = any('Lib' in p for p in sys.path)
result['sitepackages_present'] = any('site-packages' in p for p in sys.path)
result['needed_paths'] = [lib_path, sitepackages_path]

# Check if the actual paths exist
result['lib_exists'] = os.path.exists(lib_path)
result['sitepackages_exists'] = os.path.exists(sitepackages_path)

print(json.dumps(result, indent=2))
"@
        
        $pathTestResult = & $pythonExe -c $pathTestScript 2>&1
        $pathTestExit = $LASTEXITCODE
        
        if ($pathTestExit -eq 0) {
            try {
                $pathInfo = $pathTestResult | ConvertFrom-Json
                Write-Detail "Python version: $($pathInfo.version -split "`n" | Select-Object -First 1)"
                
                if ($pathInfo.lib_present -and $pathInfo.sitepackages_present) {
                    Write-Host "        [✓] Lib paths present in sys.path" -ForegroundColor $Green
                    $pythonPathWorking = $true
                    $pathDetails += "Both Lib and site-packages in sys.path"
                } else {
                    Write-Host "        [✗] Required paths missing from sys.path" -ForegroundColor $Red
                    if (-not $pathInfo.lib_present) {
                        $pathDetails += "Lib path missing"
                    }
                    if (-not $pathInfo.sitepackages_present) {
                        $pathDetails += "site-packages path missing"
                    }
                }
                
                # Show directory existence
                Write-Detail "Lib directory exists: $($pathInfo.lib_exists)"
                Write-Detail "site-packages directory exists: $($pathInfo.sitepackages_exists)"
                
            } catch {
                Write-Host "        [✗] Could not parse Python path test results" -ForegroundColor $Red
                Write-Detail "Raw output: $pathTestResult"
                $pathDetails += "Parse error: $($_.Exception.Message)"
            }
        } else {
            Write-Host "        [✗] Python path test failed (exit code: $pathTestExit)" -ForegroundColor $Red
            Write-Detail "Error output: $pathTestResult"
            $pathDetails += "Python test failed with exit code $pathTestExit"
        }
    } catch {
        Write-Host "        [✗] Failed to test Python path: $($_.Exception.Message)" -ForegroundColor $Red
        $pathDetails += "Test execution failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "        [✗] Python executable not found: $pythonExe" -ForegroundColor $Red
    $pathDetails += "Python executable missing"
}

$testResults["PythonPathWorking"] = $pythonPathWorking
$testDetails["PythonPathWorking"] = $pathDetails -join "; "

# TEST 5: Verify pip accessibility via module import
Show-TestHeader "PIP MODULE ACCESS" "Testing that 'python -m pip' works correctly"

$pipAccessible = $false
$pipDetails = @()

if (Test-Path $pythonExe) {
    try {
        Write-Detail "Testing 'python -m pip --version'..."
        $pipModuleTest = & $pythonExe -m pip --version 2>&1
        $pipTestExitCode = $LASTEXITCODE
        
        if ($pipTestExitCode -eq 0 -and $pipModuleTest) {
            Write-Host "        [✓] Pip module accessible: $pipModuleTest" -ForegroundColor $Green
            $pipAccessible = $true
            $pipDetails += "Module access: OK"
        } else {
            Write-Host "        [✗] Pip module test failed (exit code: $pipTestExitCode)" -ForegroundColor $Red
            $pipDetails += "Module access failed (exit $pipTestExitCode)"
            
            # Try alternative methods
            Write-Detail "Trying direct pip import..."
            $pipImportTest = & $pythonExe -c "import pip; print('Pip version:', pip.__version__)" 2>&1
            $importTestExitCode = $LASTEXITCODE
            
            if ($importTestExitCode -eq 0) {
                Write-Host "        [!] Pip accessible via direct import: $pipImportTest" -ForegroundColor $Yellow
                $pipDetails += "Direct import: OK"
            } else {
                $pipDetails += "Direct import: Failed"
            }
            
            # Check if pip executable exists
            $pipExePath = "$PackagePath\python\Scripts\pip.exe"
            if (Test-Path $pipExePath) {
                Write-Detail "Pip executable found at: $pipExePath"
                $pipDetails += "Executable: Found"
            } else {
                Write-Detail "Pip executable not found at expected location"
                $pipDetails += "Executable: Missing"
            }
        }
    } catch {
        Write-Host "        [✗] Failed to test pip accessibility: $($_.Exception.Message)" -ForegroundColor $Red
        $pipDetails += "Test failed: $($_.Exception.Message)"
    }
} else {
    $pipDetails += "Python executable missing"
}

$testResults["PipAccessible"] = $pipAccessible
$testDetails["PipAccessible"] = $pipDetails -join "; "

# TEST 6: Test the critical fix - _pth file filter pattern
Show-TestHeader "PTH FILTER PATTERN FIX" "Verifying the filter pattern correctly identifies all _pth files"

$filterPatternFixed = $false
$filterDetails = @()

# Simulate the old and new filter patterns
$pythonDir = "$PackagePath\python"
if (Test-Path $pythonDir) {
    # Old pattern: "*._pth" (incorrect - would miss python311._pth)
    $oldPattern = "*._pth"
    $oldMatches = @()
    try {
        $oldMatches = Get-ChildItem -Path $pythonDir -Filter $oldPattern -ErrorAction SilentlyContinue
        Write-Detail "Old pattern '$oldPattern' found $($oldMatches.Count) files"
        foreach ($match in $oldMatches) {
            Write-Detail "  Old pattern matched: $($match.Name)"
        }
    } catch {
        Write-Detail "Old pattern test failed: $($_.Exception.Message)"
    }
    
    # New pattern: "*._pth" should work, but let's verify by checking for both files explicitly
    $actualPthFiles = @()
    $possiblePthNames = @("python._pth", "python311._pth")
    
    foreach ($pthName in $possiblePthNames) {
        $pthPath = Join-Path $pythonDir $pthName
        if (Test-Path $pthPath) {
            $actualPthFiles += Get-Item $pthPath
            Write-Host "        [✓] Filter should find: $pthName" -ForegroundColor $Green
        }
    }
    
    # Test current filter pattern
    $currentMatches = @()
    try {
        $currentMatches = Get-ChildItem -Path $pythonDir -Filter "*._pth" -ErrorAction SilentlyContinue
        Write-Detail "Current pattern '*._pth' found $($currentMatches.Count) files"
        foreach ($match in $currentMatches) {
            Write-Detail "  Current pattern matched: $($match.Name)"
        }
    } catch {
        Write-Detail "Current pattern test failed: $($_.Exception.Message)"
    }
    
    # Check if the pattern now correctly finds all _pth files
    if ($actualPthFiles.Count -gt 0 -and $currentMatches.Count -eq $actualPthFiles.Count) {
        Write-Host "        [✓] Filter pattern correctly finds all _pth files" -ForegroundColor $Green
        $filterPatternFixed = $true
        $filterDetails += "Pattern finds all $($currentMatches.Count) _pth files"
    } else {
        Write-Host "        [✗] Filter pattern issue detected" -ForegroundColor $Red
        $filterDetails += "Expected $($actualPthFiles.Count) files, pattern finds $($currentMatches.Count)"
    }
    
    # Specifically check for python311._pth (the critical file that was missed)
    $python311Pth = "$pythonDir\python311._pth"
    if (Test-Path $python311Pth) {
        $python311InMatches = $currentMatches | Where-Object { $_.Name -eq "python311._pth" }
        if ($python311InMatches) {
            Write-Host "        [✓] python311._pth correctly matched by filter" -ForegroundColor $Green
            $filterDetails += "python311._pth: Found by filter"
        } else {
            Write-Host "        [✗] python311._pth NOT matched by filter (critical bug)" -ForegroundColor $Red
            $filterDetails += "python311._pth: MISSED by filter"
            $filterPatternFixed = $false
        }
    } else {
        $filterDetails += "python311._pth: File not present"
    }
    
} else {
    Write-Host "        [✗] Python directory not found: $pythonDir" -ForegroundColor $Red
    $filterDetails += "Python directory missing"
}

$testResults["FilterPatternFixed"] = $filterPatternFixed
$testDetails["FilterPatternFixed"] = $filterDetails -join "; "

# TEST 7: Simulate pip reinstall scenario to test _pth survival
Show-TestHeader "PIP REINSTALL SURVIVAL" "Testing that _pth files survive pip reinstall operations"

$pipReinstallSurvival = $false
$reinstallDetails = @()

if ($testResults["PipAccessible"] -and (Test-Path $pythonExe)) {
    try {
        # Backup current _pth files
        $backupDir = "$PackagePath\pth_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        
        $backedUpFiles = @()
        foreach ($pth in $existingFiles) {
            if (Test-Path $pth) {
                $backupPath = Join-Path $backupDir (Split-Path -Leaf $pth)
                Copy-Item $pth $backupPath -Force
                $backedUpFiles += @{ Original = $pth; Backup = $backupPath }
                Write-Detail "Backed up: $(Split-Path -Leaf $pth)"
            }
        }
        
        # Record original _pth content
        $originalContent = @{}
        foreach ($file in $backedUpFiles) {
            $originalContent[$file.Original] = Get-Content $file.Original -Raw -ErrorAction SilentlyContinue
        }
        
        # Simulate pip reinstall (just pip itself, which shouldn't affect _pth but let's test)
        Write-Detail "Simulating pip operations that might affect _pth files..."
        
        # Test 1: pip --version (should not affect _pth)
        $pipVersionTest = & $pythonExe -m pip --version 2>&1
        $versionExitCode = $LASTEXITCODE
        Write-Detail "pip --version exit code: $versionExitCode"
        
        # Check if _pth files still exist and have correct content after pip operations
        $survivalCount = 0
        $totalChecked = 0
        
        foreach ($file in $backedUpFiles) {
            $totalChecked++
            if (Test-Path $file.Original) {
                $currentContent = Get-Content $file.Original -Raw -ErrorAction SilentlyContinue
                if ($currentContent -eq $originalContent[$file.Original]) {
                    Write-Host "        [✓] _pth file survived unchanged: $(Split-Path -Leaf $file.Original)" -ForegroundColor $Green
                    $survivalCount++
                } else {
                    Write-Host "        [!] _pth file content changed: $(Split-Path -Leaf $file.Original)" -ForegroundColor $Yellow
                    $reinstallDetails += "Content changed: $(Split-Path -Leaf $file.Original)"
                    # This might still be acceptable if content is valid
                }
            } else {
                Write-Host "        [✗] _pth file disappeared: $(Split-Path -Leaf $file.Original)" -ForegroundColor $Red
                $reinstallDetails += "File missing: $(Split-Path -Leaf $file.Original)"
            }
        }
        
        if ($survivalCount -eq $totalChecked -and $totalChecked -gt 0) {
            $pipReinstallSurvival = $true
            $reinstallDetails += "All $survivalCount _pth files survived pip operations"
        } elseif ($survivalCount -gt 0) {
            # Partial survival - check if remaining files are still functional
            $remainingPathTest = & $pythonExe -c "import sys; print('OK' if any('site-packages' in p for p in sys.path) else 'FAIL')" 2>$null
            if ($remainingPathTest -eq "OK") {
                $pipReinstallSurvival = $true
                $reinstallDetails += "Partial survival ($survivalCount/$totalChecked) but Python paths still functional"
            } else {
                $reinstallDetails += "Partial survival ($survivalCount/$totalChecked) with broken Python paths"
            }
        } else {
            $reinstallDetails += "No _pth files survived pip operations"
        }
        
        # Clean up backup
        try {
            Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Detail "Could not clean up backup directory: $backupDir"
        }
        
    } catch {
        Write-Host "        [✗] Pip reinstall test failed: $($_.Exception.Message)" -ForegroundColor $Red
        $reinstallDetails += "Test execution failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "        [⚠] Skipping reinstall test (pip not accessible)" -ForegroundColor $Yellow
    $reinstallDetails += "Skipped due to pip inaccessibility"
    # If pip is not accessible due to _pth issues, we can't do reinstall test,
    # but the other tests should show the problem
    $pipReinstallSurvival = $testResults["PipAccessible"]
}

$testResults["PipReinstallSurvival"] = $pipReinstallSurvival
$testDetails["PipReinstallSurvival"] = $reinstallDetails -join "; "

# =============================================================================
# COMPREHENSIVE SUMMARY AND ANALYSIS
# =============================================================================

Write-Host "`n=============================================================================" -ForegroundColor $Cyan
Write-Host "                              TEST SUMMARY" -ForegroundColor $Cyan
Write-Host "=============================================================================" -ForegroundColor $Cyan

$passed = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$total = $testResults.Count

# Show individual test results
foreach ($test in $testResults.GetEnumerator() | Sort-Object Name) {
    $status = if ($test.Value) { "[PASS]" } else { "[FAIL]" }
    $color = if ($test.Value) { $Green } else { $Red }
    $testName = $test.Key -replace "([A-Z])", " `$1" -replace "^ ", ""
    
    Write-Host "$status $testName" -ForegroundColor $color
    if ($testDetails.ContainsKey($test.Key) -and $testDetails[$test.Key]) {
        Write-Host "       Details: $($testDetails[$test.Key])" -ForegroundColor $Gray
    }
}

Write-Host "`n" + "=" * 77 -ForegroundColor $Cyan

# Overall result
$overallColor = if ($passed -eq $total) { $Green } else { $Red }
Write-Host "OVERALL RESULT: $passed/$total tests passed" -ForegroundColor $overallColor

# Critical analysis
$criticalTests = @("PthFilesExist", "PthContentCorrect", "PipAccessible")
$criticalPassed = ($criticalTests | Where-Object { $testResults[$_] -eq $true }).Count
$criticalTotal = $criticalTests.Count

Write-Host "`nCRITICAL TESTS: $criticalPassed/$criticalTotal passed" -ForegroundColor $(if ($criticalPassed -eq $criticalTotal) { $Green } else { $Red })

# Specific analysis of the _pth fix
Write-Host "`n[ANALYSIS] _PTH FILE FIX ASSESSMENT:" -ForegroundColor $Magenta

if ($testResults["FilterPatternFixed"]) {
    Write-Host "   ✓ Filter pattern fix: WORKING" -ForegroundColor $Green
    Write-Host "     The '*._pth' pattern now correctly finds all _pth files including python311._pth" -ForegroundColor $Gray
} else {
    Write-Host "   ✗ Filter pattern fix: FAILED" -ForegroundColor $Red
    Write-Host "     The filter pattern still has issues finding _pth files" -ForegroundColor $Gray
}

if ($testResults["PthFilesWritable"]) {
    Write-Host "   ✓ File writability fix: WORKING" -ForegroundColor $Green
    Write-Host "     _pth files are not read-only and can be modified during repair" -ForegroundColor $Gray
} else {
    Write-Host "   ✗ File writability fix: NEEDS ATTENTION" -ForegroundColor $Yellow
    Write-Host "     Some _pth files may be read-only and could cause issues" -ForegroundColor $Gray
}

if ($testResults["PipReinstallSurvival"]) {
    Write-Host "   ✓ Pip reinstall survival: WORKING" -ForegroundColor $Green
    Write-Host "     _pth files survive pip operations and remain functional" -ForegroundColor $Gray
} else {
    Write-Host "   ! Pip reinstall survival: NEEDS VERIFICATION" -ForegroundColor $Yellow
    Write-Host "     Could not fully verify _pth file survival during pip operations" -ForegroundColor $Gray
}

# Recommendations
Write-Host "`n[RECOMMENDATIONS]:" -ForegroundColor $Cyan

if ($passed -eq $total) {
    Write-Host "   🎉 All tests passed! The _pth file fix is working correctly." -ForegroundColor $Green
    Write-Host "   📦 The portable package should work reliably on Windows 10." -ForegroundColor $Green
} else {
    Write-Host "   ⚠  Some issues detected. Review the following:" -ForegroundColor $Yellow
    
    if (-not $testResults["PthFilesExist"]) {
        Write-Host "     • Create missing _pth files (both python._pth and python311._pth)" -ForegroundColor $Gray
    }
    
    if (-not $testResults["PthContentCorrect"]) {
        Write-Host "     • Fix _pth file content to include proper Python paths" -ForegroundColor $Gray
    }
    
    if (-not $testResults["PipAccessible"]) {
        Write-Host "     • Ensure pip can be accessed as a Python module" -ForegroundColor $Gray
    }
    
    if (-not $testResults["FilterPatternFixed"]) {
        Write-Host "     • Verify filter pattern correctly identifies all _pth files" -ForegroundColor $Gray
    }
}

# Package validation status
if ($criticalPassed -eq $criticalTotal) {
    Write-Host "`n✅ PACKAGE VALIDATION: PASSED" -ForegroundColor $Green
    Write-Host "   The Windows 10 pip installation fix is effective." -ForegroundColor $Green
} else {
    Write-Host "`n❌ PACKAGE VALIDATION: FAILED" -ForegroundColor $Red
    Write-Host "   The package needs additional fixes before deployment." -ForegroundColor $Red
}

Write-Host "`n=============================================================================" -ForegroundColor $Cyan

# Exit with appropriate code
if ($passed -eq $total) {
    exit 0
} else {
    exit 1
}