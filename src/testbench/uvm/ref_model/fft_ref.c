// fft_ref.c — Textbook 32-point DIT radix-2 FFT in double precision.
//
// Used as the golden reference inside the UVM scoreboard. Twiddles are
// computed on the fly from cos/sin (not the RTL's Q12 table) so this
// model is independent of any RTL quantization choice.

#include <math.h>
#include "fft_ref.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Bit-reverse 'x' across 'bits' bits. For N=32 we need 5-bit reversal.
static unsigned bit_reverse(unsigned x, int bits) {
    unsigned r = 0;
    for (int i = 0; i < bits; i++) {
        r = (r << 1) | (x & 1u);
        x >>= 1;
    }
    return r;
}

void fft_ref_radix2_dit(const double *in_re, const double *in_im,
                        double *out_re,      double *out_im) {
    const int N    = FFT_N;
    const int LOG2 = 5;            // log2(32)

    // Stage 0: bit-reversed copy of the input — DIT requires inputs to
    // start in bit-reversed order so butterflies can write naturally.
    for (int i = 0; i < N; i++) {
        unsigned j = bit_reverse((unsigned)i, LOG2);
        out_re[i] = in_re[j];
        out_im[i] = in_im[j];
    }

    // Stages 1..LOG2: butterflies of size 2, 4, 8, 16, 32.
    // 'm' is the current butterfly span; 'half' is its half (= twiddle stride).
    for (int s = 1; s <= LOG2; s++) {
        int m    = 1 << s;          // butterfly size
        int half = m >> 1;          // == 2^(s-1)
        // Principal twiddle for this stage: W_m = exp(-j*2*pi/m)
        double theta = -2.0 * M_PI / (double)m;
        double wpr   = cos(theta);  // step factor (real)
        double wpi   = sin(theta);  // step factor (imag)

        for (int k = 0; k < N; k += m) {
            double wr = 1.0, wi = 0.0;  // running twiddle, reset per group
            for (int j = 0; j < half; j++) {
                int    i0 = k + j;
                int    i1 = i0 + half;
                // t = W * out[i1]  (complex multiply)
                double tr = wr * out_re[i1] - wi * out_im[i1];
                double ti = wr * out_im[i1] + wi * out_re[i1];
                // butterfly: out[i1] = out[i0] - t ; out[i0] = out[i0] + t
                out_re[i1] = out_re[i0] - tr;
                out_im[i1] = out_im[i0] - ti;
                out_re[i0] = out_re[i0] + tr;
                out_im[i0] = out_im[i0] + ti;
                // advance twiddle: W *= W_m
                double nwr = wr * wpr - wi * wpi;
                double nwi = wr * wpi + wi * wpr;
                wr = nwr;
                wi = nwi;
            }
        }
    }
}
