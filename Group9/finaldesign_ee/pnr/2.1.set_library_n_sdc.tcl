
##########################################################################
###
### Place-and-route scripts - multi-mode multi-corner (MMMC) setup.
###
###     TU Delft ET4351
###     March 2023, C. Frenkel
###     (part of this script was adapted from place-and-route scripts developed at UCLouvain, Belgium)
###
##########################################################################


# ##############
# # LIB files ##
# ##############

create_library_set -name library_typ -timing $LIB_FILES_TYP
create_library_set -name library_max -timing $LIB_FILES_MAX
create_library_set -name library_min -timing $LIB_FILES_MIN

# ##############
# # CAPTABLES ##
# ##############

create_rc_corner -name rc -qx_tech_file $QRC


# ################
# # Constraints ##
# ################

create_constraint_mode -name constraint_mode -sdc_files [list $DESIGN_PATH/$DESIGN.struct.sdc]


# ##################
# # Delay corners ##
# ##################

create_delay_corner -name delay_typ -library_set library_typ -rc_corner rc
create_delay_corner -name delay_max -library_set library_max -rc_corner rc
create_delay_corner -name delay_min -library_set library_min -rc_corner rc


# ###################
# # Analysis views ##
# ###################

create_analysis_view -name analysis_view_power -constraint_mode constraint_mode -delay_corner delay_typ
create_analysis_view -name analysis_view_setup -constraint_mode constraint_mode -delay_corner delay_max
create_analysis_view -name analysis_view_hold  -constraint_mode constraint_mode -delay_corner delay_min

set_analysis_view -setup {analysis_view_setup analysis_view_power} -hold {analysis_view_hold analysis_view_power}

# Async reset/set pins: removal/recovery hold checks are not meaningful
# since resetn is asserted asynchronously and held for many cycles.
# Applied here (not in SDC) because Genus does not support -hold on set_false_path.
set_interactive_constraint_modes [all_constraint_modes -active]
set_false_path -hold -to [get_pins -hierarchical */RN]
set_false_path -hold -to [get_pins -hierarchical */SN]

# Manual ICG clock gating: fft_clk and mem_clk are derived from clk via TLATNCAX2.
# Cross-domain paths (clk CSR regs <-> fft_clk/mem_clk FFT/mem regs) carry only
# slow control signals (enable_accel, reset_accel, finished_accel) — false path.
set_false_path -from [get_clocks clk] -to [get_pins -hierarchical accel/fft_icg/ECK]
set_false_path -from [get_clocks clk] -to [get_pins -hierarchical accel/mem_icg/ECK]
set_false_path -from [get_pins -hierarchical accel/fft_icg/ECK] -to [get_clocks clk]
set_false_path -from [get_pins -hierarchical accel/mem_icg/ECK] -to [get_clocks clk]
