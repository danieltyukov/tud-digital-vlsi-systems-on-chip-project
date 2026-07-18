# Review: FranzJosef -- HP-D1-reg_bfly Branch

**Branch:** `remotes/origin/FranzJosef-HP-D1-reg_bfly`
**Project part:** High Performance (HP), Direction D1 -- Register-file butterfly architecture
**Date reviewed:** 2026-03-18

---

## 1. What They Did

FranzJosef implemented a **register-file-based FFT accelerator** that replaces the baseline's per-butterfly SRAM read/write pattern with a bulk load-compute-store architecture. The core idea is to eliminate the SRAM bottleneck (which consumed 88.8% of baseline cycles) by:

1. **LOAD phase** -- Bulk-read all twiddle factors and input data from SRAM into on-chip register files
2. **COMPUTE phase** -- Execute all 5 FFT stages entirely from registers (no SRAM access)
3. **STORE phase** -- Bulk-write results back to SRAM

The register file consists of:
- **Data register file:** 32 complex values = 64 x 32-bit flip-flop registers (`data_re[0:31]`, `data_im[0:31]`)
- **Twiddle register file:** 5 complex twiddle factors = 10 x 32-bit flip-flop registers (`tw_re[0:4]`, `tw_im[0:4]`)

The FSM was redesigned from the baseline's 13-state machine (with separate read/compute/write states per butterfly) down to a clean **6-state machine**: `S_INIT -> S_LOAD_TWIDDLE -> S_LOAD_DATA -> S_COMPUTE -> S_STORE_DATA -> S_FINISH`.

### Commit History (7 commits)

```
4daf4e2  Setup baseline
dac9eca  Rerun the sim_behav to note cycles
af62201  Implement regs to store intermediate values
9cb2581  chore: stop tracking generated Innovus logs and temp files
232269a  Update FFT accelerator and apply comprehensive .gitignore
864ea23  chore: purge EDA databases, waveforms, and logs from git tracking
7752422  Set up reg only branch as base version (reports from parallel-bfly-regfile)
```

---

## 2. What They Discovered -- Results

### Cycle Count

The accelerator achieves **206 cycles** per 32-point FFT chunk (behavioral simulation), down from the baseline's **732 cycles**. This is a **3.55x speedup**.

The theoretical expected cycle count from the header comment:
- INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(80) + STORE(64) + FINISH(1) = **220 cycles**

The measured 206 cycles is actually **lower** than the predicted 220. This discrepancy arises because the FSM transitions between phases happen in the same cycle as the last operation of the previous phase (the `io_cnt == total - 1` check triggers the state transition on the same clock edge where the last data is captured). This is correct behavior -- the overlapping transition saves ~14 cycles.

Breakdown for N=32, 5 stages:
- LOAD_TWIDDLE: 10 cycles (2 x 5 twiddle factors)
- LOAD_DATA: 64 cycles (2 x 32 complex samples)
- COMPUTE: 80 butterflies (N/2 x log2(N) = 16 x 5 = 80)
- STORE_DATA: 64 cycles (2 x 32 complex samples)
- Overhead: ~2 cycles (INIT + FINISH transitions) minus overlap savings

### Latency

- **Accelerator runtime:** 206 cycles x 83.33 ns = **17.17 us** (down from baseline 61 us)
- **First chunk latency:** 17.17 us
- **Complete system latency:** ~122.98 ms (dominated by UART I/O and flash reads, not the accelerator)

### Area (post-PnR)

| Module | Cell Area |
|--------|-----------|
| **Total chip (et4351)** | **300,906 um²** |
| Accelerator (accel) | 181,432 um² (60.3% of chip) |
| -- FFT core (accel/fft) | 127,173 um² (42.3%) |
| -- SRAM (accel/mem) | 48,125 um² (16.0%) |
| PicoRV32 SoC (soc) | 119,140 um² (39.6%) |

The FFT core is very large at **127,173 um²** because all 74 x 32-bit data/twiddle registers are implemented as flip-flops rather than an SRAM macro. The 64 data registers alone account for 64 x 32 = 2,048 flip-flops, plus all the MUX logic for register-file indexing.

### Timing (post-synthesis)

- **Clock period:** 83.33 ns (12 MHz)
- **Critical path slack:** 32,347 ps (positive, no violations)
- Timing is comfortably met with ~39% margin

### Power (post-PnR, Voltus)

- **Total chip power:** 0.851 mW
- Accelerator power: 0.617 mW (72.5% of total)
  - FFT core: 0.295 mW (34.7%)
  - SRAM: 0.297 mW (35.0%)
- SoC: 0.207 mW (24.4%)

**Critical issue:** VCD annotation coverage is **0%** (`0/88835 = 0%`). The power numbers are based on default statistical estimation, not actual switching activity. This makes the power results unreliable.

### Energy Estimate

Energy per FFT = Power x Time = 0.617 mW x 17.17 us = **10.6 nJ**

However, since power annotation is 0%, this is unreliable. For comparison, the baseline was 24.6 nJ.

### Verification

- **Behavioral sim:** Passes -- output matches `expected_output.txt`
- **Structural sim:** Passes -- identical output
- **Physical sim:** Passes -- identical output (1,476,157 total cycles, 180 warnings but 0 errors)
- **DRC:** No violations
- **Connectivity:** No problems or warnings
- **All three simulation levels produce matching results**

---

## 3. Which Part of the Project

This is the **HP (High Performance) direction, D1 variant**: replacing the SRAM-based data flow with a register file to eliminate memory access cycles during FFT computation. The approach trades area (more flip-flops) for speed (fewer cycles).

This directly targets the baseline bottleneck: the original design spent 88.8% of its cycles on SRAM reads and writes. By doing SRAM access only in bulk LOAD/STORE phases and computing purely from registers, the per-butterfly cycle count drops from ~9 cycles (4 reads + compute + 4 writes) to 1 cycle.

---

## 4. Correctness Analysis

### RTL Correctness

The RTL design is **functionally correct** -- verified by matching simulation outputs at behavioral, structural, and physical levels.

Key correctness observations:

1. **Butterfly computation** is correct. The combinational block computes:
   - t = (v_re x w_re - v_im x w_im) >>> 12, same fixed-point arithmetic as baseline
   - Butterfly add/subtract: e = u + t, o = u - t
   - Twiddle rotation: w' = w x w_m for next butterfly

2. **Register file indexing** uses `idx_u = base + k` and `idx_v = base + k + half`, which correctly addresses the in-place butterfly operands.

3. **SRAM interface** uses the `accelerator_mem` async read (`assign rdata = mem[addr]`), which means the LOAD phases correctly capture data in the same cycle the address is presented (no read latency).

4. **Loop variable update logic** mirrors the baseline correctly:
   - Inner k loop, then base group advancement, then stage advancement
   - Twiddle factor reset to (1,0) at each new base group
   - `half` update uses `1 << stage` (before stage increment), which is correct

5. **`data_total` computation**: `number_data[IDX_W:0] << 1` uses bit range `[5:0]` which is 6 bits -- sufficient for N up to 32 (value 64 after shift). This is correct.

### Potential Concern: `stage - 1` Indexing

In the combinational butterfly block:
```verilog
w_re_next = (w_re * tw_re[stage - 1] - w_im * tw_im[stage - 1]) >>> SCALE;
```

`stage` starts at 1 and goes to `fft_stages` (5). So `stage - 1` ranges from 0 to 4, correctly indexing `tw_re[0:4]`. This is correct.

### Potential Concern: Off-by-One in LOAD Transitions

The `io_cnt == tw_total - 1` condition triggers the transition to the next state. Since `io_cnt` starts at 0 and the data is captured on the same clock edge, this correctly loads all 10 twiddle values (indices 0-9) and all 64 data values (indices 0-63). The counter reset to 0 at the end prepares it for the STORE phase. Correct.

### Difference from ShanghongLin-HP-D1-reg_bfly

**The two branches are 100% identical.** `git diff` shows zero differences across all files (RTL, firmware, reports, simulation outputs). Both branches share the same commit history (same 7 commits, same hashes). This means either:
- One person's work was copied to the other's branch, or
- Both branches were created from the same common work

This is a significant finding -- it means there is **no independent variation** between the two teammates' D1 implementations. For a team project, this suggests shared authorship rather than independent exploration.

---

## 5. What Was Done Well

1. **Clean FSM architecture**: The 6-state machine is well-structured and easy to understand. The separation of combinational next-state logic, combinational output logic, and sequential datapath follows textbook Moore FSM design practices.

2. **Well-documented RTL**: Comprehensive header comment explaining the architecture, expected cycle count, and phase breakdown. Internal comments are clear and helpful.

3. **Correct functional implementation**: All three simulation levels (behavioral, structural, physical) produce matching outputs with zero errors. The design passes DRC and connectivity checks.

4. **Significant performance improvement**: 206 cycles vs. 732 baseline = 3.55x speedup. This is a meaningful reduction that validates the register-file approach.

5. **Full flow completion**: The design has been taken through the entire ASIC flow -- synthesis, place-and-route, with timing closure achieved (positive slack).

6. **Preserved interface compatibility**: The `accelerator.v` wrapper and firmware (`accel_audio.c`) are unchanged, meaning the register-file optimization is a drop-in replacement for the baseline FFT core.

7. **SRAM is retained for CPU data exchange**: The `accelerator_mem` module correctly serves as the interface between the PicoRV32 CPU and the accelerator -- CPU writes data to SRAM, accelerator loads it, computes, and stores results back.

---

## 6. What Was Not Done or Done Wrong

### Critical Issues

1. **Power annotation is 0%**: The Voltus power report shows `Design annotation coverage: 0/88835 = 0%`. This means the VCD file was not properly loaded or matched to the post-PnR netlist. The reported power numbers (0.851 mW total) are based on statistical defaults and cannot be trusted for energy comparison against the baseline.

2. **Reports mismatch**: The top commit message states *"Note that reports files are still the one in parallel-bfly-regfile"*. This explicitly acknowledges that the synthesis/PnR reports may not correspond to the current RTL. This undermines confidence in the area, timing, and power numbers. The reports should have been regenerated for the exact RTL on this branch.

3. **Branch is identical to ShanghongLin's**: Zero diff between the two branches. For a team project, each member should ideally contribute independent work or at minimum clearly delineate who authored what. Having identical branches makes individual contribution assessment impossible.

### Missing Elements

4. **No energy-delay product (EDP) analysis**: The project requires comparing HP designs on metrics like EDP = Energy x Latency. No such analysis is present.

5. **No comparison table against baseline**: While the cycle count improvement is measurable from the transcript, there is no structured comparison document showing baseline vs. optimized metrics (cycles, area, power, energy, EDP).

6. **No exploration of design variants**: The D1 direction could explore different register-file sizes (e.g., partial register file for larger FFTs), clock gating on idle registers, or different addressing schemes. Only one variant is implemented.

7. **No clock gating**: The 2,048+ data flip-flops toggle freely. During LOAD and STORE phases, the compute datapath registers are idle but still receiving clock edges. Clock gating could significantly reduce dynamic power.

8. **`bf_cnt` ghost register**: The synthesis sequential report shows `bf_cnt_reg` flip-flops (4 bits) that do not appear in the RTL source. This could be a synthesis artifact from an older version of the code or from the mismatched reports issue.

9. **No scalability analysis**: The register-file approach only works for small N (32). For N=64 or N=128, the register count doubles or quadruples, making this approach impractical. No discussion of this limitation is provided.

10. **Structural/physical sim cycle counts not measured**: The testbench only measures accelerator cycles in behavioral mode (`is_sim_behav`). Structural and physical sims report `N/A` for accelerator runtime.

---

## 7. Recommendations

### Immediate (to complete the deliverable)

1. **Re-run synthesis and PnR** with the exact RTL from this branch. The mismatched reports undermine all area/power/timing claims.

2. **Fix VCD-based power analysis**: Ensure the structural simulation generates a VCD file that correctly maps to the post-PnR netlist. Re-run Voltus with proper annotation. Target >80% annotation coverage.

3. **Create a comparison table**:

   | Metric | Baseline | Register-file D1 | Improvement |
   |--------|----------|-------------------|-------------|
   | Cycles per FFT | 732 | 206 | 3.55x |
   | Accelerator latency | 61 us | 17.2 us | 3.55x |
   | FFT core area | (baseline) | 127,173 um² | (measure delta) |
   | Energy per FFT | 24.6 nJ | ? (needs VCD) | ? |
   | EDP | ? | ? | ? |

4. **Differentiate from ShanghongLin's branch**: If both people worked on this together, document the split of work clearly. If the intent is separate branches, make distinct design choices.

### Design Improvements

5. **Add clock gating** to the data register file. During LOAD_TWIDDLE and STORE_DATA states, the data registers are not being written -- their clock can be gated. This is likely the single biggest power optimization available.

6. **Pipeline the butterfly**: The combinational path from register read through two multiplies, two adds, and a register write is long. At higher clock frequencies, this would become the critical path. Consider registering the multiply outputs to enable higher fmax.

7. **Explore partial register file**: For scalability to N=64+, load data in blocks (e.g., 32 values at a time) rather than all at once. This trades some cycles for reduced register count.

8. **Enable accelerator cycle measurement in structural/physical sims**: Modify the testbench to track accelerator cycles regardless of simulation mode, or pass the `is_sim_behav` flag in all modes.

### Documentation

9. Write a brief design document explaining the architectural decisions, tradeoffs (area vs. speed), and the relationship between this D1 approach and other HP directions being explored by the team.

---

## Summary

FranzJosef's register-file FFT accelerator is a **functionally correct** and **architecturally sound** optimization that achieves a 3.55x cycle reduction over the baseline by eliminating per-butterfly SRAM accesses. The RTL is clean, well-commented, and passes all verification stages. However, the branch suffers from **mismatched backend reports** (explicitly acknowledged in the commit message), **0% power annotation coverage**, and is **byte-for-byte identical to ShanghongLin's branch**, raising questions about independent contribution. The key next steps are to regenerate accurate reports, fix the power analysis, and document the design tradeoffs.
