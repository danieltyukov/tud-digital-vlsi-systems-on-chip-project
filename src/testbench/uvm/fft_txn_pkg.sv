// fft_txn_pkg.sv — Transaction classes for the FFT accelerator UVM testbench
//
// Contains:
//   fft_input_txn  — stimulus: 32 complex samples + 16 twiddle pairs + config
//   fft_output_txn — observed:  32 complex results + finished flag
//
// All widths are derived from the RTL parameters in accelerator.v:
//   MAX_FFT_N  = 32,  DATA_WIDTH = 24,  NUM_TW = 16,  TW_WIDTH = 16

package fft_txn_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // =========================================================================
  //  Parameters — mirror the RTL so transaction fields match exactly
  // =========================================================================
  localparam int MAX_FFT_N  = 32;
  localparam int NUM_TW     = MAX_FFT_N / 2;   // = 16
  localparam int DATA_WIDTH = 24;
  localparam int TW_WIDTH   = 16;

  // =========================================================================
  //  fft_input_txn
  // =========================================================================
  class fft_input_txn extends uvm_sequence_item;

    // --- Stimulus fields (randomized) ---
    rand bit signed [DATA_WIDTH-1:0] data_re [MAX_FFT_N];
    rand bit signed [DATA_WIDTH-1:0] data_im [MAX_FFT_N];
    rand bit signed [TW_WIDTH-1:0]   tw_re   [NUM_TW];
    rand bit signed [TW_WIDTH-1:0]   tw_im   [NUM_TW];

    // --- Configuration fields (constrained, not freely randomized) ---
    rand bit [31:0] number_data;
    rand bit [4:0]  fft_stages;

    // --- Constraints ---

    // Realistic audio data: 17-bit values in a 24-bit container.
    // Leaves 7 bits of headroom for FFT growth (5 bits) + butterfly overflow (2 bits).
    constraint data_range {
      foreach (data_re[i]) data_re[i] inside {[-65536 : 65535]};
      foreach (data_im[i]) data_im[i] inside {[-65536 : 65535]};
    }

    // Q12 unit-circle twiddles: cos/sin in [-1,1] scaled by 2^12.
    constraint tw_range {
      foreach (tw_re[i]) tw_re[i] inside {[-4096 : 4096]};
      foreach (tw_im[i]) tw_im[i] inside {[-4096 : 4096]};
    }

    // RTL currently supports only N=32.
    constraint cfg_valid {
      number_data == 32;
      fft_stages  == 5;
    }

    // --- UVM factory registration + field automation ---
    `uvm_object_utils_begin(fft_input_txn)
      `uvm_field_sarray_int(data_re,     UVM_DEFAULT)
      `uvm_field_sarray_int(data_im,     UVM_DEFAULT)
      `uvm_field_sarray_int(tw_re,       UVM_DEFAULT)
      `uvm_field_sarray_int(tw_im,       UVM_DEFAULT)
      `uvm_field_int       (number_data, UVM_DEFAULT)
      `uvm_field_int       (fft_stages,  UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "fft_input_txn");
      super.new(name);
    endfunction

    // Compact summary for uvm_info — avoids flooding the log with 32+16 values
    virtual function string convert2string();
      string s;
      s = $sformatf("INPUT TXN: N=%0d stages=%0d\n", number_data, fft_stages);
      s = {s, $sformatf("  data[0..3] re: %0d %0d %0d %0d  im: %0d %0d %0d %0d\n",
                         data_re[0], data_re[1], data_re[2], data_re[3],
                         data_im[0], data_im[1], data_im[2], data_im[3])};
      s = {s, $sformatf("  tw[0..3]   re: %0d %0d %0d %0d  im: %0d %0d %0d %0d",
                         tw_re[0], tw_re[1], tw_re[2], tw_re[3],
                         tw_im[0], tw_im[1], tw_im[2], tw_im[3])};
      return s;
    endfunction

  endclass


  // =========================================================================
  //  fft_output_txn
  // =========================================================================
  class fft_output_txn extends uvm_sequence_item;

    // --- Observed fields (not randomized) ---
    bit signed [DATA_WIDTH-1:0] data_re [MAX_FFT_N];
    bit signed [DATA_WIDTH-1:0] data_im [MAX_FFT_N];
    bit                         fft_finished;

    // --- UVM factory registration + field automation ---
    `uvm_object_utils_begin(fft_output_txn)
      `uvm_field_sarray_int(data_re,      UVM_DEFAULT)
      `uvm_field_sarray_int(data_im,      UVM_DEFAULT)
      `uvm_field_int       (fft_finished,  UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "fft_output_txn");
      super.new(name);
    endfunction

    virtual function string convert2string();
      string s;
      s = $sformatf("OUTPUT TXN: finished=%0b\n", fft_finished);
      s = {s, $sformatf("  data[0..3] re: %0d %0d %0d %0d  im: %0d %0d %0d %0d",
                         data_re[0], data_re[1], data_re[2], data_re[3],
                         data_im[0], data_im[1], data_im[2], data_im[3])};
      return s;
    endfunction

  endclass

endpackage
