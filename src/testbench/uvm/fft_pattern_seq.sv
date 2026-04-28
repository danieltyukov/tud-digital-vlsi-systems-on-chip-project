// fft_pattern_seq.sv — Directed sequence that hits the rare semantic bins.
//
// Random + boundary stimulus alone leaves cp_pattern's all_zero / dc / impulse
// bins effectively unreachable: the dist constraints almost never produce a
// vector where every sample is 0 or every sample equals a fixed non-zero
// value. This directed sequence drives one explicit case of each, letting
// cp_pattern converge to 100% in a handful of cycles.
//
// drive_dc() is parameterized over five DC levels so the cross
// cx_pat_range hits all <dc, *> cells. Rail values (±65535) are safe:
// max bin-0 output = 32·65535 ≈ 2.1M, well within signed 24-bit range
// (±2^23 ≈ ±8.4M). See accelerator_fft.v: butterfly is unscaled, only
// the Q12 twiddle product is shifted right by SCALE=12.

import fft_txn_pkg::*;

class fft_pattern_seq extends uvm_sequence #(fft_input_txn);

  `uvm_object_utils(fft_pattern_seq)

  function new(string name = "fft_pattern_seq");
    super.new(name);
  endfunction

  task body();
    // #50us drain after each item: the driver's drive_transaction returns
    // as soon as enable_accel is written and does NOT wait for completion,
    // so back-to-back start_item/finish_item calls would let the next FFT's
    // reset_accel pulse abort the previous one mid-flight (no ap_out, no
    // scoreboard pair). The drain lets each directed FFT finish naturally.
    drive_all_zero();           #50us;
    // Five DC levels, one per cp_data_range bin, so <dc,*> cross bins fill.
    drive_dc( 24'sd500   );     #50us;  // near_zero
    drive_dc( 24'sd16000 );     #50us;  // pos_half
    drive_dc(-24'sd16000 );     #50us;  // neg_half
    drive_dc( 24'sd65535 );     #50us;  // pos_full  (rail; safe — see header)
    drive_dc(-24'sd65536 );     #50us;  // neg_full  (rail)
    drive_impulse();            #50us;
  endtask

  // Helper: load Q12 unit-circle twiddles + N=32 config into a fresh txn.
  function fft_input_txn make_base(string id);
    fft_input_txn tx;
    real pi, theta;
    pi = 3.14159265358979323846;
    tx = fft_input_txn::type_id::create(id);
    for (int i = 0; i < NUM_TW; i++) begin
      theta = 2.0 * pi * i / 32.0;
      tx.tw_re[i] = $rtoi($floor( $cos(theta) * 4096.0 + 0.5));
      tx.tw_im[i] = $rtoi($floor(-$sin(theta) * 4096.0 + 0.5));
    end
    tx.number_data = 32;
    tx.fft_stages  = 5;
    return tx;
  endfunction

  task drive_all_zero();
    fft_input_txn tx = make_base("tx_zero");
    foreach (tx.data_re[k]) begin tx.data_re[k] = 0; tx.data_im[k] = 0; end
    start_item(tx); finish_item(tx);
  endtask

  task drive_dc(bit signed [DATA_WIDTH-1:0] level);
    fft_input_txn tx = make_base($sformatf("tx_dc_%0d", level));
    foreach (tx.data_re[k]) begin tx.data_re[k] = level; tx.data_im[k] = 0; end
    start_item(tx); finish_item(tx);
  endtask

  task drive_impulse();
    fft_input_txn tx = make_base("tx_imp");
    foreach (tx.data_re[k]) begin
      tx.data_re[k] = (k == 0) ? 24'sd32768 : 24'sd0;
      tx.data_im[k] = 0;
    end
    start_item(tx); finish_item(tx);
  endtask

endclass
