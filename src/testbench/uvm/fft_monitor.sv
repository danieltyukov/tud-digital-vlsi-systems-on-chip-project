// fft_monitor.sv — Passive observer of the iomem bus + FFT-done event.
//
// Publishes two independent transaction streams on analysis ports:
//   ap_in  : one fft_input_txn per run, emitted at the enable_accel write
//   ap_out : one fft_output_txn per run, emitted at finished_accel rising edge
//
// The monitor is intentionally decoupled from the driver: it rebuilds the
// input transaction from bus activity, so driver-side protocol bugs surface
// as mismatches rather than being silently trusted.

`include "fft_hier_defs.svh"

import fft_txn_pkg::*;

class fft_monitor extends uvm_monitor;

  `uvm_component_utils(fft_monitor)

  // ---- Interface + ports ---------------------------------------------------
  virtual fft_if vif;

  uvm_analysis_port #(fft_input_txn)  ap_in;
  uvm_analysis_port #(fft_output_txn) ap_out;

  // ---- Address map (mirrors driver / RTL) ----------------------------------
  localparam bit [31:0] BASE     = 32'h0300_0000;
  localparam int        NUM_CFG  = 3;                   // CSR[0..2]
  localparam int        NUM_REGS = 19;                  // CSR[0..2] + 16 tw
  localparam bit [31:0] MASK_RESET  = 32'h0000_0001;
  localparam bit [31:0] MASK_ENABLE = 32'h0000_0002;

  // ---- Staging buffers — accumulated across the CPU programming phase -----
  // Same shape as fft_input_txn; cleared on reset-write, committed on enable.
  bit signed [DATA_WIDTH-1:0] stg_data_re [MAX_FFT_N];
  bit signed [DATA_WIDTH-1:0] stg_data_im [MAX_FFT_N];
  bit signed [TW_WIDTH-1:0]   stg_tw_re   [NUM_TW];
  bit signed [TW_WIDTH-1:0]   stg_tw_im   [NUM_TW];
  bit [31:0]                  stg_number_data;
  bit [4:0]                   stg_fft_stages;

  function new(string name = "fft_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap_in  = new("ap_in",  this);
    ap_out = new("ap_out", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fft_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual fft_if not set via uvm_config_db")
  endfunction

  // --------------------------------------------------------------------------
  // run_phase — two forked observers, both run forever.
  //   observe_writes    : rebuild input txn from bus writes
  //   observe_finished  : backdoor-read SRAM on finished_accel rising edge
  // --------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    clear_staging();
    fork
      observe_writes();
      observe_finished();
    join_none
  endtask

  // --------------------------------------------------------------------------
  // observe_writes — every bus write with addr[31:24]==0x03 is decoded and
  // routed into staging. A write to CSR[0] with ENABLE bit commits the txn.
  // --------------------------------------------------------------------------
  task observe_writes();
    forever begin
      @(posedge vif.clk);
      // Handshake completes when valid & ready are both high on the edge.
      // wstrb != 0 distinguishes writes from reads.
      if (vif.iomem_valid === 1'b1 &&
          vif.iomem_ready === 1'b1 &&
          vif.iomem_wstrb !== 4'b0000 &&
          vif.iomem_addr[31:24] === 8'h03) begin
        decode_write(vif.iomem_addr, vif.iomem_wdata);
      end
    end
  endtask

  // --------------------------------------------------------------------------
  // decode_write — route one accepted bus write into the right staging slot.
  // Word index w = addr[23:2]:
  //   w==0  ctrl : bit0=reset, bit1=enable
  //   w==1  number_data
  //   w==2  fft_stages
  //   w in [3,18]  twiddle packed as {tw_im[15:0], tw_re[15:0]}
  //   w>=19 data region: sample k = (w-19)/2, even=re, odd=im
  // --------------------------------------------------------------------------
  function void decode_write(bit [31:0] addr, bit [31:0] wdata);
    int w;
    int k;
    w = addr[23:2];

    case (1)
      (w == 0): begin
        // Reset-bit write clears anything partially accumulated from a
        // previous (possibly aborted) programming phase.
        if (wdata & MASK_RESET) begin
          clear_staging();
          `uvm_info(get_type_name(), "observed reset_accel write — staging cleared", UVM_HIGH)
        end
        // Enable-bit write is the commit point: snapshot staging into a fresh
        // fft_input_txn and broadcast on ap_in. All subsequent CSR/mem writes
        // should have already landed (driver always writes enable last).
        if (wdata & MASK_ENABLE) begin
          commit_input_txn();
        end
      end

      (w == 1): stg_number_data = wdata;
      (w == 2): stg_fft_stages  = wdata[4:0];

      (w >= 3 && w < NUM_REGS): begin
        // CSR[3+i] = {tw_im[15:0], tw_re[15:0]} — same packing as driver.
        int ti = w - NUM_CFG;
        stg_tw_re[ti] = wdata[15:0];
        stg_tw_im[ti] = wdata[31:16];
      end

      (w >= NUM_REGS): begin
        // Data region. (w - 19) is the SRAM word index; even=re, odd=im.
        int widx = w - NUM_REGS;
        k = widx >> 1;
        if (k < MAX_FFT_N) begin
          if (widx[0] == 1'b0) stg_data_re[k] = wdata[DATA_WIDTH-1:0];
          else                 stg_data_im[k] = wdata[DATA_WIDTH-1:0];
        end
      end
      default: ; // ignore
    endcase
  endfunction

  // --------------------------------------------------------------------------
  // commit_input_txn — copy staging into a new fft_input_txn and publish.
  // Scoreboard subscribers see this as "a run just started with this input".
  // --------------------------------------------------------------------------
  function void commit_input_txn();
    fft_input_txn txn;
    txn = fft_input_txn::type_id::create("in_txn");
    for (int i = 0; i < MAX_FFT_N; i++) begin
      txn.data_re[i] = stg_data_re[i];
      txn.data_im[i] = stg_data_im[i];
    end
    for (int i = 0; i < NUM_TW; i++) begin
      txn.tw_re[i] = stg_tw_re[i];
      txn.tw_im[i] = stg_tw_im[i];
    end
    txn.number_data = stg_number_data;
    txn.fft_stages  = stg_fft_stages;

    // Classify the rebuilt vector so coverage sees a faithful pattern label.
    // Done here (not in the sequence) because the monitor publishes a fresh
    // object — any tag the sequence set has already been discarded.
    classify_pattern(txn);

    `uvm_info(get_type_name(),
              {"observed enable_accel — publishing input txn\n", txn.convert2string()},
              UVM_LOW)
    ap_in.write(txn);
  endfunction

  function void clear_staging();
    foreach (stg_data_re[i]) stg_data_re[i] = '0;
    foreach (stg_data_im[i]) stg_data_im[i] = '0;
    foreach (stg_tw_re[i])   stg_tw_re[i]   = '0;
    foreach (stg_tw_im[i])   stg_tw_im[i]   = '0;
    stg_number_data = '0;
    stg_fft_stages  = '0;
  endfunction

  // --------------------------------------------------------------------------
  // observe_finished — edge-detect finished_accel via backdoor probe.
  // Waits one extra clock after the edge so the last wide-port SRAM write
  // has definitely committed before we sample.
  // --------------------------------------------------------------------------
  task observe_finished();
    bit prev;
    prev = 1'b0;
    forever begin
      @(posedge vif.clk);
      if (`FFT_FINISHED_PATH === 1'b1 && prev === 1'b0) begin
        @(posedge vif.clk);   // settle cycle — SRAM write uses posedge clk too
        sample_output_txn();
      end
      prev = `FFT_FINISHED_PATH;
    end
  endtask

  // --------------------------------------------------------------------------
  // sample_output_txn — backdoor read of the accelerator's SRAM into a fresh
  // fft_output_txn, then publish on ap_out.
  // --------------------------------------------------------------------------
  function void sample_output_txn();
    fft_output_txn out;
    out = fft_output_txn::type_id::create("out_txn");
    for (int k = 0; k < MAX_FFT_N; k++) begin
      out.data_re[k] = `FFT_MEM_PATH[2*k];
      out.data_im[k] = `FFT_MEM_PATH[2*k + 1];
    end
    out.fft_finished = 1'b1;

    `uvm_info(get_type_name(),
              {"observed finished_accel — publishing output txn\n", out.convert2string()},
              UVM_LOW)
    ap_out.write(out);
  endfunction

endclass
