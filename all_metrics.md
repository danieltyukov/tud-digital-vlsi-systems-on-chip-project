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
- Worst path slack `clk`: **31269.8 ps**
- Worst path slack `flash_clk`: **35449.3 ps**
- Total TNS: **0.0**

Source: `synth/reports/struct/et4351_qor.rpt`

### PnR Timing Progression
| Stage / File | Mode | WNS (ns) all | TNS (ns) all | Violating Paths all | DRV (max_tran) |
|---|---|---:|---:|---:|---|
| `pnr/timingReports/preCTS/et4351_preCTS.summary.gz` | Setup | 35.582 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/preCTS_hold/et4351_preCTS_hold.summary.gz` | Hold | -0.261 | -882.647 | 10444 | n/a |
| `pnr/timingReports/et4351_postCTS.summary.gz` | Setup | 35.620 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/postCTSHold_hold/et4351_postCTS_hold.summary.gz` | Hold | 0.067 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/route/et4351_postRoute.summary.gz` | Setup | 33.719 | 0.000 | 0 | 963 (3711), worst -0.350 |
| `pnr/timingReports/route_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.067 | 0.000 | 0 | n/a |
| `pnr/timingReports/postRoute_hold/et4351_postRoute_hold.summary.gz` | Hold | -0.094 | -2.348 | 53 | n/a |
| `pnr/finalReports/report_timing/et4351_postRoute.summary.gz` | Setup | 33.730 | 0.000 | 0 | 58 (146), worst -0.176 |
| `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.047 | 0.000 | 0 | n/a |

### Final Timing Signoff Snapshot
- Setup WNS/TNS/Violating paths: **33.730 ns / 0.000 ns / 0**
- Hold WNS/TNS/Violating paths: **0.047 ns / 0.000 ns / 0**
- DRV max_tran (final setup report): **58 (146)**, worst **-0.176**

Sources:
- `pnr/finalReports/report_timing/et4351_postRoute.summary.gz`
- `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz`
- `pnr/finalReports/report_DRV/et4351_postRoute.summary.gz`

## 3) Power Metrics (All Available Power Reports)

Power units in reports are **mW**.

| Report file | Internal | Switching | Leakage | Total | Annotation shown in rpt |
|---|---:|---:|---:|---:|---|
| `pnr/powerReports/prePlace_VCDImport.rpt` | 0.26401598 | 0.01091486 | 0.01280241 | 0.28773325 | 0/30062 = 0% |
| `pnr/powerReports/preCTS.rpt` | 0.26470500 | 0.02475660 | 0.01171711 | 0.30117870 | 0/29446 = 0% |
| `pnr/powerReports/postCTSHold.rpt` | 0.32024056 | 0.10273922 | 0.01991389 | 0.44289367 | 0/40954 = 0% |
| `pnr/powerReports/route.rpt` | 0.32047599 | 0.10814698 | 0.01991389 | 0.44853687 | 0/40954 = 0% |
| `pnr/powerReports/postRoute.rpt` | 0.32024922 | 0.10796422 | 0.01961870 | 0.44783214 | 0/41113 = 0% |
| `pnr/powerReports/postRouteHold.rpt` | 0.32059812 | 0.10823753 | 0.02006013 | 0.44889578 | 0/42247 = 0% |
| `pnr/finalReports/report_power_postRouteVCD.rpt` | 0.15868052 | 0.05219013 | 0.01988970 | 0.23076036 | 0/40983 = 0% |
| `pnr/finalReports/report_power.rpt` | 0.32059812 | 0.10823753 | 0.02006013 | 0.44889578 | 0/42247 = 0% |

### Final Power Breakdown (Hierarchy)
From `pnr/finalReports/report_power_postRouteVCD.rpt`:
- `accel` total power: **0.01942 mW**
  - internal: 0.008835, switching: 0.001278, leakage: 0.009304
- `soc` total power: **0.1983 mW**
- whole-chip total power: **0.23076036 mW**
- clock network power (`clk`): **0.06838 mW**
- clock period used in report: **0.083330 usec**
- clock toggle rate used in report: **23.8044 MHz**

### Energy (using first-chunk latency from behavioral sim)
Using `T_chunk = 60.997560 us`:
- Accelerator-only chunk energy: **1.185 nJ**
- Whole-chip chunk energy: **14.076 nJ**

## 4) Activity Annotation Notes

- Power report headers often show `Design annotation coverage: 0/... = 0%`.
- Innovus log VCD import section:
  - annotation source log: **pnr/innovus.log47**
  - per-file coverage: **40983/40983 = 100%**
  - total coverage: **40983/40983 = 100%**
  - zero-toggle fraction: **35987/40983 = 87.8096%**
  - nets in VCD but not design: **9**

Sources: `pnr/innovus.log47`, `pnr/voltus_power_missing_netnames.rpt`

## 5) Area and Signoff-Related Status

### Area
- Synthesis total area (Cell+Net): **171708.543**
- Synthesis total cell area: **136008.475**
- Final placed design total area: **215452.339**

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

## 6) Comparison Vs Hardcoded Baselines

Both baseline references are embedded in this script:
- Legacy baseline: non-windowed post-layout power (`report_power.rpt`)
- Windowed baseline: post-route VCD-windowed power (`report_power_postRouteVCD.rpt`)

### 6.1 Legacy Baseline Comparison
Current-run power source used for this comparison: `pnr/finalReports/report_power.rpt`

| Metric | Current run | Legacy baseline | Delta (current-baseline) | Status |
|---|---:|---:|---:|---|
| Setup WNS | 33.73 ns | 33.845 ns | -0.115 ns | worse |
| Hold WNS | 0.047 ns | 0.032 ns | +0.015 ns | better |
| Accelerator total power | 0.2336 mW | 0.403 mW | -0.1694 mW | better |
| Chip total power | 0.448896 mW | 0.626273 mW | -0.177377 mW | better |
| Accelerator leakage | 0.009312 mW | 0.01268 mW | -0.003368 mW | better |
| First-chunk latency | 60.9976 us | 60.9976 us | +0 us | same |
| Accelerator chunk energy | 14.249 nJ | 24.582 nJ | -10.333 nJ | better |
| Synthesis total area | 171709 um^2 | 194968 um^2 | -23259.3 um^2 | better |
| Final placed total area | 215452 um^2 | 242796 um^2 | -27343.9 um^2 | better |
| DRV max_tran worst | -0.176 ns | -0.626 ns | +0.45 ns | better |
| Annotation coverage | 40983/40983 = 100% | 36524/36524 = 100% | N/A | different |

### 6.2 Windowed Baseline Comparison
Current-run power source used for this comparison: `pnr/finalReports/report_power_postRouteVCD.rpt`

| Metric | Current run | Windowed baseline | Delta (current-baseline) | Status |
|---|---:|---:|---:|---|
| Setup WNS | 33.73 ns | 33.845 ns | -0.115 ns | worse |
| Hold WNS | 0.047 ns | 0.032 ns | +0.015 ns | better |
| Accelerator total power | 0.01942 mW | 0.3347 mW | -0.31528 mW | better |
| Chip total power | 0.23076 mW | 0.553843 mW | -0.323083 mW | better |
| Accelerator leakage | 0.009304 mW | 0.01266 mW | -0.003356 mW | better |
| First-chunk latency | 60.9976 us | 60.9976 us | +0 us | same |
| Accelerator chunk energy | 1.18457 nJ | 20.4159 nJ | -19.2313 nJ | better |
| Synthesis total area | 171709 um^2 | 194968 um^2 | -23259.3 um^2 | better |
| Final placed total area | 215452 um^2 | 242796 um^2 | -27343.9 um^2 | better |
| DRV max_tran worst | -0.176 ns | -0.626 ns | +0.45 ns | better |
| Annotation coverage | 40983/40983 = 100% | 36524/36524 = 100% | N/A | different |

## 7) ET4351 Project Description Checklist

Checklist derived from `instructions/ET4351_2026_Project_Description.pdf` (Section 1.1 and related “Important Things” requirements).

| Requirement (Project Description) | Result | Evidence |
|---|---|---|
| Fixed core area 596.4um x 596.4um | PASS | floorPlan -s 596.4 596.4 |
| Setup timing clean | PASS | WNS=33.730, TNS=0.000, Vio=0 |
| Hold timing clean | PASS | WNS=0.047, TNS=0.000, Vio=0 |
| DRV clean (max_cap) | PASS | real=0 (0) |
| DRV clean (max_fanout) | PASS | real=0 (0) |
| DRV clean (max_length) | PASS | real=0 (0) |
| max_tran violations acceptable note | WARN | real=58 (146), worst=-0.176 |
| Connectivity clean | PASS | verifyConnectivity |
| Geometry report clean | WARN | Explicit geometry report not found; DRC proxy=PASS |
| Antenna clean | PASS | verifyProcessAntenna |
| FFT correctness (variable chunks) | N/A | Artifacts present (outputs + expected + verify.py); full correctness requires execution/private tests |
| HP target latency < 61.00 us | PASS | first chunk latency=60.997560 us |
| EE target energy < 24.6 nJ | PASS | accel chunk energy=1.184573 nJ |
| EE minimum clock >= 10 MHz | PASS | clk=12.0005 MHz |
| Software accelerator handshake | PASS | Found enable -> wait(done) -> disable sequence in accelerated_fft flow |
| Post-layout power estimation report | PASS | pnr/finalReports/report_power_postRouteVCD.rpt |
| Activity annotation coverage 100% | PASS | 40983/40983 = 100% |
| VCD start+duration configured | PASS | struct: start=36.181386ms, dur=60.997560us, on/off=yes ; phys_setup: start=36.181386ms, dur=60.997560us, on/off=yes ; phys_hold: start=36.181386ms, dur=60.997560us, on/off=yes |
| VCD window matches behavioral start/runtime | PASS | struct: beh_start=36.181386ms vs cmd_start=36.181386ms, beh_dur=60.997560us vs cmd_dur=60.997560us ; phys_setup: beh_start=36.181386ms vs cmd_start=36.181386ms, beh_dur=60.997560us vs cmd_dur=60.997560us ; phys_hold: beh_start=36.181386ms vs cmd_start=36.181386ms, beh_dur=60.997560us vs cmd_dur=60.997560us |
| Submission finaldesign package files | PASS | finaldesign/ contains accel_audio.hex, et4351.phys.sdf, et4351.phys.v |
| Testbench compatibility (tb_et4351.sv unmodified) | N/A | Cannot auto-verify unchanged baseline here; file present |
