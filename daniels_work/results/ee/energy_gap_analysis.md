# EE Energy Gap Analysis

## Problem
- **Target**: Energy < 24.6 nJ
- **Current EE result**: 33.1 nJ (VCD-annotated) — **35% over target**
- **Current baseline**: 33.8 nJ (VCD-annotated) — also above official 24.6 nJ

## Root Cause Investigation

### Why does our baseline (33.8 nJ) not match the official baseline (24.6 nJ)?
- Official: $P = 0.403$ mW, $T = 61.00 \mu s$, $E = 24.6$ nJ
- Ours: $P = 0.554$ mW, $T = 61.00 \mu s$, $E = 33.8$ nJ
- **Power discrepancy**: 0.554 / 0.403 = 1.375× (37.5% higher)

### Hypothesis: Power analysis corner mismatch
Our power report header shows: `Rail: VDD Voltage: 1.32` (fast corner)
The `analysis_view_power` uses `fast_vdd1v2_basicCells.lib` at 1.2V/1.32V.

$P_{sw} \propto V_{DD}^2$, so at 1.32V vs 1.0V: $(1.32/1.0)^2 = 1.74\times$

This alone would explain the discrepancy. If the official baseline used 1.0V for power:
$0.554 / 1.74 = 0.318$ mW — close to 0.403 mW.

### Action items
1. Check MMMC power view configuration
2. Verify VCD annotation is using correct scope and timescale
3. If measurement can't be fixed, use relative comparison methodology
4. Pursue more aggressive EE optimizations regardless

## EE Optimization Strategy

### Approach 1: Fix measurement methodology first
If we can match the official 24.6 nJ baseline, then our 2% EE improvement gives 24.1 nJ < 24.6 nJ.

### Approach 2: Stack Romeu's optimizations
Combine all three EE strategies:
- `no_recursive_twiddle` (−3.2% energy)
- `no_twiddle_mem_reads` (−2.4% energy)
- `fastpaths` (−0.3% energy)
Estimated combined: ~5-6% reduction → 24.6 × 0.94 = 23.1 nJ

### Approach 3: Use D1 register-file architecture for EE
$E = P \times T = P \times N_{cycles} \times T_{clk}$
D1: 220 cycles vs baseline 732 cycles = 3.33× fewer
Even if power increases 30%: $E_{D1} = 24.6 \times 1.30 / 3.33 = 9.6$ nJ ≪ 24.6 nJ

**This is the safest approach** — the latency reduction dominates power increase.
But this is the same architecture as HP... Is that allowed?

### Approach 4: Lower clock frequency for EE
At 10 MHz (minimum allowed): $T_{clk} = 100$ ns vs 83.33 ns
But cycle count unchanged: $T = 732 \times 100 = 73.2 \mu s$
Power: $P_{sw} \propto f_{clk}$ drops by 12/10 = 1.2×, but $T$ increases by 1.2×
Net: $E = (P/1.2) \times (T \times 1.2) = P \times T$ — **no energy change** from frequency alone
However, synthesis at slower clock allows more HVT cells → lower leakage
