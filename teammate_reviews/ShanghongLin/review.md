# Review: Shanghong Lin -- HP (High-Performance) Design Lead

## Project Context

ET4351 FFT Accelerator for PicoRV32 RISC-V SoC, TU Delft 2026.
N=32 radix-2 DIT FFT, 5 stages. Baseline: 732 cycles, 61 us @ 12 MHz, 24.6 nJ.
Baseline bottleneck: 88.8% of cycles spent on SRAM reads/writes per butterfly.

---

## 1. What They Did: Progressive Optimization Journey (D1 -> D2 -> D3 -> D6)

Shanghong pursued a systematic, incremental strategy across four branches. Each
branch builds cleanly on the previous one and targets a specific bottleneck.
Branches D4, D5, D7, D8 are absent from the remote (parked or never created),
and the design jumps from D3 directly to D6.

### D1: Register-File Architecture (`ShanghongLin-HP-D1-reg_bfly`)

**Core idea:** Eliminate per-butterfly SRAM traffic by holding all 32 complex
data values and 5 twiddle primitives in register files inside the accelerator.

**FSM redesign from baseline's per-butterfly SRAM access to three bulk phases:**

    INIT -> LOAD_TWIDDLE -> LOAD_DATA -> COMPUTE -> STORE_DATA -> FINISH

- `data_re[0:31]`, `data_im[0:31]` -- 64 x 32-bit registers for complex data
- `tw_re[0:4]`, `tw_im[0:4]` -- 10 x 32-bit registers for twiddle primitives
- LOAD_TWIDDLE: 10 cycles (reading 5 complex twiddle pairs from SRAM)
- LOAD_DATA: 64 cycles (reading 32 complex samples, interleaved re/im)
- COMPUTE: 80 cycles (5 stages x 16 butterflies, 1 butterfly/cycle)
- STORE_DATA: 64 cycles (writing results back)

**Cycle count:** INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(80) + STORE(64) + FINISH(1) = **220 cycles**

**Butterfly datapath (combinational):**
```
t_re = (data_re[idx_v] x w_re - data_im[idx_v] x w_im) >>> 12
t_im = (data_re[idx_v] x w_im + data_im[idx_v] x w_re) >>> 12
e = u + t,  o = u - t
```

The twiddle rotation `w' = w x w_m` is computed inline for sequential
butterflies within each group. Loop control mirrors the baseline's nested
stage/base/k structure.

**Result:** 732 -> 220 cycles = **3.33x speedup**. Bottleneck shifts from
SRAM traffic to LOAD/STORE phases (128 of 220 cycles = 58%).

---

### D2: 2x Parallel Butterflies (`ShanghongLin-HP-D2-reg_parallel_bfly`)

**Core idea:** Dual butterfly units process two independent butterflies per
cycle, halving the compute phase. Also introduces a pre-stage twiddle fill
sub-phase for bit-exact results.

**Key architectural changes:**
- Two butterfly datapaths (`bf0`, `bf1`) operating on `j = bf_cnt` and
  `j = bf_cnt + 1` simultaneously
- Linear butterfly indexing replaces the nested base/k loops:
  ```
  group  = j >> (stage - 1)
  k_loc  = j & (half_cur - 1)
  idx_u  = (group << stage) | k_loc
  idx_v  = idx_u | half_cur
  tw_idx = k_loc  (direct index into per-stage table)
  ```
- Per-stage twiddle table `tw[0..HALF_N-1]` filled by chaining:
  `tw[k] = tw[k-1] x prim[stage-1]`
- COMPUTE has two sub-phases: FILL (build twiddle table) then BUTTERFLY
- `prim_re/im[0:4]` stores 5 primitive twiddle factors
- `tw_re/im[0:15]` stores the per-stage expanded twiddle table
- `compute_phase` register: 0 = fill, 1 = butterfly

**Cycle count:** INIT(1) + LOAD_TW(10) + LOAD_DATA(64)
+ COMPUTE(stage1: 0+8, stage2: 1+8, stage3: 3+8, stage4: 7+8, stage5: 15+8 = 66)
+ STORE(64) + FINISH(1) = **206 cycles**

Fill overhead per stage: 0, 1, 3, 7, 15 cycles = 26 cycles total.
Butterfly cycles: 5 x 8 = 40 (halved from 80).

**Result:** 220 -> 206 cycles = **3.55x speedup** over baseline.
Marginal gain (6.4%) because twiddle fill overhead partially offsets the
parallel butterfly savings. The LOAD/STORE phases still dominate (62%).

---

### D3: SW Twiddle Preload via CSR (`ShanghongLin-HP-D3-twiddle_preload`)

**Core idea:** Move ALL twiddle factor computation to firmware. Pre-compute
N/2 = 16 global twiddle factors $W_N^k$ and load them into CSR registers
BEFORE asserting `enable_accel`. This completely removes both the
LOAD_TWIDDLE state and the per-stage FILL sub-phase from the timed window.

**Key architectural changes:**
- New module ports: `tw_re_packed[512-1:0]`, `tw_im_packed[512-1:0]`
  (16 x 32-bit packed flat buses for twiddle data)
- Twiddle arrays become wires unpacked from CSR via `generate` block:
  ```
  assign tw_re[gi] = $signed(tw_re_packed[32*gi +: 32]);
  ```
- FSM simplified to 5 states: INIT -> LOAD_DATA -> COMPUTE -> STORE_DATA -> FINISH
- SRAM no longer stores twiddle factors -- only data. SRAM address space halved.
- Global twiddle indexing: `tw_idx = k_loc << (fft_stages - stage)`
  maps per-stage needs into the global $W_N^k$ table
- Wrapper (`accelerator.v`) expanded with 35 CSR registers:
  `iomem_accel[0..2]` = config, `iomem_accel[3..34]` = twiddle re/im pairs
- SRAM base address shifts from `0x03000010` to `0x0300008C`

**Firmware changes (`accel_audio.c`):**
- Flash layout changed: twiddle section now contains N/2 global twiddle pairs
  (was: log2(N) per-stage primitives)
- Firmware writes twiddles to `ACCEL_TW_CSR_START_ADDR` (0x0300000C) via
  memory-mapped CSR writes BEFORE enabling the accelerator
- `flog2()` replaced with manual bit-shift loop for `bits` calculation
- SRAM data starts at index 0 (no twiddle offset in SRAM)

**Cycle count:** INIT(1) + LOAD_DATA(64) + COMPUTE(5 x 8 = 40) + STORE(64) + FINISH(1) = **170 cycles**

**Result:** 206 -> 170 cycles = **4.31x speedup** over baseline.
Compute phase now only 40 cycles (23.5% of total). LOAD/STORE still
dominates at 128 cycles (75.3%).

**PnR verified:** Same timing reports as D6 (the reports appear to be from
the D3/D6 run). WNS = +34.108 ns (met) at 83.33 ns clock period (12 MHz).

---

### D6: 4-Stage Pipelined Butterfly (`ShanghongLin-HP-D6-Overlap_Pipeline`)

**Core idea:** Pipeline the butterfly computation into 4 stages to shorten
the critical path, enabling a ~5x clock frequency increase (12 MHz -> 60 MHz).
The pipeline achieves 1 butterfly-pair throughput per cycle after fill.

**Pipeline stages:**
```
  FETCH (Phase 0): Combinational address gen. Latch operands from register file.
  MUL1  (Phase 1): Raw multiplications (v_re x tw_re, v_im x tw_im, v_re x tw_im, v_im x tw_re)
  MUL2  (Phase 2): Subtract/add products, arithmetic right-shift by SCALE. Latch t values.
  ADD   (Phase 3): Final butterfly (e = u + t, o = u - t). Write back to register file.
```

**Pipeline registers (per butterfly unit, x2 for bf0/bf1):**
- Stage 1: `stg1_bf{0,1}_{u_re, u_im, v_re, v_im, tw_re, tw_im, idx_u, idx_v}`
- Stage 2: `stg2_bf{0,1}_{rr, ii, ri, ir, u_re, u_im, idx_u, idx_v}`
  (rr/ii/ri/ir are `MEM_WIDTH + TW_WIDTH - 1 : 0` = 47-bit products)
- Stage 3: `stg3_bf{0,1}_{t_re, t_im, u_re, u_im, idx_u, idx_v}`

**Pipeline control:**
- `pipe_vld[2:0]` -- 3-bit shift register tracking valid data in pipeline
- `pump` signal: `(state_reg == S_COMPUTE) && (bf_cnt < half_n)`
- Each cycle: `pipe_vld <= {pipe_vld[1:0], pump}`
- `pipe_last_drain`: `(pipe_vld == 3'b100) && !pump` -- pipeline about to empty
- Stage transition only when pipeline fully drained (`pipe_last_drain`)

**Twiddle width optimization:**
- New parameter `TW_WIDTH = 16` (reduced from 32-bit)
- Twiddle factors truncated to 16 bits during unpack:
  `assign tw_re[gi] = $signed(tw_re_packed[MEM_WIDTH*gi +: TW_WIDTH]);`
- Pipeline stage 2 products are `MEM_WIDTH + TW_WIDTH - 1 : 0` = 48 bits wide
  (was 64-bit with 32x32 multiply), reducing multiplier area

**Clock frequency increase:**
- SDC constraint changed from `CLK_PERIOD = 83.33` (12 MHz) to
  `CLK_PERIOD = 16.67` (~60 MHz) -- a 5x frequency boost
- Post-route WNS = +34.108 ns -- timing met with massive positive slack
  (This appears suspicious; see correctness analysis below)

**Cycle count per stage:** 8 fetch cycles + 3 drain cycles = 11 cycles/stage.
Total compute: 11 x 5 = 55 cycles.
**Total:** INIT(1) + LOAD_DATA(64) + COMPUTE(55) + STORE(64) + FINISH(1) = **185 cycles**

**Latency at 60 MHz:** 185 x 16.67 ns = **~3.08 us**
**Speedup over baseline:** 61 us / 3.08 us = **~19.8x latency improvement**

---

## 2. What They Discovered

### Performance progression and bottleneck shifts:

| Design | Cycles | Clock   | Latency | Speedup | Bottleneck                     |
|--------|--------|---------|---------|---------|--------------------------------|
| Base   |    732 | 12 MHz  | 61.0 us |   1.0x  | 88.8% SRAM read/write          |
| D1     |    220 | 12 MHz  | 18.3 us |   3.3x  | 58% LOAD/STORE                 |
| D2     |    206 | 12 MHz  | 17.2 us |   3.6x  | 62% LOAD/STORE + fill overhead |
| D3     |    170 | 12 MHz  | 14.2 us |   4.3x  | 75% LOAD/STORE dominates       |
| D6     |    185 | 60 MHz  |  3.1 us |  19.8x  | 69% LOAD/STORE at higher freq  |

### Key insights:
1. **Register file was the single most impactful change** (D1: 3.33x). Eliminating
   per-butterfly SRAM round-trips was worth more than all subsequent compute
   optimizations combined at the same frequency.
2. **Parallel butterflies had diminishing returns** (D2: only 6.4% gain over D1)
   because the twiddle fill overhead (26 cycles) partially consumed the savings
   from halving the butterfly count (40 saved).
3. **HW/SW co-design unlocked the next gain** (D3). Moving twiddle precomputation
   to firmware was a clean architectural insight -- it simplified the FSM, removed
   hardware state, and cut 36 cycles.
4. **Frequency scaling via pipelining was the dominant lever for latency** (D6).
   The 5x clock boost converted a modest 185-cycle design into a ~3 us solution.
   Cycles actually increased (170 -> 185) due to pipeline drain overhead, but
   the frequency gain far outweighed it.
5. **LOAD/STORE remains the persistent bottleneck** across all designs.
   At 128 cycles out of 185 (69%), the serial SRAM interface is still the
   limiting factor. The natural next step would be wider memory interfaces
   or DMA, but these were not pursued.

---

## 3. Which Part of the Project

Shanghong is the **HP (high-performance) design lead**, responsible for
optimizing latency and throughput of the FFT accelerator. The work focused
purely on cycle count reduction and clock frequency scaling, without explicit
energy or area optimization targets (those belong to the LP lead).

---

## 4. Correctness Analysis of D6 Pipeline RTL

### 4.1 Pipeline Hazard Analysis: Read-After-Write (RAW) Dependency

**Critical concern: intra-stage RAW hazards on `data_re/im` register file.**

The pipeline has 3 cycles of latency (FETCH to ADD writeback). When the FETCH
stage reads `data_re[idx_u]` / `data_re[idx_v]`, the ADD stage may be writing
to those same indices from a butterfly that entered the pipeline 3 cycles earlier.

For N=32 with 2x parallel butterflies, each stage processes 16 butterflies
in 8 pump cycles (bf_cnt = 0, 2, 4, ..., 14). The question is whether
butterfly pair at `bf_cnt = k` writes to indices that are read by the pair
at `bf_cnt = k + 2`, `k + 4`, or `k + 6` (1, 2, or 3 cycles later).

**Stage 1 (half_cur = 1, m = 2):**
- bf_cnt=0: bf0 reads/writes indices {0,1}, bf1 reads/writes {2,3}
- bf_cnt=2: bf0 reads/writes {4,5}, bf1 reads/writes {6,7}
- ...
- All butterfly pairs operate on disjoint index pairs. **No hazard.**

**Stage 2 (half_cur = 2, m = 4):**
- bf_cnt=0: bf0 operates on {0,2}, bf1 on {1,3}
- bf_cnt=2: bf0 operates on {4,6}, bf1 on {5,7}
- ...
- Groups are separated by stride m=4. Adjacent pairs touch disjoint indices. **No hazard.**

**Stage 3 (half_cur = 4, m = 8):**
- bf_cnt=0: bf0 -> {0,4}, bf1 -> {1,5}
- bf_cnt=2: bf0 -> {2,6}, bf1 -> {3,7}
- bf_cnt=4: bf0 -> {8,12}, bf1 -> {9,13}
- ...
- Within each group of 8, butterflies 0-3 operate on indices {0..7}. But
  bf_cnt=0 and bf_cnt=2 are only 1 cycle apart, and they access different
  pairs within the same group. Specifically:
  - bf_cnt=0 writes {0,4,1,5} at ADD (3 cycles later)
  - bf_cnt=2 reads {2,6,3,7} at FETCH (immediately)
  - **No overlap -> no hazard.**

**Stage 4 (half_cur = 8, m = 16):**
- bf_cnt=0: bf0 -> {0,8}, bf1 -> {1,9}
- bf_cnt=2: bf0 -> {2,10}, bf1 -> {3,11}
- bf_cnt=4: bf0 -> {4,12}, bf1 -> {5,13}
- bf_cnt=6: bf0 -> {6,14}, bf1 -> {7,15}
- bf_cnt=8: bf0 -> {16,24}, bf1 -> {17,25}  (new group)
- Within the first group (indices 0-15), bf_cnt goes 0,2,4,6 over 4 cycles.
  The ADD of bf_cnt=0 happens when bf_cnt=6 is being fetched (3 cycles later).
  bf_cnt=0 writes to {0,8,1,9}; bf_cnt=6 reads {6,14,7,15}. **No overlap -> no hazard.**

**Stage 5 (half_cur = 16, m = 32):**
- Only one group. bf_cnt goes 0,2,4,...,14 over 8 cycles.
- bf_cnt=0: bf0 -> {0,16}, bf1 -> {1,17}
- bf_cnt=6 (3 cycles later): bf0 -> {6,22}, bf1 -> {7,23}
- bf_cnt=0 writes {0,16,1,17}; bf_cnt=6 reads {6,22,7,23}. **No overlap.**

**Conclusion: For N=32 with P=2, the DIT butterfly access pattern guarantees
that no two butterfly pairs within 3 cycles of each other touch overlapping
indices.** The pipeline is hazard-free for this specific FFT size. However,
**this property is NOT guaranteed for arbitrary N or P values** -- the design
does not include any forwarding logic or hazard detection, which is a
fragility if the design were ever generalized.

### 4.2 Inter-Stage Drain Safety

The design waits for `pipe_last_drain` (= `pipe_vld == 3'b100 && !pump`)
before advancing to the next FFT stage. This means:
- All 8 pump cycles have completed (`bf_cnt >= half_n`, so `pump = 0`)
- The last valid data has reached the ADD stage (`pipe_vld[2] = 1`)
- The pipeline will write its final results this cycle

On the next cycle after `pipe_last_drain`:
- Stage advances: `stage <= stage + 1`, `bf_cnt <= 0`
- `pipe_vld` shifts to `{1, 0, 0}` -> `{0, 0, 0}` (all invalid since pump was 0)

Wait -- there is a subtlety. When `pipe_last_drain` fires:
- `pipe_vld == 3'b100` and `!pump`
- The `pipe_vld <= {pipe_vld[1:0], pump}` update makes it `{0, 0, 0}` next cycle
- But also `stage <= stage + 1` and `bf_cnt <= 0` happen
- On the NEXT cycle, `pump` will re-evaluate with the new stage and `bf_cnt = 0`
- Since `bf_cnt(0) < half_n(16)`, pump becomes 1 again
- But `pipe_vld` is now `3'b000`, so no stale data is in the pipeline

**This is correct.** There is exactly one dead cycle between stages where
the pipeline is empty and the new stage's first pump hasn't entered yet.
Total per-stage cost: 8 pump + 3 drain + 1 dead = 12 cycles... but the
header comment says 11. Let me re-check:

Actually, looking more carefully at the FSM transition logic:
- When `pipe_last_drain && !stage_is_last`: `stage <= stage + 1; bf_cnt <= 0;`
- This happens in the same cycle where `pipe_vld[2]` is writing back the last result
- Next cycle: stage is incremented, bf_cnt = 0, pipe_vld = 000
- pump re-evaluates as true (bf_cnt=0 < 16), so it immediately starts pumping

So the dead cycle IS the drain's final cycle (the drain write and the stage
advance happen simultaneously). The count is: 8 pump + 3 drain = 11 cycles,
where the stage advance happens on the last drain cycle. The comment's count
of 11 cycles/stage is **correct**.

Total compute: 5 x 11 = 55 cycles. But wait -- the first stage has no dead
cycle before it starts (pipeline is already empty from LOAD_DATA). And the
last stage needs all 3 drain cycles. So: first stage = 8 + 3 = 11.
Subsequent stages = 8 + 3 = 11 (the pump starts immediately after drain).
**Total = 5 x 11 = 55 compute cycles.** This matches the header comment but
the overall count of 185 seems to include INIT(1) + LOAD_DATA(64) + 55 + STORE(64) + FINISH(1) = 185. **Confirmed correct.**

### 4.3 Twiddle Width Truncation (TW_WIDTH = 16)

D6 introduces `TW_WIDTH = 16` as a parameter, truncating twiddle factors from
32 bits to 16 bits. The unpack logic takes the lower 16 bits:
```
assign tw_re[gi] = $signed(tw_re_packed[MEM_WIDTH*gi +: TW_WIDTH]);
```

With SCALE = 12, 16-bit twiddle factors provide only 4 bits of integer range
(1 sign bit + 3 integer bits + 12 fractional bits). Since twiddle factors are
in the range [-1, +1], this gives:
- Max representable: +1.999... (but twiddles never exceed |1|)
- Resolution: 2^(-12) = 1/4096

This is adequate for the FFT's numerical requirements but reduces precision
compared to the 32-bit path. The MUL1 products become 48-bit (32 x 16)
instead of 64-bit (32 x 32), which significantly reduces multiplier area --
a deliberate trade-off for higher clock frequency.

**Potential issue:** The firmware still writes 32-bit values to the CSR
registers, but only the lower 16 bits are used. The upper 16 bits of each
twiddle CSR word are silently discarded. This is functionally correct but
could cause subtle precision loss if the twiddle values have significant
energy in bits 16-31. For Q12 fixed-point twiddles in [-1, 1], bits 16-31
should be sign-extension, so truncation is safe.

### 4.4 Pipeline Valid Shift Register Sizing

`pipe_vld` is 3 bits for a 4-stage pipeline (FETCH/MUL1/MUL2/ADD). The
FETCH stage is implicit (controlled by `pump`), and `pipe_vld[0]` tracks
MUL1, `pipe_vld[1]` tracks MUL2, `pipe_vld[2]` tracks ADD. This mapping is
**correct** -- FETCH has no pipeline register of its own; it is the
combinational front-end.

### 4.5 PnR Timing: Hold Violations

**The D6 post-route hold timing report shows significant violations:**
- WNS (hold) = **-0.165 ns**
- TNS (hold) = **-41.580 ns**
- **457 violating paths** (all reg2reg)

This means the design does NOT close timing for hold at 60 MHz. The hold
violations indicate that some flip-flop-to-flip-flop paths are too fast
(data arrives before the hold time requirement of the capturing flop).

Additionally, the **setup WNS = +34.108 ns** at a 16.67 ns period seems
anomalous. A 34 ns positive slack on a 16.67 ns period means the actual
path delay is approximately 16.67 - 34.108 = negative, which is impossible.
Looking more carefully, the PnR report period is actually 83.33 ns (from
the clock report: period = 83.330). This suggests the **PnR was actually
run at 12 MHz (83.33 ns), NOT at 60 MHz as the SDC file claims**.

This is a discrepancy: the SDC in the source tree says 16.67 ns, but the
PnR clock report shows 83.33 ns. The PnR results may have been generated
from a different run or the SDC was changed after PnR. **The 60 MHz timing
closure claim is unverified.**

### 4.6 Max Transition Violations

The constraint report shows `max_transition` violations:
- Worst violation: -1.390 ns (pin `soc/spimemio/xfer/g3747/A0N`)
- Required: 0.280 ns, actual: 1.670 ns

And `max_capacitance` violations on the clock pin. These are DRV (design
rule violation) issues that need to be resolved for tapeout-quality results.

---

## 5. What Was Done Well

### Excellent progressive engineering methodology
Each branch builds cleanly on the previous one, with clear commit messages.
The D1 -> D2 -> D3 -> D6 progression demonstrates disciplined optimization:
identify the bottleneck, target it, measure, repeat.

### Outstanding RTL documentation
Every module has a detailed header comment explaining:
- The optimization strategy
- Cycle count breakdown with exact formulas
- Memory map and interface compatibility
- How it differs from the previous version

The inline comments throughout the RTL are thorough and explain the "why,"
not just the "what." Signal naming is consistent and descriptive
(`stg1_bf0_u_re`, `bf_pair_is_last`, `pipe_last_drain`).

### Clean FSM design
The separation of next-state logic (combinational), output logic
(combinational), and sequential datapath follows textbook synchronous design
practice. The FSM encoding is explicit (`localparam [2:0] S_INIT = 3'd0`).

### Correct pipeline architecture
The 4-stage pipeline in D6 is well-designed:
- Valid tracking via shift register is simple and correct
- Stage drain logic prevents inter-stage corruption
- Index propagation through all pipeline stages ensures correct writeback
- The `pump` / `pipe_last_drain` control signals are cleanly expressed

### HW/SW co-design insight (D3)
Moving twiddle computation to firmware was a key architectural insight. It
simplified the hardware (removed fill sub-phase and twiddle generation logic),
reduced SRAM usage, and cut cycles -- all without adding hardware complexity.
The global twiddle indexing formula `tw_idx = k_loc << (fft_stages - stage)`
is elegant.

### Correct linear butterfly indexing (D2+)
The transition from the baseline's nested `stage/base/k` loops to the linear
`bf_cnt` with combinational address generation is clean and enables parallelism.
The index derivation (`group`, `k_loc`, `idx_u`, `idx_v`) is correct for all
stages.

---

## 6. What Was Not Done or Done Wrong

### 6.1 Missing branches D4, D5, D7, D8
Only 4 of presumably 8 planned optimization steps were completed. The jump
from D3 to D6 suggests D4 and D5 were explored but abandoned (or the naming
skipped ahead to reflect the pipeline approach being "v6"). The absence of
D7/D8 means directions like wider memory interfaces, DMA-based LOAD/STORE,
or multi-point FFT support were not explored.

### 6.2 PnR timing closure at 60 MHz is NOT achieved
The most significant technical gap. The hold timing report shows 457
violating paths with TNS = -41.580 ns. The setup timing numbers suggest the
PnR may have been run with the 12 MHz (83.33 ns) constraint rather than the
16.67 ns constraint claimed in the SDC. The design needs to be re-run through
synthesis and PnR at the target 16.67 ns period with proper hold fixing.

### 6.3 Max transition and capacitance DRV violations
988 nets with max_tran violations and clock pin capacitance violations exist
in the PnR results. These must be resolved for sign-off quality.

### 6.4 No forwarding logic or hazard detection in pipeline
The pipeline relies on the mathematical property that N=32 DIT butterflies
with P=2 never create RAW hazards within the 3-cycle pipeline depth. This is
correct for the current parameters but brittle:
- Changing N to 8 could create hazards (half_n = 4, only 2 pump cycles,
  but pipeline depth is 3 -- though drain handles this)
- Increasing P to 4 would need re-analysis
- No assertion or runtime check catches this

### 6.5 LOAD/STORE remains the dominant bottleneck (128/185 = 69%)
After all compute optimizations, serial SRAM access still accounts for ~69%
of cycles. Potential solutions not explored:
- Dual-port SRAM or wider data bus (load 2 words/cycle)
- Burst/DMA transfer from CPU
- Overlapping LOAD with first-stage COMPUTE (streaming pipeline)

### 6.6 Power annotation coverage is 0%
The power report shows: `Design annotation coverage: 0/88835 = 0%`
This means the VCD switching activity was not properly loaded during power
analysis. The 0.85 mW total power figure is based on default activity
assumptions and is unreliable.

### 6.7 No testbench or simulation evidence in commits
The branches do not include simulation logs, waveform screenshots, or
automated testbench results that demonstrate functional correctness of each
optimization step. The commit "Synth verified for twiddle preload ver." on D3
suggests synthesis was checked, but there is no equivalent verification note
for D6's pipeline correctness.

### 6.8 Twiddle width reduction (32 -> 16 bit) lacks justification
The `TW_WIDTH = 16` parameter is introduced without analysis of the
numerical impact. While it is likely sufficient for the Q12 fixed-point
representation, no SNR analysis or comparison with the 32-bit baseline
results was documented.

---

## 7. Recommendations for Final Submission

### Priority 1: Fix PnR timing closure at 60 MHz
1. Rerun synthesis with `CLK_PERIOD = 16.67`
2. Ensure PnR uses the same constraint
3. Fix hold violations (add buffers, adjust clock tree)
4. Resolve max_tran and max_cap DRVs
5. If 60 MHz is infeasible, find the actual achievable Fmax

### Priority 2: Verify D6 functional correctness
1. Run behavioral simulation comparing D6 output against Python golden reference
2. Run post-synthesis simulation at 60 MHz
3. Run post-layout simulation with SDF back-annotation
4. Document bit-exact or acceptable-error results

### Priority 3: Fix power analysis
1. Generate proper VCD with full switching activity from simulation
2. Re-run `report_power` with annotated VCD
3. Compute energy = power x latency for fair comparison with baseline

### Priority 4: Attack LOAD/STORE bottleneck
Consider for the final design iteration:
- Wider memory interface (2x32 or 4x32 read bus)
- Overlap LOAD phase with early COMPUTE stages (stream-in architecture)
- This could reduce total cycles from 185 to ~120 range

### Priority 5: Documentation for report
- Add cycle-accurate breakdown table in the project report
- Include area comparison across D1-D6 (the D6 FFT core is 127,173 um^2,
  45,575 instances)
- Document the TW_WIDTH trade-off with SNR or bit-error analysis
- Create a clear diagram of the 4-stage pipeline microarchitecture

---

## Summary

Shanghong's HP optimization work demonstrates strong RTL design skills and a
methodical approach to performance optimization. The progression from register-file
(D1, 3.3x) through parallel butterflies (D2, 3.6x), SW twiddle preload (D3, 4.3x),
to pipelined execution (D6, ~20x) is well-structured and well-documented.

The D6 pipeline design is architecturally sound and functionally correct for N=32.
The main gap is that **PnR timing closure at 60 MHz has not been demonstrated**,
with 457 hold violations and evidence that the PnR was run at the original 12 MHz
constraint. Resolving this is the critical path item for the final submission.

The persistent LOAD/STORE bottleneck (128 cycles, 69%) represents the largest
remaining opportunity for further speedup but would require memory subsystem
changes beyond the accelerator RTL.
