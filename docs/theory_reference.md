# ET4351 Theory Reference — Project-Relevant Concepts

Extracted from course lectures. Covers timing, power, synthesis, PnR, and optimization theory directly applicable to the FFT accelerator project.

---

## 1. PPA Trade-offs (Power, Performance, Area)

All design criteria are application-dependent — "no free lunch":
- **Power** — energy per operation/task, static vs dynamic
- **Performance** — throughput, latency, clock frequency
- **Area** — core area (fixed at $596.4 \mu m \times 596.4 \mu m$ for this project)

Key question: which criteria are **constraints** vs **free optimization targets**?
- **HP design**: area is constraint, latency is optimization target
- **EE design**: area is constraint, energy is optimization target, clock >= 10 MHz is constraint

---

## 2. Timing in Synchronous Circuits

### Key Parameters (Reg A → combinational logic → Reg B)
- $t_{cq}$ — clock-to-Q delay of source register
- $t_{pd}$ — propagation delay (worst-case, slowest path)
- $t_{cd}$ — contamination delay (best-case, fastest path)
- $t_{setup}$ — data must be stable BEFORE clock edge
- $t_{hold}$ — data must remain stable AFTER clock edge

### Setup Time Constraint (frequency-dependent)

$$t_{cq} + t_{pd} + t_{setup} \leq t_{clk}$$

$$\text{Setup slack} = t_{clk} - t_{cq} - t_{pd} - t_{setup} > 0$$

**Project relevance:** D6 targets ~60 MHz ($t_{clk}$ = 16.67 ns). The 4-stage pipeline splits the butterfly's combinational path into ~1/4 depth, enabling this higher frequency. If setup slack is negative → must reduce $t_{pd}$ (split logic further) or increase $t_{clk}$ (lower frequency).

### Hold Time Constraint (frequency-INDEPENDENT)

$$t_{cq} + t_{cd} \geq t_{hold}$$

$$\text{Hold slack} = t_{cq} + t_{cd} - t_{hold} > 0$$

**Project relevance:** D6 has 457 hold violations (WNS = -0.165 ns). Hold violations are **unacceptable** — they cause functional failures regardless of clock speed. Fixed during CTS/routing by inserting delay buffers.

### Clock Skew and Jitter
- **Skew**: $t_{skew} = t_{cA} - t_{cB}$ (clock arrival difference at two registers)
  - Skew on source (early) → reduces setup slack
  - Skew on destination (late) → reduces hold slack
- **Jitter**: random cycle-to-cycle variation
- SDC: `set_clock_uncertainty` accounts for both

---

## 3. Power in Digital Circuits

### Dynamic Power (dominant during active operation)

**Switching power:**

$$P_{sw} \sim \alpha \cdot f_{clk} \cdot V_{DD}^2 \cdot C_L$$

Where:
- $\alpha$ = switching activity factor (fraction of cycles output transitions)
- $f_{clk}$ = clock frequency
- $V_{DD}$ = supply voltage (quadratic effect — most powerful knob)
- $C_L$ = load capacitance

**Short-circuit power:** $P_{sc} \sim \alpha \cdot f_{clk} \cdot t_{sc} \cdot I_{sc} \cdot V_{DD}$ (typically < 10% of $P_{sw}$)

### Static Power (leakage — always present)
- **Subthreshold leakage** (usually dominant): exponential in $V_{gs} - V_{th}$
- **Gate leakage**: tunneling through thin oxide
- At 45nm/32nm (our PDK), leakage is significant

### Energy per Task

$$E = P_{total} \times T_{task} = P_{total} \times N_{cycles} \times T_{clk}$$

**Project relevance for EE design:** $E = P \times T$, so reducing EITHER power OR time reduces energy.
- Reducing $f_{clk}$: P drops (linear in f), but T increases (linear in 1/f) → net effect depends on $P_{leakage}$
- Reducing $\alpha$ (switching activity): reduces $P_{sw}$ without affecting T → pure energy win
- Reducing $V_{DD}$: P drops quadratically, T increases → **minimum energy point (MEP)** exists

### Design Knobs for Energy Reduction

| Knob | Effect on Power | Effect on Time | Net Energy Effect |
|------|----------------|----------------|-------------------|
| Lower $\alpha$ (clock gating, data gating, fewer toggles) | $P_{sw}$ ↓ | No change | $E$ ↓ (pure win) |
| Lower $f_{clk}$ | $P_{sw}$ ↓ (linear) | $T$ ↑ (linear) | Depends on $P_{leak}$ share |
| Lower $V_{DD}$ | $P$ ↓ (quadratic) | $T$ ↑ | $E$ ↓ until MEP, then ↑ |
| Higher $V_{th}$ (HVT cells) | $P_{leak}$ ↓ | $t_{pd}$ ↑ | $E$ ↓ if timing allows |
| Fewer cycles (algorithmic) | $P_{sw}$ ↓ slightly | $T$ ↓ | $E$ ↓ (big win) |

**EE strategy implications:**
- Trivial-twiddle fast paths: reduces $\alpha$ (multiplier doesn't toggle) → $P_{sw}$ ↓ → $E$ ↓
- No twiddle memory reads: reduces $\alpha$ on memory read path → $P_{sw}$ ↓ → $E$ ↓
- Remove recursive twiddle: removes multiply hardware toggling → $P_{sw}$ ↓ → $E$ ↓
- Clock gating idle pipeline stages: $\alpha \to 0$ when gated → $P_{sw}$ ↓ → $E$ ↓
- Radix-4: fewer stages (5→3) → fewer cycles → $T$ ↓ → $E$ ↓

---

## 4. Clock Gating

Most registers don't update every cycle. Disabling their clock reduces $\alpha$ to 0 for those cycles.

Tool detects `if (EN) Q <= D` patterns → inserts **Integrated Clock Gating (ICG)** cells (glitch-free, special library cell).

Types:
- **Automatic**: tool detects enable patterns in RTL
- **Architectural**: manually instantiate ICGs when tool can't detect the pattern

**Project relevance:** The FFT register file (`data_re[0:31]`, `data_im[0:31]`) is idle during S_LOAD_DATA and S_STORE_DATA phases. Clock gating these 64 registers during those phases could reduce dynamic power significantly. For EE, also gate the pipeline registers during non-compute phases.

---

## 5. Multi-Threshold Libraries

Standard cells come in flavors:
- **HVT** (High $V_{th}$): slow but very low leakage
- **SVT** (Standard $V_{th}$): balanced
- **LVT** (Low $V_{th}$): fast but high leakage

Synthesis tool uses LVT **only on critical path**, HVT everywhere else → minimizes leakage while meeting timing.

**Project relevance:**
- HP design: may need more LVT cells to meet 60 MHz timing
- EE design: maximize HVT usage (slow clock allows it) → minimize leakage → lower energy

Provide multiple .lib files to Genus: `set_db library_sets ... -timing {slow_hvt.lib slow_svt.lib slow_lvt.lib}`

---

## 6. Synthesis Flow

HDL → Analysis/Elaboration → Generic netlist → Mapping → Std cell netlist → Optimization → Optimized netlist

**Only setup is optimized at synthesis.** Hold is fixed during PnR (after clock tree is built).

### Tool Optimizations (applied on critical path only):
1. Netlist optimization (simplify/restructure logic)
2. Gate mapping (choose better-fitting cells)
3. Pin swapping (route critical signal to faster transistor input)
4. Driving strength increase (X1 → X4: faster, but more area/power)
5. Buffer insertion (break high-fanout nets)
6. Register retiming (move register boundaries to balance delay)
7. Architecture optimization (e.g., ripple-carry → carry-lookahead)

### When the Tool Can't Meet Constraints
Need **architectural modifications** — e.g., **pipelining**.

**Project relevance:** D6 exists because the single-cycle butterfly had too much combinational depth for 60 MHz. The tool can't pipeline for you — that's an RTL change. The 4-stage split (FETCH → MUL1 → MUL2 → ADD) was a manual architectural decision.

---

## 7. Place & Route Flow

1. **Floorplanning** → 2. **Power planning** → 3. **Placement** → 4. **CTS** → 5. **Routing** → 6. **Verification/Signoff**

### Floorplanning
- Utilization ~70% (more routing space) vs ~90% (smaller die, congestion risk)
- Macro placement: minimize congestion, avoid constrictive channels

### Placement Types
- **Timing-driven** (default): critical path cells close, risk congestion hotspots
- **Congestion-driven**: uniform spread, sub-optimal timing
- **Power-driven**: needs activity annotation

**"Congestion is your enemy. Setup slack is your exchange currency."**

### DRVs (Design Rule Violations)
If DRVs are present, **timing analysis cannot be trusted**.

| DRV | What | Why it matters |
|-----|------|----------------|
| max_cap | Capacitive load on driver ≤ lib limit | Excess cap → slower transitions, more delay/power |
| max_tran | Rise/fall time ≤ lib limit | Slow slew → short-circuit current, unreliable switching |
| max_fanout | Downstream inputs ≤ lib limit | Too many loads degrade signal integrity |
| max_length | Wire length ≤ allowed max | Long wires have high RC delay |

**Project relevance:** D6 has 988 max_tran DRV violations — this means the timing numbers may be unreliable. Must fix before signoff.

### Clock Tree Synthesis (CTS)
- Clock tree = ~30% of total power
- Target skew: 5-10% of clock period
- CTS also fixes hold violations (inserts delay buffers)

### Verification/Signoff
- **Setup timing** checked at slowest corner
- **Hold timing** checked at fastest corner — hold violations are UNACCEPTABLE
- DRC, LVS, antenna checks
- Post-layout simulation with SDF back-annotation
- Use signoff extraction effort

---

## 8. SDC Constraints — What Matters for This Project

```
# Clock definition (example for 60 MHz HP)
create_clock -name clk -period 16.67 [get_ports clk]

# Clock uncertainty (skew + jitter)
set_clock_uncertainty 0.5 [get_clocks clk]

# False paths (reset, UART — not timing-critical)
set_false_path -from [get_ports resetn]

# IO delays (model external Flash/UART timing)
set_input_delay -clock clk 2.0 [get_ports {ser_rx}]
set_output_delay -clock clk 2.0 [get_ports {ser_tx}]
```

Key SDC rules:
- Every clock must be defined
- `set_clock_uncertainty` too relaxed → broken silicon; too conservative → PPA suffers
- False paths on reset/UART prevent the tool from wasting effort on non-critical paths

---

## 9. Pipelining — The Key HP Architectural Technique

When the tool can't meet timing (critical path too long), the designer must split it:

**Before (single-cycle butterfly):**
```
  reg_read → 32x32 multiply → shift → add/sub → reg_write
  (all in one clock cycle — long combinational path)
```

**After (4-stage pipeline, D6):**
```
  FETCH: reg_read → latch operands
  MUL1:  partial products (rr, ii, ri, ir)
  MUL2:  combine + scale (rr-ii, ri+ir) >>> 12
  ADD:   final butterfly (u+t, u-t) → writeback
```

Trade-offs:
- **Pro**: ~1/4 combinational depth per stage → ~5x higher clock frequency
- **Pro**: 1-throughput (new butterfly pair every cycle) → no idle cycles
- **Con**: 3-cycle latency per butterfly (pipeline fill/drain)
- **Con**: Must verify no data hazards (read-after-write on same index)

**Project relevance:** D6 achieves 185 cycles at ~60 MHz = ~3.1 us (vs baseline 732 cycles at 12 MHz = 61 us). The 20x speedup comes from both fewer cycles (3.96x) AND higher frequency (5x).

---

*Extracted from ET4351 Lectures 1-3. For full course notes see tud-notes/Q3/ET4351/*
