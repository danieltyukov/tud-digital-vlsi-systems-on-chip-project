import cmath
import math
from typing import List


SCALE = 12
MAX_N_PER_FFT = 32
TWIDDLES = []


for m in range(1, round(math.log2(MAX_N_PER_FFT)) + 1):
    stage = 1 << m  # m = 2, 4, 8, ..., n
    W = cmath.exp(-2j * cmath.pi / stage)
    W_scaled = complex(round(W.real * (1<<SCALE)), round(W.imag * (1<<SCALE)))
    TWIDDLES.append(W_scaled)


def complex_mult(in1: complex, in2: complex) -> complex:
    a = int(in1.real)
    b = int(in1.imag)
    c = int(in2.real)
    d = int(in2.imag)

    return complex((a * c - b * d) >> SCALE, (a * d + b * c) >> SCALE)


def flog2(x: int) -> int:
    r = 0

    while x > 1:
        r += 1
        x = x >> 1

    return r


def bit_reverse(i: int, bits: int) -> int:
    r: int = 0
    for _ in range(bits):
        r = (r << 1) | (i & 1)
        i >>= 1
    return r


def digit_reverse_mixed(i: int, bits: int) -> int:
    """Mixed-radix digit reversal for radix-4/2 FFT.
    Decomposes index into base-4 digits (2 bits each), with a possible
    base-2 digit (1 bit) at the MSB if bits is odd, then reverses the
    digit order."""
    digits = []
    widths = []
    remaining = bits

    # Extract digits from LSB: greedily take 2-bit (radix-4) digits
    while remaining >= 2:
        digits.append(i & 3)
        widths.append(2)
        i >>= 2
        remaining -= 2

    # If odd bit remains, take 1-bit (radix-2) digit
    if remaining == 1:
        digits.append(i & 1)
        widths.append(1)

    # Reconstruct in reverse digit order
    result = 0
    shift = 0
    for j in range(len(digits) - 1, -1, -1):
        result |= digits[j] << shift
        shift += widths[j]

    return result


def fft(x: List[complex]) -> List[complex]:
    n = len(x)
    bits = flog2(n)

    # Step 1: mixed-radix digit-reversal permutation
    X = [0j] * n

    for i in range(n):
        X[digit_reverse_mixed(i, bits)] = x[i]

    # Step 2: mixed radix-4/2 FFT stages
    log2_m = 0
    while log2_m < bits:
        if bits - log2_m >= 2:
            # ---- Radix-4 stage: consume 2 bits ----
            log2_m += 2
            m = 1 << log2_m
            q = m // 4  # butterflies per group

            w_m = TWIDDLES[log2_m - 1]  # primitive twiddle for this stage
            tw2 = complex_mult(w_m, w_m)
            tw3 = complex_mult(tw2, w_m)

            for base in range(0, n, m):
                w1 = complex(1 << SCALE, 0)
                w2 = complex(1 << SCALE, 0)
                w3 = complex(1 << SCALE, 0)

                for k in range(q):
                    x0 = X[base + k]
                    x1 = X[base + k + q]
                    x2 = X[base + k + 2*q]
                    x3 = X[base + k + 3*q]

                    # 3 complex multiplies
                    t1 = complex_mult(w1, x1)
                    t2 = complex_mult(w2, x2)
                    t3 = complex_mult(w3, x3)

                    # 4-point DFT kernel with j-rotations
                    # X[0] = x0 + t1 + t2 + t3
                    X[base + k]        = x0 + t1 + t2 + t3
                    # X[1] = x0 - j*t1 - t2 + j*t3
                    X[base + k + q]    = complex(
                        x0.real + t1.imag - t2.real - t3.imag,
                        x0.imag - t1.real - t2.imag + t3.real)
                    # X[2] = x0 - t1 + t2 - t3
                    X[base + k + 2*q]  = x0 - t1 + t2 - t3
                    # X[3] = x0 + j*t1 - t2 - j*t3
                    X[base + k + 3*q]  = complex(
                        x0.real - t1.imag - t2.real + t3.imag,
                        x0.imag + t1.real - t2.imag - t3.real)

                    # Advance twiddles
                    w1 = complex_mult(w1, w_m)
                    w2 = complex_mult(w2, tw2)
                    w3 = complex_mult(w3, tw3)
        else:
            # ---- Radix-2 stage: consume 1 bit ----
            log2_m += 1
            m = 1 << log2_m
            half = m // 2

            w_m = TWIDDLES[log2_m - 1]

            for base in range(0, n, m):
                w = complex(1 << SCALE, 0)

                for k in range(half):
                    t = complex_mult(w, X[base + k + half])
                    u = X[base + k]

                    X[base + k]        = u + t
                    X[base + k + half] = u - t

                    w = complex_mult(w, w_m)

    return X


def inv_dft(x: List[complex]) -> List[complex]:
    n = len(x)
    X = [0j] * n

    for k in range(n):
        sum_val = 0j
        for t in range(n):
            angle = 2j * cmath.pi * t * k / n
            sum_val += x[t] * cmath.exp(angle)
        X[k] = sum_val / n

    return X
