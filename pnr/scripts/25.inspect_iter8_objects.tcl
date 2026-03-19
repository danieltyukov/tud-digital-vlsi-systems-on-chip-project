##########################################################################
###
### Dump object identities in the remaining iter8 short box.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc.dat ${DESIGN}

set area {243.66 252.16 243.705 252.29}
set fp [open "inspect_iter8_objects.txt" w]

foreach obj [dbQuery -area $area -objType regular] {
  puts $fp "REGULAR_PTR=$obj OBJTYPE=[dbObjType $obj]"
}
foreach obj [dbQuery -area $area -objType inst] {
  puts $fp "INST_PTR=$obj NAME=[dbGet $obj.name] CELL=[dbGet $obj.cell.name]"
}
foreach obj [dbQuery -area $area -objType viaInst] {
  puts $fp "VIA_PTR=$obj NAME=[dbGet $obj.name] VIA=[dbGet $obj.via.name]"
}
foreach obj [dbQuery -area $area -objType sWire] {
  puts $fp "SWIRE_PTR=$obj NET=[dbGet $obj.net.name] BOX=[dbGet $obj.box]"
}
foreach obj [dbQuery -area $area -objType net] {
  puts $fp "NET_PTR=$obj NAME=[dbGet $obj.name]"
}

close $fp
exit
