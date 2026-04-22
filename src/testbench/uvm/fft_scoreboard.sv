// fft_scoreboard.sv — Directed checker.
//
// v1 behaviour:
//   - Subscribe to monitor's ap_in and ap_out.
//   - If the observed input matches the impulse pattern
//     (x[0]=1, x[1..31]=0, all imag=0), expected output = all bins 1+0j.
//     Any other input → mark "no oracle", skip the check for that run.
//   - On output, compare per-bin against the stored expected and report.
//
// Reference-model-based checking comes later; this is just enough to get
// a PASS/FAIL signal out of a single directed vector.

import fft_txn_pkg::*;

// Two separate analysis_imp variants so the scoreboard can have distinct
// write_in / write_out methods (UVM macro trick: one `write` per imp type).
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class fft_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(fft_scoreboard)

  // ---- Subscriber ports ----------------------------------------------------
  uvm_analysis_imp_in  #(fft_input_txn,  fft_scoreboard) in_imp;
  uvm_analysis_imp_out #(fft_output_txn, fft_scoreboard) out_imp;

  // ---- State carried between write_in and write_out ------------------------
  // Expected scalar values for the impulse case — scoreboard compares each
  // observed bin against these. If the RTL applies a global scale factor,
  // update EXP_RE here (e.g., to 4096 for a Q12-unscaled core).
  localparam int EXP_RE = 1;
  localparam int EXP_IM = 0;

  bit     have_oracle;      // true iff last input was impulse → expected is known
  int     checks_run;
  int     checks_passed;
  int     checks_failed;

  function new(string name = "fft_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    in_imp  = new("in_imp",  this);
    out_imp = new("out_imp", this);
  endfunction

  // --------------------------------------------------------------------------
  // write_in — invoked synchronously whenever the monitor publishes an input.
  // Classifies the input and stores whether we can judge the next output.
  // --------------------------------------------------------------------------
  function void write_in(fft_input_txn t);
    have_oracle = is_impulse(t);
    if (have_oracle)
      `uvm_info(get_type_name(),
                "input is impulse (x[0]=1, rest=0) — oracle = all bins 1+0j",
                UVM_LOW)
    else
      `uvm_info(get_type_name(),
                "input is not a known directed case — skipping directed check",
                UVM_MEDIUM)
  endfunction

  // --------------------------------------------------------------------------
  // write_out — compare the observed output against the stored expected.
  // --------------------------------------------------------------------------
  function void write_out(fft_output_txn t);
    int mismatches;
    mismatches = 0;

    if (!have_oracle) begin
      `uvm_info(get_type_name(),
                "output received but no oracle set — check skipped",
                UVM_MEDIUM)
      return;
    end

    checks_run++;

    for (int k = 0; k < MAX_FFT_N; k++) begin
      if (t.data_re[k] !== EXP_RE || t.data_im[k] !== EXP_IM) begin
        mismatches++;
        // First few mismatches are enough to diagnose; suppress the rest to
        // keep the log readable if the whole array is off by a scale factor.
        if (mismatches <= 4)
          `uvm_error(get_type_name(),
                     $sformatf("bin[%0d] mismatch: got (%0d,%0d)  expected (%0d,%0d)",
                               k, t.data_re[k], t.data_im[k], EXP_RE, EXP_IM))
      end
    end

    if (mismatches == 0) begin
      checks_passed++;
      `uvm_info(get_type_name(),
                $sformatf("SCOREBOARD PASS: %0d/%0d bins match", MAX_FFT_N, MAX_FFT_N),
                UVM_LOW)
    end else begin
      checks_failed++;
      `uvm_error(get_type_name(),
                 $sformatf("SCOREBOARD FAIL: %0d/%0d bins mismatched",
                           mismatches, MAX_FFT_N))
    end
  endfunction

  // --------------------------------------------------------------------------
  // is_impulse — x[0]=1, all other samples and all imag parts zero.
  // --------------------------------------------------------------------------
  function bit is_impulse(fft_input_txn t);
    if (t.data_re[0] !== 1) return 1'b0;
    if (t.data_im[0] !== 0) return 1'b0;
    for (int i = 1; i < MAX_FFT_N; i++) begin
      if (t.data_re[i] !== 0) return 1'b0;
      if (t.data_im[i] !== 0) return 1'b0;
    end
    return 1'b1;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("scoreboard summary: run=%0d pass=%0d fail=%0d",
                        checks_run, checks_passed, checks_failed),
              UVM_NONE)
  endfunction

endclass
