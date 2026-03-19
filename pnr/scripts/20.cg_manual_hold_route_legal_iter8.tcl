##########################################################################
###
### Surgical hold ECO with reduced mem_rdata delay to clear the last DRC.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_drv_iter1.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

setEcoMode -batchMode true -refinePlace false -updateTiming false
ecoChangeCell -inst soc/cpu/FE_PHC12280_n_2025 -cell DLY2X1
ecoChangeCell -inst soc/cpu/FE_PHC11129_iomem_addr_14 -cell DLY2X1
ecoChangeCell -inst soc/spimemio/FE_PHC10756_xfer_resetn -cell DLY3X1
setEcoMode -batchMode false -refinePlace false -updateTiming true

setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeSiEffort low
setNanoRouteMode -routeTdrEffort 1
ecoRoute

file mkdir finalReports_cg_manual_hold_route_legal_iter8
file mkdir finalReports_cg_manual_hold_route_legal_iter8/report_timing
file mkdir finalReports_cg_manual_hold_route_legal_iter8/report_timing_hold
file mkdir finalReports_cg_manual_hold_route_legal_iter8/report_DRV

report_power -hierarchy all -outfile finalReports_cg_manual_hold_route_legal_iter8/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_manual_hold_route_legal_iter8/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_manual_hold_route_legal_iter8/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_manual_hold_route_legal_iter8/report_DRV

saveDesign checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc
saveNetlist outputs/${DESIGN}.phys_cg_manual_hold_route_legal_iter8.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_manual_hold_route_legal_iter8.sdf

exit
