// tb_top.sv — Non-UVM top-level module
//
// Responsibilities (standard UVM harness pattern):
//   1. Generate clock and reset
//   2. Instantiate the interface
//   3. Instantiate the DUT and wire it to the interface
//   4. Store virtual interface handle into uvm_config_db
//   5. Call run_test() to hand control to the UVM phasing engine

`timescale 1ns/1ps

// Import UVM base library — gives us uvm_config_db, run_test(), etc.
import uvm_pkg::*;
`include "uvm_macros.svh"

// Transaction package — must be compiled before anything that uses it.
`include "fft_txn_pkg.sv"

// UVM component hierarchy, in dependency order.
// (driver/sequencer/monitor before agent; agent+scoreboard before env;
//  sequences and tests last.)
`include "fft_driver.sv"
`include "fft_sequencer.sv"
`include "fft_monitor.sv"
`include "fft_scoreboard.sv"
`include "fft_agent.sv"
`include "fft_env.sv"
`include "fft_smoke_seq.sv"
`include "fft_smoke_test.sv"
`include "fft_impulse_seq.sv"
`include "fft_impulse_test.sv"
`include "fft_random_seq.sv"
`include "fft_random_test.sv"

// Kept for the original smoke check (+UVM_TESTNAME=fft_base_test).
`include "fft_base_test.sv"

module tb_top;

  // ---------------------------------------------------------------
  // 1. Clock and reset generation
  // ---------------------------------------------------------------
  localparam CLK_PERIOD = 20;  // 50 MHz, same order as real SoC (12 MHz)

  logic clk;
  logic resetn;

  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    resetn = 1'b0;             // assert reset (active-low)
    #(CLK_PERIOD * 5);        // hold for 5 cycles
    resetn = 1'b1;             // release reset
  end

  // ---------------------------------------------------------------
  // 2. Instantiate the interface — clk/resetn driven from above
  // ---------------------------------------------------------------
  fft_if vif(.clk(clk), .resetn(resetn));

  // ---------------------------------------------------------------
  // 3. Instantiate the DUT — connect iomem bus to the interface
  // ---------------------------------------------------------------
  accelerator dut (
    .clk          (clk),
    .resetn       (resetn),
    .iomem_valid  (vif.iomem_valid),
    .iomem_ready  (vif.iomem_ready),
    .iomem_wstrb  (vif.iomem_wstrb),
    .iomem_addr   (vif.iomem_addr),
    .iomem_wdata  (vif.iomem_wdata),
    .iomem_rdata  (vif.iomem_rdata)
  );

  // ---------------------------------------------------------------
  // 4-5. Pass virtual interface to UVM world and start test
  // ---------------------------------------------------------------
  initial begin
    // Store the interface handle where any UVM component can retrieve it.
    // Key "vif" must match the string used in agent's build_phase get().
    uvm_config_db#(virtual fft_if)::set(
      null,    // context: null = visible globally
      "*",     // inst_name wildcard: all components can see it
      "vif",   // field name: lookup key
      vif      // value: the actual interface instance
    );

    // UVM reads +UVM_TESTNAME from the command line, factory-creates
    // that test class, and runs all phases to completion.
    run_test();
  end

endmodule
