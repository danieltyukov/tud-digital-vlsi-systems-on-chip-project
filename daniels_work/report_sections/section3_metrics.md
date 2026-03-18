# Section III: Performance Metrics and Validation

## 3.1 Performance Metric Extraction

### Methodology

All metrics are extracted from post-layout simulation and PnR reports:

1. **Latency** ($L$): Read from behavioral simulation transcript
   $$L = N_{cycles} \times T_{clk}$$

2. **Power** ($P$): From post-layout power report with VCD activity annotation
   - Activity file generated during structural simulation with VCD dumping
   - Activity annotation coverage target: ~100%
   - Power report includes: internal power, switching power, leakage power

3. **Energy** ($E$): Computed from power and latency
   $$E = P_{total} \times L = P_{total} \times N_{cycles} \times T_{clk}$$

4. **Area**: From PnR report (total cell area, net area, utilization)

### VCD Start and Duration Time

**Critical**: The VCD activity file must capture only the FFT acceleration window (from `enable_accel` assertion to `done` flag). The start time and duration are read from the behavioral simulation transcript and used to configure the VCD extraction scripts.

- Behavioral simulation reports: "Acceleration of first chunk started at (Milliseconds): X"
- Behavioral simulation reports: "Latency of first chunk is (MICROseconds): Y"
- These values are used in `power_*.db.cnstr.tcl` to set the annotation window

## 3.2 Results Summary

[TO BE FILLED with actual numbers from completed runs]

| Metric | Baseline | HP Design (D3) | EE Design | Unit |
|--------|----------|-----------------|-----------|------|
| Clock period | 83.33 | TBD | 83.33 | ns |
| Clock frequency | 12 | TBD | 12 | MHz |
| Cycles/chunk | 732 | 170 | 732 | cycles |
| Latency | 61.00 | 14.17 | 61.00 | $\mu s$ |
| Post-layout total power | 0.403 | TBD | TBD | mW |
| Energy ($E = P \times T$) | 24.6 | TBD | TBD | nJ |
| Total SoC area | TBD | TBD | TBD | $\mu m^2$ |
| Accelerator area | TBD | TBD | TBD | $\mu m^2$ |
| Accel % of SoC | TBD | TBD | TBD | % |
| Setup WNS | TBD | TBD | TBD | ns |
| Hold WNS | TBD | TBD | TBD | ns |
| DRV violations | TBD | TBD | TBD | count |

### Performance Targets

| Target | Requirement | HP Result | EE Result | Met? |
|--------|-------------|-----------|-----------|------|
| HP latency | < 61.00 $\mu s$ | TBD | N/A | TBD |
| EE energy | < 24.6 nJ | N/A | TBD | TBD |
| EE clock | $\geq$ 10 MHz | N/A | TBD | TBD |

## 3.3 Activity Annotation

### Procedure
1. Run structural simulation with VCD output enabled (`run_struct_sim_vcd.sh`)
2. Annotate VCD activity onto post-PnR netlist using Innovus
3. Generate power report with annotated switching activity
4. Verify annotation coverage (~100% target)

### Annotation Window
- Start time: aligned with `enable_accel` assertion (read from behavioral sim)
- Duration: one FFT chunk processing time
- Coverage: [TO BE FILLED — target 100%]

## 3.4 Post-Layout Simulation

### Test Specifications

| Test | Description | Pass Criteria |
|------|-------------|---------------|
| Behavioral (24 chunks) | Full audio signal FFT | `verify.py` reports "Test Passed" |
| Behavioral (1 chunk) | Single chunk FFT | `verify.py` reports "Test Passed" |
| Structural (1 chunk) | Post-synthesis netlist | `verify.py` reports "Test Passed" |
| Physical setup (1 chunk) | Post-PnR, max delay SDF | `verify.py` reports "Test Passed" |
| Physical hold (1 chunk) | Post-PnR, min delay SDF | `verify.py` reports "Test Passed" |

### Simulation Waveforms

[TO BE FILLED — include annotated waveform screenshots showing:]
- Clock and reset signals
- `enable_accel` assertion → FFT processing → `done` flag
- FSM state transitions
- Data flow: LOAD → COMPUTE → STORE
- Activity annotation period highlighted
