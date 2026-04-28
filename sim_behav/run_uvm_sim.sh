#!/bin/bash
##########################################################################
###
### QuestaSim script — UVM simulation of the accelerator in isolation
###
##########################################################################

# Load EDA tool paths (QuestaSim 2020.4)
source ../setup.sh

# QuestaSim ships UVM 1.2 built-in; point to its source for `include paths
UVM_HOME=$(dirname $(which vlog))/../verilog_src/uvm-1.2/src

# ---------- workspace ----------
workLib=workLib_uvm
rm -rf ${workLib}
vlib ${workLib}
vmap work ${workLib}

# ---------- compile C reference model into a shared object ----------
# DPI-C: Questa loads this .so at vsim time via -sv_lib (no extension).
# -fPIC is required for shared objects on x86_64; -lm pulls in cos/sin.
gcc -fPIC -shared -O2 \
    ../src/testbench/uvm/ref_model/fft_ref.c \
    -o fft_ref.so -lm

# ---------- compile DUT (accelerator + sub-modules only) ----------
# -cover sbceft enables Statement, Branch, Condition, Expression, FSM, Toggle
# coverage in addition to functional coverage from covergroups in the TB.
vlog -cover sbceft \
     /data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.v \
     ../src/design/accelerator.v \
     ../src/design/accelerator_fft.v \
     ../src/design/accelerator_mem.v \
     -timescale 1ns/1ps

# ---------- compile UVM testbench ----------
# +incdir supplies both UVM source dir and our uvm/ dir (for `include)
vlog -sv -cover sbceft \
     +incdir+${UVM_HOME} \
     +incdir+../src/testbench/uvm \
     ${UVM_HOME}/uvm_pkg.sv \
     ../src/testbench/uvm/fft_if.sv \
     ../src/testbench/uvm/tb_top.sv \
     -timescale 1ns/1ps

# ---------- elaborate & run ----------
# -sv_lib loads the pre-compiled UVM DPI shared library (.so without extension).
# This provides C functions like uvm_dpi_get_next_arg_c that UVM calls
# for command-line parsing — without it, run_test() crashes on a null pointer.
# -coverage activates collection at sim-time; coverage save -onexit writes
# the unified coverage database (.ucdb) which is then turned into HTML by
# vcover report -html.
UVM_DPI_LIB=$(dirname $(which vlog))/../uvm-1.2/linux_x86_64/uvm_dpi
TESTNAME=${1:-fft_random_test}
shift || true   # drop $1 so remaining args ($@) become +plusargs

vsim tb_top -c -coverage \
     -sv_lib ${UVM_DPI_LIB} \
     -sv_lib ./fft_ref \
     -do "onfinish stop; run -all; coverage save fft_cov.ucdb; quit -f" \
     +UVM_TESTNAME=${TESTNAME} \
     "$@"

# ---------- post-process coverage ----------
# Generate both a one-line summary (for CI/log) and a navigable HTML report
# (for the deliverable screenshot). The HTML lands in cov_html/index.html.
if [ -f fft_cov.ucdb ]; then
  vcover report -summary fft_cov.ucdb
  # vcover refuses to overwrite an existing -output directory, so wipe it first.
  # -htmldir was deprecated in 2020.4 → use -output for forward compatibility.
  rm -rf cov_html
  vcover report -details -html -output cov_html fft_cov.ucdb
fi
