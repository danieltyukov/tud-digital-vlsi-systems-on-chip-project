# Baseline All - Key Metrics (Timing + Power)

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
- Worst path slack `clk`: **31863.7 ps**
- Worst path slack `flash_clk`: **35449.3 ps**
- Total TNS: **0.0**

Source: `synth/reports/struct/et4351_qor.rpt`

### PnR Timing Progression
| Stage / File | Mode | WNS (ns) all | TNS (ns) all | Violating Paths all | DRV (max_tran) |
|---|---|---:|---:|---:|---|
| `pnr/timingReports/preCTS/et4351_preCTS.summary.gz` | Setup | 35.577 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/preCTS_hold/et4351_preCTS_hold.summary.gz` | Hold | -0.268 | -903.553 | 9428 | n/a |
| `pnr/timingReports/et4351_postCTS.summary.gz` | Setup | 35.770 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/postCTSHold_hold/et4351_postCTS_hold.summary.gz` | Hold | 0.065 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/route/et4351_postRoute.summary.gz` | Setup | 33.615 | 0.000 | 0 | 1772 (6507), worst -2.721 |
| `pnr/timingReports/route_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.066 | 0.000 | 0 | n/a |
| `pnr/timingReports/postRoute_hold/et4351_postRoute_hold.summary.gz` | Hold | -0.090 | -4.049 | 103 | n/a |
| `pnr/finalReports/report_timing/et4351_postRoute.summary.gz` | Setup | 33.597 | 0.000 | 0 | 124 (322), worst -0.389 |
| `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.030 | 0.000 | 0 | n/a |

### Final Timing Signoff Snapshot
- Setup WNS/TNS/Violating paths: **33.597 ns / 0.000 ns / 0**
- Hold WNS/TNS/Violating paths: **0.030 ns / 0.000 ns / 0**
- DRV max_tran (final setup report): **124 (322)**, worst **-0.389**

Sources:
- `pnr/finalReports/report_timing/et4351_postRoute.summary.gz`
- `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz`
- `pnr/finalReports/report_DRV/et4351_postRoute.summary.gz`

## 3) Power Metrics (All Available Power Reports)

Power units in reports are **mW**.

| Report file | Internal | Switching | Leakage | Total | Annotation shown in rpt |
|---|---:|---:|---:|---:|---|
| `pnr/powerReports/prePlace_VCDImport.rpt` | 0.37721432 | 0.01265601 | 0.01522716 | 0.40509749 | 0/37099 = 0% |
| `pnr/powerReports/preCTS.rpt` | 0.37751317 | 0.02890298 | 0.01379731 | 0.42021346 | 0/35911 = 0% |
| `pnr/powerReports/postCTSHold.rpt` | 0.44975475 | 0.13956715 | 0.02279909 | 0.61212099 | 0/49892 = 0% |
| `pnr/powerReports/route.rpt` | 0.45018637 | 0.14835703 | 0.02279909 | 0.62134248 | 0/49892 = 0% |
| `pnr/powerReports/postRoute.rpt` | 0.44994849 | 0.14839854 | 0.02227875 | 0.62062578 | 0/50221 = 0% |
| `pnr/powerReports/postRouteHold.rpt` | 0.45019162 | 0.14865173 | 0.02308524 | 0.62192859 | 0/52358 = 0% |
| `pnr/finalReports/report_power.rpt` | 0.45019162 | 0.14865173 | 0.02308524 | 0.62192859 | 0/52358 = 0% |

### Final Power Breakdown (Hierarchy)
From `pnr/finalReports/report_power.rpt`:
- `accel` total power: **0.4018 mW**
  - internal: 0.298, switching: 0.09158, leakage: 0.01224
- `soc` total power: **0.203 mW**
- whole-chip total power: **0.62192859 mW**
- clock network power (`clk`): **0.1613 mW**
- clock period used in report: **0.083330 usec**
- clock toggle rate used in report: **23.9682 MHz**

### Energy (using first-chunk latency from behavioral sim)
Using `T_chunk = 60.997560 us`:
- Accelerator-only chunk energy: **24.509 nJ**
- Whole-chip chunk energy: **37.936 nJ**

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
- Synthesis total area (Cell+Net): **196862.403**
- Synthesis total cell area: **153337.615**
- Final placed design total area: **237637.537**

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
| Setup WNS | 33.597 ns | 33.845 ns | -0.248 ns | worse |
| Hold WNS | 0.03 ns | 0.032 ns | -0.002 ns | worse |
| Accelerator total power | 0.4018 mW | 0.403 mW | -0.0012 mW | better |
| Chip total power | 0.621929 mW | 0.626273 mW | -0.00434429 mW | better |
| Accelerator leakage | 0.01224 mW | 0.01268 mW | -0.00044 mW | better |
| First-chunk latency | 60.9976 us | 60.9976 us | +0 us | same |
| Accelerator chunk energy | 24.5088 nJ | 24.582 nJ | -0.0731804 nJ | better |
| Synthesis total area | 196862 um^2 | 194968 um^2 | +1894.56 um^2 | worse |
| Final placed total area | 237638 um^2 | 242796 um^2 | -5158.73 um^2 | better |
| DRV max_tran worst | -0.389 ns | -0.626 ns | +0.237 ns | better |
| Annotation coverage | 37099/37099 = 100% | 36524/36524 = 100% | N/A | different |

## 7) ET4351 Project Description Checklist

Checklist derived from `instructions/ET4351_2026_Project_Description.pdf` (Section 1.1 and related “Important Things” requirements).

| Requirement (Project Description) | Result | Evidence |
|---|---|---|
| Fixed core area 596.4um x 596.4um | PASS | floorPlan -s 596.4 596.4 |
| Setup timing clean | PASS | WNS=33.597, TNS=0.000, Vio=0 |
| Hold timing clean | PASS | WNS=0.030, TNS=0.000, Vio=0 |
| DRV clean (max_cap) | PASS | real=0 (0) |
| DRV clean (max_fanout) | PASS | real=0 (0) |
| DRV clean (max_length) | PASS | real=0 (0) |
| max_tran violations acceptable note | WARN | real=124 (322), worst=-0.389 |
| Connectivity clean | PASS | verifyConnectivity |
| Geometry report clean | WARN | Explicit geometry report not found; DRC proxy=PASS |
| Antenna clean | PASS | verifyProcessAntenna |
| FFT correctness (variable chunks) | N/A | Artifacts present (outputs + expected + verify.py); full correctness requires execution/private tests |
| HP target latency < 61.00 us | PASS | first chunk latency=60.997560 us |
| EE target energy < 24.6 nJ | PASS | accel chunk energy=24.508820 nJ |
| EE minimum clock >= 10 MHz | PASS | clk=12.0005 MHz |
| Software accelerator handshake | PASS | Found enable -> wait(done) -> disable sequence in accelerated_fft flow |
| Post-layout power estimation report | PASS | pnr/finalReports/report_power.rpt |
| Activity annotation coverage 100% | PASS | 37099/37099 = 100% |
| VCD start+duration configured | PASS | start=36.181386ms, duration=60.997560us, on/off=yes |
| VCD window matches behavioral start/runtime | PASS | beh_start=36.181386ms vs cmd_start=36.181386ms; beh_dur=60.997560us vs cmd_dur=60.997560us |
| Submission finaldesign package files | WARN | No finaldesign/ or finaldesign_hp+finaldesign_ee packaging found |
| Testbench compatibility (tb_et4351.sv unmodified) | N/A | Cannot auto-verify unchanged baseline here; file present |
