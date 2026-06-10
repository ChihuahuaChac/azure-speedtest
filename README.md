# Azure Blob Storage Speed Test

Download speed test scripts for Azure Blob Storage from two regions:
- 🇺🇸 **US South Central** (Texas) — `jessclawscus`
- 🇲🇽 **Mexico Central** (Querétaro) — `jessclawmx`

Each region has 100MB and 500MB random binary files for testing.

## Requirements

- **azcopy** — [Install guide](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10)
  - macOS: `brew install azcopy`
  - Windows: `winget install Microsoft.AzCopy`

## Usage

### macOS / Linux
```bash
chmod +x speedtest_mac.sh

# Default 3 runs per test
./speedtest_mac.sh

# Custom runs
./speedtest_mac.sh 5
```

### Windows (PowerShell)
```powershell
# Default 3 runs per test
.\speedtest_win.ps1

# Custom runs
.\speedtest_win.ps1 -Runs 5
```

## What it measures

| Metric | Description |
|--------|-------------|
| Download speed | Mbps and MB/s via azcopy |
| DNS | DNS resolution time |
| TTFB | Time to first byte |
| Total time | End-to-end download duration |
| Avg/Min/Max | Statistical summary across runs |

Results are saved to `speedtest_results_YYYYMMDD_HHMMSS.txt`.

## SAS Token Expiry

Tokens are valid until **2027-06-10**.

## Download URLs (direct)

### US South Central
- 100MB: `https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?<sas>`
- 500MB: `https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?<sas>`

### Mexico Central
- 100MB: `https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?<sas>`
- 500MB: `https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?<sas>`

(Full SAS URLs are embedded in the scripts)
