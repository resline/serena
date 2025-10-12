@echo off
REM ==============================================================================
REM Serena Portable Installation Verification - Windows Batch Script
REM ==============================================================================
REM
REM This script performs comprehensive health checks on Serena Portable.
REM
REM Features:
REM   - Verifies all executables are present and functional
REM   - Checks directory structure
REM   - Tests bundled runtimes (Node.js, .NET, Java)
REM   - Verifies language server installations
REM   - Checks configuration files
REM   - Reports disk space usage
REM
REM Usage:
REM   verify-installation.bat
REM   verify-installation.bat --verbose
REM   verify-installation.bat --fix       (attempt to fix issues)
REM
REM ==============================================================================

setlocal enabledelayedexpansion

REM Parse command-line arguments
set "VERBOSE_MODE=0"
set "FIX_MODE=0"

:parse_args
if "%~1"=="" goto end_parse_args
if /I "%~1"=="--verbose" set "VERBOSE_MODE=1"
if /I "%~1"=="-v" set "VERBOSE_MODE=1"
if /I "%~1"=="--fix" set "FIX_MODE=1"
shift
goto parse_args
:end_parse_args

REM ==============================================================================
REM Display Banner
REM ==============================================================================

echo.
echo ================================================================================
echo   Serena Portable - Installation Verification
echo ================================================================================
echo.

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
    echo [ERROR] Cannot locate Serena installation
    exit /b 1
)

pushd "%SERENA_PORTABLE_ROOT%" 2>nul
set "SERENA_PORTABLE_ROOT=%CD%"
popd

echo [INFO] Installation directory: %SERENA_PORTABLE_ROOT%
echo.

REM Initialize counters
set "TESTS_PASSED=0"
set "TESTS_FAILED=0"
set "TESTS_WARNINGS=0"

REM ==============================================================================
REM Test 1: Verify Core Executables
REM ==============================================================================

echo [TEST 1/8] Verifying core executables...

set "SERENA_EXE=%SERENA_PORTABLE_ROOT%\serena.exe"
if exist "%SERENA_EXE%" (
    echo   [PASS] serena.exe found
    set /a TESTS_PASSED+=1

    REM Test if executable runs
    "%SERENA_EXE%" --version >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] serena.exe cannot execute
        set /a TESTS_FAILED+=1
    ) else (
        echo   [PASS] serena.exe is functional
        set /a TESTS_PASSED+=1
    )
) else (
    echo   [FAIL] serena.exe not found
    set /a TESTS_FAILED+=1
)

set "MCP_SERVER_EXE=%SERENA_PORTABLE_ROOT%\serena-mcp-server.exe"
if exist "%MCP_SERVER_EXE%" (
    echo   [PASS] serena-mcp-server.exe found
    set /a TESTS_PASSED+=1
) else (
    echo   [FAIL] serena-mcp-server.exe not found
    set /a TESTS_FAILED+=1
)

set "INDEX_PROJECT_EXE=%SERENA_PORTABLE_ROOT%\index-project.exe"
if exist "%INDEX_PROJECT_EXE%" (
    echo   [PASS] index-project.exe found ^(deprecated^)
    set /a TESTS_PASSED+=1
) else (
    echo   [WARN] index-project.exe not found ^(optional^)
    set /a TESTS_WARNINGS+=1
)

echo.

REM ==============================================================================
REM Test 2: Verify Directory Structure
REM ==============================================================================

echo [TEST 2/8] Verifying directory structure...

set "SERENA_HOME=%SERENA_PORTABLE_ROOT%\.serena-portable"

for %%D in (
    "%SERENA_HOME%"
    "%SERENA_HOME%\cache"
    "%SERENA_HOME%\logs"
    "%SERENA_HOME%\temp"
) do (
    if exist "%%~D" (
        if "%VERBOSE_MODE%"=="1" echo   [PASS] Directory exists: %%~D
        set /a TESTS_PASSED+=1
    ) else (
        echo   [FAIL] Directory missing: %%~D
        set /a TESTS_FAILED+=1

        if "%FIX_MODE%"=="1" (
            mkdir "%%~D" 2>nul
            if exist "%%~D" (
                echo   [FIX]  Created directory: %%~D
            )
        )
    )
)

if "%VERBOSE_MODE%"=="0" echo   [INFO] Directory structure verified
echo.

REM ==============================================================================
REM Test 3: Verify Configuration Files
REM ==============================================================================

echo [TEST 3/8] Verifying configuration files...

set "CONFIG_FILE=%SERENA_HOME%\serena_config.yml"
if exist "%CONFIG_FILE%" (
    echo   [PASS] serena_config.yml found
    set /a TESTS_PASSED+=1
) else (
    echo   [WARN] serena_config.yml not found
    echo          Run 'first-run.bat' to create default configuration
    set /a TESTS_WARNINGS+=1
)

echo.

REM ==============================================================================
REM Test 4: Check Bundled Runtimes
REM ==============================================================================

echo [TEST 4/8] Checking bundled runtimes...

set "RUNTIMES_DIR=%SERENA_PORTABLE_ROOT%\runtimes"

REM Node.js
set "NODE_EXE=%RUNTIMES_DIR%\nodejs\node.exe"
if exist "%NODE_EXE%" (
    echo   [PASS] Node.js runtime found
    set /a TESTS_PASSED+=1

    if "%VERBOSE_MODE%"=="1" (
        "%NODE_EXE%" --version 2>nul
    )
) else (
    echo   [WARN] Node.js runtime not bundled
    echo          Required for: TypeScript, JavaScript, Bash language servers
    set /a TESTS_WARNINGS+=1
)

REM .NET
set "DOTNET_EXE=%RUNTIMES_DIR%\dotnet\dotnet.exe"
if exist "%DOTNET_EXE%" (
    echo   [PASS] .NET runtime found
    set /a TESTS_PASSED+=1

    if "%VERBOSE_MODE%"=="1" (
        "%DOTNET_EXE%" --version 2>nul
    )
) else (
    echo   [WARN] .NET runtime not bundled
    echo          Required for: C# language server ^(OmniSharp^)
    set /a TESTS_WARNINGS+=1
)

REM Java
set "JAVA_EXE=%RUNTIMES_DIR%\java\bin\java.exe"
if exist "%JAVA_EXE%" (
    echo   [PASS] Java runtime found
    set /a TESTS_PASSED+=1

    if "%VERBOSE_MODE%"=="1" (
        "%JAVA_EXE%" -version 2>nul
    )
) else (
    echo   [WARN] Java runtime not bundled
    echo          Required for: Java, Kotlin language servers
    set /a TESTS_WARNINGS+=1
)

echo.

REM ==============================================================================
REM Test 5: Check Language Servers Directory
REM ==============================================================================

echo [TEST 5/8] Checking language servers...

set "LANGUAGE_SERVERS_DIR=%SERENA_PORTABLE_ROOT%\language_servers"

if exist "%LANGUAGE_SERVERS_DIR%" (
    echo   [PASS] Language servers directory exists
    set /a TESTS_PASSED+=1

    if "%VERBOSE_MODE%"=="1" (
        dir /B "%LANGUAGE_SERVERS_DIR%" 2>nul | find /C /V "" >nul
        echo          Language servers will be downloaded on-demand
    )
) else (
    echo   [WARN] Language servers directory not found
    echo          Language servers will be downloaded on first use
    set /a TESTS_WARNINGS+=1

    if "%FIX_MODE%"=="1" (
        mkdir "%LANGUAGE_SERVERS_DIR%" 2>nul
        echo   [FIX]  Created language servers directory
    )
)

echo.

REM ==============================================================================
REM Test 6: Check Available Disk Space
REM ==============================================================================

echo [TEST 6/8] Checking disk space...

REM Get drive letter
set "DRIVE_LETTER=%SERENA_PORTABLE_ROOT:~0,2%"

REM Use PowerShell to get free space (more reliable)
for /f "usebackq" %%A in (`powershell -Command "$drive = Get-PSDrive -Name '%DRIVE_LETTER:~0,1%'; [math]::Round($drive.Free / 1GB, 2)"`) do set "FREE_SPACE_GB=%%A"

if defined FREE_SPACE_GB (
    echo   [INFO] Free space on %DRIVE_LETTER%: %FREE_SPACE_GB% GB

    REM Check if less than 1 GB free
    if "%FREE_SPACE_GB:~0,1%"=="0" (
        echo   [WARN] Low disk space
        set /a TESTS_WARNINGS+=1
    ) else (
        set /a TESTS_PASSED+=1
    )
) else (
    echo   [WARN] Could not determine free disk space
    set /a TESTS_WARNINGS+=1
)

echo.

REM ==============================================================================
REM Test 7: Check Environment Variables
REM ==============================================================================

echo [TEST 7/8] Checking environment variables...

REM Check if Serena is in PATH
echo %PATH% | find /I "%SERENA_PORTABLE_ROOT%" >nul 2>&1
if errorlevel 1 (
    echo   [INFO] Serena not in PATH
    echo          Run 'first-run.bat' to add to PATH
) else (
    echo   [PASS] Serena is in PATH
    set /a TESTS_PASSED+=1
)

echo.

REM ==============================================================================
REM Test 8: Run Basic Functionality Test
REM ==============================================================================

echo [TEST 8/8] Running basic functionality test...

if exist "%SERENA_EXE%" (
    "%SERENA_EXE%" --help >nul 2>&1
    if errorlevel 1 (
        echo   [FAIL] serena.exe --help failed
        set /a TESTS_FAILED+=1
    ) else (
        echo   [PASS] serena.exe --help successful
        set /a TESTS_PASSED+=1
    )
) else (
    echo   [SKIP] serena.exe not available
)

echo.

REM ==============================================================================
REM Summary
REM ==============================================================================

echo ================================================================================
echo   Verification Summary
echo ================================================================================
echo.
echo   Tests Passed:   %TESTS_PASSED%
echo   Tests Failed:   %TESTS_FAILED%
echo   Warnings:       %TESTS_WARNINGS%
echo.

if %TESTS_FAILED% GTR 0 (
    echo   [RESULT] Installation has CRITICAL ISSUES
    echo.
    echo   Recommended actions:
    echo     1. Re-download the Serena portable package
    echo     2. Run 'first-run.bat' to initialize setup
    echo     3. Check the logs in: %SERENA_HOME%\logs
    echo.
    exit /b 1
) else if %TESTS_WARNINGS% GTR 0 (
    echo   [RESULT] Installation is FUNCTIONAL with warnings
    echo.
    echo   Recommended actions:
    echo     1. Run 'first-run.bat' if not already done
    echo     2. Install missing runtimes if needed for your languages
    echo.
    exit /b 0
) else (
    echo   [RESULT] Installation is HEALTHY
    echo.
    echo   Serena Portable is ready to use!
    echo.
    exit /b 0
)
