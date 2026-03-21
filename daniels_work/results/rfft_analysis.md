# RFFT (Real FFT) Analysis for 32-Point Audio FFT Accelerator

## Date: 2026-03-21
## Context: Evaluating whether an RFFT optimization is worth implementing as EE v4


---

## 1. How RFFT Works for N=32

### The Insight

Our audio input consists of 32 real-valued samples: x[0], x[1], ..., x[31]. The
firmware currently writes these as 32 complex values with zero imaginary parts:
(x[0], 0), (x[1], 0), ..., (x[31], 0). The accelerator then runs a full 32-point
complex FFT, performing all 5 stages of butterflies.

This is wasteful. A real-valued input of length N has a DFT with **conjugate symmetry**:

    X[k] = X*[N - k]     for k = 1, 2, ..., N-1

For N = 32, this means X[k] = X*[32 - k]. Only 17 unique complex outputs exist
(bins 0 through 16; bin 0 and bin 16 are purely real). We compute 32 complex
outputs but half of them are redundant conjugates.

The RFFT algorithm exploits this by converting the 32-point real FFT into a
**16-point complex FFT** plus a **recombination step**.

### The Three Phases

#### Phase 1: Packing (real samples into complex)

Form 16 complex values from 32 real samples:

    z[n] = x[2n] + j * x[2n + 1]     for n = 0, 1, ..., 15

So:
- z[0] = x[0] + j * x[1]
- z[1] = x[2] + j * x[3]
- ...
- z[15] = x[30] + j * x[31]

This interleaves even-indexed samples as real parts and odd-indexed samples as
imaginary parts.

#### Phase 2: 16-Point Complex FFT

Compute Z[k] = FFT₁₆{z[n]} for k = 0, 1, ..., 15.

This requires only **4 stages** instead of 5 (log₂(16) = 4), with **8 butterflies
per stage** (N/2 = 8), totaling **32 butterfly operations** instead of 80.

The twiddle factors needed are W₁₆ᵏ = e^(−j2πk/16) for k = 0..7, which are a
subset of the existing W₃₂ᵏ LUT (W₁₆ᵏ = W₃₂²ᵏ).

#### Phase 3: Recombination

Recover the 32-point real DFT X[k] from the 16-point complex DFT Z[k]:

    X[k] = ½(Z[k] + Z*[16 - k]) − (j/2) W₃₂ᵏ (Z[k] − Z*[16 - k])

where W₃₂ᵏ = e^(−j2πk/32) and k = 0, 1, ..., 16.

**Special cases:**
- k = 0:  X[0] = Re{Z[0]} + Im{Z[0]}  (purely real)
- k = 16: X[16] = Re{Z[0]} − Im{Z[0]}  (purely real)

**Conjugate symmetry** gives the remaining bins:
- X[32 − k] = X*[k]  for k = 1, 2, ..., 15

### Recombination Arithmetic per Bin (k = 1..15)

Let A = Z[k] and B = Z*[16 − k]. Define:

    P = ½(A + B)          (even part)
    Q = ½(A − B)          (odd part, to be multiplied by −jW₃₂ᵏ)

Then X[k] = P − j W₃₂ᵏ Q, which expands to:

    X[k].re = P.re + (W₃₂ᵏ.re × Q.im + W₃₂ᵏ.im × Q.re)
    X[k].im = P.im + (W₃₂ᵏ.re × Q.re − W₃₂ᵏ.im × Q.im)

Wait — let us be precise. We need −j × W₃₂ᵏ × Q:

    −j × W₃₂ᵏ = −j × (w_re + j w_im) = w_im − j w_re

So:

    (−j W₃₂ᵏ) × Q = (w_im − j w_re) × (Q.re + j Q.im)
                    = (w_im × Q.re + w_re × Q.im) + j(w_im × Q.im − w_re × Q.re)

Therefore:

    X[k].re = P.re + w_im × Q.re + w_re × Q.im
    X[k].im = P.im + w_im × Q.im − w_re × Q.re

This requires **2 multiplications and 2 multiply-accumulates** per bin — the same
datapath complexity as a butterfly. The existing multiplier can be reused.


---

## 2. Expected Cycle Count (Breakdown by Phase)

### EE v3 Baseline (Current Design)

| Phase       | Cycles | Notes                                   |
|-------------|--------|-----------------------------------------|
| INIT        | 1      | Initialize loop variables               |
| LOAD_DATA   | 64     | Read 32 (re, im) pairs from SRAM        |
| COMPUTE     | 80     | 5 stages x 16 butterflies/stage         |
| STORE_DATA  | 64     | Write 32 (re, im) pairs to SRAM         |
| FINISH      | 1      | Assert done flag                        |
| **Total**   | **210**|                                         |

### RFFT Design (Hypothetical EE v4)

| Phase       | Cycles | Notes                                             |
|-------------|--------|---------------------------------------------------|
| INIT        | 1      | Initialize loop variables                         |
| LOAD_DATA   | 64     | Read 32 (re, im=0) pairs, pack into 16 complex    |
| COMPUTE     | 32     | 4 stages x 8 butterflies/stage (16-pt FFT)        |
| RECOMBINE   | 17     | 2 special cases (k=0, k=16) + 15 general bins     |
| STORE_DATA  | 64     | Write 32 (re, im) pairs to SRAM                   |
| FINISH      | 1      | Assert done flag                                  |
| **Total**   | **179**|                                                   |

### Cycle Savings Analysis

Compute phase: 80 → 32 = **48 cycles saved** (60% reduction in compute)
Recombination added: **+17 cycles** (new phase)
Net saving: 48 − 17 = **31 cycles** (210 → 179)

**Percentage improvement: 14.8%** (31 / 210)

### Why the savings are modest

The LOAD_DATA (64 cycles) and STORE_DATA (64 cycles) phases dominate the total
cycle count at 128/210 = **61%** of total execution time. These are determined
by SRAM bandwidth (one word per cycle) and are unchanged by RFFT. The compute
phase (80 cycles) is only 38% of total. Even eliminating compute entirely would
only save 38%.


---

## 3. Area Impact

### Register File

The register file is the dominant area component in the FFT core. It holds 32
complex values = 64 x 32-bit registers = 2048 flip-flops.

#### Option A: Halved register file (16 complex) + expanded for output

If we use only 16 complex registers during COMPUTE but need 32 for STORE_DATA
output, we must expand back to 32 after recombination. This means the register
file stays at 32-wide — **no area savings**.

#### Option B: Streaming recombination (compute and write directly to SRAM)

During RECOMBINE, compute X[k] and immediately write both X[k] and X[32−k] to
SRAM. This avoids needing 32-wide output registers.

Register file would shrink to 16 complex = 32 x 32-bit = 1024 flip-flops.

**Area savings estimate:** The FFT core in EE v3 is 19,672 um². The register
file is roughly 60-70% of this (~12,000 um²). Halving it saves ~6,000 um².

But streaming recombination requires a more complex FSM and SRAM write logic
during the RECOMBINE state, which adds area back.

**Net area savings estimate: 3,000-5,000 um²** (15-25% of FFT core area)

In the context of the full SoC (170,575 um²), this is a **1.8-2.9% reduction** —
negligible.

### Twiddle LUT

The existing W₃₂ᵏ LUT (16 entries for stage 5) is retained for the recombination
step. The W₁₆ᵏ entries needed for the 16-point FFT are a subset (W₁₆ᵏ = W₃₂²ᵏ).
No new LUT entries needed — in fact, the m=32 case in the LUT is reused during
recombination.

The m=32 stage case (16 entries) is no longer needed during COMPUTE but is needed
during RECOMBINE. **No LUT area change.**

### Recombination Datapath

The recombination formula uses the same operations as a butterfly:
- 2 complex additions (P = ½(A+B), Q = ½(A-B))
- 1 complex multiplication (twiddle x Q)
- 1 complex addition (P + result)

The existing butterfly datapath (multiplier + adder) can be **reused** for
recombination with additional muxing. This adds modest area:
- Input muxes to select recombination operands vs butterfly operands
- Z*[16-k] conjugation logic (negate imaginary part)
- Division by 2 (right shift by 1, essentially free)
- −j rotation (swap and negate, essentially free)

**Estimated additional area: 500-1,000 um²** for muxes and control logic.

### FSM Complexity

Adding S_RECOMBINE state expands the FSM from 5 to 6 states. The recombination
loop needs a counter (k = 0..16) and special-case detection (k=0 and k=16).
This adds ~200-400 um² of control logic.

### Area Summary

| Component                  | EE v3   | RFFT (Option A) | RFFT (Option B) |
|----------------------------|---------|-----------------|-----------------|
| Register file              | ~12,000 | ~12,000         | ~6,000          |
| Twiddle LUT                | ~3,000  | ~3,000          | ~3,000          |
| Butterfly datapath         | ~3,500  | ~3,500          | ~3,500          |
| Recombination muxes + ctrl | 0       | ~1,200          | ~1,200          |
| Streaming SRAM write logic | 0       | 0               | ~800            |
| **FFT core total**         | ~19,672 | ~20,872         | ~15,672         |

**Option A (full register file)**: Area *increases* by ~6% due to extra logic,
no register savings.

**Option B (streaming)**: Area decreases by ~20% in the FFT core, but adds
significant design complexity.


---

## 4. Energy Impact Estimation

### Energy Model

    E = P_total x T_latency

Where:
- T_latency = N_cycles / f_clk
- P_total = P_accel + P_soc_rest

### EE v3 Reference Numbers

From our verified results:
- Total power: 0.492 mW
- Accelerator power: 0.271 mW (of which FFT core: ~0.028 mW)
- PicoSoC + rest: 0.221 mW
- Cycles: 210
- Clock: 12 MHz (83.33 ns period)
- Latency: 17.50 us
- Total chip energy: **8.6 nJ**

### RFFT Energy Estimate

#### Cycle count: 179 (vs 210)

    T_rfft = 179 / 12 MHz = 14.92 us

#### Power changes

The RFFT changes only the COMPUTE and RECOMBINE phases. During LOAD and STORE,
power is identical. Let us estimate phase-by-phase:

**COMPUTE phase power change:**
- 16-point FFT has fewer register file toggles (16 entries vs 32)
- Fewer butterfly operations means less switching in multiplier
- But the COMPUTE phase is only 32 cycles out of 179 — 17.9% of total time
- FFT core power (0.028 mW) is already only 5.2% of total chip power

Even halving FFT core switching power during compute:
    dP = −0.5 × 0.028 × (32/179) = −0.0025 mW

**RECOMBINE phase power:**
- 17 cycles of complex multiply + add operations
- Similar switching to butterfly operations
- Adds approximately: 0.028 × (17/80) = 0.006 mW (proportional to compute)

**Net power change: approximately zero** (within measurement noise)

    P_rfft ~ 0.492 mW (essentially unchanged)

#### Energy calculation

    E_rfft = 0.492 mW x 14.92 us = 7.3 nJ

**Energy savings: 8.6 → 7.3 nJ = 1.3 nJ (15.1% reduction)**

### Sensitivity Analysis

The energy savings come almost entirely from the 31-cycle latency reduction,
not from power reduction:

    E_rfft / E_v3 = T_rfft / T_v3 = 179 / 210 = 0.852

The 14.8% energy saving directly mirrors the 14.8% cycle reduction. Power is
essentially constant because the FFT core is a tiny fraction of total chip power.


---

## 5. Comparison: EE v3 vs Hypothetical RFFT

| Metric                   | EE v3       | RFFT (est.)   | Delta      |
|--------------------------|-------------|---------------|------------|
| **Cycles**               | 210         | 179           | −31 (−15%) |
| **Latency**              | 17.50 us    | 14.92 us      | −2.58 us   |
| **Total power**          | 0.492 mW    | ~0.492 mW     | ~0%        |
| **Total energy**         | 8.6 nJ      | ~7.3 nJ       | −15%       |
| **FFT core area**        | 19,672 um²  | ~15,700-20,900| ±20%       |
| **Design complexity**    | Moderate    | High          | Significant|
| **Verification risk**    | Proven      | Unverified    | High       |
| **Hold/DRV closure**     | 59 viol     | Unknown       | Risk       |
| **vs target (24.6 nJ)**  | 65% under   | 70% under     | Marginal   |


---

## 6. Risk Assessment

### Implementation Risks

1. **Correctness risk (HIGH)**: The recombination formula involves careful
   handling of conjugates, special cases (k=0, k=16), and interaction with
   the bit-reversal ordering that the firmware performs. A single sign error
   or off-by-one in the twiddle index breaks the entire FFT output. The
   existing testbench verifies only final outputs — intermediate correctness
   is hard to debug.

2. **Firmware compatibility risk (MEDIUM)**: The testbench is unmodifiable.
   The RFFT accelerator must accept the same SRAM layout as the baseline
   (32 complex values with im=0 written by firmware in bit-reversed order).
   The packing step must correctly reinterpret this layout. The bit-reversal
   ordering applied by firmware is for a 32-point FFT — using it with a
   16-point FFT requires careful index mapping.

3. **Timing closure risk (MEDIUM)**: EE v3 already has 59 hold violations
   and 804 max_tran DRVs. Adding recombination muxes may worsen critical
   paths, especially if the recombination datapath shares the butterfly
   multiplier with additional mux stages.

4. **Verification coverage (HIGH)**: Behavioural simulation passing does not
   guarantee the recombination logic is synthesizable without issues. The
   recombination uses the same multiplier in a different context (different
   operand selection, different write-back targets), which could expose
   timing hazards not present in the butterfly-only datapath.

### Schedule Risk

The project deadline is **April 10, 2026** (20 days away). Current status:
- EE v3 is fully implemented and verified through PnR
- Hold violations and DRVs still need ECO fixes
- Report writing has not started

Implementing RFFT would require:
- 2-3 days: RTL design and behavioral simulation
- 1-2 days: Synthesis and debug
- 1-2 days: PnR and timing closure
- 1 day: Physical simulation and power analysis
- **Total: 5-8 days** — consuming 25-40% of remaining time

This time would be better spent on:
- ECO iterations to close hold violations (improving signoff quality)
- Report writing (a knockout criterion — no report = no grade)
- Preparing presentation materials


---

## 7. Conclusion: Do Not Implement RFFT

### The case against RFFT

1. **Marginal gains**: 15% energy improvement (8.6 → 7.3 nJ) when we are
   already 65% under the 24.6 nJ target. The EE target is decisively met
   without RFFT.

2. **LOAD/STORE dominance**: The SRAM I/O phases consume 128 of 210 cycles
   (61%). RFFT only reduces the compute phase, which is already the minority
   contributor. The bottleneck is memory bandwidth, not computation.

3. **FFT core power is negligible**: At 0.028 mW (5.2% of total chip power),
   the FFT core's switching activity barely affects total energy. Reducing
   compute cycles saves latency but not power — the SoC's fixed overhead
   (CPU, PicoSoC, SRAM) dominates.

4. **Complexity vs payoff**: RFFT adds a new FSM state, recombination
   datapath muxing, special-case handling, and streaming SRAM write logic.
   This is a substantial increase in design complexity for a 15% improvement
   on a metric already well within target.

5. **Risk to existing results**: EE v3 is verified and meets all targets.
   RFFT could introduce bugs that are difficult to debug within the remaining
   schedule, and any PnR issues could leave us without a working EE design.

6. **Schedule pressure**: 20 days remain, report writing is the bottleneck,
   and hold/DRV closure on existing designs still needs work.

### When RFFT would make sense

RFFT becomes valuable when:
- N is large (e.g., 1024 or 4096) — compute dominates LOAD/STORE
- Memory bandwidth is not the bottleneck (e.g., wide SRAM port)
- The FFT core is a significant fraction of total power
- The energy target is tight and every percentage point matters
- There is sufficient verification time

For our N=32 design with single-word SRAM access, none of these conditions hold.

### Recommendation

**Keep EE v3 as-is.** Focus remaining effort on:
1. ECO iterations to close the 59 hold violations and reduce max_tran DRVs
2. Writing the 6-page IEEE report (knockout criterion)
3. Documenting the RFFT analysis as a "future work" section in the report —
   this demonstrates awareness of the optimization without the implementation
   risk.

### Summary Table

| Criterion                  | Assessment                              |
|----------------------------|-----------------------------------------|
| Energy savings             | ~15% (8.6 → 7.3 nJ)                    |
| Already meets target?      | Yes, by 65%                             |
| Implementation effort      | 5-8 days (25-40% of remaining time)     |
| Risk to existing design    | Medium-high                             |
| Impact on grade            | Minimal (target already met)            |
| **Verdict**                | **Do not implement. Document as future work.** |
