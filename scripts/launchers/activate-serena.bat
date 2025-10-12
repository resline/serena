@echo off
REM ============================================================================
REM Serena Environment Activation Script (Batch)
REM ============================================================================
REM This script activates the Serena environment in the current shell session.
REM It sets all necessary environment variables but does NOT launch any program.
REM
REM Usage: Call this script to set up environment variables:
REM        call activate-serena.bat
REM
REM        Then use commands directly:
REM        serena.exe --version
REM
REM NOTE: This script must be called (not run directly) to affect the current
REM       shell session. Use "call activate-serena.bat" or run from another script.
REM ============================================================================

REM Detect the installation directory (where this script is located)
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Navigate up two directories to get to the installation root
for %%A in ("%SCRIPT_DIR%\..\..") do set "INSTALL_DIR=%%~fA"

REM Set portable mode environment variable
set "SERENA_PORTABLE=1"
set "SERENA_HOME=%INSTALL_DIR%"

REM Add bin directory to PATH
set "PATH=%INSTALL_DIR%\bin;%PATH%"

REM Add runtime directories to PATH
set "PATH=%INSTALL_DIR%\runtimes\nodejs;%PATH%"
set "PATH=%INSTALL_DIR%\runtimes\dotnet;%PATH%"
set "PATH=%INSTALL_DIR%\runtimes\java\bin;%PATH%"

REM Set language-specific environment variables
set "JAVA_HOME=%INSTALL_DIR%\runtimes\java"
set "DOTNET_ROOT=%INSTALL_DIR%\runtimes\dotnet"
set "NODE_PATH=%INSTALL_DIR%\runtimes\nodejs\node_modules"

echo.
echo ============================================================================
echo Serena Environment Activated
echo ============================================================================
echo.
echo SERENA_HOME: %SERENA_HOME%
echo SERENA_PORTABLE: %SERENA_PORTABLE%
echo.
echo You can now use Serena commands directly:
echo   serena.exe --version
echo   serena.exe --help
echo   serena-mcp-server.exe --help
echo.
echo Runtime paths have been added to PATH:
echo   - Node.js: %INSTALL_DIR%\runtimes\nodejs
echo   - .NET: %INSTALL_DIR%\runtimes\dotnet
echo   - Java: %INSTALL_DIR%\runtimes\java\bin
echo.
echo ============================================================================
echo.
