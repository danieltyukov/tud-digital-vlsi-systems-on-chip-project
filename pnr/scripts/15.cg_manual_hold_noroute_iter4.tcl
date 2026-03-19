##########################################################################
###
### Surgical hold ECO without ecoRoute from the clock-gated DRV checkpoint.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_drv_iter1.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

# Keep the write scope tiny and avoid route perturbation.
setEcoMode -batchMode true -refinePlace false -updateTiming false
ecoChangeCell -inst soc/cpu/FE_PHC12280_n_2025 -cell DLY3X1
ecoChangeCell -inst soc/cpu/FE_PHC11129_iomem_addr_14 -cell DLY2X1
ecoChangeCell -inst soc/cpu/FE_PHC11139_iomem_addr_11 -cell DLY2X1
ecoChangeCell -inst soc/spimemio/FE_PHC10756_xfer_resetn -cell DLY3X1
setEcoMode -batchMode false -refinePlace false -updateTiming true

file mkdir finalReports_cg_manual_hold_noroute_iter4
file mkdir finalReports_cg_manual_hold_noroute_iter4/report_timing
file mkdir finalReports_cg_manual_hold_noroute_iter4/report_timing_hold
file mkdir finalReports_cg_manual_hold_noroute_iter4/report_DRV

report_power -hierarchy all -outfile finalReports_cg_manual_hold_noroute_iter4/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_manual_hold_noroute_iter4/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_manual_hold_noroute_iter4/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_manual_hold_noroute_iter4/report_DRV

saveDesign checkpoints/${DESIGN}_cg_manual_hold_noroute_iter4.enc
saveNetlist outputs/${DESIGN}.phys_cg_manual_hold_noroute_iter4.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_manual_hold_noroute_iter4.sdf

exit
