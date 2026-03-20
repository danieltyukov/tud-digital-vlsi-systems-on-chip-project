# D2 (2× Parallel Butterflies) — Results

## Behavioral Simulation
- **Cycles/chunk**: 206 (4944 total / 24 chunks)
- **Latency**: 17.17 $\mu s$ @ 12 MHz
- **Verification**: PASS (outputs and gold identical)

## Synthesis
- Not independently run (D2 agent had issues)
- Expected: similar to D1 area with ~10% increase for second butterfly datapath

## PnR
- D2 agent PnR used stale baseline outputs (innovus startup issue)
- Not independently verified through PnR
- Expected: similar to D1 (register-file based, baseline clock, ~80% density)

## Summary for Report Progression Table

D2 is a stepping stone between D1 (220 cycles) and D3 (170 cycles):
- D1 → D2: 220 → 206 cycles (6.4% reduction, 14 cycles saved)
- The gain is modest because twiddle fill overhead (26 of 66 compute cycles) limits the parallel butterfly benefit
- This bottleneck directly motivated D3 (SW twiddle preload, eliminates fill overhead)

## Note
D2 data is used only for the report's incremental progression narrative.
D5 (121 cycles @ 48 MHz) is the final HP submission design.
