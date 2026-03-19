set DESIGN et4351

restoreDesign checkpoints/${DESIGN}_done.enc.dat ${DESIGN}

setMultiCpuUsage -localCpu 4

setAnalysisMode -analysisType onChipVariation -cppr both

optDesign -postRoute -drv

file mkdir finalReports_drvfix1
file mkdir finalReports_drvfix1/report_timing
file mkdir finalReports_drvfix1/report_timing_hold

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir finalReports_drvfix1/report_timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports_drvfix1/report_timing_hold

report_power > finalReports_drvfix1/report_power.rpt

saveDesign checkpoints/${DESIGN}_done_drvfix1.enc

saveNetlist outputs/${DESIGN}.phys_drvfix1.v
write_sdf outputs/${DESIGN}.phys_drvfix1.sdf

exit
