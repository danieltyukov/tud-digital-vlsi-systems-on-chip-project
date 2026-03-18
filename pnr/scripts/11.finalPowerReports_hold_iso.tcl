##########################################################################
###
### Power report script using the isolated completed hold-corner VCD.
###
##########################################################################

source ./scripts/1.set_variable.tcl
restoreDesign ./checkpoints/et4351_done.enc.dat et4351
setDrawView place
fit

set_power_analysis_mode -report_missing_nets true -corner delay_typ -analysis_view analysis_view_power
read_activity_file ../sim_phys_hold_power_iso_20260318_1/vcd/${DESIGN}.phys.hold.vcd -reset -format VCD -scope testbench/dut
propagate_activity

report_power -hierarchy all -outfile finalReports/report_power_postRouteVCD_iso_hold.rpt
