#!/bin/bash
# validate-powershell-syntax.sh
# Basic PowerShell syntax validation using text analysis

echo "Validating PowerShell syntax in test-quality-check.ps1..."

# Check if the file exists
if [ ! -f "test-quality-check.ps1" ]; then
    echo "❌ ERROR: test-quality-check.ps1 not found"
    exit 1
fi

# Basic syntax checks
errors=0

echo "🔍 Checking for common PowerShell syntax issues..."

# Check for unmatched braces
open_braces=$(grep -o '{' test-quality-check.ps1 | wc -l)
close_braces=$(grep -o '}' test-quality-check.ps1 | wc -l)
if [ "$open_braces" -ne "$close_braces" ]; then
    echo "❌ ERROR: Unmatched braces (open: $open_braces, close: $close_braces)"
    ((errors++))
else
    echo "✅ Braces are balanced"
fi

# Check for unmatched parentheses
open_parens=$(grep -o '(' test-quality-check.ps1 | wc -l)
close_parens=$(grep -o ')' test-quality-check.ps1 | wc -l)
if [ "$open_parens" -ne "$close_parens" ]; then
    echo "❌ ERROR: Unmatched parentheses (open: $open_parens, close: $close_parens)"
    ((errors++))
else
    echo "✅ Parentheses are balanced"
fi

# Check for common PowerShell constructs
if grep -q 'Write-Host' test-quality-check.ps1; then
    echo "✅ Contains Write-Host commands"
else
    echo "⚠️  WARNING: No Write-Host commands found"
fi

if grep -q '\$LASTEXITCODE' test-quality-check.ps1; then
    echo "✅ Contains \$LASTEXITCODE references"
else
    echo "⚠️  WARNING: No \$LASTEXITCODE references found"
fi

# Check for proper if statement syntax
if grep -q 'if.*{' test-quality-check.ps1; then
    echo "✅ Contains if statements with proper opening braces"
else
    echo "⚠️  WARNING: No if statements found or missing opening braces"
fi

# Check for proper variable assignments
if grep -q '\$[a-zA-Z][a-zA-Z0-9_]*\s*=' test-quality-check.ps1; then
    echo "✅ Contains variable assignments"
else
    echo "⚠️  WARNING: No variable assignments found"
fi

# Check for proper exit statements
if grep -q 'exit [0-9]' test-quality-check.ps1; then
    echo "✅ Contains proper exit statements"
else
    echo "⚠️  WARNING: No proper exit statements found"
fi

# Look for potentially problematic patterns
if grep -q '`' test-quality-check.ps1; then
    echo "⚠️  WARNING: Contains backticks - ensure proper escaping"
fi

# Check for Unicode characters that might cause issues
if grep -P '[^\x00-\x7F]' test-quality-check.ps1 > /dev/null; then
    echo "⚠️  WARNING: Contains non-ASCII characters - may cause encoding issues"
    grep -P -n '[^\x00-\x7F]' test-quality-check.ps1
fi

echo ""
echo "📊 Syntax validation summary:"
if [ $errors -eq 0 ]; then
    echo "✅ No syntax errors detected"
    echo "✅ PowerShell script appears to be syntactically valid"
    exit 0
else
    echo "❌ Found $errors syntax errors"
    echo "❌ PowerShell script may have syntax issues"
    exit 1
fi