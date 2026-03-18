# EE Design (no_recursive_twiddle) — Behavioral Simulation Results

## Date: 2026-03-18
## Design: No Recursive Twiddle from romeu branch

### Timing Results
- **Accelerator cycles/chunk**: 732 (same as baseline)
- **Clock period**: 83.33 ns (12 MHz)
- **Accelerator latency**: $732 \times 83.33\text{ ns} = 60.998 \mu s$
- **Complete sim latency**: 1,476,158 cycles
- **Acceleration start**: 36.181386 ms (same as baseline)

### Verification
- `verify.py`: **PASSED** (outputs and gold are identical)
- Full audio (24 chunks): verified correct

### Energy Reduction Strategy
This design targets energy reduction through $\alpha$ (switching activity) reduction,
not through fewer cycles or lower frequency:

- Same FSM, same states, same cycle count as baseline
- Recursive twiddle update $w \leftarrow w \cdot w_m$ replaced with hardcoded LUT
- Removes extra complex multiplication for twiddle progression
- Expected result: same latency, lower dynamic power → lower energy

### Previous Results (from Romeu's branch)
- Baseline energy: 24.6 nJ
- EE energy: 23.795 nJ (−3.20%)
- These need to be reproduced with our own post-layout power analysis

### Notes
- VCD capture window is identical to baseline: start=36.181386 ms, duration=60.997560 us
- No firmware changes needed (same `accel_audio.c` as baseline)
