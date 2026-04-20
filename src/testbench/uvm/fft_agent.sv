// fft_agent.sv — UVM agent wrapping driver + sequencer
//
// Monitor will be added in a later step. Always-active for now: there is
// only one stimulus source (the CPU side), so passive mode is not useful.

import fft_txn_pkg::*;

class fft_agent extends uvm_agent;

  `uvm_component_utils(fft_agent)

  fft_driver    drv;
  fft_sequencer seqr;

  function new(string name = "fft_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv  = fft_driver   ::type_id::create("drv",  this);
    seqr = fft_sequencer::type_id::create("seqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
