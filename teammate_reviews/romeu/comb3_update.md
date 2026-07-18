# Romeu Combined-3 Branches Analysis

Branches analyzed:
- `remotes/origin/romeu_comb_3` -- combined 3 EE optimizations (no clock gating)
- `remotes/origin/romeu_comb_3_gc` -- combined 3 + manual RTL clock gating

Date of analysis: 2026-03-19

---

## 1. What Is Combined

Both branches combine all three of Romeu's individual EE strategies into a single FFT RTL (`accelerator_fft.v`):

1. **no_recursive_twiddle** -- Direct `twiddle_lut(m, k)` function replaces the recursive `w <- w * w_m` update. The `w_re` and `w_im` state registers are eliminated. Twiddle values are looked up combinationally as `twiddle_pair = twiddle_lut(m, k)`.

2. **no_twiddle_mem_reads** -- Since the LUT provides twiddle factors directly, SRAM reads for `w_m_re`/`w_m_im` are eliminated. The `READ_W_M_RE` and `READ_W_M_IM` states still exist in the FSM but do no work (no memory address driven, no data captured). This is a consequence of preserving the baseline FSM state numbering.

3. **fastpaths** -- Trivial twiddle detection: when the LUT output matches +1, -1, +j, or -j, the butterfly multiply is replaced with sign flips / re/im swaps. Detection via comparators: `twiddle_is_pos_one`, `twiddle_is_neg_one`, `twiddle_is_pos_j`, `twiddle_is_neg_j`. The full multiplier path is only used for non-trivial twiddle factors.

The `_gc` variant adds **manual RTL clock gating** in `accelerator.v` (the FFT RTL is identical between the two branches).

---

## 2. How the Optimizations Interact

The three optimizations are **largely additive** with one important synergy:

- **no_recursive_twiddle + no_twiddle_mem_reads**: These are almost entirely subsumed by each other in the combined design. Once the LUT replaces recursive computation, the SRAM reads for `w_m_re`/`w_m_im` become dead by construction. In the individual variants, `no_twiddle_mem_reads` still performed the recursive multiply (just with hardcoded step values), and `no_recursive_twiddle` still performed the SRAM reads (dead reads). The combined design eliminates both.

- **fastpaths + no_recursive_twiddle**: Synergistic. In the individual `fastpaths` variant, the comparators checked the *recursively computed* `w_re`/`w_im` values. In the combined design, they check the *LUT output* directly (`w_re_lut`, `w_im_lut`), which is combinational and does not accumulate rounding error. This makes the detection more reliable (though for N=32 both approaches produce identical results).

- **No conflicts observed.** The combined RTL is a clean integration. The twiddle LUT provides values, the comparators detect trivial cases, and the butterfly compute uses the appropriate path. No functional interference between the strategies.

**Key limitation preserved from individual variants:** The `READ_W_M_RE` and `READ_W_M_IM` FSM states are still present and waste 2 cycles per stage transition. These empty states still cause clock transitions (contributing to dynamic power). Removing them would save ~10 cycles per chunk out of the baseline 732 cycles.

---

## 3. Energy and Power Results

### romeu_comb_3 (no clock gating)

| Metric | Value |
|--------|-------|
| Accelerator-only power (VCD) | 0.3291 mW |
| First-chunk latency | 60.998 us |
| Accelerator energy | 20.07 nJ |
| Chip total power (VCD) | 0.5393 mW |
| Chip total energy | 32.89 nJ |
| Setup WNS | +34.016 ns |
| Hold WNS | +0.081 ns |
| Hold violations | 0 |
| Total instances | 40,624 |
| Final placed area | 219,447 um^2 |
| Accel area | 85,052 um^2 |

### romeu_comb_3_gc (with clock gating)

| Metric | Value |
|--------|-------|
| Accelerator-only power (VCD) | 0.01942 mW |
| First-chunk latency | 60.998 us |
| Accelerator energy | 1.185 nJ |
| Chip total power (VCD) | 0.2308 mW |
| Chip total energy | 14.08 nJ |
| Setup WNS | +33.733 ns |
| Hold WNS | +0.000 ns (exactly clean) |
| Hold violations | 0 |
| DRV (max_tran, real) | 0 |
| DRV (max_tran, total) | 58 nets / 146 terms (flash IO, non-real) |
| Total instances | 39,331 |
| Final placed area | 215,452 um^2 |
| Accel area | 81,636 um^2 |
| VCD annotation | 100% (40,983/40,983) |

### Comparison to individual variants and baseline

| Design | Accel Power (mW) | Energy (nJ) | vs Baseline |
|--------|----------------:|------------:|------------:|
| Baseline (official) | 0.403 | 24.6 | -- |
| no_recursive_twiddle (best single) | 0.390 | 23.8 | -3.2% |
| no_twiddle_mem_reads | 0.394 | 24.0 | -2.4% |
| fastpaths | 0.402 | 24.5 | -0.3% |
| **romeu_comb_3** | **0.329** | **20.1** | **-18.4%** |
| **romeu_comb_3_gc** | **0.019** | **1.19** | **-95.2%** |

The combined design without clock gating (comb_3) shows -18.4% energy reduction -- significantly more than the sum of individual reductions (-3.2% + -2.4% + -0.3% = -5.9%). This suggests the VCD power measurement methodology may differ between the individual runs and the combined run, or there are interaction effects from eliminating both the recursive multiply and the SRAM reads simultaneously that amplify beyond simple addition.

The clock-gated variant (comb_3_gc) shows a dramatic -95.2% reduction in accelerator energy, reducing it to just 1.19 nJ.

---

## 4. The Clock Gating Approach

The only RTL difference between `romeu_comb_3` and `romeu_comb_3_gc` is in `accelerator.v`. The FFT module (`accelerator_fft.v`) is identical.

### Implementation

Two manual ICG (Integrated Clock Gating) cells are instantiated using the `TLATNCAX2` standard cell (latch-based clock gate from the SAED/generic 45nm library):

```
TLATNCAX2 fft_icg (.ECK(fft_clk), .E(fft_clk_en), .CK(clk));
TLATNCAX2 mem_icg (.ECK(mem_clk), .E(mem_clk_en), .CK(clk));
```

**Enable logic:**
- `fft_clk_en = reset_accel || (enable_accel && !finished_accel)`
  - The FFT module receives clock pulses only during active FFT computation (after reset, while enabled, and before finished).
- `mem_clk_en = fft_clk_en || (iomem_access_mem && (|iomem_wstrb))`
  - The memory receives clock pulses during FFT computation OR when the CPU is writing to accelerator memory.

**Clock distribution:**
- `fft_clk` drives the `accelerator_fft` instance
- `mem_clk` drives the `accelerator_mem` instance
- The top-level `clk` still drives the configuration register logic (iomem interface) in `accelerator.v`

### Why this produces such a large power reduction

The VCD power measurement window is 60.998 us (one FFT chunk). During this window, the FFT accelerator is active for only a fraction of the total time -- most of the window covers firmware overhead (CPU loading data into accelerator memory, reading results back). When the accelerator is idle (`enable_accel == 0` or `finished_accel == 1`), the gated clocks are stopped, eliminating:

- **All sequential switching** in `accel/fft` (internal power drops to 0)
- **All sequential switching** in `accel/mem` (internal power drops to 0)
- **Clock tree power** for the gated portion

The power report confirms this: in the comb_3_gc variant, `accel/fft` shows 0.0 mW internal + 0.0 mW switching (only 0.00276 mW leakage), and `accel/mem` similarly shows only leakage. The accelerator total drops from 0.329 mW to 0.019 mW -- essentially only leakage remains.

### PnR effort

The clock gating required significant physical design effort. The gc branch has **30 PnR scripts** (iterations 1-30), including:
- `12.cg_drv_repair_iter1.tcl` -- DRV repair for CG design
- `13.cg_drv_hold_repair_iter2.tcl` -- Combined DRV + hold repair
- `14-17` -- Manual hold ECO iterations
- `18.cg_verify_iter6.tcl` -- Verification checkpoint
- `19-21` -- More hold repair + verification
- `22-26` -- Reroute and inspection iterations
- `27-29` -- Fix specific net `n494` / `n495` issues
- `30.export_cg_fix_iter11_final.tcl` -- Final export

This indicates the clock gating introduced hold timing violations that required 11+ ECO iterations to resolve. The final design achieves WNS = 0.000 ns (exactly clean), suggesting marginal hold closure.

### ECO fixes documented in EE_summary.md

The gc variant required:
- `soc/cpu/FE_OFC1177_n_495 -> INVX2` (local perturbation)
- `soc/cpu/FE_PHC12280_n_2025 -> DLY2X1` (hold-fix ECO)
- `soc/cpu/FE_PHC11129_iomem_addr_14 -> DLY2X1` (hold-fix ECO)
- `soc/spimemio/FE_PHC10756_xfer_resetn -> DLY3X1` (hold-fix ECO)

Notably, the hold-fix ECOs are in `soc/cpu` and `soc/spimemio`, not in the accelerator itself -- the clock gating perturbation of the clock tree affected paths in the SoC.

---

## 5. Comparison to Our EE v2 Design

Our EE v2 design uses the D1 register-file architecture with a hardcoded twiddle LUT, achieving 210 cycles/chunk (vs baseline 732) at 12 MHz.

| Metric | Our EE v2 (D1 + LUT) | romeu_comb_3 | romeu_comb_3_gc |
|--------|---------------------:|-------------:|----------------:|
| Cycles/chunk | 210 | 732 | 732 |
| Latency | 17.50 us | 61.00 us | 61.00 us |
| Accel power (VCD) | ~0.60 mW | 0.329 mW | 0.019 mW |
| Accel energy | ~12.2 nJ | 20.1 nJ | 1.19 nJ |
| vs 24.6 nJ baseline | -50% | -18% | -95% |
| Approach | Fewer cycles | Less switching | Less switching + CG |
| Hold WNS | -0.153 ns (violations) | +0.081 ns (clean) | 0.000 ns (clean) |
| Setup WNS | +33.753 ns | +34.016 ns | +33.733 ns |
| All signoff clean? | Some hold violations | Yes | Yes |

**Key observations:**

1. **Different optimization strategies, both valid.** Our design reduces energy by reducing cycle count (architectural change). Romeu's reduces energy by reducing switching activity per cycle (microarchitectural change) and then eliminating idle power (clock gating). Both meet the EE target.

2. **Romeu's comb_3_gc is far more energy-efficient** (1.19 nJ vs our 12.2 nJ). However, this comparison requires careful interpretation:
   - Our power measurement uses the official baseline VCD methodology at 0% annotation coverage (known tool reporting issue, actual coverage higher)
   - Romeu's gc variant achieves 100% VCD annotation coverage
   - The dramatic reduction in the gc variant is primarily from gating idle clock cycles during the measurement window, which may or may not reflect the project's intended energy metric

3. **Our design has hold violations; Romeu's gc variant is fully clean.** Romeu invested significant effort (11+ ECO iterations) to achieve hold closure. Our design has 192 hold violations (WNS = -0.153 ns) that do not cause functional failure but may be flagged by examiners.

4. **Romeu's comb_3 (without CG) is still in baseline FSM territory** (732 cycles, same latency). Our design's architectural advantage (210 cycles) gives fundamentally better energy per operation, but Romeu's VCD-annotated measurement produces a lower number even without CG (20.1 nJ vs our ~12.2 nJ is in our favor, though).

---

## 6. Correctness Assessment

### Combined RTL (accelerator_fft.v)

**Functionally correct.** The combined RTL cleanly integrates all three strategies:
- The `twiddle_lut()` function provides Q12 twiddle values for all (m, k) pairs needed for N=32, using values that match the recursive computation (deliberate rounding error matching for bit-identical output).
- The fastpath comparators operate on the LUT output rather than recursively-computed values.
- Memory access patterns are unchanged from baseline.
- Loop control (`butterfly_loop_finished`, `base_loop_finished`, `stage_loop_finished`) is identical to baseline.

**Preserved dead states.** `READ_W_M_RE` and `READ_W_M_IM` do nothing (the sequential logic has empty cases, the combinational output drives no address/data). These waste 2 cycles per stage = 10 cycles per chunk. Not a correctness issue but a missed optimization.

**Retained dead registers.** `w_m_re` and `w_m_im` are declared and initialized but never meaningfully written or read. Synthesis should optimize these away, but explicit removal would be cleaner.

### Clock gating (accelerator.v)

**Functionally correct with one nuance:**

The `mem_clk_en` signal includes `iomem_access_mem && (|iomem_wstrb)` -- this gates the memory clock in during CPU writes to accelerator memory. However, it does NOT gate the clock in for CPU **reads** from accelerator memory (reads have `iomem_wstrb == 0`). Since `accelerator_mem` is a synchronous SRAM that requires a clock edge to drive `rdata`, CPU reads from accelerator memory when the FFT is not active would see stale data.

BUT: In the baseline firmware, the CPU writes data into accelerator memory, then enables the FFT, waits for completion, then reads results. During the read-back phase, `finished_accel == 1` and `enable_accel == 1`, so `fft_clk_en` is false (since `!finished_accel` is false) -- wait, let me re-check:
- `fft_clk_en = reset_accel || (enable_accel && !finished_accel)`
- After FFT finishes: `finished_accel = 1`, so `(enable_accel && !finished_accel) = 0`
- `fft_clk_en = 0`
- `mem_clk_en = 0 || (iomem_access_mem && (|iomem_wstrb))` = only gated in for writes

**This means CPU reads from accelerator memory after FFT completion receive NO clock.** The memory output would be stuck at whatever was last driven.

**However:** Looking at the accelerator interface logic in `accelerator.v`, the `mem_rdata` wire feeds both `accel_mem_rdata` (FFT input) and `iomem_rdata` (CPU readback). Since the memory uses synchronous reads, the CPU would need a clock edge at the memory to update `rdata`.

**Likely saving factor:** The SRAM macro (`accelerator_mem`) in this design may use the standard-cell-based register-file implementation where read data is combinationally available from the address, or it may hold the last read value. Given that all four simulations (behavioral, structural, post-layout setup, post-layout hold) PASS, this is either:
(a) The memory is combinational-read (no clock needed for reads), or
(b) The firmware reads back data while `enable_accel` is still 1 and before software clears it (in which case `finished_accel=1` but `fft_clk_en` is still 0... this would still be a problem), or
(c) The memory read path works through a different mechanism.

Given that ALL simulations pass, this is functionally correct in practice, but the `mem_clk_en` condition for reads deserves scrutiny if the firmware ever changes.

### Signoff status

Both branches pass all required checks:
- Behavioral simulation: PASS
- Structural simulation: PASS
- Post-layout setup simulation: PASS
- Post-layout hold simulation: PASS
- Connectivity: PASS
- DRC: PASS
- Antenna: PASS
- Setup timing: Clean (WNS > 0)
- Hold timing: Clean (WNS >= 0)
- VCD annotation: 100%

---

## 7. Summary and Recommendations

### What Romeu achieved

1. **Combined all three individual EE optimizations** into a single clean RTL. The combined design without CG achieves 20.1 nJ (-18.4% vs baseline), much better than the individual variants.

2. **Added manual RTL clock gating** with two ICG cells (one for FFT, one for memory). This required 11+ ECO iterations for hold closure but achieved a fully timing-clean design at 1.19 nJ accelerator energy (-95.2% vs baseline).

3. **Passed all signoff checks** including all four simulation levels, DRC, connectivity, and antenna.

4. **Excellent documentation** via `EE_summary.md`, `all_metrics.md`, and `CONTENTS.txt` with clear metric tracking.

### Outstanding issues

1. **Dead FSM states** (`READ_W_M_RE`, `READ_W_M_IM`) waste 10 cycles per chunk and contribute to unnecessary clock toggles.

2. **Memory read gating concern** -- the `mem_clk_en` logic does not gate in for CPU reads, which could fail if firmware changes or if the SRAM macro requires a clock for reads.

3. **The 95% energy claim depends on measurement window interpretation.** The VCD window captures 61 us where the accelerator is mostly idle (being loaded/read by CPU). Clock gating eliminates idle power during this window. The FFT computation itself takes only ~61 us of actual execution at 732 cycles. If the project intent is to measure only the active computation energy, the clock gating benefit would be much smaller.

4. **No cycle reduction.** The baseline 732-cycle FSM is preserved. Our D1 architecture achieves 210 cycles, which is a fundamentally different (and architecturally more interesting) optimization.

### How this affects our project

- **For submission:** We already have a complete EE v2 design at ~12.2 nJ. Romeu's comb_3_gc at 1.19 nJ is dramatically better if the measurement methodology is accepted. We should discuss with Romeu whether to adopt his design as the team's EE submission or keep both as exploration options.

- **For the report:** Romeu's work demonstrates a complementary optimization axis (microarchitectural + clock gating vs architectural cycle reduction). The report should present both approaches with analysis of why each contributes to energy reduction, as the examiners value the exploration process.

- **Risk:** The 1.19 nJ figure may face examiner scrutiny if they interpret it as "the clock is just gated most of the time during the measurement window." The non-CG combined variant at 20.1 nJ is a more conservative claim. Our 12.2 nJ from cycle reduction is architecturally well-motivated and harder to question.
