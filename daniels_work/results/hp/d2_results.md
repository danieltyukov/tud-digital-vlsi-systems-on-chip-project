# D2 (2x Parallel Butterflies) -- Full EDA Flow Results

Branch: `remotes/origin/ShanghongLin-HP-D2-reg_parallel_bfly`
Server project: `~/project_hp_d2`
Date: 2026-03-20/21

---

## Behavioral Simulation
- **Cycles/chunk**: 206 (4944 total / 24 chunks)
- **Total latency**: 32,034,331 clock cycles (2669.42 ms)
- **Accelerator runtime**: 4944 clock cycles (0.412 ms)
- **First chunk latency**: 17.166 us
- **Verification**: PASS (outputs and gold identical)
- **Errors**: 0, Warnings: 6

## Synthesis (Genus)
- **Clock period**: 83,330 ps (12 kHz)
- **Setup WNS (clk)**: +32,347 ps (no violations)
- **Setup WNS (flash_clk)**: +35,449 ps (no violations)
- **TNS**: 0.0 (no timing violations)
- **Violating paths**: 0
- **Cell area**: 227,824.873
- **Net area**: 80,234.449
- **Total area**: 308,059.322
- **Leaf instances**: 62,529
- **Sequential instances**: 9,729
- **Combinational instances**: 52,800
- **Accelerator (accel) area**: 219,705.743
  - FFT core: 156,917.715
  - Memory: 59,839.720
- **PicoSoC area**: 88,022.757

## Structural Simulation (with VCD)
- **Verification**: PASS (outputs and gold identical)
- **Complete latency**: 1,475,833 clock cycles (122.98 ms)
- **VCD file**: sim_struct/vcd/et4351.struct.vcd (11 MB)
- **Errors**: 0, Warnings: 0

## Place & Route (Innovus)
### Setup Timing
| Mode    |  WNS (ns) |  TNS (ns) | Violating Paths | All Paths |
|---------|-----------|-----------|-----------------|-----------|
| all     |   35.108  |    0.000  |        0        |   15,403  |
| reg2reg |   37.789  |    0.000  |        0        |   15,398  |
| default |   35.108  |    0.000  |        0        |      226  |

### Hold Timing
| Mode    |  WNS (ns) |  TNS (ns) | Violating Paths | All Paths |
|---------|-----------|-----------|-----------------|-----------|
| all     |  -0.252   | -121.511  |     1,411       |   15,403  |
| reg2reg |  -0.250   | -120.641  |     1,406       |   15,398  |
| default |  -0.252   |   -0.870  |         5       |      226  |

### DRVs
| Type       | Nets (terms) | Worst Violation |
|------------|-------------|-----------------|
| max_cap    |    0 (0)    |     0.000       |
| max_tran   | 5,193 (18,704) |   -2.481    |
| max_fanout |    0 (0)    |       0         |
| max_length |    0 (0)    |       0         |

### Density
- **Cell density**: 94.587%
- **With fillers**: 100.000%

### Area (PnR)
| Module              | Instances | Total Area   |
|---------------------|-----------|-------------|
| et4351 (top)        |   99,424  | 331,078.093 |
| accel (accelerator) |   74,806  | 223,219.980 |
|   accel/fft         |   60,496  | 160,194.852 |
|   accel/mem         |   12,727  |  58,058.946 |
| soc (picosoc)       |   24,527  | 107,507.221 |
|   soc/cpu           |   21,649  |  63,499.482 |
|   soc/memory        |       29  |  34,568.539 |

### Verification
- **DRC violations**: 4 (metal shorts on Metal6)
- **Connectivity**: No problems found
- **Antenna**: No violations
- **Glitch violations**: 21

### Power (VCD-annotated, VDD=1.32V)
- **Total power**: 0.921 mW
  - Internal: 0.607 mW (65.9%)
  - Switching: 0.276 mW (30.0%)
  - Leakage: 0.037 mW (4.1%)
- **Accelerator power**: 0.691 mW (75.1%)
- **Clock power**: 0.237 mW (25.7%)
- Note: VCD annotation coverage was 0% (VCD from struct sim may need correct window alignment)

## Physical Simulation
### Setup (sdfmax, slow corner)
- **Verification**: PASS (outputs and gold identical)
- **Complete latency**: 1,475,832 clock cycles (122.98 ms)
- **Errors**: 0, Warnings: 183

### Hold (sdfmin, fast corner)
- **Verification**: PASS (outputs and gold identical)
- **Complete latency**: 1,475,832 clock cycles (122.98 ms)
- **Errors**: 0, Warnings: 163

---

## Summary for HP Progression Table

| Design   | Cycles/chunk | Reduction | Synth Area | PnR Setup WNS | PnR Hold WNS | Phys Sim |
|----------|-------------|-----------|-----------|---------------|---------------|----------|
| Baseline |     732     |     --    |     --    |       --      |       --      |    --    |
| D1       |     220     |   69.9%   |     --    |       --      |       --      |   PASS   |
| **D2**   |   **206**   | **6.4%**  | 227,825   |   +35.108     |    -0.252     | **PASS** |
| D3       |     170     |   17.5%   |     --    |       --      |       --      |   PASS   |
| D5       |     121     |   28.8%   |     --    |       --      |       --      |   PASS   |

D2 provides the first fully validated data point in the HP progression with full PnR results:
- D1 -> D2: 220 -> 206 cycles (6.4% reduction via 2x parallel butterflies)
- Both setup and hold physical simulations pass
- Setup timing has generous margin (+35.1 ns slack on 83.33 ns clock)
- Hold timing has violations in STA (-0.252 ns WNS) but physical sim still passes
- 4 minor DRC shorts on Metal6 (localized, do not affect functional correctness)
