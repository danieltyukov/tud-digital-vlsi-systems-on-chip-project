# Key Metrics (Timing + Power)

Run folder: **project_ee**  
Run path: `/home/nfs/rlongomalinski/project_ee`

This summary is generated automatically from the baseline report files.

## 1) Clock and Latency Metrics

### Clocks
- `clk` period: **83.330 ns**
- `flash_clk` period: **166.660 ns**

Source: `pnr/initialReports/report_clocks.rpt`

### Simulation Latency
- Behavioral simulation (`sim_behav/transcript`):
  - Complete latency: **32042131 cycles**
  - Accelerator runtime: **17568**
  - Complete latency: **2670.070776 ms**
  - Accelerator runtime: **1.463941**
  - First chunk latency: **60.997560 us**
- Structural simulation (`sim_struct/transcript`):
  - Complete latency: **1476158 cycles**
  - Complete latency: **123.008246 ms**
- Physical simulation (`sim_phys/transcript`):
  - Complete latency: **1476157 cycles**
  - Complete latency: **123.008163 ms**

## 2) Timing Metrics (Synthesis + PnR)

### Synthesis Timing (Genus QoR)
- `clk` period: **83330.0 ps**
- `flash_clk` period: **166660.0 ps**
- Worst path slack `clk`: **31462.7 ps**
- Worst path slack `flash_clk`: **35449.3 ps**
- Total TNS: **0.0**

Source: `synth/reports/struct/et4351_qor.rpt`

### PnR Timing Progression
| Stage / File | Mode | WNS (ns) all | TNS (ns) all | Violating Paths all | DRV (max_tran) |
|---|---|---:|---:|---:|---|
| `pnr/timingReports/preCTS/et4351_preCTS.summary.gz` | Setup | 35.576 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/preCTS_hold/et4351_preCTS_hold.summary.gz` | Hold | -0.268 | -863.002 | 9930 | n/a |
| `pnr/timingReports/et4351_postCTS.summary.gz` | Setup | 35.839 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/postCTSHold_hold/et4351_postCTS_hold.summary.gz` | Hold | 0.060 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/route/et4351_postRoute.summary.gz` | Setup | 33.874 | 0.000 | 0 | 1783 (6161), worst -1.202 |
| `pnr/timingReports/route_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.054 | 0.000 | 0 | n/a |
| `pnr/timingReports/postRoute_hold/et4351_postRoute_hold.summary.gz` | Hold | -0.095 | -5.944 | 136 | n/a |
| `pnr/finalReports/report_timing/et4351_postRoute.summary.gz` | Setup | 33.921 | 0.000 | 0 | 105 (279), worst -0.272 |
| `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.058 | 0.000 | 0 | n/a |

### Final Timing Signoff Snapshot
- Setup WNS/TNS/Violating paths: **33.921 ns / 0.000 ns / 0**
- Hold WNS/TNS/Violating paths: **0.058 ns / 0.000 ns / 0**
- DRV max_tran (final setup report): **105 (279)**, worst **-0.272**

Sources:
- `pnr/finalReports/report_timing/et4351_postRoute.summary.gz`
- `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz`
- `pnr/finalReports/report_DRV/et4351_postRoute.summary.gz`

## 3) Power Metrics (All Available Power Reports)

Power units in reports are **mW**.

| Report file | Internal | Switching | Leakage | Total | Annotation shown in rpt |
|---|---:|---:|---:|---:|---|
| `pnr/powerReports/prePlace_VCDImport.rpt` | 0.37302765 | 0.01121906 | 0.01406804 | 0.39831474 | 0/33947 = 0% |
| `pnr/powerReports/preCTS.rpt` | 0.37354442 | 0.02559686 | 0.01277362 | 0.41191490 | 0/33008 = 0% |
| `pnr/powerReports/postCTSHold.rpt` | 0.44524923 | 0.13498284 | 0.02172129 | 0.60195335 | 0/46362 = 0% |
| `pnr/powerReports/route.rpt` | 0.44561328 | 0.14292337 | 0.02172129 | 0.61025793 | 0/46362 = 0% |
| `pnr/powerReports/postRoute.rpt` | 0.44511508 | 0.14289222 | 0.02120436 | 0.60921167 | 0/46685 = 0% |
| `pnr/powerReports/postRouteHold.rpt` | 0.44534768 | 0.14309073 | 0.02202283 | 0.61046124 | 0/48754 = 0% |
| `pnr/finalReports/report_power.rpt` | 0.44534768 | 0.14309073 | 0.02202283 | 0.61046124 | 0/48754 = 0% |

### Final Power Breakdown (Hierarchy)
From `pnr/finalReports/report_power.rpt`:
- `accel` total power: **0.3935 mW**
  - internal: 0.2933, switching: 0.08892, leakage: 0.01123
- `soc` total power: **0.203 mW**
- whole-chip total power: **0.61046124 mW**
- clock network power (`clk`): **0.1597 mW**
- clock period used in report: **0.083330 usec**
- clock toggle rate used in report: **23.9682 MHz**

### Energy (using first-chunk latency from behavioral sim)
Using `T_chunk = 60.997560 us`:
- Accelerator-only chunk energy: **24.003 nJ**
- Whole-chip chunk energy: **37.237 nJ**

## 4) Activity Annotation Notes

- Power report headers often show `Design annotation coverage: 0/... = 0%`.
- Innovus log VCD import section:
  - per-file coverage: **37099/37099 = 100%**
  - total coverage: **37099/37099 = 100%**
  - zero-toggle fraction: **19512/37099 = 52.5944%**
  - nets in VCD but not design: **12**

Sources: `pnr/innovus.log`, `pnr/voltus_power_missing_netnames.rpt`

## 5) Area and Signoff-Related Status

### Area
- Synthesis total area (Cell+Net): **184902.185**
- Synthesis total cell area: **145197.673**
- Final placed design total area: **230514.019**

Sources:
- `synth/reports/struct/et4351_area.rpt`
- `pnr/finalReports/report_area.rpt`

### Signoff/Verification reports
- DRC: **Clean**
- Connectivity: **Clean**
- Antenna: **Clean**
- Placement check: **Clean**
- CTS timing-check warnings:
  - ideal_clock_waveform: **4**
  - no_input_delay: **4**
  - unconstrained endpoint: **32**

## 6) Comparison Vs Hardcoded Baseline

Hardcoded baseline values are embedded in this script (`BASELINE` dict), so this comparison works even when only a new run folder is available.

| Metric | Current run | Baseline | Delta (current-baseline) | Status |
|---|---:|---:|---:|---|
| Setup WNS | 33.921 ns | 33.845 ns | +0.076 ns | better |
| Hold WNS | 0.058 ns | 0.032 ns | +0.026 ns | better |
| Accelerator total power | 0.3935 mW | 0.403 mW | -0.0095 mW | better |
| Chip total power | 0.610461 mW | 0.626273 mW | -0.0158116 mW | better |
| Accelerator leakage | 0.01123 mW | 0.01268 mW | -0.00145 mW | better |
| First-chunk latency | 60.9976 us | 60.9976 us | +0 us | same |
| Accelerator chunk energy | 24.0025 nJ | 24.582 nJ | -0.57946 nJ | better |
| Synthesis total area | 184902 um^2 | 194968 um^2 | -10065.7 um^2 | better |
| Final placed total area | 230514 um^2 | 242796 um^2 | -12282.2 um^2 | better |
| DRV max_tran worst | -0.272 ns | -0.626 ns | +0.354 ns | better |
| Annotation coverage | 37099/37099 = 100% | 36524/36524 = 100% | N/A | different |

## 7) ET4351 Project Description Checklist

Checklist derived from `instructions/ET4351_2026_Project_Description.pdf` (Section 1.1 and related “Important Things” requirements).

| Requirement (Project Description) | Result | Evidence |
|---|---|---|
| Fixed core area 596.4um x 596.4um | PASS | floorPlan -s 596.4 596.4 |
| Setup timing clean | PASS | WNS=33.921, TNS=0.000, Vio=0 |
| Hold timing clean | PASS | WNS=0.058, TNS=0.000, Vio=0 |
| DRV clean (max_cap) | PASS | real=0 (0) |
| DRV clean (max_fanout) | PASS | real=0 (0) |
| DRV clean (max_length) | PASS | real=0 (0) |
| max_tran violations acceptable note | WARN | real=105 (279), worst=-0.272 |
| Connectivity clean | PASS | verifyConnectivity |
| Geometry report clean | WARN | Explicit geometry report not found; DRC proxy=PASS |
| Antenna clean | PASS | verifyProcessAntenna |
| FFT correctness (variable chunks) | N/A | Artifacts present (outputs + expected + verify.py); full correctness requires execution/private tests |
| HP target latency < 61.00 us | PASS | first chunk latency=60.997560 us |
| EE target energy < 24.6 nJ | PASS | accel chunk energy=24.002540 nJ |
| EE minimum clock >= 10 MHz | PASS | clk=12.0005 MHz |
| Software accelerator handshake | PASS | Found enable -> wait(done) -> disable sequence in accelerated_fft flow |
| Post-layout power estimation report | PASS | pnr/finalReports/report_power.rpt |
| Activity annotation coverage 100% | PASS | 37099/37099 = 100% |
| VCD start+duration configured | PASS | start=36.181386ms, duration=60.997560us, on/off=yes |
| VCD window matches behavioral start/runtime | PASS | beh_start=36.181386ms vs cmd_start=36.181386ms; beh_dur=60.997560us vs cmd_dur=60.997560us |
| Submission finaldesign package files | WARN | No finaldesign/ or finaldesign_hp+finaldesign_ee packaging found |
| Testbench compatibility (tb_et4351.sv unmodified) | N/A | Cannot auto-verify unchanged baseline here; file present |
