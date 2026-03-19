##########################################################################
###
### Hold-only recovery from the clock-gated DRV-repaired checkpoint.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_drv_iter1.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

# Preserve the DRV cleanup and only target the small residual hold regression.
setOptMode -fixCap false -fixTran false -fixFanoutLoad false -postRouteHoldRecovery auto
optDesign -postRoute -hold

file mkdir finalReports_cg_drv_hold_iter2
file mkdir finalReports_cg_drv_hold_iter2/report_timing
file mkdir finalReports_cg_drv_hold_iter2/report_timing_hold
file mkdir finalReports_cg_drv_hold_iter2/report_DRV

report_power -hierarchy all -outfile finalReports_cg_drv_hold_iter2/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_drv_hold_iter2/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_drv_hold_iter2/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_drv_hold_iter2/report_DRV

saveDesign checkpoints/${DESIGN}_cg_drv_hold_iter2.enc
saveNetlist outputs/${DESIGN}.phys_cg_drv_hold_iter2.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_drv_hold_iter2.sdf

exit
