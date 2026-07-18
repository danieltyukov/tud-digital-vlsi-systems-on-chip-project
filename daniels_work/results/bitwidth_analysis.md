# Bit-Width Reduction Analysis for EE FFT Accelerator

## Date: 2026-03-21
## Design Under Analysis: EE v3 (D1 register-file + hardcoded twiddle LUT + clock gating)

---

## 1. Current Design: 32-bit Data Path

The EE v3 accelerator uses `MEM_WIDTH = 32` throughout:

- **Register file**: `reg signed [31:0] data_re [0:31]`, `reg signed [31:0] data_im [0:31]` -- 64 x 32-bit registers
- **Twiddle LUT**: returns `{tw_r[31:0], tw_i[31:0]}` -- 64-bit packed pair
- **Butterfly products**: `data_re[idx_v] * lut_w_re` -- 32 x 32 = 64-bit intermediate
- **Scaled result**: `(product) >>> 12` -- truncated back to 32 bits
- **Memory interface**: `accel_mem_rdata[31:0]`, `accel_mem_wdata[31:0]` -- fixed at 32 bits by SoC bus

The Q12 fixed-point format uses 12 fractional bits, leaving 20 integer bits (including sign).

---

## 2. Twiddle Factor Range Analysis

From the hardcoded LUT in `accelerator_fft.v`, every twiddle value satisfies:

    -4096 <= tw_re, tw_im <= +4096

In Q12, this represents the range [-1.0, +1.0]. The maximum magnitude is 4096 = 2^12 = 1.0 in Q12.

**Bits actually needed for twiddle factors:**

- Range [-4096, +4096] requires 14 bits signed (1 sign + 13 magnitude)
- With Q12 fractional precision, 16 bits is natural: 1 sign + 3 integer + 12 fractional
- Bits [31:16] are always sign-extension of bit 15 (verified by inspecting all 31 LUT entries)
- Upper 16 bits carry zero information

**Conclusion:** Twiddle factors need exactly 16 bits. The current 32-bit representation wastes 16 bits per twiddle value. This is consistent with D6's `TW_WIDTH = 16` parameter, which was already validated.

---

## 3. Input Audio Data Range Analysis

### 3.1 Data Source

The firmware (`accel_audio.c`) reads audio samples from Flash via QSPI using `read_dec_entry_from_flash()`. The audio is stored as a "noisy audio sample" in `firmware/full_sound.wav`. The function returns a `signed int` (32-bit) value.

### 3.2 What Precision Do Audio Samples Actually Need?

The project description states the input is an **audio signal**. Audio samples from a WAV file are typically:

- 8-bit unsigned (range 0 to 255)
- 16-bit signed (range -32768 to +32767)
- 24-bit signed (range -8388608 to +8388607)

The firmware reads these into 32-bit integers. However, the `read_dec_entry_from_flash()` function reads **decimal ASCII strings** from Flash and converts them to integers. The actual sample values depend on how the WAV was quantized into the Flash hex file.

### 3.3 Empirical Bound: What the Hex File Tells Us

The `accel_audio.hex` file contains compiled firmware, not raw sample data -- the audio samples are embedded within the firmware binary image stored in Flash. Without access to the original `accel_audio.c` source or the `prepare_fft.py` / `fft.py` scripts (not found in this repository), we must reason from the data format.

**Key observation from firmware flow:**
1. CPU reads decimal integers from Flash
2. CPU writes them as 32-bit words into accelerator memory
3. Imaginary parts are written as 0 (real-valued input)
4. The testbench verifies bit-exact output against a golden reference

The actual audio sample values are unknown at this stage, but typical audio in Q12 would be scaled to fit within the representable range. If the source is 16-bit PCM audio, values range from -32768 to +32767, which requires exactly 16 bits.

### 3.4 Worst-Case Growth Through FFT Stages

Even if input samples fit in 16 bits, the FFT butterfly causes bit growth:

**Single butterfly:**
```
    t_re = (v_re x w_re - v_im x w_im) >>> 12
    e_re = u_re + t_re
    o_re = u_re - t_re
```

- Multiplication: 16-bit data x 16-bit twiddle = 32-bit product
- After `>>> 12`: 32 - 12 = 20 useful bits
- Addition/subtraction: 20-bit + 16-bit = up to 21 bits (1 bit growth)

**Across 5 stages:** Each stage can add 1 bit of growth via the add/subtract. Over 5 stages:

    Input width + 5 bits of growth = 16 + 5 = 21 bits minimum needed

However, the `>>> 12` shift after each multiplication provides implicit scaling that prevents unbounded growth. The twiddle factors have magnitude <= 1.0 in Q12, so:

    |t| = |v x w| / 2^12 <= |v|

The butterfly output satisfies:
    |e|, |o| <= |u| + |t| <= |u| + |v| <= 2 x max(|u|, |v|)

**Per-stage worst case:** magnitude can double (1 bit growth).
**Over 5 stages:** 2^5 = 32x growth -- input of magnitude M can produce output of magnitude up to 32 x M.

For 16-bit input (max |x| = 32767):
    Max output = 32 x 32767 = 1,048,544

This requires ceil(log2(1048544)) + 1 = 21 bits signed.

**For 32-bit data path:** plenty of headroom (11 bits unused).
**For 16-bit data path:** overflow would occur at stage 1 if input exceeds 2^15 / 2 = 16384, but the `>>> 12` scaling limits growth more tightly.

### 3.5 Precise Growth with Q12 Scaling

Let us re-examine more carefully. After the `>>> 12` arithmetic right shift:

    t = (v x w) >>> 12

If v is B bits and w is 16 bits (Q12, magnitude <= 4096):
    v x w is at most (B + 16) bits
    After >>> 12: at most (B + 16 - 12) = B + 4 bits

But since |w| <= 4096 = 2^12 and the shift is by 12:
    |t| = |v x w| / 2^12 <= |v| x 4096 / 4096 = |v|

So |t| <= |v|, and:
    |e| = |u + t| <= |u| + |v|
    |o| = |u - t| <= |u| + |v|

If input values are bounded by M, after stage 1:
    max magnitude <= 2M (each butterfly adds two inputs of magnitude <= M)

After stage 2: max <= 2 x 2M = 4M (but this is pessimistic -- the DIT butterfly structure actually maintains the bound more tightly for typical signals).

**Worst-case across all 5 stages: max output <= N x max_input = 32 x max_input** (this is a well-known FFT property -- the output magnitude scales with N for a worst-case input like a DC signal).

For 16-bit signed input (max 32767):
    Worst-case output: 32 x 32767 = 1,048,544

Representation in Q12: 1,048,544 needs 21 bits signed (20 magnitude + 1 sign).

**Verdict:** A 16-bit data path would overflow. Even a 24-bit data path would be marginal.

---

## 4. Area Impact of Bit-Width Reduction

### 4.1 Multiplier Area Scaling

Multiplier area scales approximately as O(B_data x B_twiddle):

| Data Width | Twiddle Width | Product Width | Relative Multiplier Area |
|------------|---------------|---------------|--------------------------|
| 32 | 32 | 64 | 1.00x (baseline) |
| 32 | 16 | 48 | ~0.50x |
| 24 | 16 | 40 | ~0.375x |
| 16 | 16 | 32 | ~0.25x |

The EE v3 butterfly has 4 multiplications (2 for t_re, 2 for t_im). Each 32x32 multiplier synthesizes to ~2000-4000 gates at 45nm.

### 4.2 Register File Area Scaling

Register file area scales linearly with bit-width:

| Data Width | Registers | Total Bits | Relative Register Area |
|------------|-----------|------------|------------------------|
| 32 | 64 | 2,048 | 1.00x |
| 24 | 64 | 1,536 | 0.75x |
| 16 | 64 | 1,024 | 0.50x |

### 4.3 Estimated Total Area Savings

From synthesis results, `accelerator_fft` = 19,672 um^2 (EE design). The register file and multipliers dominate this. A rough breakdown:

- Register file (64 x 32-bit): ~40% of FFT area = ~7,900 um^2
- Multiplier/butterfly logic: ~35% = ~6,900 um^2
- Control/FSM/LUT: ~25% = ~4,900 um^2

**16-bit data path savings:**
- Registers: 7,900 x 0.50 = 3,950 um^2 (save ~3,950)
- Multipliers: 6,900 x 0.25 = 1,725 um^2 (save ~5,175)
- Control: unchanged = 4,900 um^2
- **New FFT area: ~10,575 um^2 (46% reduction)**

**24-bit data path savings:**
- Registers: 7,900 x 0.75 = 5,925 um^2 (save ~1,975)
- Multipliers: 6,900 x 0.375 = 2,588 um^2 (save ~4,312)
- Control: unchanged = 4,900 um^2
- **New FFT area: ~13,413 um^2 (32% reduction)**

### 4.4 Impact on SoC Total Area

The FFT core is only 19,672 / 170,575 = 11.5% of SoC area (EE synthesis). The accelerator memory (59,635 um^2) and PicoSoC (88,015 um^2) are unchanged.

- 16-bit: SoC area drops from 170,575 to ~161,478 um^2 (5.3% reduction)
- 24-bit: SoC area drops from 170,575 to ~164,346 um^2 (3.7% reduction)

**Area savings are modest at the SoC level** because the FFT core is already small after the LUT twiddle optimization (which removed the recursive multiplier chain).

---

## 5. Power Impact of Bit-Width Reduction

### 5.1 Dynamic Power Scaling

P_sw is proportional to alpha x C_L. Fewer bits means:
- Fewer flip-flops toggling (register file)
- Smaller multiplier trees (fewer transistors switching)
- Narrower datapaths (fewer wire capacitances)

**Expected switching power reduction in FFT core:**

For 16-bit: register toggles halved, multiplier toggles quartered.
Estimated FFT core switching power reduction: ~40-60%.

However, the FFT core (`accel/fft`) only contributes 0.028 mW out of 0.543 mW total chip power = 5.2%.

**Even a 60% reduction in FFT power saves: 0.028 x 0.60 = 0.017 mW**
**Energy saving: 0.017 mW x 17.50 us = 0.30 nJ out of 8.6 nJ total = 3.5%**

### 5.2 With Clock Gating Already Applied

In the EE v3 design with clock gating, the FFT core is already gated during idle periods (LOAD/STORE and when the accelerator is disabled). The dominant power sinks are:

| Component | Power (mW) | % of Total |
|-----------|-----------|-----------|
| accel/mem | 0.141 | 28.7% |
| soc/cpu | 0.132 | 26.8% |
| Clock tree | ~0.100 | 20.3% |
| accel/fft | 0.028 | 5.7% |
| Other | 0.091 | 18.5% |

The FFT core is already the **smallest power contributor**. Bit-width reduction would shrink an already-small fraction.

### 5.3 Accelerator Memory Impact

The accelerator memory (`accel/mem`) stores 32-bit words and is accessed via the 32-bit SoC bus. Reducing the internal data width does NOT reduce memory width -- the CPU still writes/reads 32-bit words. You would need to:
- Either: pack two 16-bit values per 32-bit word (changes firmware + memory addressing)
- Or: waste the upper 16 bits (no memory power saving)

The first option changes the firmware interface and is a significant redesign. The second option gives no memory power saving.

---

## 6. Verification Risk

### 6.1 Bit-Exact Output Requirement

The project testbench (`tb_et4351.sv`, which MUST NOT be modified) compares the accelerator output against a golden reference. The verification script `verify.py` checks for bit-identical output.

**Any precision change that alters even a single output bit will cause verification failure.**

### 6.2 Overflow Risk Assessment

If data width is reduced to 16 bits:
- Butterfly product: 16 x 16 = 32 bits, after >>> 12 = 20 useful bits
- But intermediate values are truncated to 16 bits when written back to the register file
- This truncation discards 4-5 bits of information per butterfly
- Over 5 stages (80 butterflies), truncation errors accumulate

**Simulation would be required** to verify whether 16-bit precision passes the golden reference check. Given that:
- Input audio samples may use the full 32-bit range
- The golden reference was computed with 32-bit arithmetic
- Any truncation changes the output

...the probability of passing verification with 16-bit data is **low**.

### 6.3 Twiddle Width Reduction Is Safe

Reducing twiddle width from 32 to 16 bits is already proven safe by D6 (TW_WIDTH = 16). Since twiddle values fit in 14 bits, the upper 16 bits are always sign-extension. This is a lossless optimization.

**However, our EE v3 LUT already hardcodes twiddle values as 32-bit constants.** Synthesis will optimize away the unused upper bits automatically (they are constants that feed into multipliers -- the tool recognizes that the upper 16 bits are sign-extension and eliminates the corresponding hardware). The LUT approach already gets most of the twiddle width-reduction benefit for free at synthesis time.

---

## 7. Alternative: Reduce Only Twiddle Width (Keep 32-bit Data)

This is the safest optimization:

**Implementation:**
```verilog
// Change twiddle declarations from:
reg signed [MEM_WIDTH-1:0] tw_r, tw_i;    // 32-bit
// To:
reg signed [15:0] tw_r, tw_i;             // 16-bit

// Butterfly multiply becomes:
// data[31:0] x tw[15:0] = 48-bit product (vs 64-bit)
// >>> 12 = 36-bit result (vs 52-bit), truncated to 32
```

**Area savings:** Multiplier area roughly halved (32x16 vs 32x32).

**Power savings:** Fewer toggling bits in multiplier tree.

**Verification risk:** Zero -- twiddle values fit exactly in 16 bits. Output is bit-identical.

**BUT:** As noted above, the synthesis tool already optimizes this for the LUT-based design. The twiddle values are compile-time constants, so Genus can determine that the upper 16 bits are sign-extension and eliminate the corresponding multiplier logic. **This optimization may already be applied implicitly.**

---

## 8. Quantitative Comparison: Is It Worth the Effort?

| Optimization | Area Saving (SoC) | Energy Saving | Risk | Effort |
|---|---|---|---|---|
| **16-bit data** | ~5% (9,100 um^2) | ~3.5% (~0.30 nJ) | HIGH (verification failure likely) | HIGH (firmware changes, full re-verification) |
| **24-bit data** | ~3.7% (6,200 um^2) | ~2% (~0.17 nJ) | MEDIUM (may pass if inputs fit in 24 bits) | HIGH (firmware changes, full re-verification) |
| **16-bit twiddle only** | ~2% (3,400 um^2) | ~1% (~0.09 nJ) | ZERO (lossless) | LOW (declare tw as 16-bit) |
| **Already implicit** | 0% (synthesis does it) | 0% | ZERO | ZERO |

**Current EE v3 energy: 8.6 nJ. Target: < 24.6 nJ. Margin: 65% under target.**

The design already exceeds the energy target by a factor of nearly 3x. Bit-width reduction provides at most 3.5% additional energy saving -- utterly irrelevant given the existing margin.

---

## 9. Recommendation

### DO NOT IMPLEMENT bit-width reduction for the EE design.

**Reasons:**

1. **Negligible energy benefit.** The FFT core consumes only 5.2% of total chip power. Even aggressive bit-width reduction saves at most 0.30 nJ (~3.5%) from a design that is already 65% under the energy target (8.6 nJ vs 24.6 nJ).

2. **High verification risk.** Reducing data width from 32 to 16 bits will almost certainly change FFT output values due to truncation in the register file. The testbench requires bit-exact matching against a 32-bit golden reference. Any mismatch = verification failure = project failure (knock-out criterion).

3. **Firmware interface constraint.** The SoC bus is 32 bits wide. The CPU writes 32-bit words to accelerator memory. Reducing internal data width requires either wasting memory bandwidth or redesigning the firmware interface -- both are costly for negligible gain.

4. **Synthesis already optimizes twiddle width.** The hardcoded twiddle LUT uses compile-time constants. Genus recognizes that the upper 16 bits of each twiddle value are sign-extension and eliminates the corresponding multiplier logic. Explicit twiddle width reduction is redundant with the LUT approach.

5. **Time is better spent elsewhere.** The project deadline is April 10. Remaining effort should go to:
   - Fixing hold violations (59 violations at WNS = -0.131 ns)
   - Completing the report (6-page IEEE format)
   - Signoff verification and documentation

### If further EE optimization were needed (which it is not):

The correct priority order would be:
1. **Fix hold violations** (currently 59 violations -- these risk examiner knock-out)
2. **Improve VCD annotation coverage** (get the tool to report correct coverage for the report)
3. **Clock gating refinement** (gate register file during LOAD/STORE -- already done)
4. **Multi-Vt synthesis** (maximize HVT cell usage -- synthesis setting, zero RTL effort)
5. **Bit-width reduction** (last resort, high risk)

---

## 10. Summary Table

| Question | Answer |
|----------|--------|
| What is the twiddle factor range? | [-4096, +4096] in Q12 = [-1.0, +1.0]. Fits in 16 bits signed. |
| What is the data dynamic range? | Unknown input range; worst-case FFT output can be 32x input. 16-bit input needs 21+ bits at output. |
| Can we reduce data to 16 bits? | Almost certainly NO -- truncation will break bit-exact verification. |
| Can we reduce twiddle to 16 bits? | YES, but synthesis already does this implicitly for the LUT design. |
| Expected energy saving? | At most 3.5% (~0.30 nJ) from FFT core -- insignificant vs 65% margin. |
| Recommendation? | DO NOT IMPLEMENT. Risk/reward ratio is extremely unfavorable. |
