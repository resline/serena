# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for Serena - AI Coding Agent Toolkit

This spec file builds multiple executables for the Serena project:
- serena-mcp-server.exe (main MCP server)
- serena.exe (CLI interface) 
- index-project.exe (project indexing tool)

The spec file is designed to work with the Windows portable build system and
supports dynamic configuration via environment variables.

Environment Variables Used:
- SERENA_VERSION: Version string for the build
- SERENA_BUILD_TIER: Language server tier (minimal, essential, complete, full)
- LANGUAGE_SERVERS_DIR: Path to downloaded language servers
- PROJECT_ROOT: Root directory of the Serena project

Usage:
    pyinstaller serena.spec

Author: Serena Development Team
License: MIT
"""

import os
import sys
from pathlib import Path

# ==============================================================================
# Build Configuration
# ==============================================================================

# Get environment variables with fallbacks
PROJECT_ROOT = os.environ.get('PROJECT_ROOT', str(Path(__file__).parent.parent.parent))
LANGUAGE_SERVERS_DIR = os.environ.get('LANGUAGE_SERVERS_DIR', os.path.join(PROJECT_ROOT, 'build', 'language_servers'))
SERENA_VERSION = os.environ.get('SERENA_VERSION', '0.1.4')
BUILD_TIER = os.environ.get('SERENA_BUILD_TIER', 'essential')

# Build settings
ONEFILE = True  # Create single executable files
CONSOLE = True  # Show console window (required for CLI tools)
STRIP_BINARIES = True  # Strip debug information to reduce size
USE_UPX = False  # Disabled - UPX causes issues on Windows with some antivirus

# Paths
SRC_ROOT = os.path.join(PROJECT_ROOT, 'src')
SERENA_RESOURCES = os.path.join(SRC_ROOT, 'serena', 'resources')

print(f"=== PyInstaller Build Configuration ===")
print(f"PROJECT_ROOT: {PROJECT_ROOT}")
print(f"SRC_ROOT: {SRC_ROOT}")
print(f"LANGUAGE_SERVERS_DIR: {LANGUAGE_SERVERS_DIR}")
print(f"SERENA_VERSION: {SERENA_VERSION}")
print(f"BUILD_TIER: {BUILD_TIER}")
print(f"ONEFILE: {ONEFILE}")
print(f"==========================================")

# ==============================================================================
# Hidden Imports - Comprehensive Module List
# ==============================================================================

# Core Serena modules
serena_imports = [
    'serena.agent',
    'serena.cli', 
    'serena.mcp',
    'serena.project',
    'serena.dashboard',
    'serena.gui_log_viewer',
    'serena.analytics',
    'serena.code_editor',
    'serena.symbol',
    'serena.text_utils',
    'serena.agno',
    'serena.prompt_factory',
    
    # Configuration system
    'serena.config',
    'serena.config.context_mode',
    'serena.config.serena_config',
    'serena.constants',
    
    # Tools system
    'serena.tools',
    'serena.tools.tools_base',
    'serena.tools.file_tools',
    'serena.tools.symbol_tools',
    'serena.tools.memory_tools',
    'serena.tools.config_tools',
    'serena.tools.workflow_tools',
    'serena.tools.cmd_tools',
    'serena.tools.jetbrains_tools',
    'serena.tools.jetbrains_plugin_client',
    
    # Utilities
    'serena.util',
    'serena.util.logging',
    'serena.util.general',
    'serena.util.exception',
    'serena.util.class_decorators',
    
    # Generated modules
    'serena.generated.generated_prompt_factory',
]

# SolidLSP Language Server Protocol modules
solidlsp_imports = [
    'solidlsp',
    'solidlsp.ls',
    'solidlsp.ls_config',
    'solidlsp.util',
    'solidlsp.util.subprocess_util',
    
    # Language servers - core
    'solidlsp.language_servers.common',
    'solidlsp.language_servers.pyright_server',
    'solidlsp.language_servers.jedi_server',
    'solidlsp.language_servers.gopls',
    'solidlsp.language_servers.eclipse_jdtls',
    'solidlsp.language_servers.typescript_language_server',
    
    # Language servers - additional
    'solidlsp.language_servers.intelephense',
    'solidlsp.language_servers.omnisharp', 
    'solidlsp.language_servers.csharp_language_server',
    'solidlsp.language_servers.elixir_tools',
    'solidlsp.language_servers.elixir_tools.elixir_tools',
    'solidlsp.language_servers.terraform_language_server',
    'solidlsp.language_servers.clojure_lsp',
    'solidlsp.language_servers.swift_language_server',
    'solidlsp.language_servers.bash_language_server',
    'solidlsp.language_servers.ruby_lsp',
    'solidlsp.language_servers.rust_analyzer',
    'solidlsp.language_servers.clangd_language_server',
    'solidlsp.language_servers.kotlin_language_server',
    'solidlsp.language_servers.dart_language_server',
    'solidlsp.language_servers.lua_ls',
    'solidlsp.language_servers.nixd_ls',
    'solidlsp.language_servers.erlang_language_server',
    'solidlsp.language_servers.al_language_server',
]

# MCP (Model Context Protocol) modules
mcp_imports = [
    'mcp',
    'mcp.server',
    'mcp.server.fastmcp',
    'mcp.server.fastmcp.server',
    'mcp.server.fastmcp.tools',
    'mcp.server.fastmcp.tools.base',
    'mcp.server.fastmcp.utilities',
    'mcp.server.fastmcp.utilities.func_metadata',
    'mcp.types',
    'mcp.client',
    'mcp.client.session',
]

# Interprompt modules
interprompt_imports = [
    'interprompt',
    'interprompt.jinja_template',
    'interprompt.multilang_prompt', 
    'interprompt.prompt_factory',
    'interprompt.util',
    'interprompt.util.class_decorators',
]

# External dependencies
external_imports = [
    # HTTP and requests
    'requests',
    'requests.adapters',
    'requests.auth',
    'requests.cookies',
    'requests.models',
    'requests.sessions',
    'requests.structures',
    'requests.utils',
    
    # Anthropic AI SDK
    'anthropic',
    'anthropic.types',
    
    # Configuration and serialization
    'yaml', 
    'pyyaml',
    'ruamel.yaml',
    'ruamel.yaml.comments',
    'jinja2',
    'jinja2.ext',
    'jinja2.loaders',
    'jinja2.filters',
    
    # CLI framework
    'click',
    'click.core',
    'click.decorators',
    'click.types',
    'click.utils',
    
    # Data validation and modeling
    'pydantic',
    'pydantic.fields',
    'pydantic.main',
    'pydantic.types',
    'pydantic.validators',
    
    # System utilities
    'psutil',
    'pathspec',
    'tqdm',
    'joblib',
    'tiktoken',
    'docstring_parser',
    
    # Logging and utilities
    'sensai',
    'sensai.util',
    'sensai.util.logging',
    
    # Web framework
    'flask',
    'flask.app',
    'flask.helpers',
    'flask.json',
    
    # Development tools
    'overrides',
    'pyright',
]

# Windows-specific imports
windows_imports = [
    'win32api',
    'win32con', 
    'win32file',
    'win32pipe',
    'win32process',
    'win32security',
    'pywintypes',
    'pywin32_system32',
]

# Combine all hidden imports
hidden_imports = (
    serena_imports + 
    solidlsp_imports + 
    mcp_imports + 
    interprompt_imports +
    external_imports +
    windows_imports
)

# ==============================================================================
# Data Files Configuration
# ==============================================================================

datas = []

# Serena resources (templates, configs, etc.)
if os.path.exists(SERENA_RESOURCES):
    datas.append((SERENA_RESOURCES, 'serena/resources'))
    print(f"Added Serena resources: {SERENA_RESOURCES}")

# Language servers (if available)
if os.path.exists(LANGUAGE_SERVERS_DIR):
    datas.append((LANGUAGE_SERVERS_DIR, 'language_servers'))
    print(f"Added language servers: {LANGUAGE_SERVERS_DIR}")
else:
    print(f"Warning: Language servers directory not found: {LANGUAGE_SERVERS_DIR}")

# Portable runtimes (if available) - for offline functionality
RUNTIMES_DIR = os.environ.get('RUNTIMES_DIR', os.path.join(PROJECT_ROOT, 'build', 'runtimes'))
if os.path.exists(RUNTIMES_DIR):
    datas.append((RUNTIMES_DIR, 'runtimes'))
    print(f"Added portable runtimes: {RUNTIMES_DIR}")
    
    # List included runtimes
    runtime_dirs = ['nodejs', 'dotnet', 'java']
    for runtime in runtime_dirs:
        runtime_path = os.path.join(RUNTIMES_DIR, runtime)
        if os.path.exists(runtime_path):
            size_mb = sum(os.path.getsize(os.path.join(dirpath, filename))
                         for dirpath, dirnames, filenames in os.walk(runtime_path)
                         for filename in filenames) / (1024 * 1024)
            print(f"  - {runtime}: {size_mb:.2f} MB")
else:
    print(f"Note: Portable runtimes not found: {RUNTIMES_DIR}")
    print("  Language servers requiring Node.js/.NET/Java will need external runtimes")

# Version information file (if exists)
version_info_path = os.path.join(os.path.dirname(__file__), 'version_info.txt')
version_info = version_info_path if os.path.exists(version_info_path) else None

# Icon file (if exists)
icon_path = os.path.join(os.path.dirname(__file__), 'serena.ico')
icon = icon_path if os.path.exists(icon_path) else None

# ==============================================================================
# Exclusion Patterns - Reduce Bundle Size
# ==============================================================================

excludes = [
    # Large GUI frameworks
    'tkinter',
    'tkinter.ttk',
    'turtle',
    
    # Scientific computing (heavy dependencies)
    'matplotlib',
    'numpy', 
    'pandas',
    'scipy',
    'sklearn',
    'jupyter',
    'notebook',
    
    # Development tools  
    'pytest',
    'black',
    'mypy',
    'ruff',
    'setuptools',
    'pip',
    'wheel',
    
    # Alternative language servers not needed
    'pylsp',
    'rope',
    
    # Large optional dependencies
    'torch',
    'tensorflow',
    'cv2',
    'PIL.Image',
]

# ==============================================================================
# PyInstaller Analysis Configuration
# ==============================================================================

# Main MCP server analysis
mcp_server_analysis = Analysis(
    [os.path.join(SRC_ROOT, 'serena', 'cli.py')],
    pathex=[PROJECT_ROOT, SRC_ROOT],
    binaries=[],
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
    module_collection_mode={
        'pydantic': 'pyz',  # Include pydantic in PYZ
        'requests': 'pyz',
        'anthropic': 'pyz', 
    }
)

# ==============================================================================
# Executable Targets
# ==============================================================================

# Build PYZ archive
pyz = PYZ(mcp_server_analysis.pure, mcp_server_analysis.zipped_data, cipher=None)

# Primary executable: serena-mcp-server
mcp_server_exe = EXE(
    pyz,
    mcp_server_analysis.scripts,
    mcp_server_analysis.binaries,
    mcp_server_analysis.zipfiles,
    mcp_server_analysis.datas,
    [],
    name='serena-mcp-server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=STRIP_BINARIES,
    upx=USE_UPX,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=CONSOLE,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    version=version_info,
    icon=icon,
    manifest=None,
    onefile=ONEFILE,
)

# CLI wrapper executable: serena
serena_cli_analysis = Analysis(
    [os.path.join(SRC_ROOT, 'serena', 'cli.py')],
    pathex=[PROJECT_ROOT, SRC_ROOT],
    binaries=[],
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

serena_cli_pyz = PYZ(serena_cli_analysis.pure, serena_cli_analysis.zipped_data, cipher=None)

serena_cli_exe = EXE(
    serena_cli_pyz,
    serena_cli_analysis.scripts,
    serena_cli_analysis.binaries,
    serena_cli_analysis.zipfiles,
    serena_cli_analysis.datas,
    [],
    name='serena',
    debug=False,
    bootloader_ignore_signals=False,
    strip=STRIP_BINARIES,
    upx=USE_UPX,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=CONSOLE,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    version=version_info,
    icon=icon,
    manifest=None,
    onefile=ONEFILE,
)

# Project indexing tool: index-project  
index_project_analysis = Analysis(
    [os.path.join(SRC_ROOT, 'serena', 'cli.py')],
    pathex=[PROJECT_ROOT, SRC_ROOT],
    binaries=[],
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

index_project_pyz = PYZ(index_project_analysis.pure, index_project_analysis.zipped_data, cipher=None)

index_project_exe = EXE(
    index_project_pyz,
    index_project_analysis.scripts,
    index_project_analysis.binaries,
    index_project_analysis.zipfiles,
    index_project_analysis.datas,
    [],
    name='index-project',
    debug=False,
    bootloader_ignore_signals=False,
    strip=STRIP_BINARIES,
    upx=USE_UPX,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=CONSOLE,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    version=version_info,
    icon=icon,
    manifest=None,
    onefile=ONEFILE,
)

# ==============================================================================
# Bundle Collection (if not using ONEFILE)
# ==============================================================================

if not ONEFILE:
    # Create COLLECT bundle for directory-based distribution
    coll = COLLECT(
        mcp_server_exe,
        serena_cli_exe, 
        index_project_exe,
        mcp_server_analysis.binaries,
        mcp_server_analysis.zipfiles,
        mcp_server_analysis.datas,
        strip=STRIP_BINARIES,
        upx=USE_UPX,
        upx_exclude=[],
        name='serena-bundle',
    )

# ==============================================================================
# Build Summary
# ==============================================================================

print(f"\n=== PyInstaller Build Summary ===")
print(f"Build type: {'Single file' if ONEFILE else 'Directory bundle'}")
print(f"Console mode: {CONSOLE}")
print(f"Strip binaries: {STRIP_BINARIES}")
print(f"UPX compression: {USE_UPX}")
print(f"Hidden imports: {len(hidden_imports)} modules")
print(f"Data files: {len(datas)} entries")
print(f"Excluded modules: {len(excludes)} modules")
print(f"Version info: {'Yes' if version_info else 'No'}")
print(f"Icon: {'Yes' if icon else 'No'}")
print(f"=================================")

# Entry point functions for CLI tools
print(f"\n=== Entry Points ===")
print(f"serena-mcp-server -> serena.cli:start_mcp_server")
print(f"serena -> serena.cli:main") 
print(f"index-project -> serena.cli:index_project")
print(f"====================")