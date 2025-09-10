@echo off
REM Build script for Serena NSIS Installer
REM This script builds the Windows installer using NSIS

setlocal EnableDelayedExpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "INSTALLER_SCRIPT=%SCRIPT_DIR%serena-installer.nsi"
set "DIST_DIR=%PROJECT_ROOT%\dist"
set "OUTPUT_DIR=%SCRIPT_DIR%\output"

echo ============================================
echo Serena Agent - Installer Build Script
echo ============================================

REM Check if NSIS is installed
where makensis >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: NSIS (makensis) not found in PATH
    echo Please install NSIS from: https://nsis.sourceforge.io/
    exit /b 1
)

REM Check if distribution files exist
if not exist "%DIST_DIR%" (
    echo ERROR: Distribution directory not found: %DIST_DIR%
    echo Please build the portable distribution first using build-portable.ps1
    exit /b 1
)

REM Create output directory
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

REM Copy required files for installer
echo Preparing installer files...
if not exist "%SCRIPT_DIR%\dist\" (
    mkdir "%SCRIPT_DIR%\dist\"
)

REM Copy distribution files to installer directory
robocopy "%DIST_DIR%" "%SCRIPT_DIR%\dist" /E /NFL /NDL /NJH /NJS
if %ERRORLEVEL% geq 8 (
    echo ERROR: Failed to copy distribution files
    exit /b 1
)

REM Copy language servers if they exist
if exist "%PROJECT_ROOT%\language-servers" (
    echo Copying language servers...
    if not exist "%SCRIPT_DIR%\language-servers\" (
        mkdir "%SCRIPT_DIR%\language-servers\"
    )
    robocopy "%PROJECT_ROOT%\language-servers" "%SCRIPT_DIR%\language-servers" /E /NFL /NDL /NJH /NJS
)

REM Build the installer
echo Building installer...
pushd "%SCRIPT_DIR%"
makensis /V3 "%INSTALLER_SCRIPT%"
set "BUILD_RESULT=%ERRORLEVEL%"
popd

if %BUILD_RESULT% neq 0 (
    echo ERROR: Installer build failed with code %BUILD_RESULT%
    exit /b %BUILD_RESULT%
)

REM Move installer to output directory
if exist "%SCRIPT_DIR%\serena-installer-*.exe" (
    move "%SCRIPT_DIR%\serena-installer-*.exe" "%OUTPUT_DIR%\"
    echo SUCCESS: Installer created in %OUTPUT_DIR%
) else (
    echo ERROR: Installer file not found after build
    exit /b 1
)

REM Cleanup temporary files
if exist "%SCRIPT_DIR%\dist\" (
    rmdir /s /q "%SCRIPT_DIR%\dist"
)
if exist "%SCRIPT_DIR%\language-servers\" (
    rmdir /s /q "%SCRIPT_DIR%\language-servers"
)

echo.
echo ============================================
echo Build completed successfully!
echo Installer location: %OUTPUT_DIR%
echo ============================================

endlocal