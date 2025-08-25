#!/usr/bin/env python3
"""
Enhancement script to add validation features to download-dependencies-offline.py
This script patches the main download script with comprehensive validation
"""

import re
from pathlib import Path


def enhance_dependencies_script():
    """Enhance the dependencies download script with validation"""
    
    script_path = Path("scripts/download-dependencies-offline.py")
    if not script_path.exists():
        print(f"❌ Script not found: {script_path}")
        return False
        
    # Read the current script
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace the validation section in main()
    validation_section = '''        # Create manifest
        downloader.create_manifest(output_dir, dependencies)

        print("=" * 60)
        print("🔍 Validating Downloaded Packages...")
        print("=" * 60)
        
        # Validate main dependencies
        main_validation = downloader.validator.validate_directory(output_dir, len(dependencies))
        uv_dir = output_dir / "uv-deps"
        
        # Validate UV dependencies if they exist
        uv_validation = None
        if uv_dir.exists():
            uv_validation = downloader.validator.validate_directory(uv_dir)
        
        # Generate validation reports
        downloader.validator.generate_validation_report(main_validation, output_dir / "validation-report-main.md")
        if uv_validation:
            downloader.validator.generate_validation_report(uv_validation, output_dir / "validation-report-uv.md")
        
        print("=" * 60)
        print("📊 Download & Validation Summary")
        print("=" * 60)
        print(f"Main dependencies: {main_validation['valid_files']}/{main_validation['total_files']} valid wheels")
        if uv_validation:
            print(f"UV dependencies: {uv_validation['valid_files']}/{uv_validation['total_files']} valid wheels")
        print(f"Total size: {(main_validation['total_size'] + (uv_validation['total_size'] if uv_validation else 0)) / 1024 / 1024:.1f} MB")
        print(f"Output directory: {output_dir.absolute()}")
        
        # Check if validation passed
        main_success_rate = main_validation['valid_files'] / main_validation['total_files'] if main_validation['total_files'] > 0 else 0
        uv_success_rate = uv_validation['valid_files'] / uv_validation['total_files'] if uv_validation and uv_validation['total_files'] > 0 else 1
        
        overall_success = main_success_rate >= 0.9 and uv_success_rate >= 0.9  # 90% success rate required
        
        if overall_success:
            print("\\n✅ All packages validated successfully!")
            print("\\n📋 Validation Reports:")
            print(f"- Main dependencies: {output_dir}/validation-report-main.md")
            if uv_validation:
                print(f"- UV dependencies: {output_dir}/validation-report-uv.md")
        else:
            print(f"\\n⚠️  Some packages failed validation (success rate: {main_success_rate:.1%})")
            print("Please review the validation reports for details.")
            
        print("\\n🚀 Next Steps:")
        print("1. Copy this directory to your portable package")
        print("2. Run install-dependencies-offline.bat/.sh to install offline")
        print("3. Review validation reports if there were any issues")'''
    
    # Find and replace the old validation section
    pattern = r'        # Create manifest\s*\n.*?print\("2\. Run install-dependencies-offline\.bat to install offline"\)'
    replacement = validation_section
    
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # Also fix the safe_print call
    new_content = new_content.replace('safe_print(f"[ERROR] Error: {e!s}")', 'print(f"❌ Error: {e!s}")')
    
    # Write the enhanced script
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"✅ Enhanced {script_path} with validation features")
    return True


if __name__ == "__main__":
    enhance_dependencies_script()