// fft_env.sv — Top-level UVM environment.
//
// Owns the stimulus agent and the scoreboard. The env is where cross-
// component wiring lives; agent and scoreboard stay unaware of each other's
// existence beyond the analysis-port contract.

import fft_txn_pkg::*;

class fft_env extends uvm_env;

  `uvm_component_utils(fft_env)

  fft_agent      agt;
  fft_scoreboard sb;

  function new(string name = "fft_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = fft_agent     ::type_id::create("agt", this);
    sb  = fft_scoreboard::type_id::create("sb",  this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Publisher (monitor) → subscriber (scoreboard). Loose coupling via
    // analysis ports: either side can change independently as long as the
    // transaction types remain stable.
    agt.mon.ap_in .connect(sb.in_imp);
    agt.mon.ap_out.connect(sb.out_imp);
  endfunction

endclass
