
##########################################################################
###
### Place-and-route scripts - routing.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


Puts ""
Puts ""
Puts ""
Puts " ##############################################################    "
Puts " ##                                                                "
Puts " ##                        ROUTE                                   "
Puts " ##                                                                "
Puts " ##############################################################    "
Puts ""
Puts ""
Puts ""


# ####################
# Filler configuration and inclusion
# ####################

setFillerMode -core {FILL1 FILL2 FILL4 FILL8 FILL16 FILL32 FILL64} -corePrefix FILLER_ -doDRC true -ecoMode true

addFiller
checkFiller

# ####################
# Nano route parameters
# ####################

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
setOptMode       -postRouteDrvRecovery true -fixSISlew true -fixGlitch true

#Reduce effort level as there are only captables
setExtractRCMode -engine postRoute -effortLevel high

routeDesign -globalDetail

# ####################
# Post-route pre-opt reports
# ####################

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/route
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/route_hold

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/route.rpt


# ####################
# Post-route optimization
# ####################

setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto
optDesign -postRoute

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/postRoute
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/postRoute_hold

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/postRoute.rpt


# ####################
# Post-route hold optimization
# ####################

setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto
optDesign -postRoute -hold

# ####################
# Targeted ECO antenna fix
# ####################

# CTS leaves one antenna violation on the reset synchronizer clock sink.
# Isolate that sink with a legal post-route clock buffer placed in nearby filler space.
setEcoMode -honorFixedNetWire false -refinePlace false -updateTiming false
ecoAddRepeater -term {resetn_sync_int_reg/CK} -cell CLKBUFX12 -loc {604.6 279.0} -name CTS5_FIXBUF12 -newNetName CTS5_FIXNET12
ecoRoute
setEcoMode -refinePlace true -updateTiming true

# Clean up the small slew disturbance introduced by the targeted ECO so the
# final signoff state stays DRV-clean instead of only antenna-clean.
setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto
setOptMode -postRouteDrvRecovery true -fixSISlew true -fixGlitch true
optDesign -postRoute

timeDesign -postRoute -pathReports -slackReports -numPaths 50 -outDir timingReports/postRouteHold
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir timingReports/postRouteHold_hold
report_noise -bumpy_waveform -output_file timingReports/bumpyWaves_postRouteHold.rpt 

set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power

report_power -clock_network all -hierarchy all -cell_type all -power_domain all -pg_net all -sort { total } -outfile powerReports/postRouteHold.rpt


# ####################
# # Verify and Save
# ####################

checkRoute
reportRoute

deleteRouteBlk -all

Puts " \n\n save Design \n\n"

saveDesign checkpoints/${DESIGN}_route.enc

fit
