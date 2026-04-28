// fft_random_seq.sv — Constrained-random stimulus sequence.
//
// Randomizes data_re/data_im per fft_input_txn's NORMAL/BOUNDARY dist
// constraints, but assigns Q12 unit-circle twiddles deterministically.
// Twiddles are NOT randomized: only 16 specific (re, im) pairs are valid
// (one per phase index), and the C reference uses ideal twiddles, so any
// off-circle value would diverge on every bin.

import fft_txn_pkg::*;

class fft_random_seq extends uvm_sequence #(fft_input_txn);

  `uvm_object_utils(fft_random_seq)

  // How many transactions this sequence emits per start(). Tests that need
  // a 50us settle between FFTs constrain this to 1 and loop in the test.
  rand int unsigned num_iters;
  constraint c_iters { num_iters inside {[1 : 200]}; }

  function new(string name = "fft_random_seq");
    super.new(name);
  endfunction

  task body();
    fft_input_txn tx;
    real pi, theta;
    pi = 3.14159265358979323846;

    for (int n = 0; n < num_iters; n++) begin
      tx = fft_input_txn::type_id::create($sformatf("tx_%0d", n));

      // Freeze twiddles before randomize() — solver skips them, and the
      // tw_range constraint becomes a no-op for these fields.
      tx.tw_re.rand_mode(0);
      tx.tw_im.rand_mode(0);

      if (!tx.randomize())
        `uvm_fatal("RAND", "fft_input_txn randomize failed")

      // Q12 unit-circle twiddles: tw_re=cos(2πi/32)·4096, tw_im=-sin(...)·4096.
      // Same values as fft_impulse_seq — must match what the C reference assumes.
      for (int i = 0; i < NUM_TW; i++) begin
        theta = 2.0 * pi * i / 32.0;
        tx.tw_re[i] = $rtoi($floor( $cos(theta) * 4096.0 + 0.5));
        tx.tw_im[i] = $rtoi($floor(-$sin(theta) * 4096.0 + 0.5));
      end

      // Pattern classification used to live here, but the monitor rebuilds
      // the txn from bus traffic and publishes a fresh object — so any
      // pattern set here was lost. Classification now lives in the monitor.
      start_item(tx);
      finish_item(tx);
    end
  endtask

endclass
