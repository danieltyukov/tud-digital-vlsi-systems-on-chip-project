// fft_sva_bind.sv — Compile-time attachment of SVA modules to the DUT.
// Including this from tb_top.sv is the single line needed to enable SVA.

`include "sva/fft_bus_sva.sv"
`include "sva/fft_core_sva.sv"

bind accelerator fft_bus_sva u_bus_sva (
    .clk          (clk),
    .resetn       (resetn),
    .enable_accel (enable_accel),
    .iomem_valid  (iomem_valid),
    .iomem_wstrb  (iomem_wstrb),
    .iomem_addr   (iomem_addr)
);

bind accelerator_fft fft_core_sva u_core_sva (
    .clk          (clk),
    .resetn       (resetn),
    .enable_accel (enable_accel),
    .fft_finished (fft_finished),
    .state_reg    (state_reg),
    .pipe_vld     (pipe_vld)
);
