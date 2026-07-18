# FranzJosef: "Radix" Branch Analysis

**Date**: 2026-03-19
**Branch analysed**: `remotes/origin/FranzJosef-Radix`
**Related branch**: `remotes/origin/FranzJosef-HP-D1-reg_bfly`

---

## Critical Finding: FranzJosef-Radix is Empty

The `FranzJosef-Radix` branch points to commit `f76a861`, which is **the exact same
commit as `master`**. There are zero unique commits, zero design files, and zero diff
from master. The branch name is misleading -- there is no Radix-4 work on this branch.

```
FranzJosef-Radix HEAD:  f76a861  (= master HEAD)
Unique commits vs master: 0
Diff vs master: empty
```

## Where the Radix-4 Work Actually Lives

The actual Radix-4 implementation exists as a single commit (`d89e4d7`) on top of the
**FranzJosef-HP-D1-reg_bfly** branch -- NOT on FranzJosef-Radix.

```
FranzJosef-HP-D1-reg_bfly:
  d89e4d7  "4-2 Radix FSM + Digit-reversal"  (2026-03-19 11:24, Franz-JosefZ)
  7752422  "Set up reg only branch as base version"  (2026-03-12, ShanghongLin)
  864ea23  "chore: purge EDA databases"  (2026-03-10, ShanghongLin)
  ... (all earlier commits are ShanghongLin's)
```

The parent of the Radix commit (`7752422`) is the exact HEAD of
`ShanghongLin-HP-D1-reg_bfly`. FranzJosef's one commit sits on top of ShanghongLin's
complete D1 register-file implementation.

## The Radix-4 Implementation (commit d89e4d7)

### Scope of Changes

| File | Lines added | Lines removed |
|------|------------|--------------|
| `src/design/accelerator_fft.v` | 429 | 100 |
| `firmware/fft.c` | 34 | 0 |
| `firmware/fft.h` | 2 | 0 |
| `firmware/accel_audio.c` | 2 | 2 |
| **Total** | **469** | **144** |

The Verilog file grew from 398 lines (ShanghongLin's D1) to 687 lines.

### Architecture

The design implements a **mixed radix-4/radix-2** FFT for N=32:
- Since 32 = 4 x 4 x 2 (not a pure power of 4), it uses 2 radix-4 stages + 1 radix-2 stage
- Stage 1 (radix-4): m=4, 8 groups x 1 butterfly = 8 butterflies
- Stage 2 (radix-4): m=16, 2 groups x 4 butterflies = 8 butterflies
- Stage 3 (radix-2): m=32, 1 group x 16 butterflies = 16 butterflies
- 2 precompute cycles per radix-4 stage for tw^2 and tw^3

**Claimed cycle count**: INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(36) + STORE(64) + FINISH(1) = 176
- vs D1 baseline: 220 cycles (compute was 80, now 36 -- a 55% reduction in compute cycles)
- Overall: 176/220 = 20% total cycle reduction

### Key Technical Details

1. **Radix-4 butterfly**: Purely combinational, computes 4 outputs per cycle using 3 complex
   multiplies (t1 = w1*x1, t2 = w2*x2, t3 = w3*x3) followed by the 4-point DFT kernel
   with j-rotations implemented as re/im swaps with sign changes (zero cost in hardware).

2. **Twiddle precomputation**: Each radix-4 stage spends 2 cycles precomputing tw^2 and tw^3
   from the primitive twiddle factor, avoiding cascaded multiplies during butterfly execution.

3. **Stage tracking**: Replaces the linear stage counter with `log2_m` which tracks "bits
   consumed" -- advances by 2 for radix-4 stages, by 1 for radix-2.

4. **Firmware change**: Replaces `bit_reverse()` with `digit_reverse_mixed()` in the data
   loading path. The new function extracts base-4 digits greedily (2 bits each) then
   reverses digit order, with a trailing base-2 digit if log2(N) is odd.

5. **Interface compatibility**: Same 6-state FSM, same SRAM layout, same port interface.
   Claims to be a drop-in replacement.

### Code Quality Observations

- The comment style matches ShanghongLin's existing formatting exactly (same `===` banner
  blocks, same parameter sections), but with substantially more detailed annotations.
- Every section has extensive docstrings explaining the algorithm (e.g., the radix-4
  butterfly equations, twiddle advancement strategy, stage decomposition).
- The level of documentation detail is unusually high for a single commit -- 289 net new
  lines, many of which are comments. The code reads like a tutorial.

## Verification & Results

**None.** There is:
- No simulation testbench or log showing correctness
- No synthesis run (the PnR files in the tree are ShanghongLin's old results, unchanged)
- No timing or power reports for the new design
- No evidence the design was compiled, simulated, or verified in any way

The PnR reports in the commit tree (`pnr/finalReports/`) are byte-identical to ShanghongLin's
base version -- they were inherited, not regenerated.

## Assessment: Original Work or Copied?

### Evidence suggesting AI-generated code:
- The commit is a single massive 469-line change (not iterative development)
- Extremely verbose, tutorial-quality comments far exceeding what the codebase normally has
- Perfect algorithmic description in the header (stage decomposition, cycle counts) written
  before any verification
- The coding style (banners, naming, documentation density) is consistent with LLM output
- No intermediate commits (no debugging, no test runs, no synthesis attempts)

### Evidence of original contribution:
- The commit is authored by FranzJosef (`franz.zuaiter@gmail.com`), not copied from another
  teammate's branch
- No other branch in the repo has a radix-4 implementation
- The algorithmic approach (mixed radix-4/2 with digit-reversal) is technically sound and
  corresponds to the D7 exploration item from the midterm discussion

### Concerning patterns:
- The "FranzJosef-Radix" branch is just master with a new name -- it contains nothing
- The actual Radix work is hidden on FranzJosef-HP-D1-reg_bfly (which was previously
  reviewed as being 100% identical to ShanghongLin's D1)
- FranzJosef's only original commit across both branches is this single Radix commit
- The base code (398 lines) is entirely ShanghongLin's work

## Impact on HP/EE Designs

### Potential Benefit (if verified):
- 20% fewer total cycles (176 vs 220) could improve HP throughput significantly
- Compute phase goes from 80 to 36 cycles -- the radix-4 butterfly processes 4 points
  per cycle instead of 2
- Could push HP frequency target or relax timing constraints

### Potential Risks:
- The radix-4 butterfly has a much wider combinational path (3 complex multiplies +
  4-point DFT with additions) vs 1 complex multiply + add/sub for radix-2
- This will almost certainly increase the critical path delay, potentially requiring
  lower clock frequency or pipelining
- 3 parallel multipliers vs 1 means significantly more area and likely more power
- No synthesis data exists to evaluate these tradeoffs
- The `digit_reverse_mixed` firmware function adds software overhead

### Bottom Line:
The design cannot be used until it passes: (1) behavioural simulation, (2) synthesis,
(3) place-and-route, and (4) post-layout simulation. None of these have been attempted.

## Summary

| Aspect | Status |
|--------|--------|
| FranzJosef-Radix branch | Empty (= master) |
| Radix-4 code location | FranzJosef-HP-D1-reg_bfly, commit d89e4d7 |
| Base code | 100% ShanghongLin's D1 (7752422) |
| Original contribution | 1 commit: mixed radix-4/2 FSM + digit-reversal firmware |
| Simulation verified | No |
| Synthesis run | No |
| PnR completed | No |
| Post-layout verified | No |
| Likely AI-generated | High probability (style, single-shot, no iteration) |
| Usable for final design | Not yet -- requires full verification flow |
