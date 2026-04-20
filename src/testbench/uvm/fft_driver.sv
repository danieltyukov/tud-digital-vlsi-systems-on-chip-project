// fft_driver.sv — UVM driver for the accelerator iomem bus
//
// Consumes fft_input_txn from the sequencer and plays out the full
// CPU-side programming sequence over the iomem valid/ready protocol:
//   1. pulse reset_accel via CSR[0]
//   2. write number_data, fft_stages to CSR[1..2]
//   3. write 16 packed twiddles to CSR[3..18]
//   4. write 32 complex samples (64 words) to the data memory region
//   5. assert enable_accel via CSR[0]

import fft_txn_pkg::*;

class fft_driver extends uvm_driver #(fft_input_txn);

  `uvm_component_utils(fft_driver)

  virtual fft_if vif;

  // Memory map — mirrors accelerator.v decode ([31:24]==0x03, word-aligned)
  localparam bit [31:0] BASE     = 32'h0300_0000;
  localparam int        NUM_REGS = 19;                        // 3 cfg + 16 tw
  localparam bit [31:0] MEM_BASE = BASE + (NUM_REGS << 2);    // 0x0300_004C

  // CSR[0] bit fields (must match firmware MASK_CSR_RESET / MASK_CSR_ENABLE)
  localparam bit [31:0] MASK_RESET  = 32'h0000_0001;
  localparam bit [31:0] MASK_ENABLE = 32'h0000_0002;

  function new(string name = "fft_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fft_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual fft_if not set via uvm_config_db")
  endfunction

  task run_phase(uvm_phase phase);
    // Park bus at idle before reset releases — keeps iomem_valid out of X.
    vif.iomem_valid <= 1'b0;
    vif.iomem_wstrb <= 4'b0000;
    vif.iomem_addr  <= 32'd0;
    vif.iomem_wdata <= 32'd0;

    wait (vif.resetn === 1'b1);
    @(posedge vif.clk);
    `uvm_info(get_type_name(), "reset released — driver ready", UVM_LOW)

    forever begin
      fft_input_txn tx;
      seq_item_port.get_next_item(tx);
      `uvm_info(get_type_name(), {"driving:\n", tx.convert2string()}, UVM_LOW)
      drive_transaction(tx);
      seq_item_port.item_done();
    end
  endtask

  // -------------------------------------------------------------------------
  // do_write — one iomem write with valid/ready handshake.
  //   Present valid+addr+wdata+wstrb on a clock edge, wait for ready to
  //   sample high, then drop valid and the write strobe.
  // -------------------------------------------------------------------------
  task do_write(input bit [31:0] byte_addr,
                input bit [31:0] wdata,
                input bit [ 3:0] wstrb = 4'hF);
    @(posedge vif.clk);
    vif.iomem_valid <= 1'b1;
    vif.iomem_addr  <= byte_addr;
    vif.iomem_wdata <= wdata;
    vif.iomem_wstrb <= wstrb;

    do @(posedge vif.clk); while (vif.iomem_ready !== 1'b1);

    vif.iomem_valid <= 1'b0;
    vif.iomem_wstrb <= 4'b0000;
  endtask

  // -------------------------------------------------------------------------
  // drive_transaction — five-phase CPU programming sequence
  // -------------------------------------------------------------------------
  task drive_transaction(fft_input_txn tx);
    bit [31:0] packed_tw;
    bit [31:0] re_word, im_word;

    `uvm_info(get_type_name(), "phase 1: pulse reset_accel", UVM_MEDIUM)
    do_write(BASE + 32'h0, MASK_RESET);   // reset_accel = 1
    do_write(BASE + 32'h0, 32'h0);        // reset_accel = 0

    `uvm_info(get_type_name(), "phase 2: write config (N, stages)", UVM_MEDIUM)
    do_write(BASE + 32'h4, tx.number_data);
    do_write(BASE + 32'h8, {27'd0, tx.fft_stages});

    `uvm_info(get_type_name(), "phase 3: write 16 packed twiddles", UVM_MEDIUM)
    for (int i = 0; i < 16; i++) begin
      // RTL unpacks CSR[3+i] as {tw_im[15:0], tw_re[15:0]} — see accelerator.v:105
      packed_tw = { tx.tw_im[i][15:0], tx.tw_re[i][15:0] };
      do_write(BASE + 32'h0C + (i << 2), packed_tw);
    end

    `uvm_info(get_type_name(), "phase 4: write 32 complex samples", UVM_MEDIUM)
    for (int k = 0; k < 32; k++) begin
      // Sign-extend 24→32 so the low 24 bits land intact in the 24-bit SRAM word.
      // SRAM layout: re at word 2k, im at word 2k+1 (no bit-reverse here —
      // predictor/scoreboard owns that convention).
      re_word = { {8{tx.data_re[k][23]}}, tx.data_re[k] };
      im_word = { {8{tx.data_im[k][23]}}, tx.data_im[k] };
      do_write(MEM_BASE + ((2*k    ) << 2), re_word);
      do_write(MEM_BASE + ((2*k + 1) << 2), im_word);
    end

    `uvm_info(get_type_name(), "phase 5: assert enable_accel", UVM_MEDIUM)
    do_write(BASE + 32'h0, MASK_ENABLE);

    `uvm_info(get_type_name(), "drive_transaction done", UVM_LOW)
  endtask

endclass
