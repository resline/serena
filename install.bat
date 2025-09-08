@echo off
rem ===========================================================================
rem Serena Agent - Windows Batch Installer
rem ===========================================================================
rem This script installs Serena Agent on Windows by:
rem - Checking administrator privileges
rem - Extracting Python embeddable package
rem - Creating virtual environment using embedded Python
rem - Installing all wheels from local directory
rem - Extracting language servers to %USERPROFILE%\.solidlsp\
rem - Setting up environment variables
rem - Creating desktop shortcuts for MCP server
rem - Registering Serena in PATH
rem - Showing installation progress
rem ===========================================================================

setlocal EnableDelayedExpansion

rem Set script variables
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "LOG_FILE=%SCRIPT_DIR%\install.log"
set "INSTALL_DIR=%USERPROFILE%\Serena"
set "PYTHON_DIR=%INSTALL_DIR%\python"
set "VENV_DIR=%INSTALL_DIR%\venv"
set "SOLIDLSP_DIR=%USERPROFILE%\.solidlsp"
set "WHEELS_DIR=%SCRIPT_DIR%\wheels"
set "LANGUAGE_SERVERS_DIR=%SCRIPT_DIR%\language_servers"
set "PYTHON_ZIP=%SCRIPT_DIR%\python-embeddable.zip"

rem Initialize log file
echo [%date% %time%] Starting Serena Agent installation > "%LOG_FILE%"
echo [%date% %time%] Script directory: %SCRIPT_DIR% >> "%LOG_FILE%"
echo [%date% %time%] Installation directory: %INSTALL_DIR% >> "%LOG_FILE%"

echo ===============================================
echo    Serena Agent - Windows Installation
echo ===============================================
echo.
echo This will install Serena Agent to: %INSTALL_DIR%
echo Log file: %LOG_FILE%
echo.

rem Check for administrator privileges
echo [%date% %time%] Checking administrator privileges... >> "%LOG_FILE%"
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Administrator privileges required for installation.
    echo Please run this script as Administrator.
    echo [%date% %time%] ERROR: Administrator privileges required >> "%LOG_FILE%"
    pause
    exit /b 1
)
echo Administrator privileges confirmed.
echo [%date% %time%] Administrator privileges confirmed >> "%LOG_FILE%"

rem Check system architecture
echo [%date% %time%] Checking system architecture... >> "%LOG_FILE%"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "ARCH=x64"
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "ARCH=ARM64"
) else (
    echo ERROR: Unsupported architecture: %PROCESSOR_ARCHITECTURE%
    echo [%date% %time%] ERROR: Unsupported architecture: %PROCESSOR_ARCHITECTURE% >> "%LOG_FILE%"
    pause
    exit /b 1
)
echo System architecture: %ARCH%
echo [%date% %time%] System architecture: %ARCH% >> "%LOG_FILE%"

rem Check Windows version
echo [%date% %time%] Checking Windows version... >> "%LOG_FILE%"
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
if "%VERSION%" lss "10.0" (
    echo WARNING: Windows 10 or later is recommended.
    echo Current version: %VERSION%
    echo [%date% %time%] WARNING: Windows version %VERSION% may not be fully supported >> "%LOG_FILE%"
)

rem Verify required files exist
echo [%date% %time%] Verifying required files... >> "%LOG_FILE%"
if not exist "%PYTHON_ZIP%" (
    echo ERROR: Python embeddable package not found: %PYTHON_ZIP%
    echo [%date% %time%] ERROR: Python embeddable package not found: %PYTHON_ZIP% >> "%LOG_FILE%"
    pause
    exit /b 1
)

if not exist "%WHEELS_DIR%" (
    echo ERROR: Wheels directory not found: %WHEELS_DIR%
    echo [%date% %time%] ERROR: Wheels directory not found: %WHEELS_DIR% >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo Required files verified.
echo [%date% %time%] Required files verified >> "%LOG_FILE%"

rem Create installation directory
echo [%date% %time%] Creating installation directory... >> "%LOG_FILE%"
if exist "%INSTALL_DIR%" (
    echo Removing existing installation...
    echo [%date% %time%] Removing existing installation: %INSTALL_DIR% >> "%LOG_FILE%"
    rmdir /s /q "%INSTALL_DIR%" 2>nul
)

mkdir "%INSTALL_DIR%" 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to create installation directory: %INSTALL_DIR%
    echo [%date% %time%] ERROR: Failed to create installation directory >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo Installation directory created: %INSTALL_DIR%
echo [%date% %time%] Installation directory created successfully >> "%LOG_FILE%"

rem Extract Python embeddable package
echo [%date% %time%] Extracting Python embeddable package... >> "%LOG_FILE%"
echo Extracting Python embeddable package...
powershell -Command "Expand-Archive -Path '%PYTHON_ZIP%' -DestinationPath '%PYTHON_DIR%' -Force" >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to extract Python embeddable package.
    echo [%date% %time%] ERROR: Failed to extract Python embeddable package >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo Python embeddable package extracted successfully.
echo [%date% %time%] Python embeddable package extracted successfully >> "%LOG_FILE%"

rem Enable site packages in Python embeddable
echo [%date% %time%] Configuring Python embeddable... >> "%LOG_FILE%"
set "PTH_FILE=%PYTHON_DIR%\python311._pth"
if exist "%PTH_FILE%" (
    powershell -Command "(Get-Content '%PTH_FILE%') -replace '^#import site', 'import site' | Set-Content '%PTH_FILE%'" >> "%LOG_FILE%" 2>&1
)

rem Install pip in embeddable Python
echo [%date% %time%] Installing pip... >> "%LOG_FILE%"
echo Installing pip...
"%PYTHON_DIR%\python.exe" -m ensurepip --upgrade >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Failed to install pip via ensurepip, trying get-pip.py...
    echo [%date% %time%] WARNING: ensurepip failed, trying get-pip.py >> "%LOG_FILE%"
    powershell -Command "Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%PYTHON_DIR%\get-pip.py'" >> "%LOG_FILE%" 2>&1
    "%PYTHON_DIR%\python.exe" "%PYTHON_DIR%\get-pip.py" >> "%LOG_FILE%" 2>&1
)

rem Create virtual environment
echo [%date% %time%] Creating virtual environment... >> "%LOG_FILE%"
echo Creating virtual environment...
"%PYTHON_DIR%\python.exe" -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to create virtual environment.
    echo [%date% %time%] ERROR: Failed to create virtual environment >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo Virtual environment created successfully.
echo [%date% %time%] Virtual environment created successfully >> "%LOG_FILE%"

rem Upgrade pip in virtual environment
echo [%date% %time%] Upgrading pip in virtual environment... >> "%LOG_FILE%"
echo Upgrading pip...
"%VENV_DIR%\Scripts\python.exe" -m pip install --upgrade pip >> "%LOG_FILE%" 2>&1

rem Install wheels from local directory
echo [%date% %time%] Installing wheels from local directory... >> "%LOG_FILE%"
echo Installing Serena Agent and dependencies...
echo This may take a few minutes...

set "WHEEL_COUNT=0"
for %%f in ("%WHEELS_DIR%\*.whl") do set /a WHEEL_COUNT+=1

set "CURRENT_WHEEL=0"
for %%f in ("%WHEELS_DIR%\*.whl") do (
    set /a CURRENT_WHEEL+=1
    echo Installing wheel !CURRENT_WHEEL!/%WHEEL_COUNT%: %%~nxf
    echo [%date% %time%] Installing wheel: %%f >> "%LOG_FILE%"
    "%VENV_DIR%\Scripts\pip.exe" install "%%f" --no-deps --force-reinstall >> "%LOG_FILE%" 2>&1
    if !errorlevel! neq 0 (
        echo WARNING: Failed to install wheel: %%~nxf
        echo [%date% %time%] WARNING: Failed to install wheel: %%f >> "%LOG_FILE%"
    )
)

echo Wheels installation completed.
echo [%date% %time%] Wheels installation completed >> "%LOG_FILE%"

rem Install any remaining dependencies
echo [%date% %time%] Installing remaining dependencies... >> "%LOG_FILE%"
echo Installing remaining dependencies...
"%VENV_DIR%\Scripts\pip.exe" install --upgrade setuptools wheel >> "%LOG_FILE%" 2>&1

rem Create solidlsp directory and extract language servers
echo [%date% %time%] Setting up language servers... >> "%LOG_FILE%"
if exist "%LANGUAGE_SERVERS_DIR%" (
    echo Setting up language servers...
    if not exist "%SOLIDLSP_DIR%" mkdir "%SOLIDLSP_DIR%"
    
    xcopy "%LANGUAGE_SERVERS_DIR%\*" "%SOLIDLSP_DIR%\" /s /e /i /y >> "%LOG_FILE%" 2>&1
    if %errorlevel% neq 0 (
        echo WARNING: Failed to copy some language server files.
        echo [%date% %time%] WARNING: Failed to copy language server files >> "%LOG_FILE%"
    ) else (
        echo Language servers extracted successfully.
        echo [%date% %time%] Language servers extracted successfully >> "%LOG_FILE%"
    )
) else (
    echo Language servers directory not found, skipping...
    echo [%date% %time%] Language servers directory not found, skipping >> "%LOG_FILE%"
)

rem Set up environment variables
echo [%date% %time%] Setting up environment variables... >> "%LOG_FILE%"
echo Setting up environment variables...

rem Add Serena to PATH
setx PATH "%PATH%;%VENV_DIR%\Scripts" /M >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Failed to add Serena to system PATH.
    echo [%date% %time%] WARNING: Failed to add to system PATH >> "%LOG_FILE%"
)

rem Set SERENA_HOME
setx SERENA_HOME "%INSTALL_DIR%" /M >> "%LOG_FILE%" 2>&1

rem Set SOLIDLSP_HOME
setx SOLIDLSP_HOME "%SOLIDLSP_DIR%" /M >> "%LOG_FILE%" 2>&1

echo Environment variables configured.
echo [%date% %time%] Environment variables configured >> "%LOG_FILE%"

rem Create desktop shortcuts
echo [%date% %time%] Creating desktop shortcuts... >> "%LOG_FILE%"
echo Creating desktop shortcuts...

set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT_VBS=%TEMP%\create_shortcut.vbs"

rem Create VBScript to create shortcuts
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%SHORTCUT_VBS%"
echo sLinkFile = "%DESKTOP%\Serena MCP Server.lnk" >> "%SHORTCUT_VBS%"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%SHORTCUT_VBS%"
echo oLink.TargetPath = "%VENV_DIR%\Scripts\serena-mcp-server.exe" >> "%SHORTCUT_VBS%"
echo oLink.WorkingDirectory = "%VENV_DIR%\Scripts" >> "%SHORTCUT_VBS%"
echo oLink.Description = "Serena MCP Server" >> "%SHORTCUT_VBS%"
echo oLink.Save >> "%SHORTCUT_VBS%"

cscript //nologo "%SHORTCUT_VBS%" >> "%LOG_FILE%" 2>&1
del "%SHORTCUT_VBS%" 2>nul

echo Desktop shortcuts created.
echo [%date% %time%] Desktop shortcuts created >> "%LOG_FILE%"

rem Create Start Menu entry
echo [%date% %time%] Creating Start Menu entry... >> "%LOG_FILE%"
set "START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if not exist "%START_MENU%\Serena Agent" mkdir "%START_MENU%\Serena Agent"

echo Set oWS = WScript.CreateObject("WScript.Shell") > "%SHORTCUT_VBS%"
echo sLinkFile = "%START_MENU%\Serena Agent\Serena MCP Server.lnk" >> "%SHORTCUT_VBS%"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%SHORTCUT_VBS%"
echo oLink.TargetPath = "%VENV_DIR%\Scripts\serena-mcp-server.exe" >> "%SHORTCUT_VBS%"
echo oLink.WorkingDirectory = "%VENV_DIR%\Scripts" >> "%SHORTCUT_VBS%"
echo oLink.Description = "Serena MCP Server" >> "%SHORTCUT_VBS%"
echo oLink.Save >> "%SHORTCUT_VBS%"

cscript //nologo "%SHORTCUT_VBS%" >> "%LOG_FILE%" 2>&1
del "%SHORTCUT_VBS%" 2>nul

echo Start Menu entries created.
echo [%date% %time%] Start Menu entries created >> "%LOG_FILE%"

rem Verify installation
echo [%date% %time%] Verifying installation... >> "%LOG_FILE%"
echo Verifying installation...

"%VENV_DIR%\Scripts\python.exe" -c "import serena; print('Serena Agent installed successfully')" >> "%LOG_FILE%" 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Installation verification failed.
    echo [%date% %time%] ERROR: Installation verification failed >> "%LOG_FILE%"
    echo Please check the log file for details: %LOG_FILE%
    pause
    exit /b 1
)

rem Test serena command
"%VENV_DIR%\Scripts\serena.exe" --help >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Serena command test failed.
    echo [%date% %time%] WARNING: Serena command test failed >> "%LOG_FILE%"
)

echo [%date% %time%] Installation completed successfully >> "%LOG_FILE%"

echo.
echo ===============================================
echo    Installation Completed Successfully!
echo ===============================================
echo.
echo Serena Agent has been installed to: %INSTALL_DIR%
echo.
echo Environment Variables Set:
echo   SERENA_HOME=%INSTALL_DIR%
echo   SOLIDLSP_HOME=%SOLIDLSP_DIR%
echo   PATH updated to include Serena commands
echo.
echo Available Commands:
echo   serena                - Main Serena CLI
echo   serena-mcp-server     - Start MCP server
echo   index-project         - Index project for faster performance
echo.
echo Desktop shortcuts and Start Menu entries have been created.
echo.
echo IMPORTANT: Please restart your command prompt or PowerShell
echo            to use the updated PATH environment variable.
echo.
echo Installation log: %LOG_FILE%
echo.
pause