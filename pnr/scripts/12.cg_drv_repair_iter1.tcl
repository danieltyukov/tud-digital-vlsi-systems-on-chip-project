##########################################################################
###
### Focused post-route DRV repair from the clock-gated keep-clean route.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_route_keepclean.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

# Use a narrow ECO objective: fix electrical issues while starting from the
# routed state that is already setup/hold clean.
setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto
optDesign -postRoute -drv

file mkdir finalReports_cg_drv_iter1
file mkdir finalReports_cg_drv_iter1/report_timing
file mkdir finalReports_cg_drv_iter1/report_timing_hold
file mkdir finalReports_cg_drv_iter1/report_DRV

report_power -hierarchy all -outfile finalReports_cg_drv_iter1/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_drv_iter1/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_drv_iter1/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_drv_iter1/report_DRV

saveDesign checkpoints/${DESIGN}_cg_drv_iter1.enc
saveNetlist outputs/${DESIGN}.phys_cg_drv_iter1.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_drv_iter1.sdf

exit
