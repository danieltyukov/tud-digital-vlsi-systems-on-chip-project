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

    // Stimulus regime: NORMAL = audio-like distribution, BOUNDARY = extremes only.
    // One enum + one dist constraint replaces having two sequence/test classes.
    typedef enum {NORMAL, BOUNDARY} stim_mode_e;
    rand stim_mode_e mode;

    // Semantic input pattern — classified by the sequence AFTER randomize()
    // by inspecting data_re/data_im. Not randomized: it's a label, not a knob.
    // Used solely by the coverage subscriber's cp_pattern coverpoint.
    typedef enum {GENERIC, ALL_ZERO, IMPULSE, DC, MAX_RANGE} pattern_e;
    pattern_e pattern = GENERIC;

    // ~10% of iterations stress the rails; the other 90% stay in the
    // comfortable region where 100/100 PASS is achievable.
    constraint mode_dist { mode dist { NORMAL := 9, BOUNDARY := 1 }; }

    // --- Constraints ---

    // NORMAL mode: 17-bit values in a 24-bit container, weighted toward small
    // magnitudes (mimics real audio energy). 7 bits of headroom remain for
    // FFT growth (5 bits log2(N)) + butterfly overflow margin (2 bits).
    // ":/ N" splits weight N across the whole range, so the listed weights
    // (10/25/30/25/10) read directly as percentages.
    constraint data_normal {
      if (mode == NORMAL) {
        foreach (data_re[i]) data_re[i] dist {
          [-65536 : -32768] :/ 10,   // outer-negative band
          [-32767 :  -1024] :/ 25,   // mid-low
          [-1023  :   1023] :/ 30,   // small / near-zero (most common)
          [ 1024  :  32767] :/ 25,   // mid-high
          [ 32768 :  65535] :/ 10    // outer-positive band
        };
        foreach (data_im[i]) data_im[i] dist {
          [-65536 : -32768] :/ 10,
          [-32767 :  -1024] :/ 25,
          [-1023  :   1023] :/ 30,
          [ 1024  :  32767] :/ 25,
          [ 32768 :  65535] :/ 10
        };
      }
    }

    // BOUNDARY mode: only ±max and 0 — the classic boundary-value triple.
    // ":=" gives each listed value its own weight; values not listed have
    // weight 0, so the solver picks ONLY from {-65536, 65535, 0}.
    // Stresses sign propagation, accumulator overflow, and the scoreboard's
    // near-zero ABS_TOL floor.
    constraint data_boundary {
      if (mode == BOUNDARY) {
        foreach (data_re[i]) data_re[i] dist { -65536 := 4, 65535 := 4, 0 := 2 };
        foreach (data_im[i]) data_im[i] dist { -65536 := 4, 65535 := 4, 0 := 2 };
      }
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
  //  classify_pattern — shape-only classifier for fft_input_txn.pattern
  //
  // Called by fft_monitor (NOT by sequences) so the label reflects what
  // actually reached the DUT, not the sequence's intent. This is essential
  // because the monitor reconstructs the input txn from bus traffic and
  // publishes a fresh object on ap_in — any pattern field set in the
  // sequence is discarded long before coverage samples it.
  //
  // Order of tests matters: more specific shapes are tested first.
  //   ALL_ZERO  : every (re,im) pair is exactly (0,0)
  //   IMPULSE   : exactly one non-zero sample in the whole vector
  //   DC        : every sample equals the first (and the first is non-zero)
  //   MAX_RANGE : ≥25% of samples sit on the rails (±2^16 boundary)
  //   GENERIC   : everything else
  // =========================================================================
  function automatic void classify_pattern(fft_input_txn tx);
    int n_zero, n_nonzero, n_max, n_eq_first;
    bit signed [DATA_WIDTH-1:0] first_re, first_im;

    n_zero = 0; n_nonzero = 0; n_max = 0; n_eq_first = 0;
    first_re = tx.data_re[0];
    first_im = tx.data_im[0];

    foreach (tx.data_re[k]) begin
      if (tx.data_re[k] == 0 && tx.data_im[k] == 0)              n_zero++;
      else                                                       n_nonzero++;
      if (tx.data_re[k] == -65536 || tx.data_re[k] == 65535 ||
          tx.data_im[k] == -65536 || tx.data_im[k] == 65535)     n_max++;
      if (tx.data_re[k] == first_re && tx.data_im[k] == first_im) n_eq_first++;
    end

    if      (n_zero    == MAX_FFT_N)        tx.pattern = fft_input_txn::ALL_ZERO;
    else if (n_nonzero == 1)                tx.pattern = fft_input_txn::IMPULSE;
    else if (n_eq_first == MAX_FFT_N)       tx.pattern = fft_input_txn::DC;
    else if (n_max     >= (MAX_FFT_N / 4))  tx.pattern = fft_input_txn::MAX_RANGE;
    else                                    tx.pattern = fft_input_txn::GENERIC;
  endfunction


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
