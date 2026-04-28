// fft_hier_defs.svh — Hierarchical probe paths used by the monitor.
//
// Kept in one place so that wrapping/renaming the DUT only needs a single edit.

`ifndef FFT_HIER_DEFS_SVH
`define FFT_HIER_DEFS_SVH

  // 64-entry, 24-bit-wide data SRAM inside the accelerator.
  // Layout (set by the FFT core during STORE): mem[2k]=re, mem[2k+1]=im.
  `define FFT_MEM_PATH      tb_top.dut.mem.mem

  // Active-high "FFT done" strobe driven by accelerator_fft.
  `define FFT_FINISHED_PATH tb_top.dut.finished_accel

  // FSM state register inside accelerator_fft (instance name: dut.fft).
  // Encoding: 0=S_INIT, 1=S_LOAD_DATA, 2=S_COMPUTE, 3=S_STORE_DATA, 4=S_FINISH.
  `define FFT_STATE_PATH    tb_top.dut.fft.state_reg

`endif
