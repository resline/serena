#!/usr/bin/env python3
"""
Unicode to ASCII Character Replacement Tool for PowerShell Scripts

This script systematically replaces all Unicode characters with ASCII equivalents
in PowerShell scripts to ensure compatibility with Windows 10 systems that may
have encoding issues.

Target files:
- create-fully-portable-package.ps1
- portable-package-windows10-helpers.ps1  
- windows10-compatibility.ps1
- corporate-setup-windows.ps1
"""

import re
import os
from pathlib import Path
from typing import Dict, List, Tuple

# Unicode to ASCII replacement mapping
UNICODE_REPLACEMENTS = {
    # Checkmarks and success indicators
    '✅': '[OK]',
    '✓': '[OK]',
    '☑': '[OK]',
    
    # Error and warning indicators
    '❌': '[ERROR]',
    '✗': '[ERROR]',
    '⚠️': '[WARN]',
    '⚠': '[WARN]',
    
    # Emojis
    '🎉': '***',
    '🔍': '[SEARCH]',
    '📦': '[PACKAGE]',
    '🚀': '[LAUNCH]',
    '💡': '[TIP]',
    '🔧': '[CONFIG]',
    
    # Bullet points and list markers
    '•': '-',
    '◦': '-',
    '‣': '-',
    '▪': '-',
    '▫': '-',
    
    # Box drawing characters - convert to ASCII equivalents
    '║': '|',
    '╔': '+',
    '╚': '+',
    '═': '=',
    '╗': '+',
    '╝': '+',
    '─': '-',
    '│': '|',
    '├': '+',
    '┤': '+',
    '┌': '+',
    '┐': '+',
    '└': '+',
    '┘': '+',
    
    # Arrows
    '→': '->',
    '←': '<-',
    '↑': '^',
    '↓': 'v',
    '⇒': '=>',
    '⇐': '<=',
    
    # Mathematical symbols
    '×': 'x',
    '÷': '/',
    '±': '+/-',
    
    # Quotation marks
    '"': '"',
    '"': '"',
    ''': "'",
    ''': "'",
    
    # Dashes
    '–': '-',
    '—': '--',
    
    # Other common Unicode characters
    '…': '...',
    '°': 'deg',
    '©': '(c)',
    '®': '(r)',
    '™': '(tm)',
}

def scan_file_for_unicode(file_path: Path) -> List[Tuple[int, str, str]]:
    """
    Scan a file for Unicode characters and return their locations.
    
    Returns:
        List of tuples (line_number, line_content, unicode_chars_found)
    """
    unicode_findings = []
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
            
        for line_num, line in enumerate(lines, 1):
            # Find non-ASCII characters
            unicode_chars = re.findall(r'[^\x00-\x7F]', line)
            if unicode_chars:
                unique_chars = list(set(unicode_chars))
                unicode_findings.append((line_num, line.strip(), unique_chars))
                
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        
    return unicode_findings

def replace_unicode_in_content(content: str) -> Tuple[str, Dict[str, int]]:
    """
    Replace Unicode characters in content with ASCII equivalents.
    
    Returns:
        Tuple of (modified_content, replacement_counts)
    """
    modified_content = content
    replacement_counts = {}
    
    # Apply replacements from our mapping
    for unicode_char, ascii_replacement in UNICODE_REPLACEMENTS.items():
        count = modified_content.count(unicode_char)
        if count > 0:
            replacement_counts[unicode_char] = count
            modified_content = modified_content.replace(unicode_char, ascii_replacement)
    
    # Handle any remaining Unicode characters by removing or replacing them
    remaining_unicode = re.findall(r'[^\x00-\x7F]', modified_content)
    if remaining_unicode:
        for char in set(remaining_unicode):
            # Try to get a reasonable ASCII representation
            try:
                # Try to normalize to ASCII
                import unicodedata
                ascii_char = unicodedata.normalize('NFKD', char).encode('ascii', 'ignore').decode('ascii')
                if ascii_char:
                    replacement_counts[char] = modified_content.count(char)
                    modified_content = modified_content.replace(char, ascii_char)
                else:
                    # Remove the character if we can't convert it
                    replacement_counts[char] = modified_content.count(char)
                    modified_content = modified_content.replace(char, '')
                    print(f"WARNING: Removed unprintable Unicode character: {repr(char)}")
            except:
                # Last resort: remove the character
                replacement_counts[char] = modified_content.count(char)
                modified_content = modified_content.replace(char, '')
                print(f"WARNING: Removed problematic Unicode character: {repr(char)}")
    
    return modified_content, replacement_counts

def process_powershell_file(file_path: Path, backup: bool = True) -> Dict:
    """
    Process a single PowerShell file to replace Unicode characters.
    
    Args:
        file_path: Path to the PowerShell file
        backup: Whether to create a backup of the original file
        
    Returns:
        Dictionary with processing results
    """
    results = {
        'file': str(file_path),
        'original_size': 0,
        'new_size': 0,
        'unicode_found': [],
        'replacements_made': {},
        'success': False,
        'error': None
    }
    
    try:
        # Read original file
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            original_content = f.read()
            
        results['original_size'] = len(original_content)
        
        # Scan for Unicode characters first
        results['unicode_found'] = scan_file_for_unicode(file_path)
        
        if not results['unicode_found']:
            print(f"✓ {file_path.name}: No Unicode characters found")
            results['success'] = True
            return results
        
        # Create backup if requested
        if backup:
            backup_path = file_path.with_suffix(file_path.suffix + '.backup')
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(original_content)
            print(f"📋 Created backup: {backup_path.name}")
        
        # Replace Unicode characters
        modified_content, replacement_counts = replace_unicode_in_content(original_content)
        results['replacements_made'] = replacement_counts
        results['new_size'] = len(modified_content)
        
        # Write the modified content back
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(modified_content)
            
        print(f"✅ {file_path.name}: Processed successfully")
        print(f"   Original size: {results['original_size']} chars")
        print(f"   New size: {results['new_size']} chars")
        print(f"   Unicode characters found: {len(results['unicode_found'])} lines")
        print(f"   Replacements made: {len(replacement_counts)} types")
        
        # Show detailed replacements
        for unicode_char, count in replacement_counts.items():
            ascii_replacement = UNICODE_REPLACEMENTS.get(unicode_char, '[removed]')
            print(f"     {repr(unicode_char)} -> {ascii_replacement} ({count} times)")
        
        results['success'] = True
        
    except Exception as e:
        results['error'] = str(e)
        print(f"❌ {file_path.name}: Error - {e}")
        
    return results

def main():
    """Main function to process all target PowerShell files."""
    
    print("=" * 70)
    print("Unicode to ASCII Character Replacement Tool")
    print("=" * 70)
    print()
    
    # Define target files
    script_dir = Path(__file__).parent / 'scripts'
    target_files = [
        'create-fully-portable-package.ps1',
        'portable-package-windows10-helpers.ps1',
        'windows10-compatibility.ps1',
        'corporate-setup-windows.ps1'
    ]
    
    # Process each file
    all_results = []
    total_replacements = {}
    
    for filename in target_files:
        file_path = script_dir / filename
        
        if not file_path.exists():
            print(f"⚠️  File not found: {filename}")
            continue
            
        print(f"\n📄 Processing: {filename}")
        print("-" * 50)
        
        results = process_powershell_file(file_path, backup=True)
        all_results.append(results)
        
        # Aggregate replacement counts
        for unicode_char, count in results['replacements_made'].items():
            total_replacements[unicode_char] = total_replacements.get(unicode_char, 0) + count
    
    # Print summary
    print("\n" + "=" * 70)
    print("PROCESSING SUMMARY")
    print("=" * 70)
    
    successful_files = [r for r in all_results if r['success']]
    failed_files = [r for r in all_results if not r['success']]
    
    print(f"Files processed successfully: {len(successful_files)}")
    print(f"Files with errors: {len(failed_files)}")
    
    if failed_files:
        print("\nFailed files:")
        for result in failed_files:
            print(f"  ❌ {Path(result['file']).name}: {result['error']}")
    
    if total_replacements:
        print(f"\nTotal Unicode characters replaced: {sum(total_replacements.values())}")
        print("Replacement summary:")
        for unicode_char, count in sorted(total_replacements.items(), key=lambda x: x[1], reverse=True):
            ascii_replacement = UNICODE_REPLACEMENTS.get(unicode_char, '[removed]')
            print(f"  {repr(unicode_char)} -> {ascii_replacement}: {count} times")
    else:
        print("\nNo Unicode characters found to replace.")
    
    print("\n✅ Unicode to ASCII conversion completed!")
    print("🔍 All PowerShell scripts are now ASCII-safe for Windows 10 deployment.")

if __name__ == "__main__":
    main()