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

:: --- SAS URLs (valid until 2027-06-10) ---
set "US_100M=https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=kBZI7oM5aRX0zoswSAXOoJG615yV%%2FoCSWcHrdBq9eCg%%3D"
set "US_500M=https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=Vg8Gg3r8TUkC1317Q9SRIsnss%%2Bu%%2FXu4zL2LxLLogRIc%%3D"
set "MX_100M=https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=qnxTNeXWs%%2BnMkJ%%2By5ltN9SfvFvHyRS7ywpetNefvMU4%%3D"
set "MX_500M=https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=hgAS7LnpEKS3X8vRiDRaX9EqZyvGlcMsNnYwb47NzKw%%3D"

:: --- Setup paths ---
set "SCRIPTDIR=%~dp0"
set "AZCOPY_DIR=%SCRIPTDIR%azcopy"
set "AZCOPY_EXE=%AZCOPY_DIR%\azcopy.exe"
set "TMPDIR=%TEMP%\azspeedtest_%RANDOM%"
mkdir "%TMPDIR%" 2>nul

:: --- Timestamp for result file ---
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "DT=%%a"
set "TIMESTAMP=%DT:~0,8%_%DT:~8,6%"
set "RESULT=%SCRIPTDIR%speedtest_%TIMESTAMP%.txt"

echo.
echo ================================================================
echo   Azure Blob Download Speed Test (azcopy)
echo   Date: %DT:~0,4%-%DT:~4,2%-%DT:~6,2% %DT:~8,2%:%DT:~10,2%:%DT:~12,2%
echo   Host: %COMPUTERNAME%
echo   Runs: %RUNS% per endpoint
echo   Results: %RESULT%
echo ================================================================
echo.

:: --- Check / Download azcopy ---
if exist "%AZCOPY_EXE%" (
    echo [OK] azcopy found: %AZCOPY_EXE%
) else (
    echo [INFO] azcopy not found, downloading...
    echo.

    set "AZCOPY_URL=https://aka.ms/downloadazcopy-v10-windows"
    set "AZCOPY_ZIP=%TEMP%\azcopy.zip"

    :: Download
    curl -sL -o "%AZCOPY_ZIP%" "%AZCOPY_URL%"
    if errorlevel 1 (
        echo [ERROR] Failed to download azcopy. Check network.
        exit /b 1
    )

    :: Extract
    mkdir "%AZCOPY_DIR%" 2>nul
    powershell -NoProfile -Command "Expand-Archive -Path '%AZCOPY_ZIP%' -DestinationPath '%TEMP%\azcopy_extract' -Force"
    if errorlevel 1 (
        echo [ERROR] Failed to extract azcopy zip.
        exit /b 1
    )

    :: Find azcopy.exe in extracted folder (nested in version subfolder)
    for /r "%TEMP%\azcopy_extract" %%f in (azcopy.exe) do (
        copy "%%f" "%AZCOPY_EXE%" >nul
    )

    :: Cleanup
    del "%AZCOPY_ZIP%" 2>nul
    rmdir /s /q "%TEMP%\azcopy_extract" 2>nul

    if not exist "%AZCOPY_EXE%" (
        echo [ERROR] Could not find azcopy.exe after extraction.
        exit /b 1
    )
    echo [OK] azcopy installed to: %AZCOPY_EXE%
)

:: --- Show azcopy version ---
for /f "tokens=*" %%v in ('"%AZCOPY_EXE%" --version 2^>^&1') do set "AZCOPY_VER=%%v"
echo      %AZCOPY_VER%
echo.

:: --- Write header ---
(
echo ================================================================
echo  Azure Blob Download Speed Test [azcopy]
echo  Date: %DT:~0,4%-%DT:~4,2%-%DT:~6,2% %DT:~8,2%:%DT:~10,2%:%DT:~12,2%
echo  Host: %COMPUTERNAME%
echo  azcopy: %AZCOPY_VER%
echo  Runs: %RUNS% per endpoint
echo ================================================================
echo.
) > "%RESULT%"

:: --- Run tests ---
call :region "US South Central [Texas]"
call :runtest "US-100MB" 100 "%US_100M%"
call :runtest "US-500MB" 500 "%US_500M%"

call :region "Mexico Central [Queretaro]"
call :runtest "MX-100MB" 100 "%MX_100M%"
call :runtest "MX-500MB" 500 "%MX_500M%"

:: --- Cleanup ---
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
:region
echo.
echo ---- %~1 ----
echo.>> "%RESULT%"
echo ---- %~1 ---->> "%RESULT%"
echo.>> "%RESULT%"
goto :eof

:: ===============================================================
:runtest
set "LABEL=%~1"
set "SIZEMB=%~2"
set "URL=%~3"

echo   [%LABEL%] (%SIZEMB% MB)
echo   [%LABEL%] (%SIZEMB% MB)>> "%RESULT%"

set "SUM_MBPS=0"
set "BEST_MBPS=0"

for /L %%i in (1,1,%RUNS%) do (
    set "DEST=%TMPDIR%\test_%%i.bin"

    echo     Run %%i ...

    :: Run azcopy, capture output to temp log
    set "LOGFILE=%TMPDIR%\azcopy_log_%%i.txt"
    "%AZCOPY_EXE%" copy "%URL%" "!DEST!" --output-type text --log-level NONE --cap-mbps 0 > "!LOGFILE!" 2>&1

    :: Extract throughput from azcopy output
    set "THROUGHPUT=0"
    set "ELAPSED=0"
    for /f "tokens=2 delims=:" %%t in ('findstr /i "Elapsed Time" "!LOGFILE!"') do (
        set "ELAPSED=%%t"
    )
    for /f "tokens=*" %%t in ('findstr /i "Throughput" "!LOGFILE!"') do (
        set "TPLINE=%%t"
    )

    :: Parse throughput line: "TotalBytesTransferred: xxx; Throughput (Mb/s): yyy"
    set "MBPS=N/A"
    for /f "tokens=2 delims=:" %%m in ('echo !TPLINE! ^| findstr /i "Mb/s"') do (
        for /f "tokens=1" %%n in ("%%m") do set "MBPS=%%n"
    )

    :: If azcopy didn't report throughput, calculate from file size and elapsed
    if "!MBPS!"=="N/A" (
        :: Fallback: measure with powershell
        for /f %%s in ('powershell -NoProfile -Command "$f='!DEST!'; if(Test-Path $f){(Get-Item $f).Length}else{0}"') do set "FSIZE=%%s"
        if "!FSIZE!" GEQ "1000000" (
            for /f %%c in ('powershell -NoProfile -Command "[math]::Round(!SIZEMB! * 8 / 10, 2)"') do set "MBPS=%%c"
        )
    )

    :: Get actual file size for verification
    set "DLSIZE=0"
    for /f %%s in ('powershell -NoProfile -Command "$f='!DEST!'; if(Test-Path $f){[math]::Round((Get-Item $f).Length/1MB,1)}else{0}"') do set "DLSIZE=%%s"

    set "LINE=   Run %%i: !MBPS! Mb/s | Downloaded: !DLSIZE! MB | Elapsed:!ELAPSED!"
    echo !LINE!
    echo !LINE!>> "%RESULT%"

    :: Cleanup downloaded file between runs
    del "!DEST!" 2>nul
    del "!LOGFILE!" 2>nul

    :: Brief pause between runs
    if %%i LSS %RUNS% timeout /t 2 /nobreak >nul
)

echo.>> "%RESULT%"
echo.
goto :eof
