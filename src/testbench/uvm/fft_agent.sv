// fft_agent.sv — UVM agent wrapping driver + sequencer + monitor.
//
// Always-active: there is only one stimulus source (the CPU side), so a
// passive-mode variant is not useful here. Monitor runs unconditionally —
// it's how the scoreboard sees what actually reached the DUT.

import fft_txn_pkg::*;

class fft_agent extends uvm_agent;

  `uvm_component_utils(fft_agent)

  fft_driver    drv;
  fft_sequencer seqr;
  fft_monitor   mon;

  function new(string name = "fft_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = fft_driver   ::type_id::create("drv",  this);
    seqr = fft_sequencer::type_id::create("seqr", this);
    mon  = fft_monitor  ::type_id::create("mon",  this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Stimulus path: sequencer → driver.
    drv.seq_item_port.connect(seqr.seq_item_export);
    // Monitor's analysis ports are reached directly by the env via
    //   agt.mon.ap_in / agt.mon.ap_out — no agent-level re-export yet.
  endfunction

endclass
