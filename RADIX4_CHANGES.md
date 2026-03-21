# Mixed Radix-4/2 FFT Accelerator

## What was changed

The FFT accelerator's compute engine was redesigned from pure radix-2 to mixed radix-4/2, reducing the number of butterfly operations and total compute cycles.

### Files changed

| File | Change |
|---|---|
| `project/src/design/accelerator_fft.v` | Rewrote FSM for mixed radix-4/2 butterfly (SRAM-based, no register file) |
| `project/firmware/fft.c` | Added `digit_reverse_mixed()` function for mixed-radix input permutation |
| `project/firmware/fft.h` | Declared `digit_reverse_mixed()` |
| `project/firmware/accel_audio.c` | Changed input permutation from `bit_reverse()` to `digit_reverse_mixed()` |
| `project/firmware/fft.py` | Updated golden reference to use radix-4/2 FFT with digit reversal |

### Why radix-4/2?

N=32 is not a power of 4, so pure radix-4 is impossible. The mixed approach greedily takes radix-4 stages (consuming 2 bits of log2(N) each), then finishes with a radix-2 stage if an odd bit remains.

**Stage decomposition for N=32 (5 bits):**
- Stage 1: radix-4, m=4, 8 groups x 1 butterfly = 8 butterflies
- Stage 2: radix-4, m=16, 2 groups x 4 butterflies = 8 butterflies
- Stage 3: radix-2, m=32, 1 group x 16 butterflies = 16 butterflies

### Why digit reversal instead of bit reversal?

Radix-2 DIT uses bit-reversal to permute inputs. Mixed radix-4/2 requires digit-reversal: the index is decomposed into base-4 digits (2 bits) with a possible base-2 digit (1 bit), and the digit order is reversed. For N=32, some indices differ between the two (e.g. index 5 maps to 10 with digit reversal vs 20 with bit reversal).

### Cycle count comparison (SRAM-based)

| | Baseline (radix-2) | Radix-4/2 |
|---|---|---|
| Cycles per radix-2 butterfly | 9 (4 read + 1 compute + 4 write) | 9 |
| Cycles per radix-4 butterfly | N/A | 17 (8 read + 1 compute + 8 write) |
| Twiddle read per stage | 2 | 2 |
| Twiddle precompute per radix-4 stage | N/A | 2 (tw^2, tw^3) |
| Total compute cycles (N=32) | 5 x (2 + 16x9) = 730 | 2 x (2+2+8x17) + (2+16x9) = 426 |
| **Reduction** | | **~42%** |

### Hardware interface

No changes to the accelerator wrapper, SRAM layout, CSR interface, or twiddle factor format. The design is a drop-in replacement for the baseline `accelerator_fft.v`.

## Results

### Behavioural simulation (confirmed 2026-03-21)

Test: 24 chunks of 32 samples each (Nokia ringtone).

| Metric | Baseline (radix-2) | Radix-4/2 | Change |
|---|---|---|---|
| Accelerator cycles (total, 24 chunks) | 17,568 | 10,272 | **-41.5%** |
| Accelerator cycles (per chunk) | 732 | 428 | **-41.5%** |
| Accelerator latency (total) | 1.464 ms | 0.856 ms | **-41.5%** |
| First chunk latency | 60.998 µs | 35.665 µs | **-41.5%** |
| Total system cycles | 32,042,131 | 36,036,795 | +12.5% |

Note: total system cycles increased because `digit_reverse_mixed()` is more computationally expensive in firmware than `bit_reverse()`. However, the accelerator dominates power consumption, so what matters for energy is accelerator power x accelerator latency.

### Baseline power (post-layout)

| Metric | Value |
|---|---|
| Core area | 596.4 µm x 596.4 µm |
| Clock frequency | 12 MHz (83.33 ns period) |
| Total power | 0.626 mW |
| accel (total) | 0.403 mW |
| accel/fft | 0.050 mW |
| accel/mem | 0.320 mW |
| soc | 0.201 mW |
| Energy (per chunk) | 0.403 mW x 61.00 µs = **2.46 nJ** |

### Radix-4/2 power (post-layout)

Pending — synthesis, structural sim with VCD, PnR, and power report still in progress.

Energy breakeven: radix-4/2 accel power must stay below **0.69 mW** to beat the baseline energy of 2.46 nJ (since 0.69 x 35.665 µs = 2.46 nJ).
