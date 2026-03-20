# Optimization Research — Can We Do Better?

## Current Best Results

| Design | Cycles | Clock | Latency | Energy |
|--------|--------|-------|---------|--------|
| **HP (D5)** | 121 | 48 MHz | 10.08 $\mu s$ | — |
| **EE (our v2)** | 210 | 12 MHz | 17.50 $\mu s$ | ~12.2 nJ |
| **EE (Romeu gc)** | 732 | 12 MHz | 61.00 $\mu s$ | 1.19 nJ |

## HP: Can We Beat D5?

### What D5 already does
- Register-file (eliminates inter-stage SRAM): D1 optimization
- SW twiddle preload via CSR: D3 optimization
- 4-stage pipeline (FETCH/MUL1/MUL2/ADD): D6 optimization
- 2× parallel butterfly datapaths: D2 optimization
- Wide 64-bit paired memory port: D5 optimization
- Clock at 48 MHz (20.83 ns period)

### Remaining HP optimization opportunities

#### A. Higher clock frequency
- D5 synthesis slack is +2.76 ns at 48 MHz → theoretical max ~55 MHz
- PnR setup slack is only +0.113 ns → very little room
- **Risk**: Higher freq at 95% density will likely fail PnR timing
- **Verdict**: Not worth pursuing — diminishing returns

#### B. Radix-4 (FranzJosef's D7)
- Reduces compute from 55 to ~36 cycles (radix-4 butterfly processes 4 points)
- Total would be ~102 cycles (121 - 19 compute savings)
- But radix-4 butterfly has wider critical path (3 multipliers) → may require lower clock
- Unverified — would need full flow from scratch
- **Verdict**: High effort, uncertain payoff. D5 already well ahead of target.

#### C. Eliminate LOAD/STORE entirely (D4 concept)
- Preload all data via CSR → eliminates accelerator_mem entirely
- Total would be ~55 cycles (compute only) + 1 INIT + 1 FINISH = 57 cycles
- But requires 2048-bit flat bus → severe routing pressure (parked for this reason)
- **Verdict**: Architecturally interesting but physically infeasible in 596×596 $\mu m^2$

#### D. Wider memory port (4× bandwidth)
- D5 uses 2× (64-bit paired). Could go to 4× (128-bit quad)
- Would cut LOAD/STORE from 32 to 16 cycles → total ~87 cycles
- But doubles mux tree width → more area, longer critical path
- **Verdict**: Possible but D5 already well ahead of 61 $\mu s$ target

### HP Conclusion
**D5 at 10.08 $\mu s$ is 6× better than the 61 $\mu s$ target.** Further optimization has diminishing returns and high risk. D5 is our best HP.

---

## EE: Can We Beat Romeu's comb_3_gc?

### What Romeu's comb_3_gc does
- Baseline FSM (732 cycles, same as baseline)
- Three microarchitectural optimizations (LUT twiddle, no SRAM reads, fastpaths)
- Manual clock gating (2 ICG cells) — gates FFT and memory clocks when idle
- 1.19 nJ accelerator energy (0.019 mW × 61 $\mu s$)

### What our EE v2 does
- D1 register-file (210 cycles)
- Hardcoded twiddle LUT
- No clock gating
- ~12.2 nJ energy (0.699 mW × 17.50 $\mu s$)

### Optimization opportunities for EE

#### A. Add clock gating to our EE v2
- Our design has higher power (0.699 mW) partly because register file toggles during LOAD/STORE
- Clock gating the FFT core during idle periods would reduce power significantly
- **Implementation**: Same approach as Romeu — 2 ICG cells in accelerator.v
- **Expected impact**: Major — the idle power during CPU data transfer dominates our measurement
- **Verdict**: HIGH VALUE — should do this

#### B. Use Romeu's comb_3_gc directly as team EE submission
- Already verified, all signoff clean, 1.19 nJ
- But it's his design, not ours — for individual grade adjustment, we need our own contribution
- **Verdict**: Use as team submission, document our EE v2 as an alternative approach in the report

#### C. Combine our D1+LUT with Romeu's clock gating
- Take our EE v2 RTL (D1 register-file + LUT)
- Add clock gating from Romeu's approach (2 ICG cells)
- Expected: fewer cycles (210 vs 732) + less switching (LUT) + gated idle power (ICG)
- This would be the MOST optimized EE: architectural + microarchitectural + physical
- **Verdict**: BEST OPTION — genuinely novel combination, our own contribution

#### D. Lower the clock for EE
- Run at 10 MHz instead of 12 MHz
- $P_{sw} \propto f$ drops 17%, but $T$ increases 20% → net energy slightly worse
- However, synthesis at slower clock allows more HVT cells → less leakage
- **Verdict**: Marginal, not worth the effort

### EE Conclusion
**Best path: Combine our EE v2 (D1+LUT) with clock gating.** This creates a genuinely distinct design that combines all optimization axes:
1. Architectural: register-file eliminates SRAM round-trips (fewer cycles)
2. Microarchitectural: LUT twiddle eliminates recursive multiply (less switching)
3. Physical: clock gating eliminates idle power (less wasted energy)
