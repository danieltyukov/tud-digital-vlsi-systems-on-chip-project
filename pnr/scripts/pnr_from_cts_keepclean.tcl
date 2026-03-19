##########################################################################
###
### Restore CTS checkpoint, keep first routed state, then verify/report/export.
###
##########################################################################

source ./scripts/1.set_variable.tcl

restoreDesign checkpoints/${DESIGN}_cts.enc.dat ${DESIGN}

source ./scripts/7.route_keepclean.tcl
source ./scripts/8.verify.tcl
source ./scripts/9.report.tcl
source ./scripts/10.export.tcl
