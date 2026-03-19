##########################################################################
###
### Surgical hold ECO from the clock-gated DRV-repaired checkpoint.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_drv_iter1.enc.dat ${DESIGN}
setDrawView place
fit

setMultiCpuUsage -localCpu 4
setAnalysisMode -analysisType onChipVariation -cppr both

# Manual cell swaps on the small set of failing data/reset paths.
setEcoMode -batchMode true -refinePlace false -updateTiming false
ecoChangeCell -inst soc/cpu/FE_PHC12280_n_2025 -cell DLY4X1
ecoChangeCell -inst soc/cpu/FE_PHC11129_iomem_addr_14 -cell DLY2X1
ecoChangeCell -inst soc/spimemio/FE_PHC10756_xfer_resetn -cell DLY4X1
setEcoMode -batchMode false -refinePlace false -updateTiming true

ecoRoute

file mkdir finalReports_cg_manual_hold_iter3
file mkdir finalReports_cg_manual_hold_iter3/report_timing
file mkdir finalReports_cg_manual_hold_iter3/report_timing_hold
file mkdir finalReports_cg_manual_hold_iter3/report_DRV

report_power -hierarchy all -outfile finalReports_cg_manual_hold_iter3/report_power.rpt
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_manual_hold_iter3/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_cg_manual_hold_iter3/report_timing_hold
timeDesign -postRoute -drvReports -numPaths 500 -outDir finalReports_cg_manual_hold_iter3/report_DRV

saveDesign checkpoints/${DESIGN}_cg_manual_hold_iter3.enc
saveNetlist outputs/${DESIGN}.phys_cg_manual_hold_iter3.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_cg_manual_hold_iter3.sdf

exit
