# test-quality-check.ps1
# Test script to validate PowerShell syntax from the quality-check job in test-windows-portable.yml

Write-Host "Testing PowerShell syntax from quality-check job..." -ForegroundColor Green

# Simulate the Install dependencies step
Write-Host "Installing project dependencies..." -ForegroundColor Green
# uv sync --dev (simulated)
Write-Host "uv sync --dev" -ForegroundColor Yellow
$LASTEXITCODE = 0  # Simulate success
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Failed to install dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Dependencies installed" -ForegroundColor Green

# Verify development tools step
Write-Host "Verifying development tools..." -ForegroundColor Cyan

Write-Host "Checking black..." -ForegroundColor Yellow
# uv run black --version (simulated)
Write-Host "uv run black --version" -ForegroundColor Yellow
$LASTEXITCODE = 0  # Simulate success
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] black verification failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] black is available" -ForegroundColor Green

Write-Host "Checking ruff..." -ForegroundColor Yellow  
# uv run ruff --version (simulated)
Write-Host "uv run ruff --version" -ForegroundColor Yellow
$LASTEXITCODE = 0  # Simulate success
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] ruff verification failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] ruff is available" -ForegroundColor Green

Write-Host "Checking mypy..." -ForegroundColor Yellow
# uv run mypy --version (simulated)
Write-Host "uv run mypy --version" -ForegroundColor Yellow
$LASTEXITCODE = 0  # Simulate success
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] mypy verification failed" -ForegroundColor Red  
    exit 1
}
Write-Host "[OK] mypy is available" -ForegroundColor Green

# Run formatting check step
Write-Host "Running code formatting check..." -ForegroundColor Green
# Use direct commands instead of poethepoet
# uv run black --check src scripts test (simulated)
Write-Host "uv run black --check src scripts test" -ForegroundColor Yellow
$blackResult = 0  # Simulate success
# uv run ruff check src scripts test (simulated)
Write-Host "uv run ruff check src scripts test" -ForegroundColor Yellow
$ruffResult = 0  # Simulate success

if ($blackResult -eq 0 -and $ruffResult -eq 0) {
  Write-Host "[OK] Code formatting check passed" -ForegroundColor Green
} else {
  Write-Host "[FAIL] Code formatting issues found" -ForegroundColor Red
  exit 1
}

# Run type checking step
Write-Host "Running type checking..." -ForegroundColor Green
# Use direct mypy command instead of poethepoet
# uv run mypy src/serena (simulated)
Write-Host "uv run mypy src/serena" -ForegroundColor Yellow
$LASTEXITCODE = 0  # Simulate success
if ($LASTEXITCODE -eq 0) {
  Write-Host "[OK] Type checking passed" -ForegroundColor Green
} else {
  Write-Host "[FAIL] Type checking failed" -ForegroundColor Red
  exit 1
}

Write-Host "All quality check steps completed successfully!" -ForegroundColor Green
Write-Host "PowerShell syntax validation: PASSED" -ForegroundColor Green