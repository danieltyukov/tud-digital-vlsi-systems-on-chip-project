# Review of Alessandro Cagnacci's Branch (`remotes/origin/Alessandro`)

**Reviewer:** Daniel Tyukov
**Date:** 2026-03-18
**Branch:** `remotes/origin/Alessandro`
**Commits:** 7 (from `47109f0` to `122201e`)

---

## 1. What They Did

Alessandro contributed two RTL variants of the FFT accelerator, both targeting the **High-Performance (HP)** optimization direction. The core architectural idea is a **register-file architecture** that eliminates the baseline's per-butterfly SRAM access pattern (which accounts for 88.8% of baseline cycles) by restructuring execution into three bulk phases:

1. **LOAD** -- Bulk-read all twiddle factors and input data from SRAM into on-chip register files
2. **COMPUTE** -- Execute all 5 FFT stages register-to-register (zero SRAM traffic)
3. **STORE** -- Bulk-write results back to SRAM

This replaces the baseline's 9-state-per-butterfly FSM (4 reads + 1 compute + 4 writes) with a single-cycle-per-butterfly compute phase.

### v1: Register-File FFT (Clean Baseline Refactor)

File: `accelerator_fft_v1.v` (366 lines)

Three changes from the baseline:

1. **Datapath moved from `always @(*)` to `wire` + `assign`** -- All butterfly arithmetic (`t_re`, `t_im`, `bf_e_re/im`, `bf_o_re/im`, `w_re_next`, `w_im_next`) converted from `reg` inside combinational always blocks to explicit `wire`/`assign`. Numerically identical to baseline.

2. **`idx_v` optimization** -- Changed from `base + k + half` to `idx_u + half`, where `idx_u = base + k`. This removes one adder from the register-file read-address critical path.

3. **Register files removed from reset clause** -- `data_re/im` and `tw_re/im` arrays are not reset since they are fully overwritten during LOAD phases before any read. This reduces reset fanout by 74 registers.

**Expected cycle count (from header comment):**
INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(80) + STORE(64) + FINISH(1) = 220

### v2: Pipelined Butterfly (2-Stage Pipeline)

File: `accelerator_fft_v2.v` (544 lines)

Adds a **2-stage pipeline** to the butterfly computation:

- **Stage 1 (MULTIPLY):** Latches the four raw 64-bit products (`data_re[idx_v] * w_re`, `data_im[idx_v] * w_im`, etc.) plus u-operands, write-back addresses, and loop-termination flags into pipeline registers.
- **Stage 2 (ACCUMULATE/BUTTERFLY):** Purely combinational -- subtracts/adds the registered products, applies `>>> SCALE`, and produces butterfly outputs.

The pipeline introduces a **1-cycle drain** at the end of COMPUTE: when the last butterfly's products are latched in stage 1, a `drain_cycle` flag holds the FSM in S_COMPUTE for one extra cycle so stage 2 can write back the final result.

**README states:** "Pipelining added, improved slack, tested at clk period 12.5" (implying 80 MHz target).

---

## 2. What They Discovered

- The baseline's main bottleneck is SRAM access (650 of 732 cycles = 88.8%), not computation. By moving data into register files, compute becomes the dominant phase at 80 cycles (1 cycle per butterfly x 80 butterflies for N=32 DIT).
- Total cycle count drops from 732 to ~220: a **3.33x speedup** in cycle count.
- The v1 wire/assign refactoring does not change functionality but gives the synthesizer more optimization freedom (no implied latch inference risk from incomplete always blocks).
- The `idx_v = idx_u + half` optimization shortens the critical path for register-file addressing.
- Pipelining (v2) breaks the multiply-accumulate-butterfly chain into two stages, improving timing slack. The README claims a 12.5 ns clock period (80 MHz), compared to the baseline's 83.33 ns (12 MHz). At 80 MHz and ~221 cycles, latency would be approximately 221 x 12.5 ns = 2.76 us -- a **~22x improvement** over baseline.

---

## 3. Which Part of the Project

**High-Performance (HP) variant.** Both v1 and v2 target latency reduction. The register-file architecture is listed as optimization D1 in the project status (732 -> 220 cycles, verified in synthesis). The pipelined v2 aligns with D6 (pipelined butterfly targeting ~60+ MHz).

There is no energy-efficient (EE) work on this branch.

---

## 4. Correctness Analysis

### v1 Correctness

**Generally correct, with some concerns:**

**a) Twiddle factor count and addressing:**
The twiddle load phase reads `tw_total = fft_stages << 1` words (for N=32, fft_stages=5, so 10 words = 5 real + 5 imaginary). The twiddle register file is sized `[0:MAX_FFT_STAGES-1]` = `[0:4]` = 5 entries. The indexing `tw_re[io_cnt[IO_CNT_W-1:1]]` correctly maps pairs of SRAM words to (re, im) entries. This appears correct.

**b) Data load/store count:**
`data_total = number_data[IDX_W:0] << 1`. For N=32, `number_data[5:0]` = 6'b100000 = 32, so `data_total` = 64. Loading 64 words fills 32 complex entries -- correct.

**c) Butterfly computation:**
The butterfly is:
```
t = (data[v] * w) >>> 12
data[u] = data[u] + t
data[v] = data[u] - t
```
This matches standard radix-2 DIT. The 64-bit intermediate products before `>>> SCALE` correctly prevent overflow. Fixed-point rounding is identical to baseline.

**d) Loop termination logic:**
```verilog
assign butterfly_loop_finished = (next_k == half);
assign base_loop_finished      = (next_base == number_data);
assign stage_loop_finished     = (stage == fft_stages);
assign all_done = butterfly_loop_finished & base_loop_finished & stage_loop_finished;
```

**Potential issue with `stage_loop_finished`:** The condition is `stage == fft_stages`. For N=32, `fft_stages` = 5. The stage counter starts at 1 and increments after each stage completes. The last stage processed is stage 5 (since the loop body executes *then* checks if the *next* stage would exceed). When processing stage 5's last butterfly, `stage == 5 == fft_stages`, so `stage_loop_finished` is true. Combined with the other two flags, `all_done` fires. This appears correct -- the advance-to-next-stage block is skipped when `all_done` is true.

**e) Twiddle rotation index `tw_re[stage - 1'b1]`:**
When `stage` = 1, this accesses `tw_re[0]` (the first twiddle factor). When `stage` = 5, it accesses `tw_re[4]`. This is within bounds of the `[0:4]` array. Correct.

**f) `start_input_address` calculation:**
```verilog
assign start_input_address = {{(32-LOG_MAX_FFT_STAGES-1){1'b0}}, fft_stages, 1'b0};
```
This computes `fft_stages << 1` = 10 for N=32. Twiddle data occupies SRAM addresses 0..9, input data starts at address 10. This matches the baseline memory layout.

**g) SRAM interface -- asynchronous read assumption:**
The design drives `accel_mem_addr` combinationally from `io_cnt` and captures `accel_mem_rdata` on the next posedge. The header comment states "SRAM has async read so driving the current io_cnt each cycle is correct; rdata is valid before the next rising edge." This is correct for the PicoRV32 SoC's SRAM, which uses asynchronous read.

**h) Register file not reset (v1 only):**
In v1, `data_re/im` and `tw_re/im` are NOT cleared on reset. The comment says they are "fully overwritten by S_LOAD_TWIDDLE and S_LOAD_DATA before any read." This is true for the *first* run, but if the accelerator is reset mid-computation (via `reset_accel`) and restarted, the register files may contain stale data from a previous partial run during the S_COMPUTE phase *of the new run* (since LOAD fully overwrites them before COMPUTE, this is actually fine). **Verdict: correct, no functional bug.**

### v2 Correctness

**The pipeline adds complexity. Specific concerns:**

**a) Pipeline hazard -- read-after-write on register file:**
Consider consecutive butterflies in the same stage where butterfly k+1 reads a register that butterfly k just wrote. In the pipeline, butterfly k's write-back happens in stage 2 (one cycle after stage 1 latches k's products). Meanwhile, butterfly k+1's stage 1 reads the register file on the *same cycle* that k's write-back occurs.

Concretely: on cycle N, stage 1 latches products for butterfly k (reading `data_re[idx_v]`, `data_re[idx_u]`). On cycle N+1, stage 2 writes back k's results to `data_re[p_idx_u]` and `data_re[p_idx_v]`, while *simultaneously* stage 1 reads operands for butterfly k+1.

**Is there a conflict?** In a standard radix-2 DIT butterfly loop, consecutive butterflies within the same "base group" operate on *different* indices (u = base+k, v = base+k+half). As k increments, idx_u and idx_v change. Two consecutive butterflies k and k+1 will have:
- k: idx_u = base+k, idx_v = base+k+half
- k+1: idx_u = base+k+1, idx_v = base+k+1+half

These are distinct indices, so there is **no RAW hazard within a base group**.

However, **across base groups** (when base advances), the first butterfly of the new group could potentially overlap with indices from the last butterfly of the previous group. Since the pipeline drains naturally (the last butterfly of a group fires, then the loop resets k=0 and advances base), the stage-2 write-back for the last butterfly of the old group happens on the same cycle that stage-1 reads for the first butterfly of the new group. Since different base groups operate on non-overlapping index ranges (base .. base+m-1), there is **no conflict**.

**Across stages**, the pipeline does drain fully because new stages start after the advance logic fires, and the indices are completely reshuffled. **No hazard.**

**b) Drain cycle mechanism:**
When `butterfly_loop_finished && base_loop_finished && stage_loop_finished`, `drain_cycle` is set to 1. On the next cycle, the drain block runs: it sets `p_valid <= 0` and `drain_cycle <= 0`, while stage-2 write-back still executes (since `p_valid` was 1 at the start of that cycle). The FSM exit condition checks `p_valid && p_bf_done && p_base_done && p_stage_done && drain_cycle`.

**Wait -- there is a subtle issue here.** On the drain cycle, the sequential block sets `p_valid <= 1'b0` and `drain_cycle <= 1'b0`. But these are non-blocking assignments, so the *combinational* next-state logic still sees the old values (`p_valid=1`, `drain_cycle=1`) during that same cycle. The next-state logic evaluates `next_state = S_STORE_DATA`, and on the next posedge, `state_reg` transitions to `S_STORE_DATA`. The sequential block also clears `p_valid` and `drain_cycle` on that same posedge. So the FSM transitions correctly. **This is correct.**

**c) Stage-2 write-back during drain:**
During the drain cycle, `p_valid` is still 1 (old value), so the write-back:
```verilog
if (p_valid) begin
    data_re[p_idx_u] <= s2_bf_e_re;
    ...
end
```
executes for the final butterfly. **Correct.**

**d) `all_done` signal removed in v2:**
v2 removes the `all_done` wire from v1 and instead uses the per-flag checks in the pipeline context (`p_bf_done`, `p_base_done`, `p_stage_done`). The loop advance logic uses the non-pipelined flags directly (`butterfly_loop_finished`, `base_loop_finished`, `stage_loop_finished`), which is correct because the loop variables must advance for the *current* cycle's iteration, not the pipelined one.

**e) `idx_v` regression in v2:**
In v1, `idx_v = idx_u + half` (optimized). In v2, it regresses to `idx_v = base + k + half` (the original three-adder form). This is a minor regression in the address critical path but not a functional bug.

**f) Reset behavior in v2:**
v2 resets *all* register files (including `data_re/im` and `tw_re/im`) plus all pipeline registers. This is more conservative than v1 (which skipped resetting data/twiddle register files). The 74-register savings from v1 is lost, but correctness is not affected.

**g) Cycle count for v2:**
The pipeline adds exactly 1 extra cycle (the drain cycle) to the COMPUTE phase: 80 + 1 = 81 cycles.
Total: INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(81) + STORE(64) + FINISH(1) = **221 cycles**.

At 80 MHz (12.5 ns period): 221 x 12.5 ns = **2.76 us** latency. This is a **~22x improvement** over the 61 us baseline, well below the 61 us HP requirement.

### Summary of Correctness

| Aspect | v1 | v2 |
|--------|----|----|
| Butterfly math | Correct | Correct |
| Loop control | Correct | Correct |
| Pipeline hazards | N/A | No hazards (proven above) |
| Drain mechanism | N/A | Correct |
| SRAM interface | Correct | Correct |
| Memory addressing | Correct | Correct |
| Reset behavior | Correct (lean) | Correct (conservative) |

**No functional bugs found in either version.**

---

## 5. What Was Done Well

1. **Excellent architectural insight.** Identifying SRAM access as 88.8% of baseline cycles and eliminating it with register files is the highest-leverage optimization possible. Going from 732 to 220 cycles (3.33x) with a clean, simple restructuring is well-executed.

2. **Clean FSM design.** The 6-state FSM (INIT, LOAD_TWIDDLE, LOAD_DATA, COMPUTE, STORE_DATA, FINISH) is easy to understand, maps directly to the three-phase architecture, and maintains interface compatibility with the baseline `accelerator.v` wrapper.

3. **Thoughtful v1 refactoring.** Converting the datapath from `always @(*)` with `reg` to `wire`/`assign` is a best-practice move. It eliminates latch inference risk, gives the synthesizer maximum freedom for resource sharing and retiming, and makes the design easier to analyze for timing.

4. **Correct pipeline implementation (v2).** The 2-stage pipeline cleanly splits multiply from accumulate/butterfly. The drain-cycle mechanism is a correct solution to the pipeline-flush problem. The extensive comments explaining cycle-by-cycle behavior and the twiddle-rotation phase relationship are very helpful.

5. **Good documentation.** Both files have thorough header comments, section headers, and inline explanations. The README concisely describes what changed in each version.

6. **Critical-path awareness.** The `idx_v = idx_u + half` optimization in v1 shows awareness of adder chains in address computation. The pipeline split in v2 targets the multiply-accumulate chain, which is the natural critical path in a butterfly datapath.

7. **Reset fanout reduction (v1).** Removing 74 registers from the reset clause is a practical physical-design-aware optimization that reduces routing congestion around the reset tree.

---

## 6. What Was Not Done or Done Wrong

### Missing Elements

1. **No testbench or simulation results.** Neither version includes a testbench, simulation script, or evidence of functional verification. The README mentions "tested at clk period 12.5" for v2, but there is no VCD, waveform, or verify.py output to confirm this.

2. **No synthesis results.** The project status table (D1) says "VERIFIED (synth)" for the register-file architecture, but no synthesis reports, timing reports, or area reports are included on the branch. The claim of 80 MHz operation for v2 is unsubstantiated on this branch.

3. **No energy analysis.** Since this targets HP, energy is not the primary concern, but there is no discussion of the power impact of adding 64 x 32-bit registers (data_re + data_im) plus pipeline registers.

4. **No EE variant.** The branch contains only HP-direction work. This is expected if the team divided work, but it means Alessandro's contribution covers only one of the two required design variants.

5. **No firmware changes.** The register-file architecture uses the same SRAM interface as the baseline, so firmware does not need to change. However, this is not documented -- a brief note confirming firmware compatibility would be helpful.

### Issues and Regressions

6. **`idx_v` regression in v2.** v1 optimizes `idx_v = idx_u + half` (2-adder chain), but v2 reverts to `idx_v = base + k + half` (3-adder chain). Since v2 is the more advanced version, this optimization should have been carried forward. The address path feeds into the combinational multiply stage (stage 1 inputs), so it directly impacts the critical path before the pipeline register.

7. **Register file reset inconsistency.** v1 deliberately skips resetting data/twiddle register files (saving 74 registers of reset fanout), but v2 adds them back in a full reset loop:
   ```verilog
   for (i = 0; i < MAX_FFT_N; i = i + 1) begin
       data_re[i] <= 32'sd0;
       data_im[i] <= 32'sd0;
   end
   ```
   This reverses v1's reset fanout optimization without explanation. If the rationale in v1 was valid (data is overwritten before read), it should still apply in v2.

8. **Pipeline register count not documented.** v2 adds 8 x 64-bit product registers, 2 x 32-bit operand registers, 2 x 5-bit index registers, 3 flag bits, and 2 control bits. That is approximately 8 x 64 + 2 x 32 + 2 x 5 + 5 = 587 additional flip-flops. The area impact of this should be estimated.

9. **`start_input_address` inconsistency between v1 and v2.** In v1:
   ```verilog
   assign start_input_address = {{(32-LOG_MAX_FFT_STAGES-1){1'b0}}, fft_stages, 1'b0};
   ```
   In v2:
   ```verilog
   assign start_input_address = fft_stages << 1;
   ```
   Both compute `fft_stages x 2`, but the v2 form relies on implicit zero-extension of the shift, while v1 is explicit. The v2 form is cleaner but inconsistent -- the two should be reconciled.

10. **Twiddle rotation is NOT pipelined in v2.** The comment in v2 says:
    > "The critical path of this path is one multiplier + one adder, which is identical to stage-1 and does NOT chain through any pipeline flop."

    However, `w_re_next` and `w_im_next` are computed combinationally and registered into `w_re`/`w_im` on the same posedge. This path (2 multiplies + 1 add/sub + `>>> SCALE`) runs in parallel with the butterfly pipeline stage 1 but is **not itself pipelined**. If the critical path is in the twiddle rotation rather than the butterfly, the pipeline does not help. This should be verified in synthesis timing reports.

11. **No `all_done` equivalent for early exit in v2.** In v2, the transition out of S_COMPUTE requires the pipeline to fill (`p_valid`), drain (`drain_cycle`), and check all three pipeline done flags. For edge cases like N=2 (1 butterfly total), the pipeline latency overhead (fill + drain = 2 extra cycles) is proportionally larger. This is not a bug but is worth noting.

12. **`tw_total` and `data_total` use different computation styles.** In v1:
    ```verilog
    assign tw_total   = {fft_stages, 1'b0};
    assign data_total = {number_data[IDX_W:0], 1'b0};
    ```
    In v2:
    ```verilog
    assign tw_total   = fft_stages << 1;
    assign data_total = number_data[IDX_W:0] << 1;
    ```
    Both are functionally equivalent, but the inconsistency suggests copy-paste divergence rather than a deliberate change.

13. **README is extremely brief.** The README is 9 lines long. For a project of this complexity, it should include:
    - Block diagram of the register-file architecture
    - Cycle count breakdown table
    - Synthesis results (area, timing, power)
    - Simulation verification evidence
    - Comparison against baseline

---

## 7. Recommendations

### High Priority (Before Merging to Main)

1. **Carry forward the `idx_v = idx_u + half` optimization to v2.** This is a one-line fix:
   ```verilog
   assign idx_v = idx_u + half[IDX_W-1:0];
   ```
   It removes one adder from the stage-1 input path.

2. **Remove the register-file reset loop in v2** (or document why it is needed). If v1's reasoning is correct, the same applies to v2 and saves 2048 flip-flop resets.

3. **Run and include synthesis results.** At minimum, provide:
   - Area report (does the design fit in 596.4 um x 596.4 um?)
   - Timing report (does v2 actually close at 80 MHz?)
   - Critical path identification (is it in the butterfly pipeline or the twiddle rotation?)

4. **Run behavioral simulation.** Verify both v1 and v2 pass `verify.py` with multiple audio inputs and variable chunk counts. Include the output or a summary.

5. **Verify the twiddle rotation path timing.** If the critical path is the twiddle rotation (2 multiplies + 1 subtract + shift), pipelining that path as well could unlock even higher clock frequencies.

### Medium Priority (For Report Quality)

6. **Document the pipeline architecture** with a timing diagram showing the cycle-by-cycle overlap of stage 1 and stage 2, including the drain cycle.

7. **Estimate area overhead** of the register-file approach. The 32 x 2 x 32-bit data register file = 2048 flip-flops, plus 5 x 2 x 32-bit twiddle register file = 320 flip-flops, plus ~587 pipeline flip-flops in v2 = **~2955 total additional flip-flops**. Compare this against the baseline area.

8. **Provide a cycle count comparison table:**

   | Phase | Baseline | v1 | v2 |
   |-------|----------|----|----|
   | INIT | 1 | 1 | 1 |
   | LOAD_TW | 0 (inline) | 10 | 10 |
   | LOAD_DATA | 0 (inline) | 64 | 64 |
   | COMPUTE | 80 x 9 = 720 | 80 | 81 |
   | STORE | 0 (inline) | 64 | 64 |
   | FINISH | 1 | 1 | 1 |
   | **Total** | **732** | **220** | **221** |
   | Clock period | 83.33 ns | ~83.33 ns | 12.5 ns |
   | **Latency** | **61.0 us** | **~18.3 us** | **~2.76 us** |

9. **Consider combining v1 and v2 into a single parameterizable module** with a `PIPELINE` parameter, reducing code duplication and maintenance burden.

### Low Priority (Polish)

10. **Reconcile coding style** between v1 and v2 (concatenation vs shift for x2, explicit vs implicit zero-extension, SystemVerilog `'0` syntax in v2 vs explicit width in v1).

11. **Add `default` assignments to all case branches** in the sequential always block for defensive coding.

12. **Consider adding an assertion or parameter check** that `number_data <= MAX_FFT_N` to guard against out-of-bounds register-file access.

---

## 8. Overall Assessment

Alessandro's work represents a **solid and well-reasoned HP optimization**. The register-file architecture is the right first move for eliminating the SRAM bottleneck, and the pipelined v2 is a correct and meaningful follow-up that enables significantly higher clock frequencies. The code is clean, well-commented, and functionally correct.

The main gaps are in **verification evidence and synthesis data** -- the RTL looks correct on inspection, but the branch contains no simulation outputs, synthesis reports, or timing evidence to back up the claimed performance numbers. The `idx_v` regression from v1 to v2 and the inconsistent reset strategy suggest the two versions evolved in parallel rather than incrementally, which should be cleaned up before merging.

**Bottom line:** The architectural contribution (3.33x cycle reduction, potentially 22x latency reduction with pipelining) is substantial and places this firmly in the "excellent" category for HP design. The work needs synthesis/simulation verification and minor code cleanup before it is ready for final integration.
