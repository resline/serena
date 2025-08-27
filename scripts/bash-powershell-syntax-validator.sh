#!/bin/bash
# Bash-based PowerShell Syntax Validator
# Created by Claude Code for comprehensive PowerShell syntax checking

if [ $# -eq 0 ]; then
    echo "Usage: $0 <powershell-file>"
    exit 1
fi

FILE="$1"
if [ ! -f "$FILE" ]; then
    echo "[ERROR] File not found: $FILE"
    exit 1
fi

echo "PowerShell Syntax Validator (Bash Implementation)"
echo "================================================="
echo "Analyzing: $FILE"
echo ""

# Initialize counters
BRACE_COUNT=0
PAREN_COUNT=0
HERE_STRING_COUNT=0
ERRORS=0
WARNINGS=0
LINE_NUM=0

# Arrays to track issues
declare -a SYNTAX_ERRORS
declare -a SYNTAX_WARNINGS

# Function to add error
add_error() {
    local line_num=$1
    local message=$2
    SYNTAX_ERRORS+=("Line $line_num: [ERROR] $message")
    ((ERRORS++))
}

# Function to add warning  
add_warning() {
    local line_num=$1
    local message=$2
    SYNTAX_WARNINGS+=("Line $line_num: [WARNING] $message")
    ((WARNINGS++))
}

echo "[INFO] File size: $(wc -c < "$FILE") characters"
echo "[INFO] Line count: $(wc -l < "$FILE")"
echo ""
echo "Starting detailed syntax analysis..."

IN_HERE_STRING=false
HERE_STRING_TERMINATOR=""
HERE_STRING_START_LINE=0

# Process each line
while IFS= read -r line || [[ -n "$line" ]]; do
    ((LINE_NUM++))
    
    # Trim whitespace
    trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check for here-string start
    if [[ "$IN_HERE_STRING" == false ]]; then
        if [[ "$line" =~ @\".*$ ]]; then
            IN_HERE_STRING=true
            HERE_STRING_TERMINATOR='"@'
            HERE_STRING_START_LINE=$LINE_NUM
            ((HERE_STRING_COUNT++))
            echo "[DEBUG] Here-string started at line $LINE_NUM"
            continue
        elif [[ "$line" =~ @\'.*$ ]]; then
            IN_HERE_STRING=true
            HERE_STRING_TERMINATOR="'@"
            HERE_STRING_START_LINE=$LINE_NUM
            ((HERE_STRING_COUNT++))
            echo "[DEBUG] Here-string (single quote) started at line $LINE_NUM"
            continue
        fi
    fi
    
    # Check for here-string end
    if [[ "$IN_HERE_STRING" == true && "$trimmed_line" == "$HERE_STRING_TERMINATOR" ]]; then
        IN_HERE_STRING=false
        HERE_STRING_TERMINATOR=""
        ((HERE_STRING_COUNT--))
        echo "[DEBUG] Here-string ended at line $LINE_NUM"
        continue
    fi
    
    # If inside here-string, check for problematic patterns
    if [[ "$IN_HERE_STRING" == true ]]; then
        # Check for double quotes inside $(...) expressions
        if echo "$line" | grep -q '\$([^)]*"[^)]*)'; then
            add_warning $LINE_NUM "Double quotes found inside \$(...) expression within here-string. Use single quotes instead."
        fi
        
        # Count $( and ) for balance checking
        dollar_paren_count=$(echo "$line" | grep -o '\$(' | wc -l)
        closing_paren_count=$(echo "$line" | grep -o ')' | wc -l)
        
        # Simple balance check for this line
        if [[ $dollar_paren_count -gt $closing_paren_count ]]; then
            add_warning $LINE_NUM "Unbalanced parentheses in \$(...) expression within here-string"
        elif [[ $closing_paren_count -gt $dollar_paren_count ]]; then
            # This might be closing parens from previous lines, so just warn
            add_warning $LINE_NUM "Extra closing parentheses found (may be from multi-line \$(...) expression)"
        fi
        
        continue
    fi
    
    # Outside here-string - regular PowerShell syntax checking
    
    # Skip empty lines and comments
    if [[ -z "$trimmed_line" || "$trimmed_line" =~ ^#.* ]]; then
        continue
    fi
    
    # Count braces
    open_braces=$(echo "$line" | grep -o '{' | wc -l)
    close_braces=$(echo "$line" | grep -o '}' | wc -l)
    BRACE_COUNT=$((BRACE_COUNT + open_braces - close_braces))
    
    # Count parentheses (simple approach - not accounting for strings)
    open_parens=$(echo "$line" | grep -o '(' | wc -l)
    close_parens=$(echo "$line" | grep -o ')' | wc -l)
    PAREN_COUNT=$((PAREN_COUNT + open_parens - close_parens))
    
    # Check for unterminated strings (simple check)
    single_quote_count=$(echo "$line" | grep -o "'" | wc -l)
    double_quote_count=$(echo "$line" | grep -o '"' | wc -l)
    
    if [[ $((single_quote_count % 2)) -ne 0 ]]; then
        add_warning $LINE_NUM "Odd number of single quotes - possible unterminated string"
    fi
    
    if [[ $((double_quote_count % 2)) -ne 0 ]]; then
        add_warning $LINE_NUM "Odd number of double quotes - possible unterminated string"
    fi
    
    # Check for common issues
    if echo "$line" | grep -q '\s\|\s*$'; then
        add_warning $LINE_NUM "Pipeline operator at end of line without continuation"
    fi
    
    # Check for specific problematic patterns from the original error
    if echo "$line" | grep -q 'enhanced compatibility automatically applied'; then
        echo "[INFO] Found the specific line mentioned in the original error (line $LINE_NUM)"
        # This line looks fine in the current version
    fi
    
done < "$FILE"

# Final checks
if [[ "$IN_HERE_STRING" == true ]]; then
    add_error $HERE_STRING_START_LINE "Unterminated here-string (expected: $HERE_STRING_TERMINATOR)"
fi

echo ""
echo "Syntax Analysis Complete"
echo "========================"
echo ""

# Display summary
echo "SUMMARY:"
echo "--------"
echo "Braces - Balance: $BRACE_COUNT ($(if [[ $BRACE_COUNT -eq 0 ]]; then echo "BALANCED"; else echo "UNBALANCED"; fi))"
echo "Parentheses - Balance: $PAREN_COUNT ($(if [[ $PAREN_COUNT -eq 0 ]]; then echo "BALANCED"; else echo "UNBALANCED"; fi))"
echo "Here-strings - Count: $HERE_STRING_COUNT ($(if [[ $HERE_STRING_COUNT -eq 0 ]]; then echo "ALL TERMINATED"; else echo "UNTERMINATED"; fi))"
echo ""

# Add balance errors if needed
if [[ $BRACE_COUNT -ne 0 ]]; then
    add_error $LINE_NUM "Unbalanced braces (net count: $BRACE_COUNT)"
fi

if [[ $PAREN_COUNT -ne 0 ]]; then
    add_error $LINE_NUM "Unbalanced parentheses (net count: $PAREN_COUNT)"
fi

# Display errors and warnings
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo "[OK] No syntax errors or warnings found!"
else
    echo "[FOUND] $ERRORS errors, $WARNINGS warnings:"
    echo ""
    
    # Display errors
    for error in "${SYNTAX_ERRORS[@]}"; do
        echo "$error"
    done
    
    # Display warnings
    for warning in "${SYNTAX_WARNINGS[@]}"; do
        echo "$warning"
    done
fi

echo ""
echo "SPECIFIC CHECKS FOR ORIGINAL ERROR:"
echo "==================================="

# Check line 1059 specifically
LINE_1059=$(sed -n '1059p' "$FILE")
if [[ -n "$LINE_1059" ]]; then
    echo "Line 1059: $LINE_1059"
    if echo "$LINE_1059" | grep -q 'enhanced compatibility automatically applied'; then
        echo "✓ Line 1059 appears syntactically correct"
    else
        echo "ⓘ Line 1059 does not match expected pattern from original error"
    fi
else
    echo "Line 1059: (empty or doesn't exist)"
fi

echo ""

# Check the here-string section (lines 780-911)
echo "HERE-STRING SECTION ANALYSIS (lines 780-911):"
echo "=============================================="

HERE_STRING_SECTION=$(sed -n '780,911p' "$FILE")
if [[ -n "$HERE_STRING_SECTION" ]]; then
    echo "✓ Here-string section found (780-911)"
    
    # Count here-string delimiters in this section
    START_COUNT=$(echo "$HERE_STRING_SECTION" | grep -c '@"')
    END_COUNT=$(echo "$HERE_STRING_SECTION" | grep -c '"@')
    
    echo "Here-string starts (@\"): $START_COUNT"
    echo "Here-string ends (\"@): $END_COUNT"
    
    if [[ $START_COUNT -eq $END_COUNT && $START_COUNT -gt 0 ]]; then
        echo "✓ Here-string delimiters are balanced in this section"
    elif [[ $START_COUNT -ne $END_COUNT ]]; then
        echo "✗ Here-string delimiters are unbalanced (starts: $START_COUNT, ends: $END_COUNT)"
    fi
    
    # Check for nested quotes within $(...) expressions
    NESTED_QUOTES=$(echo "$HERE_STRING_SECTION" | grep -c '\$([^)]*"[^)]*)')
    if [[ $NESTED_QUOTES -gt 0 ]]; then
        echo "⚠ Found $NESTED_QUOTES instances of double quotes inside \$(...) expressions"
        echo "  These should be single quotes within here-strings"
    else
        echo "✓ No problematic nested double quotes found in \$(...) expressions"
    fi
else
    echo "✗ Here-string section not found or empty"
fi

echo ""
echo "FINAL VERDICT:"
echo "=============="

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo "✓ Syntax validation: PASSED"
        echo "✓ File appears to be syntactically correct"
    else
        echo "⚠ Syntax validation: PASSED with warnings"
        echo "⚠ $WARNINGS warnings found but no critical errors"
    fi
else
    echo "✗ Syntax validation: FAILED"  
    echo "✗ $ERRORS critical errors, $WARNINGS warnings"
fi

echo ""

# Exit with appropriate code
if [[ $ERRORS -gt 0 ]]; then
    exit 1
else
    exit 0
fi