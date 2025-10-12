@echo off
REM ============================================================================
REM Serena Index Project Launcher (Batch)
REM ============================================================================
REM This script launches the index-project.exe tool from the portable package.
REM It automatically detects the installation directory and sets up the
REM required environment variables.
REM
REM Usage: index-project.bat [arguments...]
REM All arguments are passed directly to index-project.exe
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

REM Check if index-project.exe exists
set "INDEX_EXE=%INSTALL_DIR%\bin\index-project.exe"
if not exist "%INDEX_EXE%" (
    echo ERROR: index-project.exe not found at: %INDEX_EXE%
    echo Please ensure Serena is properly installed.
    exit /b 1
)

REM Launch index-project.exe with all provided arguments
"%INDEX_EXE%" %*

REM Exit with the same code as index-project.exe
exit /b %ERRORLEVEL%
