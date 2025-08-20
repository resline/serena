#!/usr/bin/env pwsh
# Test PowerShell script syntax

$scripts = @(
    "create-fully-portable-package.ps1",
    "create-portable-package.ps1", 
    "corporate-setup-windows.ps1"
)

$hasErrors = $false

foreach ($script in $scripts) {
    Write-Host "Testing $script..." -ForegroundColor Yellow
    
    $scriptPath = Join-Path $PSScriptRoot $script
    
    if (Test-Path $scriptPath) {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath,
            [ref]$tokens,
            [ref]$errors
        )
        
        if ($errors.Count -eq 0) {
            Write-Host "  [OK] No syntax errors found" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Found $($errors.Count) syntax error(s):" -ForegroundColor Red
            foreach ($error in $errors) {
                Write-Host "    Line $($error.Extent.StartLineNumber): $($error.Message)" -ForegroundColor Red
            }
            $hasErrors = $true
        }
    } else {
        Write-Host "  [SKIP] File not found" -ForegroundColor Yellow
    }
}

if ($hasErrors) {
    Write-Host "`n[FAILED] Some scripts have syntax errors" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[SUCCESS] All scripts passed syntax check" -ForegroundColor Green
    exit 0
}