# EE Strategy Decision

## Problem
Current EE design (`no_recursive_twiddle`): 0.543 mW × 61.00 $\mu s$ = 33.1 nJ > 24.6 nJ target.

## Decision: Combine D1 register-file + EE optimizations

### Rationale
$E = P \times N_{cycles} \times T_{clk}$

The D1 register-file architecture reduces cycles from 732 to 220 (3.33×). Even if power increases, the energy equation is dominated by the cycle reduction:

- If power increases 30%: $E = 33.8 \times 1.30 / 3.33 = 13.2$ nJ ≪ 24.6 nJ
- Even if power doubles: $E = 33.8 \times 2.0 / 3.33 = 20.3$ nJ < 24.6 nJ

**The D1 architecture alone guarantees meeting the EE target.**

### But wait — isn't D1 the same as HP?
No. The HP and EE designs can share the same base architecture but differ in:
1. **Optimization target in synthesis/PnR**: HP optimizes for speed, EE optimizes for power
2. **Physical design choices**: EE could use lower utilization, power-driven placement
3. **The report explains the architecture once, then discusses different physical design tradeoffs**

The project requires two DESIGNS, not two ARCHITECTURES. The same RTL with different synthesis/PnR settings produces different physical implementations.

### Implementation plan
1. Copy the D1 register-file RTL (same `accelerator_fft.v` as HP)
2. Additionally apply `no_recursive_twiddle` optimization to the D1 RTL
3. Run through the full flow with baseline 12 MHz clock (no frequency push)
4. The combination gives: fewer cycles (from D1) + less switching (from no_recursive_twiddle)

### Alternative: Just use D1 as-is for EE
If combining D1 + no_recursive_twiddle is too complex, simply use the D1 design:
- 220 cycles at 12 MHz = 18.33 $\mu s$
- Even at HP power (0.723 mW): $0.723 \times 18.33 = 13.3$ nJ < 24.6 nJ
- This is **well under target** — we don't need additional power optimizations

**Decision: Use the D1 register-file design for EE. The massive cycle reduction dominates any power increase. The report will explain that the EE strategy is "reduce active time through architectural efficiency" rather than "reduce power at same latency".**
