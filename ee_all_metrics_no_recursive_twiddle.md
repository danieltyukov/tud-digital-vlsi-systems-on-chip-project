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
- Worst path slack `clk`: **31290.7 ps**
- Worst path slack `flash_clk`: **35449.3 ps**
- Total TNS: **0.0**

Source: `synth/reports/struct/et4351_qor.rpt`

### PnR Timing Progression
| Stage / File | Mode | WNS (ns) all | TNS (ns) all | Violating Paths all | DRV (max_tran) |
|---|---|---:|---:|---:|---|
| `pnr/timingReports/preCTS/et4351_preCTS.summary.gz` | Setup | 35.571 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/preCTS_hold/et4351_preCTS_hold.summary.gz` | Hold | -0.267 | -885.489 | 9541 | n/a |
| `pnr/timingReports/et4351_postCTS.summary.gz` | Setup | 35.836 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/postCTSHold_hold/et4351_postCTS_hold.summary.gz` | Hold | 0.060 | 0.000 | 0 | 0 (0), worst 0.000 |
| `pnr/timingReports/route/et4351_postRoute.summary.gz` | Setup | 34.135 | 0.000 | 0 | 1151 (4619), worst -1.561 |
| `pnr/timingReports/route_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.040 | 0.000 | 0 | n/a |
| `pnr/timingReports/postRoute_hold/et4351_postRoute_hold.summary.gz` | Hold | -0.092 | -2.009 | 45 | n/a |
| `pnr/finalReports/report_timing/et4351_postRoute.summary.gz` | Setup | 34.148 | 0.000 | 0 | 47 (131), worst -0.186 |
| `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz` | Hold | 0.076 | 0.000 | 0 | n/a |

### Final Timing Signoff Snapshot
- Setup WNS/TNS/Violating paths: **34.148 ns / 0.000 ns / 0**
- Hold WNS/TNS/Violating paths: **0.076 ns / 0.000 ns / 0**
- DRV max_tran (final setup report): **47 (131)**, worst **-0.186**

Sources:
- `pnr/finalReports/report_timing/et4351_postRoute.summary.gz`
- `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz`
- `pnr/finalReports/report_DRV/et4351_postRoute.summary.gz`

## 3) Power Metrics (All Available Power Reports)

Power units in reports are **mW**.

| Report file | Internal | Switching | Leakage | Total | Annotation shown in rpt |
|---|---:|---:|---:|---:|---|
| `pnr/powerReports/prePlace_VCDImport.rpt` | 0.37095360 | 0.01135830 | 0.01270294 | 0.39501483 | 0/29602 = 0% |
| `pnr/powerReports/preCTS.rpt` | 0.37192058 | 0.02735249 | 0.01168088 | 0.41095396 | 0/29262 = 0% |
| `pnr/powerReports/postCTSHold.rpt` | 0.44529063 | 0.13694149 | 0.02025087 | 0.60248299 | 0/41906 = 0% |
| `pnr/powerReports/route.rpt` | 0.44556225 | 0.14413151 | 0.02025087 | 0.60994463 | 0/41906 = 0% |
| `pnr/powerReports/postRoute.rpt` | 0.44515504 | 0.14406218 | 0.01989593 | 0.60911315 | 0/42067 = 0% |
| `pnr/powerReports/postRouteHold.rpt` | 0.44523306 | 0.14392079 | 0.02038625 | 0.60954010 | 0/43397 = 0% |
| `pnr/finalReports/report_power.rpt` | 0.44523306 | 0.14392079 | 0.02038625 | 0.60954010 | 0/43397 = 0% |

### Final Power Breakdown (Hierarchy)
From `pnr/finalReports/report_power.rpt`:
- `accel` total power: **0.3901 mW**
  - internal: 0.292, switching: 0.08852, leakage: 0.00964
- `soc` total power: **0.2002 mW**
- whole-chip total power: **0.60954010 mW**
- clock network power (`clk`): **0.1598 mW**
- clock period used in report: **0.083330 usec**
- clock toggle rate used in report: **23.9682 MHz**

### Energy (using first-chunk latency from behavioral sim)
Using `T_chunk = 60.997560 us`:
- Accelerator-only chunk energy: **23.795 nJ**
- Whole-chip chunk energy: **37.180 nJ**

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
- Synthesis total area (Cell+Net): **170574.851**
- Synthesis total cell area: **135306.349**
- Final placed design total area: **217830.949**

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
| Setup WNS | 34.148 ns | 33.845 ns | +0.303 ns | better |
| Hold WNS | 0.076 ns | 0.032 ns | +0.044 ns | better |
| Accelerator total power | 0.3901 mW | 0.403 mW | -0.0129 mW | better |
| Chip total power | 0.60954 mW | 0.626273 mW | -0.0167328 mW | better |
| Accelerator leakage | 0.00964 mW | 0.01268 mW | -0.00304 mW | better |
| First-chunk latency | 60.9976 us | 60.9976 us | +0 us | same |
| Accelerator chunk energy | 23.7951 nJ | 24.582 nJ | -0.786852 nJ | better |
| Synthesis total area | 170575 um^2 | 194968 um^2 | -24393 um^2 | better |
| Final placed total area | 217831 um^2 | 242796 um^2 | -24965.3 um^2 | better |
| DRV max_tran worst | -0.186 ns | -0.626 ns | +0.44 ns | better |
| Annotation coverage | 37099/37099 = 100% | 36524/36524 = 100% | N/A | different |

## 7) ET4351 Project Description Checklist

Checklist derived from `instructions/ET4351_2026_Project_Description.pdf` (Section 1.1 and related “Important Things” requirements).

| Requirement (Project Description) | Result | Evidence |
|---|---|---|
| Fixed core area 596.4um x 596.4um | PASS | floorPlan -s 596.4 596.4 |
| Setup timing clean | PASS | WNS=34.148, TNS=0.000, Vio=0 |
| Hold timing clean | PASS | WNS=0.076, TNS=0.000, Vio=0 |
| DRV clean (max_cap) | PASS | real=0 (0) |
| DRV clean (max_fanout) | PASS | real=0 (0) |
| DRV clean (max_length) | PASS | real=0 (0) |
| max_tran violations acceptable note | WARN | real=47 (131), worst=-0.186 |
| Connectivity clean | PASS | verifyConnectivity |
| Geometry report clean | WARN | Explicit geometry report not found; DRC proxy=PASS |
| Antenna clean | PASS | verifyProcessAntenna |
| FFT correctness (variable chunks) | N/A | Artifacts present (outputs + expected + verify.py); full correctness requires execution/private tests |
| HP target latency < 61.00 us | PASS | first chunk latency=60.997560 us |
| EE target energy < 24.6 nJ | PASS | accel chunk energy=23.795148 nJ |
| EE minimum clock >= 10 MHz | PASS | clk=12.0005 MHz |
| Software accelerator handshake | PASS | Found enable -> wait(done) -> disable sequence in accelerated_fft flow |
| Post-layout power estimation report | PASS | pnr/finalReports/report_power.rpt |
| Activity annotation coverage 100% | PASS | 37099/37099 = 100% |
| VCD start+duration configured | PASS | start=36.181386ms, duration=60.997560us, on/off=yes |
| VCD window matches behavioral start/runtime | PASS | beh_start=36.181386ms vs cmd_start=36.181386ms; beh_dur=60.997560us vs cmd_dur=60.997560us |
| Submission finaldesign package files | WARN | No finaldesign/ or finaldesign_hp+finaldesign_ee packaging found |
| Testbench compatibility (tb_et4351.sv unmodified) | N/A | Cannot auto-verify unchanged baseline here; file present |
