# Portable Package Windows 10 Helper Functions
# Specific helpers for create-fully-portable-package.ps1 with Windows 10 optimizations
# Addresses file locking, extraction issues, and build process optimizations

param()

# Import the Windows 10 compatibility module
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    . "$scriptDir\windows10-compatibility.ps1"
}
catch {
    Write-Warning "Windows 10 compatibility module not found - using fallback methods"
}

# =============================================================================
# ENHANCED PYTHON INSTALLATION FOR WINDOWS 10
# =============================================================================

function Install-PythonEmbeddedWindows10 {
    <#
    .SYNOPSIS
        Installs embedded Python with Windows 10-specific optimizations
    .DESCRIPTION
        Handles Windows 10 file locking and antivirus interference during Python installation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [string]$PythonVersion,
        
        [hashtable]$CompatibilityInfo = @{}
    )
    
    Write-Host "Installing Python $PythonVersion with Windows 10 optimizations..." -ForegroundColor Yellow
    
    $pythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
    $pythonZip = "$OutputPath\python-embedded.zip"
    
    # Apply Windows 10 specific optimizations
    $strategy = $CompatibilityInfo.OptimizationStrategy
    if (-not $strategy) {
        $winInfo = Get-WindowsVersionInfo
        $strategy = Get-Windows10OptimizationStrategy -WindowsVersion $winInfo
    }
    
    try {
        # Download with retry logic
        if ($strategy.UseExtendedRetries) {
            Write-Host "[WINDOWS 10] Using extended retry logic for download..." -ForegroundColor Gray
            $maxRetries = 5
        } else {
            $maxRetries = 3
        }
        
        $downloadSuccess = $false
        for ($retry = 1; $retry -le $maxRetries; $retry++) {
            try {
                Write-Host "  Attempt $retry/$maxRetries - Downloading Python..." -ForegroundColor Gray
                Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonZip -UseBasicParsing -TimeoutSec 300
                $downloadSuccess = $true
                break
            }
            catch {
                if ($retry -eq $maxRetries) {
                    throw $_
                }
                Write-Host "    Download failed, retrying in $($retry * 2) seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds ($retry * 2)
            }
        }
        
        if (-not $downloadSuccess) {
            throw "Failed to download Python after $maxRetries attempts"
        }
        
        Write-Host "[OK] Python download completed" -ForegroundColor Green
        
        # Extract with Windows 10 file locking handling
        Write-Host "Extracting Python with Windows 10 compatibility..." -ForegroundColor Yellow
        
        # Check if antivirus exclusion is needed
        if ($strategy.RequireAntivirusExclusions) {
            Write-Host "[WINDOWS 10 TIP] Consider adding $OutputPath to antivirus exclusions for faster extraction" -ForegroundColor Magenta
        }
        
        Invoke-SafeFileOperation {
            Expand-Archive -Path $pythonZip -DestinationPath "$OutputPath\python" -Force
        }
        
        # Clean up with retry
        Invoke-SafeFileOperation {
            Remove-Item $pythonZip -ErrorAction Stop
        }
        
        Write-Host "[OK] Python embedded extracted successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-StandardizedError -ErrorMessage "Failed to install embedded Python: $($_.Exception.Message)" `
            -Context "Windows 10 Python installation" `
            -Solution "Try running as administrator or add installation directory to antivirus exclusions" `
            -TroubleshootingHint "Windows 10 may require elevated permissions for system directory access"
        return $false
    }
}

# =============================================================================
# ENHANCED PIP INSTALLATION WITH WINDOWS 10 COMPATIBILITY
# =============================================================================

function Install-PipEmbeddedWindows10 {
    <#
    .SYNOPSIS
        Installs pip in embedded Python with Windows 10 compatibility
    .DESCRIPTION
        Addresses Windows 10 module access issues and file locking
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [hashtable]$CompatibilityInfo = @{}
    )
    
    Write-Host "Installing pip with Windows 10 optimizations..." -ForegroundColor Yellow
    
    $pythonExe = "$OutputPath\python\python.exe"
    $getPipPath = "$OutputPath\python\get-pip.py"
    $targetDir = "$OutputPath\python\Lib\site-packages"
    
    # Ensure target directory exists
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    try {
        # Download get-pip.py with retry
        Write-Host "Downloading get-pip.py..." -ForegroundColor Gray
        Invoke-SafeFileOperation {
            Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPipPath -UseBasicParsing
        }
        
        # Create enhanced python._pth for Windows 10
        Write-Host "Configuring Python path for Windows 10..." -ForegroundColor Gray
        $pthLines = @(
            "python311.zip",
            ".",
            "DLLs", 
            "Lib",
            "Lib\site-packages",
            "import site"
        )
        $pthContent = $pthLines -join "`n"
        Set-Content -Path "$OutputPath\python\python311._pth" -Value $pthContent -Encoding UTF8
        
        # Install pip with Windows 10 specific parameters
        Write-Host "Installing pip..." -ForegroundColor Gray
        $pipInstallArgs = @(
            $getPipPath,
            "--no-warn-script-location",
            "--force-reinstall",
            "--no-cache-dir"
        )
        
        # Add timeout for Windows 10 (sometimes hangs)
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $pythonExe
        $processInfo.Arguments = $pipInstallArgs -join " "
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        
        # Wait with timeout (Windows 10 can be slow)
        $timeoutMs = 300000  # 5 minutes
        if (-not $process.WaitForExit($timeoutMs)) {
            $process.Kill()
            throw "Pip installation timed out after 5 minutes"
        }
        
        if ($process.ExitCode -ne 0) {
            $stderr = $process.StandardError.ReadToEnd()
            throw "Pip installation failed with exit code $($process.ExitCode): $stderr"
        }
        
        Write-Host "[OK] Pip installed successfully" -ForegroundColor Green
        
        # Verify pip installation with Windows 10 specific tests
        Write-Host "Verifying pip installation..." -ForegroundColor Gray
        return Test-PipInstallationWindows10 -OutputPath $OutputPath
    }
    catch {
        Write-StandardizedError -ErrorMessage "Failed to install pip: $($_.Exception.Message)" `
            -Context "Windows 10 pip installation" `
            -Solution "Try running as administrator or check antivirus settings" `
            -TroubleshootingHint "Windows 10 embedded Python requires specific path configuration"
        return $false
    }
}

function Test-PipInstallationWindows10 {
    <#
    .SYNOPSIS
        Tests pip installation with Windows 10 specific verification
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    $pythonExe = "$OutputPath\python\python.exe"
    
    # Test 1: Python module access
    try {
        $pipModuleTest = & $pythonExe -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Pip module accessible: $pipModuleTest" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "  [WARN] Pip module test failed" -ForegroundColor Yellow
    }
    
    # Test 2: Direct import test
    try {
        $importTest = & $pythonExe -c "import pip; print('Pip version:', pip.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Pip import successful: $importTest" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "  [WARN] Pip import test failed" -ForegroundColor Yellow
    }
    
    # Test 3: Repair attempt for Windows 10
    Write-Host "  [CONFIG] Attempting Windows 10 pip repair..." -ForegroundColor Yellow
    try {
        $repairArgs = @(
            "$OutputPath\python\get-pip.py",
            "--no-warn-script-location",
            "--force-reinstall",
            "--no-cache-dir",
            "--no-deps"
        )
        
        & $pythonExe @repairArgs 2>$null
        
        # Final verification
        $finalTest = & $pythonExe -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Pip repair successful: $finalTest" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "  [ERROR] Pip repair failed" -ForegroundColor Red
    }
    
    return $false
}

# =============================================================================
# ENHANCED DEPENDENCY INSTALLATION FOR WINDOWS 10
# =============================================================================

function Install-DependenciesWindows10 {
    <#
    .SYNOPSIS
        Installs Python dependencies with Windows 10 optimizations
    .DESCRIPTION
        Handles Windows 10 file locking and permission issues during dependency installation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [hashtable]$CompatibilityInfo = @{}
    )
    
    $dependenciesDir = "$OutputPath\dependencies"
    $requirementsFile = "$dependenciesDir\requirements.txt"
    $targetDir = "$OutputPath\Lib\site-packages"
    $pythonExe = "$OutputPath\python\python.exe"
    
    if (-not (Test-Path $requirementsFile)) {
        Write-Host "[INFO] No offline dependencies found - will install online during first run" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "Installing dependencies with Windows 10 optimizations..." -ForegroundColor Yellow
    
    # Validate requirements file
    $reqContent = Get-Content $requirementsFile -Raw -ErrorAction SilentlyContinue
    if (-not $reqContent -or $reqContent.Trim() -eq "") {
        Write-Host "[WARN] Requirements file is empty" -ForegroundColor Yellow
        return $false
    }
    
    $reqLines = ($reqContent -split "`n" | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith("#") }).Count
    Write-Host "[INFO] Installing $reqLines requirements..." -ForegroundColor Green
    
    # Prepare target directory with Windows 10 cleanup
    Write-Host "Preparing installation directory for Windows 10..." -ForegroundColor Gray
    if (Test-Path $targetDir) {
        try {
            # Selective cleanup to avoid Windows 10 locking issues
            $dirsToRemove = Get-ChildItem $targetDir -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -notmatch "^(_|site|pip|setuptools|wheel)" }
            
            foreach ($dir in $dirsToRemove) {
                Remove-FileWithRetry -Path $dir.FullName -Force
            }
            
            # Remove .pth files and dist-info directories
            Get-ChildItem $targetDir -Filter "*.pth" -ErrorAction SilentlyContinue | 
                ForEach-Object { Remove-FileWithRetry -Path $_.FullName }
            
            Get-ChildItem $targetDir -Filter "*dist-info" -Directory -ErrorAction SilentlyContinue | 
                ForEach-Object { Remove-FileWithRetry -Path $_.FullName -Force }
                
            Write-Host "[OK] Installation directory cleaned" -ForegroundColor Green
        }
        catch {
            Write-Host "[WARN] Partial cleanup only: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Ensure target directory exists
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    # Install UV first if available (with Windows 10 handling)
    $uvWheels = Get-ChildItem "$dependenciesDir\uv-deps\*.whl" -ErrorAction SilentlyContinue
    if ($uvWheels) {
        Write-Host "Installing UV with Windows 10 compatibility..." -ForegroundColor Yellow
        try {
            $uvDepsPath = "$dependenciesDir\uv-deps" -replace '\\', '/'
            $targetDirForward = $targetDir -replace '\\', '/'
            
            & $pythonExe -m pip install --no-index --find-links $uvDepsPath --target $targetDirForward --force-reinstall uv
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] UV installed successfully" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "[WARN] UV installation failed, continuing..." -ForegroundColor Yellow
        }
    }
    
    # Install main dependencies with Windows 10 optimizations
    Write-Host "Installing main dependencies..." -ForegroundColor Yellow
    
    try {
        $depsPath = $dependenciesDir -replace '\\', '/'
        $reqPath = $requirementsFile -replace '\\', '/'
        $targetDirForward = $targetDir -replace '\\', '/'
        
        $installArgs = @(
            "-m", "pip", "install",
            "--no-index",
            "--find-links", $depsPath,
            "--target", $targetDirForward,
            "--force-reinstall",
            "--no-deps",
            "--requirement", $reqPath,
            "--timeout", "300",
            "--retries", "3"
        )
        
        Write-Host "[DEBUG] Running pip install with Windows 10 parameters..." -ForegroundColor Gray
        & $pythonExe @installArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Dependencies installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[WARN] Bulk installation failed, trying individual packages..." -ForegroundColor Yellow
            return Install-IndividualPackagesWindows10 -OutputPath $OutputPath
        }
    }
    catch {
        Write-Host "[WARN] Main installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return Install-IndividualPackagesWindows10 -OutputPath $OutputPath
    }
}

function Install-IndividualPackagesWindows10 {
    <#
    .SYNOPSIS
        Fallback method to install packages individually on Windows 10
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    $dependenciesDir = "$OutputPath\dependencies"
    $targetDir = "$OutputPath\Lib\site-packages"
    $pythonExe = "$OutputPath\python\python.exe"
    
    Write-Host "Attempting individual package installation for Windows 10..." -ForegroundColor Yellow
    
    $wheelFiles = Get-ChildItem "$dependenciesDir\*.whl" -ErrorAction SilentlyContinue
    if (-not $wheelFiles) {
        Write-Host "[WARN] No wheel files found for individual installation" -ForegroundColor Yellow
        return $false
    }
    
    $successCount = 0
    $totalFiles = $wheelFiles.Count
    
    foreach ($wheel in $wheelFiles) {
        Write-Host "  Installing: $($wheel.Name)..." -ForegroundColor Gray
        
        try {
            # Use safe file operations for Windows 10
            Invoke-SafeFileOperation {
                & $pythonExe -m pip install --no-index --target $targetDir --force-reinstall $wheel.FullName
                if ($LASTEXITCODE -ne 0) {
                    throw "Pip returned exit code $LASTEXITCODE"
                }
            }
            
            Write-Host "    [OK] Success" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "    [WARN] Failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "[INFO] Individual installation: $successCount/$totalFiles packages succeeded" -ForegroundColor Cyan
    
    if ($successCount -gt 0) {
        Write-Host "[OK] Partial installation successful" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[WARN] Individual installation failed" -ForegroundColor Yellow
        return $false
    }
}

# =============================================================================
# ENHANCED ARCHIVE EXTRACTION FOR WINDOWS 10
# =============================================================================

function Expand-ArchiveWindows10 {
    <#
    .SYNOPSIS
        Extracts archives with Windows 10 compatibility and antivirus handling
    .DESCRIPTION
        Addresses Windows 10 file locking issues during archive extraction
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [switch]$Force
    )
    
    Write-Host "Extracting with Windows 10 compatibility: $([System.IO.Path]::GetFileName($Path))..." -ForegroundColor Gray
    
    # Get Windows version info for strategy
    $winInfo = Get-WindowsVersionInfo
    $strategy = Get-Windows10OptimizationStrategy -WindowsVersion $winInfo
    
    try {
        # Pre-extraction setup for Windows 10
        if ($strategy.RequireAntivirusExclusions) {
            Write-Host "[WINDOWS 10 TIP] Antivirus may slow extraction - consider temporary exclusions" -ForegroundColor Magenta
        }
        
        # Use retry logic for Windows 10 file locking
        Invoke-SafeFileOperation -MaxRetries 5 -RetryDelayMs 1000 {
            if ($Force) {
                Expand-Archive -Path $Path -DestinationPath $DestinationPath -Force -ErrorAction Stop
            } else {
                Expand-Archive -Path $Path -DestinationPath $DestinationPath -ErrorAction Stop
            }
        }
        
        Write-Host "  [OK] Extraction completed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-StandardizedError -ErrorMessage "Archive extraction failed: $($_.Exception.Message)" `
            -Context "Windows 10 archive extraction for $([System.IO.Path]::GetFileName($Path))" `
            -Solution "Try running as administrator or add directory to antivirus exclusions" `
            -TroubleshootingHint "Windows 10 may lock files during extraction - retry often succeeds"
        
        return $false
    }
}

# =============================================================================
# ENHANCED CLEANUP OPERATIONS FOR WINDOWS 10
# =============================================================================

function Remove-TemporaryFilesWindows10 {
    <#
    .SYNOPSIS
        Removes temporary files with Windows 10 file locking handling
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [string[]]$Patterns = @("*.tmp", "*.temp", "*_download", "*.zip")
    )
    
    Write-Host "Cleaning temporary files with Windows 10 compatibility..." -ForegroundColor Gray
    
    foreach ($pattern in $Patterns) {
        try {
            $filesToRemove = Get-ChildItem -Path $Path -Filter $pattern -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $filesToRemove) {
                Remove-FileWithRetry -Path $file.FullName
                Write-Host "  [OK] Removed: $($file.Name)" -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host "  [WARN] Could not remove some $pattern files: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# WINDOWS 10 PACKAGE VALIDATION
# =============================================================================

function Test-PackageIntegrityWindows10 {
    <#
    .SYNOPSIS
        Validates package integrity with Windows 10 specific checks
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-Host "Validating package integrity for Windows 10..." -ForegroundColor Cyan
    
    $validationResults = @{
        PythonInstalled = $false
        PipWorking = $false
        DependenciesInstalled = $false
        LanguageServersPresent = $false
        ScriptsCreated = $false
        OverallValid = $false
        Issues = @()
    }
    
    # Test Python installation
    $pythonExe = "$OutputPath\python\python.exe"
    if (Test-Path $pythonExe) {
        try {
            $pythonVersion = & $pythonExe --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $validationResults.PythonInstalled = $true
                Write-Host "  [OK] Python: $pythonVersion" -ForegroundColor Green
            }
        }
        catch {
            $validationResults.Issues += "Python executable not working properly"
        }
    } else {
        $validationResults.Issues += "Python executable not found"
    }
    
    # Test pip functionality
    if ($validationResults.PythonInstalled) {
        try {
            $pipVersion = & $pythonExe -m pip --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $validationResults.PipWorking = $true
                Write-Host "  [OK] Pip: $pipVersion" -ForegroundColor Green
            }
        }
        catch {
            $validationResults.Issues += "Pip module not accessible"
        }
    }
    
    # Test dependencies
    $sitePackages = "$OutputPath\Lib\site-packages"
    if (Test-Path $sitePackages) {
        $packages = Get-ChildItem $sitePackages -Directory | Where-Object { $_.Name -notmatch "^(__pycache__|.*\.dist-info)$" }
        if ($packages.Count -gt 5) {  # Expect several packages
            $validationResults.DependenciesInstalled = $true
            Write-Host "  [OK] Dependencies: $($packages.Count) packages installed" -ForegroundColor Green
        } else {
            $validationResults.Issues += "Insufficient dependencies installed ($($packages.Count) packages)"
        }
    } else {
        $validationResults.Issues += "Site-packages directory not found"
    }
    
    # Test language servers
    $languageServers = "$OutputPath\language-servers"
    if (Test-Path $languageServers) {
        $servers = Get-ChildItem $languageServers -Directory
        if ($servers.Count -gt 3) {  # Expect several language servers
            $validationResults.LanguageServersPresent = $true
            Write-Host "  [OK] Language Servers: $($servers.Count) servers available" -ForegroundColor Green
        } else {
            $validationResults.Issues += "Few language servers available ($($servers.Count) servers)"
        }
    } else {
        $validationResults.Issues += "Language servers directory not found"
    }
    
    # Test scripts
    $mainScript = "$OutputPath\serena-mcp-portable.bat"
    if (Test-Path $mainScript) {
        $validationResults.ScriptsCreated = $true
        Write-Host "  [OK] Scripts: Main launcher created" -ForegroundColor Green
    } else {
        $validationResults.Issues += "Main launcher script not created"
    }
    
    # Overall validation
    $validationResults.OverallValid = $validationResults.PythonInstalled -and 
                                     $validationResults.PipWorking -and
                                     $validationResults.DependenciesInstalled -and
                                     $validationResults.ScriptsCreated
    
    if ($validationResults.OverallValid) {
        Write-Host "[OK] Package validation successful!" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Package validation issues found:" -ForegroundColor Yellow
        foreach ($issue in $validationResults.Issues) {
            Write-Host "  - $issue" -ForegroundColor Gray
        }
    }
    
    return $validationResults
}

# =============================================================================
# MODULE EXPORTS
# =============================================================================

# Export all functions
Export-ModuleMember -Function @(
    'Install-PythonEmbeddedWindows10',
    'Install-PipEmbeddedWindows10',
    'Test-PipInstallationWindows10',
    'Install-DependenciesWindows10',
    'Install-IndividualPackagesWindows10',
    'Expand-ArchiveWindows10',
    'Remove-TemporaryFilesWindows10',
    'Test-PackageIntegrityWindows10'
)