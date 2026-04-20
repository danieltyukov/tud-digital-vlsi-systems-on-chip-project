// fft_base_test.sv — Minimal UVM test to prove the flow compiles and runs
//
// Every UVM testbench needs at least one class extending uvm_test.
// run_test("+UVM_TESTNAME=fft_base_test") will factory-create this class,
// execute its phases, and shut down.

import fft_txn_pkg::*;

class fft_base_test extends uvm_test;

  // Register with the UVM factory so run_test() can create it by name
  `uvm_component_utils(fft_base_test)

  function new(string name = "fft_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // run_phase is the main time-consuming phase.
  // We must raise/drop an objection — without it UVM exits immediately.
  virtual task run_phase(uvm_phase phase);
    fft_input_txn  in_txn;
    fft_output_txn out_txn;

    phase.raise_objection(this);

    // --- Smoke test: randomize and print input transaction ---
    in_txn = fft_input_txn::type_id::create("in_txn");
    assert(in_txn.randomize()) else `uvm_fatal("RAND", "fft_input_txn randomize failed")
    `uvm_info(get_type_name(), {"Randomized input:\n", in_txn.convert2string()}, UVM_LOW)
    in_txn.print();

    // --- Smoke test: create and print output transaction ---
    out_txn = fft_output_txn::type_id::create("out_txn");
    out_txn.fft_finished = 1;
    out_txn.data_re[0] = 24'sd1000;
    out_txn.data_im[0] = -24'sd500;
    `uvm_info(get_type_name(), {"Output sample:\n", out_txn.convert2string()}, UVM_LOW)
    out_txn.print();

    #100ns;
    phase.drop_objection(this);
  endtask

endclass
