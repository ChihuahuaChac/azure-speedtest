@echo off
setlocal

:: ================================================================
:: Azure Blob Download Speed Test (Windows + azcopy) - Single File
:: Downloads azcopy + runner script, then executes
:: Usage: speedtest_azcopy.bat [runs]
:: ================================================================

set RUNS=%1
if "%RUNS%"=="" set RUNS=3

set "SCRIPTDIR=%~dp0"
set "AZCOPY_DIR=%SCRIPTDIR%azcopy"
set "AZCOPY_EXE=%AZCOPY_DIR%\azcopy.exe"
set "TMPDIR=%TEMP%\azspeedtest"
set "RUNNER=%TMPDIR%\speedtest_runner.ps1"

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

:: --- Download azcopy if not found ---
if exist "%AZCOPY_EXE%" goto :have_azcopy

echo [INFO] azcopy not found, downloading...
set "AZCOPY_ZIP=%TMPDIR%\azcopy.zip"
curl -L -o "%AZCOPY_ZIP%" "https://aka.ms/downloadazcopy-v10-windows"
if errorlevel 1 (
    echo [ERROR] Failed to download azcopy. Try: winget install Microsoft.AzCopy
    exit /b 1
)
mkdir "%AZCOPY_DIR%" 2>nul
powershell -NoProfile -Command "Expand-Archive -Path '%AZCOPY_ZIP%' -DestinationPath '%TMPDIR%\azcopy_extract' -Force"
for /r "%TMPDIR%\azcopy_extract" %%f in (azcopy.exe) do copy "%%f" "%AZCOPY_EXE%" >nul
del "%AZCOPY_ZIP%" 2>nul
rmdir /s /q "%TMPDIR%\azcopy_extract" 2>nul
if not exist "%AZCOPY_EXE%" (
    echo [ERROR] Could not find azcopy.exe after extraction.
    exit /b 1
)
echo [OK] azcopy installed: %AZCOPY_EXE%

:have_azcopy
:: --- Download runner ps1 and execute ---
echo [INFO] Downloading test runner...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/ChihuahuaChac/azure-speedtest/main/speedtest_runner.ps1' -OutFile '%RUNNER%' -UseBasicParsing"
if not exist "%RUNNER%" (
    echo [ERROR] Failed to download speedtest_runner.ps1
    exit /b 1
)

:: --- Run (use . to mean current dir if SCRIPTDIR has trailing backslash issues) ---
set "SCRIPTDIR_CLEAN=%SCRIPTDIR:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -Runs %RUNS% -AzCopyExe "%AZCOPY_EXE%" -ScriptDir "%SCRIPTDIR_CLEAN%"

:: --- Cleanup ---
rmdir /s /q "%TMPDIR%" 2>nul
