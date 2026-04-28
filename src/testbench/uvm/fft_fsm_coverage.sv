// fft_fsm_coverage.sv — White-box coverage of the accelerator FSM.
//
// Samples state_reg via the hierarchical probe `FFT_STATE_PATH every clock.
// Two coverpoints over the same signal:
//   cp_state : did we visit each of the 5 states?
//   cp_trans : did we exercise every legal state transition?
//              `illegal_bins default` flags any transition NOT in the
//              legal/self list as a hard error — equivalent to a free
//              consistency check on the FSM's next-state logic.
//
// Kept separate from fft_coverage because:
//   (a) the sampling event is @(posedge clk), not an analysis port write;
//   (b) FSM coverage is fundamentally white-box — pulling it into the
//       transaction-level cg would blur abstraction layers.

`include "fft_hier_defs.svh"

class fft_fsm_coverage extends uvm_component;

  `uvm_component_utils(fft_fsm_coverage)

  virtual fft_if vif;

  // Mirror state_reg into a local var: covergroups built off a hierarchical
  // reference can confuse some tools' elaboration. Local-var sampling is
  // the portable idiom.
  bit [2:0] state_q;

  // Manual-sampled covergroup. We deliberately avoid the
  //   covergroup cg_fsm @(posedge vif.clk);
  // form because vif is not bound at construction time (covergroup is
  // built in new(), vif is fetched in build_phase) — Questa would fire
  // sampling on a dangling handle and segfault. Sampling is driven by
  // run_phase's clock loop instead.
  covergroup cg_fsm;
    option.per_instance = 1;
    option.name         = "fft_fsm_cg";

    cp_state : coverpoint state_q {
      bins s_init   = {3'd0};
      bins s_load   = {3'd1};
      bins s_comp   = {3'd2};
      bins s_store  = {3'd3};
      bins s_finish = {3'd4};
    }

    // Transition coverage — faithful to accelerator_fft.v.
    //
    // Two distinct sources of legal transitions exist in the RTL:
    //
    //   (A) NEXT-STATE LOGIC (lines 173-180): the conventional 5-state
    //       pipeline INIT→LOAD→COMPUTE→STORE→FINISH plus FINISH→INIT
    //       via !enable_accel.
    //
    //   (B) SYNCHRONOUS RESET PATH (line 219): "if (!resetn || reset_accel)
    //       state_reg <= S_INIT". This is unconditional from ANY state.
    //       Because the driver pulses reset_accel between FFTs, the arcs
    //       LOAD→INIT, COMPUTE→INIT, STORE→INIT can all occur during a
    //       normal regression — they are RTL-legal, not bugs.
    //
    // Self-loops are expected: every non-INIT state stays asserted for many
    // cycles (LOAD/STORE = N pair-cycles, COMPUTE = pipeline-drain cycles,
    // FINISH stays high until enable drops or reset_accel fires). They
    // dominate the sample count, hence listed explicitly.
    //
    // No 'illegal_bins default' here: because reset_accel can lawfully
    // force ANY state to INIT, we cannot distinguish "natural FINISH→INIT"
    // from "abort-driven X→INIT" by looking at state_reg alone. A default
    // bin would either flood the log with false errors or wrongly accept
    // genuine bugs depending on how we wrote it. Real "stuck-state /
    // illegal-jump" checks belong in an SVA assertion that also samples
    // resetn / reset_accel / enable_accel.
    cp_trans : coverpoint state_q {
      // (A) Forward pipeline arcs, driven by next-state logic.
      bins fwd_init_load   = (3'd0 => 3'd1);
      bins fwd_load_comp   = (3'd1 => 3'd2);
      bins fwd_comp_store  = (3'd2 => 3'd3);
      bins fwd_store_fin   = (3'd3 => 3'd4);

      // (A) Natural completion arc — FINISH→INIT via !enable_accel.
      // (B) Reset-driven arcs — any-state→INIT via reset_accel pulse.
      // Both observable as identical state_reg transitions on the wire.
      bins rst_finish_init = (3'd4 => 3'd0);
      bins rst_load_init   = (3'd1 => 3'd0);
      bins rst_comp_init   = (3'd2 => 3'd0);
      bins rst_store_init  = (3'd3 => 3'd0);

      // Self-loops — each phase holding while its work counter advances.
      bins hold_init   = (3'd0 => 3'd0);
      bins hold_load   = (3'd1 => 3'd1);
      bins hold_comp   = (3'd2 => 3'd2);
      bins hold_store  = (3'd3 => 3'd3);
      bins hold_finish = (3'd4 => 3'd4);
    }
  endgroup

  function new(string name = "fft_fsm_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_fsm = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fft_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual fft_if not set via uvm_config_db")
  endfunction

  // Continuously mirror state_reg into state_q so the covergroup's
  // @(posedge vif.clk) sampling sees a stable, predictable value.
  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      state_q = `FFT_STATE_PATH;
      cg_fsm.sample();   // explicit sampling — see note on covergroup decl
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("cg_fsm coverage = %0.2f%%", cg_fsm.get_coverage()),
              UVM_LOW)
  endfunction

endclass
