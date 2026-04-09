##########################################################################
### Hold violation fix — restore from route checkpoint and re-optimize
### Run with: innovus -files ./scripts/fix_hold.tcl
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/et4351_route.enc.dat et4351
setDrawView place
fit

# Aggressive hold fixing — 3 passes at holdTargetSlack 0.3
setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto -holdTargetSlack 0.3
optDesign -postRoute -hold
optDesign -postRoute -hold
optDesign -postRoute -hold

# Report result
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports/report_timing_hold

# Also update setup timing report
timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports/report_timing

# Save updated checkpoint
saveDesign checkpoints/et4351_done.enc

exit
