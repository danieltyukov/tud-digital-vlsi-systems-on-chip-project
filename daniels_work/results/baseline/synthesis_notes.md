# Baseline Synthesis Notes

## Date: 2026-03-18
## Status: Running

### SDC Warnings (Expected)
- `SDC-204`: Invalid SDC command for `accel_o_path_node` / `accel_o_path_node_valid` ports
  - These ports are defined in the SDC but may not exist in the baseline RTL
  - **Not a problem** — these are output delay constraints for ports the baseline doesn't use
- `CHNM-110`: Failed to change names — cosmetic, doesn't affect synthesis quality
- `RTLOPT-54`: `parallel_case` pragma warnings — the PicoRV32 uses these for FSM encoding

### Synthesis Settings
- **Library**: `gsclib045_svt_v4.7` (SVT only, slow corner `slow_vdd1v0`)
- **SRAM**: `saed32sram_ss0p95vn40c` (slow corner)
- **Clock period**: 83.33 ns (12 MHz)
- **Clock uncertainty**: 0.25 ns
- **Max CPUs**: 4

### Key Observations
- Resource sharing detected and applied by Genus
- Datapath macros transformed for optimization
