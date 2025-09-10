;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Serena Agent - NSIS Installer Script
; Professional Windows Installer for Serena Portable Distribution
; 
; Author: Oraios AI
; License: MIT License
; Version: 0.1.4
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
!define INSTALL_TYPE_FULL "Full"
!define INSTALL_TYPE_CORE "Core"
!define INSTALL_TYPE_CUSTOM "Custom"

; Component IDs
!define COMP_CORE 1
!define COMP_LANGUAGE_SERVERS 2
!define COMP_SHORTCUTS 3
!define COMP_PATH 4
!define COMP_FILE_ASSOC 5
!define COMP_DEFENDER 6

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
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\README.md"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Show README"
!define MUI_FINISHPAGE_LINK "Visit ${PRODUCT_WEB_SITE}"
!define MUI_FINISHPAGE_LINK_LOCATION "${PRODUCT_WEB_SITE}"

; Variables
Var StartMenuFolder
Var InstallationType
Var PreviousVersion
Var PreviousInstallDir
Var UserInstall

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
LangString DESC_SecCore ${LANG_ENGLISH} "Core Serena Agent files (required)"
LangString DESC_SecLanguageServers ${LANG_ENGLISH} "Language server binaries for multi-language support"
LangString DESC_SecShortcuts ${LANG_ENGLISH} "Start Menu and Desktop shortcuts"
LangString DESC_SecPath ${LANG_ENGLISH} "Add Serena to system PATH environment variable"
LangString DESC_SecFileAssoc ${LANG_ENGLISH} "Associate .serena project files with Serena Agent"
LangString DESC_SecDefender ${LANG_ENGLISH} "Add Windows Defender exclusions for better performance"

LangString DESC_SecCore ${LANG_GERMAN} "Kern Serena Agent Dateien (erforderlich)"
LangString DESC_SecLanguageServers ${LANG_GERMAN} "Language-Server-Binärdateien für Multi-Sprach-Unterstützung"
LangString DESC_SecShortcuts ${LANG_GERMAN} "Startmenü und Desktop-Verknüpfungen"
LangString DESC_SecPath ${LANG_GERMAN} "Serena zur System-PATH-Umgebungsvariable hinzufügen"
LangString DESC_SecFileAssoc ${LANG_GERMAN} ".serena-Projektdateien mit Serena Agent verknüpfen"
LangString DESC_SecDefender ${LANG_GERMAN} "Windows Defender-Ausschlüsse für bessere Leistung hinzufügen"

; Installation types
InstType "$(INSTALL_TYPE_FULL)"
InstType "$(INSTALL_TYPE_CORE)"
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
    
    ; Check for existing installation
    Call CheckPreviousInstallation
    
    ; Check if user has admin rights
    UserInfo::GetAccountType
    Pop $0
    ${If} $0 != "Admin"
        ; Offer user-level installation
        MessageBox MB_YESNO|MB_ICONQUESTION \
            "Administrator privileges are required for system-wide installation.$\n$\n\
            Would you like to install for current user only?" \
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
        ; Initialize installation type
        StrCpy $InstallationType "${INSTALL_TYPE_FULL}"
FunctionEnd

Function CheckPreviousInstallation
    ; Check for previous installation
    ReadRegStr $PreviousInstallDir HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation"
    ${If} $PreviousInstallDir != ""
        ReadRegStr $PreviousVersion HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion"
        MessageBox MB_YESNO|MB_ICONQUESTION \
            "A previous version ($PreviousVersion) of ${PRODUCT_NAME} is installed.$\n\
            Do you want to upgrade the existing installation?" \
            IDYES UpgradeInstall IDNO FreshInstall
        
        UpgradeInstall:
            StrCpy $INSTDIR $PreviousInstallDir
            Goto CheckDone
        
        FreshInstall:
            ; Continue with new installation
    ${EndIf}
    
    CheckDone:
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
    SectionIn RO 1 2 3  ; Required, in all installation types
    
    SetOutPath "$INSTDIR"
    SetOverwrite on
    
    ; Core executable and libraries
    File /r "dist\*.*"
    
    ; Configuration files
    File "..\..\LICENSE"
    File "..\..\README.md"
    
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
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1
        
        ; Calculate installed size
        ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "EstimatedSize" "$0"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "InstallPath" "$INSTDIR"
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "Version" "${PRODUCT_VERSION}"
    ${EndIf}
    
    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninst.exe"
SectionEnd

Section "Language Servers" SecLanguageServers
    SectionIn 1 3  ; Full and Custom installations
    
    SetOutPath "$INSTDIR\language-servers"
    
    ; Language server binaries (placeholder - actual files would be included)
    File /r "language-servers\*.*"
    
    ; Update registry to indicate language servers are installed
    ${If} $UserInstall != "1"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "LanguageServers" "Installed"
    ${Else}
        WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "LanguageServers" "Installed"
    ${EndIf}
SectionEnd

Section "Start Menu Shortcuts" SecShortcuts
    SectionIn 1 3  ; Full and Custom installations
    
    !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk" \
        "$INSTDIR\serena.exe" "" "$INSTDIR\serena.exe" 0
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} MCP Server.lnk" \
        "$INSTDIR\serena-mcp-server.exe" "" "$INSTDIR\serena-mcp-server.exe" 0
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\Uninstall ${PRODUCT_NAME}.lnk" \
        "$INSTDIR\uninst.exe" "" "$INSTDIR\uninst.exe" 0
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} Documentation.lnk" \
        "$INSTDIR\README.md" "" "$INSTDIR\README.md" 0
    
    ; Desktop shortcut
    CreateShortcut "$DESKTOP\${PRODUCT_NAME}.lnk" \
        "$INSTDIR\serena.exe" "" "$INSTDIR\serena.exe" 0
    
    !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

Section "Add to PATH" SecPath
    SectionIn 3  ; Custom installation only
    
    ; Add to system PATH
    ${If} $UserInstall != "1"
        EnVar::SetHKLM
        EnVar::AddValue "PATH" "$INSTDIR"
        Pop $0
        DetailPrint "Added to system PATH: $0"
    ${Else}
        EnVar::SetHKCU
        EnVar::AddValue "PATH" "$INSTDIR"
        Pop $0
        DetailPrint "Added to user PATH: $0"
    ${EndIf}
    
    ; Broadcast environment change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
SectionEnd

Section "File Associations" SecFileAssoc
    SectionIn 1 3  ; Full and Custom installations
    
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
    SectionIn 3  ; Custom installation only
    
    DetailPrint "Configuring Windows Defender exclusions..."
    
    ; Add path exclusion
    nsExec::ExecToStack 'powershell.exe -Command "Add-MpPreference -ExclusionPath \"$INSTDIR\" -Force"'
    Pop $0
    ${If} $0 == 0
        DetailPrint "Added path exclusion for Windows Defender"
    ${Else}
        DetailPrint "Warning: Could not add Windows Defender exclusion (requires admin rights)"
    ${EndIf}
    
    ; Add process exclusion
    nsExec::ExecToStack 'powershell.exe -Command "Add-MpPreference -ExclusionProcess \"serena.exe\" -Force"'
    Pop $0
    ${If} $0 == 0
        DetailPrint "Added process exclusion for Windows Defender"
    ${EndIf}
SectionEnd

; Component descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCore} $(DESC_SecCore)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecLanguageServers} $(DESC_SecLanguageServers)
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
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\uninst.exe"
    
    ; Remove directories
    RMDir /r "$INSTDIR\language-servers"
    RMDir /r "$INSTDIR\logs"
    RMDir /r "$INSTDIR\temp"
    RMDir /r "$INSTDIR\_internal"
    RMDir "$INSTDIR"
    
    ; Remove shortcuts
    !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
    Delete "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME} MCP Server.lnk"
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
    MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 \
        "Are you sure you want to completely remove $(^Name) and all of its components?" \
        IDYES +2
    Abort
FunctionEnd

Function un.onUninstSuccess
    HideWindow
    MessageBox MB_ICONINFORMATION|MB_OK \
        "$(^Name) was successfully removed from your computer."
FunctionEnd

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Code signing placeholders
; Uncomment and configure these when code signing certificate is available
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; !finalize 'signtool.exe sign /f "certificate.p12" /p "password" /t http://timestamp.verisign.com/scripts/timstamp.dll "%1"'
; !uninstfinalize 'signtool.exe sign /f "certificate.p12" /p "password" /t http://timestamp.verisign.com/scripts/timstamp.dll "%1"'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Additional utility functions for enterprise deployment
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Function CheckDiskSpace
    ; Check if enough disk space is available
    ${DriveSpace} "$INSTDIR" "/D=F /S=M" $0
    ${If} $0 < 500  ; Minimum 500MB required
        MessageBox MB_OK|MB_ICONSTOP \
            "Insufficient disk space. At least 500MB is required for installation."
        Abort
    ${EndIf}
FunctionEnd

Function CheckRunningProcesses
    ; Check for running Serena processes
    FindProcDLL::FindProc "serena.exe"
    ${If} $R0 == 1
        MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
            "Serena is currently running. Please close it before continuing." \
            IDRETRY CheckRunningProcesses IDCANCEL AbortInstall
    ${EndIf}
    
    FindProcDLL::FindProc "serena-mcp-server.exe"
    ${If} $R0 == 1
        MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
            "Serena MCP Server is currently running. Please close it before continuing." \
            IDRETRY CheckRunningProcesses IDCANCEL AbortInstall
    ${EndIf}
    
    Return
    
    AbortInstall:
        Abort
FunctionEnd

; End of installer script