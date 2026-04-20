// fft_sequencer.sv — Sequencer for fft_input_txn
//
// A concrete subclass (rather than a typedef) so the factory can create it
// by name and the hierarchy shows a readable component type.

import fft_txn_pkg::*;

class fft_sequencer extends uvm_sequencer #(fft_input_txn);

  `uvm_component_utils(fft_sequencer)

  function new(string name = "fft_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass
