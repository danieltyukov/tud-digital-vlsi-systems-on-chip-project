##########################################################################
###
### Export the clean clock-gated iter11 checkpoint as the final design.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_fix_n494_from_drv_iter11.enc.dat ${DESIGN}
setDrawView place
fit

source ./scripts/10.export.tcl

exit
