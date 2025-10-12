;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Serena Agent - Enhanced NSIS Installer Script
; Professional Windows Installer with Portable Distribution Integration
;
; Author: Oraios AI
; License: MIT License
; Version: 0.1.4
;
; ENHANCEMENTS:
; - Integrates with portable distribution ZIP/folder structure
; - Tier-based language server selection (Minimal, Essential, Complete, Full)
; - Improved component selection with size estimates
; - User config directory initialization (~/.serena/)
; - Enhanced upgrade detection and migration
; - Better silent installation support
; - Comprehensive registry integration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Include Modern UI 2
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "WinVer.nsh"
!include "x64.nsh"
!include "Sections.nsh"
!include "StrFunc.nsh"
!include "FileAssociation.nsh"

; String functions
${StrRep}
${StrLoc}

; Installer properties
!define PRODUCT_NAME "Serena Agent"
!define PRODUCT_VERSION "0.1.4"
!define PRODUCT_PUBLISHER "Oraios AI"
!define PRODUCT_WEB_SITE "https://github.com/oraios/serena"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\serena.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
!define PRODUCT_STARTMENU_REGVAL "NSIS:StartMenuDir"

; Minimum Windows version (Windows 10)
!define MIN_WIN_VER "10.0"

; Installation types
!define INSTALL_TYPE_FULL "Full Installation"
!define INSTALL_TYPE_ESSENTIAL "Essential Installation"
!define INSTALL_TYPE_MINIMAL "Minimal Installation"
!define INSTALL_TYPE_CUSTOM "Custom Installation"

; Language Server Tiers
!define TIER_MINIMAL "minimal"
!define TIER_ESSENTIAL "essential"
!define TIER_COMPLETE "complete"
!define TIER_FULL "full"

; Component IDs
!define COMP_CORE 1
!define COMP_LS_ESSENTIAL 2
!define COMP_LS_COMPLETE 3
!define COMP_LS_FULL 4
!define COMP_SHORTCUTS 5
!define COMP_PATH 6
!define COMP_FILE_ASSOC 7
!define COMP_DEFENDER 8
!define COMP_USER_CONFIG 9

; General settings
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "serena-installer-${PRODUCT_VERSION}.exe"
InstallDir "$PROGRAMFILES64\${PRODUCT_NAME}"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show
BrandingText "${PRODUCT_PUBLISHER}"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

; Version info
VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "LegalCopyright" "© 2025 ${PRODUCT_PUBLISHER}. All rights reserved."
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} Installer"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}.0"

; Multi-language support
!define MUI_LANGDLL_ALLLANGUAGES
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"

; Modern UI configuration
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis3-grey.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis3-grey.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\nsis3-grey.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\nsis3-grey.bmp"

; Start Menu configuration
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "${PRODUCT_NAME}"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKLM"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "${PRODUCT_STARTMENU_REGVAL}"

; Finish page configuration
!define MUI_FINISHPAGE_RUN "$INSTDIR\serena.exe"
!define MUI_FINISHPAGE_RUN_PARAMETERS "--version"
!define MUI_FINISHPAGE_RUN_TEXT "Run Serena version check"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.txt"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Show README"
!define MUI_FINISHPAGE_LINK "Visit ${PRODUCT_WEB_SITE}"
!define MUI_FINISHPAGE_LINK_LOCATION "${PRODUCT_WEB_SITE}"

; Variables
Var StartMenuFolder
Var InstallationType
Var LanguageServerTier
Var PreviousVersion
Var PreviousInstallDir
Var UserInstall
Var UserConfigDir
Var PortableSource

; Custom pages
Page custom TierSelectionPage TierSelectionPageLeave

; Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Languages
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "German"
!insertmacro MUI_LANGUAGE "Spanish"

; Language strings
LangString DESC_SecCore ${LANG_ENGLISH} "Core Serena Agent files (required) - 150MB"
LangString DESC_SecLSEssential ${LANG_ENGLISH} "Essential language servers (Python, TypeScript, Go, Rust) - 100MB"
LangString DESC_SecLSComplete ${LANG_ENGLISH} "Complete language servers (adds Java, C#, Lua, Bash) - 250MB"
LangString DESC_SecLSFull ${LANG_ENGLISH} "Full language server suite (all 28+ supported languages) - 500MB"
LangString DESC_SecShortcuts ${LANG_ENGLISH} "Start Menu and Desktop shortcuts"
LangString DESC_SecPath ${LANG_ENGLISH} "Add Serena to system PATH environment variable"
LangString DESC_SecFileAssoc ${LANG_ENGLISH} "Associate .serena project files with Serena Agent"
LangString DESC_SecDefender ${LANG_ENGLISH} "Add Windows Defender exclusions for better performance"
LangString DESC_SecUserConfig ${LANG_ENGLISH} "Initialize user configuration directory (~/.serena/)"

LangString TEXT_TierSelection ${LANG_ENGLISH} "Select Language Server Tier"
LangString TEXT_TierDesc ${LANG_ENGLISH} "Choose which language servers to install based on your development needs:"
LangString TEXT_TierMinimal ${LANG_ENGLISH} "Minimal - No language servers (smallest)"
LangString TEXT_TierEssential ${LANG_ENGLISH} "Essential - Python, TypeScript, Go, Rust (~100MB)"
LangString TEXT_TierComplete ${LANG_ENGLISH} "Complete - Essential + Java, C#, Lua, Bash (~250MB)"
LangString TEXT_TierFull ${LANG_ENGLISH} "Full - All 28+ supported languages (~500MB)"

; German translations
LangString DESC_SecCore ${LANG_GERMAN} "Kern Serena Agent Dateien (erforderlich) - 150MB"
LangString DESC_SecLSEssential ${LANG_GERMAN} "Wesentliche Sprachserver (Python, TypeScript, Go, Rust) - 100MB"
LangString DESC_SecLSComplete ${LANG_GERMAN} "Vollständige Sprachserver (+ Java, C#, Lua, Bash) - 250MB"
LangString DESC_SecLSFull ${LANG_GERMAN} "Vollständige Sprachserver-Suite (alle 28+ unterstützte Sprachen) - 500MB"

; Installation types
InstType "$(INSTALL_TYPE_FULL)"
InstType "$(INSTALL_TYPE_ESSENTIAL)"
InstType "$(INSTALL_TYPE_MINIMAL)"
InstType "$(INSTALL_TYPE_CUSTOM)"

; Functions
Function .onInit
    ; Language selection
    !insertmacro MUI_LANGDLL_DISPLAY

    ; Check Windows version
    ${IfNot} ${AtLeastWin10}
        MessageBox MB_OK|MB_ICONSTOP "This software requires Windows 10 or later."
        Abort
    ${EndIf}

    ; Check for 64-bit system
    ${IfNot} ${RunningX64}
        MessageBox MB_OK|MB_ICONSTOP "This software requires a 64-bit Windows system."
        Abort
    ${EndIf}

    ; Initialize user config directory
    StrCpy $UserConfigDir "$PROFILE\.serena"

    ; Check for existing installation
    Call CheckPreviousInstallation

    ; Check if user has admin rights
    UserInfo::GetAccountType
    Pop $0
    ${If} $0 != "Admin"
        ; Offer user-level installation
        MessageBox MB_YESNO|MB_ICONQUESTION \
            "Administrator privileges are required for system-wide installation.$\n$\n\
            Would you like to install for current user only?$\n$\n\
            User installation will install to: $LOCALAPPDATA\${PRODUCT_NAME}" \
            IDYES UserInstallation IDNO RequireAdmin

        UserInstallation:
            StrCpy $UserInstall "1"
            StrCpy $INSTDIR "$LOCALAPPDATA\${PRODUCT_NAME}"
            SetShellVarContext current
            Goto InitDone

        RequireAdmin:
            MessageBox MB_OK|MB_ICONSTOP "Administrator privileges are required for installation."
            Abort
    ${EndIf}

    InitDone:
        ; Initialize installation type and tier
        StrCpy $InstallationType "${INSTALL_TYPE_FULL}"
        StrCpy $LanguageServerTier "${TIER_ESSENTIAL}"

        ; Detect portable source if building from portable distribution
        Call DetectPortableSource
FunctionEnd

Function DetectPortableSource
    ; Check if we're building from a portable distribution
    ; This function looks for portable bundle structure
    StrCpy $PortableSource ""

    ; Check common portable locations
    IfFileExists "$EXEDIR\dist\serena-mcp-server.exe" 0 +3
        StrCpy $PortableSource "$EXEDIR\dist"
        Return

    IfFileExists "$EXEDIR\..\dist\serena-mcp-server.exe" 0 +3
        StrCpy $PortableSource "$EXEDIR\..\dist"
        Return

    IfFileExists "$EXEDIR\portable\serena-mcp-server.exe" 0 +3
        StrCpy $PortableSource "$EXEDIR\portable"
        Return
FunctionEnd

Function CheckPreviousInstallation
    ; Check for previous installation
    ReadRegStr $PreviousInstallDir HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation"
    ${If} $PreviousInstallDir != ""
        ReadRegStr $PreviousVersion HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion"
        MessageBox MB_YESNO|MB_ICONQUESTION \
            "A previous version ($PreviousVersion) of ${PRODUCT_NAME} is installed at:$\n\
            $PreviousInstallDir$\n$\n\
            Do you want to upgrade the existing installation?$\n$\n\
            Note: Your user configuration in ~/.serena/ will be preserved." \
            IDYES UpgradeInstall IDNO FreshInstall

        UpgradeInstall:
            StrCpy $INSTDIR $PreviousInstallDir
            ; Migrate settings if needed
            Call MigrateUserSettings
            Goto CheckDone

        FreshInstall:
            ; Continue with new installation
    ${EndIf}

    CheckDone:
FunctionEnd

Function MigrateUserSettings
    ; Migrate user settings from previous version
    DetailPrint "Checking for user configuration migration..."

    IfFileExists "$UserConfigDir\serena_config.yml" 0 +2
        DetailPrint "Existing user configuration found - will be preserved"

    ; Future: Add version-specific migration logic here
FunctionEnd

Function TierSelectionPage
    nsDialogs::Create 1018
    Pop $0

    ${NSD_CreateLabel} 0 0 100% 20u "$(TEXT_TierSelection)"
    Pop $0

    ${NSD_CreateLabel} 0 25u 100% 20u "$(TEXT_TierDesc)"
    Pop $0

    ${NSD_CreateRadioButton} 10u 50u 100% 12u "$(TEXT_TierMinimal)"
    Pop $1
    ${NSD_CreateRadioButton} 10u 65u 100% 12u "$(TEXT_TierEssential)"
    Pop $2
    ${NSD_CreateRadioButton} 10u 80u 100% 12u "$(TEXT_TierComplete)"
    Pop $3
    ${NSD_CreateRadioButton} 10u 95u 100% 12u "$(TEXT_TierFull)"
    Pop $4

    ; Default to Essential
    ${NSD_Check} $2

    nsDialogs::Show
FunctionEnd

Function TierSelectionPageLeave
    ; Save selected tier
    ${NSD_GetState} $1 $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $LanguageServerTier "${TIER_MINIMAL}"
    ${EndIf}

    ${NSD_GetState} $2 $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $LanguageServerTier "${TIER_ESSENTIAL}"
    ${EndIf}

    ${NSD_GetState} $3 $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $LanguageServerTier "${TIER_COMPLETE}"
    ${EndIf}

    ${NSD_GetState} $4 $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $LanguageServerTier "${TIER_FULL}"
    ${EndIf}

    DetailPrint "Selected language server tier: $LanguageServerTier"
FunctionEnd

Function ComponentsPageLeave
    ; Validate component selection
    SectionGetFlags ${SecCore} $0
    IntOp $0 $0 & ${SF_SELECTED}
    ${If} $0 == 0
        MessageBox MB_OK|MB_ICONSTOP "Core components must be selected."
        Abort
    ${EndIf}
FunctionEnd

; Sections
Section "!Core Components" SecCore
    SectionIn RO 1 2 3 4  ; Required, in all installation types

    SetOutPath "$INSTDIR"
    SetOverwrite on

    DetailPrint "Installing core components from portable distribution..."

    ; Core executables and libraries
    ; If portable source is available, copy from there
    ${If} $PortableSource != ""
        DetailPrint "Copying from portable bundle: $PortableSource"
        File /r "$PortableSource\*.*"
    ${Else}
        ; Otherwise use bundled files
        File /r "dist\*.*"
    ${EndIf}

    ; Configuration files
    File "..\..\LICENSE"

    ; Create README.txt for Windows
    FileOpen $0 "$INSTDIR\README.txt" w
    FileWrite $0 "Serena Agent v${PRODUCT_VERSION}$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "Installation Directory: $INSTDIR$\r$\n"
    FileWrite $0 "User Config Directory: $UserConfigDir$\r$\n"
    FileWrite $0 "Language Server Tier: $LanguageServerTier$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "Quick Start:$\r$\n"
    FileWrite $0 "  1. Open Command Prompt or PowerShell$\r$\n"
    FileWrite $0 "  2. Run: serena --help$\r$\n"
    FileWrite $0 "  3. Start MCP server: serena-mcp-server$\r$\n"
    FileWrite $0 "$\r$\n"
    FileWrite $0 "Documentation: https://github.com/oraios/serena$\r$\n"
    FileClose $0

    ; Create directories
    CreateDirectory "$INSTDIR\logs"
    CreateDirectory "$INSTDIR\temp"

    ; Registry entries
    ${If} $UserInstall != "1"
        WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\serena.exe"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "LanguageServerTier" "$LanguageServerTier"
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1

        ; Calculate installed size
        ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "InstallPath" "$INSTDIR"
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "Version" "${PRODUCT_VERSION}"
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "LanguageServerTier" "$LanguageServerTier"
    ${EndIf}

    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninst.exe"
SectionEnd

Section "Essential Language Servers" SecLSEssential
    SectionIn 1 2 4  ; Full, Essential, and Custom installations

    ${If} $LanguageServerTier == "${TIER_MINIMAL}"
        DetailPrint "Skipping language servers (minimal tier selected)"
        Return
    ${EndIf}

    SetOutPath "$INSTDIR\language-servers"

    DetailPrint "Installing essential language servers (Python, TypeScript, Go, Rust)..."

    ; Copy essential language servers if available
    ${If} $PortableSource != ""
        IfFileExists "$PortableSource\language-servers\pyright\*.*" 0 +2
            File /r "$PortableSource\language-servers\pyright"

        IfFileExists "$PortableSource\language-servers\typescript-language-server\*.*" 0 +2
            File /r "$PortableSource\language-servers\typescript-language-server"

        IfFileExists "$PortableSource\language-servers\gopls\*.*" 0 +2
            File /r "$PortableSource\language-servers\gopls"

        IfFileExists "$PortableSource\language-servers\rust-analyzer\*.*" 0 +2
            File /r "$PortableSource\language-servers\rust-analyzer"
    ${Else}
        IfFileExists "language-servers\essential\*.*" 0 +2
            File /r "language-servers\essential\*.*"
    ${EndIf}

    ; Update registry
    ${If} $UserInstall != "1"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "LanguageServersEssential" "Installed"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "LanguageServersEssential" "Installed"
    ${EndIf}
SectionEnd

Section "Complete Language Servers" SecLSComplete
    SectionIn 1 4  ; Full and Custom installations only

    ${If} $LanguageServerTier == "${TIER_MINIMAL}"
    ${OrIf} $LanguageServerTier == "${TIER_ESSENTIAL}"
        DetailPrint "Skipping complete language servers (tier: $LanguageServerTier)"
        Return
    ${EndIf}

    SetOutPath "$INSTDIR\language-servers"

    DetailPrint "Installing complete language servers (Java, C#, Lua, Bash)..."

    ; Copy complete tier language servers
    ${If} $PortableSource != ""
        IfFileExists "$PortableSource\language-servers\eclipse-jdtls\*.*" 0 +2
            File /r "$PortableSource\language-servers\eclipse-jdtls"

        IfFileExists "$PortableSource\language-servers\csharp-language-server\*.*" 0 +2
            File /r "$PortableSource\language-servers\csharp-language-server"

        IfFileExists "$PortableSource\language-servers\lua-language-server\*.*" 0 +2
            File /r "$PortableSource\language-servers\lua-language-server"

        IfFileExists "$PortableSource\language-servers\bash-language-server\*.*" 0 +2
            File /r "$PortableSource\language-servers\bash-language-server"
    ${Else}
        IfFileExists "language-servers\complete\*.*" 0 +2
            File /r "language-servers\complete\*.*"
    ${EndIf}

    ${If} $UserInstall != "1"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "LanguageServersComplete" "Installed"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "LanguageServersComplete" "Installed"
    ${EndIf}
SectionEnd

Section "Full Language Server Suite" SecLSFull
    SectionIn 1 4  ; Full and Custom installations only

    ${If} $LanguageServerTier != "${TIER_FULL}"
        DetailPrint "Skipping full language server suite (tier: $LanguageServerTier)"
        Return
    ${EndIf}

    SetOutPath "$INSTDIR\language-servers"

    DetailPrint "Installing full language server suite (all 28+ languages)..."

    ; Copy all language servers
    ${If} $PortableSource != ""
        IfFileExists "$PortableSource\language-servers\*.*" 0 +2
            File /r "$PortableSource\language-servers\*.*"
    ${Else}
        IfFileExists "language-servers\full\*.*" 0 +2
            File /r "language-servers\full\*.*"
    ${EndIf}

    ${If} $UserInstall != "1"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "LanguageServersFull" "Installed"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "LanguageServersFull" "Installed"
    ${EndIf}
SectionEnd

Section "User Configuration Directory" SecUserConfig
    SectionIn 1 2 3 4  ; All installation types

    DetailPrint "Initializing user configuration directory: $UserConfigDir"

    ; Create .serena directory in user profile
    CreateDirectory "$UserConfigDir"
    CreateDirectory "$UserConfigDir\memories"
    CreateDirectory "$UserConfigDir\projects"

    ; Create default configuration file if it doesn't exist
    IfFileExists "$UserConfigDir\serena_config.yml" ConfigExists 0
        DetailPrint "Creating default configuration file..."
        FileOpen $0 "$UserConfigDir\serena_config.yml" w
        FileWrite $0 "# Serena Agent Configuration$\r$\n"
        FileWrite $0 "# Version: ${PRODUCT_VERSION}$\r$\n"
        FileWrite $0 "$\r$\n"
        FileWrite $0 "installation:$\r$\n"
        FileWrite $0 "  path: $INSTDIR$\r$\n"
        FileWrite $0 "  version: ${PRODUCT_VERSION}$\r$\n"
        FileWrite $0 "  language_server_tier: $LanguageServerTier$\r$\n"
        FileWrite $0 "$\r$\n"
        FileWrite $0 "# Add your custom configuration below$\r$\n"
        FileClose $0
        Goto ConfigDone

    ConfigExists:
        DetailPrint "Configuration file already exists - preserving existing settings"

    ConfigDone:

    ; Update registry with config directory location
    ${If} $UserInstall != "1"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UserConfigDirectory" "$UserConfigDir"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "UserConfigDirectory" "$UserConfigDir"
    ${EndIf}
SectionEnd

Section "Start Menu Shortcuts" SecShortcuts
    SectionIn 1 2 4  ; Full, Essential, and Custom installations

    !insertmacro MUI_STARTMENU_WRITE_BEGIN Application

    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"

    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk" \
        "$INSTDIR\serena.exe" "--help" "$INSTDIR\serena.exe" 0

    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} MCP Server.lnk" \
        "$INSTDIR\serena-mcp-server.exe" "" "$INSTDIR\serena-mcp-server.exe" 0

    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Serena Configuration.lnk" \
        "notepad.exe" "$UserConfigDir\serena_config.yml" "notepad.exe" 0

    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Uninstall ${PRODUCT_NAME}.lnk" \
        "$INSTDIR\uninst.exe" "" "$INSTDIR\uninst.exe" 0

    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} Documentation.lnk" \
        "$INSTDIR\README.txt" "" "$INSTDIR\README.txt" 0

    ; Desktop shortcut
    CreateShortcut "$DESKTOP\${PRODUCT_NAME}.lnk" \
        "$INSTDIR\serena.exe" "--help" "$INSTDIR\serena.exe" 0

    !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

Section "Add to PATH" SecPath
    SectionIn 4  ; Custom installation only

    ; Add to system PATH
    ${If} $UserInstall != "1"
        DetailPrint "Adding to system PATH..."
        EnVar::SetHKLM
        EnVar::AddValue "PATH" "$INSTDIR"
        Pop $0
        DetailPrint "Added to system PATH: $0"
    ${Else}
        DetailPrint "Adding to user PATH..."
        EnVar::SetHKCU
        EnVar::AddValue "PATH" "$INSTDIR"
        Pop $0
        DetailPrint "Added to user PATH: $0"
    ${EndIf}

    ; Broadcast environment change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
SectionEnd

Section "File Associations" SecFileAssoc
    SectionIn 1 2 4  ; Full, Essential, and Custom installations

    DetailPrint "Registering .serena file association..."

    ; Register .serena file association
    ${If} $UserInstall != "1"
        ${registerExtension} "$INSTDIR\serena.exe" ".serena" "Serena Project File"
        WriteRegStr HKLM "Software\Classes\.serena" "" "SerenaProject"
        WriteRegStr HKLM "Software\Classes\SerenaProject" "" "Serena Project File"
        WriteRegStr HKLM "Software\Classes\SerenaProject\DefaultIcon" "" "$INSTDIR\serena.exe,0"
        WriteRegStr HKLM "Software\Classes\SerenaProject\shell\open\command" "" '"$INSTDIR\serena.exe" "%1"'
    ${Else}
        WriteRegStr HKCU "Software\Classes\.serena" "" "SerenaProject"
        WriteRegStr HKCU "Software\Classes\SerenaProject" "" "Serena Project File"
        WriteRegStr HKCU "Software\Classes\SerenaProject\DefaultIcon" "" "$INSTDIR\serena.exe,0"
        WriteRegStr HKCU "Software\Classes\SerenaProject\shell\open\command" "" '"$INSTDIR\serena.exe" "%1"'
    ${EndIf}

    ; Refresh shell
    System::Call 'shell32.dll::SHChangeNotify(l, l, i, i) v (0x08000000, 0, 0, 0)'
SectionEnd

Section "Windows Defender Exclusions" SecDefender
    SectionIn 4  ; Custom installation only

    DetailPrint "Configuring Windows Defender exclusions..."

    ; Add path exclusion
    nsExec::ExecToStack 'powershell.exe -Command "Add-MpPreference -ExclusionPath \"$INSTDIR\" -Force"'
    Pop $0
    ${If} $0 == 0
        DetailPrint "Added path exclusion for Windows Defender"
    ${Else}
        DetailPrint "Warning: Could not add Windows Defender exclusion (requires admin rights)"
    ${EndIf}

    ; Add process exclusions
    nsExec::ExecToStack 'powershell.exe -Command "Add-MpPreference -ExclusionProcess \"serena.exe\" -Force"'
    Pop $0
    nsExec::ExecToStack 'powershell.exe -Command "Add-MpPreference -ExclusionProcess \"serena-mcp-server.exe\" -Force"'
    Pop $0
    ${If} $0 == 0
        DetailPrint "Added process exclusions for Windows Defender"
    ${EndIf}
SectionEnd

; Component descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCore} $(DESC_SecCore)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecLSEssential} $(DESC_SecLSEssential)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecLSComplete} $(DESC_SecLSComplete)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecLSFull} $(DESC_SecLSFull)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecUserConfig} $(DESC_SecUserConfig)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecShortcuts} $(DESC_SecShortcuts)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecPath} $(DESC_SecPath)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecFileAssoc} $(DESC_SecFileAssoc)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDefender} $(DESC_SecDefender)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; Uninstaller sections
Section "Uninstall"
    ; Remove files
    Delete "$INSTDIR\serena.exe"
    Delete "$INSTDIR\serena-mcp-server.exe"
    Delete "$INSTDIR\index-project.exe"
    Delete "$INSTDIR\LICENSE"
    Delete "$INSTDIR\README.txt"
    Delete "$INSTDIR\uninst.exe"

    ; Remove directories
    RMDir /r "$INSTDIR\language-servers"
    RMDir /r "$INSTDIR\logs"
    RMDir /r "$INSTDIR\temp"
    RMDir /r "$INSTDIR\_internal"
    RMDir "$INSTDIR"

    ; Ask about user configuration
    MessageBox MB_YESNO|MB_ICONQUESTION \
        "Do you want to remove your user configuration directory?$\n$\n\
        $UserConfigDir$\n$\n\
        This will delete all your project configurations and memories." \
        IDYES RemoveUserConfig IDNO KeepUserConfig

    RemoveUserConfig:
        RMDir /r "$UserConfigDir"
        DetailPrint "Removed user configuration directory"
        Goto ConfigDone

    KeepUserConfig:
        DetailPrint "User configuration directory preserved"

    ConfigDone:

    ; Remove shortcuts
    !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
    Delete "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} MCP Server.lnk"
    Delete "$SMPROGRAMS\$StartMenuFolder\Serena Configuration.lnk"
    Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall ${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} Documentation.lnk"
    RMDir "$SMPROGRAMS\$StartMenuFolder"
    Delete "$DESKTOP\${PRODUCT_NAME}.lnk"

    ; Remove from PATH
    EnVar::SetHKLM
    EnVar::DeleteValue "PATH" "$INSTDIR"
    Pop $0
    EnVar::SetHKCU
    EnVar::DeleteValue "PATH" "$INSTDIR"
    Pop $0

    ; Remove file associations
    ${unregisterExtension} ".serena" "Serena Project File"
    DeleteRegKey HKLM "Software\Classes\.serena"
    DeleteRegKey HKLM "Software\Classes\SerenaProject"
    DeleteRegKey HKCU "Software\Classes\.serena"
    DeleteRegKey HKCU "Software\Classes\SerenaProject"

    ; Remove Windows Defender exclusions
    nsExec::ExecToStack 'powershell.exe -Command "Remove-MpPreference -ExclusionPath \"$INSTDIR\" -Force"'
    nsExec::ExecToStack 'powershell.exe -Command "Remove-MpPreference -ExclusionProcess \"serena.exe\" -Force"'
    nsExec::ExecToStack 'powershell.exe -Command "Remove-MpPreference -ExclusionProcess \"serena-mcp-server.exe\" -Force"'

    ; Remove registry entries
    DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
    DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
    DeleteRegKey HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}"

    ; Refresh shell
    System::Call 'shell32.dll::SHChangeNotify(l, l, i, i) v (0x08000000, 0, 0, 0)'
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000

    SetAutoClose true
SectionEnd

Function un.onInit
    !insertmacro MUI_UNGETLANGUAGE

    ; Read user config directory from registry
    ReadRegStr $UserConfigDir HKLM "${PRODUCT_UNINST_KEY}" "UserConfigDirectory"
    ${If} $UserConfigDir == ""
        StrCpy $UserConfigDir "$PROFILE\.serena"
    ${EndIf}

    MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 \
        "Are you sure you want to completely remove $(^Name) and all of its components?" \
        IDYES +2
    Abort
FunctionEnd

Function un.onUninstSuccess
    HideWindow
    MessageBox MB_ICONINFORMATION|MB_OK \
        "$(^Name) was successfully removed from your computer.$\n$\n\
        Note: User configuration in $UserConfigDir was preserved if you chose to keep it."
FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Code signing placeholders
; Uncomment and configure these when code signing certificate is available
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; !finalize 'signtool.exe sign /f "certificate.p12" /p "password" /t http://timestamp.verisign.com/scripts/timstamp.dll "%1"'
; !uninstfinalize 'signtool.exe sign /f "certificate.p12" /p "password" /t http://timestamp.verisign.com/scripts/timstamp.dll "%1"'

; End of installer script
