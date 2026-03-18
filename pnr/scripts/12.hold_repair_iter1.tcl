##########################################################################
###
### Focused post-route hold repair pass from the exported checkpoint.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/et4351_done.enc.dat et4351
setDrawView place
fit

setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto
optDesign -postRoute -hold
optDesign -postRoute -drv

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_holdfix1/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_holdfix1/report_timing_hold

saveNetlist outputs/${DESIGN}.phys_holdfix1.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/${DESIGN}.phys_holdfix1.sdf
saveDesign checkpoints/${DESIGN}_done_holdfix1.enc
