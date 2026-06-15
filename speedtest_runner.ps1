param(
    [int]$Runs = 3,
    [string]$AzCopyExe,
    [string]$ScriptDir
)

# Always use current working directory for output (avoids path escaping issues from bat)
$OutDir = (Get-Location).Path
if (-not $AzCopyExe) {
    if ($ScriptDir) {
        $ScriptDir = $ScriptDir -replace '["\s]+$', ''
        $AzCopyExe = Join-Path $ScriptDir "azcopy\azcopy.exe"
    } else {
        $AzCopyExe = Join-Path $OutDir "azcopy\azcopy.exe"
    }
}

$TmpDir = Join-Path $env:TEMP "azspeedtest"
if (-not (Test-Path $TmpDir)) { New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ResultFile = Join-Path $OutDir "speedtest_$Timestamp.txt"

# URLs - stored here in PowerShell where % is not a special character
$Endpoints = @(
    @{ Label = "US-100MB"; Region = "US South Central [Texas]"; SizeMB = 100
       Url = "https://chacspeedtest.blob.core.windows.net/speedtest/100M.bin?se=2026-06-22T08%3A29Z&sp=r&sv=2026-04-06&sr=b&skoid=0144ac18-a824-4f96-b045-e5c9fd4f49c7&sktid=3f0ca837-5d5d-4d8a-84fa-555d252985a0&skt=2026-06-15T08%3A29%3A05Z&ske=2026-06-22T08%3A29%3A00Z&sks=b&skv=2026-04-06&sig=yjdnMBxRaVf0KnZHQhTiUtOeXVWLgsXti9egjK2PXoI%3D" }
    @{ Label = "US-500MB"; Region = "US South Central [Texas]"; SizeMB = 500
       Url = "https://chacspeedtest.blob.core.windows.net/speedtest/500M.bin?se=2026-06-22T08%3A29Z&sp=r&sv=2026-04-06&sr=b&skoid=0144ac18-a824-4f96-b045-e5c9fd4f49c7&sktid=3f0ca837-5d5d-4d8a-84fa-555d252985a0&skt=2026-06-15T08%3A29%3A06Z&ske=2026-06-22T08%3A29%3A00Z&sks=b&skv=2026-04-06&sig=ygVzA7IeP%2Boyv%2F0c7GEHdL4puKG9eno%2FrdGR%2BW9d6G0%3D" }
    @{ Label = "MX-100MB"; Region = "Mexico Central [Queretaro]"; SizeMB = 100
       Url = "https://chacspeedtestmx.blob.core.windows.net/speedtest/100M.bin?se=2026-06-22T08%3A33Z&sp=r&sv=2026-04-06&sr=b&skoid=0144ac18-a824-4f96-b045-e5c9fd4f49c7&sktid=3f0ca837-5d5d-4d8a-84fa-555d252985a0&skt=2026-06-15T08%3A33%3A00Z&ske=2026-06-22T08%3A33%3A00Z&sks=b&skv=2026-04-06&sig=aIpGLQ1jNqzGrKOWRMu4woM5Wl6hCKGn3m9016eNd9w%3D" }
    @{ Label = "MX-500MB"; Region = "Mexico Central [Queretaro]"; SizeMB = 500
       Url = "https://chacspeedtestmx.blob.core.windows.net/speedtest/500M.bin?se=2026-06-22T08%3A33Z&sp=r&sv=2026-04-06&sr=b&skoid=0144ac18-a824-4f96-b045-e5c9fd4f49c7&sktid=3f0ca837-5d5d-4d8a-84fa-555d252985a0&skt=2026-06-15T08%3A33%3A01Z&ske=2026-06-22T08%3A33%3A00Z&sks=b&skv=2026-04-06&sig=pht0X9beYn8Y%2F1jZ9XA0TJaYy3LQZ2ojTWQ%2FTnlDphs%3D" }
)

# Header
$AzVer = & $AzCopyExe --version 2>&1 | Select-Object -First 1
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Azure Blob Download Speed Test (azcopy)" -ForegroundColor Cyan
Write-Host "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "  Host: $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host "  azcopy: $AzVer" -ForegroundColor Cyan
Write-Host "  Runs: $Runs per endpoint" -ForegroundColor Cyan
Write-Host "  Results: $ResultFile" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

@"
================================================================
 Azure Blob Download Speed Test [azcopy]
 Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
 Host: $env:COMPUTERNAME
 azcopy: $AzVer
 Runs: $Runs per endpoint
================================================================

"@ | Out-File -FilePath $ResultFile -Encoding utf8

# Run tests
$currentRegion = ""
foreach ($ep in $Endpoints) {
    if ($ep.Region -ne $currentRegion) {
        $currentRegion = $ep.Region
        Write-Host "`n---- $currentRegion ----" -ForegroundColor Yellow
        "`n---- $currentRegion ----`n" | Out-File -Append $ResultFile -Encoding utf8
    }

    Write-Host "  [$($ep.Label)]" -ForegroundColor White
    "  [$($ep.Label)]" | Out-File -Append $ResultFile -Encoding utf8

    for ($i = 1; $i -le $Runs; $i++) {
        Write-Host "    Run $i ..." -NoNewline
        $dest = Join-Path $TmpDir "dl_$i.bin"
        $log = Join-Path $TmpDir "log_$i.txt"

        $sw = [Diagnostics.Stopwatch]::StartNew()
        & $AzCopyExe copy $ep.Url $dest --output-type text --log-level NONE 2>&1 | Out-File $log -Encoding utf8
        $sw.Stop()
        $sec = $sw.Elapsed.TotalSeconds

        $dlMB = 0
        if (Test-Path $dest) { $dlMB = [math]::Round((Get-Item $dest).Length / 1MB, 1) }

        $mbps = "FAILED"
        $content = Get-Content $log -Raw -ErrorAction SilentlyContinue
        if ($content -match 'Throughput \(Mb/s\)\s*:\s*([0-9.]+)') {
            $mbps = $Matches[1]
        } elseif ($dlMB -gt 0) {
            $mbps = [math]::Round(($ep.SizeMB * 8) / $sec, 2)
        }

        $secRound = [math]::Round($sec, 2)
        $color = if ($mbps -eq "FAILED") { "Red" } else { "Green" }
        Write-Host "`r    Run ${i}: $mbps Mb/s | ${dlMB} MB | ${secRound}s    " -ForegroundColor $color
        "   Run ${i}: $mbps Mb/s | Downloaded: ${dlMB} MB | Time: ${secRound}s" | Out-File -Append $ResultFile -Encoding utf8

        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        Remove-Item $log -Force -ErrorAction SilentlyContinue
        if ($i -lt $Runs) { Start-Sleep 2 }
    }
    "" | Out-File -Append $ResultFile -Encoding utf8
}

# Done
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Done! Results: $ResultFile" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Get-Content $ResultFile
