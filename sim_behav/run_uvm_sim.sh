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

# ---------- compile DUT (accelerator + sub-modules only) ----------
vlog /data/Cadence/gpdk045_v60/Synopsys_sram/saed32sram.v \
     ../src/design/accelerator.v \
     ../src/design/accelerator_fft.v \
     ../src/design/accelerator_mem.v \
     -timescale 1ns/1ps

# ---------- compile UVM testbench ----------
# +incdir supplies both UVM source dir and our uvm/ dir (for `include)
vlog -sv \
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
UVM_DPI_LIB=$(dirname $(which vlog))/../uvm-1.2/linux_x86_64/uvm_dpi
vsim tb_top -c \
     -sv_lib ${UVM_DPI_LIB} \
     -do "run -all; quit" \
     +UVM_TESTNAME=fft_base_test
