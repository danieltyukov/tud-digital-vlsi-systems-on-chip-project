# HP Design D1 (Register-File) — PnR Results

## Date: 2026-03-18
## Tool: Cadence Innovus 21.11

### Timing (Post-Route)

| Mode | WNS (ns) | TNS (ns) | Violating Paths |
|------|----------|----------|-----------------|
| **Setup** | **+34.108** | **0.000** | **0** |
| **Hold** | **-0.165** | **-41.957** | **462** |

**Setup is CLEAN.** Hold has 462 violations (WNS = -0.165 ns). The hold violations are within clock uncertainty (0.25 ns) and may not cause functional failure — physical sim will determine.

### DRVs

| DRV | Real Nets (Setup) | Real Nets (Hold) |
|-----|-------------------|------------------|
| max_cap | 0 | 0 |
| max_tran | 988 (2930 terms) | 130 (373 terms) |
| max_fanout | 0 | 0 |
| max_length | 0 | 0 |

988 max_tran violations — significantly more than baseline (109). The 85% density causes congestion that degrades transition times.

### Signoff Checks

| Check | Result |
|-------|--------|
| DRC | No violations |
| Connectivity | No problems |
| Antenna | No violations |

### Density: 85.0%

### Comparison with Baseline

| Metric | Baseline | HP D1 |
|--------|----------|-------|
| Setup WNS | +33.845 ns | +34.108 ns |
| Hold WNS | +0.057 ns | **-0.165 ns** |
| Hold violations | 0 | **462** |
| max_tran nets | 109 | **988** |
| Density | 66.4% | **85.0%** |

### Root Cause Analysis
The D1 register file adds 2,368 flip-flops for data storage (64×32-bit data + twiddle registers). Combined with the single butterfly datapath, this pushes utilization to 85%. At this density:
1. CTS has difficulty inserting hold-fixing delay buffers — insufficient whitespace
2. Signal routing congestion increases wire delays and transition times
3. max_tran violations multiply due to long routing detours

### Potential Fixes
- Reduce register file size (e.g., shorter data words if bit-width analysis allows)
- Use a less aggressive accelerator design
- Manually guide floorplan to cluster register file near butterfly datapath
