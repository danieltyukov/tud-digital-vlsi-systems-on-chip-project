// fft_impulse_test.sv — End-to-end directed test.
//
// Runs fft_impulse_seq through the existing driver, then idles long enough
// for the FFT core to finish. Pass/fail is determined by the scoreboard
// via the monitor's analysis ports.

import fft_txn_pkg::*;

class fft_impulse_test extends uvm_test;

  `uvm_component_utils(fft_impulse_test)

  fft_env env;

  function new(string name = "fft_impulse_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fft_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    fft_impulse_seq seq;
    phase.raise_objection(this);

    seq = fft_impulse_seq::type_id::create("seq");
    seq.start(env.agt.seqr);

    // Give the core time to run 32-pt / 5-stage FFT and raise finished_accel.
    // Monitor's output-capture path depends on seeing that rising edge here.
    #50us;

    phase.drop_objection(this);
  endtask

endclass
