// fft_smoke_test.sv — End-to-end smoke test for the driver path
//
// Builds the env, starts fft_smoke_seq on the agent's sequencer, then
// idles long enough for the FFT core to finish. No scoreboard yet —
// success criterion is a clean handshake trace and finished_accel=1
// in the waveform.

import fft_txn_pkg::*;

class fft_smoke_test extends uvm_test;

  `uvm_component_utils(fft_smoke_test)

  fft_env env;

  function new(string name = "fft_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fft_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    fft_smoke_seq seq;
    phase.raise_objection(this);

    seq = fft_smoke_seq::type_id::create("seq");
    seq.start(env.agt.seqr);

    // Let the FFT core run after enable. N=32, 5 stages — a few µs is plenty.
    #50us;

    phase.drop_objection(this);
  endtask

endclass
