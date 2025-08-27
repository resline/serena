#!/usr/bin/env python3
"""
Fixed PowerShell Syntax Validator

This script validates PowerShell syntax without requiring PowerShell to be installed.
It performs comprehensive checks for common syntax issues including:
- Matching braces, parentheses, and square brackets
- Quote pairing (single and double quotes)
- Unterminated strings and here-strings
- Unicode character detection
- Line ending validation (CRLF for Windows)
"""

import os
import re
import sys
import unicodedata
from pathlib import Path
from typing import List, Dict, Tuple, Optional, NamedTuple
from dataclasses import dataclass
from enum import Enum


class IssueType(Enum):
    UNMATCHED_BRACE = "unmatched_brace"
    UNMATCHED_PAREN = "unmatched_paren"
    UNMATCHED_BRACKET = "unmatched_bracket"
    UNMATCHED_QUOTE = "unmatched_quote"
    UNTERMINATED_STRING = "unterminated_string"
    UNTERMINATED_HERESTRING = "unterminated_herestring"
    UNICODE_CHARACTER = "unicode_character"
    INCORRECT_LINE_ENDING = "incorrect_line_ending"


@dataclass
class ValidationIssue:
    type: IssueType
    line: int
    column: int
    message: str
    context: str = ""


class PowerShellSyntaxValidator:
    """Validates PowerShell syntax without requiring PowerShell installation."""
    
    def __init__(self):
        self.issues: List[ValidationIssue] = []
        self.line_number = 0
        self.current_line = ""
    
    def validate_file(self, file_path: Path) -> List[ValidationIssue]:
        """Validate a PowerShell file and return list of issues."""
        self.issues.clear()
        
        try:
            with open(file_path, 'rb') as f:
                content_bytes = f.read()
            
            # Check line endings
            self._check_line_endings(content_bytes, file_path)
            
            # Decode content
            try:
                content = content_bytes.decode('utf-8')
            except UnicodeDecodeError:
                try:
                    content = content_bytes.decode('utf-8-sig')  # Try with BOM
                except UnicodeDecodeError:
                    content = content_bytes.decode('latin1')  # Fallback
            
            # Perform syntax validation
            self._validate_syntax(content)
            
        except Exception as e:
            self.issues.append(ValidationIssue(
                type=IssueType.UNTERMINATED_STRING,
                line=0,
                column=0,
                message=f"Error reading file: {str(e)}"
            ))
        
        return self.issues.copy()
    
    def _check_line_endings(self, content_bytes: bytes, file_path: Path):
        """Check if line endings are correct (CRLF for Windows PowerShell)."""
        content_str = content_bytes.decode('utf-8', errors='ignore')
        lines = content_str.split('\n')
        
        for i, line in enumerate(lines[:-1], 1):  # Exclude last empty line
            if not line.endswith('\r'):
                self.issues.append(ValidationIssue(
                    type=IssueType.INCORRECT_LINE_ENDING,
                    line=i,
                    column=len(line) + 1,
                    message="Line should end with CRLF (\\r\\n) for Windows compatibility",
                    context=line[:50] + "..." if len(line) > 50 else line
                ))
    
    def _validate_syntax(self, content: str):
        """Perform comprehensive syntax validation."""
        lines = content.splitlines()
        
        # Track bracket/brace/paren stack
        bracket_stack = []
        
        # Track string states
        in_single_quote = False
        in_double_quote = False
        in_herestring = False
        herestring_marker = ""
        herestring_start_line = 0
        
        for line_num, line in enumerate(lines, 1):
            self.line_number = line_num
            self.current_line = line
            
            # Check for Unicode characters
            self._check_unicode_characters(line, line_num)
            
            # Check for here-string end first
            if in_herestring:
                line_stripped = line.strip()
                if line_stripped == '"@' or line_stripped == "'@":
                    expected_marker = '"@' if herestring_marker == '@"' else "'@"
                    if line_stripped == expected_marker:
                        in_herestring = False
                        herestring_marker = ""
                        herestring_start_line = 0
                continue  # Skip processing inside here-strings
            
            # Check for here-string start
            herestring_start = self._find_herestring_start(line)
            if herestring_start is not None:
                in_herestring = True
                herestring_marker = herestring_start
                herestring_start_line = line_num
                continue
            
            # Process character by character for quotes and brackets
            i = 0
            escaped = False
            
            while i < len(line):
                char = line[i]
                
                # Handle escape sequences
                if escaped:
                    escaped = False
                    i += 1
                    continue
                
                if char == '`':  # PowerShell escape character
                    escaped = True
                    i += 1
                    continue
                
                # Handle quotes (only outside here-strings)
                if char == "'" and not in_double_quote:
                    in_single_quote = not in_single_quote
                elif char == '"' and not in_single_quote:
                    in_double_quote = not in_double_quote
                
                # Handle brackets, braces, and parentheses (only outside strings)
                if not in_single_quote and not in_double_quote:
                    if char in "({[":
                        bracket_stack.append((char, line_num, i + 1))
                    elif char in ")}]":
                        if not bracket_stack:
                            self.issues.append(ValidationIssue(
                                type=self._get_bracket_issue_type(char),
                                line=line_num,
                                column=i + 1,
                                message=f"Unmatched closing '{char}'",
                                context=self._get_context(line, i)
                            ))
                        else:
                            open_char, _, _ = bracket_stack[-1]
                            if self._brackets_match(open_char, char):
                                bracket_stack.pop()
                            else:
                                self.issues.append(ValidationIssue(
                                    type=self._get_bracket_issue_type(char),
                                    line=line_num,
                                    column=i + 1,
                                    message=f"Mismatched bracket: expected '{self._get_matching_bracket(open_char)}' but found '{char}'",
                                    context=self._get_context(line, i)
                                ))
                
                i += 1
        
        # Check for unterminated strings
        if in_single_quote:
            self.issues.append(ValidationIssue(
                type=IssueType.UNTERMINATED_STRING,
                line=len(lines),
                column=len(lines[-1]) if lines else 0,
                message="Unterminated single-quoted string",
                context=lines[-1] if lines else ""
            ))
        
        if in_double_quote:
            self.issues.append(ValidationIssue(
                type=IssueType.UNTERMINATED_STRING,
                line=len(lines),
                column=len(lines[-1]) if lines else 0,
                message="Unterminated double-quoted string",
                context=lines[-1] if lines else ""
            ))
        
        if in_herestring:
            expected_end = '"@' if herestring_marker == '@"' else "'@"
            self.issues.append(ValidationIssue(
                type=IssueType.UNTERMINATED_HERESTRING,
                line=herestring_start_line,
                column=0,
                message=f"Unterminated here-string starting at line {herestring_start_line} (expected '{expected_end}')",
                context=""
            ))
        
        # Check for unmatched brackets
        for open_char, line_num, col_num in bracket_stack:
            self.issues.append(ValidationIssue(
                type=self._get_bracket_issue_type(open_char),
                line=line_num,
                column=col_num,
                message=f"Unmatched opening '{open_char}'",
                context=""
            ))
    
    def _check_unicode_characters(self, line: str, line_num: int):
        """Check for Unicode characters that might cause issues."""
        for i, char in enumerate(line):
            if ord(char) > 127:  # Non-ASCII character
                char_name = unicodedata.name(char, f"U+{ord(char):04X}")
                self.issues.append(ValidationIssue(
                    type=IssueType.UNICODE_CHARACTER,
                    line=line_num,
                    column=i + 1,
                    message=f"Unicode character found: '{char}' ({char_name})",
                    context=self._get_context(line, i)
                ))
    
    def _find_herestring_start(self, line: str) -> Optional[str]:
        """Find here-string start marker in line."""
        # Look for @" or @' at end of line (possibly with whitespace)
        line_stripped = line.strip()
        if line_stripped.endswith('@"'):
            return '@"'
        elif line_stripped.endswith("@'"):
            return "@'"
        return None
    
    def _get_bracket_issue_type(self, char: str) -> IssueType:
        """Get the appropriate issue type for bracket characters."""
        if char in "()":
            return IssueType.UNMATCHED_PAREN
        elif char in "{}":
            return IssueType.UNMATCHED_BRACE
        elif char in "[]":
            return IssueType.UNMATCHED_BRACKET
        return IssueType.UNMATCHED_BRACE  # Default
    
    def _brackets_match(self, open_char: str, close_char: str) -> bool:
        """Check if opening and closing brackets match."""
        pairs = {"(": ")", "{": "}", "[": "]"}
        return pairs.get(open_char) == close_char
    
    def _get_matching_bracket(self, open_char: str) -> str:
        """Get the matching closing bracket for an opening bracket."""
        pairs = {"(": ")", "{": "}", "[": "]"}
        return pairs.get(open_char, "")
    
    def _get_context(self, line: str, pos: int, context_length: int = 20) -> str:
        """Get context around a position in a line."""
        start = max(0, pos - context_length)
        end = min(len(line), pos + context_length + 1)
        context = line[start:end]
        
        if start > 0:
            context = "..." + context
        if end < len(line):
            context = context + "..."
            
        return context


def validate_powershell_files(directory: Path) -> Dict[str, List[ValidationIssue]]:
    """Validate all PowerShell files in a directory."""
    validator = PowerShellSyntaxValidator()
    results = {}
    
    # Find all PowerShell files
    ps_files = list(directory.glob("*.ps1")) + list(directory.glob("*.psm1")) + list(directory.glob("*.psd1"))
    
    for file_path in ps_files:
        print(f"Validating: {file_path}")
        issues = validator.validate_file(file_path)
        results[str(file_path)] = issues
    
    return results


def main():
    """Main function to run PowerShell validation."""
    if len(sys.argv) > 1:
        target_path = Path(sys.argv[1])
    else:
        target_path = Path(__file__).parent
    
    if not target_path.exists():
        print(f"Error: Path {target_path} does not exist")
        sys.exit(1)
    
    print(f"PowerShell Syntax Validator (Fixed)")
    print(f"Validating files in: {target_path.absolute()}")
    print("=" * 60)
    
    results = validate_powershell_files(target_path)
    
    total_files = len(results)
    total_issues = sum(len(issues) for issues in results.values())
    files_with_issues = sum(1 for issues in results.values() if issues)
    
    print(f"\nValidation Results:")
    print(f"Files checked: {total_files}")
    print(f"Files with issues: {files_with_issues}")
    print(f"Total issues found: {total_issues}")
    
    if total_issues > 0:
        print("\nDetailed Issues:")
        print("=" * 60)
        
        for file_path, issues in results.items():
            if issues:
                print(f"\n📄 {file_path}")
                print("-" * 40)
                
                for issue in issues:
                    print(f"  ⚠️  Line {issue.line}, Column {issue.column}: {issue.message}")
                    if issue.context:
                        print(f"      Context: {issue.context}")
                    print(f"      Type: {issue.type.value}")
                    print()
    else:
        print("\n✅ All files passed validation!")
    
    return 0 if total_issues == 0 else 1


if __name__ == "__main__":
    sys.exit(main())