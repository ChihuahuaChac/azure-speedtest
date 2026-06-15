@echo off
setlocal enabledelayedexpansion

:: ================================================================
:: Azure Blob Download Speed Test (Windows + azcopy)
:: - Auto-downloads azcopy if not found
:: - Measures real throughput (full file download)
:: Usage: speedtest_azcopy.bat [runs]
:: Example: speedtest_azcopy.bat
::          speedtest_azcopy.bat 5
:: ================================================================

set RUNS=%1
if "%RUNS%"=="" set RUNS=3

:: --- Timestamp (powershell, works on all Windows 10/11) ---
for /f "tokens=*" %%d in ('powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set "TIMESTAMP=%%d"
for /f "tokens=*" %%d in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "DATETIME=%%d"

:: --- SAS URLs (valid until 2027-06-10) ---
set "US_100M=https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=kBZI7oM5aRX0zoswSAXOoJG615yV%%2FoCSWcHrdBq9eCg%%3D"
set "US_500M=https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=Vg8Gg3r8TUkC1317Q9SRIsnss%%2Bu%%2FXu4zL2LxLLogRIc%%3D"
set "MX_100M=https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=qnxTNeXWs%%2BnMkJ%%2By5ltN9SfvFvHyRS7ywpetNefvMU4%%3D"
set "MX_500M=https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=hgAS7LnpEKS3X8vRiDRaX9EqZyvGlcMsNnYwb47NzKw%%3D"

:: --- Setup paths ---
set "SCRIPTDIR=%~dp0"
set "AZCOPY_DIR=%SCRIPTDIR%azcopy"
set "AZCOPY_EXE=%AZCOPY_DIR%\azcopy.exe"
set "TMPDIR=%TEMP%\azspeedtest"
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

:: --- Result file ---
set "RESULT=%SCRIPTDIR%speedtest_%TIMESTAMP%.txt"

echo.
echo ================================================================
echo   Azure Blob Download Speed Test (azcopy)
echo   Date: %DATETIME%
echo   Host: %COMPUTERNAME%
echo   Runs: %RUNS% per endpoint
echo   Results: %RESULT%
echo ================================================================
echo.

:: --- Check / Download azcopy ---
if exist "%AZCOPY_EXE%" (
    echo [OK] azcopy found: %AZCOPY_EXE%
    goto :azcopy_ready
)

echo [INFO] azcopy not found, downloading...
echo.

set "AZCOPY_ZIP=%TMPDIR%\azcopy.zip"

:: Download using curl
curl -L -o "%AZCOPY_ZIP%" "https://aka.ms/downloadazcopy-v10-windows"
if errorlevel 1 (
    echo [ERROR] Failed to download azcopy. Check network.
    exit /b 1
)

:: Extract using powershell
mkdir "%AZCOPY_DIR%" 2>nul
powershell -NoProfile -Command "Expand-Archive -Path '%AZCOPY_ZIP%' -DestinationPath '%TMPDIR%\azcopy_extract' -Force"
if errorlevel 1 (
    echo [ERROR] Failed to extract azcopy zip.
    exit /b 1
)

:: Find azcopy.exe (nested in version subfolder)
for /r "%TMPDIR%\azcopy_extract" %%f in (azcopy.exe) do (
    copy "%%f" "%AZCOPY_EXE%" >nul
)

:: Cleanup zip
del "%AZCOPY_ZIP%" 2>nul
rmdir /s /q "%TMPDIR%\azcopy_extract" 2>nul

if not exist "%AZCOPY_EXE%" (
    echo [ERROR] Could not find azcopy.exe after extraction.
    exit /b 1
)
echo [OK] azcopy installed to: %AZCOPY_EXE%

:azcopy_ready

:: --- Show azcopy version ---
set "AZCOPY_VER="
for /f "tokens=*" %%v in ('"%AZCOPY_EXE%" --version 2^>^&1') do set "AZCOPY_VER=%%v"
echo      %AZCOPY_VER%
echo.

:: --- Write header ---
(
echo ================================================================
echo  Azure Blob Download Speed Test [azcopy]
echo  Date: %DATETIME%
echo  Host: %COMPUTERNAME%
echo  azcopy: %AZCOPY_VER%
echo  Runs: %RUNS% per endpoint
echo ================================================================
echo.
) > "%RESULT%"

:: --- Run tests ---
echo.
echo ---- US South Central [Texas] ----
echo.>> "%RESULT%"
echo ---- US South Central [Texas] ---->> "%RESULT%"
echo.>> "%RESULT%"
call :runtest "US-100MB" 100 "%US_100M%"
call :runtest "US-500MB" 500 "%US_500M%"

echo.
echo ---- Mexico Central [Queretaro] ----
echo.>> "%RESULT%"
echo ---- Mexico Central [Queretaro] ---->> "%RESULT%"
echo.>> "%RESULT%"
call :runtest "MX-100MB" 100 "%MX_100M%"
call :runtest "MX-500MB" 500 "%MX_500M%"

:: --- Cleanup temp ---
rmdir /s /q "%TMPDIR%" 2>nul

:: --- Done ---
echo.
echo ================================================================
echo   Done! Results saved to: %RESULT%
echo ================================================================
echo.
echo --- Full Results ---
echo.
type "%RESULT%"
goto :eof

:: ===============================================================
:runtest
set "LABEL=%~1"
set "SIZEMB=%~2"
set "URL=%~3"

echo.
echo   [%LABEL%] (%SIZEMB% MB)
echo   [%LABEL%] (%SIZEMB% MB)>> "%RESULT%"

for /L %%i in (1,1,%RUNS%) do (
    set "DEST=%TMPDIR%\test_%%i.bin"
    set "LOGFILE=%TMPDIR%\azcopy_log_%%i.txt"

    echo     Run %%i ...

    :: Run azcopy copy
    "%AZCOPY_EXE%" copy "%URL%" "!DEST!" --output-type text --log-level NONE > "!LOGFILE!" 2>&1

    :: Parse throughput from azcopy summary output
    set "MBPS="
    set "ELAPSED="
    set "BYTES="

    for /f "tokens=*" %%L in ('findstr /i "Throughput" "!LOGFILE!" 2^>nul') do (
        :: Line looks like: "Throughput (Mb/s): 123.45"
        for /f "tokens=4 delims= " %%n in ("%%L") do set "MBPS=%%n"
    )
    for /f "tokens=*" %%L in ('findstr /i "Elapsed Time" "!LOGFILE!" 2^>nul') do (
        for /f "tokens=4-99 delims= " %%a in ("%%L") do set "ELAPSED=%%a %%b"
    )
    for /f "tokens=*" %%L in ('findstr /i "TotalBytesTransferred" "!LOGFILE!" 2^>nul') do (
        for /f "tokens=2 delims=:" %%b in ("%%L") do set "BYTES=%%b"
    )

    :: Verify file size
    set "DLSIZE=0"
    if exist "!DEST!" (
        for /f %%s in ('powershell -NoProfile -Command "[math]::Round((Get-Item '!DEST!').Length/1MB,1)"') do set "DLSIZE=%%s"
    )

    :: If azcopy didn't output throughput, calculate manually
    if "!MBPS!"=="" (
        if !DLSIZE! GTR 0 (
            for /f %%c in ('powershell -NoProfile -Command "$sw=[IO.File]::GetLastWriteTime('!LOGFILE!')-[IO.File]::GetCreationTime('!LOGFILE!'); if($sw.TotalSeconds -gt 0){[math]::Round(!SIZEMB!*8/$sw.TotalSeconds,2)}else{'N/A'}"') do set "MBPS=%%c"
        ) else (
            set "MBPS=FAILED"
        )
    )

    set "LINE=   Run %%i: !MBPS! Mb/s | Downloaded: !DLSIZE! MB | Elapsed: !ELAPSED!"
    echo !LINE!
    echo !LINE!>> "%RESULT%"

    :: Cleanup between runs
    del "!DEST!" 2>nul
    del "!LOGFILE!" 2>nul

    :: Brief pause
    if %%i LSS %RUNS% timeout /t 2 /nobreak >nul
)

echo.>> "%RESULT%"
goto :eof
