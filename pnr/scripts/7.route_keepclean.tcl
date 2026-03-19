##########################################################################
###
### Place-and-route scripts - routing, keeping the first clean routed state.
###
##########################################################################

Puts ""
Puts ""
Puts ""
Puts " ##############################################################    "
Puts " ##                                                                "
Puts " ##                    ROUTE (KEEP CLEAN)                          "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""

setFillerMode -core {FILL1 FILL2 FILL4 FILL8 FILL16 FILL32 FILL64} -corePrefix FILLER_ -doDRC true -ecoMode true

addFiller
checkFiller

setNanoRouteMode -quiet -routeWithTimingDriven 1
setNanoRouteMode -quiet -routeTdrEffort 5
setNanoRouteMode -quiet -routeBottomRoutingLayer default
setNanoRouteMode -quiet -drouteEndIteration 30
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
setNanoRouteMode -quiet -routeSiEffort high
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeFixTopLayerAntenna false
setNanoRouteMode -routeInsertAntennaDiode true
setNanoRouteMode -routeAntennaCellName "ANTENNA"

# Keep the first routed state, which is hold-clean for the local clock-gated variant.
routeDesign -globalDetail

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/route
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/route_hold

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/route_keepclean.rpt

checkRoute
reportRoute

deleteRouteBlk -all

Puts " \n\n save Design \n\n"

saveDesign checkpoints/${DESIGN}_route_keepclean.enc

fit
