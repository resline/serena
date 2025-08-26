@echo off
REM Batch file to run PowerShell line ending validation
REM This can be run on Windows systems to validate the PowerShell scripts

echo Running PowerShell Line Ending Validation...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0validate-powershell-line-endings.ps1" -Verbose

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: All PowerShell files are properly formatted!
    pause
    exit /b 0
) else (
    echo.
    echo ERROR: Some PowerShell files need attention.
    pause
    exit /b 1
)