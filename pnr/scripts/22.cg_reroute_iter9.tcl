##########################################################################
###
### Re-run legalization-focused ecoRoute on iter8 to clear the last short.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeSiEffort low
setNanoRouteMode -routeTdrEffort 1
ecoRoute

file mkdir finalReports_cg_reroute_iter9
file mkdir finalReports_cg_reroute_iter9/report_timing
file mkdir finalReports_cg_reroute_iter9/report_timing_hold
file mkdir finalReports_cg_reroute_iter9/report_DRV

report_power -hierarchy all -outfile finalReports_cg_reroute_iter9/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_reroute_iter9/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_reroute_iter9/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_reroute_iter9/report_DRV

saveDesign checkpoints/${DESIGN}_cg_reroute_iter9.enc
saveNetlist outputs/${DESIGN}.phys_cg_reroute_iter9.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_reroute_iter9.sdf

exit
