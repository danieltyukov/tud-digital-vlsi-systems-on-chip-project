##########################################################################
###
### Fresh rebuild from cg_drv_iter1 plus local n_494 perturbation.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_drv_iter1.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

setEcoMode -batchMode true -refinePlace true -updateTiming false
ecoChangeCell -inst soc/cpu/FE_PHC12280_n_2025 -cell DLY2X1
ecoChangeCell -inst soc/cpu/FE_PHC11129_iomem_addr_14 -cell DLY2X1
ecoChangeCell -inst soc/spimemio/FE_PHC10756_xfer_resetn -cell DLY3X1
ecoChangeCell -inst soc/cpu/FE_OFC1177_n_495 -cell INVX2
setEcoMode -batchMode false -refinePlace true -updateTiming true

setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -routeWithSiDriven false
setNanoRouteMode -routeSiEffort low
setNanoRouteMode -routeTdrEffort 1
ecoRoute

file mkdir finalReports_cg_fix_n494_from_drv_iter11
file mkdir finalReports_cg_fix_n494_from_drv_iter11/report_timing
file mkdir finalReports_cg_fix_n494_from_drv_iter11/report_timing_hold
file mkdir finalReports_cg_fix_n494_from_drv_iter11/report_DRV
file mkdir finalReports_cg_fix_n494_from_drv_iter11/verifyReports

clearDrc
verifyConnectivity -type all -error 1000 -warning 50 -report finalReports_cg_fix_n494_from_drv_iter11/verifyReports/verifyConnectivity.rpt
verify_drc -limit 1000 -report finalReports_cg_fix_n494_from_drv_iter11/verifyReports/verify_drc.rpt
verifyProcessAntenna -error 1000 -reportfile finalReports_cg_fix_n494_from_drv_iter11/verifyReports/verifyProcessAntenna.rpt

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_fix_n494_from_drv_iter11/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_fix_n494_from_drv_iter11/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_fix_n494_from_drv_iter11/report_DRV

saveDesign checkpoints/${DESIGN}_cg_fix_n494_from_drv_iter11.enc
saveNetlist outputs/${DESIGN}.phys_cg_fix_n494_from_drv_iter11.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_fix_n494_from_drv_iter11.sdf

exit
