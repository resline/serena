# Serena Agent Installer - UI Design and User Experience

## Overview

The enhanced Serena Agent installer provides a professional, user-friendly experience with modern UI components and intelligent defaults. This document describes the installer UI flow, component selection options, and user experience design.

## Installer Wizard Flow

### 1. Welcome Page

```
╔════════════════════════════════════════════════════════════════╗
║  [Serena Logo]           Welcome to Serena Agent Setup         ║
║                                                                ║
║  Version 0.1.4                                                 ║
║  © 2025 Oraios AI                                              ║
║                                                                ║
║  This wizard will guide you through the installation of        ║
║  Serena Agent, an AI-powered coding agent toolkit with         ║
║  multi-language support through Language Server Protocol.      ║
║                                                                ║
║  Before continuing, please ensure:                             ║
║    • Windows 10 or later (64-bit)                              ║
║    • At least 500MB of free disk space                         ║
║    • Administrator privileges (for system-wide installation)   ║
║                                                                ║
║  Click Next to continue, or Cancel to exit Setup.              ║
║                                                                ║
║                                      [Cancel]  [< Back]  [Next >]║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- Professional branding with Serena logo
- Clear system requirements
- Version information prominently displayed
- Multi-language support (EN, DE, FR, ES)

---

### 2. License Agreement Page

```
╔════════════════════════════════════════════════════════════════╗
║  License Agreement                                              ║
║                                                                ║
║  Please review the license terms before installing Serena.     ║
║                                                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ MIT License                                               │ ║
║  │                                                           │ ║
║  │ Copyright (c) 2025 Oraios AI                              │ ║
║  │                                                           │ ║
║  │ Permission is hereby granted, free of charge, to any      │ ║
║  │ person obtaining a copy of this software and associated   │ ║
║  │ documentation files (the "Software"), to deal in the      │ ║
║  │ Software without restriction, including without           │ ║
║  │ limitation the rights to use, copy, modify, merge,        │ ║
║  │ publish, distribute, sublicense, and/or sell copies...    │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  [✓] I accept the terms in the License Agreement               ║
║                                                                ║
║                                      [Cancel]  [< Back]  [Next >]║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- Full MIT license text display
- Scrollable license text area
- Required acceptance checkbox
- Next button disabled until acceptance

---

### 3. Language Server Tier Selection (NEW)

```
╔════════════════════════════════════════════════════════════════╗
║  Language Server Tier Selection                                 ║
║                                                                ║
║  Choose which language servers to install based on your        ║
║  development needs. You can always add more later.             ║
║                                                                ║
║  ○ Minimal - No language servers                               ║
║     Core Serena functionality only                             ║
║     Installation size: ~150 MB                                 ║
║                                                                ║
║  ● Essential - Python, TypeScript, Go, Rust (Recommended)      ║
║     Most popular modern programming languages                  ║
║     Installation size: ~250 MB                                 ║
║                                                                ║
║  ○ Complete - Essential + Java, C#, Lua, Bash                  ║
║     Comprehensive support for enterprise languages             ║
║     Installation size: ~400 MB                                 ║
║                                                                ║
║  ○ Full - All 28+ supported languages                          ║
║     Maximum language support including specialized languages   ║
║     Installation size: ~650 MB                                 ║
║                                                                ║
║  ℹ Language servers provide IDE features like autocomplete,    ║
║    go-to-definition, and refactoring for each language.        ║
║                                                                ║
║                                      [Cancel]  [< Back]  [Next >]║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **NEW**: Dedicated tier selection page before components
- Visual radio buttons with clear descriptions
- Disk space estimates for each tier
- Default selection: Essential (recommended for most users)
- Informative tooltip explaining language servers
- Size estimates help users make informed decisions

**Tier Details:**

| Tier | Languages | Size | Use Case |
|------|-----------|------|----------|
| **Minimal** | None | 150 MB | CLI-only usage, minimal footprint |
| **Essential** | Python, TypeScript, Go, Rust | 250 MB | Modern web/systems development |
| **Complete** | + Java, C#, Lua, Bash | 400 MB | Enterprise polyglot development |
| **Full** | All 28+ languages | 650 MB | Maximum language coverage |

---

### 4. Component Selection Page

```
╔════════════════════════════════════════════════════════════════╗
║  Select Components                                              ║
║                                                                ║
║  Select the components you want to install; clear the          ║
║  components you do not want to install. Click Next when ready. ║
║                                                                ║
║  Installation Type: [Full Installation ▼]                      ║
║                                                                ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ [✓] Core Components (Required)              150.0 MB     │ ║
║  │     Serena Agent executables and libraries                │ ║
║  │                                                           │ ║
║  │ [✓] Language Servers (Selected Tier)        100.0 MB     │ ║
║  │     ├─ [✓] Essential Servers                100.0 MB     │ ║
║  │     │      Python, TypeScript, Go, Rust                   │ ║
║  │     ├─ [ ] Complete Servers                 150.0 MB     │ ║
║  │     │      + Java, C#, Lua, Bash                          │ ║
║  │     └─ [ ] Full Language Suite              250.0 MB     │ ║
║  │            All 28+ supported languages                     │ ║
║  │                                                           │ ║
║  │ [✓] User Configuration Directory             < 1.0 MB     │ ║
║  │     Initialize ~/.serena/ with default configs            │ ║
║  │                                                           │ ║
║  │ [✓] Start Menu Shortcuts                     < 1.0 MB     │ ║
║  │     Program shortcuts and documentation links             │ ║
║  │                                                           │ ║
║  │ [ ] Add to System PATH                       < 1.0 MB     │ ║
║  │     Command-line access from anywhere                     │ ║
║  │                                                           │ ║
║  │ [✓] File Associations (.serena)              < 1.0 MB     │ ║
║  │     Associate project files with Serena                   │ ║
║  │                                                           │ ║
║  │ [ ] Windows Defender Exclusions              < 1.0 MB     │ ║
║  │     Performance optimization (requires admin)             │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  Space required: 250.0 MB                                      ║
║  Space available: 125.5 GB                                     ║
║                                                                ║
║  Description: Core Serena Agent files (required) - 150MB      ║
║                                                                ║
║                                      [Cancel]  [< Back]  [Next >]║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **Hierarchical component tree** with language server tiers
- **Installation type dropdown:**
  - Full Installation (all components)
  - Essential Installation (core + essential LS)
  - Minimal Installation (core only)
  - Custom Installation (user selection)
- **Size information** for each component
- **Dynamic space calculation** shows total required space
- **Component descriptions** at bottom of page
- **Checkbox hierarchy** reflects tier selection from previous page
- **Intelligent defaults** based on tier selection

**Component Details:**

```
Core Components (Required)
├── serena.exe (main CLI)
├── serena-mcp-server.exe (MCP server)
├── index-project.exe (project indexer)
├── Python runtime and dependencies
└── Core libraries (~150 MB)

Language Servers
├── Essential Tier (~100 MB)
│   ├── pyright (Python)
│   ├── typescript-language-server
│   ├── gopls (Go)
│   └── rust-analyzer
├── Complete Tier (+150 MB)
│   ├── eclipse-jdtls (Java)
│   ├── omnisharp (C#)
│   ├── lua-language-server
│   └── bash-language-server
└── Full Tier (+250 MB)
    └── All 28+ language servers

User Configuration Directory
├── Creates ~/.serena/
├── Default serena_config.yml
├── memories/ subdirectory
└── projects/ subdirectory

Start Menu Shortcuts
├── Serena Agent (main launcher)
├── Serena MCP Server
├── Serena Configuration
├── Documentation
└── Uninstaller

System Integration
├── PATH environment variable
├── .serena file association
└── Windows Defender exclusions
```

---

### 5. Installation Directory Page

```
╔════════════════════════════════════════════════════════════════╗
║  Choose Install Location                                        ║
║                                                                ║
║  Setup will install Serena Agent in the following folder.      ║
║  To install in a different folder, click Browse and select     ║
║  another folder. Click Next to continue.                       ║
║                                                                ║
║  Destination Folder:                                           ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ C:\Program Files\Serena Agent                             │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                 [Browse...]    ║
║                                                                ║
║  Installation Type: System-wide (requires administrator)       ║
║                                                                ║
║  Disk Space Information:                                       ║
║    Required:  250.0 MB                                         ║
║    Available: 125.5 GB                                         ║
║    After:     125.3 GB                                         ║
║                                                                ║
║  ℹ For user-only installation, select:                         ║
║    C:\Users\[Username]\AppData\Local\Serena Agent              ║
║                                                                ║
║                                      [Cancel]  [< Back]  [Next >]║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **Default location**: C:\Program Files\Serena Agent (system)
- **Alternative**: %LOCALAPPDATA%\Serena Agent (user)
- **Browse button** for custom location
- **Disk space validation** prevents insufficient space installations
- **Installation type indicator** (system vs. user)
- **Automatic privilege detection** offers user installation if admin not available

---

### 6. Start Menu Folder Selection

```
╔════════════════════════════════════════════════════════════════╗
║  Choose Start Menu Folder                                       ║
║                                                                ║
║  Setup will create the program's shortcuts in the following    ║
║  Start Menu folder. To create in a different folder, select    ║
║  from the list or enter a name.                                ║
║                                                                ║
║  Start Menu Folder:                                            ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ Serena Agent                                              │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  Existing Folders:                                             ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │  Development Tools                                        │ ║
║  │  Programming                                              │ ║
║  │  Serena Agent                                             │ ║
║  │  System Tools                                             │ ║
║  │                                                           │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║  [ ] Don't create Start Menu folder                            ║
║                                                                ║
║                                      [Cancel]  [< Back]  [Next >]║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **Default folder**: Serena Agent
- **Existing folder list** for easy selection
- **Custom folder name** support
- **Option to skip** Start Menu folder creation

---

### 7. Installation Progress Page

```
╔════════════════════════════════════════════════════════════════╗
║  Installing                                                     ║
║                                                                ║
║  Please wait while Setup installs Serena Agent on your         ║
║  computer. This may take several minutes.                      ║
║                                                                ║
║  Status:                                                       ║
║  Installing core components...                                 ║
║                                                                ║
║  Progress:                                                     ║
║  ████████████████████░░░░░░░░░░░░░░░░░░░  45%                  ║
║                                                                ║
║  Details:                                                      ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ Extract: serena.exe                                       │ ║
║  │ Extract: serena-mcp-server.exe                            │ ║
║  │ Extract: _internal\python311.dll                          │ ║
║  │ Extract: _internal\library.zip                            │ ║
║  │ Creating directories...                                   │ ║
║  │ Installing language servers...                            │ ║
║  │   → pyright (Python language server)                      │ ║
║  │   → typescript-language-server                            │ ║
║  │   → gopls (Go language server)                            │ ║
║  │   → rust-analyzer                                         │ ║
║  │ Initializing user configuration: C:\Users\...\.serena\    │ ║
║  │ Creating shortcuts...                                     │ ║
║  │ Registering file associations...                          │ ║
║  │ Writing registry entries...                               │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                                ║
║                                                        [Cancel] ║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **Overall progress bar** shows installation completion
- **Status text** describes current operation
- **Detailed log window** shows file-by-file progress
- **Cancel button** allows aborting installation
- **Time estimate** (optional) shows expected completion
- **Real-time updates** as files are extracted and configured

---

### 8. Completion Page

```
╔════════════════════════════════════════════════════════════════╗
║  Completing the Serena Agent Setup Wizard                      ║
║                                                                ║
║  Setup has finished installing Serena Agent on your computer.  ║
║  The application may be launched by selecting the installed    ║
║  shortcuts.                                                    ║
║                                                                ║
║  Installation Summary:                                         ║
║    • Version: 0.1.4                                            ║
║    • Location: C:\Program Files\Serena Agent                   ║
║    • Language Tier: Essential (Python, TS, Go, Rust)           ║
║    • User Config: C:\Users\John\.serena\                       ║
║    • Total Size: 250.0 MB                                      ║
║                                                                ║
║  [✓] Run Serena version check (serena --version)               ║
║  [✓] Show README file                                          ║
║                                                                ║
║  Quick Start:                                                  ║
║    Open Command Prompt and type: serena --help                 ║
║    Start MCP server: serena-mcp-server                         ║
║                                                                ║
║  [ Visit https://github.com/oraios/serena ]                    ║
║                                                                ║
║  Click Finish to exit Setup.                                   ║
║                                                                ║
║                                                        [Finish] ║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **Installation summary** with key details
- **Launch options:**
  - Run version check (default)
  - Show README file
- **Quick start instructions** for immediate use
- **Website link** to documentation
- **Professional completion** message

---

## Silent Installation Interface

For enterprise deployments, the installer supports silent/unattended installation using INI configuration:

```bash
# Silent installation with all defaults
serena-installer-0.1.4.exe /S

# Silent installation with custom directory
serena-installer-0.1.4.exe /S /D=C:\Custom\Path

# Silent installation with INI configuration
serena-installer-0.1.4.exe /S /INI=config.ini

# Silent installation with tier selection
serena-installer-0.1.4.exe /S /TIER=essential /D=C:\Serena
```

### Example INI Configuration

```ini
[General]
InstallDir=C:\Program Files\Serena Agent
InstallType=full
LanguageServerTier=essential
StartMenuFolder=Serena Agent
Language=English

[Components]
Core=1
LanguageServers=1
UserConfig=1
Shortcuts=1
AddToPath=0
FileAssociations=1
DefenderExclusions=0

[Options]
InstallMode=system
SuppressReboot=1
ShowProgress=0
LaunchAfterInstall=0
AcceptLicense=1
```

---

## Uninstaller Interface

The uninstaller provides a similar professional experience:

```
╔════════════════════════════════════════════════════════════════╗
║  Uninstall Serena Agent                                         ║
║                                                                ║
║  Are you sure you want to completely remove Serena Agent       ║
║  and all of its components?                                    ║
║                                                                ║
║  Installation Details:                                         ║
║    • Version: 0.1.4                                            ║
║    • Location: C:\Program Files\Serena Agent                   ║
║    • Installed: 2025-01-16 14:30:25                            ║
║    • Size: 250.0 MB                                            ║
║                                                                ║
║  ⚠ User Configuration Directory:                               ║
║                                                                ║
║  Your user configuration directory contains project settings   ║
║  and memories: C:\Users\John\.serena\                          ║
║                                                                ║
║  [ ] Also remove user configuration directory                  ║
║      (This will delete all your project configurations)        ║
║                                                                ║
║  Components to remove:                                         ║
║    ✓ Core application files                                    ║
║    ✓ Language servers                                          ║
║    ✓ Start Menu shortcuts                                      ║
║    ✓ File associations                                         ║
║    ✓ PATH environment entries                                  ║
║    ✓ Windows Defender exclusions                               ║
║    ✓ Registry entries                                          ║
║                                                                ║
║                                          [Cancel]  [Uninstall] ║
╚════════════════════════════════════════════════════════════════╝
```

**Features:**
- **Installation information** display
- **User configuration preservation option**
- **Component checklist** shows what will be removed
- **Confirmation dialog** prevents accidental uninstall
- **Complete cleanup** of all installer artifacts

---

## User Experience Highlights

### Intelligent Defaults
- **Essential tier** selected by default (best for most users)
- **Recommended components** pre-selected
- **System-wide installation** with user fallback if no admin
- **File associations enabled** for .serena files

### User-Friendly Features
- **Progress feedback** at every step
- **Disk space validation** prevents failures
- **Detailed component descriptions**
- **Size estimates** help users make informed decisions
- **Upgrade detection** preserves existing settings

### Professional Polish
- **Modern UI** with consistent styling
- **Multi-language support** (EN, DE, FR, ES)
- **Helpful tooltips** and info boxes
- **Clear error messages** with resolution suggestions
- **Clean uninstall** with configuration preservation option

### Enterprise Features
- **Silent installation** support
- **INI-based configuration**
- **Group Policy compatible**
- **Network deployment ready**
- **Registry-based settings**

---

This UI design ensures a smooth, professional installation experience for all user types, from individual developers to enterprise IT administrators.
