# PowerShell Code Comparison: Workflow vs Test Script

## Original Workflow Code (Lines 395-462 from test-windows-portable.yml)

### Install dependencies step:
```powershell
shell: powershell
run: |
  Write-Host "Installing project dependencies..." -ForegroundColor Green
  uv sync --dev
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Failed to install dependencies" -ForegroundColor Red
    exit 1
  }
  Write-Host "[OK] Dependencies installed" -ForegroundColor Green
```

### Verify development tools step:
```powershell
shell: powershell  
run: |
  Write-Host "Verifying development tools..." -ForegroundColor Cyan
  
  Write-Host "Checking black..." -ForegroundColor Yellow
  uv run black --version
  if ($LASTEXITCODE -ne 0) {
      Write-Host "✗ black verification failed" -ForegroundColor Red
      exit 1
  }
  Write-Host "✓ black is available" -ForegroundColor Green
  
  Write-Host "Checking ruff..." -ForegroundColor Yellow  
  uv run ruff --version
  if ($LASTEXITCODE -ne 0) {
      Write-Host "✗ ruff verification failed" -ForegroundColor Red
      exit 1
  }
  Write-Host "✓ ruff is available" -ForegroundColor Green
  
  Write-Host "Checking mypy..." -ForegroundColor Yellow
  uv run mypy --version
  if ($LASTEXITCODE -ne 0) {
      Write-Host "✗ mypy verification failed" -ForegroundColor Red  
      exit 1
  }
  Write-Host "✓ mypy is available" -ForegroundColor Green
```

### Run formatting check step:
```powershell
shell: powershell
run: |
  Write-Host "Running code formatting check..." -ForegroundColor Green
  # Use direct commands instead of poethepoet
  uv run black --check src scripts test
  $blackResult = $LASTEXITCODE
  uv run ruff check src scripts test
  $ruffResult = $LASTEXITCODE
  
  if ($blackResult -eq 0 -and $ruffResult -eq 0) {
    Write-Host "[OK] Code formatting check passed" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] Code formatting issues found" -ForegroundColor Red
    exit 1
  }
```

### Run type checking step:
```powershell
shell: powershell
run: |
  Write-Host "Running type checking..." -ForegroundColor Green
  # Use direct mypy command instead of poethepoet
  uv run mypy src/serena
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Type checking passed" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] Type checking failed" -ForegroundColor Red
    exit 1
  }
```

## Test Script Modifications

The test script (`test-quality-check.ps1`) includes the following changes:
1. **Simulated commands**: Actual `uv` commands are replaced with `Write-Host` statements showing what would be executed
2. **Manual LASTEXITCODE**: Set to 0 to simulate successful execution
3. **Unicode cleanup**: Replaced ✓ and ✗ with [OK] and [FAIL] for better compatibility
4. **Comments**: Added explanatory comments for each simulated step

## Validation Results

✅ **Syntax Validation**: PASSED
- All braces and parentheses are balanced
- Proper PowerShell constructs are used
- Variable assignments follow PowerShell syntax
- Exit statements are correctly formatted
- No syntax errors detected

✅ **Code Accuracy**: The test script accurately represents the workflow code structure
✅ **Compatibility**: No Unicode characters that could cause encoding issues
✅ **Functionality**: Script can be executed to validate PowerShell syntax independently

## Purpose

This test script serves to:
1. Validate PowerShell syntax independently of YAML
2. Simulate the quality-check job workflow logic
3. Identify potential PowerShell syntax errors before CI/CD execution
4. Provide a local testing mechanism for PowerShell code