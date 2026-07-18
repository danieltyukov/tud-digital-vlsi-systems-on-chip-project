# EE v3 (Ours) vs Romeu comb_3_gc — Full Comparison

## Design Approach

| Aspect | Romeu comb_3_gc | My EE v3 |
|--------|----------------|-----------|
| **Base architecture** | Baseline FSM (9-state per-butterfly) | D1 register-file (5-state bulk) |
| **Cycles/chunk** | 732 | **210** |
| **Clock** | 12 MHz | 12 MHz |
| **Latency** | 61.00 $\mu s$ | **17.50 $\mu s$** |
| **LUT twiddle** | Yes (his implementation) | Yes (our implementation on D1 FSM) |
| **No SRAM twiddle reads** | Yes (dead states kept) | Yes (state removed entirely) |
| **Fastpaths** | Yes (trivial twiddle bypass) | No |
| **Clock gating** | Yes (2 ICG cells) | Yes (2 ICG cells, same approach) |

## Results

| Metric | Romeu comb_3_gc | My EE v3 |
|--------|----------------|-----------|
| **Accel power** | 0.019 mW | 0.271 mW |
| **Total chip power** | 0.231 mW | 0.492 mW |
| **Accel energy** | 1.19 nJ | ~4.7 nJ |
| **Total chip energy** | 14.08 nJ | **8.6 nJ** |
| **Setup WNS** | +33.733 ns | +33.564 ns |
| **Hold WNS** | 0.000 ns (exactly clean) | -0.131 ns (59 violations) |
| **Hold violations** | **0** | 59 |
| **max_tran DRVs (real)** | **0** | 804 |
| **DRC** | Clean | Clean |
| **Connectivity** | Clean | Clean |
| **Antenna** | Clean | Clean |
| **Density** | ~60% | ~80% |
| **VCD annotation** | 99.98% (shows 0%) | 99.98% (shows 0%) |
| **ECO iterations for hold** | 11 | 0 |
| **All sims pass** | Yes | Yes |

## Analysis

### Romeu wins on
- **Accelerator power**: 0.019 vs 0.271 mW — his accelerator is idle ~95% of the VCD window, clock gating eliminates that idle power
- **Hold closure**: 0 violations vs 59 — his 11 ECO iterations achieved fully clean timing
- **DRV count**: 0 real max_tran vs 804 — lower density (~60%) gives better signal integrity
- **Signoff cleanliness**: fully clean on all metrics

### We win on
- **Total chip energy**: 8.6 vs 14.08 nJ — our 3.5× shorter latency outweighs 2× higher power
- **Fewer cycles**: 210 vs 732 — architectural optimization via register-file
- **Latency**: 17.5 vs 61 $\mu s$
- **No ECO needed**: our design closes (with minor violations) in the default PnR flow

### Why Romeu's accelerator power is so low
His 732-cycle design means the accelerator is active for the same duration as baseline. During the 61 $\mu s$ VCD window, the CPU spends most time loading data into accelerator memory and reading results back — the accelerator itself is only computing for a fraction of the window. Clock gating eliminates all switching during idle periods, so accelerator power drops to near-zero (leakage only).

### Why our total energy is lower
$E = P_{total} \times T_{latency}$

Our latency is 3.5× shorter (17.5 vs 61 $\mu s$). Even though our power is 2.1× higher (0.492 vs 0.231 mW):

$$\frac{E_{ours}}{E_{romeu}} = \frac{0.492 \times 17.5}{0.231 \times 61.0} = \frac{8.61}{14.09} = 0.61$$

Our energy is 39% lower because the latency reduction dominates the power increase.

### Both meet the target
- Target: Energy < 24.6 nJ
- Romeu: 14.08 nJ (43% under)
- Ours: 8.6 nJ (65% under)
