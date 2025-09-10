@echo off
setlocal EnableDelayedExpansion

REM =============================================================================
REM Serena Portable Launcher for Windows
REM 
REM This script provides a portable launcher for Serena on Windows systems.
REM It handles environment setup, path detection, and launches the PyInstaller
REM executable with proper error handling and user feedback.
REM =============================================================================

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "SERENA_PORTABLE_ROOT=%SCRIPT_DIR%"

REM Configuration file path
set "CONFIG_FILE=%SCRIPT_DIR%\launcher-config.json"

REM Log file for troubleshooting
set "LOG_FILE=%SCRIPT_DIR%\serena-launcher.log"

REM Clear previous log
echo. > "%LOG_FILE%" 2>NUL

echo [%date% %time%] Serena Portable Launcher Starting >> "%LOG_FILE%"
echo.
echo ========================================
echo   Serena Portable Launcher v1.0
echo ========================================
echo.

REM Function to log messages
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

REM Function to display error and log
:error
echo ERROR: %~1
call :log "ERROR: %~1"
goto :eof

REM Function to display info and log
:info
echo INFO: %~1
call :log "INFO: %~1"
goto :eof

REM Check if configuration file exists
if not exist "%CONFIG_FILE%" (
    call :error "Configuration file not found: %CONFIG_FILE%"
    echo.
    echo Please ensure launcher-config.json exists in the same directory.
    echo You can create it from the template or reinstall Serena Portable.
    pause
    exit /b 1
)

call :info "Configuration file found: %CONFIG_FILE%"

REM Look for Serena executable in common locations
set "SERENA_EXE="
set "POSSIBLE_PATHS[0]=%SCRIPT_DIR%\serena.exe"
set "POSSIBLE_PATHS[1]=%SCRIPT_DIR%\dist\serena.exe"
set "POSSIBLE_PATHS[2]=%SCRIPT_DIR%\build\serena.exe"
set "POSSIBLE_PATHS[3]=%SCRIPT_DIR%\serena-mcp-server.exe"
set "POSSIBLE_PATHS[4]=%SCRIPT_DIR%\dist\serena-mcp-server.exe"
set "POSSIBLE_PATHS[5]=%SCRIPT_DIR%\build\serena-mcp-server.exe"

for /L %%i in (0,1,5) do (
    if exist "!POSSIBLE_PATHS[%%i]!" (
        set "SERENA_EXE=!POSSIBLE_PATHS[%%i]!"
        call :info "Found Serena executable: !SERENA_EXE!"
        goto :found_exe
    )
)

call :error "Serena executable not found in expected locations"
echo.
echo Searched locations:
for /L %%i in (0,1,5) do (
    echo   - !POSSIBLE_PATHS[%%i]!
)
echo.
echo Please ensure the Serena executable is built and placed in one of these locations.
pause
exit /b 1

:found_exe

REM Set up environment variables from config (basic implementation)
call :info "Setting up environment from configuration..."

REM Create a portable user directory if it doesn't exist
set "SERENA_USER_DIR=%SCRIPT_DIR%\.serena-portable"
if not exist "%SERENA_USER_DIR%" (
    mkdir "%SERENA_USER_DIR%" 2>NUL
    call :info "Created portable user directory: %SERENA_USER_DIR%"
)

REM Set environment variables for portable operation
set "SERENA_HOME=%SERENA_USER_DIR%"
set "SERENA_CONFIG_DIR=%SERENA_USER_DIR%"
set "SERENA_CACHE_DIR=%SERENA_USER_DIR%\cache"
set "SERENA_LOG_DIR=%SERENA_USER_DIR%\logs"

REM Create necessary directories
if not exist "%SERENA_CACHE_DIR%" mkdir "%SERENA_CACHE_DIR%" 2>NUL
if not exist "%SERENA_LOG_DIR%" mkdir "%SERENA_LOG_DIR%" 2>NUL

call :info "Portable directories configured"

REM Check for language server dependencies
call :info "Checking language server setup..."
set "LANGUAGE_SERVERS_DIR=%SCRIPT_DIR%\language-servers"
if exist "%LANGUAGE_SERVERS_DIR%" (
    call :info "Language servers directory found: %LANGUAGE_SERVERS_DIR%"
    set "PATH=%LANGUAGE_SERVERS_DIR%;%PATH%"
) else (
    call :info "Language servers directory not found - servers will be downloaded on demand"
)

REM Handle command line arguments
set "ARGS="
:parse_args
if "%~1"=="" goto :done_parsing
if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help
if "%~1"=="--version" goto :show_version
if "%~1"=="--config" goto :show_config

REM Accumulate all arguments, properly quoting those with spaces
if "!ARGS!"=="" (
    set "ARGS=%~1"
) else (
    if "%~1"=="%1" (
        set "ARGS=!ARGS! %~1"
    ) else (
        set "ARGS=!ARGS! "%~1""
    )
)
shift
goto :parse_args

:done_parsing

REM Display startup information
echo Starting Serena Portable...
echo Executable: %SERENA_EXE%
echo User Directory: %SERENA_USER_DIR%
if not "!ARGS!"=="" echo Arguments: !ARGS!
echo.

call :info "Launching Serena with arguments: !ARGS!"

REM Launch Serena and capture exit code
if "!ARGS!"=="" (
    "%SERENA_EXE%"
) else (
    "%SERENA_EXE%" !ARGS!
)

set "EXIT_CODE=%ERRORLEVEL%"
call :log "Serena exited with code: %EXIT_CODE%"

REM Handle different exit codes
if %EXIT_CODE%==0 (
    call :info "Serena completed successfully"
    goto :end
)

if %EXIT_CODE%==1 (
    call :error "Serena exited with error code 1"
    echo.
    echo This may indicate a configuration or runtime error.
    echo Check the log file for details: %LOG_FILE%
    goto :error_end
)

call :error "Serena exited with unexpected code: %EXIT_CODE%"
echo.
echo Please check the log file for details: %LOG_FILE%
goto :error_end

:show_help
echo.
echo Serena Portable Launcher Help
echo =============================
echo.
echo Usage: serena-portable.bat [OPTIONS] [SERENA_ARGUMENTS]
echo.
echo Launcher Options:
echo   --help, -h          Show this help message
echo   --version           Show version information  
echo   --config            Show configuration information
echo.
echo Any other arguments are passed directly to Serena.
echo.
echo Examples:
echo   serena-portable.bat --help
echo   serena-portable.bat start-mcp-server
echo   serena-portable.bat start-mcp-server --project "C:\My Project"
echo   serena-portable.bat start-mcp-server --context agent --mode editing
echo.
echo For Serena-specific help, use:
echo   serena-portable.bat --help
echo.
goto :end

:show_version
echo.
echo Serena Portable Launcher v1.0
echo.
if exist "%SERENA_EXE%" (
    echo Serena executable: %SERENA_EXE%
    "%SERENA_EXE%" --version 2>NUL
    if !ERRORLEVEL! neq 0 echo Unable to get Serena version
) else (
    echo Serena executable: Not found
)
echo.
goto :end

:show_config
echo.
echo Serena Portable Configuration
echo =============================
echo.
echo Script Directory: %SCRIPT_DIR%
echo Configuration File: %CONFIG_FILE%
echo Log File: %LOG_FILE%
echo User Directory: %SERENA_USER_DIR%
echo Cache Directory: %SERENA_CACHE_DIR%
echo Log Directory: %SERENA_LOG_DIR%
echo.
if exist "%LANGUAGE_SERVERS_DIR%" (
    echo Language Servers: %LANGUAGE_SERVERS_DIR%
) else (
    echo Language Servers: Not bundled (downloaded on demand)
)
echo.
if exist "%SERENA_EXE%" (
    echo Serena Executable: %SERENA_EXE%
) else (
    echo Serena Executable: NOT FOUND
)
echo.
goto :end

:error_end
echo.
echo If you continue to experience issues:
echo 1. Check the log file: %LOG_FILE%
echo 2. Verify the configuration: %CONFIG_FILE%
echo 3. Ensure all dependencies are properly installed
echo 4. Try running with --config to see current settings
echo.
pause
exit /b %EXIT_CODE%

:end
exit /b 0