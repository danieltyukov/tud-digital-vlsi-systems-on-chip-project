# ET4351 EE Hand-In Summary

This summary combines:

- the course rules from [ET4351_full_flow_restore.md](/home/nfs/rlongomalinski/instructions/ET4351_full_flow_restore.md)
- the clean signoff reports under [pnr/verifyReports](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports)
- the clean timing/DRV reports under [pnr/finalReports](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports)
- the VCD-based post-layout power run from [11.finalPowerReports.tcl](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/scripts/11.finalPowerReports.tcl)

## What The Course Expects

For the `EE` version, the important project targets are:

- energy must beat the baseline `24.6 nJ`
- clock frequency must stay at or above `10 MHz`
- fixed core area must remain `596.4 um x 596.4 um`
- final design must be clean on:
  - setup timing
  - hold timing
  - DRV
  - connectivity
  - geometry / DRC
  - antenna
- post-layout simulation must pass
- final power must come from the post-layout VCD-based power flow, not just the generic static power report

## Final EE Metrics

| Metric | Target / requirement | Current value | Status | Source |
|---|---|---:|---|---|
| Core dimensions | `596.4 um x 596.4 um` fixed | `596.4 um x 596.4 um` | Pass | [ET4351_full_flow_restore.md](/home/nfs/rlongomalinski/instructions/ET4351_full_flow_restore.md) |
| Core area | fixed by project rule | `355692.96 um^2` | Pass | computed from fixed core size |
| Implemented cell area | reportable in final report | `223541.665 um^2` | Info | [report_area.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_area.rpt) |
| Core utilization | reportable in final report | `62.85%` | Info | computed from cell area / core area |
| Nominal clock period | must support `>= 10 MHz` | `83.33 ns` | Pass | project setup / power report |
| Nominal clock frequency | `>= 10 MHz` | `12 MHz` | Pass | project setup / power report |
| Total accelerator runtime over full behavioral audio | not the EE hand-in window | `5040 cycles` | Info | [sim_behav/transcript](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_behav/transcript) |
| Total accelerator runtime over full behavioral audio | not the EE hand-in window | `0.419983 ms` | Info | [sim_behav/transcript](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_behav/transcript) |
| Accelerator start time | used to set VCD window | `36.181386 ms` | Info | [sim_behav/transcript](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_behav/transcript) |
| First chunk latency | used for EE energy and VCD window | `17.499300 us` | Info | [sim_behav/transcript](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_behav/transcript) |
| Post-layout accelerator power | must beat `0.403 mW` baseline | `0.02576 mW` | Pass | [report_power_postRouteVCD.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_power_postRouteVCD.rpt) |
| Post-layout accelerator energy | must beat `24.6 nJ` baseline | `0.4508 nJ` | Pass | computed from VCD power x first-chunk latency |
| Post-layout total chip power | useful report number | `0.22997921 mW` | Info | [report_power_postRouteVCD.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_power_postRouteVCD.rpt) |
| Setup timing | clean | `WNS = 34.322 ns`, `TNS = 0` | Pass | [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_DRV/et4351_postRoute.summary.gz) |
| Hold timing | clean | `WNS = 0.002 ns`, `TNS = 0` | Pass | [report_timing_hold](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_timing_hold) |
| Real `max_cap` | clean | `0` | Pass | [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_DRV/et4351_postRoute.summary.gz) |
| Real `max_tran` | clean | `0` | Pass | [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_DRV/et4351_postRoute.summary.gz) |
| Real `max_fanout` | clean | `0` | Pass | [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_DRV/et4351_postRoute.summary.gz) |
| Connectivity | clean | `0` violations | Pass | [verifyConnectivity.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/verifyConnectivity.rpt) |
| DRC / geometry | clean | `0` violations | Pass | [verify_drc.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/verify_drc.rpt) |
| Antenna | clean | `0` violations | Pass | [verifyProcessAntenna.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/verifyProcessAntenna.rpt) |
| Post-layout functional sim | must pass | `verify.py` passed | Pass | [sim_phys/transcript](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_phys/transcript) |
| VCD annotation coverage | expected to be effectively `100%` | `55988/55988 = 100%` | Pass | [innovus.log13](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/innovus.log13) |

## Energy Calculation

The EE energy is computed from the accelerator-only post-layout power and the first-chunk latency:

```text
Energy = Power x Time
       = 0.02576 mW x 17.499300 us
       = 0.4508 nJ
```

Unit note:

- `1 mW x 1 us = 1 nJ`

## Power Breakdown To Report

From [report_power_postRouteVCD.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_power_postRouteVCD.rpt):

- total chip power = `0.22997921 mW`
- accelerator power = `0.02576 mW`
- `accel/fft` power = `0.009273 mW`
- `accel/mem` power = `0.005526 mW`
- `soc/cpu` power = `0.1525 mW`

These are the main hierarchy numbers worth reusing in the report appendix.

## Important Power Flow Notes

The course expects final EE power from the VCD-based post-layout flow:

- VCD scripts updated:
  - [run_vcd_setup.cmd](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_phys/scripts/run_vcd_setup.cmd)
  - [run_vcd_hold.cmd](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_phys/scripts/run_vcd_hold.cmd)
- both now use:
  - start time `36.181386 ms`
  - runtime `17.499300 us`
- generated VCDs:
  - [et4351.phys.setup.vcd](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_phys/vcd/et4351.phys.setup.vcd)
  - [et4351.phys.hold.vcd](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_phys/vcd/et4351.phys.hold.vcd)
- final VCD-based power report:
  - [report_power_postRouteVCD.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_power_postRouteVCD.rpt)

One small reporting quirk:

- the header of [report_power_postRouteVCD.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/finalReports/report_power_postRouteVCD.rpt) still prints `Design annotation coverage: 0/55988 = 0%`
- the actual power-import run log shows the real coverage after VCD read and propagation:
  - `Total annotation coverage for all files of type VCD: 55988/55988 = 100%`
  - `Total Nets : 55988/55988 = 100%`
- those lines are in [innovus.log13](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/innovus.log13)

Also note:

- `9` VCD net names were not found in the design, but overall annotation still reached `100%`
- see [voltus_power_missing_netnames.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/voltus_power_missing_netnames.rpt)

## Final Clean Signoff Set

The clean implementation and export files to keep are:

- [et4351_done.enc](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/checkpoints/et4351_done.enc)
- [et4351.phys.v](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/outputs/et4351.phys.v)
- [et4351.phys.sdf](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/outputs/et4351.phys.sdf)

These are the physical outputs that were re-exported from the cleaned checkpoint and revalidated in post-layout simulation.

## Submission Checklist For This EE Tree

For the EE hand-in, you now already have:

- clean RTL / scripts in the project tree
- clean signoff reports
- clean physical netlist and SDF
- VCD-based post-layout power report
- computed EE power and energy

You still need to package them into the required submission structure:

- `finaldesign_ee/`
  - `accel_audio.hex`
  - `et4351.phys.sdf`
  - `et4351.phys.v`
- the report PDF
- all signoff reports in the zip
- activity annotation / power reports in the zip
- screenshots or excerpts of these reports in the appendix

## Bottom Line

For the current `EE` version in this tree:

- implementation is signoff-clean
- post-layout simulation passes
- annotation coverage is `100%`
- accelerator power is `0.02576 mW`
- accelerator energy is `0.4508 nJ`
- the EE target is met against the baseline `24.6 nJ`
