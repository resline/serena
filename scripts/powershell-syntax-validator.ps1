# PowerShell Syntax Validation Script
# Created by Claude Code for comprehensive syntax checking

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

# Initialize counters and tracking variables
$SyntaxErrors = @()
$Warnings = @()
$LineNumber = 0

# Counters for balanced constructs
$BraceStack = @()
$ParenStack = @()
$HereStringStack = @()
$QuoteStack = @()
$InHereString = $false
$HereStringTerminator = $null

Write-Host "PowerShell Syntax Validator" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host "Analyzing: $FilePath" -ForegroundColor Yellow
Write-Host ""

# Check if file exists
if (-not (Test-Path $FilePath)) {
    Write-Host "[ERROR] File not found: $FilePath" -ForegroundColor Red
    exit 1
}

# Read the file content
try {
    $Content = Get-Content -Path $FilePath -Raw
    $Lines = Get-Content -Path $FilePath
} catch {
    Write-Host "[ERROR] Could not read file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] File size: $($Content.Length) characters" -ForegroundColor Green
Write-Host "[INFO] Line count: $($Lines.Count)" -ForegroundColor Green
Write-Host ""

# Function to add syntax error
function Add-SyntaxError {
    param([int]$Line, [string]$Message, [string]$Severity = "ERROR")
    $Script:SyntaxErrors += [PSCustomObject]@{
        Line = $Line
        Message = $Message
        Severity = $Severity
    }
}

# Function to check if we're inside a string literal
function Test-InsideString {
    param([string]$TextBefore, [int]$Position)
    
    $inSingleQuote = $false
    $inDoubleQuote = $false
    $escapeNext = $false
    
    for ($i = 0; $i -lt $Position; $i++) {
        $char = $TextBefore[$i]
        
        if ($escapeNext) {
            $escapeNext = $false
            continue
        }
        
        switch ($char) {
            '`' { $escapeNext = $true }
            "'" { 
                if (-not $inDoubleQuote) { $inSingleQuote = -not $inSingleQuote }
            }
            '"' { 
                if (-not $inSingleQuote) { $inDoubleQuote = -not $inDoubleQuote }
            }
        }
    }
    
    return $inSingleQuote -or $inDoubleQuote
}

Write-Host "Starting detailed syntax analysis..." -ForegroundColor Yellow

# Process each line
for ($i = 0; $i -lt $Lines.Count; $i++) {
    $line = $Lines[$i]
    $LineNumber = $i + 1
    $trimmedLine = $line.Trim()
    
    # Skip empty lines and comments (unless inside here-string)
    if (-not $InHereString -and ($trimmedLine -eq "" -or $trimmedLine.StartsWith("#"))) {
        continue
    }
    
    # Check for here-string start
    if (-not $InHereString -and $line -match '@".*$') {
        $InHereString = $true
        $HereStringTerminator = '"@'
        $HereStringStack += [PSCustomObject]@{ Line = $LineNumber; Terminator = $HereStringTerminator }
        Write-Host "[DEBUG] Here-string started at line $LineNumber" -ForegroundColor Gray
        continue
    } elseif (-not $InHereString -and $line -match "@'.*$") {
        $InHereString = $true
        $HereStringTerminator = "'@"
        $HereStringStack += [PSCustomObject]@{ Line = $LineNumber; Terminator = $HereStringTerminator }
        Write-Host "[DEBUG] Here-string (single quote) started at line $LineNumber" -ForegroundColor Gray
        continue
    }
    
    # Check for here-string end
    if ($InHereString -and $trimmedLine -eq $HereStringTerminator) {
        $InHereString = $false
        $HereStringTerminator = $null
        if ($HereStringStack.Count -gt 0) {
            $HereStringStack = $HereStringStack[0..($HereStringStack.Count - 2)]
        }
        Write-Host "[DEBUG] Here-string ended at line $LineNumber" -ForegroundColor Gray
        continue
    }
    
    # If we're inside a here-string, check for embedded expressions
    if ($InHereString) {
        # Count $(...) expressions inside here-string
        $dollarParenMatches = [regex]::Matches($line, '\$\(')
        $closingParenMatches = [regex]::Matches($line, '\)')
        
        foreach ($match in $dollarParenMatches) {
            $ParenStack += [PSCustomObject]@{ Line = $LineNumber; Type = "DollarParen"; Position = $match.Index }
        }
        
        # Check for unbalanced parens in $() expressions
        $parenCount = 0
        for ($pos = 0; $pos -lt $line.Length; $pos++) {
            $char = $line[$pos]
            if ($char -eq '(' -and $pos -gt 0 -and $line[$pos-1] -eq '$') {
                $parenCount++
            } elseif ($char -eq ')') {
                $parenCount--
                if ($parenCount -lt 0) {
                    Add-SyntaxError $LineNumber "Unmatched closing parenthesis in here-string expression"
                }
            }
        }
        
        # Check for nested quotes in $() expressions - they should be single quotes
        if ($line -match '\$\([^)]*"[^)]*\)') {
            Add-SyntaxError $LineNumber "Double quotes found inside `$(...) expression within here-string. Use single quotes instead." "WARNING"
        }
        
        continue
    }
    
    # Outside here-string - check regular PowerShell syntax
    
    # Count braces
    $openBraces = [regex]::Matches($line, '\{').Count
    $closeBraces = [regex]::Matches($line, '\}').Count
    
    for ($j = 0; $j -lt $openBraces; $j++) {
        $BraceStack += [PSCustomObject]@{ Line = $LineNumber; Type = "Brace" }
    }
    
    for ($j = 0; $j -lt $closeBraces; $j++) {
        if ($BraceStack.Count -eq 0) {
            Add-SyntaxError $LineNumber "Unmatched closing brace"
        } else {
            $BraceStack = $BraceStack[0..($BraceStack.Count - 2)]
        }
    }
    
    # Count parentheses (outside strings)
    $openParens = 0
    $closeParens = 0
    $inString = $false
    $stringChar = $null
    
    for ($pos = 0; $pos -lt $line.Length; $pos++) {
        $char = $line[$pos]
        $prevChar = if ($pos -gt 0) { $line[$pos-1] } else { $null }
        
        # Handle string detection
        if (($char -eq '"' -or $char -eq "'") -and $prevChar -ne '`') {
            if (-not $inString) {
                $inString = $true
                $stringChar = $char
            } elseif ($char -eq $stringChar) {
                $inString = $false
                $stringChar = $null
            }
        }
        
        if (-not $inString) {
            if ($char -eq '(') { $openParens++ }
            if ($char -eq ')') { $closeParens++ }
        }
    }
    
    # Add to stacks
    for ($j = 0; $j -lt $openParens; $j++) {
        $ParenStack += [PSCustomObject]@{ Line = $LineNumber; Type = "Paren" }
    }
    
    for ($j = 0; $j -lt $closeParens; $j++) {
        if ($ParenStack.Count -eq 0) {
            Add-SyntaxError $LineNumber "Unmatched closing parenthesis"
        } else {
            $ParenStack = $ParenStack[0..($ParenStack.Count - 2)]
        }
    }
    
    # Check for unterminated strings on single line
    $singleQuoteCount = ($line.ToCharArray() | Where-Object { $_ -eq "'" }).Count
    $doubleQuoteCount = ($line.ToCharArray() | Where-Object { $_ -eq '"' }).Count
    
    if ($singleQuoteCount % 2 -ne 0) {
        Add-SyntaxError $LineNumber "Unterminated single quote string" "WARNING"
    }
    if ($doubleQuoteCount % 2 -ne 0) {
        Add-SyntaxError $LineNumber "Unterminated double quote string" "WARNING"
    }
    
    # Check specific problematic patterns
    if ($line -match '(?<!`)["''][^"'']*$') {
        Add-SyntaxError $LineNumber "Possible unterminated string at end of line" "WARNING"
    }
    
    # Check for common PowerShell syntax issues
    if ($line -match '\s+\|\s*$') {
        Add-SyntaxError $LineNumber "Pipeline operator at end of line without continuation" "WARNING"
    }
}

Write-Host ""
Write-Host "Syntax Analysis Complete" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

# Check for unmatched constructs
if ($BraceStack.Count -gt 0) {
    Add-SyntaxError $BraceStack[-1].Line "Unmatched opening brace (total unmatched: $($BraceStack.Count))"
}

if ($ParenStack.Count -gt 0) {
    Add-SyntaxError $ParenStack[-1].Line "Unmatched opening parenthesis (total unmatched: $($ParenStack.Count))"
}

if ($HereStringStack.Count -gt 0) {
    Add-SyntaxError $HereStringStack[-1].Line "Unterminated here-string (expected: $($HereStringStack[-1].Terminator))"
}

# Display summary
Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "--------" -ForegroundColor Cyan
Write-Host "Braces - Balanced: $(if ($BraceStack.Count -eq 0) { 'YES' } else { 'NO (' + $BraceStack.Count + ' unmatched)' })"
Write-Host "Parentheses - Balanced: $(if ($ParenStack.Count -eq 0) { 'YES' } else { 'NO (' + $ParenStack.Count + ' unmatched)' })"
Write-Host "Here-strings - Terminated: $(if ($HereStringStack.Count -eq 0) { 'YES' } else { 'NO (' + $HereStringStack.Count + ' unterminated)' })"
Write-Host ""

# Display errors and warnings
if ($SyntaxErrors.Count -eq 0) {
    Write-Host "[OK] No syntax errors found!" -ForegroundColor Green
} else {
    Write-Host "[FOUND] $($SyntaxErrors.Count) syntax issues:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($error in $SyntaxErrors | Sort-Object Line) {
        $color = if ($error.Severity -eq "ERROR") { "Red" } else { "Yellow" }
        Write-Host "Line $($error.Line): [$($error.Severity)] $($error.Message)" -ForegroundColor $color
    }
}

# Try PowerShell's built-in syntax checking
Write-Host ""
Write-Host "Running PowerShell Built-in Syntax Check..." -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

try {
    $null = [System.Management.Automation.PSParser]::Tokenize($Content, [ref]$null)
    Write-Host "[OK] PowerShell parser validation: PASSED" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] PowerShell parser validation: FAILED" -ForegroundColor Red
    Write-Host "Parser Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Final verdict
Write-Host ""
Write-Host "FINAL VERDICT:" -ForegroundColor Magenta
Write-Host "==============" -ForegroundColor Magenta

if ($SyntaxErrors.Count -eq 0) {
    Write-Host "[OK] Syntax validation: PASSED" -ForegroundColor Green
    Write-Host "[OK] File appears to be syntactically correct" -ForegroundColor Green
} else {
    $errorCount = ($SyntaxErrors | Where-Object { $_.Severity -eq "ERROR" }).Count
    $warningCount = ($SyntaxErrors | Where-Object { $_.Severity -eq "WARNING" }).Count
    
    if ($errorCount -eq 0) {
        Write-Host "[WARN] Syntax validation: PASSED with warnings" -ForegroundColor Yellow
        Write-Host "[WARN] $warningCount warnings found but no critical errors" -ForegroundColor Yellow
    } else {
        Write-Host "[X] Syntax validation: FAILED" -ForegroundColor Red
        Write-Host "[X] $errorCount critical errors, $warningCount warnings" -ForegroundColor Red
    }
}

Write-Host ""