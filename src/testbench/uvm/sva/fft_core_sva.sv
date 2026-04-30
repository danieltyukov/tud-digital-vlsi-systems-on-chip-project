// fft_core_sva.sv — Internal protocol assertions for accelerator_fft.
//
// Bound to `accelerator_fft`, so all signals are local-scope identifiers.
// FSM encoding is re-declared locally (not imported) — gives a checked
// redundancy: if the RTL renumbers the states without updating here, A3
// will fire.

module fft_core_sva (
    input logic       clk,
    input logic       resetn,
    input logic       enable_accel,
    input logic       fft_finished,
    input logic [2:0] state_reg,
    input logic [2:0] pipe_vld
);

  localparam [2:0] S_INIT       = 3'd0,
                   S_LOAD_DATA  = 3'd1,
                   S_COMPUTE    = 3'd2,
                   S_STORE_DATA = 3'd3,
                   S_FINISH     = 3'd4;

  // -------------------------------------------------------------------------
  // A1 — Finished/enable handshake, split into two sub-properties:
  //   A1a: fft_finished rises only in S_FINISH (no spurious pulse).
  //   A1b: S_FINISH + !enable_accel → S_INIT in exactly one cycle.
  // -------------------------------------------------------------------------
  property p_finished_only_in_finish;
    @(posedge clk) disable iff (!resetn)
      $rose(fft_finished) |-> (state_reg == S_FINISH);
  endproperty

  property p_finish_to_init_on_disable;
    @(posedge clk) disable iff (!resetn)
      ((state_reg == S_FINISH) && !enable_accel) |=> (state_reg == S_INIT);
  endproperty

  a_finished_only_in_finish:
    assert property (p_finished_only_in_finish)
    else $error("A1a: fft_finished rose with state_reg=%0d (expected S_FINISH=4)", state_reg);

  a_finish_to_init_on_disable:
    assert property (p_finish_to_init_on_disable)
    else $error("A1b: S_FINISH + !enable_accel did not transition to S_INIT next cycle");

  c_finish_disable_handshake:
    cover property (@(posedge clk) disable iff (!resetn)
                    $rose(fft_finished) ##1 !enable_accel);

  // -------------------------------------------------------------------------
  // A3 — FSM state always in the legal set {0..4}.
  // `inside` returns false on X bits, so this also catches X-propagation
  // through the FSM in gate-level sim.
  // -------------------------------------------------------------------------
  property p_fsm_state_defined;
    @(posedge clk) disable iff (!resetn)
      state_reg inside {S_INIT, S_LOAD_DATA, S_COMPUTE, S_STORE_DATA, S_FINISH};
  endproperty

  a_fsm_state_defined:
    assert property (p_fsm_state_defined)
    else $error("A3: state_reg = %0b is not a legal FSM encoding", state_reg);

  // -------------------------------------------------------------------------
  // A4 — Pipeline shift register drained on COMPUTE exit.
  // Exit condition `pipe_last_drain && stage_is_last` fires when
  // pipe_vld == 3'b100 and pump==0; on the next clock edge pipe_vld
  // shifts to 000 simultaneously with state_reg becoming S_STORE_DATA.
  // -------------------------------------------------------------------------
  property p_pipe_drained_after_compute;
    @(posedge clk) disable iff (!resetn)
      $fell(state_reg == S_COMPUTE) |-> (pipe_vld == 3'b000);
  endproperty

  a_pipe_drained_after_compute:
    assert property (p_pipe_drained_after_compute)
    else $error("A4: pipe_vld=%0b on COMPUTE exit (expected 000)", pipe_vld);

  c_pipe_drained_after_compute:
    cover property (@(posedge clk) disable iff (!resetn)
                    $fell(state_reg == S_COMPUTE));

endmodule
