// fft_env.sv — Top-level UVM environment
//
// Currently contains only the stimulus agent. Scoreboard and coverage
// components slot in here as the TB grows.

import fft_txn_pkg::*;

class fft_env extends uvm_env;

  `uvm_component_utils(fft_env)

  fft_agent agt;

  function new(string name = "fft_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = fft_agent::type_id::create("agt", this);
  endfunction

endclass
