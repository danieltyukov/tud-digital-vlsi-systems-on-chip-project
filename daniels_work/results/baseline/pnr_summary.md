# Baseline PnR Results

## Date: 2026-03-18
## Tool: Cadence Innovus 21.11

### Timing (Post-Route)

| Mode | WNS (ns) | TNS (ns) | Violating Paths |
|------|----------|----------|-----------------|
| **Setup** | **+33.845** | **0.000** | **0** |
| **Hold** | **+0.057** | **0.000** | **0** |

Both setup and hold are clean with positive slack.

### DRVs (Post-Route)

| DRV | Real Nets | Worst Violation | Total Nets |
|-----|-----------|----------------|------------|
| max_cap | 0 | 0.000 | 0 |
| **max_tran** | **109 (344 terms)** | **-0.626 ns** | **113 (352)** |
| max_fanout | 0 | 0 | 0 |
| max_length | 0 | 0 | 0 |

max_tran violations are allowed per project spec (footnote 1). All other DRVs are zero.

### Signoff Verification

| Check | Result |
|-------|--------|
| DRC | **No violations found** |
| Connectivity | **No problems or warnings** |
| Antenna | **No violations found** |
| Glitch violations | **0** |

### Area (Post-PnR)

| Module | Instances | Area ($\mu m^2$) |
|--------|-----------|-----------|
| **et4351 (total)** | **50,544** | **242,796** |
| accelerator | 25,597 | 111,300 |
| - accelerator_fft | 11,048 | 40,093 |
| - accelerator_mem | 13,012 | 64,853 |
| picosoc | 24,892 | 131,139 |
| - picorv32 CPU | 21,922 | 84,096 |
| - SRAM macros | 18 | 34,549 |

Density: 66.4%

### Power (Post-Route, 0% VCD annotation — needs re-run with physical VCD)

| Component | Power (mW) | % |
|-----------|-----------|---|
| Internal | 0.451 | 72.1% |
| Switching | 0.151 | 24.1% |
| Leakage | 0.024 | 3.8% |
| **Total** | **0.626** | **100%** |

**WARNING**: 0% activity annotation coverage. Power numbers are based on default activity assumptions and are NOT reliable for energy calculations. Need physical simulation VCD for accurate power.

### Power by Hierarchy (unreliable due to 0% annotation)

| Module | Power (mW) | % |
|--------|-----------|---|
| accelerator total | 0.403 | 64.4% |
| - accel/mem | 0.320 | 51.1% |
| - accel/fft | 0.050 | 8.0% |
| picosoc total | 0.201 | 32.1% |
| - CPU | 0.153 | 24.4% |
