#!/usr/bin/env python3
"""
Download language servers for offline/corporate deployment
Handles proxy and certificate issues
"""

import os
import sys
import json
import urllib.request
import urllib.error
import ssl
import zipfile
import tarfile
import gzip
import shutil
from pathlib import Path
from typing import Dict, Any

class CorporateDownloader:
    def __init__(self, proxy_url: str = None, ca_cert_path: str = None):
        self.proxy_url = proxy_url or os.environ.get('HTTP_PROXY')
        self.ca_cert_path = ca_cert_path or os.environ.get('REQUESTS_CA_BUNDLE')
        self.setup_urllib()
        
    def setup_urllib(self):
        """Configure urllib for corporate proxy and certificates"""
        # Setup proxy
        if self.proxy_url:
            proxy = urllib.request.ProxyHandler({
                'http': self.proxy_url,
                'https': self.proxy_url
            })
            opener = urllib.request.build_opener(proxy)
            urllib.request.install_opener(opener)
            print(f"✓ Configured proxy: {self.proxy_url}")
        
        # Setup SSL context
        self.ssl_context = ssl.create_default_context()
        if self.ca_cert_path and os.path.exists(self.ca_cert_path):
            self.ssl_context.load_verify_locations(self.ca_cert_path)
            print(f"✓ Loaded CA certificate: {self.ca_cert_path}")
        else:
            # For testing/dev only - disable SSL verification
            # Remove this in production!
            # self.ssl_context.check_hostname = False
            # self.ssl_context.verify_mode = ssl.CERT_NONE
            pass

    def download_file(self, url: str, dest_path: Path, description: str = ""):
        """Download file with progress indication"""
        print(f"Downloading {description or url}...")
        
        try:
            # Create request with headers
            req = urllib.request.Request(url, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            })
            
            with urllib.request.urlopen(req, context=self.ssl_context) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0
                block_size = 8192
                
                with open(dest_path, 'wb') as f:
                    while True:
                        chunk = response.read(block_size)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if total_size > 0:
                            percent = (downloaded / total_size) * 100
                            print(f"\r  Progress: {percent:.1f}%", end='', flush=True)
                
                print(f"\r  ✓ Downloaded {description}")
                return True
                
        except Exception as e:
            print(f"\r  ✗ Failed to download {description}: {str(e)}")
            return False

    def extract_archive(self, archive_path: Path, dest_dir: Path, archive_type: str):
        """Extract downloaded archive"""
        try:
            if archive_type == 'zip':
                with zipfile.ZipFile(archive_path, 'r') as zf:
                    zf.extractall(dest_dir)
            elif archive_type == 'tar.gz' or archive_type == 'tgz':
                with gzip.open(archive_path, 'rb') as gz:
                    with tarfile.open(fileobj=gz) as tar:
                        tar.extractall(dest_dir)
            elif archive_type == 'tar':
                with tarfile.open(archive_path, 'r') as tar:
                    tar.extractall(dest_dir)
            
            print(f"  ✓ Extracted to {dest_dir}")
            return True
            
        except Exception as e:
            print(f"  ✗ Failed to extract: {str(e)}")
            return False


def get_language_servers() -> Dict[str, Dict[str, Any]]:
    """Define language servers to download"""
    return {
        'pyright': {
            'url': 'https://registry.npmjs.org/pyright/-/pyright-1.1.396.tgz',
            'type': 'tgz',
            'description': 'Python Language Server (Pyright)',
            'post_extract': lambda d: (d / 'package').rename(d / 'pyright')
        },
        'typescript': {
            'url': 'https://registry.npmjs.org/typescript-language-server/-/typescript-language-server-4.3.3.tgz',
            'type': 'tgz',
            'description': 'TypeScript Language Server',
        },
        'vscode-langservers-extracted': {
            'url': 'https://registry.npmjs.org/vscode-langservers-extracted/-/vscode-langservers-extracted-4.10.0.tgz',
            'type': 'tgz',
            'description': 'VS Code Language Servers (HTML, CSS, JSON)',
        },
        'gopls': {
            'url': 'https://github.com/golang/tools/releases/download/gopls%2Fv0.16.2/gopls_v0.16.2_windows_amd64.zip',
            'type': 'zip',
            'description': 'Go Language Server (gopls)',
            'platform_specific': True,
            'platforms': {
                'win32': 'https://github.com/golang/tools/releases/download/gopls%2Fv0.16.2/gopls_v0.16.2_windows_amd64.zip',
                'linux': 'https://github.com/golang/tools/releases/download/gopls%2Fv0.16.2/gopls_v0.16.2_linux_amd64.tar.gz',
                'darwin': 'https://github.com/golang/tools/releases/download/gopls%2Fv0.16.2/gopls_v0.16.2_darwin_amd64.tar.gz'
            }
        },
        'rust-analyzer': {
            'url': 'https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-pc-windows-msvc.zip',
            'type': 'zip',
            'description': 'Rust Language Server',
            'platform_specific': True,
            'platforms': {
                'win32': 'https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-pc-windows-msvc.zip',
                'linux': 'https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-unknown-linux-gnu.gz',
                'darwin': 'https://github.com/rust-lang/rust-analyzer/releases/download/2024-12-30/rust-analyzer-x86_64-apple-darwin.gz'
            }
        },
        'jdtls': {
            'url': 'https://download.eclipse.org/jdtls/milestones/1.40.0/jdt-language-server-1.40.0-202410021750.tar.gz',
            'type': 'tar.gz',
            'description': 'Java Language Server (Eclipse JDT.LS)',
        },
        'omnisharp': {
            'url': 'https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-win-x64.zip',
            'type': 'zip',
            'description': 'C# Language Server (OmniSharp)',
            'platform_specific': True,
            'platforms': {
                'win32': 'https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-win-x64.zip',
                'linux': 'https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-linux-x64.tar.gz',
                'darwin': 'https://github.com/OmniSharp/omnisharp-roslyn/releases/download/v1.39.12/omnisharp-osx-x64.tar.gz'
            }
        },
        'clangd': {
            'url': 'https://github.com/clangd/clangd/releases/download/19.1.0/clangd-windows-19.1.0.zip',
            'type': 'zip',
            'description': 'C/C++ Language Server (clangd)',
            'platform_specific': True,
            'platforms': {
                'win32': 'https://github.com/clangd/clangd/releases/download/19.1.0/clangd-windows-19.1.0.zip',
                'linux': 'https://github.com/clangd/clangd/releases/download/19.1.0/clangd-linux-19.1.0.zip',
                'darwin': 'https://github.com/clangd/clangd/releases/download/19.1.0/clangd-mac-19.1.0.zip'
            }
        }
    }


def main():
    # Parse arguments
    import argparse
    parser = argparse.ArgumentParser(description='Download language servers for offline deployment')
    parser.add_argument('--proxy', help='HTTP proxy URL')
    parser.add_argument('--cert', help='CA certificate bundle path')
    parser.add_argument('--output', default='language-servers', help='Output directory')
    parser.add_argument('--servers', nargs='+', help='Specific servers to download')
    args = parser.parse_args()
    
    # Initialize downloader
    downloader = CorporateDownloader(args.proxy, args.cert)
    
    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Get platform
    platform = sys.platform
    
    # Get servers to download
    all_servers = get_language_servers()
    if args.servers:
        servers = {k: v for k, v in all_servers.items() if k in args.servers}
    else:
        servers = all_servers
    
    print(f"\nDownloading {len(servers)} language servers to {output_dir}")
    print("=" * 60)
    
    success_count = 0
    
    for name, info in servers.items():
        server_dir = output_dir / name
        server_dir.mkdir(exist_ok=True)
        
        # Get platform-specific URL if needed
        if info.get('platform_specific'):
            url = info['platforms'].get(platform, info['url'])
            archive_type = 'zip' if platform == 'win32' else info['type']
        else:
            url = info['url']
            archive_type = info['type']
        
        # Download
        archive_name = f"{name}.{archive_type}"
        archive_path = server_dir / archive_name
        
        if downloader.download_file(url, archive_path, info['description']):
            # Extract
            if downloader.extract_archive(archive_path, server_dir, archive_type):
                # Run post-extract if defined
                if 'post_extract' in info:
                    try:
                        info['post_extract'](server_dir)
                    except:
                        pass
                
                # Clean up archive
                archive_path.unlink()
                success_count += 1
            
        print()
    
    print("=" * 60)
    print(f"Successfully downloaded {success_count}/{len(servers)} language servers")
    
    if success_count < len(servers):
        print("\nFailed servers can be manually downloaded from:")
        for name, info in servers.items():
            if not (output_dir / name).exists():
                print(f"  - {name}: {info['url']}")
    
    # Create manifest
    manifest = {
        'version': '1.0',
        'servers': list(servers.keys()),
        'platform': platform,
        'success_count': success_count
    }
    
    with open(output_dir / 'manifest.json', 'w') as f:
        json.dump(manifest, f, indent=2)
    
    print(f"\nPackage ready at: {output_dir}")
    print("Copy this directory to target machines for offline deployment")


if __name__ == '__main__':
    main()