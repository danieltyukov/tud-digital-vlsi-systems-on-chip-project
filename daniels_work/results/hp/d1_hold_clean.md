# HP D1 Hold-Clean Build Results

## Design: D1 Register-File Architecture (HP)
- **Branch:** `ShanghongLin-HP-D1-reg_bfly`
- **Architecture:** Register-file based butterfly with recursive twiddle factors (not LUT)
- **Clock period:** 83.33 ns (12 MHz)
- **Build date:** 2026-03-22
- **Server project:** `~/project_hp_d1_clean`

## Build Strategy

D5 (48 MHz, 95% density) failed ECO hold fixing with 3,900+ violations. EE v3 (12 MHz, 66% density) achieved 0 hold violations on a clean rebuild. D1 uses the same register-file architecture as EE v3 with recursive twiddle (not LUT).

**Key insight:** The initial 596.4 x 596.4 core at 12 MHz gave 51.5% pre-hold-fix density, but after hold buffer insertion the density grew to 85%, leaving no room for the tool to fix remaining violations (457 hold violations, WNS = -0.165 ns). ECO fixing also failed.

**Solution:** Enlarged the core to 700.0 x 700.0, giving 36% initial density. This provided ample room for hold buffer insertion, and the tool achieved zero hold violations with a final density of ~63.8%.

## Final Timing Results

### Hold Timing (ZERO VIOLATIONS)
| Metric          | All    | Reg2Reg | Default |
|-----------------|--------|---------|---------|
| WNS (ns)        | +0.015 | +0.015  | +0.103  |
| TNS (ns)        | 0.000  | 0.000   | 0.000   |
| Violating Paths | 0      | 0       | 0       |
| All Paths       | 13926  | 13921   | 226     |

### Setup Timing (ZERO VIOLATIONS)
| Metric          | All    | Reg2Reg | Default |
|-----------------|--------|---------|---------|
| WNS (ns)        | +34.474| +38.879 | +34.474 |
| TNS (ns)        | 0.000  | 0.000   | 0.000   |
| Violating Paths | 0      | 0       | 0       |
| All Paths       | 13926  | 13921   | 226     |

### DRVs
- max_cap: 0 violations
- max_tran: 161 nets (worst = -0.306 ns) -- real only, not blocking
- max_fanout: 0 violations
- max_length: 0 violations
- Glitch violations: 0

## Area & Density
- **Core dimensions:** 700.0 x 700.0
- **Final density:** 63.77% (100% with fillers)
- **Total cell area:** 320,342 (76,233 instances)
  - Accelerator: 189,348 (51,436 instances)
    - FFT engine: 135,707 (38,943 instances)
    - Memory: 46,884 (11,054 instances)
  - SoC: 130,603 (24,739 instances)
    - CPU: 82,750 (21,742 instances)
    - SRAM: 34,586
    - UART: 5,581
    - SPI: 6,061

## Hold Buffer Insertion Summary
- Pre-CTS hold violations: 13,892 (at 34.08% density)
- CTS hold fix added: 20,408 cells
- Post-CTS density: 63.63%
- Post-route hold opt achieved: 0 violations

## Simulation Verification (ALL PASSED)

### Behavioral Simulation
- Result: PASSED (outputs match gold)
- Accelerator runtime: 5,280 clock cycles
- Accelerator latency: 0.440 ms (first chunk: 18.33 us)

### Structural Simulation (with VCD)
- Result: PASSED (outputs match gold)
- SDF backannotation: successful

### Physical Simulation - Hold (min timing, fast corner)
- Result: PASSED (outputs match gold)
- 0 errors, 179 warnings (timing check warnings from library cells)

### Physical Simulation - Setup (max timing, slow corner)
- Result: PASSED (outputs match gold)
- 0 errors, 182 warnings (timing check warnings from library cells)

## Packaged Files (~/finaldesign_hp/)
- `accel_audio.hex` - Firmware (single chunk for sim)
- `et4351.phys.v` - Post-PnR netlist (9.5 MB)
- `et4351.phys.sdf` - Post-PnR timing (40.5 MB)
- `fft_data.hex` - FFT input data

## Comparison with Previous Attempts

| Design | Clock  | Init Density | Final Density | Hold Violations | Hold WNS  |
|--------|--------|-------------|---------------|-----------------|-----------|
| D5     | 48 MHz | ~80%        | ~95%          | 3,900+          | ~ -1.0 ns |
| D1 v1  | 12 MHz | 51.5%       | 85.0%         | 457             | -0.165 ns |
| D1 v2  | 12 MHz | 36.0%       | 63.8%         | 0               | +0.015 ns |
| EE v3  | 12 MHz | ~55%        | ~66%          | 0               | +0.015 ns |

## Floorplan Change
Modified `pnr/scripts/3.0.fplan.tcl`:
- `set Wcore 596.4` -> `set Wcore 700.0`
- `set Hcore 596.4` -> `set Hcore 700.0`
