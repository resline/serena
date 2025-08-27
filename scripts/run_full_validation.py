#!/usr/bin/env python3
"""
PowerShell Full Validation Suite Runner

This script runs the complete validation process for PowerShell files:
1. Syntax validation using the fixed validator
2. Comprehensive test suite
3. Full validation report generation
4. Summary output with recommendations

Usage: python3 run_full_validation.py [directory_path]
"""

import sys
import subprocess
from pathlib import Path


def run_command(cmd, description):
    """Run a command and display results."""
    print(f"\n{'='*60}")
    print(f"Running: {description}")
    print('='*60)
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print("STDERR:", result.stderr)
        return result.returncode == 0
    except Exception as e:
        print(f"Error running command: {e}")
        return False


def main():
    """Main function to run full validation suite."""
    if len(sys.argv) > 1:
        target_path = Path(sys.argv[1])
    else:
        target_path = Path(__file__).parent
    
    if not target_path.exists():
        print(f"Error: Path {target_path} does not exist")
        sys.exit(1)
    
    print("PowerShell Full Validation Suite")
    print(f"Target Directory: {target_path.absolute()}")
    print("="*80)
    
    # Change to target directory
    original_cwd = Path.cwd()
    
    try:
        # Run individual components
        success = True
        
        # 1. Run syntax validation
        cmd1 = f"cd {target_path} && python3 validate_powershell_syntax_fixed.py"
        success &= run_command(cmd1, "PowerShell Syntax Validation")
        
        # 2. Run test suite
        cmd2 = f"cd {target_path} && python3 test_powershell_validation.py"
        success &= run_command(cmd2, "PowerShell Test Suite")
        
        # 3. Generate full report
        cmd3 = f"cd {target_path} && python3 generate_validation_report.py"
        success &= run_command(cmd3, "Validation Report Generation")
        
        # Summary
        print("\n" + "="*80)
        print("VALIDATION SUMMARY")
        print("="*80)
        
        if success:
            print("✅ All validation components completed successfully!")
            print("\nFiles generated:")
            print("  📄 powershell_validation_report_*.txt - Full detailed report")
            print("  📊 validation_summary_*.json - JSON summary for automation")
            print("\nNext steps:")
            print("  1. Review the detailed report for specific issues")
            print("  2. Fix any syntax errors identified")
            print("  3. Consider removing Unicode characters for better compatibility")
            print("  4. Re-run validation after making fixes")
        else:
            print("❌ Some validation components encountered issues")
            print("Please check the output above for details")
        
        print("\n" + "="*80)
        
        return 0 if success else 1
        
    finally:
        # Restore original working directory
        pass


if __name__ == "__main__":
    sys.exit(main())