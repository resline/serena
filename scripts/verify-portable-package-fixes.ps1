#!/usr/bin/env pwsh
# Script to verify all fixes applied to portable package creation scripts

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PORTABLE PACKAGE FIX VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Join-Path $PSScriptRoot "create-fully-portable-package.ps1"
$helperPath = Join-Path $PSScriptRoot "portable-package-windows10-helpers.ps1"

$verificationResults = @()
$hasErrors = $false

# Test 1: Check python311._pth configuration in main script
Write-Host "[TEST 1] Checking python311._pth configuration..." -ForegroundColor Yellow
$mainContent = Get-Content $scriptPath -Raw
if ($mainContent -match '\$pthLines\s*=\s*@\([^)]+\)') {
    $pthBlock = $matches[0]
    if ($pthBlock -notmatch '\.\.\\Lib\\site-packages' -and 
        $pthBlock -notmatch '\.\.\\serena\\src' -and
        $pthBlock -match 'DLLs') {
        Write-Host "  [OK] Main script _pth configuration is correct" -ForegroundColor Green
        $verificationResults += "✓ Main script _pth fixed"
    } else {
        Write-Host "  [ERROR] Main script _pth still has problematic paths" -ForegroundColor Red
        $hasErrors = $true
        $verificationResults += "✗ Main script _pth needs fixing"
    }
}

# Test 2: Check Windows 10 helper _pth configuration
Write-Host "[TEST 2] Checking Windows 10 helper _pth configuration..." -ForegroundColor Yellow
$helperContent = Get-Content $helperPath -Raw
if ($helperContent -match 'Create enhanced python\._pth[^@]+@\([^)]+\)') {
    $helperPthBlock = $matches[0]
    if ($helperPthBlock -notmatch '\.\.\\\.\.\\Lib\\site-packages' -and 
        $helperPthBlock -notmatch '\.\.\\\.\.\\serena\\src' -and
        $helperPthBlock -match 'DLLs') {
        Write-Host "  [OK] Helper script _pth configuration is correct" -ForegroundColor Green
        $verificationResults += "✓ Helper script _pth fixed"
    } else {
        Write-Host "  [ERROR] Helper script _pth still has problematic paths" -ForegroundColor Red
        $hasErrors = $true
        $verificationResults += "✗ Helper script _pth needs fixing"
    }
}

# Test 3: Check directory creation
Write-Host "[TEST 3] Checking directory structure creation..." -ForegroundColor Yellow
if ($mainContent -match '\$requiredDirs\s*=\s*@\([^)]+DLLs[^)]+\)') {
    Write-Host "  [OK] Directory structure validation added" -ForegroundColor Green
    $verificationResults += "✓ Directory structure validation added"
} else {
    Write-Host "  [WARN] Directory structure validation may be missing" -ForegroundColor Yellow
    $verificationResults += "⚠ Check directory structure validation"
}

# Test 4: Check pip installation (no --target)
Write-Host "[TEST 4] Checking pip installation method..." -ForegroundColor Yellow
if ($mainContent -match 'get-pip\.py.*--no-cache-dir' -and
    $mainContent -notmatch 'get-pip\.py.*--target.*Lib\\site-packages') {
    Write-Host "  [OK] Pip installation uses correct method (no --target)" -ForegroundColor Green
    $verificationResults += "✓ Pip installation method fixed"
} else {
    Write-Host "  [ERROR] Pip installation may still use --target" -ForegroundColor Red
    $hasErrors = $true
    $verificationResults += "✗ Check pip installation method"
}

# Test 5: Check sitecustomize.py creation
Write-Host "[TEST 5] Checking sitecustomize.py creation..." -ForegroundColor Yellow
if ($mainContent -match 'sitecustomize\.py') {
    Write-Host "  [OK] sitecustomize.py creation found" -ForegroundColor Green
    $verificationResults += "✓ sitecustomize.py added"
} else {
    Write-Host "  [WARN] sitecustomize.py creation not found" -ForegroundColor Yellow
    $verificationResults += "⚠ sitecustomize.py may be missing"
}

# Test 6: Check enhanced diagnostics
Write-Host "[TEST 6] Checking enhanced diagnostics..." -ForegroundColor Yellow
if ($mainContent -match 'Python sys\.path analysis' -or 
    $mainContent -match 'site-packages exists:') {
    Write-Host "  [OK] Enhanced diagnostics added" -ForegroundColor Green
    $verificationResults += "✓ Enhanced diagnostics added"
} else {
    Write-Host "  [WARN] Enhanced diagnostics may be missing" -ForegroundColor Yellow
    $verificationResults += "⚠ Check enhanced diagnostics"
}

# Test 7: Check safeguards
Write-Host "[TEST 7] Checking safeguards and validation..." -ForegroundColor Yellow
if ($mainContent -match 'python311\.zip.*too small' -and
    $mainContent -match 'Final validation') {
    Write-Host "  [OK] Safeguards and validation added" -ForegroundColor Green
    $verificationResults += "✓ Safeguards added"
} else {
    Write-Host "  [WARN] Some safeguards may be missing" -ForegroundColor Yellow
    $verificationResults += "⚠ Check safeguards"
}

# Test 8: Check timeout protection
Write-Host "[TEST 8] Checking timeout protection..." -ForegroundColor Yellow
if ($mainContent -match 'Start-Process.*-Wait.*pip' -or
    $mainContent -match 'WaitForExit.*timeout') {
    Write-Host "  [OK] Timeout protection added" -ForegroundColor Green
    $verificationResults += "✓ Timeout protection added"
} else {
    Write-Host "  [WARN] Timeout protection may be missing" -ForegroundColor Yellow
    $verificationResults += "⚠ Check timeout protection"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VERIFICATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($result in $verificationResults) {
    if ($result -match '^✓') {
        Write-Host $result -ForegroundColor Green
    } elseif ($result -match '^✗') {
        Write-Host $result -ForegroundColor Red
    } else {
        Write-Host $result -ForegroundColor Yellow
    }
}

Write-Host ""
if ($hasErrors) {
    Write-Host "❌ VERIFICATION FAILED - Some critical fixes are missing" -ForegroundColor Red
    Write-Host "   Please review the scripts and apply all necessary fixes" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ VERIFICATION PASSED - All critical fixes applied" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run the fixed script: .\create-fully-portable-package.ps1" -ForegroundColor White
    Write-Host "2. Monitor the output for any remaining issues" -ForegroundColor White
    Write-Host "3. Test pip installation with: python\python.exe -m pip --version" -ForegroundColor White
    Write-Host "4. If issues persist, check the enhanced diagnostics output" -ForegroundColor White
}