// fft_env.sv — Top-level UVM environment.
//
// Owns the stimulus agent and the scoreboard. The env is where cross-
// component wiring lives; agent and scoreboard stay unaware of each other's
// existence beyond the analysis-port contract.

import fft_txn_pkg::*;

class fft_env extends uvm_env;

  `uvm_component_utils(fft_env)

  fft_agent        agt;
  fft_scoreboard   sb;
  fft_coverage     cov;     // input-side functional coverage subscriber
  fft_fsm_coverage fsm_cov; // white-box FSM state/transition coverage

  function new(string name = "fft_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt     = fft_agent       ::type_id::create("agt",     this);
    sb      = fft_scoreboard  ::type_id::create("sb",      this);
    cov     = fft_coverage    ::type_id::create("cov",     this);
    fsm_cov = fft_fsm_coverage::type_id::create("fsm_cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Publisher (monitor) → subscriber (scoreboard). Loose coupling via
    // analysis ports: either side can change independently as long as the
    // transaction types remain stable.
    agt.mon.ap_in .connect(sb.in_imp);
    agt.mon.ap_out.connect(sb.out_imp);

    // Same monitor ports also feed the coverage subscriber. Multiple
    // analysis_imp's can attach to the same analysis_port — UVM broadcasts
    // each write() to every connected subscriber.
    agt.mon.ap_in .connect(cov.ap_cov_in_imp);
    agt.mon.ap_out.connect(cov.ap_cov_out_imp);
    // fsm_cov samples directly off vif.clk, no analysis-port wiring needed.
  endfunction

endclass
