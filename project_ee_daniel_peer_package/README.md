This folder is a peer-share package for the final clean `project_ee_daniel_check` version.

Included:
- final RTL, firmware, SDC, and flow scripts
- synthesis outputs
- final PNR outputs: `et4351.phys.v`, `et4351.phys.sdf`, `et4351.phys.gds`
- final signoff and power reports
- behavioral, structural, and physical simulation transcripts/results
- summary markdown files

Left out on purpose:
- large work libraries
- PNR checkpoints
- debug-only TCL scripts used during violation cleanup
- extra old/intermediate verify reports

Important files:
- `HANDIN_METRICS_SUMMARY.md`
- `VIOLATIONS_SUMMARY.md`
- `pnr/finalReports/report_power_postRouteVCD.rpt`
- `pnr/verifyReports/verifyConnectivity.rpt`
- `pnr/verifyReports/verify_drc.rpt`
- `pnr/verifyReports/verifyProcessAntenna.rpt`
- `pnr/outputs/et4351.phys.v`
- `pnr/outputs/et4351.phys.sdf`

This package is meant for review/sharing. The full working project with all checkpoints and intermediate artifacts is still in `~/project_ee_daniel_check`.
