@echo off
REM ============================================================================
REM Serena CLI Launcher (Batch)
REM ============================================================================
REM This script launches the serena.exe CLI tool from the portable package.
REM It automatically detects the installation directory and sets up the
REM required environment variables.
REM
REM Usage: serena.bat [arguments...]
REM All arguments are passed directly to serena.exe
REM ============================================================================

setlocal enabledelayedexpansion

REM Detect the installation directory (where this script is located)
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Navigate up two directories to get to the installation root
for %%A in ("%SCRIPT_DIR%\..\..") do set "INSTALL_DIR=%%~fA"

REM Set portable mode environment variable
set "SERENA_PORTABLE=1"
set "SERENA_HOME=%INSTALL_DIR%"

REM Add runtime directories to PATH
set "PATH=%INSTALL_DIR%\runtimes\nodejs;%PATH%"
set "PATH=%INSTALL_DIR%\runtimes\dotnet;%PATH%"
set "PATH=%INSTALL_DIR%\runtimes\java\bin;%PATH%"

REM Set language-specific environment variables
set "JAVA_HOME=%INSTALL_DIR%\runtimes\java"
set "DOTNET_ROOT=%INSTALL_DIR%\runtimes\dotnet"
set "NODE_PATH=%INSTALL_DIR%\runtimes\nodejs\node_modules"

REM Check if serena.exe exists
set "SERENA_EXE=%INSTALL_DIR%\bin\serena.exe"
if not exist "%SERENA_EXE%" (
    echo ERROR: serena.exe not found at: %SERENA_EXE%
    echo Please ensure Serena is properly installed.
    exit /b 1
)

REM Launch serena.exe with all provided arguments
"%SERENA_EXE%" %*

REM Exit with the same code as serena.exe
exit /b %ERRORLEVEL%
