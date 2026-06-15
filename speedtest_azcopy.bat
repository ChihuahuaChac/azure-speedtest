@echo off
setlocal enabledelayedexpansion

:: ================================================================
:: Azure Blob Download Speed Test (Windows + azcopy)
:: - Auto-downloads azcopy if not found
:: - Full file download, reports real throughput
:: Usage: speedtest_azcopy.bat [runs]
:: ================================================================

set RUNS=%1
if "%RUNS%"=="" set RUNS=3

:: --- Timestamp via powershell (wmic removed on new Windows) ---
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

:: --- Write result header ---
(
echo ================================================================
echo  Azure Blob Download Speed Test [azcopy]
echo  Date: %DT%
echo  Host: %COMPUTERNAME%
echo  azcopy: %AZCOPY_VER%
echo  Runs: %RUNS% per endpoint
echo ================================================================
echo.
) > "%RESULT%"

:: ================================================================
:: TEST: US South Central [Texas] - 100MB
:: ================================================================
echo ---- US South Central [Texas] ----
echo.>> "%RESULT%"
echo ---- US South Central [Texas] ---->> "%RESULT%"
echo.>> "%RESULT%"
echo   [US-100MB] (100 MB)
echo   [US-100MB] (100 MB)>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    echo     Run %%i ...
    set "DEST=%TMPDIR%\us100_%%i.bin"
    set "LOG=%TMPDIR%\us100_%%i.log"
    "%AZCOPY_EXE%" copy "https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=kBZI7oM5aRX0zoswSAXOoJG615yV%2FoCSWcHrdBq9eCg%3D" "!DEST!" --output-type text --log-level NONE > "!LOG!" 2>&1
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
:: TEST: US South Central [Texas] - 500MB
:: ================================================================
echo.
echo   [US-500MB] (500 MB)
echo   [US-500MB] (500 MB)>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    echo     Run %%i ...
    set "DEST=%TMPDIR%\us500_%%i.bin"
    set "LOG=%TMPDIR%\us500_%%i.log"
    "%AZCOPY_EXE%" copy "https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=Vg8Gg3r8TUkC1317Q9SRIsnss%2Bu%2FXu4zL2LxLLogRIc%3D" "!DEST!" --output-type text --log-level NONE > "!LOG!" 2>&1
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
:: TEST: Mexico Central [Queretaro] - 100MB
:: ================================================================
echo.
echo ---- Mexico Central [Queretaro] ----
echo.>> "%RESULT%"
echo ---- Mexico Central [Queretaro] ---->> "%RESULT%"
echo.>> "%RESULT%"
echo   [MX-100MB] (100 MB)
echo   [MX-100MB] (100 MB)>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    echo     Run %%i ...
    set "DEST=%TMPDIR%\mx100_%%i.bin"
    set "LOG=%TMPDIR%\mx100_%%i.log"
    "%AZCOPY_EXE%" copy "https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=qnxTNeXWs%2BnMkJ%2By5ltN9SfvFvHyRS7ywpetNefvMU4%3D" "!DEST!" --output-type text --log-level NONE > "!LOG!" 2>&1
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
:: TEST: Mexico Central [Queretaro] - 500MB
:: ================================================================
echo.
echo   [MX-500MB] (500 MB)
echo   [MX-500MB] (500 MB)>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    echo     Run %%i ...
    set "DEST=%TMPDIR%\mx500_%%i.bin"
    set "LOG=%TMPDIR%\mx500_%%i.log"
    "%AZCOPY_EXE%" copy "https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=hgAS7LnpEKS3X8vRiDRaX9EqZyvGlcMsNnYwb47NzKw%3D" "!DEST!" --output-type text --log-level NONE > "!LOG!" 2>&1
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
