// fft_ref.h — C reference model for the 32-point FFT scoreboard.
//
// Pure double-precision DIT radix-2. Used by the UVM scoreboard via DPI-C
// to compute the mathematically ideal output for a given input vector.

#ifndef FFT_REF_H
#define FFT_REF_H

#define FFT_N 32

// In-place-safe FFT: caller passes 4 arrays of length FFT_N.
// Twiddles are NOT a parameter — the model uses ideal cos/sin so it
// represents mathematical truth, not the RTL's quantized datapath.
void fft_ref_radix2_dit(const double *in_re, const double *in_im,
                        double *out_re,      double *out_im);

#endif
