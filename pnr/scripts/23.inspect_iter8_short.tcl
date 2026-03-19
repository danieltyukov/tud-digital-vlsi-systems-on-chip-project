##########################################################################
###
### Inspect the remaining iter8 geometry short.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/${DESIGN}_cg_manual_hold_route_legal_iter8.enc.dat ${DESIGN}

set fp [open "inspect_iter8_short.txt" w]
puts $fp "NET_QUERY_BEGIN"
puts $fp "net_obj=[dbGet top.nets.name soc/cpu/n_494]"
puts $fp "marker_count=[llength [dbGet top.markers]]"
puts $fp "marker_boxes=[dbGet top.markers.box]"
puts $fp "marker_types=[dbGet top.markers.userType]"
puts $fp "marker_nets=[dbGet top.markers.net.name]"
close $fp

exit
