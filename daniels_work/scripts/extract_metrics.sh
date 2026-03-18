#!/bin/bash
################################################################################
## Extract key PPA metrics from a completed design on the ET4351 server
## Usage: ./extract_metrics.sh [project_dir]
##
## Extracts: latency, power, area, timing slack, DRV count
## Prints a formatted summary
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CRED_FILE="$PROJECT_ROOT/credentials.txt"
REMOTE_DIR="${1:-~/project}"

SERVER="et4351.ewi.tudelft.nl"
USERNAME="datyukov"
PASSWORD=$(grep '^password:' "$CRED_FILE" | sed 's/^password: //')

echo "=========================================="
echo " PPA Metrics Extraction"
echo " Remote dir: $REMOTE_DIR"
echo "=========================================="

sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$SERVER" "
cd $REMOTE_DIR

echo ''
echo '---- LATENCY (from behavioral sim) ----'
if [ -f sim_behav/transcript ]; then
    grep -E 'Latency|runtime|Clock Cycles|Microseconds' sim_behav/transcript 2>/dev/null | tail -10
fi

echo ''
echo '---- TIMING (from PnR reports) ----'
if [ -d pnr/reports ]; then
    # Setup slack
    echo 'Setup timing:'
    grep -r 'WNS\|Worst Negative Slack\|slack' pnr/reports/ 2>/dev/null | grep -i setup | head -5
    echo 'Hold timing:'
    grep -r 'WNS\|Worst Negative Slack\|slack' pnr/reports/ 2>/dev/null | grep -i hold | head -5
fi

echo ''
echo '---- DRV (from PnR reports) ----'
if [ -d pnr/reports ]; then
    grep -r 'max_tran\|max_cap\|max_fanout\|Total.*violation\|DRV' pnr/reports/ 2>/dev/null | head -10
fi

echo ''
echo '---- POWER (from PnR reports) ----'
if [ -d pnr/reports ]; then
    grep -r -A2 'Total Power\|Dynamic\|Leakage\|Internal\|Switching' pnr/reports/ 2>/dev/null | head -20
fi

echo ''
echo '---- AREA (from PnR reports) ----'
if [ -d pnr/reports ]; then
    grep -r 'Total area\|Cell area\|Net area\|Instance.*Count\|Utilization' pnr/reports/ 2>/dev/null | head -10
fi

echo ''
echo '---- CLOCK (from SDC) ----'
grep -r 'create_clock\|period' src/sdc/*.sdc 2>/dev/null | head -5

echo ''
echo '=========================================='
"
