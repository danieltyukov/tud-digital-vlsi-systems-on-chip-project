##########################################################################
###
### Verify physical signoff status for cg_manual_hold_route_legal_iter6.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter6.enc.dat ${DESIGN}
setDrawView place
fit

file mkdir verifyReports_cg_manual_hold_route_legal_iter6

verifyConnectivity -type all -error 1000 -warning 50 -report verifyReports_cg_manual_hold_route_legal_iter6/verifyConnectivity.rpt
verify_drc -limit 1000 -report verifyReports_cg_manual_hold_route_legal_iter6/verify_drc.rpt
verifyProcessAntenna -error 1000 -reportfile verifyReports_cg_manual_hold_route_legal_iter6/verifyProcessAntenna.rpt

exit
