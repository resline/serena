#!/usr/bin/env python3
import re
import os

def validate_powershell_syntax(file_path):
    issues = []
    
    try:
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            lines = f.readlines()
    except Exception as e:
        return [f'Error reading file: {e}']
    
    brace_count = 0
    paren_count = 0
    in_here_string = False
    here_string_terminator = None
    in_string = False
    string_char = None
    
    for i, line in enumerate(lines, 1):
        line_stripped = line.rstrip()
        
        # Check for here-strings
        here_string_start = re.search(r'@(["\'])', line)
        if here_string_start and not in_here_string:
            in_here_string = True
            here_string_terminator = here_string_start.group(1) + '@'
            continue
        
        if in_here_string:
            if line_stripped.endswith(here_string_terminator):
                in_here_string = False
                here_string_terminator = None
            continue
            
        # Skip comments (but check for unbalanced quotes in comments)
        if line_stripped.startswith('#'):
            continue
            
        # Track string states and braces/parens outside strings
        j = 0
        while j < len(line):
            char = line[j]
            
            # Handle escape sequences
            if char == '`' and j + 1 < len(line):
                j += 2  # Skip escaped character
                continue
                
            # Handle string boundaries
            if char in ['"', "'"] and not in_string:
                in_string = True
                string_char = char
            elif char == string_char and in_string:
                in_string = False
                string_char = None
                
            # Count braces and parentheses outside of strings
            elif not in_string:
                if char == '{':
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
                elif char == '(':
                    paren_count += 1
                elif char == ')':
                    paren_count -= 1
                    
            j += 1
    
    # Check for unbalanced constructs
    if brace_count != 0:
        issues.append(f'Unbalanced braces: {brace_count} extra opening braces' if brace_count > 0 else f'Unbalanced braces: {abs(brace_count)} extra closing braces')
    if paren_count != 0:
        issues.append(f'Unbalanced parentheses: {paren_count} extra opening parens' if paren_count > 0 else f'Unbalanced parentheses: {abs(paren_count)} extra closing parens')
    if in_here_string:
        issues.append(f'Unterminated here-string (missing {here_string_terminator})')
    if in_string:
        issues.append(f'Unterminated string (missing closing {string_char})')
    
    return issues

# Main validation
scripts = [
    'create-fully-portable-package.ps1',
    'portable-package-windows10-helpers.ps1',
    'windows10-compatibility.ps1',
    'corporate-setup-windows.ps1'
]

print('=== POWERSHELL SYNTAX VALIDATION ===')
total_issues = 0
all_valid = True

for script in scripts:
    if os.path.exists(script):
        print(f'\n--- {script} ---')
        issues = validate_powershell_syntax(script)
        if issues:
            all_valid = False
            total_issues += len(issues)
            for issue in issues:
                print(f'  [ERROR] {issue}')
        else:
            print('  [OK] No syntax issues found')
    else:
        print(f'  [MISSING] File not found: {script}')
        all_valid = False

print(f'\n=== SYNTAX VALIDATION RESULTS ===')
print(f'Scripts checked: {len([s for s in scripts if os.path.exists(s)])}')
print(f'Total issues found: {total_issues}')
print(f'All scripts valid: {"YES" if all_valid else "NO"}')