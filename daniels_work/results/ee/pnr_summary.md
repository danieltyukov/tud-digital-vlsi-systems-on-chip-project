# EE Design (no_recursive_twiddle) — PnR Results

## Date: 2026-03-18
## Tool: Cadence Innovus 21.11

### Timing (Post-Route)

| Mode | WNS (ns) | TNS (ns) | Violating Paths |
|------|----------|----------|-----------------|
| **Setup** | **+34.148** | **0.000** | **0** |
| **Hold** | **+0.076** | **0.000** | **0** |

### DRVs

| DRV | Real Nets | Worst Violation | Total Nets |
|-----|-----------|----------------|------------|
| max_cap | 0 | 0.000 | 0 |
| max_tran | 47 (131) | -0.186 ns | 51 (141) |
| max_fanout | 0 | 0 | 0 |
| max_length | 0 | 0 | 0 |

### Signoff Checks

| Check | Result |
|-------|--------|
| DRC | No violations |
| Connectivity | No problems |
| Antenna | No violations |
| Glitch | 1 (cosmetic) |

### Area (Post-PnR)

| Module | Instances | Area ($\mu m^2$) |
|--------|-----------|-----------|
| **et4351 (total)** | **41,762** | **217,831** |
| accelerator | 18,903 | 84,974 |
| - accelerator_fft | 5,533 | 23,651 |
| - accelerator_mem | 12,001 | 54,786 |
| picosoc | 22,796 | 132,438 |

Density: 58.5%

### Power (0% VCD annotation — needs physical VCD)

| Component | Power (mW) | % |
|-----------|-----------|---|
| Internal | 0.445 | 73.0% |
| Switching | 0.144 | 23.6% |
| Leakage | 0.020 | 3.3% |
| **Total** | **0.610** | **100%** |

### Comparison with Baseline

| Metric | Baseline | EE | Change |
|--------|----------|-----|--------|
| Setup WNS | +33.845 ns | +34.148 ns | +0.3 ns better |
| Hold WNS | +0.057 ns | +0.076 ns | +0.019 ns better |
| max_tran nets | 109 | 47 | -57% (much fewer) |
| Total area | 242,796 $\mu m^2$ | 217,831 $\mu m^2$ | -10.3% |
| accel_fft area | 40,093 $\mu m^2$ | 23,651 $\mu m^2$ | -41% |
| Total power | 0.626 mW | 0.610 mW | -2.6% |
| Density | 66.4% | 58.5% | -7.9 pp |
