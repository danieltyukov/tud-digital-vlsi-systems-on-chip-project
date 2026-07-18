# SDC Fix Results — Zero Hold Violations Achieved

## Date: 2026-03-23
## Based on: Lynn's PnR analysis (Notion doc, March 23)

## Fixes Applied

### SDC Changes (`src/sdc/et4351.sdc`)
| Fix | Parameter | Before | After | Rationale |
|-----|-----------|--------|-------|-----------|
| **A+E** | `CLK_UNCERTAINTY` | 0.25 ns | **0.10 ns** | Actual skew is 0.002 ns; 0.25 was 125x over-pessimistic, forcing unnecessary hold buffers |
| **D** | `set_max_transition` | Not set | **0.28 ns** | Forces Genus to pick stronger-drive cells, reducing max_tran DRVs at source |

### PnR Script Changes
| Fix | File | Change |
|-----|------|--------|
| **B** | `6.cts.tcl` | `holdTargetSlack` 0.1 → **0.2** (more pre-route hold margin) |
| **C** | `7.route.tcl` | Added `holdTargetSlack 0.05` + second `optDesign -postRoute -hold` pass |

## Results

### HP D1 (Register-File, 220 cycles, 12 MHz)

| Metric | Before SDC Fix | After SDC Fix |
|--------|---------------|---------------|
| **Hold WNS** | -0.165 ns | **+0.050 ns** |
| **Hold violations** | 462 | **0** |
| **Setup WNS** | +34.108 ns | +34.442 ns |
| **Setup violations** | 0 | 0 |
| **DRC** | Clean | Clean |
| **Connectivity** | Clean | Clean |
| **Antenna** | Clean | Clean |
| **Density** | 85.0% | **56.9%** |
| **Phys sim (setup)** | PASS | PASS |
| **Phys sim (hold)** | PASS | PASS |

### EE v3 (D1 + LUT + Clock Gating, 210 cycles, 12 MHz)

| Metric | Before SDC Fix (clean rebuild) | After SDC Fix |
|--------|-------------------------------|---------------|
| **Hold WNS** | +0.057 ns | **+0.049 ns** |
| **Hold violations** | 0 | **0** |
| **Setup WNS** | +33.845 ns | +34.317 ns |
| **Setup violations** | 0 | 0 |
| **DRC** | Clean | Clean |
| **Connectivity** | Clean | Clean |
| **Antenna** | Clean | Clean |
| **Density** | 66.4% | **70.2%** |
| **Phys sim (setup)** | PASS | PASS |
| **Phys sim (hold)** | PASS | PASS |

## Key Insight

The dramatic density reduction on HP D1 (85% → 57%) is because:
1. `set_max_transition 0.28` forces Genus to pick stronger-drive cells (INVX2 instead of INVXL) — these are wider but fewer are needed
2. Reduced clock uncertainty means Innovus inserts far fewer hold-fixing delay buffers (~20,000 fewer FFs)
3. The combined effect is a much smaller post-PnR design that has plenty of room for timing closure

## Files
- Fixed SDC: `daniels_work/sdc_fixes/et4351_hp_d1_fixed.sdc`
- Fixed CTS script: `daniels_work/sdc_fixes/pnr_scripts/6.cts_fixed.tcl`
- Fixed route script: `daniels_work/sdc_fixes/pnr_scripts/7.route_fixed.tcl`
- Server projects: `~/project_hp_d1_clean`, `~/project_ee_v3`
- Packaged: `~/finaldesign_hp/`, `~/finaldesign_ee/`
