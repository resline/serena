@echo off
REM ============================================================================
REM Serena Installation Verification Script (Batch)
REM ============================================================================
REM This script performs health checks on the Serena portable installation:
REM - Verifies all executables exist
REM - Checks language server availability
REM - Tests serena --version command
REM - Checks disk space
REM - Reports overall installation status
REM
REM Usage: verify-installation.bat
REM Exit code: 0 = success, 1 = failure
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================================
echo Serena Installation Verification
echo ============================================================================
echo.

REM Detect the installation directory
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%A in ("%SCRIPT_DIR%\..\..") do set "INSTALL_DIR=%%~fA"

REM Set environment variables
set "SERENA_PORTABLE=1"
set "SERENA_HOME=%INSTALL_DIR%"
set "PATH=%INSTALL_DIR%\runtimes\nodejs;%PATH%"
set "PATH=%INSTALL_DIR%\runtimes\dotnet;%PATH%"
set "PATH=%INSTALL_DIR%\runtimes\java\bin;%PATH%"
set "JAVA_HOME=%INSTALL_DIR%\runtimes\java"
set "DOTNET_ROOT=%INSTALL_DIR%\runtimes\dotnet"
set "NODE_PATH=%INSTALL_DIR%\runtimes\nodejs\node_modules"

echo Installation directory: %INSTALL_DIR%
echo.

set "ERRORS=0"
set "WARNINGS=0"

REM Check executables
echo [1/5] Checking executables...
set "EXECUTABLES=bin\serena.exe bin\serena-mcp-server.exe bin\index-project.exe"
for %%E in (%EXECUTABLES%) do (
    if exist "%INSTALL_DIR%\%%E" (
        echo       [OK] %%E
    ) else (
        echo       [ERROR] Missing: %%E
        set /a ERRORS+=1
    )
)
echo.

REM Check runtime directories
echo [2/5] Checking language runtimes...
set "RUNTIMES=runtimes\nodejs runtimes\dotnet runtimes\java"
for %%R in (%RUNTIMES%) do (
    if exist "%INSTALL_DIR%\%%R" (
        echo       [OK] %%R
    ) else (
        echo       [WARNING] Missing: %%R
        set /a WARNINGS+=1
    )
)
echo.

REM Check language servers
echo [3/5] Checking language servers...
set "LS_DIR=%INSTALL_DIR%\language_servers"
if exist "%LS_DIR%" (
    dir /b /a:d "%LS_DIR%" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        for /f %%L in ('dir /b /a:d "%LS_DIR%" 2^>nul ^| find /c /v ""') do set "LS_COUNT=%%L"
        echo       [OK] Found !LS_COUNT! language server(s)
        REM List first few language servers
        set "COUNT=0"
        for /f "delims=" %%L in ('dir /b /a:d "%LS_DIR%" 2^>nul') do (
            if !COUNT! lss 5 (
                echo            - %%L
                set /a COUNT+=1
            )
        )
        if !COUNT! lss !LS_COUNT! (
            set /a REMAINING=!LS_COUNT!-!COUNT!
            echo            ... and !REMAINING! more
        )
    ) else (
        echo       [WARNING] No language servers found
        set /a WARNINGS+=1
    )
) else (
    echo       [WARNING] Language servers directory not found
    set /a WARNINGS+=1
)
echo.

REM Test serena command
echo [4/5] Testing serena executable...
set "SERENA_EXE=%INSTALL_DIR%\bin\serena.exe"
if exist "%SERENA_EXE%" (
    "%SERENA_EXE%" --version >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo       [OK] serena.exe runs successfully
        for /f "delims=" %%V in ('"%SERENA_EXE%" --version 2^>nul') do (
            echo            Version: %%V
            goto :version_done
        )
        :version_done
    ) else (
        echo       [ERROR] serena.exe failed to execute
        set /a ERRORS+=1
    )
) else (
    echo       [ERROR] serena.exe not found
    set /a ERRORS+=1
)
echo.

REM Check disk space (if available)
echo [5/5] Checking disk space...
for /f "tokens=3" %%A in ('dir /-c "%INSTALL_DIR%" ^| find "bytes free"') do set "FREE_SPACE=%%A"
if defined FREE_SPACE (
    echo       [OK] Free space available
) else (
    echo       [WARNING] Could not determine free space
    set /a WARNINGS+=1
)
echo.

REM Summary
echo ============================================================================
echo Verification Summary
echo ============================================================================
if %ERRORS% equ 0 (
    if %WARNINGS% equ 0 (
        echo [SUCCESS] Installation is complete and healthy
        echo.
        echo You can now use Serena:
        echo   serena.bat --version
        echo   serena.bat --help
        echo   serena-mcp-server.bat --help
        echo.
        exit /b 0
    ) else (
        echo [WARNING] Installation is functional but has %WARNINGS% warning(s)
        echo Please review the warnings above.
        echo.
        exit /b 0
    )
) else (
    echo [FAILED] Installation has %ERRORS% error(s) and %WARNINGS% warning(s)
    echo Please review the errors above and reinstall if necessary.
    echo.
    exit /b 1
)
