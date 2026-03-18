#!/bin/bash
################################################################################
## Run all the steps in the project flow
##
## Author: 
##     Ang Li <Ang.Li@tudelft.nl>
##     Yizhuo Wu <Yizhuo.Wu@tudelft.nl>
## Edited 22/01/2026: 
##     Guilherme Guedes <g.guedes@tudelft.nl> 
##	
##
## Usage:
##   ./run_all.sh
################################################################################

# Project directory variable
PROJECT_DIR="$(pwd)"

# Use system Python3
PYTHON="/usr/bin/python3"

echo ":::: INFO :::: Starting full project flow..."

# 0. Setup Environment
echo ":::: INFO :::: Setting up environment..."
source setup.sh

# Exit on error from here on
set -e

#1. Generate Firmware
echo ":::: INFO :::: Generating firmware for full audio signal..."
cd "${PROJECT_DIR}/firmware"
make clean && make
cd "${PROJECT_DIR}"

# 2. Run Hardware Pathfinding - RTL Simulation and Verification
echo ":::: INFO :::: Running behavioral simulation..."
cd "${PROJECT_DIR}/sim_behav"
source run_behav_sim.sh

echo ":::: INFO :::: Verifying behavioral simulation..."
${PYTHON} ../sw/verify.py sim_behav

echo ":::: INFO :::: Syncing VCD capture window to behavioral timing..."
cd "${PROJECT_DIR}"
${PYTHON} - <<'PY'
import re
import sys
from pathlib import Path

targets = [
    Path("sim_struct/scripts/run_vcd.cmd"),
    Path("sim_phys/scripts/run_vcd_setup.cmd"),
    Path("sim_phys/scripts/run_vcd_hold.cmd"),
]

transcript = Path("sim_behav/transcript")
if not transcript.exists():
    print(f"ERROR: Missing transcript: {transcript}", file=sys.stderr)
    sys.exit(1)

text = transcript.read_text(errors="ignore")
m_start = re.search(r"Acceleration of first chunk started at \(Milliseconds\):\s*([-\d.]+)", text)
m_dur = re.search(r"Latency of first chunk is \(MICROseconds\):\s*([-\d.]+)", text)
if not m_start or not m_dur:
    print("ERROR: Could not extract behavioral VCD timing window.", file=sys.stderr)
    sys.exit(1)

start_ms = float(m_start.group(1))
dur_us = float(m_dur.group(1))
updated = []

for path in targets:
    if not path.exists():
      print(f"ERROR: Missing VCD script: {path}", file=sys.stderr)
      sys.exit(1)
    original = path.read_text()
    lines = original.splitlines()
    run_idxs = [idx for idx, line in enumerate(lines) if line.lstrip().startswith("run ")]
    if len(run_idxs) < 2:
      print(f"ERROR: Could not find two run commands in {path}", file=sys.stderr)
      sys.exit(1)
    lines[run_idxs[0]] = f"run {start_ms:.6f}ms"
    lines[run_idxs[1]] = f"run {dur_us:.6f}us"
    updated_text = "\n".join(lines) + ("\n" if original.endswith("\n") else "")
    if updated_text != original:
        path.write_text(updated_text)
        updated.append(str(path))

print(
    f":::: INFO :::: VCD window set to start={start_ms:.6f}ms duration={dur_us:.6f}us; "
    f"updated {len(updated)} file(s)"
)
PY

echo ":::: INFO :::: Generating firmware for single chunk of audio..."
cd "${PROJECT_DIR}/firmware"
make clean && N_CHUNKS=1 make
cd "${PROJECT_DIR}"

# 3. Synthesis
echo ":::: INFO :::: Running synthesis..."
cd "${PROJECT_DIR}/synth"
source run_synth.sh
cd "${PROJECT_DIR}"

# 4. Run Simulation on Post-Synthesis Netlist
echo ":::: INFO :::: Running structural simulation..."
cd "${PROJECT_DIR}/sim_struct"
source run_struct_sim_vcd.sh

echo ":::: INFO :::: Verifying structural simulation..."
${PYTHON} ../sw/verify.py sim_struct


# 5. Place and Route
echo ":::: INFO :::: Running place and route..."
cd "${PROJECT_DIR}/pnr"
source run_pnr.sh
cd "${PROJECT_DIR}"

# 6. Run Simulation on Post-Place and Route Netlist
echo ":::: INFO :::: Running physical simulation..."
cd "${PROJECT_DIR}/sim_phys"
source run_pnr_sim_setup_max.sh
source run_pnr_sim_hold_min.sh

echo ":::: INFO :::: Verifying physical simulation..."
${PYTHON} ../sw/verify.py sim_phys

# 7. Final post-route VCD-annotated power report
echo ":::: INFO :::: Generating final post-route VCD-annotated power report..."
cd "${PROJECT_DIR}/pnr"
innovus -files ./scripts/11.finalPowerReports.tcl

echo ":::: INFO :::: Checking activity annotation coverage..."
${PYTHON} - <<'PY'
import re
import sys
from pathlib import Path

pnr = Path(".")
report = pnr / "finalReports" / "report_power_postRouteVCD.rpt"
innovus_log = pnr / "innovus.log"

if not report.exists():
    print(f"ERROR: Missing power report: {report}", file=sys.stderr)
    sys.exit(1)

report_txt = report.read_text(errors="ignore")
log_candidates = sorted(
    [p for p in pnr.glob("innovus.log*") if re.fullmatch(r"innovus\.log\d*", p.name)],
    key=lambda p: p.stat().st_mtime,
    reverse=True,
)
selected_log = None
log_txt = ""
step11_marker = 'Sourcing file "./scripts/11.finalPowerReports.tcl"'

for cand in log_candidates:
    txt = cand.read_text(errors="ignore")
    if step11_marker in txt:
        selected_log = cand
        log_txt = txt
        break

if selected_log is None:
    if innovus_log.exists():
        selected_log = innovus_log
        log_txt = innovus_log.read_text(errors="ignore")
    elif log_candidates:
        selected_log = log_candidates[0]
        log_txt = selected_log.read_text(errors="ignore")

coverages = []

m_report = re.search(r"Design annotation coverage:\s*([0-9]+/[0-9]+\s*=\s*[0-9.]+%)", report_txt)
if m_report:
    cov_str = m_report.group(1)
    m_pct = re.search(r"=\s*([0-9.]+)%", cov_str)
    if m_pct:
        coverages.append(("report_power_postRouteVCD.rpt", float(m_pct.group(1)), cov_str))

m_log = re.findall(
    r"Total annotation coverage for all files of type VCD:\s*([0-9]+/[0-9]+\s*=\s*[0-9.]+%)",
    log_txt,
)
if m_log:
    cov_str = m_log[-1]
    m_pct = re.search(r"=\s*([0-9.]+)%", cov_str)
    if m_pct:
        src = selected_log.name if selected_log is not None else "innovus.log*"
        coverages.append((src, float(m_pct.group(1)), cov_str))

if not coverages:
    print("ERROR: Could not find annotation coverage in final power artifacts.", file=sys.stderr)
    sys.exit(1)

best_src, best_pct, best_desc = max(coverages, key=lambda x: x[1])
print(f":::: INFO :::: Coverage from {best_src}: {best_desc}")

if best_pct < 99.99:
    print(f"ERROR: Annotation coverage is below 100% ({best_pct:.3f}%).", file=sys.stderr)
    sys.exit(1)
PY
cd "${PROJECT_DIR}"

# 8. Package final design artifacts for submission
echo ":::: INFO :::: Packaging final design artifacts..."
mkdir -p "${PROJECT_DIR}/finaldesign" "${PROJECT_DIR}/finaldesign_hp"

cp -f "${PROJECT_DIR}/firmware/accel_audio.hex" "${PROJECT_DIR}/finaldesign/accel_audio.hex"
cp -f "${PROJECT_DIR}/pnr/outputs/et4351.phys.sdf" "${PROJECT_DIR}/finaldesign/et4351.phys.sdf"
cp -f "${PROJECT_DIR}/pnr/outputs/et4351.phys.v"   "${PROJECT_DIR}/finaldesign/et4351.phys.v"

cp -f "${PROJECT_DIR}/firmware/accel_audio.hex" "${PROJECT_DIR}/finaldesign_hp/accel_audio.hex"
cp -f "${PROJECT_DIR}/pnr/outputs/et4351.phys.sdf" "${PROJECT_DIR}/finaldesign_hp/et4351.phys.sdf"
cp -f "${PROJECT_DIR}/pnr/outputs/et4351.phys.v"   "${PROJECT_DIR}/finaldesign_hp/et4351.phys.v"

echo ":::: INFO :::: Packaged: finaldesign/ and finaldesign_hp/"


# Optional: Visualization
# echo "Running visualization tools..."
# TODO: Implement the .wav generation file

echo ":::: INFO :::: Full project flow completed successfully!"
