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


def fft(x: List[complex]) -> List[complex]:
    n = len(x)
    bits = flog2(n)

    # Step 1: bit-reversal permutation
    X = [0j] * n

    for i in range(n):
        X[bit_reverse(i, bits)] = x[i]

    # Step 2: iterative FFT stages
    for stage in range(1, bits + 1):
        m = 1 << stage  # m = 2, 4, 8, ..., n

        half = m // 2
        w_m = TWIDDLES[stage-1]

        for base in range(0, n, m):
            w = complex(1 << SCALE, 0)

            for k in range(half):
                t = complex_mult(w, X[base + k + half])

                u = X[base + k]
                X[base + k] = u + t
                X[base + k + half] = u - t

                w = complex_mult(w, w_m)

    return X


def _dr4(k: int) -> int:
    """Base-4 digit reversal for a 2-digit base-4 number k ∈ {0..15}."""
    return (k % 4) * 4 + (k // 4)


def rfft_radix4(x_real: List[int]) -> List[complex]:
    """
    32-point RFFT via 16-point Radix-4 DIT FFT with Q12 arithmetic.

    Exact integer replica of ee_design_v2/accelerator_fft.v:
      PACK      z[k].re = x_real[2·DR4(k)], z[k].im = x_real[2·DR4(k)+1]
      COMPUTE   Stage 1 (trivial butterflies) + Stage 2 (hardcoded Q12 twiddles)
      RECOMBINE X[k] = (E[k] − j·W32^k·D[k]) >> 1
                where E = Y[k]+conj(Y[16−k]), D = Y[k]−conj(Y[16−k])
                Hardware twiddle values taken verbatim from Verilog case statements.

    x_real : 32 real integer samples, already Q12-scaled
    Returns : 32 complex integers X[0..31], Q12-scaled
    """
    S = SCALE  # 12

    # ── PACK ──────────────────────────────────────────────────────────────────
    dr = [x_real[2 * _dr4(k)] for k in range(16)]
    di = [x_real[2 * _dr4(k) + 1] for k in range(16)]

    # ── COMPUTE  Stage 1: 4 trivial Radix-4 butterflies on consecutive quads ─
    # Formula (non-blocking, so snapshot inputs before writing):
    #   s0=a0+a2, s1=a1+a3, d0=a0-a2, d1=a1-a3
    #   out[0]=s0+s1, out[1]=d0-j·d1, out[2]=s0-s1, out[3]=d0+j·d1
    ndr, ndi = list(dr), list(di)
    for g in range(4):
        i0, i1, i2, i3 = 4*g, 4*g+1, 4*g+2, 4*g+3
        s0r = dr[i0]+dr[i2]; s0i = di[i0]+di[i2]
        s1r = dr[i1]+dr[i3]; s1i = di[i1]+di[i3]
        d0r = dr[i0]-dr[i2]; d0i = di[i0]-di[i2]
        d1r = dr[i1]-dr[i3]; d1i = di[i1]-di[i3]
        ndr[i0] = s0r+s1r;  ndi[i0] = s0i+s1i
        ndr[i1] = d0r+d1i;  ndi[i1] = d0i-d1r   # d0 - j·d1
        ndr[i2] = s0r-s1r;  ndi[i2] = s0i-s1i
        ndr[i3] = d0r-d1i;  ndi[i3] = d0i+d1r   # d0 + j·d1
    dr, di = ndr, ndi

    # ── COMPUTE  Stage 2: 4 stride-4 butterflies (non-blocking per group) ─────

    # Helper: Q12 twiddle multiply  (a+jb)*(wr+j·wi) with >>> SCALE truncation
    def tw(ar, ai, wr, wi):
        return (ar*wr - ai*wi) >> S, (ar*wi + ai*wr) >> S

    # Trivial butterfly (W=1) used for group g=0
    def triv_bf(ar, ai, br, bi, cr, ci, er, ei):
        """a=no twiddle, b=t1, c=t2(W=1→c), e=t3"""
        s0r=ar+cr; s0i=ai+ci; d0r=ar-cr; d0i=ai-ci
        s1r=br+er; s1i=bi+ei; d1r=br-er; d1i=bi-ei
        return (s0r+s1r, s0i+s1i,
                d0r+d1i, d0i-d1r,
                s0r-s1r, s0i-s1i,
                d0r-d1i, d0i+d1r)

    def stage2_bf(a0r,a0i, t1r,t1i, t2r,t2i, t3r,t3i):
        """Combine a0 (no twiddle), pre-multiplied t1/t2/t3."""
        return (a0r+t2r)+(t1r+t3r), (a0i+t2i)+(t1i+t3i), \
               (a0r-t2r)+(t1i-t3i), (a0i-t2i)-(t1r-t3r), \
               (a0r+t2r)-(t1r+t3r), (a0i+t2i)-(t1i+t3i), \
               (a0r-t2r)-(t1i-t3i), (a0i-t2i)+(t1r-t3r)

    # Group g=0: {0,4,8,12}, W_16^0=1 (trivial) — same formula as Stage 1
    ndr, ndi = list(dr), list(di)
    (ndr[0],ndi[0], ndr[4],ndi[4],
     ndr[8],ndi[8], ndr[12],ndi[12]) = triv_bf(
        dr[0],di[0], dr[4],di[4], dr[8],di[8], dr[12],di[12])
    dr, di = ndr, ndi

    # Group g=1: {1,5,9,13}
    # W_16^1=(3784,−1567)  W_16^2=(2896,−2896)  W_16^3=(1567,−3784)
    t1r,t1i = tw(dr[5], di[5],  3784, -1567)
    t2r,t2i = tw(dr[9], di[9],  2896, -2896)
    t3r,t3i = tw(dr[13],di[13], 1567, -3784)
    ndr, ndi = list(dr), list(di)
    (ndr[1],ndi[1], ndr[5],ndi[5],
     ndr[9],ndi[9], ndr[13],ndi[13]) = stage2_bf(
        dr[1],di[1], t1r,t1i, t2r,t2i, t3r,t3i)
    dr, di = ndr, ndi

    # Group g=2: {2,6,10,14}
    # W_16^2=(2896,−2896)  W_16^4=−j (trivial)  W_16^6=(−2896,−2897)
    t1r,t1i = tw(dr[6], di[6],  2896, -2896)
    t2r,t2i =  di[10], -dr[10]              # ×(−j): re'=+im, im'=−re
    t3r,t3i = tw(dr[14],di[14], -2896, -2897)
    ndr, ndi = list(dr), list(di)
    (ndr[2],ndi[2], ndr[6],ndi[6],
     ndr[10],ndi[10], ndr[14],ndi[14]) = stage2_bf(
        dr[2],di[2], t1r,t1i, t2r,t2i, t3r,t3i)
    dr, di = ndr, ndi

    # Group g=3: {3,7,11,15}
    # W_16^3=(1567,−3784)  W_16^6=(−2896,−2897)  W_16^9=(−3784,+1569)
    t1r,t1i = tw(dr[7], di[7],  1567, -3784)
    t2r,t2i = tw(dr[11],di[11], -2896, -2897)
    t3r,t3i = tw(dr[15],di[15], -3784,  1569)
    ndr, ndi = list(dr), list(di)
    (ndr[3],ndi[3], ndr[7],ndi[7],
     ndr[11],ndi[11], ndr[15],ndi[15]) = stage2_bf(
        dr[3],di[3], t1r,t1i, t2r,t2i, t3r,t3i)
    dr, di = ndr, ndi

    # dr[0..15], di[0..15] = Y[0..15]  (16-pt FFT output, natural order)

    # ── RECOMBINE ─────────────────────────────────────────────────────────────
    # Exact Q12 W_32^k values from Verilog case statement (k=0..15)
    W32 = [
        ( 4096,     0), ( 4017,  -799), ( 3783, -1568), ( 3404, -2276),
        ( 2894, -2897), ( 2273, -3406), ( 1564, -3784), (  795, -4017),
        (   -4, -4095), ( -803, -4016), (-1571, -3782), (-2279, -3403),
        (-2899, -2893), (-3408, -2272), (-3786, -1564), (-4019,  -796),
    ]

    Xr = [0] * 32
    Xi = [0] * 32

    for k in range(9):   # k=0..8 covers all unique outputs via symmetry
        ci = (-k) % 16  # index of Y[16-k] (4-bit wrap: same as Verilog 4'd0-recomb_k)

        # E = Y[k] + conj(Y[16-k]),  D = Y[k] - conj(Y[16-k])
        Er = dr[k] + dr[ci];  Ei = di[k] - di[ci]
        Dr = dr[k] - dr[ci];  Di = di[k] + di[ci]

        wr, wi = W32[k]
        # P = W_32^k * D  (Q12 multiply, >>> SCALE = arithmetic right-shift)
        Pr = (wr*Dr - wi*Di) >> S
        Pi = (wr*Di + wi*Dr) >> S

        # X[k] = (E - j·P) / 2   →  re=(E.re+P.im)>>1, im=(E.im-P.re)>>1
        if k == 0:
            Xr[0]  = (Er + Pi) >> 1;  Xi[0]  = 0
            Xr[16] = (Er - Pi) >> 1;  Xi[16] = 0
        elif k == 8:
            Xr[8]  = (Er + Pi) >> 1;  Xi[8]  =  (Ei - Pr) >> 1
            Xr[24] = (Er + Pi) >> 1;  Xi[24] =  (Pr - Ei) >> 1
        else:
            Xr[k]    = (Er + Pi) >> 1;  Xi[k]    =  (Ei - Pr) >> 1   # X[k]
            Xr[32-k] = (Er + Pi) >> 1;  Xi[32-k] =  (Pr - Ei) >> 1   # X[32-k]=conj(X[k])
            Xr[16-k] = (Er - Pi) >> 1;  Xi[16-k] = (-Ei - Pr) >> 1   # X[16-k]
            Xr[16+k] = (Er - Pi) >> 1;  Xi[16+k] =  (Ei + Pr) >> 1   # X[16+k]=conj(X[16-k])

    return [complex(Xr[i], Xi[i]) for i in range(32)]


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
