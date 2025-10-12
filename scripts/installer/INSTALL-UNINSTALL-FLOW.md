# Serena Agent - Installation and Uninstallation Flow Diagrams

## Installation Flow Diagram

### High-Level Installation Process

```
┌─────────────────────────────────────────────────────────────────┐
│                    INSTALLATION FLOW                            │
└─────────────────────────────────────────────────────────────────┘

                        START INSTALLER
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │      Language Selection Dialog          │
        │  ┌───────────────────────────────────┐  │
        │  │ • English                         │  │
        │  │ • German                          │  │
        │  │ • French                          │  │
        │  │ • Spanish                         │  │
        │  └───────────────────────────────────┘  │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │     Prerequisites Validation            │
        │  • Windows 10+ (64-bit)?                │
        │  • Disk space available?                │
        │  • Admin privileges?                    │
        └─────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
               PASS │                   │ FAIL
                    ▼                   ▼
        ┌───────────────────┐  ┌────────────────────┐
        │ Continue Install  │  │ Offer User Install │
        └───────────────────┘  │ or Exit            │
                    │          └────────────────────┘
                    │                   │
                    │        ┌──────────┴────────┐
                    │        │                   │
                    │    Accept User         Abort
                    │        │                   │
                    └────────┴───────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │  Check for Previous Installation        │
        └─────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
              Found │                   │ Not Found
                    ▼                   ▼
        ┌───────────────────┐  ┌────────────────────┐
        │ Upgrade Dialog    │  │ Fresh Install      │
        │ • Preserve config │  └────────────────────┘
        │ • Migrate settings│           │
        └───────────────────┘           │
                    │                   │
                    └───────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │         WELCOME PAGE                    │
        │  • Product information                  │
        │  • Version display                      │
        │  • System requirements                  │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │       LICENSE AGREEMENT                 │
        │  • Display MIT license                  │
        │  • Acceptance checkbox                  │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │   LANGUAGE SERVER TIER SELECTION        │
        │  ○ Minimal  (No LS)        ~150 MB      │
        │  ● Essential (Core LS)     ~250 MB      │
        │  ○ Complete (+ More)       ~400 MB      │
        │  ○ Full     (All 28+)      ~650 MB      │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │      COMPONENT SELECTION                │
        │  [✓] Core Components (Required)         │
        │  [✓] Language Servers (Tier-based)      │
        │  [✓] User Config Directory              │
        │  [✓] Start Menu Shortcuts               │
        │  [ ] Add to PATH                        │
        │  [✓] File Associations                  │
        │  [ ] Windows Defender Exclusions        │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │    INSTALLATION DIRECTORY               │
        │  Default: C:\Program Files\Serena Agent │
        │  User:    %LOCALAPPDATA%\Serena Agent   │
        │  • Browse for custom location           │
        │  • Disk space validation                │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │     START MENU FOLDER                   │
        │  Default: "Serena Agent"                │
        │  • Custom folder name                   │
        │  • Skip Start Menu option               │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │         READY TO INSTALL                │
        │  • Review selections                    │
        │  • Final confirmation                   │
        └─────────────────────────────────────────┘
                              │
                              ▼
        ╔═════════════════════════════════════════╗
        ║      INSTALLATION EXECUTION             ║
        ╠═════════════════════════════════════════╣
        ║  1. Extract Core Components             ║
        ║     • serena.exe                        ║
        ║     • serena-mcp-server.exe             ║
        ║     • Python runtime                    ║
        ║     • Dependencies                      ║
        ║                                         ║
        ║  2. Install Language Servers            ║
        ║     Based on selected tier:             ║
        ║     Essential: py, ts, go, rust         ║
        ║     Complete: + java, c#, lua, bash     ║
        ║     Full: All 28+ servers               ║
        ║                                         ║
        ║  3. Initialize User Configuration       ║
        ║     • Create ~/.serena/                 ║
        ║     • Generate serena_config.yml        ║
        ║     • Create memories/ directory        ║
        ║     • Create projects/ directory        ║
        ║                                         ║
        ║  4. Create Shortcuts                    ║
        ║     • Start Menu folder                 ║
        ║     • Desktop shortcut                  ║
        ║     • Documentation links               ║
        ║                                         ║
        ║  5. System Integration                  ║
        ║     • Register file associations        ║
        ║     • Update PATH (if selected)         ║
        ║     • Windows Defender exclusions       ║
        ║                                         ║
        ║  6. Registry Configuration              ║
        ║     • Uninstall entry                   ║
        ║     • App path registration             ║
        ║     • Component tracking                ║
        ║                                         ║
        ║  7. Create Uninstaller                  ║
        ║     • Generate uninst.exe               ║
        ║     • Save install metadata             ║
        ╚═════════════════════════════════════════╝
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │         COMPLETION PAGE                 │
        │  • Installation summary                 │
        │  • Launch options:                      │
        │    [✓] Run version check                │
        │    [✓] Show README                      │
        │  • Quick start instructions             │
        │  • Documentation link                   │
        └─────────────────────────────────────────┘
                              │
                              ▼
                        INSTALLATION
                         COMPLETE
```

---

## Uninstallation Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                   UNINSTALLATION FLOW                           │
└─────────────────────────────────────────────────────────────────┘

                   START UNINSTALLER
                   (uninst.exe)
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │    Load Installation Metadata           │
        │  • Read from registry                   │
        │  • Installed components                 │
        │  • Installation path                    │
        │  • User config location                 │
        │  • Language server tier                 │
        └─────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │     Language Selection (if saved)       │
        │  Use saved language preference          │
        └─────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │      UNINSTALL CONFIRMATION             │
        │  "Are you sure you want to remove       │
        │   Serena Agent and all components?"     │
        │                                         │
        │  Installation Details:                  │
        │    • Version: 0.1.4                     │
        │    • Location: C:\Program Files\...     │
        │    • Size: 250 MB                       │
        │                                         │
        │         [ No ]      [ Yes ]             │
        └─────────────────────────────────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
               No                  Yes
                │                   │
                ▼                   ▼
        ┌───────────┐      ┌────────────────────┐
        │   ABORT   │      │  Continue Uninstall│
        └───────────┘      └────────────────────┘
                                    │
                                    ▼
        ┌─────────────────────────────────────────┐
        │   USER CONFIG PRESERVATION DIALOG       │
        │                                         │
        │  Your configuration directory:          │
        │  C:\Users\[User]\.serena\               │
        │                                         │
        │  Contains:                              │
        │    • Project configurations             │
        │    • Memory database                    │
        │    • Custom settings                    │
        │                                         │
        │  [ ] Also remove user configuration     │
        │                                         │
        │  Components to remove:                  │
        │    ✓ Core application                   │
        │    ✓ Language servers                   │
        │    ✓ Shortcuts                          │
        │    ✓ File associations                  │
        │    ✓ PATH entries                       │
        │    ✓ Registry entries                   │
        │                                         │
        │      [ Cancel ]  [ Uninstall ]          │
        └─────────────────────────────────────────┘
                          │
                          ▼
        ╔═════════════════════════════════════════╗
        ║      UNINSTALLATION EXECUTION           ║
        ╠═════════════════════════════════════════╣
        ║  1. Stop Running Processes              ║
        ║     • Check for serena.exe              ║
        ║     • Check for serena-mcp-server.exe   ║
        ║     • Prompt to close if running        ║
        ║                                         ║
        ║  2. Remove Shortcuts                    ║
        ║     • Start Menu folder                 ║
        ║     • Desktop shortcuts                 ║
        ║     • Quick launch items                ║
        ║                                         ║
        ║  3. Remove System Integration           ║
        ║     • PATH environment entries          ║
        ║     • File associations (.serena)       ║
        ║     • Windows Defender exclusions       ║
        ║     • Shell integration                 ║
        ║                                         ║
        ║  4. Remove Application Files            ║
        ║     • Core executables                  ║
        ║     • Language servers                  ║
        ║     • Runtime libraries                 ║
        ║     • Documentation                     ║
        ║     • Installation directory            ║
        ║                                         ║
        ║  5. Remove User Config (if selected)    ║
        ║     • ~/.serena/ directory              ║
        ║     • Project configurations            ║
        ║     • Memory database                   ║
        ║     • Custom settings                   ║
        ║                                         ║
        ║  6. Clean Registry                      ║
        ║     • Uninstall entry                   ║
        ║     • App path registration             ║
        ║     • File associations                 ║
        ║     • User preferences                  ║
        ║                                         ║
        ║  7. Refresh System                      ║
        ║     • Broadcast environment changes     ║
        ║     • Refresh shell associations        ║
        ║     • Update icon cache                 ║
        ╚═════════════════════════════════════════╝
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │      UNINSTALL COMPLETION               │
        │                                         │
        │  Serena Agent has been successfully     │
        │  removed from your computer.            │
        │                                         │
        │  Note: User configuration in            │
        │  ~/.serena/ was preserved (if kept)     │
        │                                         │
        │                [Finish]                 │
        └─────────────────────────────────────────┘
                          │
                          ▼
                  UNINSTALL COMPLETE
```

---

## Silent Installation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│               SILENT INSTALLATION FLOW                          │
└─────────────────────────────────────────────────────────────────┘

    Command: serena-installer.exe /S [/INI=config.ini] [/D=path]
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │    Parse Command-Line Arguments         │
        │  • /S = Silent mode                     │
        │  • /INI = Config file path              │
        │  • /D = Install directory               │
        │  • /TIER = Language server tier         │
        │  • /LOG = Log file path                 │
        └─────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │      Load Configuration (if INI)        │
        │  [General]                              │
        │  InstallDir=...                         │
        │  LanguageServerTier=essential           │
        │  [Components]                           │
        │  Core=1, LanguageServers=1, ...         │
        └─────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │    Silent Prerequisites Check           │
        │  • Windows version                      │
        │  • Disk space                           │
        │  • Privileges (admin or user)           │
        │  • No UI shown - log errors             │
        └─────────────────────────────────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
            SUCCESS              FAILURE
                │                   │
                │                   ▼
                │        ┌──────────────────┐
                │        │ Exit with error  │
                │        │ code (1)         │
                │        │ Write error log  │
                │        └──────────────────┘
                │
                ▼
        ┌─────────────────────────────────────────┐
        │    Execute Installation Silently        │
        │  • No user prompts                      │
        │  • No progress UI (optional log)        │
        │  • Use defaults/config values           │
        │  • Auto-accept license                  │
        │  • Install all selected components      │
        └─────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │      Write Installation Log             │
        │  • Timestamp each operation             │
        │  • Record errors/warnings               │
        │  • Component installation status        │
        │  • Registry writes                      │
        └─────────────────────────────────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
            SUCCESS              FAILURE
                │                   │
                ▼                   ▼
        ┌───────────┐      ┌────────────────┐
        │ Exit 0    │      │ Rollback &     │
        │ (Success) │      │ Exit 1 (Error) │
        └───────────┘      └────────────────┘
```

---

## Upgrade Installation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  UPGRADE INSTALLATION FLOW                      │
└─────────────────────────────────────────────────────────────────┘

                     START INSTALLER
                           │
                           ▼
        ┌─────────────────────────────────────────┐
        │   Detect Previous Installation          │
        │  Check registry:                        │
        │  HKLM\...\Uninstall\Serena Agent        │
        └─────────────────────────────────────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
          NOT FOUND                FOUND
                │                     │
                ▼                     ▼
        ┌───────────────┐   ┌─────────────────────┐
        │ Fresh Install │   │  Read Install Info  │
        │ (normal flow) │   │  • Version          │
        └───────────────┘   │  • Location         │
                            │  • Components       │
                            │  • User config path │
                            └─────────────────────┘
                                     │
                                     ▼
                      ┌──────────────────────────────┐
                      │    Version Comparison        │
                      │  Current: 0.1.3              │
                      │  New:     0.1.4              │
                      └──────────────────────────────┘
                                     │
                      ┌──────────────┴──────────────┐
                      │                             │
              Same/Newer Version          Older Version
                      │                             │
                      ▼                             ▼
        ┌──────────────────────┐      ┌──────────────────────┐
        │ Downgrade Warning    │      │  Upgrade Dialog      │
        │ "Already installed"  │      │  "Upgrade from X.X?" │
        │ [ Reinstall ] [Exit] │      │  • Preserve settings │
        └──────────────────────┘      │  • Migrate config    │
                      │               │  [ Yes ] [ No ]      │
                      │               └──────────────────────┘
                      │                             │
                      └─────────────┬───────────────┘
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                    Accepted              Declined
                         │                     │
                         │                     ▼
                         │            ┌────────────────┐
                         │            │  Fresh Install │
                         │            │  New Location  │
                         │            └────────────────┘
                         ▼
        ┌─────────────────────────────────────────┐
        │      Backup User Configuration          │
        │  • Copy ~/.serena/ to backup            │
        │  • Save component list                  │
        │  • Preserve custom settings             │
        └─────────────────────────────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────────────┐
        │    Uninstall Previous Version           │
        │  • Remove old binaries                  │
        │  • Keep user config                     │
        │  • Preserve registry settings           │
        │  • Clean old language servers           │
        └─────────────────────────────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────────────┐
        │     Install New Version                 │
        │  • Use same install location            │
        │  • Install selected components          │
        │  • Restore user config                  │
        │  • Migrate settings if needed           │
        └─────────────────────────────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────────────┐
        │      Configuration Migration            │
        │  • Update config file version           │
        │  • Add new default settings             │
        │  • Preserve custom values               │
        │  • Update registry entries              │
        └─────────────────────────────────────────┘
                         │
                         ▼
                 UPGRADE COMPLETE
```

---

## Error Handling Flow

```
        ┌─────────────────────────────────────────┐
        │      INSTALLATION ERROR DETECTED        │
        └─────────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
    Recoverable                   Unrecoverable
        │                                 │
        ▼                                 ▼
┌──────────────────┐          ┌─────────────────────┐
│ Show Error UI    │          │  Critical Failure   │
│ • Retry option   │          │  • Show error       │
│ • Skip option    │          │  • Write log        │
│ • Cancel         │          │  • Rollback install │
└──────────────────┘          │  • Exit with code   │
        │                     └─────────────────────┘
        │
┌───────┴────────┐
│                │
Retry        Skip/Cancel
│                │
▼                ▼
Resume      Rollback &
Install     Exit
```

---

## Component Dependencies

```
Core Components (REQUIRED)
    │
    ├──> Language Servers (OPTIONAL)
    │    ├──> Essential Tier
    │    ├──> Complete Tier
    │    └──> Full Tier
    │
    ├──> User Configuration (RECOMMENDED)
    │    └──> Creates ~/.serena/
    │
    ├──> Shortcuts (RECOMMENDED)
    │    └──> Requires: Core Components
    │
    ├──> PATH Integration (OPTIONAL)
    │    └──> Requires: Core Components
    │
    ├──> File Associations (OPTIONAL)
    │    └──> Requires: Core Components
    │
    └──> Windows Defender (OPTIONAL)
         └──> Requires: Admin privileges
```

---

This comprehensive flow documentation ensures clear understanding of the installation process for both users and developers.
