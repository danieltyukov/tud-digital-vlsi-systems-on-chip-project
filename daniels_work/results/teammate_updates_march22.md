# Teammate Updates — March 22, 2026

## Ali (NEW branch: `origin/Ali`)

**What he did:** Built on our EE v2 design (D1 + LUT twiddle), optimized the LOAD_DATA phase.

**Key change:** Since audio input is real-valued (im=0), the firmware writes imaginary parts as zero to SRAM. Ali modified LOAD_DATA to use stride-2 SRAM addressing — reads only real words, skips zeros. `data_im[]` stays zero from reset.

**Result:**
- LOAD_DATA: 64 → 32 cycles
- Total: 210 → **178 cycles** (14.83 $\mu s$)
- Behavioral sim: PASS (verified identical output)
- No firmware changes needed

**Impact:** This could be applied to our EE v3 (with clock gating) to get 178 cycles + CG. Energy would drop further: 0.492 mW × 14.83 $\mu s$ ≈ 7.3 nJ.

**Note:** Ali used Claude Sonnet 4.6 (per his commit co-author line).

---

## Shanghong D5 Update (commit `6f22444`)

**What changed:** "Narrow datapath to 24-bit, pack twiddle CSRs, clean up .gitignore"

**Key changes:**
- `MEM_WIDTH` reduced from 32 to **24** bits
- Data register file: 64 × 32-bit → 64 × 24-bit (saves 512 flip-flops)
- Store phase adds sign-extension: 24-bit → 32-bit for bus interface
- Twiddle CSR packing (reduces CSR width)

**Impact on hold violations:**
- 512 fewer flip-flops could reduce density from 95% to ~90%
- More room for hold-fixing buffers
- This might be Shanghong's approach to fixing the D5 hold violations

**Status:** Not yet verified by us. Needs full flow re-run.

---

## FranzJosef (NEW branch: `FranzJosef-HP-D1-reg_bfly_Radix4`)

Same Radix-4 code as before but on a properly named branch (was previously only a commit on the D1 branch). The `FranzJosef-Radix` branch with full SRAM-based results (14.12 nJ) is unchanged.

---

## Romeu — No Updates

`romeu_comb_3_gc` unchanged since last review. Still the cleanest EE design (0 hold violations, 1.19 nJ accelerator energy).
