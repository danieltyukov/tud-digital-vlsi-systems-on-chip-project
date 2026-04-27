// fft_dpi.svh — DPI-C imports for the C reference model.
//
// Included from exactly one site (fft_scoreboard.sv). DPI imports have
// global scope, so duplicating the include across compilation units
// triggers Questa "function already imported" warnings — keep it single-
// sourced.
//
// Fixed-size arrays match the C signature 'double in_re[32], ...':
// Questa marshals these as plain C double pointers (no svOpenArrayHandle
// needed). N is hard-locked to 32 in the RTL, so this coupling is fine.

`ifndef FFT_DPI_SVH
`define FFT_DPI_SVH

import "DPI-C" function void fft_ref_radix2_dit(
    input  real in_re  [32],
    input  real in_im  [32],
    output real out_re [32],
    output real out_im [32]
);

`endif
