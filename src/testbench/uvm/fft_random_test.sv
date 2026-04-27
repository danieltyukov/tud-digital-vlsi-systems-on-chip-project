// fft_random_test.sv — Constrained-random regression.
//
// Loops fft_random_seq N times (default 100, override with +N_RAND=<int>).
// Each outer iteration drives exactly one FFT, then waits 50us for the
// core to finish before the next — same settle pattern as fft_impulse_test.
// PASS criterion: scoreboard reports run>=N and fail==0.

import fft_txn_pkg::*;

class fft_random_test extends uvm_test;

  `uvm_component_utils(fft_random_test)

  fft_env env;

  function new(string name = "fft_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fft_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    fft_random_seq seq;
    int N = 100;

    // +N_RAND=<count> on the vsim cmdline overrides the default.
    void'($value$plusargs("N_RAND=%d", N));

    phase.raise_objection(this);

    `uvm_info(get_type_name(),
              $sformatf("starting %0d random iterations", N), UVM_LOW)

    for (int i = 0; i < N; i++) begin
      seq = fft_random_seq::type_id::create($sformatf("seq_%0d", i));
      // num_iters==1 so the 50us drain happens between every FFT, not
      // every batch — keeps the in-flight FFT from racing the next stimulus.
      if (!seq.randomize() with { num_iters == 1; })
        `uvm_fatal("RAND", "fft_random_seq randomize failed")
      seq.start(env.agt.seqr);
      #50us;
    end

    phase.drop_objection(this);
  endtask

endclass
