@echo off
setlocal enabledelayedexpansion

:: ================================================================
:: Azure Blob Download Speed Test (Windows + azcopy)
:: All logic runs in PowerShell to avoid cmd % expansion issues
:: Usage: speedtest_azcopy.bat [runs]
:: ================================================================

set RUNS=%1
if "%RUNS%"=="" set RUNS=3

set "SCRIPTDIR=%~dp0"
set "AZCOPY_DIR=%SCRIPTDIR%azcopy"
set "AZCOPY_EXE=%AZCOPY_DIR%\azcopy.exe"
set "TMPDIR=%TEMP%\azspeedtest"

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

:: --- Download azcopy if not found ---
if exist "%AZCOPY_EXE%" goto :run_test

echo [INFO] azcopy not found, downloading...
set "AZCOPY_ZIP=%TMPDIR%\azcopy.zip"
curl -L -o "%AZCOPY_ZIP%" "https://aka.ms/downloadazcopy-v10-windows"
if errorlevel 1 (
    echo [ERROR] Failed to download azcopy.
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

:run_test
:: --- Execute test via PowerShell (avoids all cmd escaping issues) ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "$runs=%RUNS%; $azcopy='%AZCOPY_EXE%'; $scriptDir='%SCRIPTDIR%'; & '%SCRIPTDIR%speedtest_runner.ps1' -Runs $runs -AzCopyExe $azcopy -ScriptDir $scriptDir"

rmdir /s /q "%TMPDIR%" 2>nul
