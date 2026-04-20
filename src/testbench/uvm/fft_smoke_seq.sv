// fft_smoke_seq.sv — One-shot sequence: fire a single randomized fft_input_txn
//
// Smallest sequence that exercises the full driver path. Later sequences
// (back-to-back, corner-case stimulus, etc.) will replace or extend this.

import fft_txn_pkg::*;

class fft_smoke_seq extends uvm_sequence #(fft_input_txn);

  `uvm_object_utils(fft_smoke_seq)

  function new(string name = "fft_smoke_seq");
    super.new(name);
  endfunction

  task body();
    fft_input_txn tx;
    tx = fft_input_txn::type_id::create("tx");
    start_item(tx);
    if (!tx.randomize())
      `uvm_fatal("RAND", "fft_input_txn randomize failed")
    finish_item(tx);
  endtask

endclass
