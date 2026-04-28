// fft_coverage.sv — Functional coverage subscriber for the input side.
//
// Independent uvm_component (not folded into monitor or scoreboard) so that
// "what was driven" coverage stays orthogonal from "did it pass" checking.
// Subscribes to BOTH analysis ports of the monitor:
//   ap_in  → samples cg_input on every committed input transaction
//   ap_out → updates the back-to-back flag based on inter-FFT gap
//
// Two analysis_imp's are declared via `uvm_analysis_imp_decl because a
// single component cannot have two plain uvm_analysis_imp's of distinct
// types without distinct write() method names. The suffixes _cov_in /
// _cov_out are deliberately verbose to avoid colliding with any decls
// already shipped in Questa's prebuilt UVM library.

import fft_txn_pkg::*;

`uvm_analysis_imp_decl(_cov_in)
`uvm_analysis_imp_decl(_cov_out)

class fft_coverage extends uvm_component;

  `uvm_component_utils(fft_coverage)

  uvm_analysis_imp_cov_in  #(fft_input_txn,  fft_coverage) ap_cov_in_imp;
  uvm_analysis_imp_cov_out #(fft_output_txn, fft_coverage) ap_cov_out_imp;

  // Back-to-back detection:
  //   last_finish_time = simulation time of the most recent ap_out.
  //   On the next ap_in, if (now - last_finish_time) < B2B_THRESHOLD_NS,
  //   we treat that FFT as "back-to-back" with the previous one.
  //
  // Threshold sized to comfortably bracket the two cadences we run:
  //   tight pair  : test waits #10us — long enough for the previous FFT
  //                 to actually finish (FFT ≈ 4us), then ~6us idle before
  //                 driver programs the next CSRs. ap_out → next ap_in
  //                 gap ≈ 7us  ⇒ must be < threshold to count as b2b.
  //   normal drain: test waits #50us — gap ≈ 47us ⇒ must be > threshold.
  // 15us sits in the middle and is robust to FFT-runtime variation.
  // (Using a too-short test gap, e.g. #1us, would abort the previous FFT
  // via reset_accel — no ap_out fires, last_finish_time stays stale, and
  // b2b can never trigger. That's why this threshold pairs with #10us.)
  realtime last_finish_time = 0;
  bit      b2b_flag         = 0;
  localparam realtime B2B_THRESHOLD_NS = 15000.0;  // 15 us

  // Latched txn fields for the covergroup to sample. Mirroring scalars into
  // local variables sidesteps tool quirks around sampling unpacked-array
  // formals via 'with function sample(...)'.
  bit signed [DATA_WIDTH-1:0] s_data0;
  fft_input_txn::pattern_e    s_pattern;
  bit                         s_b2b;

  // ---------------------------------------------------------------------
  // cg_input — the headline covergroup for this milestone.
  //   cp_data_range : 5-bin partition of data_re[0] (single representative
  //                   sample; covering all 32 lanes would inflate the score
  //                   without adding information since the dist constraint
  //                   is identical across lanes).
  //   cp_pattern    : semantic class of the input vector (filled by sequence).
  //   cp_b2b        : was this FFT issued back-to-back with the previous one?
  //   cx_pat_range  : cross of pattern × range, with ignore_bins for the
  //                   physically unreachable cells (e.g. ALL_ZERO can only
  //                   land in near_zero by definition).
  // ---------------------------------------------------------------------
  covergroup cg_input;
    option.per_instance = 1;
    option.name         = "fft_input_cg";

    cp_data_range : coverpoint s_data0 {
      bins neg_full  = {[-65536 : -32768]};
      bins neg_half  = {[-32767 :  -1024]};
      bins near_zero = {[-1023  :   1023]};
      bins pos_half  = {[ 1024  :  32767]};
      bins pos_full  = {[ 32768 :  65535]};
    }

    cp_pattern : coverpoint s_pattern {
      bins all_zero  = {fft_input_txn::ALL_ZERO};
      bins impulse   = {fft_input_txn::IMPULSE};
      bins dc        = {fft_input_txn::DC};
      bins max_range = {fft_input_txn::MAX_RANGE};
      bins generic   = {fft_input_txn::GENERIC};
    }

    cp_b2b : coverpoint s_b2b {
      bins gap = {1'b0};
      bins b2b = {1'b1};
    }

    // Cross with ignore_bins for unreachable combinations. Without these,
    // the cross's 5x5 = 25 denominator caps coverage well below 100% for
    // purely physical reasons, masking real testing gaps.
    cx_pat_range : cross cp_pattern, cp_data_range {
      // ALL_ZERO: every sample is exactly 0 → data_re[0] is always near_zero.
      ignore_bins all_zero_unreachable =
          binsof(cp_pattern.all_zero) &&
          !binsof(cp_data_range.near_zero);

      // MAX_RANGE (BOUNDARY mode): solver picks only from {-65536, 65535, 0}.
      // Mid-band bins are excluded by construction.
      // Note: 'binsof(<cp>) intersect { <values> }' takes raw values, not
      // bin names — to refer to specific named bins we OR several binsof's.
      ignore_bins max_range_unreachable =
          binsof(cp_pattern.max_range) &&
          (binsof(cp_data_range.neg_half) || binsof(cp_data_range.pos_half));

      // IMPULSE: this sequence places the spike at index 0, so data_re[0]
      // is always the spike value (positive, large) → only pos_full reachable.
      ignore_bins impulse_unreachable =
          binsof(cp_pattern.impulse) &&
          !binsof(cp_data_range.pos_full);
    }
  endgroup

  function new(string name = "fft_coverage", uvm_component parent = null);
    super.new(name, parent);
    ap_cov_in_imp  = new("ap_cov_in_imp",  this);
    ap_cov_out_imp = new("ap_cov_out_imp", this);
    cg_input       = new();
  endfunction

  // Called by monitor.ap_in.write() — one per FFT commit.
  function void write_cov_in(fft_input_txn t);
    // Compute b2b BEFORE sampling so this txn's b2b reflects its own gap
    // from the previous FFT's completion, not a stale value.
    b2b_flag = ((last_finish_time != 0) &&
                (($realtime - last_finish_time) < B2B_THRESHOLD_NS));

    s_data0   = t.data_re[0];
    s_pattern = t.pattern;
    s_b2b     = b2b_flag;
    cg_input.sample();
  endfunction

  // Called by monitor.ap_out.write() — one per FFT done.
  function void write_cov_out(fft_output_txn t);
    last_finish_time = $realtime;
  endfunction

  // Headline number printed at end-of-test for quick log scanning;
  // the per-bin breakdown lives in the UCDB / HTML report.
  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("cg_input coverage = %0.2f%%", cg_input.get_coverage()),
              UVM_LOW)
  endfunction

endclass
