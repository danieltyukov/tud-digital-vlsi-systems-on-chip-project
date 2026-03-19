##########################################################################
###
### Dump the wire geometry near the remaining iter8 short.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc.dat ${DESIGN}

set area {243.66 252.16 243.705 252.29}
set fp [open "inspect_iter8_wires.txt" w]

foreach obj [dbQuery -area $area -objType regular] {
  puts $fp "WIRE_PTR=$obj TYPE=[dbObjType $obj] NET=[dbGet $obj.net.name] LAYER=[dbGet $obj.layer.name] BOX=[dbGet $obj.box]"
}
foreach obj [dbQuery -area $area -objType sWire] {
  puts $fp "SWIRE_PTR=$obj NET=[dbGet $obj.net.name] LAYER=[dbGet $obj.layer.name] BOX=[dbGet $obj.box]"
}

close $fp
exit
