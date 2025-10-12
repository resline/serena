@echo off
REM ==============================================================================
REM Serena Portable First-Run Setup - Windows Batch Script
REM ==============================================================================
REM
REM This script performs first-time setup for Serena Portable installation.
REM
REM Features:
REM   - Creates .serena-portable directory structure
REM   - Copies default configuration files
REM   - Optionally adds Serena to user PATH
REM   - Verifies installation integrity
REM   - Tests executable functionality
REM
REM Usage:
REM   first-run.bat
REM   first-run.bat --no-path     (skip adding to PATH)
REM   first-run.bat --silent      (minimal output)
REM
REM ==============================================================================

setlocal enabledelayedexpansion

REM Parse command-line arguments
set "ADD_TO_PATH=1"
set "SILENT_MODE=0"

:parse_args
if "%~1"=="" goto end_parse_args
if /I "%~1"=="--no-path" set "ADD_TO_PATH=0"
if /I "%~1"=="--silent" set "SILENT_MODE=1"
shift
goto parse_args
:end_parse_args

REM ==============================================================================
REM Display Banner
REM ==============================================================================

if "%SILENT_MODE%"=="0" (
    echo.
    echo ================================================================================
    echo   Serena Portable - First-Run Setup
    echo ================================================================================
    echo.
)

REM ==============================================================================
REM Detect Installation Directory
REM ==============================================================================

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

if exist "%SCRIPT_DIR%\serena.exe" (
    set "SERENA_PORTABLE_ROOT=%SCRIPT_DIR%"
) else if exist "%SCRIPT_DIR%\..\serena.exe" (
    set "SERENA_PORTABLE_ROOT=%SCRIPT_DIR%\.."
) else (
    echo ERROR: Cannot locate Serena installation
    echo Please run this script from the Serena portable installation directory.
    exit /b 1
)

pushd "%SERENA_PORTABLE_ROOT%" 2>nul
set "SERENA_PORTABLE_ROOT=%CD%"
popd

if "%SILENT_MODE%"=="0" (
    echo [1/6] Detected installation directory:
    echo       %SERENA_PORTABLE_ROOT%
    echo.
)

REM ==============================================================================
REM Verify Installation
REM ==============================================================================

if "%SILENT_MODE%"=="0" echo [2/6] Verifying installation files...

set "MISSING_FILES=0"

if not exist "%SERENA_PORTABLE_ROOT%\serena.exe" (
    echo       ERROR: serena.exe not found
    set "MISSING_FILES=1"
)

if not exist "%SERENA_PORTABLE_ROOT%\serena-mcp-server.exe" (
    echo       ERROR: serena-mcp-server.exe not found
    set "MISSING_FILES=1"
)

if not exist "%SERENA_PORTABLE_ROOT%\index-project.exe" (
    echo       WARNING: index-project.exe not found ^(optional^)
)

if "%MISSING_FILES%"=="1" (
    echo.
    echo ERROR: Installation is incomplete. Please download the full Serena portable package.
    exit /b 1
)

if "%SILENT_MODE%"=="0" echo       OK - All required executables found

REM ==============================================================================
REM Create Directory Structure
REM ==============================================================================

if "%SILENT_MODE%"=="0" echo [3/6] Creating directory structure...

set "SERENA_HOME=%SERENA_PORTABLE_ROOT%\.serena-portable"

REM Create main directories
for %%D in (
    "%SERENA_HOME%"
    "%SERENA_HOME%\cache"
    "%SERENA_HOME%\logs"
    "%SERENA_HOME%\temp"
    "%SERENA_HOME%\contexts"
    "%SERENA_HOME%\modes"
    "%SERENA_HOME%\prompt_templates"
    "%SERENA_HOME%\memories"
) do (
    if not exist "%%~D" (
        mkdir "%%~D" 2>nul
        if "%SILENT_MODE%"=="0" echo       Created: %%~D
    )
)

REM ==============================================================================
REM Copy Default Configuration Files
REM ==============================================================================

if "%SILENT_MODE%"=="0" echo [4/6] Copying default configuration files...

REM Check if running from a PyInstaller bundle (resources in _internal)
set "RESOURCES_DIR=%SERENA_PORTABLE_ROOT%\_internal\serena\resources"
if not exist "%RESOURCES_DIR%" (
    set "RESOURCES_DIR=%SERENA_PORTABLE_ROOT%\serena\resources"
)

REM Copy serena_config.yml if it doesn't exist
set "CONFIG_FILE=%SERENA_HOME%\serena_config.yml"
set "TEMPLATE_FILE=%RESOURCES_DIR%\serena_config.template.yml"

if not exist "%CONFIG_FILE%" (
    if exist "%TEMPLATE_FILE%" (
        copy /Y "%TEMPLATE_FILE%" "%CONFIG_FILE%" >nul 2>&1
        if "%SILENT_MODE%"=="0" echo       Copied: serena_config.yml
    ) else (
        if "%SILENT_MODE%"=="0" echo       WARNING: Template file not found: %TEMPLATE_FILE%
    )
) else (
    if "%SILENT_MODE%"=="0" echo       EXISTS: serena_config.yml ^(not overwritten^)
)

REM Copy default contexts
set "CONTEXTS_SRC=%RESOURCES_DIR%\config\contexts"
if exist "%CONTEXTS_SRC%" (
    xcopy /Y /Q "%CONTEXTS_SRC%\*.yml" "%SERENA_HOME%\contexts\" >nul 2>&1
    if "%SILENT_MODE%"=="0" echo       Copied: default contexts
)

REM Copy default modes
set "MODES_SRC=%RESOURCES_DIR%\config\modes"
if exist "%MODES_SRC%" (
    xcopy /Y /Q "%MODES_SRC%\*.yml" "%SERENA_HOME%\modes\" >nul 2>&1
    if "%SILENT_MODE%"=="0" echo       Copied: default modes
)

REM Copy prompt templates
set "TEMPLATES_SRC=%RESOURCES_DIR%\config\prompt_templates"
if exist "%TEMPLATES_SRC%" (
    xcopy /Y /Q "%TEMPLATES_SRC%\*.yml" "%SERENA_HOME%\prompt_templates\" >nul 2>&1
    if "%SILENT_MODE%"=="0" echo       Copied: prompt templates
)

REM ==============================================================================
REM Add to PATH (Optional)
REM ==============================================================================

if "%ADD_TO_PATH%"=="1" (
    if "%SILENT_MODE%"=="0" echo [5/6] Adding Serena to user PATH...

    REM Use PowerShell to modify user PATH
    powershell -Command "$currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User'); if ($currentPath -notlike '*%SERENA_PORTABLE_ROOT%*') { [Environment]::SetEnvironmentVariable('PATH', $currentPath + ';%SERENA_PORTABLE_ROOT%', 'User'); Write-Host '       Added to PATH: %SERENA_PORTABLE_ROOT%' } else { Write-Host '       Already in PATH' }" 2>nul

    if errorlevel 1 (
        if "%SILENT_MODE%"=="0" (
            echo       WARNING: Failed to add to PATH ^(requires PowerShell^)
            echo       You can manually add this directory to your PATH:
            echo       %SERENA_PORTABLE_ROOT%
        )
    )
) else (
    if "%SILENT_MODE%"=="0" echo [5/6] Skipping PATH modification ^(--no-path specified^)
)

REM ==============================================================================
REM Verify Installation
REM ==============================================================================

if "%SILENT_MODE%"=="0" echo [6/6] Verifying installation...

REM Test serena.exe
"%SERENA_PORTABLE_ROOT%\serena.exe" --version >nul 2>&1
if errorlevel 1 (
    echo       WARNING: serena.exe returned an error
) else (
    if "%SILENT_MODE%"=="0" echo       OK - serena.exe is functional
)

REM ==============================================================================
REM Completion
REM ==============================================================================

if "%SILENT_MODE%"=="0" (
    echo.
    echo ================================================================================
    echo   Setup Complete!
    echo ================================================================================
    echo.
    echo Serena Portable is now ready to use.
    echo.
    echo Installation directory: %SERENA_PORTABLE_ROOT%
    echo User data directory:    %SERENA_HOME%
    echo.
    echo Next steps:
    echo   1. Run 'serena --help' to see available commands
    echo   2. Run 'serena config edit' to customize your configuration
    echo   3. Run 'serena project index [path]' to index your first project
    echo   4. Run 'verify-installation.bat' to perform a health check
    echo.
    if "%ADD_TO_PATH%"=="1" (
        echo Note: Restart your command prompt to use 'serena' from any directory.
        echo.
    )
    echo ================================================================================
    echo.
)

exit /b 0
