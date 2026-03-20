# Daniel's Work Log — ET4351 FFT Accelerator Project

## Strategy

### HP Design: D1 (Register-File Architecture)
- **Originally tried D3** (SW twiddle preload, 170 cycles) — structural sim TIMEOUT (accelerator hangs in post-synthesis netlist)
- **Fell back to D1** (register-file, 220 cycles) — simpler, uses baseline firmware, no CSR interface changes
- **Result:** 220 cycles at 12 MHz = 18.33 $\mu s$ (3.33x speedup). All sims pass.
- Hold violations exist (462, WNS=-0.165ns) but don't cause functional failure.

### EE Design: D1 Register-File + Hardcoded Twiddle LUT (EE v2)
- Combines D1 register-file (fewer cycles) with hardcoded twiddle LUT (less switching)
- Different RTL from HP: no recursive twiddle, no LOAD_TWIDDLE state
- 210 cycles (10 fewer than HP's 220), 17.50 $\mu s$ latency
- Energy dominated by cycle reduction: even with higher power, energy drops massively

## Results Summary — ALL TARGETS MET

| Metric | Baseline | HP (D1) | EE (D1+LUT) | Target |
|--------|----------|---------|-------------|--------|
| Clock period | 83.33 ns | 83.33 ns | 83.33 ns | — |
| Clock frequency | 12 MHz | 12 MHz | 12 MHz | EE: ≥ 10 MHz ✓ |
| Cycles/chunk | 732 | **220** | **210** | — |
| Latency | 61.00 $\mu s$ | **18.33 $\mu s$** | **17.50 $\mu s$** | HP: < 61 $\mu s$ ✓ |
| Power (postRoute) | 0.626 mW | 0.851 mW | 0.699 mW | — |
| Power (phys VCD) | 0.554 mW | 0.723 mW | ~0.60 mW | — |
| **Energy** | 38.2 nJ | **15.6 nJ** | **12.2 nJ** | EE: < 24.6 nJ ✓ |
| SoC area (post-PnR) | 242,796 | 300,906 | ~270,000 $\mu m^2$ | — |
| Density | 66.4% | 85.0% | 79.6% | — |
| Setup WNS | +33.845 ns | +34.108 ns | +33.753 ns | > 0 ✓ |
| Hold WNS | +0.057 ns | -0.165 ns | -0.153 ns | — |
| Hold violations | 0 | 462 | 192 | — |
| max_tran DRVs | 109 | 988 | 860 | allowed ✓ |
| DRC | Clean | Clean | Clean | Clean ✓ |
| Connectivity | Clean | Clean | Clean | Clean ✓ |
| Antenna | Clean | Clean | Clean | Clean ✓ |
| Behav sim | PASS | PASS | PASS | ✓ |
| Struct sim | PASS | PASS | PASS | ✓ |
| Phys sim (setup) | PASS | PASS | PASS | ✓ |
| Phys sim (hold) | PASS | PASS | PASS | ✓ |
| `finaldesign` | N/A | YES | YES | ✓ |
| Designs different | — | — | MD5 verified ≠ | ✓ |

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

### 2026-03-18 — EE Target Not Met, Redesign
- EE v1 (no_recursive_twiddle alone): 0.543 mW × 61.00 $\mu s$ = 33.1 nJ > 24.6 nJ — **FAILS TARGET**
- Root cause: 2% power reduction at same cycle count is insufficient
- **Decision**: Create EE v2 = D1 register-file + hardcoded twiddle LUT
  - Different RTL from HP (no recursive twiddle, no LOAD_TWIDDLE state)
  - Genuinely distinct design from HP D1

### 2026-03-18 — EE v2 (D1 + LUT twiddle)
- Behavioral sim: PASS — **210 cycles** (10 fewer than D1's 220, since no LOAD_TWIDDLE)
- Latency: 17.50 $\mu s$ (3.49x speedup)
- Synthesis: area 238,482 $\mu m^2$ (67% util, down from D1's 75%), WNS +31.46 ns, 0 violations
- PnR: Setup +33.75 ns, Hold -0.153 ns (192 violations), DRC/conn/antenna clean
- Phys sim: PASS (both setup and hold)

### 2026-03-20 — D5 Debugging and Fix
- Initial D5 attempt failed: behavioral sim timeout, all imaginary parts = 0
- Lynn suggested zero-init for data regs — applied but didn't fix the computation bug
- **Root cause found**: firmware build mismatch. D5's `prepare_fft.py` generates `fft_data.hex` for the wide memory layout. Our earlier attempt used baseline firmware build artifacts with D5 RTL.
- **Fix**: Rebuild firmware entirely from D5 branch files (not just overlay RTL)
- **Lesson**: always rebuild firmware from teammate's branch, don't just copy RTL

### 2026-03-20 — D5 Full Flow COMPLETE
- Behavioral sim: **PASS** — 121 cycles/chunk, 10.08 $\mu s$ first chunk latency
- Synthesis: WNS +2.76 ns at 48 MHz, 297,791 $\mu m^2$ area, 0 violations
- Structural sim: **PASS** (with VCD)
- PnR: Setup WNS +0.113 ns (tight!), Hold WNS -0.230 ns (4,133 violations)
  - DRC/Connectivity/Antenna: all clean
  - Density: 94.9% — extremely congested
  - max_tran: 1,489 nets
- Physical sim (setup): **PASS**
- Physical sim (hold): **PASS** (despite hold violations)
- `finaldesign_hp/` updated with D5 files
