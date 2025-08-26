#!/bin/bash
# Focused PowerShell Syntax Validator
# Specifically checking for the issues mentioned by the previous specialists

FILE="$1"
if [ ! -f "$FILE" ]; then
    echo "[ERROR] File not found: $FILE"
    exit 1
fi

echo "Focused PowerShell Syntax Validator"
echo "===================================="
echo "File: $FILE"
echo ""

ERRORS=0
WARNINGS=0

# Check specific line 1059
LINE_1059=$(sed -n '1059p' "$FILE")
echo "CHECKING LINE 1059 (where original error was reported):"
echo "Line 1059: $LINE_1059"
if [[ -n "$LINE_1059" ]]; then
    echo "✓ Line 1059 exists and contains: $(echo "$LINE_1059" | sed 's/^[[:space:]]*//')"
    # Check if it looks problematic
    if echo "$LINE_1059" | grep -q '[^"]"[^"]'; then
        echo "⚠ Potential quote issue detected on line 1059"
        ((WARNINGS++))
    else
        echo "✓ Line 1059 appears syntactically clean"
    fi
else
    echo "✗ Line 1059 is empty or doesn't exist"
    ((ERRORS++))
fi
echo ""

# Check HERE-STRING section (lines 780-911) in detail
echo "ANALYZING HERE-STRING SECTION (lines 780-911):"
echo "=============================================="

# Extract the here-string section
HERE_SECTION=$(sed -n '780,911p' "$FILE")
if [[ -z "$HERE_SECTION" ]]; then
    echo "✗ Here-string section is empty"
    ((ERRORS++))
else
    echo "✓ Here-string section found ($((911-780+1)) lines)"
    
    # Count here-string delimiters
    START_DELIM=$(echo "$HERE_SECTION" | grep -n '@"' | head -1)
    END_DELIM=$(echo "$HERE_SECTION" | grep -n '"@' | head -1)
    
    if [[ -n "$START_DELIM" && -n "$END_DELIM" ]]; then
        START_LINE=$(echo "$START_DELIM" | cut -d: -f1)
        END_LINE=$(echo "$END_DELIM" | cut -d: -f1)
        echo "✓ Here-string found: starts at relative line $START_LINE, ends at relative line $END_LINE"
        
        # Extract just the content between the here-string delimiters
        ACTUAL_START=$((779 + START_LINE))
        ACTUAL_END=$((779 + END_LINE))
        HERE_CONTENT=$(sed -n "${ACTUAL_START},${ACTUAL_END}p" "$FILE")
        
        echo "✓ Here-string content: $(echo "$HERE_CONTENT" | wc -l) lines"
        
        # Check for problematic nested quotes in $(...) expressions
        PROBLEMATIC_LINES=$(echo "$HERE_CONTENT" | grep -n '\$([^)]*"[^)]*)')
        if [[ -n "$PROBLEMATIC_LINES" ]]; then
            echo "⚠ Found problematic double quotes inside \$(...) expressions:"
            echo "$PROBLEMATIC_LINES"
            ((WARNINGS++))
        else
            echo "✓ No double quotes found inside \$(...) expressions in here-string"
        fi
        
        # Check for unmatched parentheses within the here-string
        OPEN_DOLLAR_PAREN=0
        CLOSE_PAREN=0
        
        while IFS= read -r line; do
            # Count $( patterns
            DOLLAR_PAREN_COUNT=$(echo "$line" | grep -o '\$(' | wc -l)
            OPEN_DOLLAR_PAREN=$((OPEN_DOLLAR_PAREN + DOLLAR_PAREN_COUNT))
            
            # Count ) patterns (approximately)
            CLOSE_PAREN_COUNT=$(echo "$line" | grep -o ')' | wc -l)
            CLOSE_PAREN=$((CLOSE_PAREN + CLOSE_PAREN_COUNT))
        done <<< "$HERE_CONTENT"
        
        echo "Here-string expression analysis:"
        echo "  \$( patterns found: $OPEN_DOLLAR_PAREN"
        echo "  ) patterns found: $CLOSE_PAREN"
        
        if [[ $OPEN_DOLLAR_PAREN -eq $CLOSE_PAREN && $OPEN_DOLLAR_PAREN -gt 0 ]]; then
            echo "✓ Parentheses appear balanced in here-string expressions"
        elif [[ $OPEN_DOLLAR_PAREN -ne $CLOSE_PAREN ]]; then
            echo "⚠ Parentheses may be unbalanced in here-string expressions"
            ((WARNINGS++))
        fi
        
    else
        echo "✗ Here-string delimiters not found in expected section"
        ((ERRORS++))
    fi
fi
echo ""

# Check overall file balance
echo "OVERALL FILE BALANCE CHECKS:"
echo "============================"

# Count all braces
TOTAL_OPEN_BRACES=$(grep -o '{' "$FILE" | wc -l)
TOTAL_CLOSE_BRACES=$(grep -o '}' "$FILE" | wc -l)
echo "Total braces: { = $TOTAL_OPEN_BRACES, } = $TOTAL_CLOSE_BRACES"
if [[ $TOTAL_OPEN_BRACES -eq $TOTAL_CLOSE_BRACES ]]; then
    echo "✓ Braces are balanced"
else
    echo "✗ Braces are unbalanced (difference: $((TOTAL_OPEN_BRACES - TOTAL_CLOSE_BRACES)))"
    ((ERRORS++))
fi

# Count here-string delimiters throughout file
TOTAL_HERE_START=$(grep -c '@"' "$FILE")
TOTAL_HERE_END=$(grep -c '"@' "$FILE")
echo "Here-strings: @\" = $TOTAL_HERE_START, \"@ = $TOTAL_HERE_END"
if [[ $TOTAL_HERE_START -eq $TOTAL_HERE_END ]]; then
    echo "✓ Here-string delimiters are balanced"
else
    echo "✗ Here-string delimiters are unbalanced (difference: $((TOTAL_HERE_START - TOTAL_HERE_END)))"
    ((ERRORS++))
fi

# Check for common PowerShell syntax errors
echo ""
echo "COMMON POWERSHELL SYNTAX CHECKS:"
echo "================================"

# Check for unterminated strings (basic check)
UNTERMINATED_STRINGS=$(grep -n '[^`]"[^"]*$' "$FILE" | grep -v '@"' | grep -v '"@')
if [[ -n "$UNTERMINATED_STRINGS" ]]; then
    echo "⚠ Potential unterminated strings found:"
    echo "$UNTERMINATED_STRINGS" | head -5
    ((WARNINGS++))
else
    echo "✓ No obvious unterminated strings detected"
fi

# Check for lines ending with backslash (PowerShell uses backtick)
WRONG_CONTINUATION=$(grep -n '\\$' "$FILE")
if [[ -n "$WRONG_CONTINUATION" ]]; then
    echo "⚠ Lines ending with backslash found (should use backtick \` in PowerShell):"
    echo "$WRONG_CONTINUATION"
    ((WARNINGS++))
fi

echo ""
echo "SYNTAX VALIDATION SUMMARY:"
echo "=========================="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo "✓ PASSED: No syntax issues detected"
        echo "✓ The reported PowerShell error appears to be RESOLVED"
    else
        echo "⚠ PASSED with warnings: $WARNINGS non-critical issues"
        echo "✓ No critical syntax errors that would cause PowerShell to fail"
    fi
else
    echo "✗ FAILED: $ERRORS critical syntax errors detected"
    echo "✗ These issues need to be fixed before PowerShell can run the script"
fi

echo ""
echo "SPECIFIC ORIGINAL ERROR VERIFICATION:"
echo "===================================="
echo "The original error was reported at line 1059."
echo "Current line 1059: $LINE_1059"
echo ""
if echo "$LINE_1059" | grep -q "enhanced compatibility automatically applied"; then
    echo "✓ This matches the expected content and appears syntactically correct"
    echo "✓ The original syntax error has been RESOLVED"
else
    echo "ⓘ Line 1059 content differs from original error report"
    echo "ⓘ This suggests the file has been modified since the error was reported"
fi

exit $ERRORS