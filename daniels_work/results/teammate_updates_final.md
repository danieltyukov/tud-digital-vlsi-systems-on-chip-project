# Teammate Updates -- Final Branches (April 12, 2026)

All teams converged on "final" and "clean" branches in the days before the
April 10 submission deadline. This document records what each branch contains,
its signoff status, and how it compares to our designs.

---

## 1. ShanghongLin-HP-pnrClean

**Owner:** Shanghong Lin
**Design:** HP D5 -- v7 overlap-pipeline + wide paired-SRAM interface, 24-bit narrowed datapath
**Clock:** 15.1 ns (66.2 MHz)
**Cycles:** 121 (INIT 1 + LOAD 32 + COMPUTE 55 + STORE 32 + FINISH 1)
**Latency:** 121 x 15.1 ns = 1.83 us

### SDC

- CLK_PERIOD = 15.1 ns
- CLK_UNCERTAINTY = 0.15 (single value for both setup and hold)
- No split setup/hold uncertainty
- Still carries stale output-delay constraints on `accel_o_path_node` / `accel_o_path_node_valid`

### Timing

- Setup: WNS = +0.226 ns, TNS = 0, 0 violating paths -- CLEAN
- Hold: WNS = +0.015 ns, TNS = 0, 0 violating paths -- CLEAN (very tight margin)
- max_cap: 0 violations
- max_tran: 10 real nets / 20 terms (worst -0.223) -- still has some DRV issues
- Glitch violations: 0

### Power

- Static power report (struct VCD annotation): 0.560 mW total chip
  - accel: 0.333 mW, accel/fft: 0.178 mW, accel/mem: 0.105 mW
- VCD-annotated power report (postRouteVCD): 0.704 mW total chip

### Area

- Total: 251,294 um^2 (65,307 instances)
- Accelerator: 140,132 um^2 (accel/fft: 91,371 + accel/mem: 31,334)
- Density: 69.1%

### Assessment

This is the fully timing-clean HP design. 0 setup violations, 0 hold violations.
The hold WNS of +0.015 ns is very tight but passing. Still has 10 real max_tran
violations, which may be a concern for strict signoff. The 24-bit narrowing
and tighter hold target re-run (commit 47d65e5 on Apr 6) fixed the hold issues
that plagued earlier D5 runs.

Leonardo's `leonardo-final-signoff` branch is identical to this (same design)
but with additional physical sim and VCD power extraction work.

---

## 2. leonardo-final-signoff

**Owner:** Leonardo Castello
**Design:** Same as ShanghongLin-HP-pnrClean (HP D5 v7, 24-bit, 121 cycles, 66.2 MHz)
**Clock:** 15.1 ns

### What Leonardo did

Leonardo took the clean HP D5 PnR checkpoint from Shanghong and ran:
1. Updated TB clock period for physical sim
2. Re-verified PnR
3. Ran sim_phys (both setup and hold min)
4. Extracted VCD
5. Generated VCD-annotated power report

### Timing

Same as ShanghongLin-HP-pnrClean:
- Setup: WNS = +0.226 ns, 0 violations
- Hold: WNS = +0.015 ns, 0 violations

### Power

- VCD-annotated (postRouteVCD): 2.795 mW total chip
  - Note: This is much higher than the struct-VCD report because the clock
    toggle rate shows 23.97 MHz at 15.1 ns period -- suggesting VCD annotation
    captured a longer window with more activity. Sequential power alone is 1.833 mW.
  - Clock power: 0.881 mW (31.5%)

### Assessment

This is the HP design sign-off branch. The high VCD power number is suspicious
and may indicate an incorrect VCD window or annotation issue. The timescale
was fixed to 1ps (commit 809d7b1) which could affect results. Worth double-
checking the VCD window start/stop times for the first chunk only.

---

## 3. EE_FINAL

**Owner:** Franz Josef (built on Ali's RFFT + Radix-4 code)
**Design:** Ali's RFFT + Radix-4 (130 cycles) with manual clock gating (TLATNCAX2)
**Clock:** 83.33 ns (12 MHz)
**Cycles:** 130

### SDC

- CLK_PERIOD = 83.33 ns
- CLK_UNCERTAINTY = 0.10 (single value)
- set_max_transition 0.28 applied
- No stale output-delay constraints (cleaned)

### Timing

- Setup: WNS = +35.091 ns, 0 violating paths -- CLEAN
- Hold: WNS = +0.041 ns, 0 violating paths -- CLEAN
- max_cap: 0
- max_tran: 791 real nets / 2408 terms -- SIGNIFICANT DRV ISSUES
- Glitch violations: 4

### Power

- Static report: 0.250 mW total chip
  - Clock: 0.073 mW (29.2%, includes ICG sequential power)
  - Sequential: 0.137 mW
  - Combinational: 0.040 mW
- VCD-annotated: 0.247 mW total chip

### Area

- Total: 283,374 um^2 (78,500 instances) -- LARGEST of all EE designs
- accel/fft: 118,940 um^2
- Density: 79.4%

### Assessment

This is Ali's RFFT + Radix-4 design wrapped with Franz Josef's manual clock gating.
0 timing violations but 791 real max_tran violations -- this is NOT signoff clean
from a DRV perspective. The 79.4% density is very high and likely causing the
transition problems. The power of 0.250 mW at 12 MHz / 130 cycles gives:
Energy = 0.250 mW x 130 x 83.33 ns = 2.71 nJ (using total chip, first-chunk window).

The manual CG uses TLATNCAX2 cells, same approach as our EE v3 / Romeu's gc design.

---

## 4. Ali_final_final_w_o_cg

**Owner:** Ali Sakr
**Design:** RFFT + pure Radix-4 DIT, 16-point complex FFT for 32-point real FFT, NO clock gating
**Clock:** 83.33 ns (12 MHz)
**Cycles:** 130 (INIT 1 + LOAD 32 + COMPUTE 14 + RECOMBINE 18 + STORE 64 + FINISH 1)

### Architecture highlights

- 32 real samples -> 16-point complex FFT via RFFT packing (combinational, 0 cycles)
- Radix-4 DIT: Stage 1 (1 cycle, trivial twiddles), Stage 2 (13 cycles, 4 butterflies x 3 mul-cycles)
- RECOMBINE phase (18 cycles) using Hermitian symmetry X[k] = (E[k] - j*W_32^k*D[k])/2
- 32 registers (16 complex) vs 64 in D1 -- RFFT halves FFT size
- Hardcoded inline twiddles -- no LUT function or SRAM reads
- LOAD only reads real words (stride-2), imag stays 0

### Timing

- Setup: WNS = +35.229 ns, 0 violating paths -- CLEAN
- Hold: WNS = +0.042 ns, 0 violating paths -- CLEAN
- max_cap: 0
- max_tran: 487 real nets / 1119 terms -- DRV issues but fewer than EE_FINAL
- Glitch violations: 2

### Power

- Static report: 0.684 mW total chip (clock 83.33 ns)
- VCD-annotated: 0.679 mW total chip
  - Sequential: 0.440 mW, Clock: 0.203 mW, Combinational: 0.036 mW

### Area

- Total: 273,271 um^2 (74,685 instances)
- accel/fft: 115,156 um^2
- Density: 76.1%

### Energy estimate

Energy = 0.679 mW x 130 x 83.33 ns = 7.36 nJ (total chip)
Accelerator-only energy would be lower.

### Assessment

Clean timing (0 setup, 0 hold violations) but has 487 real max_tran violations.
This is the "no clock gating" baseline for Ali's design. The RFFT + Radix-4
approach is innovative -- it halves the FFT problem size and uses pure Radix-4
for the compute. The 130-cycle count is significantly better than our 210-cycle
D1+LUT design, primarily due to RFFT (32 vs 64 LOAD cycles) and Radix-4
(14 vs 80 compute cycles).

---

## 5. Ali_final_final_with_cg

**Owner:** Ali Sakr
**Design:** Same RFFT + Radix-4 as above, WITH manual ICG (TLATNCAX2)
**Clock:** 83.33 ns (12 MHz)
**Cycles:** 130

### Timing

- Setup: WNS = +35.299 ns, 0 violating paths -- CLEAN
- Hold: WNS = +0.056 ns, 0 violating paths -- CLEAN
- max_cap: 0
- max_tran: 316 real nets / 862 terms -- better than w/o CG, still has DRV issues
- Glitch violations: 2

### Power

- Static report: 0.242 mW total chip
  - Clock: 0.068 mW (28.0%, includes ICG)
  - Sequential: 0.138 mW
  - Combinational: 0.036 mW
- VCD-annotated: 0.239 mW total chip

### Energy estimate

Energy = 0.239 mW x 130 x 83.33 ns = 2.59 nJ (total chip)

### Area

- Density: 74.6% (slightly lower than w/o CG)

### Assessment

Clock gating drops total power from 0.684 -> 0.242 mW (64.6% reduction).
The CG variant has fewer max_tran violations (316 vs 487) and better hold
margin (+0.056 vs +0.042). This is the best-performing EE design by power,
but still not fully DRV clean.

### Comparison: Ali with CG vs our designs

| Metric                  | Ali + CG     | Daniel EE v3 (D1+LUT+CG) | Romeu comb_3_gc |
|-------------------------|-------------|---------------------------|-----------------|
| Cycles                  | 130         | 210                       | 732             |
| Total power (VCD)       | 0.239 mW   | ~0.492 mW                | ~0.23 mW       |
| Energy (chip, approx)   | ~2.59 nJ   | ~7.2 nJ                  | ~1.19 nJ       |
| Hold violations         | 0           | 0                        | 0               |
| max_tran violations     | 316         | unknown                  | 0(?)            |
| Architecture            | RFFT+R4+CG | D1+LUT+CG               | Baseline+LUT+CG |

---

## 6. romeu_no_violations

**Owner:** Romeu Longo Malinski
**Design:** Daniel's EE v3 (D1 + hardcoded twiddle LUT + manual CG) -- fixed/cleaned by Romeu
**Clock:** 83.33 ns (12 MHz)
**Cycles:** 210

### What Romeu did (detailed in HOW_VIOLATIONS_WERE_FIXED.md)

Romeu took Daniel's EE v3 design and performed a thorough signoff cleanup:

1. **Behavioral sim unblock**: Added simulation stub for TLATNCAX2 clock-gating cell
2. **Stale constraint cleanup**: Removed extra `set_max_transition 0.28`, split clock
   uncertainty (setup 0.25, hold 0.10), removed stale output-delay constraints on
   `accel_o_path_node` / `accel_o_path_node_valid`, removed stale IO pin definitions
3. **De-aggressivized hold PNR tuning**: Changed CTS holdTargetSlack from 0.2 -> 0.1,
   removed aggressive `-holdTargetSlack 0.05` from route, removed duplicate post-route
   hold passes. This was THE main fix -- Daniel's aggressive hold settings were causing
   massive collateral slew/DRV damage.
4. **Targeted ECO**: One ECO clock buffer (CLKBUFX12) to fix last antenna violation
   on resetn_sync_int_reg/CK
5. **VCD window correction**: start=36.181386 ms, runtime=17.499300 us

### Timing

- Setup: WNS = +34.322 ns, 0 violating paths -- CLEAN
- Hold: WNS = +0.002 ns, 0 violating paths -- CLEAN (extremely tight!)
- max_cap: 0
- max_tran: 0 REAL violations -- FULLY DRV CLEAN
- Connectivity: CLEAN
- DRC: CLEAN
- Antenna: CLEAN
- VCD annotation: 100% (55,988/55,988 nets)

### Power

- Static report: 0.448 mW total chip
- VCD-annotated: 0.230 mW total chip
  - Accelerator: 0.026 mW
  - accel/fft: 0.009 mW, accel/mem: 0.006 mW

### Energy

Energy = 0.026 mW (accel) x 17.4993 us = 0.451 nJ (accelerator only)

### Area

- Total: 223,542 um^2 (54,376 instances) -- smallest EE design
- Density: 60.3%

### Assessment

THIS IS THE GOLD STANDARD for signoff cleanliness. Romeu achieved:
- 0 setup violations
- 0 hold violations (WNS +0.002 ns)
- 0 real DRV violations (max_tran, max_cap, max_fanout all clean)
- 0 DRC violations
- 0 antenna violations
- 100% VCD annotation coverage
- All 3 simulation levels pass (behav, struct, phys)

The critical insight from Romeu: Daniel's aggressive hold settings (holdTargetSlack 0.2
in CTS, 0.05 in route) were causing far worse DRV problems than they solved. Backing
off to standard hold targets (0.1) eliminated hundreds of transition violations.

The accelerator energy of 0.451 nJ is excellent (baseline was 24.6 nJ = 54.6x improvement).

---

## 7. Jiahui_FinalEE_cleanpnr

**Owner:** Jiahui Que
**Design:** D1 register-file + hardcoded twiddle LUT (same architecture as Daniel EE v2)
**Clock:** 83.33 ns (12 MHz)
**Cycles:** 210

### Timing

- Setup: WNS = +34.374 ns, 0 violating paths -- CLEAN
- Hold: WNS = +0.119 ns, 0 violating paths -- CLEAN (good margin)
- max_cap: 0
- max_tran: 237 real nets / 686 terms -- has DRV issues
- Glitch violations: 0

### Power

- Static report: ~0.449 mW total chip (merge conflict in file, two versions: 0.449/0.447)
- VCD-annotated: 0.236 mW total chip

### Area

- Total: ~264,401 um^2 (~59,759 instances)
- accel/fft: 91,664 um^2 (MEM_WIDTH=32, ADDR_WIDTH=7)
- Density: 73.3%

### Assessment

Jiahui used the D1+LUT design (same as our EE v2, 210 cycles) with clock gating.
0 timing violations but 237 real max_tran violations remain. Good hold margin at
+0.119 ns. The VCD power of 0.236 mW is comparable to other CG EE designs.

Note: There are git merge conflicts in some report files (<<<< markers visible),
suggesting some merging was done on this branch.

---

## 8. ShanghongLin-HP-D5-2xBandwidth

**Owner:** Shanghong Lin
**Latest commit:** `9491015` "Narrow wide memory port to native DATA_WIDTH, re-synthesize"

No new commits since the March 22 review. The 24-bit narrowing (commit 6f22444)
was the last change. This branch is the pre-pnrClean version -- the clean
timing closure happened on the `ShanghongLin-HP-pnrClean` branch instead.

---

## Summary Comparison Table

### HP Designs

| Branch                    | Design      | Clock     | Cycles | Setup Vio | Hold Vio | max_tran  | Power (VCD) |
|---------------------------|-------------|-----------|--------|-----------|----------|-----------|-------------|
| ShanghongLin-HP-pnrClean  | D5 24-bit   | 15.1 ns   | 121    | 0         | 0        | 10 real   | 0.704 mW    |
| leonardo-final-signoff     | D5 24-bit   | 15.1 ns   | 121    | 0         | 0        | 10 real   | 2.795 mW*   |

*Leonardo's VCD power is suspiciously high -- likely VCD window/annotation issue.

### EE Designs

| Branch                     | Design             | Cycles | Setup Vio | Hold Vio | max_tran  | Power (VCD)  | Energy est  |
|----------------------------|--------------------|--------|-----------|----------|-----------|--------------|-------------|
| romeu_no_violations        | D1+LUT+CG (Daniel) | 210    | 0         | 0        | 0 REAL    | 0.230 mW     | 0.451 nJ    |
| Ali_final_final_with_cg    | RFFT+R4+CG          | 130    | 0         | 0        | 316 real  | 0.239 mW     | ~2.59 nJ    |
| Ali_final_final_w_o_cg     | RFFT+R4 no CG       | 130    | 0         | 0        | 487 real  | 0.679 mW     | ~7.36 nJ    |
| EE_FINAL                   | RFFT+R4+CG (Franz)  | 130    | 0         | 0        | 791 real  | 0.247 mW     | ~2.71 nJ    |
| Jiahui_FinalEE_cleanpnr    | D1+LUT+CG           | 210    | 0         | 0        | 237 real  | 0.236 mW     | ~3.44 nJ    |

### Key Findings

1. **Only Romeu's branch is fully signoff clean** (0 real DRV violations). All other
   EE branches have hundreds of max_tran violations.

2. **Romeu's critical fix**: Daniel's aggressive hold PNR settings caused collateral
   DRV damage. Reverting holdTargetSlack from 0.2 to 0.1 (CTS) and removing the
   aggressive 0.05 route target was the breakthrough.

3. **Ali's RFFT + Radix-4 is architecturally superior** (130 vs 210 cycles) but his
   branches are not DRV clean. If someone could apply Romeu's PNR fixes to Ali's
   design, it could be the best overall EE submission.

4. **The HP D5 design is timing clean** with 0 hold violations after Shanghong's
   24-bit narrowing and PnR re-run with tighter hold target.

5. **Clock gating is universally adopted** across EE final branches. All CG variants
   use manual TLATNCAX2 ICG cells. Power drops 60-65% with CG.

6. **VCD annotation is critical**: Romeu's branch achieves 100% annotation; others
   show 0% in report headers (though actual coverage may differ in logs).
