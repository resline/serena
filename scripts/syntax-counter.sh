#!/bin/bash
# PowerShell Syntax Counter - Counts structural elements

FILE="create-fully-portable-package.ps1"

echo "PowerShell Syntax Element Counter"
echo "=================================="
echo "File: $FILE"
echo ""

if [ ! -f "$FILE" ]; then
    echo "ERROR: File not found"
    exit 1
fi

echo "📊 Structural Element Counts:"
echo "============================"

# Count braces
OPEN_BRACES=$(grep -o '{' "$FILE" | wc -l)
CLOSE_BRACES=$(grep -o '}' "$FILE" | wc -l)
echo "Opening braces { : $OPEN_BRACES"
echo "Closing braces } : $CLOSE_BRACES"
echo "Brace balance    : $((OPEN_BRACES - CLOSE_BRACES)) (should be 0)"

echo ""

# Count quotes (excluding here-string delimiters)
SINGLE_QUOTES=$(grep -o "'" "$FILE" | wc -l)
DOUBLE_QUOTES=$(grep -o '"' "$FILE" | wc -l)
echo "Single quotes '  : $SINGLE_QUOTES"
echo "Double quotes \"  : $DOUBLE_QUOTES"

# Subtract here-string delimiter quotes
HERESTRING_DELIM_QUOTES=$(grep -E '(@"|"@)' "$FILE" | grep -o '"' | wc -l)
CONTENT_DOUBLE_QUOTES=$((DOUBLE_QUOTES - HERESTRING_DELIM_QUOTES))
echo "Content quotes   : $CONTENT_DOUBLE_QUOTES (excluding here-string delimiters)"

echo ""

# Count here-string terminators
HERESTRING_STARTS=$(grep -c '@"' "$FILE")
HERESTRING_ENDS=$(grep -c '"@' "$FILE")
echo "Here-string @\"   : $HERESTRING_STARTS"
echo "Here-string \"@   : $HERESTRING_ENDS"
echo "Here-string bal  : $((HERESTRING_STARTS - HERESTRING_ENDS)) (should be 0)"

echo ""

# Count parentheses (approximate - doesn't account for strings)
OPEN_PARENS=$(grep -o '(' "$FILE" | wc -l)
CLOSE_PARENS=$(grep -o ')' "$FILE" | wc -l)
echo "Opening parens ( : $OPEN_PARENS"
echo "Closing parens ) : $CLOSE_PARENS"
echo "Paren balance    : $((OPEN_PARENS - CLOSE_PARENS)) (should be 0)"

echo ""
echo "🎯 Balance Check Results:"
echo "========================"

ALL_BALANCED=true

if [[ $((OPEN_BRACES - CLOSE_BRACES)) -eq 0 ]]; then
    echo "✅ Braces: BALANCED"
else
    echo "❌ Braces: UNBALANCED (difference: $((OPEN_BRACES - CLOSE_BRACES)))"
    ALL_BALANCED=false
fi

if [[ $((HERESTRING_STARTS - HERESTRING_ENDS)) -eq 0 ]]; then
    echo "✅ Here-strings: BALANCED"
else
    echo "❌ Here-strings: UNBALANCED (difference: $((HERESTRING_STARTS - HERESTRING_ENDS)))"
    ALL_BALANCED=false
fi

if [[ $((OPEN_PARENS - CLOSE_PARENS)) -eq 0 ]]; then
    echo "✅ Parentheses: BALANCED"
else
    echo "❌ Parentheses: UNBALANCED (difference: $((OPEN_PARENS - CLOSE_PARENS)))"
    ALL_BALANCED=false
fi

echo ""
if [[ "$ALL_BALANCED" == true ]]; then
    echo "🎉 ALL STRUCTURAL ELEMENTS ARE BALANCED!"
    echo "✅ File appears syntactically correct"
else
    echo "⚠️  SOME ELEMENTS ARE UNBALANCED"
    echo "🛠️  Manual review recommended"
fi

echo ""
echo "📍 Line 1059 Check:"
echo "==================="
LINE_1059=$(sed -n '1059p' "$FILE")
echo "Content: $LINE_1059"
if [[ -n "$LINE_1059" ]]; then
    echo "✅ Line 1059 exists and has content"
else
    echo "❌ Line 1059 is missing or empty"
fi