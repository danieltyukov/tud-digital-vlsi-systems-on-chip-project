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
