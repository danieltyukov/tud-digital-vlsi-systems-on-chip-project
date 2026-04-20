// fft_if.sv — SystemVerilog interface for the CPU-side iomem bus
//
// Models the 6 protocol signals at the accelerator module boundary.
// clk/resetn are passed as port inputs so the interface can be
// used for clocking blocks and reset-aware assertions later.

interface fft_if (
    input logic clk,
    input logic resetn
);

  logic        iomem_valid;   // CPU asserts to start a bus transaction
  logic        iomem_ready;   // accelerator asserts to complete the handshake
  logic [ 3:0] iomem_wstrb;   // byte-lane write strobes (0 = read)
  logic [31:0] iomem_addr;    // byte address; accelerator decodes [31:24]==0x03
  logic [31:0] iomem_wdata;   // write data from CPU
  logic [31:0] iomem_rdata;   // read data from accelerator

endinterface
