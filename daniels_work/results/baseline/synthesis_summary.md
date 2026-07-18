# Baseline Synthesis Results

## Date: 2026-03-18
## Tool: Cadence Genus 21.10

### Timing
| Clock | Period (ps) | WNS (ps) | TNS (ps) | Violating Paths |
|-------|-------------|----------|----------|-----------------|
| clk | 83,330 | 31,851 | 0.0 | 0 |
| flash_clk | 166,660 | 35,449 | 0.0 | 0 |

- Critical path slack: 31.85 ns (setup margin very comfortable)
- Critical path delay: ~51.5 ns
- Theoretical max frequency: ~19 MHz

### Area ($\mu m^2$)
| Module | Cell Area | Net Area | Total Area | % of SoC |
|--------|-----------|----------|------------|----------|
| **et4351 (SoC total)** | **152,104** | **42,864** | **194,968** | 100% |
| accelerator (total) | 79,426 | 27,125 | 106,552 | 54.6% |
| - accelerator_fft | 30,537 | 13,430 | 43,967 | 22.6% |
| - accelerator_mem (128 words) | 46,813 | 12,833 | 59,646 | 30.6% |
| picosoc (total) | 72,630 | 15,453 | 88,083 | 45.2% |
| - picorv32 CPU | 33,177 | 13,506 | 46,683 | 23.9% |
| - picosoc_mem (SRAM) | 34,538 | 3 | 34,541 | 17.7% |
| - simpleuart | 2,018 | 692 | 2,710 | 1.4% |
| - spimemio | 2,412 | 800 | 3,212 | 1.6% |

### Instance Count
| Category | Count |
|----------|-------|
| Total leaf instances | 33,748 |
| Sequential (FFs) | 7,160 |
| Combinational | 26,588 |
| Hierarchical | 15 |

### Runtime
- CPU time: 712.7 seconds (~12 minutes)
- Peak memory: 1,619 MB
