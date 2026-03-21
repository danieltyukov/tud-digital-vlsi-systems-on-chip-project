# Mixed Radix-4/2 FFT Accelerator

## What was changed

The FFT accelerator's compute engine was redesigned from pure radix-2 to mixed radix-4/2, reducing the number of butterfly operations and total compute cycles.

### Files changed

| File | Change |
|---|---|
| `project/src/design/accelerator_fft.v` | Rewrote FSM for mixed radix-4/2 butterfly (SRAM-based, no register file) |
| `project/firmware/fft.c` | Added `digit_reverse_mixed()` function for mixed-radix input permutation |
| `project/firmware/fft.h` | Declared `digit_reverse_mixed()` |
| `project/firmware/accel_audio.c` | Changed input permutation from `bit_reverse()` to `digit_reverse_mixed()` (scatter form) |
| `project/firmware/fft.py` | Updated golden reference to use radix-4/2 FFT with digit reversal |

### Why radix-4/2?

N=32 is not a power of 4, so pure radix-4 is impossible. The mixed approach greedily takes radix-4 stages (consuming 2 bits of log2(N) each), then finishes with a radix-2 stage if an odd bit remains.

**Stage decomposition for N=32 (5 bits):**
- Stage 1: radix-4, m=4, 8 groups x 1 butterfly = 8 butterflies
- Stage 2: radix-4, m=16, 2 groups x 4 butterflies = 8 butterflies
- Stage 3: radix-2, m=32, 1 group x 16 butterflies = 16 butterflies

### Why digit reversal instead of bit reversal?

Radix-2 DIT uses bit-reversal to permute inputs. Mixed radix-4/2 requires digit-reversal: the index is decomposed into mixed-radix digits (1-bit radix-2 digit first if log2(N) is odd, then 2-bit radix-4 digits), and the digit order is reversed.

Important: `digit_reverse_mixed()` is **not self-inverse** (unlike `bit_reverse()`), so the firmware must use scatter form (`SRAM[perm(i)] = input[i]`) rather than gather form.

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

### Behavioural simulation

Source: behavioural RTL simulation (`sim_behav`). Test: 24 chunks of 32 samples each (Nokia ringtone).

| Metric | Baseline (radix-2) | Radix-4/2 | Change |
|---|---|---|---|
| Accelerator cycles (total, 24 chunks) | 17,568 | 10,272 | **-41.5%** |
| Accelerator cycles (per chunk) | 732 | 428 | **-41.5%** |
| Accelerator latency (total) | 1.464 ms | 0.856 ms | **-41.5%** |
| First chunk latency | 60.998 us | 35.665 us | **-41.5%** |
| Total system cycles | 32,042,131 | 36,523,707 | +14.0% |

Note: total system cycles increased because `digit_reverse_mixed()` is more computationally expensive in firmware than `bit_reverse()`. However, the accelerator dominates power consumption, so what matters for energy is accelerator power x accelerator latency.

### Post-layout power

Source: Innovus power report using VCD from physical simulation (`sim_phys`). Technology: 45nm, 12 MHz clock.

| Metric | Baseline (radix-2) | Radix-4/2 | Change |
|---|---|---|---|
| Total power | 0.626 mW | 0.629 mW | +0.5% |
| accel (total) | 0.403 mW | 0.396 mW | -1.7% |
| accel/fft | 0.050 mW | 0.090 mW | +80% |
| accel/mem | 0.320 mW | 0.283 mW | -11.6% |
| soc | 0.201 mW | 0.205 mW | +2.0% |

### Energy comparison

Energy per chunk = accelerator power (from post-layout power report) x first chunk latency (from behavioural simulation).

| Metric | Baseline (radix-2) | Radix-4/2 | Change |
|---|---|---|---|
| Accelerator power | 0.403 mW | 0.396 mW | -1.7% |
| First chunk latency | 61.0 us | 35.7 us | -41.5% |
| **Energy per chunk** | **24.6 nJ** | **14.12 nJ** | **-42.6%** |

The radix-4/2 FFT achieves **~43% energy reduction** per chunk. The FFT logic itself uses more power (+80%) due to the more complex radix-4 butterfly, but memory power decreased (-11.6%) due to fewer SRAM accesses per FFT. The net accelerator power is nearly unchanged, so the energy saving comes almost entirely from the 41.5% cycle reduction.
