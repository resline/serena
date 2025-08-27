#!/usr/bin/env python3
"""
PowerShell Issue Fixer

This script automatically fixes common issues found in PowerShell files:
- Replaces Unicode characters with ASCII equivalents
- Suggests fixes for syntax errors
- Validates fixes
"""

import re
import sys
import unicodedata
from pathlib import Path
from typing import Dict, List, Tuple

# Unicode character replacements
UNICODE_REPLACEMENTS = {
    '✓': '[OK]',    # CHECK MARK
    '✗': '[X]',     # BALLOT X
    '•': '*',       # BULLET
    '→': '->',      # RIGHTWARDS ARROW
    '←': '<-',      # LEFTWARDS ARROW
    '…': '...',     # HORIZONTAL ELLIPSIS
    '"': '"',       # LEFT DOUBLE QUOTATION MARK
    '"': '"',       # RIGHT DOUBLE QUOTATION MARK
    ''': "'",       # LEFT SINGLE QUOTATION MARK
    ''': "'",       # RIGHT SINGLE QUOTATION MARK
    '–': '-',       # EN DASH
    '—': '--',      # EM DASH
}


class PowerShellIssueFixer:
    """Fixes common PowerShell syntax issues."""
    
    def __init__(self):
        self.issues_fixed = []
        self.issues_found = []
    
    def fix_file(self, file_path: Path, backup: bool = True) -> bool:
        """Fix issues in a PowerShell file."""
        print(f"Analyzing: {file_path}")
        
        try:
            # Read file
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            original_content = content
            
            # Fix Unicode characters
            content = self._fix_unicode_characters(content, file_path)
            
            # Check if changes were made
            if content != original_content:
                if backup:
                    backup_path = file_path.with_suffix(file_path.suffix + '.backup')
                    with open(backup_path, 'w', encoding='utf-8') as f:
                        f.write(original_content)
                    print(f"  💾 Backup created: {backup_path}")
                
                # Write fixed content
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                print(f"  ✅ Fixed issues in: {file_path}")
                return True
            else:
                print(f"  ℹ️  No issues found in: {file_path}")
                return False
                
        except Exception as e:
            print(f"  ❌ Error processing {file_path}: {e}")
            return False
    
    def _fix_unicode_characters(self, content: str, file_path: Path) -> str:
        """Replace Unicode characters with ASCII equivalents."""
        lines = content.splitlines()
        fixed_lines = []
        changes_made = False
        
        for line_num, line in enumerate(lines, 1):
            original_line = line
            
            # Replace known Unicode characters
            for unicode_char, replacement in UNICODE_REPLACEMENTS.items():
                if unicode_char in line:
                    line = line.replace(unicode_char, replacement)
                    changes_made = True
                    self.issues_fixed.append(
                        f"Line {line_num}: Replaced '{unicode_char}' with '{replacement}'"
                    )
            
            # Check for other Unicode characters
            for i, char in enumerate(line):
                if ord(char) > 127 and char not in UNICODE_REPLACEMENTS:
                    char_name = unicodedata.name(char, f"U+{ord(char):04X}")
                    self.issues_found.append(
                        f"Line {line_num}, Col {i+1}: Unknown Unicode character '{char}' ({char_name})"
                    )
            
            fixed_lines.append(line)
        
        if changes_made:
            print(f"  🔧 Fixed {len([f for f in self.issues_fixed if str(file_path) in f])} Unicode character issues")
        
        return '\n'.join(fixed_lines)
    
    def generate_syntax_recommendations(self, file_path: Path) -> List[str]:
        """Generate recommendations for syntax issues that can't be automatically fixed."""
        recommendations = []
        
        try:
            from validate_powershell_syntax_fixed import PowerShellSyntaxValidator
            
            validator = PowerShellSyntaxValidator()
            issues = validator.validate_file(file_path)
            
            for issue in issues:
                if issue.type.value == "unmatched_brace":
                    recommendations.append(
                        f"Line {issue.line}: Check for missing closing brace '}}' - {issue.message}"
                    )
                elif issue.type.value == "unmatched_paren":
                    recommendations.append(
                        f"Line {issue.line}: Check for missing closing parenthesis ')' - {issue.message}"
                    )
                elif issue.type.value == "unterminated_string":
                    recommendations.append(
                        f"Line {issue.line}: Check for missing closing quote - {issue.message}"
                    )
                elif issue.type.value == "unterminated_herestring":
                    recommendations.append(
                        f"Line {issue.line}: Check for missing here-string terminator - {issue.message}"
                    )
        
        except ImportError:
            recommendations.append("Could not import syntax validator - manual review recommended")
        
        return recommendations


def main():
    """Main function to fix PowerShell issues."""
    if len(sys.argv) > 1:
        target_path = Path(sys.argv[1])
    else:
        target_path = Path(__file__).parent
    
    if not target_path.exists():
        print(f"Error: Path {target_path} does not exist")
        sys.exit(1)
    
    print("PowerShell Issue Fixer")
    print(f"Processing files in: {target_path.absolute()}")
    print("=" * 60)
    
    fixer = PowerShellIssueFixer()
    
    # Find PowerShell files
    ps_files = []
    ps_files.extend(target_path.glob("*.ps1"))
    ps_files.extend(target_path.glob("*.psm1"))
    ps_files.extend(target_path.glob("*.psd1"))
    
    if not ps_files:
        print("No PowerShell files found.")
        return 0
    
    print(f"Found {len(ps_files)} PowerShell files to process:")
    for file_path in ps_files:
        print(f"  📄 {file_path.name}")
    print()
    
    # Process files
    files_fixed = 0
    all_recommendations = []
    
    for file_path in ps_files:
        was_fixed = fixer.fix_file(file_path)
        if was_fixed:
            files_fixed += 1
        
        # Get syntax recommendations
        recommendations = fixer.generate_syntax_recommendations(file_path)
        if recommendations:
            all_recommendations.extend([f"📄 {file_path.name}:"] + recommendations + [""])
    
    # Summary
    print("\n" + "=" * 60)
    print("FIXING SUMMARY")
    print("=" * 60)
    
    print(f"Files processed: {len(ps_files)}")
    print(f"Files modified: {files_fixed}")
    print(f"Issues automatically fixed: {len(fixer.issues_fixed)}")
    print(f"Issues requiring manual review: {len(fixer.issues_found)}")
    
    if fixer.issues_fixed:
        print("\n🔧 Issues Fixed:")
        for issue in fixer.issues_fixed[:10]:  # Show first 10
            print(f"  ✅ {issue}")
        if len(fixer.issues_fixed) > 10:
            print(f"  ... and {len(fixer.issues_fixed) - 10} more")
    
    if fixer.issues_found:
        print("\n⚠️ Issues Requiring Manual Review:")
        for issue in fixer.issues_found[:10]:  # Show first 10
            print(f"  ⚠️  {issue}")
        if len(fixer.issues_found) > 10:
            print(f"  ... and {len(fixer.issues_found) - 10} more")
    
    if all_recommendations:
        print("\n📋 Syntax Issue Recommendations:")
        for rec in all_recommendations[:15]:  # Show first 15
            print(f"  {rec}")
        if len(all_recommendations) > 15:
            print(f"  ... and {len(all_recommendations) - 15} more")
    
    if files_fixed > 0:
        print(f"\n✅ {files_fixed} files were modified. Backup files (.backup) created.")
        print("💡 Run validation again to confirm fixes.")
    else:
        print(f"\n✅ No automatic fixes were needed.")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())