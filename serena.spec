# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec file for Serena Standalone.

Build commands:
    # One-file executable (slower startup, easier distribution)
    pyinstaller serena.spec --onefile

    # One-folder executable (faster startup)
    pyinstaller serena.spec --onedir

    # Build with specific variant (slim, standard, full)
    SERENA_BUILD_VARIANT=slim pyinstaller serena.spec --onefile
    SERENA_BUILD_VARIANT=full pyinstaller serena.spec --onefile

Output will be in dist/serena-mcp-server[.exe]

Build Variants:
    - slim: Minimal build without tiktoken, anthropic SDK, jinja2 templates
            Size: ~50MB, Languages: Python (via pyright)
    - standard: Default build with all current functionality (default)
            Size: ~80MB, Languages: Python (via pyright), requires Node.js for TS/YAML/Bash/PHP
    - full: Complete offline build with bundled Node.js runtime and npm-based language servers
            Size: ~180MB, Languages: Python, TypeScript, JavaScript, YAML, Bash, PHP (offline)

Full Variant - Bundled Language Servers:
    The 'full' variant includes pre-installed npm-based language servers for offline use:
    - TypeScript/JavaScript: typescript-language-server@4.3.3, typescript@5.5.4
    - YAML: yaml-language-server@1.19.2
    - Bash: bash-language-server@5.6.0
    - PHP: intelephense@1.14.4
    - VTS (TypeScript via VSCode): @vtsls/language-server@0.2.9

    These are bundled in the ./language_servers/ directory alongside the executable.
    The bundled Node.js runtime is in ./node/ directory.

Environment Variables (for standalone mode):
    - SERENA_STANDALONE=1: Enable standalone mode (auto-detected for frozen builds)
    - SERENA_BUNDLED_LS_DIR: Override path to bundled language servers
    - SERENA_BUNDLED_NODE: Override path to bundled Node.js executable
"""

import os
import sys
from pathlib import Path

block_cipher = None

# Project paths
PROJECT_ROOT = Path(SPECPATH)
SRC_DIR = PROJECT_ROOT / "src"

# =============================================================================
# BUILD VARIANT CONFIGURATION
# =============================================================================
# Determine build variant from environment variable
VARIANT = os.environ.get('SERENA_BUILD_VARIANT', 'standard').lower()

# Validate variant
VALID_VARIANTS = ['slim', 'standard', 'full']
if VARIANT not in VALID_VARIANTS:
    print(f"WARNING: Invalid variant '{VARIANT}'. Using 'standard'.")
    VARIANT = 'standard'

print(f"Building Serena variant: {VARIANT.upper()}")

# =============================================================================
# HIDDEN IMPORTS
# =============================================================================
# PyInstaller doesn't automatically detect dynamic imports.
# These must be explicitly listed.

# Language Server implementations (dynamically imported in ls_config.py)
ls_hidden_imports = [
    "solidlsp.language_servers.pyright_server",
    "solidlsp.language_servers.jedi_server",
    "solidlsp.language_servers.eclipse_jdtls",
    "solidlsp.language_servers.kotlin_language_server",
    "solidlsp.language_servers.rust_analyzer",
    "solidlsp.language_servers.csharp_language_server",
    "solidlsp.language_servers.omnisharp",
    "solidlsp.language_servers.typescript_language_server",
    "solidlsp.language_servers.vts_language_server",
    "solidlsp.language_servers.gopls",
    "solidlsp.language_servers.ruby_lsp",
    "solidlsp.language_servers.solargraph",
    "solidlsp.language_servers.dart_language_server",
    "solidlsp.language_servers.clangd_language_server",
    "solidlsp.language_servers.intelephense",
    "solidlsp.language_servers.perl_language_server",
    "solidlsp.language_servers.clojure_lsp",
    "solidlsp.language_servers.elixir_tools.elixir_tools",
    "solidlsp.language_servers.elm_language_server",
    "solidlsp.language_servers.terraform_ls",
    "solidlsp.language_servers.sourcekit_lsp",
    "solidlsp.language_servers.bash_language_server",
    "solidlsp.language_servers.yaml_language_server",
    "solidlsp.language_servers.zls",
    "solidlsp.language_servers.nixd_ls",
    "solidlsp.language_servers.lua_ls",
    "solidlsp.language_servers.erlang_language_server",
    "solidlsp.language_servers.al_language_server",
    "solidlsp.language_servers.regal_server",
    "solidlsp.language_servers.marksman",
    "solidlsp.language_servers.r_language_server",
    "solidlsp.language_servers.scala_language_server",
    "solidlsp.language_servers.julia_server",
    "solidlsp.language_servers.fortran_language_server",
    "solidlsp.language_servers.haskell_language_server",
    "solidlsp.language_servers.common",
]

# Serena tools (wildcard imports in tools/__init__.py)
tool_hidden_imports = [
    "serena.tools",
    "serena.tools.tools_base",
    "serena.tools.file_tools",
    "serena.tools.symbol_tools",
    "serena.tools.memory_tools",
    "serena.tools.cmd_tools",
    "serena.tools.config_tools",
    "serena.tools.workflow_tools",
    "serena.tools.jetbrains_tools",
    "serena.tools.jetbrains_plugin_client",
]

# Core third-party libraries (required for all variants)
core_third_party_imports = [
    # MCP Framework
    "mcp",
    "mcp.server",
    "mcp.server.fastmcp",
    "mcp.server.fastmcp.server",
    "mcp.server.fastmcp.tools",
    "mcp.server.fastmcp.tools.base",
    "mcp.server.fastmcp.utilities",
    "mcp.server.fastmcp.utilities.func_metadata",
    # Pydantic
    "pydantic",
    "pydantic.fields",
    "pydantic.main",
    "pydantic._internal",
    "pydantic._internal._core_utils",
    "pydantic._internal._decorators",
    "pydantic._internal._fields",
    "pydantic._internal._generics",
    "pydantic._internal._model_construction",
    "pydantic._internal._validators",
    "pydantic.deprecated.decorator",
    "pydantic_settings",
    "pydantic_core",
    # SensAI utilities
    "sensai",
    "sensai.util",
    "sensai.util.logging",
    "sensai.util.pickle",
    "sensai.util.string",
    # YAML processing
    "yaml",
    "ruamel",
    "ruamel.yaml",
    # Flask dashboard
    "flask",
    "werkzeug",
    # HTTP/Network
    "requests",
    "urllib3",
    "charset_normalizer",
    # CLI
    "click",
    # Other utilities
    "docstring_parser",
    "pathspec",
    "pathspec.patterns",
    "pathspec.patterns.gitwildmatch",
    "psutil",
    "tqdm",
    "joblib",
    "overrides",
    # dotenv
    "dotenv",
]

# Extended imports for standard and full builds (excluded in slim)
extended_third_party_imports = [
    # Anthropic SDK (for AI features)
    "anthropic",
    # Token counting
    "tiktoken",
    "tiktoken_ext",
    "tiktoken_ext.openai_public",
    # Jinja2 templates (for prompt templating)
    "jinja2",
    "jinja2.ext",
    # Interprompt module (depends on jinja2)
    "interprompt",
    "interprompt.jinja_template",
    "interprompt.multilang_prompt",
    "interprompt.prompt_factory",
    "interprompt.util",
    "interprompt.util.class_decorators",
]

# Build variant-specific imports
third_party_imports = core_third_party_imports.copy()

if VARIANT in ['standard', 'full']:
    # Standard and full builds include all extended functionality
    third_party_imports += extended_third_party_imports
    print(f"  Including extended imports (anthropic, tiktoken, jinja2, interprompt)")
else:
    print(f"  Excluding extended imports (slim build)")

# Platform-specific imports
platform_imports = []
if sys.platform != "win32":
    platform_imports.append("pwd")

# Combine all hidden imports
all_hidden_imports = (
    ls_hidden_imports + tool_hidden_imports + third_party_imports + platform_imports
)

# =============================================================================
# DATA FILES
# =============================================================================
# Resources that need to be bundled with the executable

datas = [
    # Serena resources (contexts, modes, templates, dashboard)
    (str(SRC_DIR / "serena" / "resources"), "serena/resources"),
]

# =============================================================================
# BUNDLED RESOURCES FOR FULL VARIANT
# =============================================================================
if VARIANT == 'full':
    print(f"  Full build: Checking for bundled resources...")

    # Check for bundled Node.js
    node_dir = PROJECT_ROOT / "node"
    if node_dir.exists():
        datas.append((str(node_dir), "node"))
        # Calculate size for info
        node_size = sum(f.stat().st_size for f in node_dir.rglob('*') if f.is_file()) / (1024 * 1024)
        print(f"    [OK] Including bundled Node.js runtime (~{node_size:.1f} MB)")
    else:
        print(f"    [WARN] Node.js directory not found at {node_dir}")
        print(f"    [WARN] Full variant without Node.js - npm-based language servers may not work offline")

    # Check for bundled language servers (npm packages)
    ls_static_dir = PROJECT_ROOT / "language_servers"
    if ls_static_dir.exists():
        datas.append((str(ls_static_dir), "language_servers"))
        # Calculate size and list included servers
        ls_size = sum(f.stat().st_size for f in ls_static_dir.rglob('*') if f.is_file()) / (1024 * 1024)
        included_servers = [d.name for d in ls_static_dir.iterdir() if d.is_dir()]
        print(f"    [OK] Including bundled language servers (~{ls_size:.1f} MB)")
        print(f"         Servers: {', '.join(included_servers)}")
    else:
        print(f"    [WARN] Language servers directory not found at {ls_static_dir}")
        print(f"    [WARN] Full variant without bundled language servers")
        print(f"    [INFO] To bundle language servers, create ./language_servers/ with:")
        print(f"           - ts-lsp/node_modules/... (TypeScript)")
        print(f"           - yaml-lsp/node_modules/... (YAML)")
        print(f"           - bash-lsp/node_modules/... (Bash)")
        print(f"           - php-lsp/node_modules/... (PHP/Intelephense)")
        print(f"           - vts-lsp/node_modules/... (VTS TypeScript)")

# =============================================================================
# ANALYSIS
# =============================================================================
a = Analysis(
    [str(SRC_DIR / "serena" / "cli.py")],
    pathex=[str(SRC_DIR)],
    binaries=[],
    datas=datas,
    hiddenimports=all_hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude unnecessary large packages
        "tkinter",
        "matplotlib",
        "numpy",
        "pandas",
        "PIL",
        "scipy",
        "notebook",
        "IPython",
        "pytest",
        "sphinx",
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

# =============================================================================
# PYZ (Python Zip archive)
# =============================================================================
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# =============================================================================
# EXE - Single executable
# =============================================================================
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="serena-mcp-server",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,  # Enable UPX compression if available
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # MCP server needs console for stdio
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    # Uncomment to add icon on Windows:
    # icon='resources/serena.ico',
)

# =============================================================================
# COLLECT - For one-folder builds (--onedir)
# =============================================================================
# Note: COLLECT is only used when running: pyinstaller serena.spec --onedir
# For --onefile builds (the default), only EXE is needed.
# The EXE above already bundles all binaries/data for single-file distribution.
#
# To enable one-folder builds, uncomment below AND modify EXE above to
# remove a.binaries, a.zipfiles, a.datas from the EXE arguments.
#
# coll = COLLECT(
#     exe,
#     a.binaries,
#     a.zipfiles,
#     a.datas,
#     strip=False,
#     upx=True,
#     upx_exclude=[],
#     name="serena-mcp-server",
# )
