##########################################################################
###
### Perturb n_494 source cell to clear the remaining short.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

setEcoMode -batchMode true -refinePlace true -updateTiming false
ecoChangeCell -inst soc/cpu/FE_OFC1177_n_495 -cell INVX2
setEcoMode -batchMode false -refinePlace true -updateTiming true

setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeSiEffort low
setNanoRouteMode -routeTdrEffort 1
ecoRoute

file mkdir finalReports_cg_fix_n494_iter10
file mkdir finalReports_cg_fix_n494_iter10/report_timing
file mkdir finalReports_cg_fix_n494_iter10/report_timing_hold
file mkdir finalReports_cg_fix_n494_iter10/report_DRV

report_power -hierarchy all -outfile finalReports_cg_fix_n494_iter10/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_fix_n494_iter10/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_fix_n494_iter10/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_fix_n494_iter10/report_DRV

saveDesign checkpoints/${DESIGN}_cg_fix_n494_iter10.enc
saveNetlist outputs/${DESIGN}.phys_cg_fix_n494_iter10.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_fix_n494_iter10.sdf

exit
