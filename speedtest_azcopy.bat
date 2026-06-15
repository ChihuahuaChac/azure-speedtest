@echo off
setlocal enabledelayedexpansion

:: ================================================================
:: Azure Blob Download Speed Test (Windows + azcopy)
:: - Auto-downloads azcopy if not found
:: - Full file download, reports real throughput
:: - Region: US South Central (Texas)
:: Usage: speedtest_azcopy.bat [runs]
:: ================================================================

set RUNS=%1
if "%RUNS%"=="" set RUNS=3

for /f "tokens=*" %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%d"
for /f "tokens=*" %%d in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "DT=%%d"

set "SCRIPTDIR=%~dp0"
set "AZCOPY_DIR=%SCRIPTDIR%azcopy"
set "AZCOPY_EXE=%AZCOPY_DIR%\azcopy.exe"
set "TMPDIR=%TEMP%\azspeedtest"
set "RESULT=%SCRIPTDIR%speedtest_%TS%.txt"

if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo.
echo ================================================================
echo   Azure Blob Download Speed Test (azcopy)
echo   Date: %DT%
echo   Host: %COMPUTERNAME%
echo   Runs: %RUNS% per endpoint
echo   Results: %RESULT%
echo ================================================================
echo.

:: --- Download azcopy if not found ---
if exist "%AZCOPY_EXE%" (
    echo [OK] azcopy found: %AZCOPY_EXE%
    goto :azcopy_ready
)

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

:azcopy_ready
for /f "tokens=*" %%v in ('"%AZCOPY_EXE%" --version 2^>^&1') do set "AZCOPY_VER=%%v"
echo      %AZCOPY_VER%
echo.

(
echo ================================================================
echo  Azure Blob Download Speed Test [azcopy]
echo  Date: %DT%
echo  Host: %COMPUTERNAME%
echo  azcopy: %AZCOPY_VER%
echo  Runs: %RUNS% per endpoint
echo  Region: US South Central (Texas)
echo ================================================================
echo.
) > "%RESULT%"

:: ================================================================
:: US South Central - 100MB
:: ================================================================
echo ---- US South Central [Texas] ----
echo.>> "%RESULT%"
echo ---- US South Central [Texas] ---->> "%RESULT%"
echo.>> "%RESULT%"
echo   [100MB]
echo   [100MB]>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    echo     Run %%i ...
    set "DEST=%TMPDIR%\us100_%%i.bin"
    set "LOG=%TMPDIR%\us100_%%i.log"
    "%AZCOPY_EXE%" copy "https://chacspeedtest.blob.core.windows.net/speedtest/100M.bin?se=2026-06-22T08%3A29Z&sp=r&sv=2026-04-06&sr=b&skoid=0144ac18-a824-4f96-b045-e5c9fd4f49c7&sktid=3f0ca837-5d5d-4d8a-84fa-555d252985a0&skt=2026-06-15T08%3A29%3A05Z&ske=2026-06-22T08%3A29%3A00Z&sks=b&skv=2026-04-06&sig=yjdnMBxRaVf0KnZHQhTiUtOeXVWLgsXti9egjK2PXoI%3D" "!DEST!" --output-type text --log-level NONE > "!LOG!" 2>&1
    set "MBPS=FAILED"
    set "DLMB=0"
    if exist "!DEST!" for /f %%s in ('powershell -NoProfile -Command "[math]::Round((Get-Item '!DEST!').Length/1MB,1)"') do set "DLMB=%%s"
    for /f "tokens=*" %%L in ('findstr /i "Throughput" "!LOG!" 2^>nul') do (
        for /f "tokens=4" %%n in ("%%L") do set "MBPS=%%n"
    )
    set "LINE=   Run %%i: !MBPS! Mb/s | Downloaded: !DLMB! MB"
    echo !LINE!
    echo !LINE!>> "%RESULT%"
    del "!DEST!" 2>nul
    del "!LOG!" 2>nul
    if %%i LSS %RUNS% timeout /t 2 /nobreak >nul
)
echo.>> "%RESULT%"

:: ================================================================
:: US South Central - 500MB
:: ================================================================
echo.
echo   [500MB]
echo   [500MB]>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    echo     Run %%i ...
    set "DEST=%TMPDIR%\us500_%%i.bin"
    set "LOG=%TMPDIR%\us500_%%i.log"
    "%AZCOPY_EXE%" copy "https://chacspeedtest.blob.core.windows.net/speedtest/500M.bin?se=2026-06-22T08%3A29Z&sp=r&sv=2026-04-06&sr=b&skoid=0144ac18-a824-4f96-b045-e5c9fd4f49c7&sktid=3f0ca837-5d5d-4d8a-84fa-555d252985a0&skt=2026-06-15T08%3A29%3A06Z&ske=2026-06-22T08%3A29%3A00Z&sks=b&skv=2026-04-06&sig=ygVzA7IeP%2Boyv%2F0c7GEHdL4puKG9eno%2FrdGR%2BW9d6G0%3D" "!DEST!" --output-type text --log-level NONE > "!LOG!" 2>&1
    set "MBPS=FAILED"
    set "DLMB=0"
    if exist "!DEST!" for /f %%s in ('powershell -NoProfile -Command "[math]::Round((Get-Item '!DEST!').Length/1MB,1)"') do set "DLMB=%%s"
    for /f "tokens=*" %%L in ('findstr /i "Throughput" "!LOG!" 2^>nul') do (
        for /f "tokens=4" %%n in ("%%L") do set "MBPS=%%n"
    )
    set "LINE=   Run %%i: !MBPS! Mb/s | Downloaded: !DLMB! MB"
    echo !LINE!
    echo !LINE!>> "%RESULT%"
    del "!DEST!" 2>nul
    del "!LOG!" 2>nul
    if %%i LSS %RUNS% timeout /t 2 /nobreak >nul
)
echo.>> "%RESULT%"

:: --- Done ---
rmdir /s /q "%TMPDIR%" 2>nul
echo.
echo ================================================================
echo   Done! Results: %RESULT%
echo ================================================================
echo.
type "%RESULT%"
