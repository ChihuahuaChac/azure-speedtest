<# 
.SYNOPSIS
    Azure Blob Storage Download Speed Test (Windows + azcopy)
.DESCRIPTION
    Tests download speed from US South Central and Mexico Central Azure regions.
    Requires: azcopy.exe (winget install Microsoft.AzCopy or https://aka.ms/downloadazcopy-v10-windows)
.PARAMETER Runs
    Number of test runs per file (default: 3)
.EXAMPLE
    .\speedtest_win.ps1
    .\speedtest_win.ps1 -Runs 5
#>

param(
    [int]$Runs = 3
)

$ErrorActionPreference = "Stop"

# URLs
$URLs = @{
    "US_100M" = "https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=kBZI7oM5aRX0zoswSAXOoJG615yV%2FoCSWcHrdBq9eCg%3D"
    "US_500M" = "https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=Vg8Gg3r8TUkC1317Q9SRIsnss%2Bu%2FXu4zL2LxLLogRIc%3D"
    "MX_100M" = "https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=qnxTNeXWs%2BnMkJ%2By5ltN9SfvFvHyRS7ywpetNefvMU4%3D"
    "MX_500M" = "https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=hgAS7LnpEKS3X8vRiDRaX9EqZyvGlcMsNnYwb47NzKw%3D"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ResultFile = "speedtest_results_$Timestamp.txt"
$TempDir = Join-Path $env:TEMP "speedtest_$Timestamp"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# Check azcopy
$azcopyPath = Get-Command azcopy -ErrorAction SilentlyContinue
if (-not $azcopyPath) {
    $azcopyPath = Get-Command azcopy.exe -ErrorAction SilentlyContinue
}
if (-not $azcopyPath) {
    Write-Host "ERROR: azcopy not found. Install with:" -ForegroundColor Red
    Write-Host "  winget install Microsoft.AzCopy" -ForegroundColor Yellow
    Write-Host "  or download from: https://aka.ms/downloadazcopy-v10-windows" -ForegroundColor Yellow
    exit 1
}

# Header
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      Azure Blob Download Speed Test (Windows + azcopy)      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Runs per test: $Runs"
Write-Host "Results: $ResultFile"
Write-Host "Temp dir: $TempDir"
Write-Host ""

# System info header
$sysInfo = @"
=== Azure Blob Download Speed Test ===
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')
Host: $env:COMPUTERNAME
OS: $([System.Environment]::OSVersion.VersionString)
Arch: $env:PROCESSOR_ARCHITECTURE
azcopy: $(azcopy --version 2>&1 | Select-Object -First 1)
Network: $(Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty Name) ($(Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1 -ExpandProperty LinkSpeed))
Runs per test: $Runs

"@
$sysInfo | Out-File -FilePath $ResultFile -Encoding utf8

function Run-SpeedTest {
    param(
        [string]$Label,
        [string]$Url,
        [int]$SizeMB
    )

    Write-Host "Testing: $Label (${SizeMB}MB)" -ForegroundColor Yellow
    "--- $Label (${SizeMB}MB) ---" | Out-File -Append -FilePath $ResultFile -Encoding utf8

    $speeds = @()
    $times = @()

    for ($i = 1; $i -le $Runs; $i++) {
        $dest = Join-Path $TempDir "test_${SizeMB}_${i}.bin"

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Run azcopy
        $azcopyOutput = & azcopy copy $Url $dest --output-type text 2>&1 | Out-String

        $stopwatch.Stop()
        $elapsed = $stopwatch.Elapsed.TotalSeconds

        # Try to extract throughput from azcopy log
        $throughputMatch = [regex]::Match($azcopyOutput, "Throughput \(Mb/s\)\s*:\s*([0-9.]+)")
        if ($throughputMatch.Success) {
            $speedMbps = [double]$throughputMatch.Groups[1].Value
        } else {
            # Calculate manually
            $speedMbps = [math]::Round(($SizeMB * 8) / $elapsed, 2)
        }

        $speedMBs = [math]::Round($speedMbps / 8, 2)
        $elapsedRound = [math]::Round($elapsed, 2)

        $speeds += $speedMbps
        $times += $elapsed

        $line = "  Run ${i}: $($speedMbps.ToString('F2')) Mbps ($($speedMBs.ToString('F2')) MB/s) | Time: ${elapsedRound}s"
        Write-Host $line
        $line | Out-File -Append -FilePath $ResultFile -Encoding utf8

        # Cleanup
        Remove-Item -Path $dest -Force -ErrorAction SilentlyContinue

        if ($i -lt $Runs) { Start-Sleep -Seconds 2 }
    }

    $avgSpeed = [math]::Round(($speeds | Measure-Object -Average).Average, 2)
    $minSpeed = [math]::Round(($speeds | Measure-Object -Minimum).Minimum, 2)
    $maxSpeed = [math]::Round(($speeds | Measure-Object -Maximum).Maximum, 2)
    $avgTime = [math]::Round(($times | Measure-Object -Average).Average, 2)

    $summary = "  >> Avg: $avgSpeed Mbps | Min: $minSpeed | Max: $maxSpeed | Avg Time: ${avgTime}s"
    Write-Host "  $summary" -ForegroundColor Green
    Write-Host ""
    "$summary`n" | Out-File -Append -FilePath $ResultFile -Encoding utf8
}

function Run-LatencyProbe {
    param(
        [string]$Label,
        [string]$Url
    )

    Write-Host "  Latency probe:" -ForegroundColor Cyan
    "  Latency probe:" | Out-File -Append -FilePath $ResultFile -Encoding utf8

    try {
        # DNS lookup time
        $uri = [System.Uri]$Url.Split('?')[0]
        $dnsStart = [System.Diagnostics.Stopwatch]::StartNew()
        [System.Net.Dns]::GetHostAddresses($uri.Host) | Out-Null
        $dnsStart.Stop()
        $dnsMs = [math]::Round($dnsStart.Elapsed.TotalMilliseconds, 1)

        # TTFB using HttpWebRequest with range
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = "GET"
        $request.AddRange(0, 1023)
        $ttfbStart = [System.Diagnostics.Stopwatch]::StartNew()
        $response = $request.GetResponse()
        $ttfbStart.Stop()
        $ttfbMs = [math]::Round($ttfbStart.Elapsed.TotalMilliseconds, 1)
        $response.Close()

        $line = "    DNS: ${dnsMs}ms | TTFB: ${ttfbMs}ms"
        Write-Host "  $line"
        $line | Out-File -Append -FilePath $ResultFile -Encoding utf8
    } catch {
        $errLine = "    Probe failed: $_"
        Write-Host "  $errLine" -ForegroundColor Red
        $errLine | Out-File -Append -FilePath $ResultFile -Encoding utf8
    }
    "" | Out-File -Append -FilePath $ResultFile -Encoding utf8
}

# US South Central
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  US South Central (Texas, southcentralus)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
"=== US South Central (Texas) ===" | Out-File -Append -FilePath $ResultFile -Encoding utf8

Run-LatencyProbe -Label "US" -Url $URLs["US_100M"]
Run-SpeedTest -Label "US South Central 100MB" -Url $URLs["US_100M"] -SizeMB 100
Run-SpeedTest -Label "US South Central 500MB" -Url $URLs["US_500M"] -SizeMB 500

# Mexico Central
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Mexico Central (Querétaro, mexicocentral)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
"`n=== Mexico Central (Querétaro) ===" | Out-File -Append -FilePath $ResultFile -Encoding utf8

Run-LatencyProbe -Label "MX" -Url $URLs["MX_100M"]
Run-SpeedTest -Label "Mexico Central 100MB" -Url $URLs["MX_100M"] -SizeMB 100
Run-SpeedTest -Label "Mexico Central 500MB" -Url $URLs["MX_500M"] -SizeMB 500

# Cleanup temp
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

# Final
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                       Complete!                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results saved to: $ResultFile" -ForegroundColor Green
Write-Host ""
Write-Host "--- Results ---" -ForegroundColor Green
Get-Content $ResultFile
