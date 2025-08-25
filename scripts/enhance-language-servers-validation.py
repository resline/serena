#!/usr/bin/env python3
"""
Enhancement script to add validation features to download-language-servers-offline.py
"""

import re
from pathlib import Path


def enhance_language_servers_script():
    """Enhance the language servers download script with validation"""
    
    script_path = Path("scripts/download-language-servers-offline.py")
    if not script_path.exists():
        print(f"❌ Script not found: {script_path}")
        return False
        
    # Read the current script
    with open(script_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add validator initialization
    content = content.replace(
        '    # Initialize downloader\n    downloader = CorporateDownloader(args.proxy, args.cert)',
        '    # Initialize downloader\n    downloader = CorporateDownloader(args.proxy, args.cert)\n    validator = LanguageServerValidator()'
    )
    
    # Add progress tracking to downloads
    content = content.replace(
        '    success_count = 0\n\n    for name, info in servers.items():',
        '    success_count = 0\n    \n    # Initialize progress tracker for downloads\n    progress = ProgressTracker(len(servers), "Downloading language servers")\n\n    for i, (name, info) in enumerate(servers.items()):\n        progress.update(i, name)'
    )
    
    # Complete progress tracking
    content = content.replace(
        '                success_count += 1\n\n        print()',
        '                success_count += 1\n    \n    progress.update(len(servers), "Complete")\n    print()'
    )
    
    # Replace the final section with enhanced validation
    final_section_old = '''    # Create manifest
    manifest = {"version": "1.0", "servers": list(servers.keys()), "platform": platform, "success_count": success_count}

    with open(output_dir / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"\\nPackage ready at: {output_dir}")
    print("Copy this directory to target machines for offline deployment")'''
    
    final_section_new = '''    # Create manifest
    manifest = {"version": "1.0", "servers": list(servers.keys()), "platform": platform, "success_count": success_count}

    with open(output_dir / "manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)

    print("\\n" + "=" * 60)
    print("🔍 Validating Language Servers...")
    print("=" * 60)
    
    # Validate all downloaded servers
    validation_results = validator.validate_all_servers(output_dir)
    
    # Generate validation report
    validator.generate_validation_report(validation_results, output_dir / "language-server-validation-report.md")
    
    print("\\n" + "=" * 60)
    print("📊 Download & Validation Summary")
    print("=" * 60)
    print(f"Downloaded: {success_count}/{len(servers)} language servers")
    print(f"Validated: {validation_results['valid_servers']}/{validation_results['total_servers']} servers")
    print(f"Total size: {validation_results['total_size'] / 1024 / 1024:.1f} MB")
    print(f"Output directory: {output_dir}")
    
    # Check validation results
    validation_success_rate = validation_results['valid_servers'] / validation_results['total_servers'] if validation_results['total_servers'] > 0 else 0
    
    if validation_success_rate >= 0.9:  # 90% success rate
        print("\\n✅ Language servers validated successfully!")
        print(f"📋 Validation report: {output_dir}/language-server-validation-report.md")
    else:
        print(f"\\n⚠️  Some servers failed validation (success rate: {validation_success_rate:.1%})")
        print("Please review the validation report for details.")
        
    print("\\n🚀 Next Steps:")
    print("1. Copy this directory to target machines for offline deployment")
    print("2. Review validation report for any issues")
    print("3. Test language servers in your development environment")
    
    # Show failed servers if any
    if success_count < len(servers):
        print("\\n⚠️  Failed downloads - manual installation required:")
        for name, info in servers.items():
            server_dir = output_dir / name
            if not server_dir.exists() or not any(server_dir.iterdir()):
                print(f"  - {name}: {info['url']}")'''
    
    content = content.replace(final_section_old, final_section_new)
    
    # Remove the old failed servers section
    content = content.replace('''
    if success_count < len(servers):
        print("\\nFailed servers can be manually downloaded from:")
        for name, info in servers.items():
            if not (output_dir / name).exists():
                print(f"  - {name}: {info['url']}")''', '')
    
    # Write the enhanced script
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Enhanced {script_path} with validation features")
    return True


if __name__ == "__main__":
    enhance_language_servers_script()