// fft_ref_selftest.c — Standalone sanity check for the C reference.
// Build:  gcc -O2 fft_ref.c fft_ref_selftest.c -o fft_selftest -lm
// Expect: impulse → all bins (1, 0); cos(2*pi*n/32) → bin1=bin31=16, rest~0.

#include <math.h>
#include <stdio.h>
#include "fft_ref.h"

int main(void) {
    double in_re[FFT_N], in_im[FFT_N];
    double out_re[FFT_N], out_im[FFT_N];

    // Test 1: impulse
    for (int i = 0; i < FFT_N; i++) { in_re[i] = (i == 0) ? 1.0 : 0.0; in_im[i] = 0.0; }
    fft_ref_radix2_dit(in_re, in_im, out_re, out_im);
    printf("Impulse:\n");
    for (int k = 0; k < FFT_N; k++)
        printf("  bin[%2d] = (%+.4f, %+.4f)\n", k, out_re[k], out_im[k]);

    // Test 2: single-bin cosine
    for (int i = 0; i < FFT_N; i++) {
        in_re[i] = cos(2.0 * M_PI * (double)i / (double)FFT_N);
        in_im[i] = 0.0;
    }
    fft_ref_radix2_dit(in_re, in_im, out_re, out_im);
    printf("\nCos(2*pi*n/32):\n");
    for (int k = 0; k < FFT_N; k++)
        printf("  bin[%2d] = (%+.4f, %+.4f)\n", k, out_re[k], out_im[k]);

    return 0;
}
