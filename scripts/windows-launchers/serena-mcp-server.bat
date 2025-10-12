@echo off
REM ==============================================================================
REM Serena MCP Server Launcher - Windows Batch Script
REM ==============================================================================
REM
REM This script launches the Serena MCP Server executable in portable mode.
REM
REM Features:
REM   - Automatically detects portable installation directory
REM   - Sets up environment variables (SERENA_PORTABLE, SERENA_HOME, PATH)
REM   - Supports bundled runtimes (Node.js, Java, .NET)
REM   - Passes through all command-line arguments
REM   - Works from any working directory
REM   - Handles spaces in paths
REM
REM Usage:
REM   serena-mcp-server.bat [ARGUMENTS...]
REM   serena-mcp-server.bat --transport stdio
REM   serena-mcp-server.bat --transport sse --port 8001
REM
REM ==============================================================================

setlocal enabledelayedexpansion

REM ==============================================================================
REM Detect Installation Directory
REM ==============================================================================

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Set portable root (one level up from scripts directory, or current if in root)
if exist "%SCRIPT_DIR%\serena-mcp-server.exe" (
    set "SERENA_PORTABLE_ROOT=%SCRIPT_DIR%"
) else if exist "%SCRIPT_DIR%\..\serena-mcp-server.exe" (
    set "SERENA_PORTABLE_ROOT=%SCRIPT_DIR%\.."
) else (
    echo ERROR: Cannot locate serena-mcp-server.exe
    echo Searched in:
    echo   - %SCRIPT_DIR%
    echo   - %SCRIPT_DIR%\..
    echo.
    echo Please ensure this script is in the Serena portable installation directory.
    exit /b 1
)

REM Normalize path (resolve ..)
pushd "%SERENA_PORTABLE_ROOT%" 2>nul
if errorlevel 1 (
    echo ERROR: Cannot access portable root directory: %SERENA_PORTABLE_ROOT%
    exit /b 1
)
set "SERENA_PORTABLE_ROOT=%CD%"
popd

REM ==============================================================================
REM Verify Installation
REM ==============================================================================

set "SERENA_MCP_SERVER_EXE=%SERENA_PORTABLE_ROOT%\serena-mcp-server.exe"

if not exist "%SERENA_MCP_SERVER_EXE%" (
    echo ERROR: serena-mcp-server.exe not found at:
    echo   %SERENA_MCP_SERVER_EXE%
    echo.
    echo Please verify your Serena portable installation is complete.
    exit /b 1
)

REM ==============================================================================
REM Set Up Environment Variables
REM ==============================================================================

REM Portable mode flag
set "SERENA_PORTABLE=1"

REM Serena home directory (user data, configs, cache)
set "SERENA_HOME=%SERENA_PORTABLE_ROOT%\.serena-portable"
set "SERENA_CONFIG_DIR=%SERENA_HOME%"
set "SERENA_CACHE_DIR=%SERENA_HOME%\cache"
set "SERENA_LOG_DIR=%SERENA_HOME%\logs"
set "SERENA_TEMP_DIR=%SERENA_HOME%\temp"

REM Create directories if they don't exist
if not exist "%SERENA_HOME%" mkdir "%SERENA_HOME%" 2>nul
if not exist "%SERENA_CACHE_DIR%" mkdir "%SERENA_CACHE_DIR%" 2>nul
if not exist "%SERENA_LOG_DIR%" mkdir "%SERENA_LOG_DIR%" 2>nul
if not exist "%SERENA_TEMP_DIR%" mkdir "%SERENA_TEMP_DIR%" 2>nul

REM ==============================================================================
REM Set Up Bundled Runtimes
REM ==============================================================================

set "RUNTIMES_DIR=%SERENA_PORTABLE_ROOT%\runtimes"
set "LANGUAGE_SERVERS_DIR=%SERENA_PORTABLE_ROOT%\language_servers"

REM Add bundled Node.js to PATH (for TypeScript, Bash language servers)
if exist "%RUNTIMES_DIR%\nodejs\node.exe" (
    set "PATH=%RUNTIMES_DIR%\nodejs;%PATH%"
    set "NODE_PATH=%RUNTIMES_DIR%\nodejs"
)

REM Add bundled .NET to PATH (for C# language server - OmniSharp)
if exist "%RUNTIMES_DIR%\dotnet\dotnet.exe" (
    set "PATH=%RUNTIMES_DIR%\dotnet;%PATH%"
    set "DOTNET_ROOT=%RUNTIMES_DIR%\dotnet"
    set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
)

REM Add bundled Java to PATH (for Java, Kotlin language servers)
if exist "%RUNTIMES_DIR%\java\bin\java.exe" (
    set "PATH=%RUNTIMES_DIR%\java\bin;%PATH%"
    set "JAVA_HOME=%RUNTIMES_DIR%\java"
)

REM Add language servers directory to PATH
if exist "%LANGUAGE_SERVERS_DIR%" (
    set "PATH=%LANGUAGE_SERVERS_DIR%;%PATH%"
)

REM Add main executable directory to PATH
set "PATH=%SERENA_PORTABLE_ROOT%;%PATH%"

REM ==============================================================================
REM Launch Serena MCP Server
REM ==============================================================================

REM Pass all arguments to the executable
"%SERENA_MCP_SERVER_EXE%" %*

REM Capture exit code
set "EXIT_CODE=%ERRORLEVEL%"

REM Exit with the same code as serena-mcp-server.exe
exit /b %EXIT_CODE%
