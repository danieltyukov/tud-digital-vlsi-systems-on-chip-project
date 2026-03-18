#!/bin/bash
################################################################################
## Run baseline design through the full EDA flow on the ET4351 server
## This establishes reference numbers for comparison with HP and EE designs.
##
## Prerequisites: VPN connected, ~/project exists on server
## Outputs: Results saved to ~/project/baseline_results/
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ssh_cmd.sh" "
set -e
export PATH='/usr/bin:/data/picorv32-utils/riscv32imc/bin:\$PATH'

echo '==== BASELINE FLOW START ===='
cd ~/project

# Setup environment
source setup.sh

# 1. Build firmware (full audio — 24 chunks)
echo ':::: STEP 1: Building firmware (full audio)...'
cd firmware && make clean && make 2>&1 | tail -5
cd ~/project

# 2. Behavioral simulation
echo ':::: STEP 2: Behavioral simulation...'
cd sim_behav && source run_behav_sim.sh 2>&1 | tail -10
cd ~/project/sw && python verify.py sim_behav 2>&1
cd ~/project

# 3. Rebuild firmware (single chunk for synthesis/PnR)
echo ':::: STEP 3: Rebuilding firmware (single chunk)...'
cd firmware && make clean && N_CHUNKS=1 make 2>&1 | tail -5
cd ~/project

# 4. Synthesis
echo ':::: STEP 4: Running synthesis...'
cd synth && source run_synth.sh 2>&1 | tail -20
cd ~/project

# 5. Structural simulation with VCD
echo ':::: STEP 5: Structural simulation (VCD)...'
cd sim_struct && source run_struct_sim_vcd.sh 2>&1 | tail -10
cd ~/project/sw && python verify.py sim_struct 2>&1
cd ~/project

# 6. Place and Route
echo ':::: STEP 6: Place and Route...'
cd pnr && source run_pnr.sh 2>&1 | tail -20
cd ~/project

# 7. Physical simulation
echo ':::: STEP 7: Physical simulation (setup)...'
cd sim_phys && source run_pnr_sim_setup_max.sh 2>&1 | tail -10
echo ':::: STEP 7b: Physical simulation (hold)...'
source run_pnr_sim_hold_min.sh 2>&1 | tail -10
cd ~/project/sw && python verify.py sim_phys 2>&1
cd ~/project

echo '==== BASELINE FLOW COMPLETE ===='
"
