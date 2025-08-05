@echo off
:: Serena MCP Quick Deploy for Corporate Windows 11
:: One-click deployment with automatic proxy/cert detection
:: Target: Under 15 minutes deployment

setlocal enabledelayedexpansion

echo ===============================================
echo  Serena MCP Corporate Quick Deploy
echo  Target: 15-minute deployment
echo ===============================================
echo.

:: Auto-detect corporate proxy
if defined HTTP_PROXY (
    set PROXY_URL=%HTTP_PROXY%
    echo [✓] Detected proxy: %HTTP_PROXY%
) else (
    :: Try to detect from registry
    for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "proxyserver"') do (
        set PROXY_URL=http://%%a
        echo [✓] Detected proxy from registry: http://%%a
    )
)

:: Auto-detect corporate certificates
set CA_CERT_PATH=
if exist "C:\Corporate\ca-bundle.crt" (
    set CA_CERT_PATH=C:\Corporate\ca-bundle.crt
    echo [✓] Found corporate certificate: C:\Corporate\ca-bundle.crt
) else if exist "C:\ProgramData\SSL\certs\ca-bundle.crt" (
    set CA_CERT_PATH=C:\ProgramData\SSL\certs\ca-bundle.crt
    echo [✓] Found corporate certificate: C:\ProgramData\SSL\certs\ca-bundle.crt
) else if defined REQUESTS_CA_BUNDLE (
    set CA_CERT_PATH=%REQUESTS_CA_BUNDLE%
    echo [✓] Using certificate from environment: %REQUESTS_CA_BUNDLE%
)

:: Deployment options
echo.
echo Select deployment method:
echo [1] Docker (Recommended - Isolated environment)
echo [2] Local installation
echo [3] Portable package (Pre-configured)
echo.
set /p DEPLOY_METHOD="Enter choice (1-3): "

:: IDE integration options
echo.
echo Select IDE integration:
echo [1] VS Code with Continue
echo [2] IntelliJ IDEA
echo [3] Both
echo [4] None
echo.
set /p IDE_CHOICE="Enter choice (1-4): "

:: Convert choices to parameters
if "%IDE_CHOICE%"=="1" set IDE_INTEGRATION=vscode
if "%IDE_CHOICE%"=="2" set IDE_INTEGRATION=intellij
if "%IDE_CHOICE%"=="3" set IDE_INTEGRATION=both
if "%IDE_CHOICE%"=="4" set IDE_INTEGRATION=none

:: Set installation path
set INSTALL_PATH=%USERPROFILE%\serena-mcp

:: Execute deployment
echo.
echo Starting deployment...
echo.

if "%DEPLOY_METHOD%"=="1" (
    :: Docker deployment
    powershell -ExecutionPolicy Bypass -File "%~dp0corporate-setup-windows.ps1" -UseDocker -ProxyUrl "%PROXY_URL%" -CaCertPath "%CA_CERT_PATH%" -IDEIntegration "%IDE_INTEGRATION%"
) else if "%DEPLOY_METHOD%"=="2" (
    :: Local installation
    powershell -ExecutionPolicy Bypass -File "%~dp0corporate-setup-windows.ps1" -ProxyUrl "%PROXY_URL%" -CaCertPath "%CA_CERT_PATH%" -IDEIntegration "%IDE_INTEGRATION%"
) else if "%DEPLOY_METHOD%"=="3" (
    :: Portable package
    echo Downloading portable package...
    call :download_portable
)

goto :end

:download_portable
:: Download pre-configured portable package
echo Downloading Serena portable package...
set PORTABLE_URL=https://github.com/oraios/serena/releases/download/latest/serena-portable-windows.zip

:: Create temp download with proxy support
powershell -Command ^
    "$proxy = New-Object System.Net.WebProxy('%PROXY_URL%'); ^
     $client = New-Object System.Net.WebClient; ^
     $client.Proxy = $proxy; ^
     $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials; ^
     $client.DownloadFile('%PORTABLE_URL%', '%TEMP%\serena-portable.zip')"

:: Extract to installation directory
echo Extracting package...
powershell -Command "Expand-Archive -Path '%TEMP%\serena-portable.zip' -DestinationPath '%INSTALL_PATH%' -Force"

:: Configure for corporate environment
echo @echo off > "%INSTALL_PATH%\set-corp-env.bat"
echo set HTTP_PROXY=%PROXY_URL% >> "%INSTALL_PATH%\set-corp-env.bat"
echo set HTTPS_PROXY=%PROXY_URL% >> "%INSTALL_PATH%\set-corp-env.bat"
echo set REQUESTS_CA_BUNDLE=%CA_CERT_PATH% >> "%INSTALL_PATH%\set-corp-env.bat"

:: Create run script
echo @echo off > "%INSTALL_PATH%\run-serena.bat"
echo call "%INSTALL_PATH%\set-corp-env.bat" >> "%INSTALL_PATH%\run-serena.bat"
echo "%INSTALL_PATH%\serena\serena-mcp-server.exe" %%* >> "%INSTALL_PATH%\run-serena.bat"

echo [✓] Portable package installed successfully!
goto :eof

:end
echo.
echo ===============================================
echo  Deployment complete!
echo  Check desktop for shortcuts
echo ===============================================
echo.
pause