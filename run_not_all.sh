#!/bin/bash
################################################################################
## Run all the steps until synthysis in the project flow
##
## Author: 
##     Ang Li <Ang.Li@tudelft.nl>
##     Yizhuo Wu <Yizhuo.Wu@tudelft.nl>
## Edited 22/01/2026: 
##     Guilherme Guedes <g.guedes@tudelft.nl> 
##	
##
## Usage:
##   ./run_not_all.sh
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

echo ":::: INFO :::: Generating firmware for single chunk of audio..."
cd "${PROJECT_DIR}/firmware"
make clean && N_CHUNKS=1 make
cd "${PROJECT_DIR}"

# 3. Synthesis
echo ":::: INFO :::: Running synthesis..."
cd "${PROJECT_DIR}/synth"
source run_synth.sh
cd "${PROJECT_DIR}"

# # 4. Activity Annotation
# cd "${PROJECT_DIR}/sim_struct"
# source run_struct_sim_vcd.sh
# cd "${PROJECT_DIR}"

# # 5. Synthesis
# echo ":::: INFO :::: Running synthesis..."
# cd "${PROJECT_DIR}/synth"
# source run_synth.sh
# cd "${PROJECT_DIR}"


echo "DONE"