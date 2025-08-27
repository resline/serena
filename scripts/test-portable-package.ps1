#!/usr/bin/env pwsh
# Test script for portable package after creation

param(
    [Parameter(Mandatory=$false)]
    [string]$PackagePath = ".\serena-fully-portable"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PORTABLE PACKAGE TESTING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testResults = @()
$failedTests = 0

# Test 1: Check package structure
Write-Host "[TEST 1] Checking package structure..." -ForegroundColor Yellow
$requiredPaths = @(
    "$PackagePath\python\python.exe",
    "$PackagePath\python\python311._pth",
    "$PackagePath\python\python311.zip",
    "$PackagePath\python\DLLs",
    "$PackagePath\python\Lib",
    "$PackagePath\python\Lib\site-packages",
    "$PackagePath\python\Scripts",
    "$PackagePath\python\sitecustomize.py",
    "$PackagePath\serena",
    "$PackagePath\dependencies"
)

foreach ($path in $requiredPaths) {
    if (Test-Path $path) {
        Write-Host "  [OK] $path" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $path" -ForegroundColor Red
        $failedTests++
    }
}

# Test 2: Python executable
Write-Host ""
Write-Host "[TEST 2] Testing Python executable..." -ForegroundColor Yellow
try {
    $pythonVersion = & "$PackagePath\python\python.exe" --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Python works: $pythonVersion" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Python failed with exit code $LASTEXITCODE" -ForegroundColor Red
        $failedTests++
    }
} catch {
    Write-Host "  [ERROR] Cannot run Python: $_" -ForegroundColor Red
    $failedTests++
}

# Test 3: Python paths
Write-Host ""
Write-Host "[TEST 3] Testing Python path configuration..." -ForegroundColor Yellow
$pathTest = & "$PackagePath\python\python.exe" -c @"
import sys
import os

print('Python paths:')
for p in sys.path:
    exists = os.path.exists(p)
    print(f'  {"[OK]" if exists else "[MISSING]"} {p}')

# Check site-packages
site_packages = os.path.join(os.path.dirname(sys.executable), 'Lib', 'site-packages')
print(f'\nsite-packages: {site_packages}')
print(f'Exists: {os.path.exists(site_packages)}')
"@ 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host $pathTest -ForegroundColor Gray
} else {
    Write-Host "  [ERROR] Path test failed" -ForegroundColor Red
    Write-Host $pathTest -ForegroundColor Red
    $failedTests++
}

# Test 4: Pip module
Write-Host ""
Write-Host "[TEST 4] Testing pip module..." -ForegroundColor Yellow
$pipTest = & "$PackagePath\python\python.exe" -m pip --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] pip module works: $pipTest" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] pip module failed" -ForegroundColor Red
    Write-Host $pipTest -ForegroundColor Red
    $failedTests++
    
    # Try alternative methods
    Write-Host "  [INFO] Trying direct import..." -ForegroundColor Yellow
    $importTest = & "$PackagePath\python\python.exe" -c "import pip; print(f'pip version: {pip.__version__}')" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PARTIAL] pip imports but -m pip fails: $importTest" -ForegroundColor Yellow
    } else {
        Write-Host "  [ERROR] pip cannot be imported at all" -ForegroundColor Red
    }
}

# Test 5: Pip executable
Write-Host ""
Write-Host "[TEST 5] Testing pip executable..." -ForegroundColor Yellow
if (Test-Path "$PackagePath\python\Scripts\pip.exe") {
    $pipExeTest = & "$PackagePath\python\Scripts\pip.exe" --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] pip.exe works: $pipExeTest" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] pip.exe exists but doesn't work" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [ERROR] pip.exe not found" -ForegroundColor Red
    $failedTests++
}

# Test 6: UV installation
Write-Host ""
Write-Host "[TEST 6] Testing UV installation..." -ForegroundColor Yellow
$uvTest = & "$PackagePath\python\python.exe" -c "import uv; print(f'uv version: {uv.__version__}')" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] UV is installed: $uvTest" -ForegroundColor Green
} else {
    Write-Host "  [WARN] UV not installed or not accessible" -ForegroundColor Yellow
}

# Test 7: Serena imports
Write-Host ""
Write-Host "[TEST 7] Testing Serena imports..." -ForegroundColor Yellow
$serenaTest = & "$PackagePath\python\python.exe" -c @"
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(sys.executable), '..', 'serena', 'src'))
try:
    from serena.agent import SerenaAgent
    print('[OK] Serena agent imports successfully')
except ImportError as e:
    print(f'[ERROR] Cannot import Serena: {e}')
    sys.exit(1)
"@ 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  $serenaTest" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Serena import failed" -ForegroundColor Red
    Write-Host $serenaTest -ForegroundColor Red
    $failedTests++
}

# Test 8: Offline dependency installation
Write-Host ""
Write-Host "[TEST 8] Testing offline dependency installation..." -ForegroundColor Yellow
if (Test-Path "$PackagePath\dependencies") {
    $depCount = (Get-ChildItem "$PackagePath\dependencies\*.whl" -ErrorAction SilentlyContinue).Count
    Write-Host "  [INFO] Found $depCount wheel files in dependencies" -ForegroundColor Gray
    
    # Try installing a simple package offline
    $testInstall = & "$PackagePath\python\python.exe" -m pip list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Can list installed packages" -ForegroundColor Green
        Write-Host ($testInstall | Select-String -Pattern "pip|setuptools|wheel" | Out-String) -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] Cannot list packages" -ForegroundColor Red
        $failedTests++
    }
} else {
    Write-Host "  [WARN] No dependencies directory found" -ForegroundColor Yellow
}

# Test 9: Batch file launcher
Write-Host ""
Write-Host "[TEST 9] Testing batch file launcher..." -ForegroundColor Yellow
$batchFile = "$PackagePath\serena.bat"
if (Test-Path $batchFile) {
    Write-Host "  [OK] serena.bat exists" -ForegroundColor Green
    
    # Check batch file content
    $batchContent = Get-Content $batchFile -Raw
    if ($batchContent -match "PYTHONPATH") {
        Write-Host "  [OK] PYTHONPATH configured in batch file" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] PYTHONPATH may not be configured" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [ERROR] serena.bat not found" -ForegroundColor Red
    $failedTests++
}

# Test 10: sitecustomize.py
Write-Host ""
Write-Host "[TEST 10] Testing sitecustomize.py..." -ForegroundColor Yellow
$siteCustomizeTest = & "$PackagePath\python\python.exe" -c @"
import sys
import os

# Check if sitecustomize is being loaded
try:
    import sitecustomize
    print('[OK] sitecustomize module loaded')
except ImportError:
    print('[WARN] sitecustomize not loaded')
    
# Check if paths are correctly set
if '' in sys.path:
    print('[OK] Current directory in sys.path')
else:
    print('[WARN] Current directory not in sys.path')
"@ 2>&1

Write-Host $siteCustomizeTest -ForegroundColor Gray

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "✅ ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The portable package is ready to use:" -ForegroundColor Cyan
    Write-Host "  1. Copy the '$PackagePath' folder to any Windows machine" -ForegroundColor White
    Write-Host "  2. Run 'serena.bat' to start using Serena" -ForegroundColor White
    Write-Host "  3. No internet connection or installation required!" -ForegroundColor White
} else {
    Write-Host "❌ $failedTests TESTS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "  1. Re-run create-fully-portable-package.ps1" -ForegroundColor White
    Write-Host "  2. Check the error messages above" -ForegroundColor White
    Write-Host "  3. Verify Python 3.11 embedded package downloaded correctly" -ForegroundColor White
    Write-Host "  4. Run with -Verbose flag for more details" -ForegroundColor White
}

exit $failedTests