"""
32-point complex FFT reference — maximum float accuracy.

Usage:
    python3 fft_reference.py

Edit the INPUT list below with your 32 complex samples, then run.
Real-only input: set imaginary parts to 0.

Fill COMPARE_OUTPUT with 32 values to compare against the exact DFT.
Set COMPARE_OUTPUT = None to skip comparison.
"""

import cmath
import math

# ── INPUT: 32 complex samples (edit here) ─────────────────────────────────────
INPUT = [
    # real + imaginary  (chunk used in the behavioral sym)
      30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
     30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
     30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
     30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
]
# ──────────────────────────────────────────────────────────────────────────────

# ── COMPARE_OUTPUT: 32 values to compare against the exact DFT ────────────────
# Fill these in with your hardware / sim output, or set to None to skip.
COMPARE_OUTPUT = [
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   479930 + -124j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
  0 + 0j,
   0 + 0j,
   69 + -124j,   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   69 + 124j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   0 + 0j,
   479930 + 124j,
   0 + 0j,
   0 + 0j,
 0 + 0j,
]
# Example (paste 32 values as complex numbers):
# COMPARE_OUTPUT = [
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
#      0+0j,   0+0j,   0+0j,   0+0j,
# ]
# ──────────────────────────────────────────────────────────────────────────────


def dft(x):
    """Direct O(N²) DFT — exact to float precision, no FFT approximation."""
    N = len(x)
    return [
        sum(x[n] * cmath.exp(-2j * math.pi * k * n / N) for n in range(N))
        for k in range(N)
    ]


def fft_ct(x):
    """Cooley-Tukey radix-2 DIT FFT — O(N log N), same float accuracy as DFT."""
    N = len(x)
    if N == 1:
        return list(x)
    if N & (N - 1):
        raise ValueError("N must be a power of 2")
    even = fft_ct(x[0::2])
    odd  = fft_ct(x[1::2])
    T = [cmath.exp(-2j * math.pi * k / N) * odd[k] for k in range(N // 2)]
    return [even[k] + T[k] for k in range(N // 2)] + \
           [even[k] - T[k] for k in range(N // 2)]


def fmt(z):
    r = round(z.real, 4)
    i = round(z.imag, 4)
    return f"{r:>14.4f} {i:>+14.4f}j"


if __name__ == "__main__":
    assert len(INPUT) == 32, f"Expected 32 samples, got {len(INPUT)}"

    # Use the direct DFT for maximum accuracy (no butterfly rounding)
    X = dft(INPUT)

    print("32-point FFT output (exact float):")
    print(f"{'k':>3}  {'real':>14} {'imag':>15}")
    print("-" * 36)
    for k, v in enumerate(X):
        print(f"{k:>3}  {fmt(v)}")

    # ── Comparison ──────────────────────────────────────────────────────────────
    if COMPARE_OUTPUT is not None:
        assert len(COMPARE_OUTPUT) == 32, \
            f"COMPARE_OUTPUT must have 32 entries, got {len(COMPARE_OUTPUT)}"

        errs = [COMPARE_OUTPUT[k] - X[k] for k in range(32)]
        max_err = max(abs(e) for e in errs)

        print()
        print("Comparison: COMPARE_OUTPUT vs exact DFT")
        print(f"{'k':>3}  {'Exact_re':>14} {'Exact_im':>14}  "
              f"{'Cmp_re':>12} {'Cmp_im':>12}  "
              f"{'Err_re':>10} {'Err_im':>10}  {'|Err|':>10}")
        print("-" * 105)
        for k in range(32):
            e = errs[k]
            c = COMPARE_OUTPUT[k]
            x = X[k]
            print(f"{k:>3}  {x.real:>14.2f} {x.imag:>14.2f}  "
                  f"{c.real:>12.2f} {c.imag:>12.2f}  "
                  f"{e.real:>+10.2f} {e.imag:>+10.2f}  {abs(e):>10.2f}")
        print("-" * 105)
        print(f"Max |error|: {max_err:.4f}   "
              f"(max relative: {max_err / max(abs(x) for x in X):.6f})")

        # ── Plot ────────────────────────────────────────────────────────────────
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt

            ks = list(range(32))
            mag_exact = [abs(X[k]) for k in ks]
            mag_cmp   = [abs(COMPARE_OUTPUT[k]) for k in ks]

            fig, ax = plt.subplots(figsize=(12, 5))
            fig.suptitle("32-point FFT Magnitude Spectrum", fontsize=13)

            ax.plot(ks, mag_exact, "b.-", label="Exact DFT", linewidth=1.2)
            ax.plot(ks, mag_cmp,   "r.--", label="Compare", linewidth=1.2)
            ax.set_xlabel("k (bin)")
            ax.set_ylabel("|X[k]|")
            ax.legend()
            ax.grid(True, alpha=0.3)
            ax.set_xticks(ks)

            plt.tight_layout()
            out = "fft_comparison.png"
            plt.savefig(out, dpi=150)
            print(f"\nPlot saved to {out}")

        except Exception as exc:
            print(f"\n(plot skipped: {exc})")
