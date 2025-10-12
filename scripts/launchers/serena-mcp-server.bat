@echo off
REM ============================================================================
REM Serena MCP Server Launcher (Batch)
REM ============================================================================
REM This script launches the serena-mcp-server.exe from the portable package.
REM It automatically detects the installation directory and sets up the
REM required environment variables.
REM
REM Usage: serena-mcp-server.bat [arguments...]
REM All arguments are passed directly to serena-mcp-server.exe
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

REM Check if serena-mcp-server.exe exists
set "MCP_SERVER_EXE=%INSTALL_DIR%\bin\serena-mcp-server.exe"
if not exist "%MCP_SERVER_EXE%" (
    echo ERROR: serena-mcp-server.exe not found at: %MCP_SERVER_EXE%
    echo Please ensure Serena is properly installed.
    exit /b 1
)

REM Launch serena-mcp-server.exe with all provided arguments
"%MCP_SERVER_EXE%" %*

REM Exit with the same code as serena-mcp-server.exe
exit /b %ERRORLEVEL%
