# Violation Summary for `project_ee_daniel_check`

Date: 2026-04-07

This note summarizes the final status of the merged Daniel EE design after the full ET4351 flow completed successfully.

## Overall conclusion

The full flow completed successfully:

- Behavioral simulation: passed
- Structural simulation: passed
- Physical simulation: passed

However, the final physical design is **not fully signoff-clean** because there are still **post-route `max_tran` violations**.

So the correct summary is:

- Functional flow: **PASS**
- Final implementation cleanliness: **NOT FULLY CLEAN**

## Final status by category

| Category | Final status | Evidence |
| --- | --- | --- |
| Behavioral functionality | PASS | `sim_behav` verification passed |
| Structural functionality | PASS | `sim_struct` verification passed |
| Physical functionality | PASS | `sim_phys` verification passed |
| Setup timing | PASS | WNS `34.317 ns`, TNS `0.000`, violating paths `0` |
| Hold timing | PASS | WNS `0.049 ns`, TNS `0.000`, violating paths `0` |
| Max capacitance | PASS | `0` violations |
| Max fanout | PASS | `0` violations |
| Max length | PASS | `0` violations |
| Max transition | FAIL | `198` real violating nets / `509` terms, worst violation `-0.481` |
| Placement legality | PASS | `checkPlace`: no violations found |
| Connectivity | PASS | `verifyConnectivity`: no problems or warnings |
| DRC | PASS | `verify_drc`: no violations |
| Antenna | PASS | `verifyProcessAntenna`: no violations |
| Floorplan quality checks | WARN | grid / halo / SRAM snap warnings remain |

## Key final reports

### 1. Final post-route setup timing

Source:
- [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/et4351_postRoute.summary.gz)
- [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/postRoute/et4351_postRoute.summary.gz)

Final setup summary:

- WNS: `34.317 ns`
- TNS: `0.000 ns`
- Violating paths: `0`

Interpretation:

- Setup timing is clean.

### 2. Final post-route hold timing

Source:
- [et4351_postRoute_hold.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/et4351_postRoute_hold.summary.gz)
- [et4351_postRoute_hold.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/postRoute_hold/et4351_postRoute_hold.summary.gz)

Final hold summary:

- WNS: `0.049 ns`
- TNS: `0.000 ns`
- Violating paths: `0`

Interpretation:

- Hold timing is clean, although the slack margin is much smaller than setup.

### 3. Final post-route DRV summary

Source:
- [et4351_postRoute.summary.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/et4351_postRoute.summary.gz)
- [et4351_postRoute.tran.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/et4351_postRoute.tran.gz)
- [innovus.log](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/innovus.log)

Final DRV status:

- `max_cap`: `0`
- `max_fanout`: `0`
- `max_length`: `0`
- `max_tran`: `198` real violating nets / `509` terms
- Worst `max_tran` violation: `-0.481`

Interpretation:

- This is the main remaining implementation problem.
- Because `max_tran` is still violated, the design is not fully DRV-clean.

## Detailed remaining issue: `max_tran`

The worst remaining transition violations appear in:

- `flash_io0`
- `flash_io1`
- `flash_io2`
- `flash_io3`
- a large number of internal CPU nets

Source:
- [et4351_postRoute.tran.gz](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/timingReports/et4351_postRoute.tran.gz)

The report shows examples such as:

- `flash_io0` transition up to about `1.580 ns` against a `0.280 ns` limit
- `flash_io3` transition up to about `1.548 ns` against a `0.280 ns` limit

Interpretation:

- The design is functionally working, but some nets still switch too slowly.
- This usually points to buffering, drive strength, clocking, routing, or constraint issues that need to be fixed back in PNR or RTL, not in physical simulation.

## Floorplan warnings

Source:
- [checkFPlan.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/checkFPlan.rpt)

Warnings still present:

- DIE corner is not on placement grid
- CORE corner is not on placement grid
- halo should be created around each SRAM macro
- SRAM instances `sram_0` to `sram_3` are not snapped to row-site

Interpretation:

- These are floorplan-quality warnings, not the reason the flow failed to sign off.
- They usually require TCL/floorplan script cleanup rather than later-stage simulation.

## Clean physical verification reports

### Placement

Source:
- [checkPlace.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/checkPlace.rpt)

Result:

- No violations found

### Connectivity

Source:
- [verifyConnectivity.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/verifyConnectivity.rpt)

Result:

- No problems or warnings

### DRC

Source:
- [verify_drc.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/verify_drc.rpt)

Result:

- No DRC violations found

### Antenna

Source:
- [verifyProcessAntenna.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/verifyProcessAntenna.rpt)

Result:

- No violations found

## Timing-check warnings during CTS

Source:
- [cts_check_timing.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/verifyReports/cts_check_timing.rpt)

Warnings reported there:

- `ideal_clock_waveform`: `4`
- `no_input_delay`: `4`
- `uncons_endpoint`: `32`

Interpretation:

- These are analysis/constraint warnings, not final post-route signoff violations.
- They are still worth cleaning up because they suggest some pins and endpoints are not fully constrained.

## Power-analysis net-name warning

Source:
- [voltus_power_missing_netnames.rpt](/home/nfs/rlongomalinski/project_ee_daniel_check/pnr/voltus_power_missing_netnames.rpt)

Reported issue:

- `12` nets appeared in the VCD but were not found in the design database

Examples:

- `flash_io0_di`
- `flash_io1_di`
- `flash_io2_di`
- `flash_io3_di`
- SRAM control nets such as `soc/memory/sram_0/OEB`, `soc/memory/sram_0/CSB`

Interpretation:

- This matters for power accounting accuracy.
- It does not mean the chip is functionally broken.

## Physical simulation warnings

Source:
- [transcript](/home/nfs/rlongomalinski/project_ee_daniel_check/sim_phys/transcript)

Warnings observed:

- "Too few port connections" / "Missing connection for port" warnings on some modules in the generated physical netlist
- many SDF timing-check warnings where negative check limits were clamped to zero

Interpretation:

- These warnings did not stop simulation.
- Physical simulation still passed and matched the golden outputs.
- They should be treated as warning-level issues, not as proof of functional failure.

## Final practical takeaway

This design is in a good state for:

- running the complete flow
- producing correct outputs
- continuing functional work

This design is **not yet in a good state for final clean signoff** because:

- post-route `max_tran` is still violated

So if you need the strict ET4351 "clean final design" standard, the next fix target should be:

1. remove the remaining `max_tran` violations
2. then re-check post-route timing and DRV
3. optionally clean up floorplan and constraint warnings afterward
