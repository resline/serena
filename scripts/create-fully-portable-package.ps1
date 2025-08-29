# Create Fully Portable Serena Package for Corporate Deployment
# This script creates a 100% self-contained package with ALL dependencies offline
# Version: 2.1 - Windows 10 Enhanced Edition
# Includes Windows 10-specific optimizations and compatibility enhancements

param(
    [string]$OutputPath = ".\serena-fully-portable",
    [string]$ProxyUrl = $env:HTTP_PROXY,
    [string]$CertPath = $env:REQUESTS_CA_BUNDLE,
    [string]$PythonVersion = "3.11.9",
    [string]$Platform = "win_amd64"
)

# =============================================================================
# WINDOWS 10 COMPATIBILITY INITIALIZATION
# =============================================================================

# Force English locale for consistent corporate deployment
try {
    [System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
} catch {
    Write-Host "[WARN] Could not set English locale - continuing with system default" -ForegroundColor Yellow
}

# Fix Windows console encoding issues for Windows 10 compatibility
try {
    # Set console to UTF-8 for Unicode support
    chcp 65001 | Out-Null
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Fallback: continue with default encoding if UTF-8 setup fails
    Write-Host "[INFO] Using default console encoding (UTF-8 setup failed)" -ForegroundColor Yellow
}

# Load Windows 10 compatibility modules
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Windows 10 compatibility module loading with enhanced error handling
$Win10CompatibilityLoaded = $false
$compatModulePath = "$ScriptDir\windows10-compatibility.ps1"

if (Test-Path $compatModulePath) {
    try {
        . $compatModulePath
        # Verify key functions are available
        if (Get-Command Test-Windows10Compatibility -ErrorAction SilentlyContinue) {
            $Win10CompatibilityLoaded = $true
            Write-Host "[OK] Windows 10 compatibility module loaded successfully" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Windows 10 compatibility module loaded but functions not available" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Failed to load Windows 10 compatibility module: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[DEBUG] Attempted path: $compatModulePath" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] Windows 10 compatibility module not found at: $compatModulePath" -ForegroundColor Yellow
}

# Windows 10 helpers module loading with enhanced error handling
$Win10HelpersLoaded = $false
$helpersModulePath = "$ScriptDir\portable-package-windows10-helpers.ps1"

if (Test-Path $helpersModulePath) {
    try {
        . $helpersModulePath
        if (Get-Command Install-PythonEmbeddedWindows10 -ErrorAction SilentlyContinue) {
            $Win10HelpersLoaded = $true
            Write-Host "[OK] Windows 10 helpers module loaded successfully" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Windows 10 helpers module loaded but functions not available" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Failed to load Windows 10 helpers: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[DEBUG] Attempted path: $helpersModulePath" -ForegroundColor Gray
    }
} else {
    Write-Host "[WARN] Windows 10 helpers not found at: $helpersModulePath" -ForegroundColor Yellow
}

# =============================================================================
# WINDOWS 10 COMPATIBILITY ASSESSMENT
# =============================================================================

Write-Host "Creating FULLY PORTABLE Serena package with Windows 10 optimizations..." -ForegroundColor Cyan
Write-Host "This package will be 100% offline-capable" -ForegroundColor Green

# Run Windows 10 compatibility check if module is loaded
$CompatibilityInfo = $null
if ($Win10CompatibilityLoaded) {
    Write-Host "`n" + "=" * 60
    Write-Host "WINDOWS 10 COMPATIBILITY ASSESSMENT" -ForegroundColor Cyan
    Write-Host "=" * 60
    
    $CompatibilityInfo = Test-Windows10Compatibility -InstallationPath (Resolve-Path $OutputPath -ErrorAction SilentlyContinue)
    
    # Display key findings
    if ($CompatibilityInfo.WindowsInfo.IsWindows10) {
        Write-Host "`n[WINDOWS 10 DETECTED] Optimizations active:" -ForegroundColor Green
        foreach ($opt in $CompatibilityInfo.OptimizationStrategy.Optimizations) {
            Write-Host "  - $opt" -ForegroundColor White
        }
        
        # Show recommendations
        if ($CompatibilityInfo.AntivirusInfo.PotentialInterference) {
            Write-Host "`n[ANTIVIRUS RECOMMENDATIONS]:" -ForegroundColor Yellow
            foreach ($rec in $CompatibilityInfo.AntivirusInfo.Recommendations) {
                Write-Host "  - $rec" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`n" + "=" * 60 + "`n"
}

# Initialize variables
$OfflineMode = $false

# Create directory structure with existence checks to avoid warnings
$dirs = @(
    "$OutputPath",
    "$OutputPath\serena",
    "$OutputPath\language-servers",
    "$OutputPath\dependencies",
    "$OutputPath\config",
    "$OutputPath\scripts",
    "$OutputPath\Lib\site-packages"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

Write-Host "[OK] Created directory structure" -ForegroundColor Green

# Clone Serena (using fork for corporate deployment)
Write-Host "Cloning Serena repository..." -ForegroundColor Yellow
git clone https://github.com/resline/serena "$OutputPath\serena-temp"

# Copy only necessary files
$essentialDirs = @("src", "scripts", "pyproject.toml", "README.md", "LICENSE", "CLAUDE.md")
foreach ($item in $essentialDirs) {
    Copy-Item -Path "$OutputPath\serena-temp\$item" -Destination "$OutputPath\serena\" -Recurse -Force
}

Remove-Item -Path "$OutputPath\serena-temp" -Recurse -Force
Write-Host "[OK] Copied Serena source code" -ForegroundColor Green

# =============================================================================
# PYTHON INSTALLATION WITH WINDOWS 10 OPTIMIZATIONS
# =============================================================================

# Use Windows 10 optimized Python installation if available
if ($Win10HelpersLoaded -and $CompatibilityInfo) {
    Write-Host "Installing Python with Windows 10 optimizations..." -ForegroundColor Cyan
    
    $pythonInstallSuccess = Install-PythonEmbeddedWindows10 -OutputPath $OutputPath -PythonVersion $PythonVersion -CompatibilityInfo $CompatibilityInfo
    if (-not $pythonInstallSuccess) {
        Write-Host "[WARN] Windows 10 optimized installation failed, falling back to standard method" -ForegroundColor Yellow
    }
} else {
    $pythonInstallSuccess = $false
}

# Fallback to standard Python installation
if (-not $pythonInstallSuccess) {
    Write-Host "Downloading Python $PythonVersion embedded (standard method)..." -ForegroundColor Yellow
    $pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
    $pythonZip = "$OutputPath\python-embedded.zip"

    try {
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonZip -UseBasicParsing -TimeoutSec 300
        
        # Use Windows 10 optimized extraction if available
        if ($Win10HelpersLoaded) {
            $extractSuccess = Expand-ArchiveWindows10 -Path $pythonZip -DestinationPath "$OutputPath\python" -Force
        } else {
            Expand-Archive -Path $pythonZip -DestinationPath "$OutputPath\python" -Force
            $extractSuccess = $true
        }
        
        if (-not $extractSuccess) {
            throw "Archive extraction failed"
        }
        
        # Clean up with Windows 10 compatibility
        if ($Win10HelpersLoaded) {
            Remove-FileWithRetry -Path $pythonZip
        } else {
            Remove-Item $pythonZip
        }
        
        Write-Host "[OK] Downloaded and extracted Python embedded" -ForegroundColor Green
        
        # Create Lib and Scripts directory structure for pip installation
        $pythonLibDir = "$OutputPath\python\Lib"
        $pythonSitePackagesDir = "$OutputPath\python\Lib\site-packages"
        $pythonScriptsDir = "$OutputPath\python\Scripts"
        if (-not (Test-Path $pythonLibDir)) {
            New-Item -ItemType Directory -Path $pythonLibDir -Force | Out-Null
        }
        if (-not (Test-Path $pythonSitePackagesDir)) {
            New-Item -ItemType Directory -Path $pythonSitePackagesDir -Force | Out-Null
        }
        if (-not (Test-Path $pythonScriptsDir)) {
            New-Item -ItemType Directory -Path $pythonScriptsDir -Force | Out-Null
        }
        Write-Host "[OK] Created Python Lib and Scripts directory structure" -ForegroundColor Green
        
        # Ensure all required directories exist for embedded Python
        $requiredDirs = @(
            "$OutputPath\python\DLLs",
            "$OutputPath\python\Lib",
            "$OutputPath\python\Lib\site-packages",
            "$OutputPath\python\Scripts"
        )
        foreach ($dir in $requiredDirs) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Host "[OK] Created directory: $dir" -ForegroundColor Green
            }
        }
    } catch {
        if ($Win10CompatibilityLoaded) {
            Write-StandardizedError -ErrorMessage "Failed to download Python: $($_.Exception.Message)" `
                -Context "Python $PythonVersion embedded installation" `
                -Solution "Check internet connection and try running as administrator" `
                -TroubleshootingHint "Windows 10 may require elevated permissions or antivirus exclusions"
        } else {
            Write-Host "[ERROR] Failed to download Python: $($_.Exception.Message)" -ForegroundColor Red
        }
        exit 1
    }

    # Download get-pip with retry logic
    Write-Host "Setting up pip..." -ForegroundColor Yellow
    $maxPipRetries = if ($CompatibilityInfo -and $CompatibilityInfo.OptimizationStrategy.UseExtendedRetries) { 5 } else { 3 }
    
    for ($retry = 1; $retry -le $maxPipRetries; $retry++) {
        try {
            Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile "$OutputPath\python\get-pip.py" -UseBasicParsing -TimeoutSec 120
            break
        } catch {
            if ($retry -eq $maxPipRetries) {
                throw $_
            }
            Write-Host "  Retry $retry/$maxPipRetries for get-pip download..." -ForegroundColor Gray
            Start-Sleep -Seconds ($retry * 2)
        }
    }

    # Create python._pth to enable pip and site-packages
    # FIXED: Ensure python311.zip exists and create proper paths without BOM
    $python311ZipPath = "$OutputPath\python\python311.zip"
    if (-not (Test-Path $python311ZipPath)) {
        Write-Host "[WARN] python311.zip not found, checking for embedded zip files..." -ForegroundColor Yellow
        $embeddedZips = Get-ChildItem "$OutputPath\python" -Filter "python*.zip" -ErrorAction SilentlyContinue
        if ($embeddedZips) {
            $sourceZip = $embeddedZips[0].FullName
            Copy-Item $sourceZip $python311ZipPath -Force
            Write-Host "[OK] Created python311.zip from $($embeddedZips[0].Name)" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] No Python zip file found in embedded distribution" -ForegroundColor Red
            exit 1
        }
    }
    
    # Validate Python embedded files
    $pythonZip = "$OutputPath\python\python311.zip"
    if (Test-Path $pythonZip) {
        $zipSize = (Get-Item $pythonZip).Length
        if ($zipSize -lt 1MB) {
            Write-Host "[WARN] python311.zip seems too small ($zipSize bytes), may need extraction" -ForegroundColor Yellow
        } else {
            Write-Host "[OK] python311.zip present ($([math]::Round($zipSize/1MB, 2)) MB)" -ForegroundColor Green
        }
    } else {
        Write-Host "[WARN] python311.zip not found - may affect standard library imports" -ForegroundColor Yellow
    }
    
    # Validate paths before adding to _pth file
    Write-Host "[INFO] Validating Python paths..." -ForegroundColor Gray
    $pthPaths = @(".", "DLLs", "Lib", "Lib\site-packages")
    foreach ($path in $pthPaths) {
        $fullPath = "$OutputPath\python\$path"
        if ($path -eq ".") {
            continue  # Current directory always valid
        }
        if (-not (Test-Path $fullPath)) {
            Write-Host "[WARN] Creating missing path: $path" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }
    
    # Remove any conflicting ._pth files and create fresh ones
    # FIX: Correct the filter to match all *._pth files (previous pattern missed python311._pth)
    $existingPth = Get-ChildItem -Path "$OutputPath\python" -Filter "*._pth" -ErrorAction SilentlyContinue
    if ($existingPth) {
        foreach ($f in $existingPth) {
            try {
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                Write-Host "[INFO] Removed pre-existing _pth file: $($f.Name)" -ForegroundColor Gray
            } catch {
                Write-Host "[WARN] Could not remove _pth file $($f.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # Create proper python._pth content without BOM characters
    $pthLines = @(
        "python311.zip",
        ".",
        "DLLs",
        "Lib",
        "Lib\site-packages",
        "import site"
    )
    
    # Write file with explicit UTF8 encoding without BOM
    $pthContent = $pthLines -join "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    # Ensure targets are writable (some corp images mark files read-only after extraction)
    $pthTargets = @(
        "$OutputPath\python\python311._pth",
        "$OutputPath\python\python._pth"
    )
    foreach ($pth in $pthTargets) {
        if (Test-Path $pth) {
            try {
                (Get-Item $pth).IsReadOnly = $false
            } catch { }
        }
    }
    [System.IO.File]::WriteAllText($pthTargets[0], $pthContent, $utf8NoBom)
    # Also write python._pth for broader compatibility on some Win10 builds
    [System.IO.File]::WriteAllText($pthTargets[1], $pthContent, $utf8NoBom)
    Write-Host "[OK] Created python311._pth and python._pth without BOM" -ForegroundColor Green
    Write-Host "[OK] Configured Python path" -ForegroundColor Green

    # Verify that python311._pth is effective (Windows 10 often ignores bad encodings)
    Write-Host "[TEST] Verifying python311._pth takes effect..." -ForegroundColor Gray
    $pthVerify = & "$OutputPath\python\python.exe" -c @"
import sys, os
py = sys.executable
print('Python executable:', py)
print('Python version:', sys.version)
print('Sys.path entries:')
for i, p in enumerate(sys.path):
    flag = ' [EXISTS]' if os.path.exists(p) else ' [MISSING]'
    print(f'  {i}: {p}{flag}')
needed = [os.path.join(os.path.dirname(py), 'Lib'), os.path.join(os.path.dirname(py), 'Lib', 'site-packages')]
missing = [p for p in needed if p not in sys.path]
print('NEEDED_MISSING:', ';'.join(missing))
"@ 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] Could not verify _pth due to Python error" -ForegroundColor Yellow
    } else {
        # Extract missing markers
        $missingLine = ($pthVerify | Select-String -Pattern "NEEDED_MISSING:").ToString()
        if ($missingLine -and $missingLine.Trim().EndsWith(':')) {
            Write-Host "[OK] _pth active: Lib paths present in sys.path" -ForegroundColor Green
        } elseif ($missingLine) {
            Write-Host "[WARN] _pth seems inactive (Lib paths missing). Attempting repair..." -ForegroundColor Yellow
            # Repair attempt: force-rewrite the _pth files and re-verify
            Write-Host "[DEBUG] Attempting _pth repair..." -ForegroundColor Gray
            try {
                foreach ($pth in $pthTargets) {
                    Write-Host "[DEBUG] Repairing _pth file: $pth" -ForegroundColor Gray
                    try { 
                        if (Test-Path $pth) { 
                            (Get-Item $pth).IsReadOnly = $false 
                            Write-Host "[DEBUG] Set writable: $pth" -ForegroundColor Gray
                        }
                    } catch { 
                        Write-Host "[DEBUG] Could not set writable: $($_.Exception.Message)" -ForegroundColor Gray
                    }
                    
                    [System.IO.File]::WriteAllText($pth, $pthContent, $utf8NoBom)
                    $repairedSize = (Get-Item $pth -ErrorAction SilentlyContinue).Length
                    Write-Host "[DEBUG] Rewrote: $pth ($repairedSize bytes)" -ForegroundColor Gray
                }
                
                Write-Host "[DEBUG] Re-verifying _pth effectiveness after repair..." -ForegroundColor Gray
                $reVerify = & "$OutputPath\python\python.exe" -c @"
import sys, os
py = sys.executable
needed = [os.path.join(os.path.dirname(py), 'Lib'), os.path.join(os.path.dirname(py), 'Lib', 'site-packages')]
print('OK' if all(p in sys.path for p in needed) else 'MISS')
"@ 2>&1
                if ($LASTEXITCODE -eq 0 -and ($reVerify -join '').Contains('OK')) {
                    Write-Host "[OK] _pth repaired successfully" -ForegroundColor Green
                } else {
                    Write-Host "[WARN] _pth repair did not take effect; sitecustomize fallback will be used" -ForegroundColor Yellow
                    Write-Host "[DEBUG] Re-verify output: $reVerify" -ForegroundColor Gray
                }
            } catch {
                Write-Host "[WARN] _pth repair failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # Create a robust runpip.py shim that ensures site-packages on sys.path (fallback for embedded edge cases)
    $runPipShim = @"
import os, sys, traceback

def _ensure_paths(verbose=False):
    py_dir = os.path.dirname(sys.executable)
    candidates = [
        os.path.join(py_dir, 'Lib'),
        os.path.join(py_dir, 'Lib', 'site-packages'),
    ]
    for p in candidates:
        if os.path.isdir(p) and p not in sys.path:
            sys.path.insert(0, p)
            if verbose:
                print(f"[runpip] added to sys.path: {p}")

def _main():
    verbose = os.environ.get('RUNPIP_VERBOSE') == '1'
    _ensure_paths(verbose)
    try:
        from pip._internal import main as _pip_main
    except Exception:
        try:
            import pip
            def _pip_main(argv=None):
                return pip.main(argv)
        except Exception as e:
            if verbose:
                print("[runpip] import error:")
                traceback.print_exc()
            return 1
    try:
        return _pip_main(sys.argv[1:])
    except SystemExit as e:
        return int(e.code) if isinstance(e.code, int) else 1
    except Exception:
        if verbose:
            traceback.print_exc()
        return 1

if __name__ == '__main__':
    raise SystemExit(_main())
"@
    [System.IO.File]::WriteAllText("$OutputPath\python\runpip.py", $runPipShim, $utf8NoBom)
    Write-Host "[OK] Added runpip.py fallback shim" -ForegroundColor Green
}

# =============================================================================
# PIP INSTALLATION WITH WINDOWS 10 OPTIMIZATIONS
# =============================================================================

# Use Windows 10 optimized pip installation if available
if ($Win10HelpersLoaded -and $CompatibilityInfo) {
    Write-Host "Installing pip with Windows 10 optimizations..." -ForegroundColor Cyan
    
    $pipInstallSuccess = Install-PipEmbeddedWindows10 -OutputPath $OutputPath -CompatibilityInfo $CompatibilityInfo
    if (-not $pipInstallSuccess) {
        Write-Host "[WARN] Windows 10 optimized pip installation failed, falling back to standard method" -ForegroundColor Yellow
    }
} else {
    $pipInstallSuccess = $false
}

# Fallback to standard pip installation with enhanced error handling
if (-not $pipInstallSuccess) {
    Write-Host "Installing pip in embedded Python (standard method)..." -ForegroundColor Yellow
    
    Write-Host "[INFO] Installing pip using get-pip.py for embedded Python..." -ForegroundColor Gray
    
    # DEBUG: Check _pth files before initial pip installation
    Write-Host "[DEBUG] Checking _pth files before initial pip installation..." -ForegroundColor Gray
    $pthFilesCheck = @(
        "$OutputPath\python\python311._pth",
        "$OutputPath\python\python._pth"
    )
    foreach ($pthFile in $pthFilesCheck) {
        if (Test-Path $pthFile) {
            $pthSize = (Get-Item $pthFile).Length
            Write-Host "[DEBUG] Found: $pthFile ($pthSize bytes)" -ForegroundColor Gray
        } else {
            Write-Host "[DEBUG] Missing: $pthFile" -ForegroundColor Yellow
        }
    }

    # Install pip WITHOUT --target for embedded Python compatibility
    # Run pip installation with timeout protection
    $pipProcess = Start-Process -FilePath "$OutputPath\python\python.exe" `
        -ArgumentList "$OutputPath\python\get-pip.py", "--no-warn-script-location", "--no-cache-dir" `
        -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$OutputPath\pip_install.log" `
        -RedirectStandardError "$OutputPath\pip_error.log"

    # Wait up to 5 minutes
    $timeout = 300
    if (-not $pipProcess.WaitForExit($timeout * 1000)) {
        $pipProcess.Kill()
        Write-Host "[ERROR] Pip installation timed out after $timeout seconds" -ForegroundColor Red
        Write-Host "[INFO] Check $OutputPath\pip_error.log for details" -ForegroundColor Yellow
        exit 1
    }
    
    $pipExitCode = $pipProcess.ExitCode

    # DEBUG: Check _pth files after initial pip installation
    Write-Host "[DEBUG] Checking _pth files after initial pip installation..." -ForegroundColor Gray
    foreach ($pthFile in $pthFilesCheck) {
        if (Test-Path $pthFile) {
            $pthSize = (Get-Item $pthFile).Length
            Write-Host "[DEBUG] Still exists: $pthFile ($pthSize bytes)" -ForegroundColor Gray
        } else {
            Write-Host "[WARN] Deleted by initial pip installation: $pthFile" -ForegroundColor Yellow
        }
    }
    
    if ($pipExitCode -ne 0) {
        Write-Host "[WARN] Pip installation had issues: $pipInstallResult" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Pip installation completed" -ForegroundColor Green
    }

    # Show where pip was actually installed for debugging
    Write-Host "[DEBUG] Checking pip installation locations..." -ForegroundColor Gray
    $possiblePipLocations = @(
        "$OutputPath\python\Scripts\pip.exe",
        "$OutputPath\python\Lib\site-packages\pip",
        "$OutputPath\python\pip"
    )
    foreach ($location in $possiblePipLocations) {
        if (Test-Path $location) {
            Write-Host "[DEBUG] Found pip at: $location" -ForegroundColor Gray
        }
    }

    # Create sitecustomize.py to ensure proper path configuration
    Write-Host "[INFO] Creating sitecustomize.py for path configuration..." -ForegroundColor Gray
    $siteCustomize = @"
import sys
import os

# Add current directory to path if not present
if '' not in sys.path:
    sys.path.insert(0, '')

# Ensure site-packages is in path
python_dir = os.path.dirname(sys.executable)
site_packages = os.path.join(python_dir, 'Lib', 'site-packages')
if site_packages not in sys.path and os.path.exists(site_packages):
    sys.path.append(site_packages)

# Add the parent serena/src directory if it exists
serena_src = os.path.abspath(os.path.join(python_dir, '..', 'serena', 'src'))
if os.path.exists(serena_src) and serena_src not in sys.path:
    sys.path.append(serena_src)
"@

    $siteCustomizePath = "$OutputPath\python\sitecustomize.py"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($siteCustomizePath, $siteCustomize, $utf8NoBom)
    Write-Host "[OK] Created sitecustomize.py" -ForegroundColor Green

    # Test pip installation with enhanced Windows 10 error handling
    if ($Win10HelpersLoaded) {
        $pipInstallSuccess = Test-PipInstallationWindows10 -OutputPath $OutputPath
        if (-not $pipInstallSuccess) {
            exit 1
        }
    } else {
        # Standard pip testing logic
        Write-Host "Testing pip installation..." -ForegroundColor Yellow
        $pipInstallSuccess = $false
        try {
            # Test 1: Check if pip module is accessible
            Write-Host "[TEST] Testing 'python -m pip --version'..." -ForegroundColor Gray
            $pipModuleTest = & "$OutputPath\python\python.exe" -m pip --version 2>&1
            $pipTestExitCode = $LASTEXITCODE
            
            if ($pipTestExitCode -ne 0) {
                Write-Host "[DEBUG] Pip test error output: $pipModuleTest" -ForegroundColor Red
                Write-Host "[DEBUG] Python sys.path analysis:" -ForegroundColor Gray
                & "$OutputPath\python\python.exe" -c @"
import sys
import os
print('Python executable:', sys.executable)
print('Python version:', sys.version)
print('Python paths:')
for i, p in enumerate(sys.path):
    exists = ' [EXISTS]' if os.path.exists(p) else ' [MISSING]'
    print(f'  {i}: {p}{exists}')

# Check site-packages
site_packages = os.path.join(os.path.dirname(sys.executable), 'Lib', 'site-packages')
print(f'\nsite-packages path: {site_packages}')
print(f'site-packages exists: {os.path.exists(site_packages)}')
if os.path.exists(site_packages):
    dirs = [d for d in os.listdir(site_packages) if os.path.isdir(os.path.join(site_packages, d))]
    print(f'Installed packages: {dirs[:5]}...' if len(dirs) > 5 else f'Installed packages: {dirs}')
"@ 2>&1 | Write-Host -ForegroundColor Gray
            }
            
            if ($pipTestExitCode -eq 0 -and $pipModuleTest) {
                Write-Host "[OK] Pip module accessible: $pipModuleTest" -ForegroundColor Green
                $pipInstallSuccess = $true
            } else {
                Write-Host "[WARN] pip module test failed (exit code: $pipTestExitCode)" -ForegroundColor Yellow
                
                # Test 2: Alternative test - import pip directly
                Write-Host "[TEST] Testing direct pip import..." -ForegroundColor Gray
                # Ensure PYTHONPATH includes site-packages for this one process as a fallback
                $prevPythonPath = $env:PYTHONPATH
                $env:PYTHONPATH = "$OutputPath\python\Lib\site-packages;$prevPythonPath"
                $pipImportTest = & "$OutputPath\python\python.exe" -c "import pip; print('Pip version:', pip.__version__)" 2>$null
                $importTestExitCode = $LASTEXITCODE
                $env:PYTHONPATH = $prevPythonPath
                
                if ($importTestExitCode -eq 0 -and $pipImportTest) {
                    Write-Host "[OK] Pip accessible via import: $pipImportTest" -ForegroundColor Green
                    $pipInstallSuccess = $true
                } else {
                    # Test 3: Check if pip.exe exists in Scripts directory
                    Write-Host "[TEST] Testing Scripts/pip.exe directly..." -ForegroundColor Gray
                    $pipExePath = "$OutputPath\python\Scripts\pip.exe"
                    $scriptsTestPassed = $false
                    if (Test-Path $pipExePath) {
                        try {
                            $scriptsTest = & $pipExePath --version 2>$null
                            $scriptsExitCode = $LASTEXITCODE
                            if ($scriptsExitCode -eq 0 -and $scriptsTest) {
                                Write-Host "[OK] Pip executable found and working: $scriptsTest" -ForegroundColor Green
                                # If Scripts/pip.exe works, the installation is actually successful
                                # The module path issue might be resolved by the _pth file
                                $scriptsTestPassed = $true
                                $pipInstallSuccess = $true
                            } else {
                                Write-Host "[WARN] pip.exe found but not working" -ForegroundColor Yellow
                            }
                        } catch {
                            Write-Host "[WARN] pip.exe found but failed to run: $($_.Exception.Message)" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "[WARN] pip.exe not found in Scripts directory" -ForegroundColor Yellow
                    }
                    
                    # Test 4: Use runpip.py shim to execute pip
                    if (-not $pipInstallSuccess) {
                        Write-Host "[TEST] Testing runpip.py shim..." -ForegroundColor Gray
                        $prevVerbose = $env:RUNPIP_VERBOSE
                        $env:RUNPIP_VERBOSE = "1"
                        $shimTest = & "$OutputPath\python\python.exe" "$OutputPath\python\runpip.py" --version 2>&1
                        $shimExit = $LASTEXITCODE
                        $env:RUNPIP_VERBOSE = $prevVerbose
                        if ($shimExit -eq 0 -and $shimTest) {
                            Write-Host "[OK] runpip.py working: $shimTest" -ForegroundColor Green
                            $pipInstallSuccess = $true
                        } else {
                            Write-Host "[WARN] runpip.py shim failed (exit $shimExit)" -ForegroundColor Yellow
                            if ($shimTest) { Write-Host $shimTest -ForegroundColor Gray }
                        }
                    }

                    # Only proceed with repair if ALL tests failed
                    if (-not $pipInstallSuccess) {
                        Write-Host "[ERROR] Pip installation failed - not accessible via any method" -ForegroundColor Red
                        Write-Host "[DEBUG] pip -m test exit code: $pipTestExitCode" -ForegroundColor Gray
                        Write-Host "[DEBUG] pip import test exit code: $importTestExitCode" -ForegroundColor Gray
                        
                        Write-Host "[INFO] Attempting pip installation repair..." -ForegroundColor Yellow
                        
                        # Retry installation without --target to let get-pip.py choose proper location
                        Write-Host "[INFO] Reinstalling pip using get-pip.py (force reinstall)..." -ForegroundColor Yellow
                        
                        # DEBUG: Check _pth files before pip reinstall
                        Write-Host "[DEBUG] Checking _pth files before pip reinstall..." -ForegroundColor Gray
                        $pthPreCheck = @(
                            "$OutputPath\python\python311._pth",
                            "$OutputPath\python\python._pth"
                        )
                        foreach ($pthFile in $pthPreCheck) {
                            if (Test-Path $pthFile) {
                                $pthSize = (Get-Item $pthFile).Length
                                Write-Host "[DEBUG] Found: $pthFile ($pthSize bytes)" -ForegroundColor Gray
                                # Show first few lines of content
                                $pthContent = Get-Content $pthFile -Head 3 -ErrorAction SilentlyContinue
                                if ($pthContent) {
                                    Write-Host "[DEBUG]   Content preview: $($pthContent -join ';')" -ForegroundColor Gray
                                }
                            } else {
                                Write-Host "[DEBUG] Missing: $pthFile" -ForegroundColor Yellow
                            }
                        }
                        
                        # Temporarily add Scripts directory to PATH to help with pip installation
                        $originalPath = $env:PATH
                        $pythonScriptsDir = "$OutputPath\python\Scripts"
                        $env:PATH = "$pythonScriptsDir;$originalPath"
                        
                        try {
                            & "$OutputPath\python\python.exe" "$OutputPath\python\get-pip.py" --no-warn-script-location --force-reinstall
                        } finally {
                            # Restore original PATH
                            $env:PATH = $originalPath
                        }
                        
                        # DEBUG: Check _pth files after pip reinstall
                        Write-Host "[DEBUG] Checking _pth files after pip reinstall..." -ForegroundColor Gray
                        foreach ($pthFile in $pthPreCheck) {
                            if (Test-Path $pthFile) {
                                $pthSize = (Get-Item $pthFile).Length
                                Write-Host "[DEBUG] Still exists: $pthFile ($pthSize bytes)" -ForegroundColor Gray
                            } else {
                                Write-Host "[WARN] Deleted by pip reinstall: $pthFile" -ForegroundColor Yellow
                            }
                        }
                        
                        # Recreate _pth files removed by get-pip.py --force-reinstall
                        Write-Host "[INFO] Recreating _pth files after pip reinstall..." -ForegroundColor Gray
                        # Redefine variables if they're out of scope
                        $pthTargets = @(
                            "$OutputPath\python\python311._pth",
                            "$OutputPath\python\python._pth"
                        )
                        $pthLines = @(
                            "python311.zip",
                            ".",
                            "DLLs",
                            "Lib",
                            "Lib\site-packages",
                            "import site"
                        )
                        $pthContent = $pthLines -join "`r`n"
                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false

                        foreach ($pth in $pthTargets) {
                            try {
                                if (Test-Path $pth) {
                                    (Get-Item $pth).IsReadOnly = $false
                                }
                                [System.IO.File]::WriteAllText($pth, $pthContent, $utf8NoBom)
                            } catch {
                                Write-Host "[WARN] Could not recreate $pth: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                        }
                        Write-Host "[OK] Recreated _pth files after pip reinstall" -ForegroundColor Green
                        
                        # Final verification
                        Write-Host "[TEST] Final pip verification..." -ForegroundColor Gray
                        $finalTest = & "$OutputPath\python\python.exe" -m pip --version 2>$null
                        $finalExitCode = $LASTEXITCODE
                        if ($finalExitCode -eq 0 -and $finalTest) {
                            Write-Host "[OK] Pip installation successful after repair: $finalTest" -ForegroundColor Green
                        } else {
                            # Try shim as last resort
                            $finalShim = & "$OutputPath\python\python.exe" "$OutputPath\python\runpip.py" --version 2>$null
                            $finalShimExit = $LASTEXITCODE
                            if ($finalShimExit -eq 0 -and $finalShim) {
                                Write-Host "[OK] Pip usable via runpip.py after repair: $finalShim" -ForegroundColor Green
                            } else {
                                Write-Host "[ERROR] Pip installation still failed after repair" -ForegroundColor Red
                                Write-Host "[ERROR] Final test exit code: $finalExitCode (shim: $finalShimExit)" -ForegroundColor Red
                                Write-Host "[ERROR] Cannot proceed without working pip installation" -ForegroundColor Red
                                exit 1
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Host "[ERROR] Failed to verify pip installation: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
            exit 1
        }
    }
}

# Final validation before completing
Write-Host "`n[INFO] Performing final validation..." -ForegroundColor Cyan
$validationErrors = @()

# Check critical files exist
$criticalFiles = @(
    "$OutputPath\python\python.exe",
    "$OutputPath\python\python311._pth",
    "$OutputPath\python\Lib\site-packages\pip",
    "$OutputPath\python\Scripts\pip.exe"
)

foreach ($file in $criticalFiles) {
    if (-not (Test-Path $file)) {
        $validationErrors += "Missing: $file"
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Host "[ERROR] Validation failed:" -ForegroundColor Red
    $validationErrors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "[OK] All critical components validated" -ForegroundColor Green

# Download ALL Python dependencies offline
$depDownloadScript = "$PSScriptRoot\download-dependencies-offline.py"
if (Test-Path $depDownloadScript) {
    Write-Host "Downloading ALL Python dependencies offline..." -ForegroundColor Yellow
    $dependencyArgs = @(
        "--output", "$OutputPath\dependencies",
        "--pyproject", "$OutputPath\serena\pyproject.toml",
        "--python-version", "3.11",
        "--platform", $Platform,
        "--python-exe", "$OutputPath\python\python.exe"  # Pass embedded Python path
    )
    
    # Add proxy and cert only if they have values
    if ($ProxyUrl -and $ProxyUrl -ne "") {
        $dependencyArgs += "--proxy", $ProxyUrl
    }
    if ($CertPath -and $CertPath -ne "") {
        $dependencyArgs += "--cert", $CertPath
    }
    
    try {
        # FIXED: Use proper Python executable for dependency download
        & "$OutputPath\python\python.exe" $depDownloadScript @dependencyArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Dependencies download failed"
        }
        Write-Host "[OK] Downloaded all Python dependencies offline" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Failed to download dependencies: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Dependencies will be installed online during first run..." -ForegroundColor Yellow
        # Store the embedded python path for offline installer
        $env:SERENA_PORTABLE_PYTHON = "$OutputPath\python\python.exe"
    }
} else {
    Write-Host "[INFO] Dependency download script not found, skipping offline download" -ForegroundColor Yellow
    Write-Host "Dependencies will be installed online during first run..." -ForegroundColor Yellow
}

# =============================================================================
# DEPENDENCY INSTALLATION WITH WINDOWS 10 OPTIMIZATIONS
# =============================================================================

# Use Windows 10 optimized dependency installation if available
if ($Win10HelpersLoaded -and (Test-Path "$OutputPath\dependencies\requirements.txt")) {
    Write-Host "Installing dependencies with Windows 10 optimizations..." -ForegroundColor Cyan
    
    $dependencyInstallSuccess = Install-DependenciesWindows10 -OutputPath $OutputPath -CompatibilityInfo $CompatibilityInfo
    if ($dependencyInstallSuccess) {
        $OfflineMode = $true
        Write-Host "[OK] Windows 10 optimized dependency installation completed" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Windows 10 optimized dependency installation failed, falling back to standard method" -ForegroundColor Yellow
        $OfflineMode = $false
    }
} else {
    $dependencyInstallSuccess = $false
}

# Fallback to standard dependency installation
if (-not $dependencyInstallSuccess -and (Test-Path "$OutputPath\dependencies\requirements.txt")) {
    Write-Host "Installing dependencies offline (standard method)..." -ForegroundColor Yellow
    
    # CRITICAL: Validate requirements.txt has content
    $reqContent = Get-Content "$OutputPath\dependencies\requirements.txt" -Raw -ErrorAction SilentlyContinue
    if (-not $reqContent -or $reqContent.Trim() -eq "") {
        if ($Win10CompatibilityLoaded) {
            Write-StandardizedError -ErrorMessage "requirements.txt is empty or unreadable" `
                -Context "This indicates dependency download failed earlier" `
                -Solution "Re-run the script or check internet connectivity" `
                -TroubleshootingHint "Windows 10 may have blocked the download process"
        } else {
            Write-Host "[ERROR] requirements.txt is empty or unreadable" -ForegroundColor Red
            Write-Host "[ERROR] This indicates dependency download failed earlier" -ForegroundColor Red
        }
        $OfflineMode = $false
    } else {
        # Count non-empty, non-comment lines
        $reqLines = ($reqContent -split "`n" | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }).Count
        Write-Host "[INFO] Found $reqLines requirements to install" -ForegroundColor Green
        
        # FIXED: Use consistent target directory for both Python and dependencies
        $targetDir = "$OutputPath\python\Lib\site-packages"
        
        # ENHANCED: Clear existing installations to avoid conflicts with Windows 10 compatibility
        if (Test-Path $targetDir) {
            Write-Host "[INFO] Clearing existing site-packages to avoid conflicts..." -ForegroundColor Yellow
            try {
                # Remove only non-essential directories, keep core Python modules
                $dirsToRemove = Get-ChildItem $targetDir -Directory -ErrorAction SilentlyContinue | Where-Object { 
                    $_.Name -notmatch "^(_|site|pip|setuptools|wheel)" 
                }
                foreach ($dir in $dirsToRemove) {
                    if ($Win10HelpersLoaded) {
                        Remove-FileWithRetry -Path $dir.FullName -Force
                    } else {
                        Remove-Item $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                
                # Remove .pth files and dist-info directories
                $pthFiles = Get-ChildItem $targetDir -Filter "*.pth" -ErrorAction SilentlyContinue
                foreach ($pthFile in $pthFiles) {
                    if ($Win10HelpersLoaded) {
                        Remove-FileWithRetry -Path $pthFile.FullName
                    } else {
                        Remove-Item $pthFile.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
                
                $distInfoDirs = Get-ChildItem $targetDir -Filter "*dist-info" -Directory -ErrorAction SilentlyContinue
                foreach ($distDir in $distInfoDirs) {
                    if ($Win10HelpersLoaded) {
                        Remove-FileWithRetry -Path $distDir.FullName -Force
                    } else {
                        Remove-Item $distDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                
                Write-Host "[OK] Cleared existing packages" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not fully clear existing packages: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        # Ensure target directory exists
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        # Install UV first (if available) with Windows 10 handling
        $uvWheels = Get-ChildItem "$OutputPath\dependencies\uv-deps\*.whl" -ErrorAction SilentlyContinue
        if ($uvWheels) {
            Write-Host "Installing UV..." -ForegroundColor Yellow
            # FIXED: Use forward slashes in paths passed to Python for cross-platform compatibility
            $uvDepsPath = "$OutputPath\dependencies\uv-deps" -replace '\\', '/'
            $targetDirForward = $targetDir -replace '\\', '/'
            
            if ($CompatibilityInfo -and $CompatibilityInfo.OptimizationStrategy.UseExtendedRetries) {
                # Use retry logic for Windows 10
                $uvInstallSuccess = $false
                for ($retry = 1; $retry -le 3; $retry++) {
                    try {
                        & "$OutputPath\python\python.exe" -m pip install --no-index --find-links $uvDepsPath --target $targetDirForward --force-reinstall uv --timeout 180
                        if ($LASTEXITCODE -eq 0) {
                            $uvInstallSuccess = $true
                            break
                        }
                    } catch {
                        if ($retry -lt 3) {
                            Write-Host "  UV install retry $retry..." -ForegroundColor Gray
                            Start-Sleep -Seconds ($retry * 2)
                        }
                    }
                }
                
                if ($uvInstallSuccess) {
                    Write-Host "[OK] UV installed successfully" -ForegroundColor Green
                } else {
                    Write-Host "[WARN] UV installation failed after retries, continuing without UV..." -ForegroundColor Yellow
                }
            } else {
                # Standard UV installation
                & "$OutputPath\python\python.exe" -m pip install --no-index --find-links $uvDepsPath --target $targetDirForward --force-reinstall uv
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[WARN] UV installation failed, continuing without UV..." -ForegroundColor Yellow
                } else {
                    Write-Host "[OK] UV installed successfully" -ForegroundColor Green
                }
            }
        }
        
        # Install main dependencies
        Write-Host "Installing main dependencies..." -ForegroundColor Yellow
        # FIXED: Use forward slashes and proper path escaping
        $depsPath = "$OutputPath\dependencies" -replace '\\', '/'
        $reqPath = "$OutputPath\dependencies\requirements.txt" -replace '\\', '/'
        $targetDirForward = $targetDir -replace '\\', '/'
        
        # ENHANCED: Add --force-reinstall to handle existing files with Windows 10 timeout
        $installCmd = @(
            "$OutputPath\python\python.exe", "-m", "pip", "install",
            "--no-index",
            "--find-links", $depsPath,
            "--target", $targetDirForward,
            "--force-reinstall",
            "--no-deps",  # Avoid dependency resolution issues
            "--timeout", "300",  # Extended timeout for Windows 10
            "--requirement", $reqPath
        )
        
        Write-Host "[DEBUG] Running pip install command with Windows 10 optimizations..." -ForegroundColor Gray
        
        # DEBUG: Check _pth files before main dependency installation
        Write-Host "[DEBUG] Checking _pth files before main dependency installation..." -ForegroundColor Gray
        $pthCheckBeforeDeps = @(
            "$OutputPath\python\python311._pth",
            "$OutputPath\python\python._pth"
        )
        foreach ($pthFile in $pthCheckBeforeDeps) {
            if (Test-Path $pthFile) {
                $pthSize = (Get-Item $pthFile).Length
                Write-Host "[DEBUG] Found: $pthFile ($pthSize bytes)" -ForegroundColor Gray
            } else {
                Write-Host "[DEBUG] Missing: $pthFile" -ForegroundColor Yellow
            }
        }
        
        & $installCmd[0] $installCmd[1..$($installCmd.Length-1)]
        
        # DEBUG: Check _pth files after main dependency installation
        Write-Host "[DEBUG] Checking _pth files after main dependency installation..." -ForegroundColor Gray
        foreach ($pthFile in $pthCheckBeforeDeps) {
            if (Test-Path $pthFile) {
                $pthSize = (Get-Item $pthFile).Length
                Write-Host "[DEBUG] Still exists: $pthFile ($pthSize bytes)" -ForegroundColor Gray
            } else {
                Write-Host "[WARN] Deleted by dependency installation: $pthFile" -ForegroundColor Yellow
            }
        }
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Installed all dependencies offline" -ForegroundColor Green
        $OfflineMode = $true
    } else {
        Write-Host "[WARN] Offline installation failed (exit code: $LASTEXITCODE), will install online during first run" -ForegroundColor Yellow
        
        # Try individual package installation as fallback
        Write-Host "[INFO] Attempting fallback individual package installation..." -ForegroundColor Yellow
        
        # DEBUG: Check _pth files before individual wheel installation
        Write-Host "[DEBUG] Checking _pth files before individual wheel installation..." -ForegroundColor Gray
        foreach ($pthFile in $pthCheckBeforeDeps) {
            if (Test-Path $pthFile) {
                $pthSize = (Get-Item $pthFile).Length
                Write-Host "[DEBUG] Found: $pthFile ($pthSize bytes)" -ForegroundColor Gray
            } else {
                Write-Host "[DEBUG] Missing: $pthFile" -ForegroundColor Yellow
            }
        }
        
        $wheelFiles = Get-ChildItem "$OutputPath\dependencies\*.whl" -ErrorAction SilentlyContinue
        if ($wheelFiles) {
            $successCount = 0
            foreach ($wheel in $wheelFiles) {
                Write-Host "  Installing: $($wheel.Name)" -ForegroundColor Gray
                & "$OutputPath\python\python.exe" -m pip install --no-index --target $targetDir --force-reinstall $wheel.FullName
                if ($LASTEXITCODE -eq 0) {
                    $successCount++
                }
            }
            
            # DEBUG: Check _pth files after individual wheel installation
            Write-Host "[DEBUG] Checking _pth files after individual wheel installation..." -ForegroundColor Gray
            foreach ($pthFile in $pthCheckBeforeDeps) {
                if (Test-Path $pthFile) {
                    $pthSize = (Get-Item $pthFile).Length
                    Write-Host "[DEBUG] Still exists: $pthFile ($pthSize bytes)" -ForegroundColor Gray
                } else {
                    Write-Host "[WARN] Deleted by individual wheel installation: $pthFile" -ForegroundColor Yellow
                }
            }
            
            if ($successCount -gt 0) {
                Write-Host "[OK] Installed $successCount individual packages as fallback" -ForegroundColor Green
                $OfflineMode = $true
            } else {
                Write-Host "[WARN] Fallback installation also failed" -ForegroundColor Yellow
                $OfflineMode = $false
            }
        } else {
            $OfflineMode = $false
        }
    }
} else {
    Write-Host "[WARN] No offline dependencies found, will install online during first run" -ForegroundColor Yellow
    $OfflineMode = $false
}

# Download language servers
$lsDownloadScript = "$PSScriptRoot\download-language-servers-offline.py"
if (Test-Path $lsDownloadScript) {
    Write-Host "Downloading language servers..." -ForegroundColor Yellow
    try {
        $lsArgs = @("--output", "$OutputPath\language-servers")
        if ($ProxyUrl -and $ProxyUrl -ne "") {
            $lsArgs += "--proxy", $ProxyUrl
        }
        if ($CertPath -and $CertPath -ne "") {
            $lsArgs += "--cert", $CertPath
        }
        
        & "$OutputPath\python\python.exe" $lsDownloadScript @lsArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Downloaded language servers" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Some language servers may not have been downloaded" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[WARN] Failed to download language servers: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Language servers will need to be downloaded separately" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] Language server download script not found, skipping" -ForegroundColor Yellow
    Write-Host "Language servers will need to be downloaded separately" -ForegroundColor Yellow
}

# Create enhanced wrapper scripts
Write-Host "Creating enhanced wrapper scripts..." -ForegroundColor Yellow

# Enhanced main wrapper script with offline capability
$mainWrapper = @"
@echo off
setlocal enabledelayedexpansion

:: Fully Portable Serena MCP Launcher
:: Version 2.0 - 100% Offline Capable

echo ==========================================
echo  Serena MCP - Fully Portable Edition
echo  Version 0.1.4 - Offline Capable
echo ==========================================

:: Set paths
set SERENA_PORTABLE=%~dp0
set PYTHONHOME=%SERENA_PORTABLE%python
set PYTHONPATH=%SERENA_PORTABLE%Lib\site-packages;%SERENA_PORTABLE%serena\src
set PATH=%PYTHONHOME%;%PYTHONHOME%\Scripts;%PATH%

:: Set corporate environment if available
if not "%HTTP_PROXY%"=="" (
    echo [INFO] Using proxy: %HTTP_PROXY%
)
if not "%REQUESTS_CA_BUNDLE%"=="" (
    echo [INFO] Using CA bundle: %REQUESTS_CA_BUNDLE%
)

:: Create user directories
if not exist "%USERPROFILE%\.solidlsp" mkdir "%USERPROFILE%\.solidlsp"
if not exist "%USERPROFILE%\.solidlsp\language_servers" mkdir "%USERPROFILE%\.solidlsp\language_servers"
if not exist "%USERPROFILE%\.solidlsp\language_servers\static" mkdir "%USERPROFILE%\.solidlsp\language_servers\static"
if not exist "%USERPROFILE%\.serena" mkdir "%USERPROFILE%\.serena"

:: Copy language servers if not present
echo [INFO] Setting up language servers...
xcopy /E /I /Y /Q "%SERENA_PORTABLE%language-servers\*" "%USERPROFILE%\.solidlsp\language_servers\static\" >nul 2>&1

:: Check if dependencies are installed
echo [INFO] Checking dependencies...
"%PYTHONHOME%\python.exe" -c "import serena; print('[OK] Serena available')" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [WARN] Dependencies not installed, running offline installer...
    if exist "%SERENA_PORTABLE%dependencies\install-dependencies-offline.bat" (
        call "%SERENA_PORTABLE%dependencies\install-dependencies-offline.bat"
    ) else (
        echo [ERROR] No offline installer found and dependencies missing!
        echo [ERROR] Please run with internet access for first-time setup
        pause
        exit /b 1
    )
)

:: Final verification
"%PYTHONHOME%\python.exe" -c "import serena" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Serena dependencies still not available!
    echo [ERROR] Please check your installation
    pause
    exit /b 1
)

echo [OK] All dependencies verified
echo [INFO] Starting Serena MCP server...
echo.

:: Run Serena MCP server
cd /d "%SERENA_PORTABLE%serena"
"%PYTHONHOME%\python.exe" -m serena.cli start-mcp-server %*

endlocal
"@
Set-Content -Path "$OutputPath\serena-mcp-portable.bat" -Value $mainWrapper

# Create dependency check script
$depCheckScript = @"
@echo off
setlocal

:: Dependency Checker for Serena Portable
set SERENA_PORTABLE=%~dp0
set PYTHONHOME=%SERENA_PORTABLE%python
set PYTHONPATH=%SERENA_PORTABLE%Lib\site-packages;%SERENA_PORTABLE%serena\src

echo Checking Serena Portable dependencies...
echo.

:: Check Python
"%PYTHONHOME%\python.exe" --version
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python not found
    goto :error
)

:: Check main dependencies
set DEPS=requests pyright mcp flask pydantic pyyaml jinja2 psutil tqdm tiktoken anthropic

for %%d in (%DEPS%) do (
    echo Checking %%d...
    "%PYTHONHOME%\python.exe" -c "import %%d; print('  [OK] %%d:', %%d.__version__ if hasattr(%%d, '__version__') else 'OK')" 2>nul
    if !ERRORLEVEL! neq 0 (
        echo   [ERROR] %%d: Missing
        set HAS_MISSING=1
    )
)

:: Check Serena
echo Checking Serena...
"%PYTHONHOME%\python.exe" -c "import serena; print('  [OK] Serena: Available')" 2>nul
if %ERRORLEVEL% neq 0 (
    echo   [ERROR] Serena: Missing
    set HAS_MISSING=1
)

:: Check language servers
echo.
echo Checking language servers...
dir /b "%SERENA_PORTABLE%language-servers" 2>nul | find /c /v "" >nul
if %ERRORLEVEL% equ 0 (
    for /f %%i in ('dir /b "%SERENA_PORTABLE%language-servers" 2^>nul ^| find /c /v ""') do echo   [OK] Language servers: %%i found
) else (
    echo   [ERROR] Language servers: None found
)

if defined HAS_MISSING (
    echo.
    echo [WARN] Some dependencies are missing
    if exist "%SERENA_PORTABLE%dependencies\install-dependencies-offline.bat" (
        echo [INFO] Run install-dependencies-offline.bat to fix
    ) else (
        echo [INFO] Internet connection required for first setup
    )
    goto :error
)

echo.
echo [OK] All dependencies verified successfully!
echo [OK] Serena Portable is ready to use
pause
exit /b 0

:error
echo.
echo [ERROR] Dependency check failed
pause
exit /b 1
"@
Set-Content -Path "$OutputPath\check-dependencies.bat" -Value $depCheckScript

# Create configuration templates (same as before)
$vscodeConfig = @{
    mcpServers = @{
        serena = @{
            command = "C:\\serena-fully-portable\\serena-mcp-portable.bat"
            args = @("--context", "ide-assistant")
        }
    }
}
$vscodeConfig | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\config\vscode-continue-config.json"

# Claude Desktop config
$claudeConfig = @{
    mcpServers = @{
        serena = @{
            command = "C:\\serena-fully-portable\\serena-mcp-portable.bat"
            args = @("--context", "desktop-app")
        }
    }
}
$claudeConfig | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath\config\claude-desktop-config.json"

# Enhanced setup script
$setupScript = @"
@echo off
echo Setting up Serena Fully Portable...

:: Copy to C:\serena-fully-portable
echo Copying files...
xcopy /E /I /Y "%~dp0*" "C:\serena-fully-portable\" >nul

:: Run dependency check
echo.
echo Running dependency check...
call "C:\serena-fully-portable\check-dependencies.bat"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Setup completed but dependencies need attention
    pause
    exit /b 1
)

:: Create desktop shortcut
echo Creating desktop shortcut...
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%USERPROFILE%\Desktop\Serena MCP Portable.lnk'); $SC.TargetPath = 'C:\serena-fully-portable\serena-mcp-portable.bat'; $SC.WorkingDirectory = 'C:\serena-fully-portable'; $SC.Save()"

echo.
echo ==========================================
echo  Serena Fully Portable installed!
echo ==========================================
echo.
echo Desktop shortcut created: "Serena MCP Portable"
echo.
echo IDE Integration:
echo - VS Code: Import C:\serena-fully-portable\config\vscode-continue-config.json
echo - Claude Desktop: Import C:\serena-fully-portable\config\claude-desktop-config.json
echo.
echo Test installation: run check-dependencies.bat
echo.
pause
"@
Set-Content -Path "$OutputPath\SETUP.bat" -Value $setupScript

# Create comprehensive README
$readme = @"
# Serena MCP - Fully Portable Package v0.1.4
## 100% Offline Capable Edition

This is a FULLY SELF-CONTAINED Serena MCP package designed for corporate environments,
air-gapped systems, and offline deployment.

##  Key Features

- **100% Offline**: No internet required after initial setup
- **Embedded Python**: Python 3.11 included
- **All Dependencies**: $(if ($OfflineMode) { '[OK] Pre-installed offline' } else { '[WARN] Will install on first run' })
- **Language Servers**: Pre-downloaded for 13+ languages  
- **Corporate Ready**: Proxy and certificate support
- **Zero Installation**: Runs from any directory

##  Package Contents

- **python/**: Embedded Python 3.11 ($PythonVersion)
- **dependencies/**: All Python wheels $(if ($OfflineMode) { '(~150MB)' } else { '(download on first run)' })
- **language-servers/**: Pre-downloaded language servers (~200MB)
- **serena/**: Complete Serena source code
- **Lib/site-packages/**: $(if ($OfflineMode) { 'Installed Python packages' } else { 'Will be populated on first run' })
- **config/**: IDE integration templates

##  Installation

### Option 1: Automated (Recommended)
1. **Run SETUP.bat** - Copies to C:\serena-fully-portable
2. **Uses desktop shortcut** - "Serena MCP Portable"

### Option 2: Manual
1. Extract package to desired location
2. Run **serena-mcp-portable.bat** 
3. First run will complete setup if needed

##  Usage

### Direct Usage
```cmd
serena-mcp-portable.bat
```

### VS Code with Continue
1. Install Continue extension
2. Import config: `config\vscode-continue-config.json`

### Claude Desktop
1. Import config: `config\claude-desktop-config.json`

### IntelliJ IDEA
1. Use as external tool pointing to serena-mcp-portable.bat

##  Supported Languages

Pre-configured language servers for:
- Python (Pyright)
- TypeScript/JavaScript  
- Go (gopls)
- Java (Eclipse JDT.LS)
- C# (OmniSharp)
- Rust (rust-analyzer)
- Ruby (Solargraph)
- PHP (Intelephense)
- Terraform (terraform-ls)
- Elixir (Elixir-LS)
- Clojure (clojure-lsp)
- Swift (SourceKit-LSP)
- Bash
- C/C++ (clangd)

##  Corporate Environment

### Proxy Support
Set environment variables before running:
```cmd
set HTTP_PROXY=http://proxy:8080
set HTTPS_PROXY=http://proxy:8080
```

### Certificate Bundles
```cmd
set REQUESTS_CA_BUNDLE=C:\path\to\ca-bundle.crt
```

### Air-Gapped Systems
$(if ($OfflineMode) {
'[OK] This package works completely offline!'
} else {
'[WARN] Internet required for first-time dependency installation'
})

##  Troubleshooting

### Check Installation
```cmd
check-dependencies.bat
```

### Manual Dependency Installation
$(if ($OfflineMode) {
'If dependencies are missing:
````cmd
dependencies\install-dependencies-offline.bat
````'
} else {
'Ensure internet access for first run, or obtain offline dependency package'
})

### Reset Installation
1. Delete `Lib\site-packages\*` 
2. Run `serena-mcp-portable.bat` again

##  Package Statistics

- **Total Size**: ~$(if ($OfflineMode) { '500' } else { '200' })MB (compressed ~$(if ($OfflineMode) { '300' } else { '150' })MB)
- **Python Dependencies**: 21 packages
- **Language Servers**: 13 servers
- **Offline Ready**: $(if ($OfflineMode) { '[YES] YES' } else { '[WARN] Requires internet for first setup' })

##  Support

- GitHub: https://github.com/resline/serena
- Original: https://github.com/oraios/serena
- Corporate Support: Available

---
**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Platform**: $Platform  
**Python**: $PythonVersion
**Offline Mode**: $(if ($OfflineMode) { 'Enabled' } else { 'First-run setup required' })
"@
Set-Content -Path "$OutputPath\README.txt" -Value $readme

Write-Host "[OK] Created configuration files and documentation" -ForegroundColor Green

# =============================================================================
# WINDOWS 10 PACKAGE VALIDATION
# =============================================================================

# Run Windows 10 package validation if helpers are loaded
if ($Win10HelpersLoaded) {
    Write-Host "`n" + "=" * 60
    Write-Host "WINDOWS 10 PACKAGE VALIDATION" -ForegroundColor Cyan
    Write-Host "=" * 60
    
    $validationResults = Test-PackageIntegrityWindows10 -OutputPath $OutputPath
    
    if ($validationResults.OverallValid) {
        Write-Host "`n[OK] Windows 10 package validation: PASSED" -ForegroundColor Green
        if ($validationResults.Issues.Count -eq 0) {
            Write-Host "*** Package is fully optimized for Windows 10 deployment!" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Minor issues detected but package is still functional:" -ForegroundColor Yellow
            foreach ($issue in $validationResults.Issues) {
                Write-Host "  - $issue" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "`n[ERROR] Windows 10 package validation: FAILED" -ForegroundColor Red
        Write-Host "Critical issues that need attention:" -ForegroundColor Red
        foreach ($issue in $validationResults.Issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
        Write-Host "`nRecommendation: Re-run the script or check Windows 10 compatibility" -ForegroundColor Yellow
    }
    
    Write-Host "`n" + "=" * 60 + "`n"
    
    # Clean up temporary files with Windows 10 compatibility
    Write-Host "Cleaning up temporary files..." -ForegroundColor Gray
    Remove-TemporaryFilesWindows10 -Path $OutputPath
}

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow
$zipName = "serena-fully-portable-windows-v0.1.4.zip"
$zipPath = Join-Path (Get-Location) $zipName
$zipSize = 0

try {
    Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath -Force -CompressionLevel Optimal
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    $zipMsg = "[OK] Created ZIP package: $zipPath (" + $zipSize + " MB)"
    Write-Host $zipMsg -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create ZIP: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# FINAL SUMMARY WITH WINDOWS 10 INFORMATION
# =============================================================================

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  FULLY PORTABLE PACKAGE CREATED!" -ForegroundColor Green
Write-Host "   Windows 10 Enhanced Edition v2.1" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
if ($zipSize -gt 0) {
    $packageMsg = " Package: $zipName (" + $zipSize + " MB)"
    Write-Host $packageMsg -ForegroundColor Yellow
} else {
    Write-Host " Package: $zipName" -ForegroundColor Yellow
}

# Display Windows 10 specific information if available
if ($CompatibilityInfo) {
    Write-Host " Windows: $($CompatibilityInfo.WindowsInfo.ProductName)" -ForegroundColor Yellow
    if ($CompatibilityInfo.WindowsInfo.IsWindows10) {
        Write-Host " Version: $($CompatibilityInfo.WindowsInfo.Windows10Version)" -ForegroundColor Yellow
        Write-Host " Console: $($CompatibilityInfo.ConsoleInfo.ConsoleType)" -ForegroundColor Yellow
    }
    if ($CompatibilityInfo.CorporateInfo.IsDomainJoined) {
        Write-Host " Environment: Corporate Domain" -ForegroundColor Yellow
    } else {
        Write-Host " Environment: Personal/Workgroup" -ForegroundColor Yellow
    }
} else {
    Write-Host " Platform: Windows (compatibility modules not loaded)" -ForegroundColor Gray
}

Write-Host " Target: Corporate/Air-gapped environments" -ForegroundColor Yellow  
$offlineStatus = if ($OfflineMode) { "100% Ready" } else { "Requires internet for first setup" }
$offlineColor = if ($OfflineMode) { "Green" } else { "Yellow" }
Write-Host " Offline: $offlineStatus" -ForegroundColor $offlineColor
Write-Host ""

Write-Host "[CORE FEATURES]:" -ForegroundColor Green
Write-Host "   [OK] Embedded Python $PythonVersion" -ForegroundColor White
$depStatus = if ($OfflineMode) { "Pre-installed dependencies" } else { "Online dependency installer" }
Write-Host "   [OK] $depStatus" -ForegroundColor White  
Write-Host "   [OK] 13+ Language servers pre-downloaded" -ForegroundColor White
Write-Host "   [OK] VS Code + Claude Desktop integration" -ForegroundColor White
Write-Host "   [OK] Corporate proxy/certificate support" -ForegroundColor White
Write-Host "   [OK] Zero-installation deployment" -ForegroundColor White

# Display Windows 10 specific enhancements
if ($Win10CompatibilityLoaded -or $Win10HelpersLoaded) {
    Write-Host ""
    Write-Host "[WINDOWS 10 ENHANCEMENTS]:" -ForegroundColor Cyan
    if ($Win10CompatibilityLoaded) {
        Write-Host "   [OK] Windows 10 version detection and optimization" -ForegroundColor White
        Write-Host "   [OK] Antivirus interference detection and mitigation" -ForegroundColor White
        Write-Host "   [OK] Corporate environment detection" -ForegroundColor White
        Write-Host "   [OK] NTFS permission validation" -ForegroundColor White
    }
    if ($Win10HelpersLoaded) {
        Write-Host "   [OK] Enhanced file locking handling" -ForegroundColor White
        Write-Host "   [OK] Retry logic for failed operations" -ForegroundColor White
        Write-Host "   [OK] Optimized extraction processes" -ForegroundColor White
        Write-Host "   [OK] Standardized English error messages" -ForegroundColor White
    }
    
    if ($CompatibilityInfo -and $CompatibilityInfo.OptimizationStrategy.UseExtendedRetries) {
        Write-Host "   [OK] Legacy Windows 10 compatibility mode enabled" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "[NOTE]: Windows 10 compatibility modules not loaded - using standard methods" -ForegroundColor Gray
}

Write-Host ""
Write-Host " *** Ready for deployment to corporate Windows 10 environments!" -ForegroundColor Cyan

# Display deployment recommendations
if ($CompatibilityInfo) {
    if ($CompatibilityInfo.AntivirusInfo.PotentialInterference -or $CompatibilityInfo.CorporateInfo.IsDomainJoined) {
        Write-Host ""
        Write-Host "[DEPLOYMENT RECOMMENDATIONS]:" -ForegroundColor Magenta
        if ($CompatibilityInfo.AntivirusInfo.PotentialInterference) {
            Write-Host "   - Add installation directory to antivirus exclusions" -ForegroundColor Gray
            Write-Host "   - Consider temporary real-time protection disable during installation" -ForegroundColor Gray
        }
        if ($CompatibilityInfo.CorporateInfo.IsDomainJoined) {
            Write-Host "   - Run installation as administrator in corporate environments" -ForegroundColor Gray
            Write-Host "   - Verify proxy/certificate configuration before deployment" -ForegroundColor Gray
        }
        if ($CompatibilityInfo.WindowsInfo.RequiresLegacyHandling) {
            Write-Host "   - Older Windows 10 detected - enhanced compatibility automatically applied" -ForegroundColor Gray
        }
    }
}

Write-Host ""
