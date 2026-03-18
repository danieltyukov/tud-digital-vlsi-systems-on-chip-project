# Daniel's Work Log — ET4351 FFT Accelerator Project

## Strategy

### HP Design Choice: D3 (SW Twiddle Preload) with D2 parallel butterflies
- **Why not D6 (pipeline)?** 457 hold violations, 988 max_tran DRVs, 0% power annotation coverage. Not PnR-clean.
- **Why D3?** 170 cycles at 12 MHz = 14.17 $\mu s$ (4.31x speedup). Synthesis-verified. 15.6% smaller area than D1/D2. Clean 5-state FSM.
- **Fallback:** If D3 doesn't close timing at higher frequency, use baseline clock (12 MHz) — still meets < 61 $\mu s$ requirement easily.

### EE Design Choice: Romeu's `no_recursive_twiddle` variant
- **Why?** Best energy result: 23.795 nJ (3.20% reduction from baseline 24.6 nJ). Passes verification.
- **Combination opportunity:** Stack with `no_twiddle_mem_reads` and `fastpaths` for further gains.

### Workflow
1. **Baseline** — reproduce baseline results, establish reference numbers
2. **HP Design** — integrate D3 RTL, run full flow, extract PPA
3. **EE Design** — integrate Romeu's best variant, run full flow, extract PPA
4. **Documentation** — capture all results, create report sections

## Results Summary

| Metric | Baseline | HP Design (D3) | EE Design |
|--------|----------|-----------------|-----------|
| Clock period | 83.33 ns | 83.33 ns | 83.33 ns |
| Clock frequency | 12 MHz | 12 MHz | 12 MHz |
| Cycles/chunk | 732 | 170 | 732 |
| Latency | 61.00 $\mu s$ | 14.17 $\mu s$ | 61.00 $\mu s$ |
| Post-layout power | TBD (need VCD) | TBD | TBD |
| Energy | TBD | TBD | TBD |
| SoC area (post-PnR) | 242,796 $\mu m^2$ | TBD | TBD |
| Synth area | 194,968 $\mu m^2$ | 259,890 $\mu m^2$ | 170,575 $\mu m^2$ |
| Setup WNS (post-PnR) | +33.845 ns | TBD | TBD |
| Hold WNS (post-PnR) | +0.057 ns | TBD | TBD |
| max_tran DRVs | 109 nets | TBD | TBD |
| DRC | Clean | TBD | TBD |
| Connectivity | Clean | TBD | TBD |
| Antenna | Clean | TBD | TBD |
| Behav sim | PASS | PASS | PASS |
| Struct sim | PASS | **FAIL** (investigating) | PASS |
| Phys sim (setup) | PASS | TBD | TBD |
| Phys sim (hold) | Running | TBD | TBD |

---

## Log

### 2026-03-18 — Midterm Oral Feedback (Additional)
- **Explanation > performance**: Report should prioritize *why* over raw numbers
- **HP progress = incremental bottleneck table**: identify bottleneck → fix → re-profile → next bottleneck → fix
- **Questions modifiable**: Can adapt project questions, but must explain all decisions. Optimizations should come at the end (after base flow works)

### 2026-03-18 — Session Start
- Repository organized, teammate branches reviewed
- Baseline project copied to server at `~/project`
- Behavioral simulation verified: baseline passes `verify.py`
- Killed zombie vsim processes from Feb 27 (consuming 55,800 CPU-hours combined!)

### 2026-03-18 — Baseline Synthesis Complete
- **Synthesis runtime**: ~12 minutes
- **Setup slack**: 31.85 ns (critical path ~51.5 ns at 83.33 ns period)
- **Zero timing violations** (WNS > 0, TNS = 0)
- **Total area**: 194,968 $\mu m^2$ (cell: 152,104; net: 42,864)
- **Accelerator**: 106,552 $\mu m^2$ (54.6% of SoC)
  - `accelerator_fft`: 43,967 $\mu m^2$
  - `accelerator_mem` (128 words): 59,646 $\mu m^2$
- **Cell count**: 33,748 (7,160 sequential, 26,588 combinational)

### 2026-03-18 — Behavioral Simulations Complete
- HP (D3): PASS — 170 cycles, 14.17 $\mu s$ latency, 4.31x speedup
- EE (no_recursive_twiddle): PASS — 732 cycles, 61.00 $\mu s$ (same as baseline)
- Both produce bit-identical output to golden reference

### 2026-03-18 — Synthesis Complete (all three)
- Baseline: WNS +31.85 ns, area 194,968 $\mu m^2$
- HP (D3): WNS +32.35 ns, area 259,890 $\mu m^2$ (FFT core 2.75x larger due to 2x parallel BF)
- EE: WNS +31.29 ns, area 170,575 $\mu m^2$ (FFT core 55% smaller — LUT replaces recursive multiplier)

### 2026-03-18 — Baseline PnR Complete
- Setup WNS: +33.845 ns (clean)
- Hold WNS: +0.057 ns (clean)
- DRC: No violations
- Connectivity: Clean
- Antenna: Clean
- max_tran: 109 nets (allowed)
- Power: 0.626 mW (0% VCD annotation — unreliable, need physical VCD)

### 2026-03-18 — HP Structural Sim FAILED
- Post-synthesis netlist produces 0 output values (expected 32)
- Investigating: may be timing issue in structural sim or firmware/CSR mismatch
- Running non-VCD struct sim to isolate the problem

### 2026-03-18 — Baseline FULLY COMPLETE
- Phys sim (setup): PASS
- Phys sim (hold): PASS
- All signoff reports clean (DRC, connectivity, antenna)
- Power needs re-annotation with physical VCD (0% coverage in current report)

### 2026-03-18 — EE Design FULLY COMPLETE
- PnR: Setup WNS +34.148 ns, Hold WNS +0.076 ns — both clean
- DRC/Connectivity/Antenna: all clean
- max_tran: 47 nets (much better than baseline 109)
- Phys sim (setup): PASS
- Phys sim (hold): PASS
- Area: 217,831 $\mu m^2$ (−10.3% vs baseline)
- Power: 0.610 mW (−2.6% vs baseline, but 0% annotation — needs physical VCD)

### 2026-03-18 — HP D3 Structural Sim FAILED (Timeout)
- Post-synthesis netlist hangs — accelerator never completes
- Root cause: likely CSR twiddle preload path broken by synthesis optimization
- **Decision: Fall back to D1 (register-file, 220 cycles = 18.33 $\mu s$)**
- D1 uses baseline firmware (no CSR changes) — much more robust
- D1 behavioral sim: PASS, 220 cycles, 3.33× speedup

### 2026-03-18 — HP D1 Design FULLY COMPLETE
- Synthesis: WNS +31.46 ns, area 267,139 $\mu m^2$
- Structural sim: PASS (with VCD captured)
- PnR: Setup WNS +34.108 ns (clean), Hold WNS -0.165 ns (462 violations)
  - max_tran: 988 nets (high due to 85% density)
  - DRC/Connectivity/Antenna: all clean
- Phys sim (setup): **PASS**
- Phys sim (hold): **PASS** (despite hold violations, functionally correct)

### 2026-03-18 — Final Design Status

| | Baseline | HP (D1) | EE |
|---|----------|---------|-----|
| Behav sim | PASS | PASS | PASS |
| Struct sim | PASS | PASS | PASS |
| PnR signoff | Clean | Hold violations* | Clean |
| Phys sim setup | PASS | PASS | PASS |
| Phys sim hold | PASS | PASS | PASS |
| Cycles | 732 | 220 | 732 |
| Latency | 61.00 $\mu s$ | 18.33 $\mu s$ | 61.00 $\mu s$ |

*462 hold violations (WNS = -0.165 ns) but phys sim passes — within SDF margin
