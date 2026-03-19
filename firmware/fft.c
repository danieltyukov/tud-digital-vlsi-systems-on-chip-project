#include "fft.h"
#include "uart.h"

static Complex complex_mult(Complex a, Complex b)
{
    Complex result;

    result.real = ( (a.real * b.real) - (a.imag * b.imag) ) >> SCALE; 
    result.imag = ( (a.real * b.imag) + (a.imag * b.real) ) >> SCALE;

    return result;
}

static Complex complex_add(Complex a, Complex b)
{
    Complex result;

    result.real = a.real + b.real;
    result.imag = a.imag + b.imag;

    return result;
}

static Complex complex_sub(Complex a, Complex b)
{
    return complex_add(a, (Complex){.real = -b.real, .imag = -b.imag});
}

int flog2(int x)
{
    int r = 0;

    while (x > 1) {
        x = x >> 1;
        r++;
    }

    return r;
}

int bit_reverse(int x, int bits)
{
    int rev = 0;

    for (int j = 0; j < bits; j++) {
        rev = (rev << 1) | (x & 1);
        x = x >> 1;
    }

    return rev;
}

int digit_reverse_mixed(int x, int bits)
{
    // For mixed radix-4/2: extract base-4 digits (2 bits each) greedily,
    // with a possible base-2 digit (1 bit) if bits is odd.
    // Then reconstruct with digits in reversed order.
    int digits[8];
    int widths[8];
    int n_digits = 0;
    int remaining = bits;

    while (remaining >= 2) {
        digits[n_digits] = x & 3;
        widths[n_digits] = 2;
        x >>= 2;
        remaining -= 2;
        n_digits++;
    }
    if (remaining == 1) {
        digits[n_digits] = x & 1;
        widths[n_digits] = 1;
        n_digits++;
    }

    // Reconstruct in reverse digit order
    int result = 0;
    int shift = 0;
    for (int i = n_digits - 1; i >= 0; i--) {
        result |= digits[i] << shift;
        shift += widths[i];
    }

    return result;
}

void bit_reverse_array(int input[], Complex output[], int n, int bits)
{
    for (int i = 0; i < n; i++) {
        int rev = bit_reverse(i, bits);
        output[rev] = (Complex){.real = input[i], .imag = 0};
    }
}

void fft(Complex x[], Complex twiddles[], int n, int bits) {
    for (int stage = 1; stage < bits + 1; stage++) {
        int m = 1 << stage;
        int half = m / 2;

        Complex w_m = twiddles[stage - 1];

        for (int base = 0; base < n; base += m) {
            Complex w = (Complex){.real = 1 << SCALE, .imag = 0};

            for (int k = 0; k < half; k++) {
                Complex t = complex_mult(w, x[base + k + half]);
                Complex u = x[base + k];

                x[base + k] = complex_add(u, t);
                x[base + k + half] = complex_sub(u, t);

                w = complex_mult(w, w_m);
            }
        }
    }
}
