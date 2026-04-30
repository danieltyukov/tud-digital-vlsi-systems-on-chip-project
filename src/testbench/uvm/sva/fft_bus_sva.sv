// fft_bus_sva.sv — CPU↔accelerator memory access mutex (Assertion A2).
//
// Bound to module `accelerator` so it sees the iomem bus ports and the
// CSR-decoded `enable_accel` (= iomem_accel[0][1]) without hierarchical refs.

module fft_bus_sva (
    input logic        clk,
    input logic        resetn,
    input logic        enable_accel,
    input logic        iomem_valid,
    input logic [ 3:0] iomem_wstrb,
    input logic [31:0] iomem_addr
);

  // Mirrors the decode in accelerator.v exactly (top byte == 0x03,
  // word index >= NUM_REGS = 19, any byte-strobe high → CPU write).
  localparam int NUM_REGS = 19;

  wire cpu_write_to_data_mem =
         iomem_valid
      && (|iomem_wstrb)
      && (iomem_addr[31:24] == 8'h03)
      && ((iomem_addr[23:2]) >= NUM_REGS[21:0]);

  // A2 — While the accelerator is enabled, the CPU must not write the
  // shared data memory. The wide FFT port skips arbitration based on
  // this protocol contract; violating it = silent data corruption.
  property p_no_cpu_write_during_accel;
    @(posedge clk) disable iff (!resetn)
      enable_accel |-> !cpu_write_to_data_mem;
  endproperty

  a_no_cpu_write_during_accel:
    assert property (p_no_cpu_write_during_accel)
    else $error("A2 violated: CPU write to data mem at addr=0x%08h with enable_accel=1",
                iomem_addr);

  c_no_cpu_write_during_accel:
    cover property (@(posedge clk) disable iff (!resetn)
                    enable_accel ##0 (iomem_valid && (iomem_addr[31:24] == 8'h03)));

endmodule
