##########################################################################
###
### Inspect route objects around the remaining iter8 short.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc.dat ${DESIGN}

set fp [open "inspect_iter8_area.txt" w]
set area {243.66 252.16 243.705 252.29}
puts $fp "AREA=$area"
puts $fp "QUERY_ALL=[dbQuery -area $area -objType regular]"
puts $fp "QUERY_VIAINST=[dbQuery -area $area -objType viaInst]"
puts $fp "QUERY_INST=[dbQuery -area $area -objType inst]"
puts $fp "QUERY_SNET=[dbQuery -area $area -objType sWire]"
puts $fp "QUERY_NET=[dbQuery -area $area -objType net]"
close $fp

exit
