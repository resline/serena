#!/usr/bin/env python3
"""
Simple Enterprise Download Module for Serena Agent Offline Scripts

This provides basic enterprise networking support for proxy and SSL handling
in the offline download scripts.
"""

import os
import ssl
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional, Dict


class SimpleEnterpriseDownloader:
    """Simple enterprise downloader with proxy and SSL support."""
    
    def __init__(self, proxy_url: Optional[str] = None, no_ssl_verify: bool = False):
        self.proxy_url = proxy_url
        self.no_ssl_verify = no_ssl_verify
    
    def download_with_progress(self, url: str, target_path: Path, headers: Optional[Dict] = None) -> bool:
        """Download file with enterprise networking support."""
        try:
            # Create request
            request = urllib.request.Request(url, headers=headers or {})
            
            # Set up proxy if specified
            if self.proxy_url:
                proxy_handler = urllib.request.ProxyHandler({'http': self.proxy_url, 'https': self.proxy_url})
                opener = urllib.request.build_opener(proxy_handler)
            else:
                opener = urllib.request.build_opener()
            
            # Handle SSL verification
            if self.no_ssl_verify:
                ssl_context = ssl.create_default_context()
                ssl_context.check_hostname = False
                ssl_context.verify_mode = ssl.CERT_NONE
                https_handler = urllib.request.HTTPSHandler(context=ssl_context)
                opener = urllib.request.build_opener(https_handler)
            
            # Download
            with opener.open(request, timeout=300) as response:
                with open(target_path, 'wb') as f:
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        f.write(chunk)
            
            return True
            
        except Exception as e:
            print(f"Download failed: {e}")
            return False
    
    def get_environment_config(self) -> Dict[str, str]:
        """Get environment variables for subprocess calls."""
        env = os.environ.copy()
        
        if self.proxy_url:
            env['HTTP_PROXY'] = self.proxy_url
            env['HTTPS_PROXY'] = self.proxy_url
        
        if self.no_ssl_verify:
            env['PYTHONHTTPSVERIFY'] = '0'
        
        return env
    
    def get_pip_args(self) -> list:
        """Get additional pip arguments."""
        args = []
        
        if self.proxy_url:
            args.extend(['--proxy', self.proxy_url])
        
        if self.no_ssl_verify:
            args.extend(['--trusted-host', 'pypi.org'])
            args.extend(['--trusted-host', 'files.pythonhosted.org'])
        
        return args


def create_enterprise_downloader_from_args(args):
    """Create downloader from args."""
    return SimpleEnterpriseDownloader(
        proxy_url=getattr(args, 'proxy', None),
        no_ssl_verify=getattr(args, 'no_ssl_verify', False)
    )


def add_enterprise_args(parser):
    """Add enterprise args to parser."""
    group = parser.add_argument_group('enterprise networking')
    
    group.add_argument('--proxy', help='HTTP proxy URL')
    group.add_argument('--no-ssl-verify', action='store_true', help='Disable SSL verification')
    group.add_argument('--ca-bundle', help='Custom CA bundle path')
    group.add_argument('--config', help='Enterprise config file path')
    group.add_argument('--enterprise', action='store_true', help='Enable enterprise mode')