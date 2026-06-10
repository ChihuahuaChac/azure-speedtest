#!/bin/bash
# Azure Blob Storage Download Speed Test (macOS)
# Uses azcopy for accurate transfer metrics
# Requires: azcopy (brew install azcopy)

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# URLs
US_100M="https://jessclawscus.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=kBZI7oM5aRX0zoswSAXOoJG615yV%2FoCSWcHrdBq9eCg%3D"
US_500M="https://jessclawscus.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=Vg8Gg3r8TUkC1317Q9SRIsnss%2Bu%2FXu4zL2LxLLogRIc%3D"
MX_100M="https://jessclawmx.blob.core.windows.net/speedtest/100M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=qnxTNeXWs%2BnMkJ%2By5ltN9SfvFvHyRS7ywpetNefvMU4%3D"
MX_500M="https://jessclawmx.blob.core.windows.net/speedtest/500M.bin?se=2027-06-10T08%3A22Z&sp=r&spr=https&sv=2026-04-06&sr=b&sig=hgAS7LnpEKS3X8vRiDRaX9EqZyvGlcMsNnYwb47NzKw%3D"

RUNS=${1:-3}
RESULT_FILE="speedtest_results_$(date +%Y%m%d_%H%M%S).txt"
TMPDIR_TEST=$(mktemp -d)

trap "rm -rf $TMPDIR_TEST" EXIT

# Check azcopy
if ! command -v azcopy &>/dev/null; then
    echo -e "${RED}Error: azcopy not found. Install with: brew install azcopy${NC}"
    exit 1
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       Azure Blob Download Speed Test (macOS + azcopy)       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Runs per test: $RUNS"
echo "Results: $RESULT_FILE"
echo "Temp dir: $TMPDIR_TEST"
echo ""

# System info
{
    echo "=== Azure Blob Download Speed Test ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Host: $(hostname)"
    echo "OS: $(sw_vers -productName 2>/dev/null || uname -s) $(sw_vers -productVersion 2>/dev/null || uname -r)"
    echo "Arch: $(uname -m)"
    echo "azcopy: $(azcopy --version 2>&1 | head -1)"
    echo "Network: $(networksetup -getairportnetwork en0 2>/dev/null || echo 'N/A')"
    echo "Runs per test: $RUNS"
    echo ""
} > "$RESULT_FILE"

run_test() {
    local label="$1"
    local url="$2"
    local size_mb="$3"

    echo -e "${YELLOW}Testing: ${label} (${size_mb}MB)${NC}"
    echo "--- $label (${size_mb}MB) ---" >> "$RESULT_FILE"

    local total_speed=0
    local total_time=0
    local speeds=()

    for i in $(seq 1 $RUNS); do
        local dest="$TMPDIR_TEST/test_${size_mb}_${i}.bin"
        local start_time=$(python3 -c "import time; print(time.time())")

        # Run azcopy and capture throughput from output
        local azcopy_log
        azcopy_log=$(azcopy copy "$url" "$dest" --output-type text 2>&1)

        local end_time=$(python3 -c "import time; print(time.time())")
        local elapsed=$(python3 -c "print(f'{$end_time - $start_time:.2f}')")

        # Extract throughput from azcopy output (looks for "Throughput (Mb/s)" or calculate)
        local throughput_mbps
        throughput_mbps=$(echo "$azcopy_log" | grep -i "throughput" | grep -oE '[0-9]+\.?[0-9]*' | tail -1)

        # If azcopy doesn't report throughput, calculate manually
        if [ -z "$throughput_mbps" ] || [ "$throughput_mbps" = "0" ]; then
            throughput_mbps=$(python3 -c "print(f'{$size_mb * 8 / $elapsed:.2f}')")
        fi

        local speed_mbs=$(python3 -c "print(f'{$throughput_mbps / 8:.2f}')")

        speeds+=("$throughput_mbps")
        total_speed=$(python3 -c "print($total_speed + $throughput_mbps)")
        total_time=$(python3 -c "print($total_time + $elapsed)")

        printf "  Run %d: %8s Mbps (%6s MB/s) | Time: %ss\n" "$i" "$throughput_mbps" "$speed_mbs" "$elapsed"
        printf "  Run %d: %s Mbps (%s MB/s) | Time: %ss\n" "$i" "$throughput_mbps" "$speed_mbs" "$elapsed" >> "$RESULT_FILE"

        # Cleanup temp file
        rm -f "$dest"
        [ $i -lt $RUNS ] && sleep 2
    done

    local avg_speed=$(python3 -c "print(f'{$total_speed / $RUNS:.2f}')")
    local avg_time=$(python3 -c "print(f'{$total_time / $RUNS:.2f}')")
    local min_speed=$(printf '%s\n' "${speeds[@]}" | sort -n | head -1)
    local max_speed=$(printf '%s\n' "${speeds[@]}" | sort -n | tail -1)

    echo -e "  ${GREEN}▸ Avg: ${avg_speed} Mbps | Min: ${min_speed} | Max: ${max_speed} | Avg Time: ${avg_time}s${NC}"
    echo ""
    printf "  >> Avg: %s Mbps | Min: %s | Max: %s | Avg Time: %ss\n\n" "$avg_speed" "$min_speed" "$max_speed" "$avg_time" >> "$RESULT_FILE"
}

# Also run curl-based test for latency metrics
run_curl_test() {
    local label="$1"
    local url="$2"

    echo -e "  ${CYAN}Latency probe (curl):${NC}"
    echo "  Latency probe (curl):" >> "$RESULT_FILE"

    local result
    result=$(curl -o /dev/null -s -w "DNS:%{time_namelookup}s | TCP:%{time_connect}s | TLS:%{time_appconnect}s | TTFB:%{time_starttransfer}s" "$url" --range 0-1023)
    echo "    $result"
    echo "    $result" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"
}

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  🇺🇸 US South Central (Texas, southcentralus)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "=== 🇺🇸 US South Central (Texas) ===" >> "$RESULT_FILE"
run_curl_test "US Latency" "$US_100M"
run_test "US South Central 100MB" "$US_100M" 100
run_test "US South Central 500MB" "$US_500M" 500

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  🇲🇽 Mexico Central (Querétaro, mexicocentral)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "=== 🇲🇽 Mexico Central (Querétaro) ===" >> "$RESULT_FILE"
run_curl_test "MX Latency" "$MX_100M"
run_test "Mexico Central 100MB" "$MX_100M" 100
run_test "Mexico Central 500MB" "$MX_500M" 500

# Final summary
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      Complete!                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Full results: $(pwd)/$RESULT_FILE"
echo ""
echo -e "${GREEN}--- Results ---${NC}"
cat "$RESULT_FILE"
