# EE v5 (Radix-4 + Clock Gating) — Analysis

## Attempt
Tried to combine Franz's SRAM-based Radix-4/2 design with our clock gating approach.

## Result: Clock gating is incompatible with SRAM-based FFT architecture

### Why it fails
Franz's radix-4 design accesses SRAM for EVERY butterfly operation:
- Radix-4 butterfly: 8 reads + 1 compute + 8 writes = 17 cycles per butterfly
- The FFT core drives memory addresses and data on every clock cycle during computation
- Gating the FFT clock causes stale addresses → wrong data → garbage output
- Gating the memory clock prevents writes → data loss

### Why clock gating works on D1 (register-file) but not on SRAM-based
- **D1**: LOAD phase (64 cycles) → COMPUTE phase (80 cycles, internal registers only) → STORE phase (64 cycles)
  - Memory can be gated during COMPUTE because no SRAM access occurs
  - FFT can be gated when not active (CPU loading/reading data)
- **SRAM-based**: Every butterfly reads/writes SRAM → memory must be clocked continuously
  - No separation between compute and memory phases
  - Clock gating can only gate during idle between chunks, not during computation

### Attempted fixes
1. Two separate gated clocks (fft_clk, mem_clk) — both need to be active during computation
2. Single shared gated clock (accel_clk) — same result
3. Behavioral latch-based clock gate instead of TLATNCAX2 — same result

### Energy comparison

| Design | Architecture | Cycles | Power | Energy |
|--------|-------------|--------|-------|--------|
| Baseline | SRAM radix-2 | 732 | 0.403 mW | 24.6 nJ |
| Franz radix-4 | SRAM radix-4/2 | 428 | 0.396 mW | 14.1 nJ |
| **Our EE v3** | **Register-file + LUT + CG** | **210** | **0.492 mW** | **8.6 nJ** |

### Conclusion
To combine radix-4 with clock gating, the radix-4 algorithm would need to be ported to the D1 register-file architecture (bulk LOAD → radix-4 compute from registers → bulk STORE). This is a substantial RTL redesign requiring:
- Radix-4 butterfly operating on register file instead of SRAM
- New twiddle LUT for radix-4 factors
- Digit-reversal in firmware
- Full re-verification

Estimated effort: 3-5 days. Not worth pursuing since EE v3 already beats the target by 65%.

**EE v3 remains our best EE submission.**
