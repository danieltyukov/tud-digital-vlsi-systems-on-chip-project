# Section II: Implementation

## 2.1 Synthesis Configuration

### Tool: Cadence Genus 21.10

**Library selection:**
- Standard cells: `gsclib045_svt_v4.7` (45nm GPDK, SVT flavor, slow corner `slow_vdd1v0`)
- SRAM macros: `saed32sram_ss0p95vn40c` (32nm Synopsys, slow corner)
- LEF: Technology LEF + standard cell LEF + SRAM LEF

**Timing constraints (SDC):**
- Main clock: $T_{clk} = 83.33$ ns (12 MHz) for baseline/EE; potentially tighter for HP
- QSPI generated clock: $T_{clk}/2 = 41.67$ ns
- Clock uncertainty: 0.25 ns (covers skew + jitter)
- False paths: reset (`resetn`), UART (`ser_tx`, `ser_rx`)
- IO delays: 5.0 ns max on QSPI signals

**Optimization settings:**
- Max CPUs: 4 (super-threading enabled)
- Scan flip-flops avoided (`set_attribute avoid true SDFF*`)
- Resource sharing enabled (Genus auto-merges equivalent operators)

### Synthesis Observations

[TO BE FILLED after synthesis completes — include:]
- Total cell count
- Critical path location and slack
- Area breakdown (std cells vs SRAM macros)
- Any DRVs post-synthesis
- Register count (especially for register-file designs)

## 2.2 Place and Route Configuration

### Tool: Cadence Innovus 21.11

**Floorplan:**
- Core area: $596.4 \mu m \times 596.4 \mu m$ (fixed constraint)
- Utilization target: ~70% (balanced routing space vs area efficiency)
- SRAM macro placement: CPU's `picosoc_mem` (4× `SRAM1RW256x8`)

**PnR flow (14 steps via `pnr.tcl`):**
1. Set variables and paths
2. Load design (post-synthesis netlist + constraints)
3. Set library and SDC
4. Floorplan setup
5. Power planning (power rings + stripes)
6. Placement (timing-driven)
7. Clock tree synthesis (CTS)
8. Routing (global + detail)
9. Verification
10. Report generation
11. Final power reports (with activity annotation)

**Congestion management:**
[TO BE FILLED — document any congestion issues and how resolved]

## 2.3 Floorplan Analysis

[TO BE FILLED — include floorplan screenshot showing:]
- SRAM macro placement
- Accelerator register file region
- Power ring/stripe layout
- Congestion heatmap

## 2.4 Tool Setting Optimizations

### HP Design
[TO BE FILLED — document any changes from baseline settings:]
- Clock period tightening (if attempted)
- Placement effort level
- Routing optimization iterations

### EE Design
[TO BE FILLED — document EE-specific settings:]
- Clock gating insertion settings
- Power-driven placement (if used)
- Multi-$V_{th}$ library usage (if HVT added)

## 2.5 Signoff Verification

### Reports Required (for both HP and EE):

| Report | Requirement | HP Status | EE Status |
|--------|-------------|-----------|-----------|
| Setup timing | WNS $\geq 0$ | TBD | TBD |
| Hold timing | WNS $\geq 0$ | TBD | TBD |
| max_tran DRV | 0 violations (or only max_tran) | TBD | TBD |
| max_cap DRV | 0 violations | TBD | TBD |
| Connectivity | Clean | TBD | TBD |
| Geometry | Clean | TBD | TBD |
| Antenna | Clean | TBD | TBD |

### Timing Analysis Methodology

Setup timing analyzed at **slow corner** (worst-case delays):
$$\text{Setup slack} = T_{clk} - t_{cq} - t_{pd} - t_{setup} > 0$$

Hold timing analyzed at **fast corner** (best-case delays):
$$\text{Hold slack} = t_{cq} + t_{cd} - t_{hold} > 0$$

**Note**: Hold violations are frequency-independent and **must** be zero. CTS inserts delay buffers to fix hold violations. max_tran violations are technically acceptable per the project spec (footnote 1) but indicate the timing table doesn't cover the requested input slew / output load combination — extrapolation may give inaccurate timing.
