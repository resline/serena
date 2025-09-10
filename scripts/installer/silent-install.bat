@echo off
REM Silent installation script for Serena Agent
REM This script performs an unattended installation using predefined settings

setlocal EnableDelayedExpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "CONFIG_FILE=%SCRIPT_DIR%silent-install.ini"
set "LOG_FILE=%TEMP%\serena-silent-install.log"

echo ============================================
echo Serena Agent - Silent Installation
echo ============================================

REM Find the installer executable
for %%f in ("%SCRIPT_DIR%serena-installer-*.exe") do (
    set "INSTALLER_EXE=%%f"
    goto :found
)

echo ERROR: Installer executable not found in %SCRIPT_DIR%
echo Expected filename pattern: serena-installer-*.exe
pause
exit /b 1

:found
echo Installer: !INSTALLER_EXE!
echo Configuration: %CONFIG_FILE%
echo Log file: %LOG_FILE%
echo.

REM Check if configuration file exists
if not exist "%CONFIG_FILE%" (
    echo WARNING: Configuration file not found: %CONFIG_FILE%
    echo Using default installation settings...
    set "CONFIG_PARAM="
) else (
    echo Using configuration file: %CONFIG_FILE%
    set "CONFIG_PARAM=/INI=%CONFIG_FILE%"
)

REM Check for administrator privileges if system-wide installation is requested
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo WARNING: Administrator privileges not detected
    echo Some features may not be available or installation may fail
    echo.
    choice /C YN /M "Continue with installation"
    if errorlevel 2 exit /b 1
)

REM Perform silent installation
echo Starting silent installation...
echo Command: "!INSTALLER_EXE!" /S %CONFIG_PARAM% /LOG="%LOG_FILE%"
echo.

"!INSTALLER_EXE!" /S %CONFIG_PARAM% /LOG="%LOG_FILE%"
set "INSTALL_RESULT=%ERRORLEVEL%"

REM Check installation result
if %INSTALL_RESULT% equ 0 (
    echo.
    echo ============================================
    echo Installation completed successfully!
    echo ============================================
    echo.
    echo Installation log: %LOG_FILE%
    
    REM Check if Serena was installed correctly
    where serena >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo Serena is available in PATH
        echo Testing installation...
        serena --version
    ) else (
        echo Serena not found in PATH - manual PATH setup may be required
    )
) else (
    echo.
    echo ============================================
    echo Installation failed with code %INSTALL_RESULT%
    echo ============================================
    echo.
    echo Please check the installation log: %LOG_FILE%
    echo.
    echo Common issues:
    echo - Insufficient permissions (run as administrator)
    echo - Antivirus interference (temporarily disable)
    echo - Previous installation conflicts (uninstall first)
    echo - Insufficient disk space
    pause
    exit /b %INSTALL_RESULT%
)

REM Optional: Display log file if installation failed
if %INSTALL_RESULT% neq 0 (
    if exist "%LOG_FILE%" (
        echo.
        choice /C YN /M "Display installation log"
        if not errorlevel 2 (
            echo.
            echo === Installation Log ===
            type "%LOG_FILE%"
            echo === End of Log ===
        )
    )
)

echo.
echo Press any key to exit...
pause >nul

endlocal