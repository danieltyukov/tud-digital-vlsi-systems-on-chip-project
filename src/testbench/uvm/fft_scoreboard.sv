// fft_scoreboard.sv — Reference-model checker.
//
// Subscribes to monitor's ap_in / ap_out. On each input transaction it
// dequantizes the 24-bit signed samples to 'real' and calls a C reference
// (32-pt DIT radix-2 FFT, ideal twiddles) via DPI-C. The expected output
// is stored, then compared per-bin against the next observed output with
// a (absolute + relative) tolerance to absorb the RTL's fixed-point and
// twiddle-quantization error.
//
// Why ideal twiddles in the C model (not the RTL's Q12 ones):
//   Using the same quantized twiddles in both reference and DUT would
//   cancel twiddle error in the diff and hide twiddle-path bugs. Keeping
//   the reference pristine forces the tolerance to absorb twiddle error
//   but makes the comparison measure RTL-vs-truth.

import fft_txn_pkg::*;

`include "fft_dpi.svh"

// Two analysis_imp variants so the scoreboard exposes distinct write_in /
// write_out methods (UVM macro trick: one `write` per imp type).
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class fft_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(fft_scoreboard)

  // ---- Subscriber ports ----------------------------------------------------
  uvm_analysis_imp_in  #(fft_input_txn,  fft_scoreboard) in_imp;
  uvm_analysis_imp_out #(fft_output_txn, fft_scoreboard) out_imp;

  // ---- Tolerance -----------------------------------------------------------
  // tol(k) = ABS_TOL + REL_TOL * |expected[k]|
  //   ABS_TOL : noise floor for near-zero bins (twiddle/round error makes
  //             "should be 0" come out as a few LSB).
  //   REL_TOL : percentage band that scales with magnitude; large-signal
  //             error grows roughly with signal level in fixed-point FFTs.
  // Start loose, tighten as confidence grows. Don't loosen these to silence
  // a failure — investigate first.
  localparam real ABS_TOL   = 8.0;
  localparam real REL_TOL   = 0.01;
  // Cross-bin noise floor: 0.1% of the run's largest expected magnitude.
  // Captures twiddle/butterfly error that leaks INTO small bins from the
  // large bins — proportional to total signal scale, not per-bin magnitude.
  // Without this, small "should-be-near-zero" bins fail under the global
  // 0.025%-per-mult Q12 twiddle error * 5 stages of mixing.
  localparam real REL_FLOOR = 0.001;

  // ---- State carried between write_in and write_out ------------------------
  real exp_re [MAX_FFT_N];
  real exp_im [MAX_FFT_N];
  real exp_max_mag;    // max(|exp_re[k]|, |exp_im[k]|) across all bins
  bit  exp_valid;     // false until first input txn arrives

  int  checks_run;
  int  checks_passed;
  int  checks_failed;

  function new(string name = "fft_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    in_imp  = new("in_imp",  this);
    out_imp = new("out_imp", this);
  endfunction

  // --------------------------------------------------------------------------
  // write_in — dequantize 24-bit signed samples to real, call C reference,
  // stash the expected output for the next write_out.
  // --------------------------------------------------------------------------
  function void write_in(fft_input_txn t);
    real in_re [MAX_FFT_N];
    real in_im [MAX_FFT_N];

    // The monitor reconstructs the input txn by snooping SRAM writes, so
    // t.data_* arrives in bit-reversed order (driver bit-reverses to match
    // the firmware/RTL contract). Un-permute here so the natural-order C
    // reference sees the same x[n] the user originally specified.
    // $signed() first — without it, the upper bits of negative values
    // would be interpreted as a huge positive integer and $itor would
    // produce garbage (e.g. -1 -> 16777215.0).
    foreach (t.data_re[i]) begin
      int ir = bit_reverse5(i);
      in_re[ir] = $itor($signed(t.data_re[i]));
      in_im[ir] = $itor($signed(t.data_im[i]));
    end

    fft_ref_radix2_dit(in_re, in_im, exp_re, exp_im);

    // Snapshot the run's signal scale for the cross-bin noise-floor term.
    exp_max_mag = 0.0;
    for (int k = 0; k < MAX_FFT_N; k++) begin
      if (abs_real(exp_re[k]) > exp_max_mag) exp_max_mag = abs_real(exp_re[k]);
      if (abs_real(exp_im[k]) > exp_max_mag) exp_max_mag = abs_real(exp_im[k]);
    end

    exp_valid = 1'b1;

    `uvm_info(get_type_name(),
              $sformatf("ref model computed: exp[0]=(%.2f,%.2f)  exp[1]=(%.2f,%.2f)",
                        exp_re[0], exp_im[0], exp_re[1], exp_im[1]),
              UVM_HIGH)
  endfunction

  // --------------------------------------------------------------------------
  // write_out — per-bin compare against stored expected with tolerance.
  // --------------------------------------------------------------------------
  function void write_out(fft_output_txn t);
    int  mismatches;
    real got_re, got_im;
    real diff_re, diff_im;
    real tol_re, tol_im;

    mismatches = 0;

    if (!exp_valid) begin
      `uvm_warning(get_type_name(),
                   "output received before any input — no expected to compare")
      return;
    end

    checks_run++;

    for (int k = 0; k < MAX_FFT_N; k++) begin
      got_re = $itor($signed(t.data_re[k]));
      got_im = $itor($signed(t.data_im[k]));

      diff_re = got_re - exp_re[k];
      diff_im = got_im - exp_im[k];

      // Per-bin tolerance: floor + per-bin magnitude band + cross-bin
      // noise term. Real/imag computed independently so a large-real /
      // small-imag bin doesn't get an over-generous imaginary budget;
      // the REL_FLOOR term shares a single signal-scale slack across both.
      tol_re = ABS_TOL + REL_TOL * abs_real(exp_re[k]) + REL_FLOOR * exp_max_mag;
      tol_im = ABS_TOL + REL_TOL * abs_real(exp_im[k]) + REL_FLOOR * exp_max_mag;

      if (abs_real(diff_re) > tol_re || abs_real(diff_im) > tol_im) begin
        mismatches++;
        // Cap log spam at the first few — a global scale error blows up
        // every bin and 32 errors of the same shape are not informative.
        if (mismatches <= 4)
          `uvm_error(get_type_name(),
                     $sformatf("bin[%0d] mismatch: got (%.2f, %.2f)  expected (%.2f, %.2f)  tol (%.2f, %.2f)",
                               k, got_re, got_im, exp_re[k], exp_im[k], tol_re, tol_im))
      end
    end

    if (mismatches == 0) begin
      checks_passed++;
      `uvm_info(get_type_name(),
                $sformatf("SCOREBOARD PASS: %0d/%0d bins within tolerance",
                          MAX_FFT_N, MAX_FFT_N),
                UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error(get_type_name(),
                 $sformatf("SCOREBOARD FAIL: %0d/%0d bins mismatched",
                           mismatches, MAX_FFT_N))
    end

    // Invalidate so a stray second output without a fresh input is caught.
    exp_valid = 1'b0;
  endfunction

  // SV has no built-in real abs(); $abs is integer-only in older sims.
  function real abs_real(real x);
    return (x < 0.0) ? -x : x;
  endfunction

  // 5-bit reversal for N=32. Used to un-permute the monitor's SRAM-snooped
  // input back to natural order before feeding the natural-order C reference.
  function int bit_reverse5(int x);
    int r;
    r = 0;
    for (int b = 0; b < 5; b++)
      if (x & (1 << b)) r |= (1 << (4 - b));
    return r;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("scoreboard summary: run=%0d pass=%0d fail=%0d",
                        checks_run, checks_passed, checks_failed),
              UVM_NONE)
  endfunction

endclass
