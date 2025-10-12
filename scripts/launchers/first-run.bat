@echo off
REM ============================================================================
REM Serena First-Run Setup Script (Batch)
REM ============================================================================
REM This script performs first-time setup for Serena portable installation:
REM - Creates ~/.serena/ directory structure
REM - Copies default configuration files
REM - Optionally adds Serena to Windows PATH
REM - Runs installation verification
REM
REM Usage: first-run.bat [--add-to-path]
REM        --add-to-path: Automatically add to PATH (requires admin)
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================================
echo Serena First-Run Setup
echo ============================================================================
echo.

REM Detect the installation directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%A in ("%SCRIPT_DIR%\..\..") do set "INSTALL_DIR=%%~fA"

REM Set environment variables
set "SERENA_PORTABLE=1"
set "SERENA_HOME=%INSTALL_DIR%"

echo Installation directory: %INSTALL_DIR%
echo.

REM Create user configuration directory
set "USER_CONFIG_DIR=%USERPROFILE%\.serena"
echo [1/5] Creating configuration directory...
if not exist "%USER_CONFIG_DIR%" (
    mkdir "%USER_CONFIG_DIR%"
    if !ERRORLEVEL! neq 0 (
        echo ERROR: Failed to create directory: %USER_CONFIG_DIR%
        exit /b 1
    )
    echo       Created: %USER_CONFIG_DIR%
) else (
    echo       Already exists: %USER_CONFIG_DIR%
)
echo.

REM Create subdirectories
echo [2/5] Creating subdirectories...
for %%D in (memories projects logs cache) do (
    if not exist "%USER_CONFIG_DIR%\%%D" (
        mkdir "%USER_CONFIG_DIR%\%%D"
        echo       Created: %USER_CONFIG_DIR%\%%D
    )
)
echo.

REM Copy default configuration files
echo [3/5] Copying default configuration files...
set "DEFAULT_CONFIG=%INSTALL_DIR%\config"
if exist "%DEFAULT_CONFIG%\serena_config.yml" (
    if not exist "%USER_CONFIG_DIR%\serena_config.yml" (
        copy "%DEFAULT_CONFIG%\serena_config.yml" "%USER_CONFIG_DIR%\serena_config.yml" >nul
        if !ERRORLEVEL! equ 0 (
            echo       Copied: serena_config.yml
        ) else (
            echo       WARNING: Failed to copy serena_config.yml
        )
    ) else (
        echo       Already exists: serena_config.yml
    )
)
echo.

REM Check for --add-to-path argument
set "ADD_TO_PATH=0"
if "%~1"=="--add-to-path" set "ADD_TO_PATH=1"

echo [4/5] PATH Configuration...
if %ADD_TO_PATH%==1 (
    echo       Attempting to add Serena to system PATH...
    echo       NOTE: This requires administrator privileges.

    REM Try to add to user PATH using setx
    set "LAUNCHER_DIR=%INSTALL_DIR%\scripts\launchers"
    setx PATH "%PATH%;!LAUNCHER_DIR!" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo       SUCCESS: Added to PATH: !LAUNCHER_DIR!
        echo       Restart your command prompt to use serena commands globally.
    ) else (
        echo       FAILED: Could not add to PATH automatically.
        echo       Please add manually: !LAUNCHER_DIR!
    )
) else (
    echo       Skipped (use --add-to-path to add automatically)
    echo.
    echo       To use Serena from anywhere, add this to your PATH:
    echo       %INSTALL_DIR%\scripts\launchers
)
echo.

REM Run verification
echo [5/5] Running installation verification...
echo.
call "%SCRIPT_DIR%\verify-installation.bat"
set "VERIFY_RESULT=!ERRORLEVEL!"

echo.
echo ============================================================================
if %VERIFY_RESULT% equ 0 (
    echo First-run setup completed successfully!
    echo.
    echo You can now use Serena. Try these commands:
    echo   cd "%INSTALL_DIR%\scripts\launchers"
    echo   serena.bat --version
    echo   serena.bat --help
) else (
    echo First-run setup completed with warnings.
    echo Please review the verification results above.
)
echo ============================================================================
echo.

exit /b %VERIFY_RESULT%
