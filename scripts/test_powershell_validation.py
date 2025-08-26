#!/usr/bin/env python3
"""
PowerShell Validation Test Suite

This script performs comprehensive testing of PowerShell files including:
- Unicode character detection
- Line ending validation (CRLF for Windows)
- Here-string formatting validation  
- Syntax error detection
- Integration with the PowerShell syntax validator
"""

import os
import re
import sys
import subprocess
from pathlib import Path
from typing import List, Dict, Tuple, Set
from dataclasses import dataclass
from enum import Enum

# Import our validator
try:
    from validate_powershell_syntax_fixed import PowerShellSyntaxValidator, ValidationIssue, IssueType
except ImportError:
    print("Error: Could not import validate_powershell_syntax_fixed module")
    sys.exit(1)


class TestResult(Enum):
    PASS = "PASS"
    FAIL = "FAIL"
    WARNING = "WARNING"


@dataclass
class TestReport:
    test_name: str
    result: TestResult
    message: str
    details: str = ""


class PowerShellTestSuite:
    """Comprehensive test suite for PowerShell file validation."""
    
    def __init__(self, directory: Path):
        self.directory = directory
        self.validator = PowerShellSyntaxValidator()
        self.reports: List[TestReport] = []
        
    def run_all_tests(self) -> List[TestReport]:
        """Run all validation tests."""
        self.reports.clear()
        
        # Find all PowerShell and batch files
        ps_files = self._find_script_files()
        
        if not ps_files:
            self.reports.append(TestReport(
                test_name="File Discovery",
                result=TestResult.WARNING,
                message="No PowerShell or batch files found to test"
            ))
            return self.reports
        
        print(f"Found {len(ps_files)} script files to test")
        
        # Run individual tests
        self._test_unicode_characters(ps_files)
        self._test_line_endings(ps_files)
        self._test_herestring_formatting(ps_files)
        self._test_syntax_errors(ps_files)
        self._test_file_encoding(ps_files)
        self._test_powershell_specific_syntax(ps_files)
        
        return self.reports
    
    def _find_script_files(self) -> List[Path]:
        """Find all PowerShell and batch files."""
        files = []
        
        # PowerShell files
        files.extend(self.directory.glob("*.ps1"))
        files.extend(self.directory.glob("*.psm1"))
        files.extend(self.directory.glob("*.psd1"))
        
        # Batch files
        files.extend(self.directory.glob("*.bat"))
        files.extend(self.directory.glob("*.cmd"))
        
        return sorted(files)
    
    def _test_unicode_characters(self, files: List[Path]):
        """Test for Unicode characters that might cause issues."""
        unicode_issues = {}
        
        for file_path in files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                issues = []
                for line_num, line in enumerate(content.splitlines(), 1):
                    for col_num, char in enumerate(line, 1):
                        if ord(char) > 127:
                            issues.append(f"Line {line_num}, Col {col_num}: '{char}' (U+{ord(char):04X})")
                
                if issues:
                    unicode_issues[file_path] = issues
            
            except Exception as e:
                unicode_issues[file_path] = [f"Error reading file: {str(e)}"]
        
        if unicode_issues:
            details = []
            for file_path, issues in unicode_issues.items():
                details.append(f"\n{file_path}:")
                for issue in issues[:5]:  # Limit to first 5 issues per file
                    details.append(f"  - {issue}")
                if len(issues) > 5:
                    details.append(f"  - ... and {len(issues) - 5} more issues")
            
            self.reports.append(TestReport(
                test_name="Unicode Character Detection",
                result=TestResult.FAIL,
                message=f"Found Unicode characters in {len(unicode_issues)} files",
                details="".join(details)
            ))
        else:
            self.reports.append(TestReport(
                test_name="Unicode Character Detection", 
                result=TestResult.PASS,
                message="No Unicode characters found in any files"
            ))
    
    def _test_line_endings(self, files: List[Path]):
        """Test line endings (should be CRLF for Windows compatibility)."""
        line_ending_issues = {}
        
        for file_path in files:
            # Skip batch files as they have different requirements
            if file_path.suffix.lower() in ['.bat', '.cmd']:
                continue
                
            try:
                with open(file_path, 'rb') as f:
                    content = f.read()
                
                # Check for LF without CR
                issues = []
                lines = content.split(b'\n')
                for line_num, line in enumerate(lines[:-1], 1):  # Exclude last empty line
                    if not line.endswith(b'\r'):
                        issues.append(f"Line {line_num}: LF without CR")
                
                if issues:
                    line_ending_issues[file_path] = issues[:10]  # Limit to first 10
            
            except Exception as e:
                line_ending_issues[file_path] = [f"Error reading file: {str(e)}"]
        
        if line_ending_issues:
            details = []
            for file_path, issues in line_ending_issues.items():
                details.append(f"\n{file_path}:")
                for issue in issues:
                    details.append(f"  - {issue}")
            
            self.reports.append(TestReport(
                test_name="Line Ending Validation",
                result=TestResult.FAIL,
                message=f"Incorrect line endings found in {len(line_ending_issues)} files",
                details="".join(details)
            ))
        else:
            self.reports.append(TestReport(
                test_name="Line Ending Validation",
                result=TestResult.PASS,
                message="All PowerShell files have correct CRLF line endings"
            ))
    
    def _test_herestring_formatting(self, files: List[Path]):
        """Test here-string formatting."""
        herestring_issues = {}
        
        for file_path in files:
            if file_path.suffix.lower() not in ['.ps1', '.psm1']:
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                
                issues = []
                in_herestring = False
                herestring_start_line = 0
                
                for line_num, line in enumerate(lines, 1):
                    stripped = line.strip()
                    
                    # Check for here-string start
                    if not in_herestring and (stripped.endswith('@"') or stripped.endswith("@'")):
                        in_herestring = True
                        herestring_start_line = line_num
                        
                        # Check if here-string opener is properly formatted
                        if not re.match(r'.*@["\']$', stripped):
                            issues.append(f"Line {line_num}: Malformed here-string opener")
                    
                    # Check for here-string end
                    elif in_herestring and (stripped == '"@' or stripped == "'@"):
                        in_herestring = False
                        
                        # Check if here-string closer is on its own line
                        if line.strip() != stripped:
                            issues.append(f"Line {line_num}: Here-string closer should be on its own line")
                    
                    # Check for potential issues inside here-strings
                    elif in_herestring:
                        # Look for unescaped quotes that might cause problems
                        if '"' in line or "'" in line:
                            # This is more of a warning
                            pass
                
                # Check for unclosed here-strings
                if in_herestring:
                    issues.append(f"Line {herestring_start_line}: Unclosed here-string")
                
                if issues:
                    herestring_issues[file_path] = issues
            
            except Exception as e:
                herestring_issues[file_path] = [f"Error reading file: {str(e)}"]
        
        if herestring_issues:
            details = []
            for file_path, issues in herestring_issues.items():
                details.append(f"\n{file_path}:")
                for issue in issues:
                    details.append(f"  - {issue}")
            
            self.reports.append(TestReport(
                test_name="Here-String Formatting",
                result=TestResult.FAIL,
                message=f"Here-string formatting issues found in {len(herestring_issues)} files",
                details="".join(details)
            ))
        else:
            self.reports.append(TestReport(
                test_name="Here-String Formatting",
                result=TestResult.PASS,
                message="All here-strings are properly formatted"
            ))
    
    def _test_syntax_errors(self, files: List[Path]):
        """Test for syntax errors using our validator."""
        syntax_issues = {}
        
        for file_path in files:
            if file_path.suffix.lower() not in ['.ps1', '.psm1', '.psd1']:
                continue
                
            issues = self.validator.validate_file(file_path)
            if issues:
                # Filter out line ending issues as we test those separately
                filtered_issues = [
                    issue for issue in issues 
                    if issue.type != IssueType.INCORRECT_LINE_ENDING
                ]
                if filtered_issues:
                    syntax_issues[file_path] = filtered_issues
        
        if syntax_issues:
            details = []
            for file_path, issues in syntax_issues.items():
                details.append(f"\n{file_path}:")
                for issue in issues[:10]:  # Limit to first 10 issues
                    details.append(f"  - Line {issue.line}: {issue.message}")
                if len(issues) > 10:
                    details.append(f"  - ... and {len(issues) - 10} more issues")
            
            self.reports.append(TestReport(
                test_name="Syntax Error Detection",
                result=TestResult.FAIL,
                message=f"Syntax errors found in {len(syntax_issues)} files",
                details="".join(details)
            ))
        else:
            self.reports.append(TestReport(
                test_name="Syntax Error Detection",
                result=TestResult.PASS,
                message="No syntax errors detected"
            ))
    
    def _test_file_encoding(self, files: List[Path]):
        """Test file encoding (should be UTF-8 or UTF-8 with BOM)."""
        encoding_issues = {}
        
        for file_path in files:
            try:
                # Try to read as UTF-8
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check if file starts with BOM
                with open(file_path, 'rb') as f:
                    first_bytes = f.read(3)
                    has_bom = first_bytes == b'\xef\xbb\xbf'
                
                # This is informational rather than an error
                if has_bom:
                    encoding_issues[file_path] = ["File has UTF-8 BOM (not necessarily a problem)"]
            
            except UnicodeDecodeError:
                try:
                    # Try UTF-8 with BOM
                    with open(file_path, 'r', encoding='utf-8-sig') as f:
                        content = f.read()
                    encoding_issues[file_path] = ["File requires UTF-8-sig encoding"]
                except UnicodeDecodeError:
                    encoding_issues[file_path] = ["File is not valid UTF-8"]
            except Exception as e:
                encoding_issues[file_path] = [f"Error reading file: {str(e)}"]
        
        if encoding_issues:
            details = []
            for file_path, issues in encoding_issues.items():
                details.append(f"\n{file_path}:")
                for issue in issues:
                    details.append(f"  - {issue}")
            
            # Determine if this is a warning or failure
            has_real_issues = any(
                "not valid UTF-8" in str(issues) 
                for issues in encoding_issues.values()
            )
            
            result = TestResult.FAIL if has_real_issues else TestResult.WARNING
            
            self.reports.append(TestReport(
                test_name="File Encoding Validation",
                result=result,
                message=f"Encoding issues found in {len(encoding_issues)} files",
                details="".join(details)
            ))
        else:
            self.reports.append(TestReport(
                test_name="File Encoding Validation",
                result=TestResult.PASS,
                message="All files have valid UTF-8 encoding"
            ))
    
    def _test_powershell_specific_syntax(self, files: List[Path]):
        """Test PowerShell-specific syntax patterns."""
        ps_issues = {}
        
        for file_path in files:
            if file_path.suffix.lower() not in ['.ps1', '.psm1', '.psd1']:
                continue
                
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                
                issues = []
                
                for line_num, line in enumerate(lines, 1):
                    # Check for common PowerShell syntax patterns
                    
                    # Check for proper parameter syntax
                    if re.search(r'\$[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*\$null', line):
                        # This is fine
                        pass
                    
                    # Check for potential variable naming issues
                    if re.search(r'\$\d', line):
                        issues.append(f"Line {line_num}: Variable name starts with digit")
                    
                    # Check for common cmdlet capitalization (informational)
                    cmdlets = re.findall(r'\b(write-host|get-item|set-location|new-item)\b', line, re.IGNORECASE)
                    for cmdlet in cmdlets:
                        if not cmdlet[0].isupper():
                            # This is more style than syntax, so we'll skip it
                            pass
                    
                    # Check for potential path issues
                    if '\\\\' in line and not line.strip().startswith('#'):
                        issues.append(f"Line {line_num}: Double backslashes found (potential UNC path issue)")
                
                if issues:
                    ps_issues[file_path] = issues
            
            except Exception as e:
                ps_issues[file_path] = [f"Error reading file: {str(e)}"]
        
        if ps_issues:
            details = []
            for file_path, issues in ps_issues.items():
                details.append(f"\n{file_path}:")
                for issue in issues:
                    details.append(f"  - {issue}")
            
            self.reports.append(TestReport(
                test_name="PowerShell Syntax Patterns",
                result=TestResult.WARNING,
                message=f"PowerShell syntax warnings in {len(ps_issues)} files",
                details="".join(details)
            ))
        else:
            self.reports.append(TestReport(
                test_name="PowerShell Syntax Patterns",
                result=TestResult.PASS,
                message="No PowerShell syntax pattern issues found"
            ))
    
    def generate_report(self) -> str:
        """Generate a comprehensive validation report."""
        if not self.reports:
            return "No tests were run."
        
        report_lines = []
        report_lines.append("PowerShell Validation Test Report")
        report_lines.append("=" * 50)
        report_lines.append("")
        
        # Summary
        total_tests = len(self.reports)
        passed_tests = sum(1 for r in self.reports if r.result == TestResult.PASS)
        failed_tests = sum(1 for r in self.reports if r.result == TestResult.FAIL)
        warning_tests = sum(1 for r in self.reports if r.result == TestResult.WARNING)
        
        report_lines.append("Summary:")
        report_lines.append(f"  Total tests: {total_tests}")
        report_lines.append(f"  Passed: {passed_tests}")
        report_lines.append(f"  Failed: {failed_tests}")
        report_lines.append(f"  Warnings: {warning_tests}")
        report_lines.append("")
        
        # Detailed results
        report_lines.append("Detailed Results:")
        report_lines.append("-" * 30)
        
        for report in self.reports:
            status_icon = {
                TestResult.PASS: "✅",
                TestResult.FAIL: "❌",
                TestResult.WARNING: "⚠️"
            }[report.result]
            
            report_lines.append(f"{status_icon} {report.test_name}: {report.result.value}")
            report_lines.append(f"   {report.message}")
            
            if report.details:
                report_lines.append(f"   Details: {report.details}")
            
            report_lines.append("")
        
        return "\n".join(report_lines)


def main():
    """Main function to run PowerShell validation tests."""
    if len(sys.argv) > 1:
        target_path = Path(sys.argv[1])
    else:
        target_path = Path(__file__).parent
    
    if not target_path.exists():
        print(f"Error: Path {target_path} does not exist")
        sys.exit(1)
    
    print(f"PowerShell Validation Test Suite")
    print(f"Testing files in: {target_path.absolute()}")
    print("=" * 60)
    
    test_suite = PowerShellTestSuite(target_path)
    reports = test_suite.run_all_tests()
    
    print("\n" + test_suite.generate_report())
    
    # Return appropriate exit code
    has_failures = any(r.result == TestResult.FAIL for r in reports)
    return 1 if has_failures else 0


if __name__ == "__main__":
    sys.exit(main())