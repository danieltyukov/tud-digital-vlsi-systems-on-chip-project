
##########################################################################
###
### Synthesis scripts - elaboration.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


puts ""
puts ""
puts " ##################################"
puts " #                                #"
puts " #    ELABORATION                 #"
puts " #                                #"
puts " ##################################"
puts ""
puts ""


####################################################################
## Load Design
####################################################################

# Source design HDL
read_hdl -v2001 "${INPUT_PATH}/design/${DESIGN}.v"
read_hdl -v2001 "${INPUT_PATH}/design/accelerator.v"
read_hdl -sv    "${INPUT_PATH}/design/accelerator_fft.v"
read_hdl -v2001 "${INPUT_PATH}/design/accelerator_mem.v"
read_hdl -v2001 "${INPUT_PATH}/design/picosoc.v"
read_hdl -v2001 "${INPUT_PATH}/design/spimemio.v"
read_hdl -v2001 "${INPUT_PATH}/design/simpleuart.v"
read_hdl -v2001 "${INPUT_PATH}/design/picorv32.v"

# Issue an error on latch inference
set_attribute hdl_error_on_latch true /

# No automatically ungroup of any hierarchy during the synthesis process (Good for debug but turn it off for better results)
set_attribute auto_ungroup none /

# Elaborate design
elaborate $DESIGN
timestat Elaboration

set_attr preserve true [get_nets soc/*]
set_attr preserve true [get_nets soc/cpu/*]
set_attr preserve true [get_nets soc/simpleuart/*]
set_attr preserve true [get_nets soc/spimemio/*]
set_attr preserve true [get_nets soc/memory/*]
set_attr preserve true [get_nets soc/cpu/mem_done]

####################################################################
## Constraints and implementation parameters setup
####################################################################

read_sdc "${INPUT_PATH}/sdc/${DESIGN}.sdc"

change_names -restricted "\[ \]" -replace_str "_"

# Number of routing layers
set_attribute number_of_routing_layers 8 /designs/*

# Clock gating options — set AFTER elaborate so all submodule objects exist.
# Disable CG on ALL designs first, then enable only on the accelerator modules.
# This must be done post-elaborate because submodules like picorv32_pcpi_div,
# spimemio_xfer etc. are separate Genus design objects that don't exist before
# elaboration, so a pre-elaborate "false /" does not cover them.
set_attribute lp_clock_gating_control_point precontrol /des*/*
set_attribute lp_clock_gating_style latch /des*/*
set_attribute lp_insert_discrete_clock_gating_logic true

# Disable CG on all designs using /designs/* glob (works in Genus legacy_ui),
# then re-enable only on the accelerator modules using find.
set_attribute lp_insert_clock_gating false /designs/*
set_attribute lp_insert_clock_gating true  [find /designs -design accelerator]
set_attribute lp_insert_clock_gating true  [find /designs -design "accelerator_fft*"]


####################################################################
## Generic synthesis
####################################################################

syn_generic
timestat GENERIC


####################################################################
## Generate reports
####################################################################

set IMPL_STAGE "elb"

if {![file exists ${REPORTS_PATH}/${IMPL_STAGE}]} {
  file mkdir ${REPORTS_PATH}/${IMPL_STAGE}
  puts "Creating directory ${REPORTS_PATH}/${IMPL_STAGE}"
}

report timing -lint -verbose       > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_lint.rpt
report clocks                      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_clocks.rpt
report clocks -generated           > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_clocksg.rpt
report port *                      > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_port.rpt
find / -instance cdn_loop_breaker*
report cdn_loop_breaker            > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_loopbreaks.rpt
check_design -all                  > ${REPORTS_PATH}/${IMPL_STAGE}/${DESIGN}_precheck.rpt
