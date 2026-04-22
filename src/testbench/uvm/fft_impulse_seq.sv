// fft_impulse_seq.sv — Directed impulse stimulus.
//
// x[0] = 1, x[1..31] = 0, all imag = 0.
// Twiddles initialised to Q12 unit-circle values: tw_re[i]=cos(2πi/32)*4096,
// tw_im[i]=-sin(2πi/32)*4096 (matches the conventional DFT twiddle sign).
// For a pure impulse the twiddles don't actually affect the answer (they
// only multiply zero-valued lanes), but the RTL still requires legal values.

import fft_txn_pkg::*;

class fft_impulse_seq extends uvm_sequence #(fft_input_txn);

  `uvm_object_utils(fft_impulse_seq)

  function new(string name = "fft_impulse_seq");
    super.new(name);
  endfunction

  task body();
    fft_input_txn tx;
    real pi, theta;
    pi = 3.14159265358979323846;

    tx = fft_input_txn::type_id::create("tx");

    // Impulse sample vector.
    for (int k = 0; k < MAX_FFT_N; k++) begin
      tx.data_re[k] = (k == 0) ? 24'sd1 : 24'sd0;
      tx.data_im[k] = 24'sd0;
    end

    // Q12 twiddles. $rtoi($floor(x+0.5)) = round-to-nearest integer.
    for (int i = 0; i < NUM_TW; i++) begin
      theta = 2.0 * pi * i / 32.0;
      tx.tw_re[i] = $rtoi($floor( $cos(theta) * 4096.0 + 0.5));
      tx.tw_im[i] = $rtoi($floor(-$sin(theta) * 4096.0 + 0.5));
    end

    tx.number_data = 32;
    tx.fft_stages  = 5;

    // Directed vector: skip randomize() entirely — we want exactly these
    // values, not whatever the constraint solver might pick.
    start_item(tx);
    finish_item(tx);
  endtask

endclass
