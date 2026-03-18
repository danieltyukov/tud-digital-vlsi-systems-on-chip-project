# Synthesis Results Comparison

## Date: 2026-03-18
## Tool: Cadence Genus 21.10, slow corner (PVT_0P9V_125C)

### Timing

| Design | Clock (ns) | WNS (ps) | TNS (ps) | Violations |
|--------|-----------|----------|----------|------------|
| Baseline | 83,330 | 31,851 | 0.0 | 0 |
| HP (D3) | 83,330 | 32,347 | 0.0 | 0 |
| EE (no_recursive_tw) | 83,330 | 31,291 | 0.0 | 0 |

All three designs have comfortable positive setup slack at 12 MHz. No timing violations.

### Area ($\mu m^2$)

| Component | Baseline | HP (D3) | EE | HP vs BL | EE vs BL |
|-----------|----------|---------|-----|----------|----------|
| **SoC total** | **194,968** | **259,890** | **170,575** | **+33%** | **−13%** |
| Accelerator total | 106,552 | 171,400 | 82,227 | +61% | −23% |
| - accelerator_fft | 43,967 | 121,155 | 19,672 | +176% | −55% |
| - accelerator_mem | 59,646 | 29,628 | 59,635 | −50% | ≈0% |
| PicoSoC total | 88,083 | 88,206 | 88,015 | ≈0% | ≈0% |
| - CPU | 46,683 | 46,787 | 46,614 | ≈0% | ≈0% |
| - SRAM macros | 34,541 | 34,541 | 34,541 | 0% | 0% |

### Instance Count

| Category | Baseline | HP (D3) | EE |
|----------|----------|---------|-----|
| Total leaf | 33,748 | 51,959 | 27,967 |
| Sequential (FFs) | 7,160 | 7,707 | 7,087 |
| Combinational | 26,588 | 44,252 | 20,880 |

### Key Observations

1. **HP area increase** is driven by the dual butterfly datapaths (2× multiplier sets) and expanded twiddle CSR logic. The 176% growth in `accelerator_fft` is the cost of 2× parallel compute.

2. **HP memory savings**: SRAM halved from 128→64 words (−50%) because twiddles moved to CSR registers.

3. **EE area decrease**: The no-recursive-twiddle LUT replaces the recursive multiplier chain, allowing Genus to optimize constant twiddle values into simpler gate logic. 55% reduction in FFT core area.

4. **Die area utilization**: Baseline 55%, HP 73%, EE 48%. All fit within 596.4² = 355,693 $\mu m^2$.

### Die Area Check
- Core area constraint: $596.4 \times 596.4 = 355,693 \mu m^2$
- Baseline utilization: $194,968 / 355,693 = 54.8\%$
- HP utilization: $259,890 / 355,693 = 73.1\%$
- EE utilization: $170,575 / 355,693 = 48.0\%$
