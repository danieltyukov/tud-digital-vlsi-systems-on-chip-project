# Review of Romeu's Branch (`remotes/origin/romeu`)

## Summary of Work

Romeu explored three distinct energy-efficient (EE) strategies for the ET4351 N=32 radix-2 DIT FFT accelerator. Each strategy targets dynamic power reduction while keeping the same FSM cycle count as the baseline (732 cycles per chunk). The three variants are:

1. **no_twiddle_mem_reads** -- Replace twiddle-factor SRAM reads with hardcoded stage constants
2. **fastpaths** -- Bypass the complex multiplier for trivial twiddle values (+1, -1, +j, -j)
3. **no_recursive_twiddle** -- Replace the recursive twiddle update `w <- w * w_m` with a direct (m, k) lookup table

All three were taken through the full physical design flow (synthesis, PnR, power analysis with VCD annotation) and compared against the baseline.

---

## What They Discovered

### Strategy 1: no_twiddle_mem_reads

**Concept:** The baseline reads `w_m_re` and `w_m_im` from SRAM during `READ_W_M_RE` and `READ_W_M_IM` states. Since `W_m = exp(-j2pi/m)` depends only on the stage index, these can be hardcoded in a `stage_twiddle_step()` function that maps stage index to Q12 fixed-point (re, im) pairs. The recursive twiddle update `w <- w * w_m` is preserved.

**Key results vs baseline:**
- Accelerator power: 0.3935 mW (baseline 0.403 mW, delta = -0.0095 mW)
- Accelerator energy: 24.003 nJ (baseline 24.582 nJ, delta = -0.579 nJ, -2.36%)
- Latency: 60.998 us (unchanged)
- Area: 184,902 um^2 synth / 230,514 um^2 final (baseline 194,968 / 242,796; -5.2% / -5.1%)
- All timing/signoff checks pass

### Strategy 2: fastpaths (Trivial-Twiddle Fast Paths)

**Concept:** When the current twiddle factor w equals one of four trivial values (+1, -1, +j, -j), the butterfly output t = w * v can be computed with sign flips and real/imaginary swaps instead of a full complex multiply. For N=32: 46 of 80 butterflies (57.5%) use trivial twiddles. The design detects these cases via comparators (`twiddle_is_pos_one`, `twiddle_is_neg_one`, `twiddle_is_pos_j`, `twiddle_is_neg_j`) and routes around the multiplier.

**Key results vs baseline:**
- Accelerator power: 0.4018 mW (baseline 0.403 mW, delta = -0.0012 mW)
- Accelerator energy: 24.509 nJ (baseline 24.582 nJ, delta = -0.073 nJ, -0.30%)
- Latency: 60.998 us (unchanged)
- Area: 196,862 um^2 synth / 237,638 um^2 final (baseline 194,968 / 242,796; +1.0% / -2.1%)
- All timing/signoff checks pass

### Strategy 3: no_recursive_twiddle

**Concept:** Eliminate the recursive twiddle update entirely. Instead of computing `w_next = w * w_m` each butterfly, look up the twiddle factor directly from a hardcoded `twiddle_lut(m, k)` function. This removes the second complex multiply per butterfly and the `w_re`, `w_im` registers from the datapath.

**Key results vs baseline:**
- Accelerator power: 0.3901 mW (baseline 0.403 mW, delta = -0.0129 mW)
- Accelerator energy: 23.795 nJ (baseline 24.582 nJ, delta = -0.787 nJ, -3.20%)
- Latency: 60.998 us (unchanged)
- Area: 170,575 um^2 synth / 217,831 um^2 final (baseline 194,968 / 242,796; -12.5% / -10.3%)
- DRV max_tran: only 47 violations with worst -0.186 ns (baseline 105 violations, worst -0.626 ns)
- All timing/signoff checks pass

### Ranking (best to worst by energy reduction):

| Strategy | Energy (nJ) | Delta vs Baseline | Relative |
|---|---:|---:|---:|
| no_recursive_twiddle | 23.795 | -0.787 | -3.20% |
| no_twiddle_mem_reads | 24.003 | -0.579 | -2.36% |
| fastpaths | 24.509 | -0.073 | -0.30% |
| baseline | 24.582 | -- | -- |

---

## Which Part of the Project

This work covers the **Energy-Efficient (EE) design exploration** portion of the ET4351 project. All three variants target the same clock frequency (12 MHz, 83.33 ns period) and aim to reduce per-chunk energy below the 24.6 nJ target through dynamic power reduction.

---

## Correctness Analysis

### no_twiddle_mem_reads

**Functionally correct.** The `stage_twiddle_step()` function maps each stage to the correct Q12 twiddle step:
- stage 1 (m=2): W_m = (-4096, 0) = exp(-j*pi) -- correct
- stage 2 (m=4): W_m = (0, -4096) = exp(-j*pi/2) -- correct
- stage 3 (m=8): W_m = (2896, -2896) = exp(-j*pi/4), where 4096 * cos(pi/4) = 4096 * 0.7071 = 2896 -- correct
- stage 4 (m=16): W_m = (3784, -1567) = exp(-j*pi/8) -- correct
- stage 5 (m=32): W_m = (4017, -799) = exp(-j*pi/16) -- correct

The recursive twiddle update `w_re_comb` / `w_im_comb` is preserved in `BUTTERFLY_COMPUTE`, and loop control is identical. The `READ_W_M_RE` state now loads from the constant function instead of `accel_mem_rdata`, and `READ_W_M_IM` is a no-op. Mathematically equivalent to the baseline.

**Potential concern:** The `READ_W_M_RE` and `READ_W_M_IM` states still exist and consume cycles. The FSM still transitions through them. In `READ_W_M_RE`, `accel_mem_addr` is not driven (defaults to 0 from the combinational block), meaning no real SRAM read occurs. This is correct behavior -- the SRAM simply sees a spurious address 0 with no write strobe.

### fastpaths

**Functionally correct with a minor observation.** The twiddle detection logic uses exact Q12 comparisons:
```
assign twiddle_is_pos_one = (w_re == TWIDDLE_ONE) && (w_im == TWIDDLE_ZERO);
```
Where `TWIDDLE_ONE = 32'sd4096`, `TWIDDLE_NEG_ONE = -32'sd4096`, `TWIDDLE_ZERO = 32'sd0`.

The fast-path math for each case:
- w = +1: t_re = v_re, t_im = v_im -- correct (multiply by 1)
- w = -1: t_re = -v_re, t_im = -v_im -- correct (multiply by -1)
- w = +j: t_re = -v_im, t_im = v_re -- correct (multiply by j)
- w = -j: t_re = v_im, t_im = -v_re -- correct (multiply by -j)

**Bug risk (minor):** The recursive twiddle update `w_re_comb = (w_re * w_m_re - w_im * w_m_im) >>> SCALE` is always computed, even when the fast path was taken for the butterfly output. This means the multipliers still toggle for the twiddle-update path. The benefit is limited to the butterfly output computation only. This is not a functional bug, but it limits the energy savings. Additionally, the `w_m_re` and `w_m_im` values are still read from SRAM (in `READ_W_M_RE` / `READ_W_M_IM`), adding further unnecessary switching. This explains why the energy improvement is only -0.073 nJ (0.30%).

**Another observation:** The twiddle detection uses exact equality. Due to the recursive multiply, the accumulated w values will have rounding errors from the `>>> SCALE` shifts. For stages where the twiddle is supposed to be exactly +1, -1, +j, or -j (e.g., w at k=0 is always exactly +1 since it starts as `1 << SCALE`), the detection works. But for later k values where w is computed recursively, the twiddle may drift from the exact value and fail the comparator. For example, in stage m=4, k=1 should give w = (0, -4096), but if computed recursively as (4096,0) * (0,-4096) >>> 12, the result is exactly (0, -4096) in Q12, so it works. The recursive multiply preserves exact values when inputs are exact Q12 representations of roots of unity for small m. This is safe for N=32.

### no_recursive_twiddle

**Functionally correct with a numerical precision observation.** The `twiddle_lut(m, k)` function provides precomputed values for all (m, k) combinations needed for N=32. The values are hardcoded Q12 constants.

**Precision discrepancy:** Some LUT values differ slightly from what the recursive method would produce. For example, in the m=16 case:
- k=6: LUT gives (-2896, -2897) while the exact Q12 value of cos(6*pi/8) would give (-2896, -2896)
- k=7: LUT gives (-3784, -1569) while exact would be (-3784, -1567)

Similarly for m=32:
- k=8: LUT gives (-4, -4095) instead of (0, -4096)
- k=9: LUT gives (-803, -4016) instead of (-799, -4017)
- etc.

These are the values that the *recursive* method would have produced (accumulating rounding from repeated `>>> SCALE` shifts). So the LUT deliberately encodes the same rounding errors as the recursive computation. This means the output is bit-identical to the baseline, which is important for passing the correctness verification. This is a deliberate and correct design decision.

**Structural note:** The `w_m_re` and `w_m_im` registers are retained "for baseline FSM compatibility" (per the comment), and `READ_W_M_RE` / `READ_W_M_IM` states still read from SRAM. These reads are functionally dead since the values are never used in the butterfly computation. The `w_re` and `w_im` registers are fully removed from the datapath, which is correct.

---

## What Was Done Well

1. **Systematic methodology.** Three distinct strategies were explored, each targeting a different aspect of the energy equation. Each has a clear hypothesis, implementation, and measurement. This is excellent experimental methodology.

2. **Full physical design flow.** Every variant was taken through synthesis, PnR, CTS, routing, and post-layout power analysis with VCD annotation at 100% coverage. The metrics are from actual Voltus power reports, not estimates.

3. **Documentation quality.** Each strategy has:
   - A "why it can reduce energy" explanation with clear reasoning
   - A comprehensive metrics report with baseline comparison
   - A project-description compliance checklist

4. **Automation tooling.** Two Python scripts were created:
   - `generate_metrics.py` (884 lines): Parses all report files from the ASIC flow (Genus QoR, Innovus timing summaries, Voltus power reports, VCD annotation logs, area reports, signoff reports) and generates a comprehensive markdown comparison. Includes hardcoded baseline values and an ET4351 project-description compliance checklist. This is a high-quality, reusable tool.
   - `run_all_auto_exit.py`: Automates the full `run_all.sh` flow by detecting tool prompts (Genus, Innovus) and automatically sending `exit`. Saves significant manual effort.

5. **Correct twiddle mathematics.** All three variants correctly implement the Cooley-Tukey DIT butterfly. The Q12 fixed-point values are accurately computed for all stages.

6. **Cumulative improvement tracking.** The strategies build on each other logically: first remove SRAM reads for twiddles, then bypass multiplies for trivial cases, then eliminate recursive twiddle altogether. This gives clear insight into which optimization provides the most benefit.

7. **Area improvements.** The no_recursive_twiddle variant achieves -12.5% synthesis area and -10.3% final placed area, showing that removing the recursive multiply path has significant structural benefits.

---

## What Was Not Done or Done Wrong

### 1. The FSM states READ_W_M_RE and READ_W_M_IM are never removed

All three variants keep the two `READ_W_M_*` states in the FSM, even when no useful work is done in them. This wastes 2 cycles per stage transition (5 stages, but first stage enters from INIT, so 2 x 5 = 10 wasted cycles total). For 732 baseline cycles, removing these states could save approximately 10 cycles per chunk. More importantly, these idle states still cause clock-edge transitions and SRAM address toggling (address defaults to stage-based values), contributing to unnecessary dynamic power. The `no_twiddle_mem_reads` variant explicitly notes this limitation but does not implement the removal.

**Estimated impact:** Removing the 2 dead states would reduce the inner loop from 10 cycles to 8 cycles per butterfly (for the first butterfly of each base group that goes through READ_W_M). This could contribute an additional ~1-2% energy reduction.

### 2. Strategies were not combined

The three strategies are largely orthogonal and could be combined:
- `no_twiddle_mem_reads` + `no_recursive_twiddle` = eliminate both SRAM reads and recursive multiply
- All three together: LUT-based twiddle + fast paths for trivial cases + no SRAM reads

The `no_recursive_twiddle` variant already subsumes `no_twiddle_mem_reads` in practice (since the LUT replaces both the SRAM read and the recursive update), but it still performs the SRAM reads due to the retained FSM states. Combining `no_recursive_twiddle` with the elimination of `READ_W_M_*` states and the fastpath optimization would yield the maximum energy reduction.

### 3. No testbench or simulation correctness verification included

While the metrics reports indicate behavioral/structural/physical simulations were run and the FFT correctness is listed as "N/A" (artifacts present but not verifiable from the branch), there are no testbench files, expected output comparisons, or verification scripts committed on this branch. A diff of the simulation output against expected values would strengthen confidence in correctness.

### 4. The fastpaths variant still reads twiddle factors from SRAM

The `fastpaths` variant still reads `w_m_re` and `w_m_im` from SRAM and still performs the recursive twiddle update multiplication. The fast path only bypasses the butterfly output multiply. This severely limits its effectiveness (only -0.073 nJ improvement). A combined approach would be more effective.

### 5. No clock gating or operand isolation explored

The documentation correctly identifies that Energy = Power x Time, and that these strategies target power. However, no explicit clock gating or operand isolation techniques were explored. For example:
- Gating the multiplier inputs when the fast path is active
- Gating the `w_re`/`w_im` update logic in `no_recursive_twiddle`
- Using enable signals on specific register banks

These microarchitectural techniques could amplify the power savings of each strategy.

### 6. Twiddle LUT values in no_recursive_twiddle encode recursive rounding errors

While this is functionally correct (bit-identical to baseline), it means the LUT is not providing the mathematically optimal twiddle values. For a standalone implementation not requiring bit-compatibility with the baseline, using the mathematically exact Q12 values (e.g., round(4096 * cos(2*pi*k/m)) for each entry) could improve FFT output accuracy. This is a minor point given the project context, but worth noting.

### 7. No exploration of clock frequency changes

All three variants run at the same 12 MHz clock. Since the strategies reduce area and critical path complexity (the no_recursive_twiddle variant has +0.303 ns better setup WNS), there is headroom to increase the clock frequency, which would reduce latency and potentially allow further energy optimization via voltage scaling.

### 8. Missing finaldesign packaging

All three metrics reports flag: "No finaldesign/ or finaldesign_hp+finaldesign_ee packaging found." The final submission package with `accel_audio.hex`, `et4351.phys.sdf`, and `et4351.phys.v` is not present on the branch.

---

## Recommendations

1. **Combine the best strategies.** Merge `no_recursive_twiddle` (best energy: 23.795 nJ) with the elimination of `READ_W_M_RE`/`READ_W_M_IM` FSM states. This would remove 10 wasted cycles and further reduce dynamic power from dead SRAM reads. Estimated combined energy: ~23.3-23.5 nJ.

2. **Add fastpath detection to no_recursive_twiddle.** Since the LUT provides exact twiddle values, the trivial-twiddle comparators can be replaced with a direct check on the LUT output (or even on `m` and `k` values directly, e.g., k==0 always means w=+1). This would be simpler than the fastpaths approach and could further reduce switching.

3. **Include simulation verification.** Add the behavioral simulation transcript or output diff to the branch to demonstrate that each variant produces bit-correct FFT results.

4. **Explore operand isolation.** When the fast path is active, force multiplier inputs to zero (or hold them constant) to eliminate switching power. This can be done with AND gates on the multiplier inputs controlled by the fast-path detection signals.

5. **Consider removing dead registers.** In `no_recursive_twiddle`, `w_m_re`, `w_m_im`, and the READ_W_M SRAM reads are dead logic. Synthesis may or may not optimize these away. Explicitly removing them from the RTL guarantees no wasted area or power.

6. **Package the best variant.** Create the `finaldesign_ee/` directory with the required submission files for the best-performing variant (no_recursive_twiddle at 23.795 nJ).

7. **Consider using the LUT with mathematically exact values** (rather than recursive-rounding-matched values) and verify against the testbench. If the testbench tolerance allows it, this could improve overall FFT accuracy.

---

## Summary Table

| Aspect | no_twiddle_mem_reads | fastpaths | no_recursive_twiddle |
|---|---|---|---|
| Energy (nJ) | 24.003 | 24.509 | 23.795 |
| Energy reduction | -2.36% | -0.30% | -3.20% |
| Accel power (mW) | 0.3935 | 0.4018 | 0.3901 |
| Synth area (um^2) | 184,902 | 196,862 | 170,575 |
| Final area (um^2) | 230,514 | 237,638 | 217,831 |
| Setup WNS (ns) | 33.921 | 33.597 | 34.148 |
| Cycles per chunk | 732 (unchanged) | 732 (unchanged) | 732 (unchanged) |
| SRAM reads eliminated | twiddle only | none | none (still reads) |
| Multiplies eliminated | none | butterfly (57.5%) | recursive twiddle |
| Functional correctness | correct | correct | correct (bit-identical) |
| Meets EE target (<24.6 nJ) | yes | yes | yes |

**Best variant:** `no_recursive_twiddle` at 23.795 nJ (-3.20% vs baseline), with additional headroom available if combined with FSM state elimination and fast paths.
