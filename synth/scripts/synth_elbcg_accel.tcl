##########################################################################
###
### Synthesis scripts - elaboration with accelerator-local clock gating.
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

read_hdl -v2001 "${INPUT_PATH}/design/${DESIGN}.v"
read_hdl -v2001 "${INPUT_PATH}/design/accelerator.v"
read_hdl -sv    "${INPUT_PATH}/design/accelerator_fft.v"
read_hdl -v2001 "${INPUT_PATH}/design/accelerator_mem.v"
read_hdl -v2001 "${INPUT_PATH}/design/picosoc.v"
read_hdl -v2001 "${INPUT_PATH}/design/spimemio.v"
read_hdl -v2001 "${INPUT_PATH}/design/simpleuart.v"
read_hdl -v2001 "${INPUT_PATH}/design/picorv32.v"

set_attribute hdl_error_on_latch true /
set_attribute auto_ungroup none /

elaborate $DESIGN
timestat Elaboration

####################################################################
## Constraints and implementation parameters setup
####################################################################

read_sdc "${INPUT_PATH}/sdc/${DESIGN}.sdc"

change_names -restricted "\[ \]" -replace_str "_"

set_attribute number_of_routing_layers 8 /designs/*

####################################################################
## Accelerator-local clock gating
####################################################################

set accel_scope /designs/et4351/subdesigns/accelerator
set fft_scope /designs/et4351/subdesigns/accelerator_fft_LOG_MAX_N32_MEM_WIDTH32_ADDR_WIDTH7

set_attribute lp_insert_clock_gating true $accel_scope
set_attribute lp_insert_clock_gating true $fft_scope
set_attribute lp_clock_gating_control_point precontrol $accel_scope
set_attribute lp_clock_gating_control_point precontrol $fft_scope
set_attribute lp_clock_gating_style latch $accel_scope
set_attribute lp_clock_gating_style latch $fft_scope
set_attribute lp_insert_discrete_clock_gating_logic true /

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
