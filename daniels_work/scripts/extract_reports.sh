#!/bin/bash
################################################################################
## Extract all signoff reports from a completed design on the ET4351 server
## Usage: ./extract_reports.sh <design_name>  (e.g., baseline, hp, ee)
##
## Extracts: timing, DRV, power, area, connectivity, geometry, antenna reports
## Saves to: daniels_work/results/<design_name>/
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CRED_FILE="$PROJECT_ROOT/credentials.txt"
DESIGN_NAME="${1:-baseline}"
RESULTS_DIR="$PROJECT_ROOT/daniels_work/results/$DESIGN_NAME"

SERVER="et4351.ewi.tudelft.nl"
USERNAME="datyukov"
PASSWORD=$(grep '^password:' "$CRED_FILE" | sed 's/^password: //')

mkdir -p "$RESULTS_DIR"/{timing,drv,power,area,simulation}

echo "Extracting reports for design: $DESIGN_NAME"
echo "Saving to: $RESULTS_DIR"

# Extract timing reports
echo ":::: Extracting timing reports..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/reports/*timing*" \
    "$RESULTS_DIR/timing/" 2>/dev/null || echo "  (no timing reports found)"

# Extract DRV reports
echo ":::: Extracting DRV reports..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/reports/*drv*" \
    "$RESULTS_DIR/drv/" 2>/dev/null || echo "  (no DRV reports found)"
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/reports/*violation*" \
    "$RESULTS_DIR/drv/" 2>/dev/null || true

# Extract power reports
echo ":::: Extracting power reports..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/reports/*power*" \
    "$RESULTS_DIR/power/" 2>/dev/null || echo "  (no power reports found)"

# Extract area reports
echo ":::: Extracting area reports..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/reports/*area*" \
    "$RESULTS_DIR/area/" 2>/dev/null || echo "  (no area reports found)"

# Extract all reports (catch-all)
echo ":::: Extracting all remaining reports..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/reports/*" \
    "$RESULTS_DIR/" 2>/dev/null || echo "  (no reports directory found)"

# Extract simulation outputs
echo ":::: Extracting simulation outputs..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/sim_behav/outputs.txt" \
    "$RESULTS_DIR/simulation/behav_outputs.txt" 2>/dev/null || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/sim_struct/outputs.txt" \
    "$RESULTS_DIR/simulation/struct_outputs.txt" 2>/dev/null || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/sim_phys/outputs.txt" \
    "$RESULTS_DIR/simulation/phys_outputs.txt" 2>/dev/null || true

# Extract final design files
echo ":::: Extracting final design files..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/outputs/et4351.phys.v" \
    "$RESULTS_DIR/" 2>/dev/null || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/pnr/outputs/et4351.phys.sdf" \
    "$RESULTS_DIR/" 2>/dev/null || true
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/firmware/accel_audio.hex" \
    "$RESULTS_DIR/" 2>/dev/null || true

# Extract synthesis report
echo ":::: Extracting synthesis reports..."
sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    "$USERNAME@$SERVER:~/project/synth/reports/*" \
    "$RESULTS_DIR/" 2>/dev/null || true

echo "==== Report extraction complete for $DESIGN_NAME ===="
ls -la "$RESULTS_DIR/"
