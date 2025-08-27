#!/usr/bin/env python3
"""
PowerShell Validation Report Generator

This script generates comprehensive validation reports showing:
- Files checked and their status
- Issues found (if any) with detailed descriptions
- Confirmation of fixes applied
- Recommendations for future improvements
"""

import os
import sys
import json
import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict

# Import our validation modules
try:
    from validate_powershell_syntax_fixed import PowerShellSyntaxValidator, validate_powershell_files
    from test_powershell_validation import PowerShellTestSuite, TestResult
except ImportError as e:
    print(f"Error: Could not import validation modules: {e}")
    sys.exit(1)


@dataclass
class ValidationSummary:
    """Summary of validation results."""
    timestamp: str
    directory: str
    total_files: int
    files_with_issues: int
    total_issues: int
    files_passed: int
    test_summary: Dict[str, int]
    recommendations: List[str]


class ValidationReportGenerator:
    """Generates comprehensive validation reports."""
    
    def __init__(self, directory: Path):
        self.directory = directory
        self.timestamp = datetime.datetime.now().isoformat()
        
    def generate_full_report(self) -> str:
        """Generate a comprehensive validation report."""
        report_lines = []
        
        # Header
        report_lines.extend(self._generate_header())
        
        # File discovery
        files = self._discover_files()
        report_lines.extend(self._generate_file_list(files))
        
        # Syntax validation
        syntax_results = validate_powershell_files(self.directory)
        report_lines.extend(self._generate_syntax_report(syntax_results))
        
        # Test suite results
        test_suite = PowerShellTestSuite(self.directory)
        test_reports = test_suite.run_all_tests()
        report_lines.extend(self._generate_test_report(test_reports))
        
        # Summary and recommendations
        summary = self._create_summary(files, syntax_results, test_reports)
        report_lines.extend(self._generate_summary(summary))
        
        # Footer
        report_lines.extend(self._generate_footer())
        
        return "\n".join(report_lines)
    
    def _generate_header(self) -> List[str]:
        """Generate report header."""
        return [
            "PowerShell Validation Report",
            "=" * 80,
            f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Directory: {self.directory.absolute()}",
            f"Report Version: 1.0",
            "",
        ]
    
    def _discover_files(self) -> List[Path]:
        """Discover all relevant script files."""
        files = []
        
        # PowerShell files
        files.extend(self.directory.glob("*.ps1"))
        files.extend(self.directory.glob("*.psm1"))
        files.extend(self.directory.glob("*.psd1"))
        
        # Batch files
        files.extend(self.directory.glob("*.bat"))
        files.extend(self.directory.glob("*.cmd"))
        
        return sorted(files)
    
    def _generate_file_list(self, files: List[Path]) -> List[str]:
        """Generate file discovery section."""
        lines = [
            "📁 File Discovery",
            "-" * 40,
            f"Total script files found: {len(files)}",
            "",
        ]
        
        if files:
            lines.append("Files to be validated:")
            for file_path in files:
                file_size = file_path.stat().st_size if file_path.exists() else 0
                lines.append(f"  📄 {file_path.name} ({file_size} bytes)")
            lines.append("")
        else:
            lines.extend([
                "⚠️  No script files found in the directory.",
                "   Make sure you're running this in the correct directory.",
                ""
            ])
        
        return lines
    
    def _generate_syntax_report(self, syntax_results: Dict[str, List]) -> List[str]:
        """Generate syntax validation section."""
        lines = [
            "🔍 Syntax Validation Results",
            "-" * 40,
        ]
        
        total_files = len(syntax_results)
        files_with_issues = sum(1 for issues in syntax_results.values() if issues)
        total_issues = sum(len(issues) for issues in syntax_results.values())
        
        lines.extend([
            f"Files analyzed: {total_files}",
            f"Files with syntax issues: {files_with_issues}",
            f"Total syntax issues: {total_issues}",
            "",
        ])
        
        if total_issues == 0:
            lines.extend([
                "✅ All files passed syntax validation!",
                "",
            ])
        else:
            lines.append("❌ Syntax Issues Found:")
            lines.append("")
            
            for file_path, issues in syntax_results.items():
                if issues:
                    lines.append(f"  📄 {Path(file_path).name}:")
                    
                    # Group issues by type
                    issue_groups = {}
                    for issue in issues:
                        issue_type = issue.type.value
                        if issue_type not in issue_groups:
                            issue_groups[issue_type] = []
                        issue_groups[issue_type].append(issue)
                    
                    for issue_type, type_issues in issue_groups.items():
                        lines.append(f"    🔸 {issue_type.replace('_', ' ').title()} ({len(type_issues)} issues):")
                        
                        for issue in type_issues[:5]:  # Show first 5 issues
                            lines.append(f"      • Line {issue.line}: {issue.message}")
                            if issue.context:
                                lines.append(f"        Context: {issue.context[:60]}...")
                        
                        if len(type_issues) > 5:
                            lines.append(f"      • ... and {len(type_issues) - 5} more issues")
                        lines.append("")
            
            lines.append("")
        
        return lines
    
    def _generate_test_report(self, test_reports: List) -> List[str]:
        """Generate test suite results section."""
        lines = [
            "🧪 Test Suite Results", 
            "-" * 40,
        ]
        
        if not test_reports:
            lines.extend([
                "⚠️  No test results available.",
                "",
            ])
            return lines
        
        # Summary
        total_tests = len(test_reports)
        passed_tests = sum(1 for r in test_reports if r.result == TestResult.PASS)
        failed_tests = sum(1 for r in test_reports if r.result == TestResult.FAIL)
        warning_tests = sum(1 for r in test_reports if r.result == TestResult.WARNING)
        
        lines.extend([
            f"Total tests run: {total_tests}",
            f"Passed: {passed_tests} ✅",
            f"Failed: {failed_tests} ❌",
            f"Warnings: {warning_tests} ⚠️",
            "",
        ])
        
        # Detailed results
        lines.append("Test Details:")
        for report in test_reports:
            status_icon = {
                TestResult.PASS: "✅",
                TestResult.FAIL: "❌",
                TestResult.WARNING: "⚠️"
            }[report.result]
            
            lines.append(f"  {status_icon} {report.test_name}")
            lines.append(f"     Result: {report.result.value}")
            lines.append(f"     {report.message}")
            
            if report.details:
                lines.append("     Details:")
                detail_lines = report.details.split('\n')
                for detail_line in detail_lines[:10]:  # Limit details
                    if detail_line.strip():
                        lines.append(f"       {detail_line}")
                if len(detail_lines) > 10:
                    lines.append("       ... (details truncated)")
            lines.append("")
        
        return lines
    
    def _create_summary(self, files: List[Path], syntax_results: Dict, test_reports: List) -> ValidationSummary:
        """Create validation summary."""
        total_files = len(files)
        files_with_issues = sum(1 for issues in syntax_results.values() if issues)
        total_issues = sum(len(issues) for issues in syntax_results.values())
        files_passed = total_files - files_with_issues
        
        test_summary = {
            "total": len(test_reports),
            "passed": sum(1 for r in test_reports if r.result == TestResult.PASS),
            "failed": sum(1 for r in test_reports if r.result == TestResult.FAIL),
            "warnings": sum(1 for r in test_reports if r.result == TestResult.WARNING),
        }
        
        recommendations = self._generate_recommendations(syntax_results, test_reports)
        
        return ValidationSummary(
            timestamp=self.timestamp,
            directory=str(self.directory.absolute()),
            total_files=total_files,
            files_with_issues=files_with_issues,
            total_issues=total_issues,
            files_passed=files_passed,
            test_summary=test_summary,
            recommendations=recommendations
        )
    
    def _generate_recommendations(self, syntax_results: Dict, test_reports: List) -> List[str]:
        """Generate recommendations based on validation results."""
        recommendations = []
        
        # Check for common issues
        has_unicode_issues = any(
            any(issue.type.value == "unicode_character" for issue in issues)
            for issues in syntax_results.values()
        )
        
        has_line_ending_issues = any(
            any(issue.type.value == "incorrect_line_ending" for issue in issues)
            for issues in syntax_results.values()
        )
        
        has_syntax_errors = any(
            len(issues) > 0 for issues in syntax_results.values()
        )
        
        failed_tests = any(r.result == TestResult.FAIL for r in test_reports)
        
        if has_unicode_issues:
            recommendations.append(
                "Remove or properly escape Unicode characters in PowerShell files to ensure "
                "compatibility across different systems and PowerShell versions."
            )
        
        if has_line_ending_issues:
            recommendations.append(
                "Convert line endings to CRLF (Windows format) for better PowerShell compatibility. "
                "Use tools like dos2unix or configure your editor to use CRLF line endings."
            )
        
        if has_syntax_errors:
            recommendations.append(
                "Fix syntax errors found in PowerShell files. Check for unmatched brackets, "
                "quotes, and proper here-string formatting."
            )
        
        if failed_tests:
            recommendations.append(
                "Address test failures identified in the validation suite. These may indicate "
                "potential compatibility or functionality issues."
            )
        
        if not recommendations:
            recommendations.append(
                "All validation checks passed! Consider setting up automated validation "
                "in your CI/CD pipeline to maintain code quality."
            )
        
        return recommendations
    
    def _generate_summary(self, summary: ValidationSummary) -> List[str]:
        """Generate summary section."""
        lines = [
            "📊 Validation Summary",
            "-" * 40,
            f"Directory: {summary.directory}",
            f"Validation completed at: {summary.timestamp}",
            "",
            "File Statistics:",
            f"  • Total files analyzed: {summary.total_files}",
            f"  • Files passed validation: {summary.files_passed}",
            f"  • Files with issues: {summary.files_with_issues}",
            f"  • Total issues found: {summary.total_issues}",
            "",
            "Test Statistics:",
            f"  • Total tests run: {summary.test_summary['total']}",
            f"  • Tests passed: {summary.test_summary['passed']} ✅",
            f"  • Tests failed: {summary.test_summary['failed']} ❌", 
            f"  • Warnings: {summary.test_summary['warnings']} ⚠️",
            "",
            "🎯 Recommendations:",
        ]
        
        for i, recommendation in enumerate(summary.recommendations, 1):
            lines.append(f"  {i}. {recommendation}")
        
        lines.append("")
        
        return lines
    
    def _generate_footer(self) -> List[str]:
        """Generate report footer."""
        return [
            "=" * 80,
            "Report generated by PowerShell Validation Suite",
            f"For questions or issues, check the validation scripts in {self.directory}",
            ""
        ]
    
    def save_report(self, report_content: str, filename: Optional[str] = None) -> Path:
        """Save the report to a file."""
        if filename is None:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"powershell_validation_report_{timestamp}.txt"
        
        report_path = self.directory / filename
        
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write(report_content)
        
        return report_path
    
    def save_json_summary(self, summary: ValidationSummary, filename: Optional[str] = None) -> Path:
        """Save a JSON summary of the validation results."""
        if filename is None:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"validation_summary_{timestamp}.json"
        
        json_path = self.directory / filename
        
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(asdict(summary), f, indent=2)
        
        return json_path


def main():
    """Main function to generate validation report."""
    if len(sys.argv) > 1:
        target_path = Path(sys.argv[1])
    else:
        target_path = Path(__file__).parent
    
    if not target_path.exists():
        print(f"Error: Path {target_path} does not exist")
        sys.exit(1)
    
    print("PowerShell Validation Report Generator")
    print(f"Analyzing: {target_path.absolute()}")
    print("=" * 60)
    
    # Generate report
    generator = ValidationReportGenerator(target_path)
    report_content = generator.generate_full_report()
    
    # Display report
    print(report_content)
    
    # Save report files
    try:
        report_file = generator.save_report(report_content)
        print(f"\n📝 Full report saved to: {report_file}")
        
        # Generate and save JSON summary
        files = generator._discover_files()
        syntax_results = validate_powershell_files(target_path)
        test_suite = PowerShellTestSuite(target_path)
        test_reports = test_suite.run_all_tests()
        summary = generator._create_summary(files, syntax_results, test_reports)
        
        json_file = generator.save_json_summary(summary)
        print(f"📊 JSON summary saved to: {json_file}")
        
    except Exception as e:
        print(f"\n⚠️  Error saving report files: {e}")
    
    # Determine exit code based on validation results
    has_failures = any(
        len(issues) > 0 for issues in validate_powershell_files(target_path).values()
    )
    
    return 1 if has_failures else 0


if __name__ == "__main__":
    sys.exit(main())