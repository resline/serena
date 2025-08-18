@echo off
setlocal enabledelayedexpansion

:: Offline Dependencies Installer for Serena MCP Portable
:: This script installs all Python dependencies from local wheels
:: Version: 1.0

echo ==========================================
echo  Serena MCP - Offline Dependencies
echo  Installing from local wheels...
echo ==========================================
echo.

:: Detect script location
set SCRIPT_DIR=%~dp0
set SERENA_PORTABLE=%SCRIPT_DIR%..
set DEPENDENCIES_DIR=%SCRIPT_DIR%

:: Set Python paths
set PYTHONHOME=%SERENA_PORTABLE%\python
set PYTHONPATH=%SERENA_PORTABLE%\Lib\site-packages;%SERENA_PORTABLE%\serena\src
set PATH=%PYTHONHOME%;%PYTHONHOME%\Scripts;%PATH%

echo [INFO] Script directory: %SCRIPT_DIR%
echo [INFO] Serena portable: %SERENA_PORTABLE%
echo [INFO] Python home: %PYTHONHOME%
echo [INFO] Dependencies: %DEPENDENCIES_DIR%
echo.

:: Verify Python is available
if not exist "%PYTHONHOME%\python.exe" (
    echo [ERROR] Python not found at: %PYTHONHOME%\python.exe
    echo [ERROR] Please ensure the portable package is complete
    goto :error
)

:: Test Python
echo [INFO] Testing Python installation...
"%PYTHONHOME%\python.exe" --version
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python test failed
    goto :error
)
echo [OK] Python is working
echo.

:: Create target directory
if not exist "%SERENA_PORTABLE%\Lib\site-packages" (
    echo [INFO] Creating site-packages directory...
    mkdir "%SERENA_PORTABLE%\Lib\site-packages"
)

:: Install UV first (if available)
echo [INFO] Installing UV...
if exist "%DEPENDENCIES_DIR%\uv-deps" (
    echo [INFO] Found UV dependencies, installing offline...
    "%PYTHONHOME%\python.exe" -m pip install --no-index --find-links "%DEPENDENCIES_DIR%\uv-deps" --target "%SERENA_PORTABLE%\Lib\site-packages" uv
    if %ERRORLEVEL% equ 0 (
        echo [OK] UV installed successfully
    ) else (
        echo [WARN] UV installation failed, continuing without UV
    )
) else (
    echo [WARN] UV dependencies not found in offline package
)
echo.

:: Check if requirements.txt exists
if not exist "%DEPENDENCIES_DIR%\requirements.txt" (
    echo [ERROR] requirements.txt not found at: %DEPENDENCIES_DIR%\requirements.txt
    echo [ERROR] This may not be a complete offline package
    goto :error
)

:: Count available wheels
for /f %%i in ('dir /b "%DEPENDENCIES_DIR%\*.whl" 2^>nul ^| find /c /v ""') do set WHEEL_COUNT=%%i
if %WHEEL_COUNT% equ 0 (
    echo [ERROR] No wheel files found in dependencies directory
    echo [ERROR] This package may be incomplete or corrupted
    goto :error
)

echo [INFO] Found %WHEEL_COUNT% wheel files for installation
echo.

:: Install main dependencies from wheels
echo [INFO] Installing Serena dependencies from wheels...
echo [INFO] This may take a few minutes...
echo.

"%PYTHONHOME%\python.exe" -m pip install ^
    --no-index ^
    --find-links "%DEPENDENCIES_DIR%" ^
    --target "%SERENA_PORTABLE%\Lib\site-packages" ^
    --requirement "%DEPENDENCIES_DIR%\requirements.txt" ^
    --force-reinstall

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install dependencies from wheels
    echo [ERROR] Check the error messages above
    goto :error
)

echo.
echo [OK] Dependencies installed successfully!
echo.

:: Verify critical imports
echo [INFO] Verifying installation...
set VERIFICATION_FAILED=0

:: Test critical packages
set TEST_PACKAGES=requests mcp flask pydantic pyyaml

for %%p in (%TEST_PACKAGES%) do (
    echo Testing %%p...
    "%PYTHONHOME%\python.exe" -c "import %%p; print('  ✓ %%p:', %%p.__version__ if hasattr(%%p, '__version__') else 'OK')" 2>nul
    if !ERRORLEVEL! neq 0 (
        echo   ✗ %%p: Import failed
        set VERIFICATION_FAILED=1
    )
)

:: Test Serena specifically
echo Testing Serena...
"%PYTHONHOME%\python.exe" -c "import serena; print('  ✓ Serena: Available')" 2>nul
if %ERRORLEVEL% neq 0 (
    echo   ✗ Serena: Import failed
    set VERIFICATION_FAILED=1
)

echo.

if %VERIFICATION_FAILED% equ 1 (
    echo [WARN] Some packages failed verification
    echo [WARN] Serena may still work, but some features might be unavailable
    echo [INFO] You can try running Serena to see if it works
    echo.
    echo Continue anyway? (Y/N)
    choice /c YN /n
    if !ERRORLEVEL! equ 2 goto :error
) else (
    echo [OK] All packages verified successfully!
)

:: Create installation marker
echo %DATE% %TIME% > "%SERENA_PORTABLE%\.dependencies-installed"

echo.
echo ==========================================
echo  Installation Complete!
echo ==========================================
echo.
echo ✅ All dependencies installed offline
echo ✅ Serena MCP is ready to use
echo ✅ No internet connection required
echo.
echo Next steps:
echo 1. Run serena-mcp-portable.bat to start
echo 2. Use check-dependencies.bat to verify
echo 3. Configure your IDE integration
echo.
pause
exit /b 0

:error
echo.
echo ==========================================
echo  Installation Failed!
echo ==========================================
echo.
echo ❌ Offline dependency installation failed
echo.
echo Possible solutions:
echo 1. Ensure this is a complete offline package
echo 2. Check if dependencies\ folder contains .whl files
echo 3. Verify Python embedded is working
echo 4. Try downloading a fresh portable package
echo.
echo For support, see: https://github.com/resline/serena
echo.
pause
exit /b 1