# Final Optimization Summary

## Every Project Optimization — Explored

| Optimization | Status | Result | Used in Final? |
|---|---|---|---|
| D1 Register-file | **Verified** | 732→220 cycles | Base for EE |
| D2 2× parallel BF | **Verified** | 220→206 cycles | Report data |
| D3 SW twiddle preload | **Verified** | 206→170 cycles | Report data |
| D5 Pipeline + wide mem | **Verified** | 170→121 @ 48MHz | **HP submission** |
| D4 All data via CSR | Analyzed | ~42 cycles | No (infeasible routing) |
| D7 Radix-4 | Committed (FranzJosef) | 176 cycles | No (unverified) |
| Clock gating | **Verified** | -30% power | **EE submission** |
| LUT twiddle | **Verified** | Less switching | **EE submission** |
| Fastpaths | **Verified** | 46% less multiplies | No (marginal, worse hold) |
| RFFT | **Analyzed** | -15% energy | No (SRAM I/O bottleneck) |
| Bit-width reduction | **Analyzed** | -3.5% max | No (FFT core = 5% of power) |

## Final Submissions

| | HP (D5) | EE (v3) |
|---|---|---|
| Architecture | Pipeline + wide memory | Register-file + LUT + clock gating |
| Cycles | 121 @ 48 MHz | 210 @ 12 MHz |
| Latency | **10.08 $\mu s$** | 17.50 $\mu s$ |
| Power | ~0.7 mW | 0.492 mW |
| Energy | — | **8.6 nJ** |
| Target | < 61 $\mu s$ (6× margin) | < 24.6 nJ (65% margin) |
| All sims | PASS | PASS |
| Setup WNS | +0.113 ns | +33.564 ns |
| Hold violations | 4,133 | 59 |
| DRC/Conn/Ant | Clean | Clean |
| Packaged | `finaldesign_hp/` | `finaldesign_ee/` |
| MD5 verified different | Yes | Yes |
