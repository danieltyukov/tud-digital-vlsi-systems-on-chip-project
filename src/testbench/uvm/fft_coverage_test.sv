// fft_coverage_test.sv — Coverage-closure regression.
//
// Strategy:
//   1. Run fft_pattern_seq once to hit ALL_ZERO / DC / IMPULSE corners that
//      random stimulus practically never reaches.
//   2. Run fft_random_seq num_iters=1 in a loop, with a 50us drain between
//      iterations (same cadence as fft_random_test). N defaults to 500;
//      override with +N_RAND=<count>.
//   3. Some iterations are intentionally back-to-back (no drain) so cp_b2b's
//      'b2b' bin gets covered. We do this by issuing pairs every K steps.
//
// PASS criterion: scoreboard reports run==expected and fail==0; coverage
// numbers printed in report_phase by fft_coverage / fft_fsm_coverage.

import fft_txn_pkg::*;

class fft_coverage_test extends uvm_test;

  `uvm_component_utils(fft_coverage_test)

  fft_env env;

  function new(string name = "fft_coverage_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fft_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    fft_pattern_seq pseq;
    fft_random_seq  rseq;
    int N = 500;

    void'($value$plusargs("N_RAND=%d", N));

    phase.raise_objection(this);

    `uvm_info(get_type_name(),
              $sformatf("coverage regression: 3 directed + %0d random", N),
              UVM_LOW)

    // --- Phase 1: directed patterns -------------------------------------
    // Run the directed sequence 5× so each <pattern, range> cross bin gets
    // multiple hits — protects against single-sample flukes and gives
    // healthier counts in the HTML report.
    repeat (5) begin
      pseq = fft_pattern_seq::type_id::create("pseq");
      pseq.start(env.agt.seqr);
      // No extra drain here — pseq.body() inserts a #50us drain after
      // every FFT it drives (see fft_pattern_seq.sv).
    end

    // --- Phase 2: random regression with periodic back-to-back pairs ----
    // Every 10th iteration uses a SHORT (but FFT-completion-safe) drain so
    // the next FFT is issued promptly after the previous one finishes —
    // covers cp_b2b.b2b. The wait must be ≥ FFT runtime (~4us) otherwise
    // the next iteration's reset_accel pulse aborts the previous FFT mid-
    // flight and finished_accel never rises, leaving last_finish_time
    // stale and the b2b heuristic blind. #10us gives ~6us of true idle
    // after completion, well below B2B_THRESHOLD_NS = 15us.
    for (int i = 0; i < N; i++) begin
      rseq = fft_random_seq::type_id::create($sformatf("rseq_%0d", i));
      if (!rseq.randomize() with { num_iters == 1; })
        `uvm_fatal("RAND", "fft_random_seq randomize failed")
      rseq.start(env.agt.seqr);

      if ((i % 10) == 9) #10us;  // tight: FFT completes, then short idle → b2b
      else               #50us;  // normal drain
    end

    phase.drop_objection(this);
  endtask

endclass
