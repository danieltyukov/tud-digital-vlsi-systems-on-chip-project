# D5 Review: HP 2x Bandwidth Memory (ShanghongLin-HP-D5-2xBandwidth)

## Branch Summary

Branch: `remotes/origin/ShanghongLin-HP-D5-2xBandwidth`

Commit history (oldest to newest):
```
4daf4e2 Setup baseline
dac9eca Rerun the sim_behav to note cycles.
af62201 Implement regs to store intermediate values
9cb2581 chore: stop tracking generated Innovus logs and temp files
232269a Update FFT accelerator and apply comprehensive .gitignore
864ea23 chore: purge EDA databases, waveforms, and logs from git tracking
5c2692f Synth verified for twiddle preload ver.
e7d3c88 Overlap pipeline computation stage, enabling 5x freq.
6c2c6e2 Update readme and remove dead cycle
3a8fa82 Update readme
23c6618 Update readme
1de4431 Extend acc_mem 2x with pnr done.
0e20628 post-layout pwr estimation done.
```

This branch builds on top of v6 (pipelined butterfly) and adds a wide (64-bit) paired memory interface to halve the LOAD/STORE transfer time. PnR and post-layout power estimation are complete.

---

## What the 2x Bandwidth Change Is

**Approach: Wide paired SRAM interface (Option B -- not dual-port, not banked)**

The memory (`accelerator_mem`) keeps its original single array of flip-flops (`reg [31:0] mem [0:63]`) but now exposes **two ports**:

1. **Narrow port (32-bit)** -- serves CPU (iomem) accesses. This is the original single-word read/write path. Used by firmware to write input data and read output data before/after the FFT run.

2. **Wide port (64-bit paired)** -- serves the FFT core's LOAD/STORE phases. Addresses a *pair* of consecutive words in one cycle using `pair_addr`:
   - `rdata_lo = mem[{pair_addr, 1'b0}]` (even address = real part)
   - `rdata_hi = mem[{pair_addr, 1'b1}]` (odd address = imaginary part)

This exploits the interleaved re/im data layout. The synthesis sees 32x (MEM_DEPTH/2):1 mux trees per output bit, sharing the pair_addr decode between rdata_lo and rdata_hi. Writes are mutually exclusive between narrow and wide by protocol.

Key architectural note: The narrow and wide write paths both exist in the always block without explicit mutual-exclusion guards -- correctness relies on the system protocol (CPU writes before enable; FFT writes after). This is safe but not defensive.

---

## Cycle Count Analysis

Per the header comment in `accelerator_fft.v` (v7):

| Phase       | D6 (v6 pipeline) | D5 (v7 wide port) | Change |
|-------------|-------------------|--------------------|--------|
| INIT        | 1                 | 1                  | 0      |
| LOAD_DATA   | 64                | 32                 | -32    |
| COMPUTE     | 55                | 55                 | 0      |
| STORE_DATA  | 64                | 32                 | -32    |
| FINISH      | 1                 | 1                  | 0      |
| **TOTAL**   | **185**           | **121**            | **-64** |

The wide port loads one complex pair (re + im) per cycle instead of one word. For N=32 complex values that are interleaved as 64 words:
- Old: 64 cycles LOAD + 64 cycles STORE = 128 cycles for I/O
- New: 32 cycles LOAD + 32 cycles STORE = 64 cycles for I/O

The compute pipeline (4-stage: FETCH -> MUL1 -> MUL2/SCALE -> ADD/WRITEBACK, 2 parallel butterflies per pump) is completely unchanged from v6.

**Net savings: 64 cycles (34.6% reduction from 185 to 121 cycles).**

---

## Architecture Changes (vs D6 pipeline)

### accelerator_fft.v (v7)
- New wide port signals: `accel_mem_wstrb_lo/hi`, `accel_mem_rdata_lo/hi`, `accel_mem_wdata_lo/hi`, `accel_mem_pair_addr`
- Removed the old single `accel_mem_addr`, `accel_mem_rdata`, `accel_mem_wdata`, `accel_mem_wstrb`
- LOAD_DATA: captures `rdata_lo -> data_re[io_cnt]`, `rdata_hi -> data_im[io_cnt]` in one cycle
- STORE_DATA: drives both `wdata_lo = data_re[io_cnt]`, `wdata_hi = data_im[io_cnt]` with full strobes in one cycle
- `pair_total = number_data` (= N = 32), and io_cnt counts 0..31 (pairs, not individual words)
- Compute pipeline registers, addressing logic, and stage control are completely unchanged

### accelerator_mem.v (wide-port variant)
- Added wide port inputs: `wen_lo[3:0]`, `wen_hi[3:0]`, `pair_addr[4:0]`, `wdata_lo[31:0]`, `wdata_hi[31:0]`
- Added wide port outputs: `rdata_lo[31:0]`, `rdata_hi[31:0]`
- Wide read is combinational: `rdata_lo = mem[{pair_addr, 1'b0}]`, `rdata_hi = mem[{pair_addr, 1'b1}]`
- Wide write uses the same byte-enable pattern as narrow, applied to `wide_addr_lo` and `wide_addr_hi`
- Still synthesizes to flip-flops (no SRAM macro)

### accelerator.v (wrapper)
- Instantiation updated to connect both narrow (CPU) and wide (FFT) ports
- `PAIR_ADDR_WIDTH = ADDR_WIDTH - 1 = 5` added as localparam
- CPU narrow path unchanged; wide port signals routed directly from FFT core to memory
- CSR interface, twiddle packing, memory map all unchanged

### firmware (accel_audio.c)
- **No firmware changes** -- the firmware still writes individual words through the narrow port. The wide port is internal to the accelerator only. This is clean design.

---

## PnR & Physical Results

### Clock Period
- **20.83 ns (48.01 MHz)** -- same as D6

### Timing (post-route)
- Worst setup slack: **+0.254 ns** (met) on `soc/cpu/count_cycle_reg_63_/D`
- All setup paths meet timing
- No hold violations reported
- DRC: **No violations**
- Connectivity: **No problems or warnings**

### Area
| Module           | Instances | Area (um^2)  |
|------------------|-----------|-------------|
| et4351 (total)   | 92,499    | 322,724     |
| accel (total)    | 66,110    | 206,970     |
| accel/fft        | 43,730    | 132,655     |
| accel/mem        | 12,780    | 47,519      |
| soc (total)      | 26,320    | 115,366     |

The accelerator dominates area at 64% of the total design. The memory module at 47,519 um^2 includes the extra mux trees for the wide read port.

### Power (VCD-annotated, post-route)
| Component        | Internal (mW) | Switching (mW) | Leakage (mW) | Total (mW) | % of Total |
|------------------|---------------|-----------------|---------------|------------|------------|
| **Total**        | 0.506         | 0.162           | 0.036         | **0.704**  | 100%       |
| accel            | 0.350         | 0.087           | 0.026         | 0.463      | 65.8%      |
| accel/fft        | 0.175         | 0.043           | 0.017         | 0.234      | 33.3%      |
| accel/mem        | 0.113         | 0.027           | 0.005         | 0.146      | 20.7%      |
| soc              | 0.145         | 0.048           | 0.010         | 0.202      | 28.8%      |
| Clock tree       | 0.061         | 0.149           | 0.000         | 0.211      | 30.0%      |

**IMPORTANT CAVEAT:** The VCD annotation coverage is reported as **0/95799 = 0%**. This means the VCD file did not map to any nets in the post-layout netlist. The power numbers are based on default/statistical activity, NOT actual simulation-derived switching. This is a significant issue -- the power numbers are unreliable estimates.

---

## Latency Calculation

- Cycles: 121
- Clock period: 20.83 ns
- **Latency: 121 x 20.83 ns = 2.520 us**

---

## Comparison to Our D1 HP Design

| Metric                    | Our D1 HP          | Shanghong D5       | Delta          |
|---------------------------|--------------------|--------------------|----------------|
| Cycles                    | 220                | 121                | D5 is 45% fewer |
| Clock frequency           | 12 MHz (est.)      | 48 MHz             | D5 is 4x faster |
| Latency                   | 18.33 us           | 2.52 us            | D5 is 7.3x faster |
| Total power (VCD)         | --                 | 0.704 mW*          | --             |
| Area                      | --                 | 322,724 um^2       | --             |

*Power figure is unreliable due to 0% VCD annotation coverage.

D5 is significantly faster than our D1, primarily because:
1. Higher clock frequency (48 MHz vs 12 MHz, inherited from D6 pipeline)
2. Fewer cycles (121 vs 220, from both the pipeline and the wide memory port)

---

## Issues Found

### Critical
1. **VCD annotation coverage is 0%** -- Both power reports (`report_power.rpt` and `report_power_postRouteVCD.rpt`) show "Design annotation coverage: 0/95799 = 0%". The VCD file path references `../sim_struct/vcd/et4351.struct.vcd` and `../sim_phys/vcd/et4351.phys.hold.vcd` respectively, but no nets were mapped. The power numbers are statistical estimates, not simulation-based. The VCD-annotated report uses `et4351.phys.hold.vcd` which sounds like it might be a hold-time check VCD rather than a functional simulation VCD.

### Minor
2. **No mutual-exclusion guard in memory writes** -- The `accelerator_mem` write logic has both narrow and wide write enable checks active simultaneously in the always block. Correctness depends on the wrapper never asserting both at once (guaranteed by protocol, but not by hardware). If both were asserted simultaneously, the wide write would silently overwrite the narrow write (or vice versa depending on synthesis priority).

3. **Clock tree slew violation** -- 2 pins have minor slew violations (0.002 ns over target of 0.093 ns) on the flash_clk path. This is marginal and unlikely to cause issues.

4. **power.rpt is empty** -- The file `pnr/power.rpt` is 0 bytes (empty blob `e69de29b`).

---

## Summary

D5 successfully implements the "wide memory bus" optimization. By adding a 64-bit paired read/write interface to the accelerator memory, it halves the LOAD/STORE time from 128 cycles to 64 cycles (for N=32). Combined with the v6 pipeline compute engine running at 48 MHz, total latency drops to 121 cycles / 2.52 us. This is 7.3x faster than our D1 HP design.

The PnR is clean (no DRC violations, timing met). The main concern is that power estimates are unreliable due to 0% VCD annotation coverage -- this needs to be rerun with a properly mapped VCD file before the numbers can be trusted for the final report.
