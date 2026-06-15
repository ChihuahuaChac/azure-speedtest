<# 
.SYNOPSIS
    Azure Blob Download Speed Test (azcopy)
.DESCRIPTION
    Auto-downloads azcopy, then tests download throughput from 
    US South Central (Texas) and Mexico Central (Queretaro).
.PARAMETER Runs
    Number of test runs per endpoint (default: 3)
.EXAMPLE
    .\speedtest_azcopy.ps1
    .\speedtest_azcopy.ps1 -Runs 5
#>

param([int]$Runs = 3)

$ErrorActionPreference = "Stop"

# --- SAS URLs ---
$Endpoints = @(
    @{ Label = "US-100MB"; Region = "US South Central [Texas]"; SizeMB = 100
       Url = "https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=kBZI7oM5aRX0zoswSAXOoJG615yV%2FoCSWcHrdBq9eCg%3D" }
    @{ Label = "US-500MB"; Region = "US South Central [Texas]"; SizeMB = 500
       Url = "https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=Vg8Gg3r8TUkC1317Q9SRIsnss%2Bu%2FXu4zL2LxLLogRIc%3D" }
    @{ Label = "MX-100MB"; Region = "Mexico Central [Queretaro]"; SizeMB = 100
       Url = "https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=qnxTNeXWs%2BnMkJ%2By5ltN9SfvFvHyRS7ywpetNefvMU4%3D" }
    @{ Label = "MX-500MB"; Region = "Mexico Central [Queretaro]"; SizeMB = 500
       Url = "https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=hgAS7LnpEKS3X8vRiDRaX9EqZyvGlcMsNnYwb47NzKw%3D" }
)

# --- Paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }
$AzCopyDir = Join-Path $ScriptDir "azcopy"
$AzCopyExe = Join-Path $AzCopyDir "azcopy.exe"
$TmpDir = Join-Path $env:TEMP "azspeedtest_$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ResultFile = Join-Path $ScriptDir "speedtest_$Timestamp.txt"

# --- Header ---
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Azure Blob Download Speed Test (azcopy)" -ForegroundColor Cyan
Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "  Host: $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "  Runs: $Runs per endpoint" -ForegroundColor Cyan
Write-Host "  Results: $ResultFile" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# --- Download azcopy if needed ---
if (-not (Test-Path $AzCopyExe)) {
    Write-Host "[INFO] azcopy not found, downloading..." -ForegroundColor Yellow
    $zipPath = Join-Path $TmpDir "azcopy.zip"
    $extractPath = Join-Path $TmpDir "azcopy_extract"

    # Download
    Write-Host "  Downloading from https://aka.ms/downloadazcopy-v10-windows ..."
    Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile $zipPath -UseBasicParsing
    
    # Extract
    Write-Host "  Extracting..."
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    
    # Find azcopy.exe
    $found = Get-ChildItem -Path $extractPath -Recurse -Filter "azcopy.exe" | Select-Object -First 1
    if (-not $found) {
        Write-Host "[ERROR] Could not find azcopy.exe in downloaded archive." -ForegroundColor Red
        exit 1
    }
    
    New-Item -ItemType Directory -Path $AzCopyDir -Force | Out-Null
    Copy-Item $found.FullName $AzCopyExe
    
    # Cleanup
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "[OK] azcopy installed to: $AzCopyExe" -ForegroundColor Green
} else {
    Write-Host "[OK] azcopy found: $AzCopyExe" -ForegroundColor Green
}

# Version
$AzCopyVer = & $AzCopyExe --version 2>&1 | Select-Object -First 1
Write-Host "     $AzCopyVer"
Write-Host ""

# --- Write result header ---
@"
================================================================
 Azure Blob Download Speed Test [azcopy]
 Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
 Host: $env:COMPUTERNAME
 azcopy: $AzCopyVer
 Runs: $Runs per endpoint
================================================================

"@ | Out-File -FilePath $ResultFile -Encoding utf8

# --- Run tests ---
$currentRegion = ""

foreach ($ep in $Endpoints) {
    # Region header
    if ($ep.Region -ne $currentRegion) {
        $currentRegion = $ep.Region
        $regionLine = "`n---- $currentRegion ----"
        Write-Host $regionLine -ForegroundColor Yellow
        $regionLine | Out-File -Append -FilePath $ResultFile -Encoding utf8
        "" | Out-File -Append -FilePath $ResultFile -Encoding utf8
    }

    $label = "$($ep.Label) ($($ep.SizeMB) MB)"
    Write-Host "`n  [$label]" -ForegroundColor White
    "  [$label]" | Out-File -Append -FilePath $ResultFile -Encoding utf8

    for ($i = 1; $i -le $Runs; $i++) {
        Write-Host "    Run $i ..." -NoNewline

        $dest = Join-Path $TmpDir "test_${i}.bin"
        $logFile = Join-Path $TmpDir "azcopy_log_${i}.txt"

        # Run azcopy
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $AzCopyExe copy $ep.Url $dest --output-type text --log-level NONE 2>&1 | Out-File $logFile -Encoding utf8
        $sw.Stop()
        $elapsedSec = $sw.Elapsed.TotalSeconds

        # Check file size
        $dlSizeMB = 0
        if (Test-Path $dest) {
            $dlSizeMB = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        }

        # Parse throughput from azcopy output
        $mbps = "N/A"
        $logContent = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if ($logContent -match "Throughput \(Mb/s\)\s*:\s*([0-9.]+)") {
            $mbps = $Matches[1]
        } elseif ($dlSizeMB -gt 0) {
            # Calculate manually
            $mbps = [math]::Round(($ep.SizeMB * 8) / $elapsedSec, 2)
        } else {
            $mbps = "FAILED"
        }

        $elapsedRound = [math]::Round($elapsedSec, 2)
        $line = "   Run ${i}: $mbps Mb/s | Downloaded: ${dlSizeMB} MB | Time: ${elapsedRound}s"
        
        Write-Host "`r    Run ${i}: $mbps Mb/s | ${dlSizeMB} MB | ${elapsedRound}s    " -ForegroundColor $(if ($mbps -eq "FAILED") {"Red"} else {"Green"})
        $line | Out-File -Append -FilePath $ResultFile -Encoding utf8

        # Cleanup
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue

        if ($i -lt $Runs) { Start-Sleep -Seconds 2 }
    }
    "" | Out-File -Append -FilePath $ResultFile -Encoding utf8
}

# --- Cleanup ---
Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue

# --- Summary ---
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Done! Results saved to: $ResultFile" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "--- Results ---" -ForegroundColor Green
Get-Content $ResultFile
