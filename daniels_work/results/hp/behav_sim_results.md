# HP Design (D3) — Behavioral Simulation Results

## Date: 2026-03-18
## Design: SW Twiddle Preload (D3) from ShanghongLin-HP-D3-twiddle_preload

### Timing Results
- **Accelerator cycles/chunk**: 170
- **Clock period**: 83.33 ns (12 MHz)
- **Accelerator latency**: $170 \times 83.33\text{ ns} = 14.166 \mu s$
- **Complete sim latency**: 1,491,826 cycles
- **Acceleration start**: 41.069274 ms (firmware boot + data loading)
- **Speedup vs baseline**: $61.00 / 14.17 = 4.31\times$

### Cycle Breakdown
| Phase | Cycles | % |
|-------|--------|---|
| INIT | 1 | 0.6% |
| LOAD_DATA | 64 | 37.6% |
| COMPUTE | 40 | 23.5% |
| STORE_DATA | 64 | 37.6% |
| FINISH | 1 | 0.6% |
| **Total** | **170** | **100%** |

### Verification
- `verify.py`: **PASSED** (outputs and gold are identical)
- Full audio (24 chunks): verified correct

### Notes
- Acceleration start time differs from baseline (41.07 ms vs 36.18 ms)
  because the firmware pre-loads twiddle factors to CSR registers before
  enabling the accelerator — this takes extra CPU cycles but is outside
  the timed accelerator window.
- VCD capture window must be updated to: start=41.069274 ms, duration=14.166100 us
