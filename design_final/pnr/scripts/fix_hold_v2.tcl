##########################################################################
### Hold fix v2: false-path async reset/set pins, re-verify from done checkpoint
### Run with: innovus -files ./scripts/fix_hold_v2.tcl
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/et4351_done.enc.dat et4351
setDrawView place
fit

# Activate constraint mode before adding new constraints
set_interactive_constraint_modes [all_constraint_modes -active]

# Async reset/set pins are driven by the system resetn (asynchronous, held
# for many cycles). Hold/removal checks on these pins are not meaningful.
set_false_path -hold -to [get_pins -hierarchical */RN]
set_false_path -hold -to [get_pins -hierarchical */SN]

# Re-run hold opt to insert any remaining buffers on true data paths
setOptMode -fixCap true -fixTran true -fixFanoutLoad true -postRouteHoldRecovery auto -holdTargetSlack 0.2
optDesign -postRoute -hold

# Report final timing
timeDesign -postRoute -hold -pathReports -slackReports -numPaths 50 -outDir finalReports/report_timing_hold
timeDesign -postRoute        -pathReports -slackReports -numPaths 50 -outDir finalReports/report_timing

# Power
set_power_analysis_mode -method static -corner delay_typ -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true -analysis_view analysis_view_power
report_power -outfile finalReports/report_power.rpt

# Save updated checkpoint and re-export
saveDesign checkpoints/et4351_done.enc
saveNetlist outputs/et4351.phys.v
write_sdf -min_view analysis_view_hold -max_view analysis_view_setup -typ_view analysis_view_power -delimiter "/" outputs/et4351.phys.sdf

exit
