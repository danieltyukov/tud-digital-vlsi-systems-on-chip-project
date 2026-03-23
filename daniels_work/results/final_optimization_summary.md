# Final Optimization Summary (Updated March 23, 2026)

## Every Project Optimization — Explored

| Optimization | Status | Result | Used in Final? |
|---|---|---|---|
| D1 Register-file | **Verified** | 732→220 cycles | **HP submission** |
| D2 2× parallel BF | **Verified** | 220→206 cycles | Report data |
| D3 SW twiddle preload | **Verified** | 206→170 cycles | Report data |
| D5 Pipeline + wide mem | **Verified** | 170→121 @ 48MHz | Report data (hold violations unfixable at 95% density) |
| D4 All data via CSR | Analyzed | ~42 cycles | No (infeasible routing) |
| D7 Radix-4 | Verified (FranzJosef) | 428 cycles, 14.12 nJ | Report data |
| Clock gating | **Verified** | -30% power | **EE submission** |
| LUT twiddle | **Verified** | Less switching | **EE submission** |
| Fastpaths | **Verified** | 46% less multiplies | No (marginal, worse hold) |
| RFFT | **Analyzed** | -15% energy | No (SRAM I/O bottleneck) |
| Bit-width reduction | **Analyzed** | -3.5% max | No (FFT core = 5% of power) |
| SDC uncertainty fix | **Verified** | Eliminates all hold violations | **Both submissions** |
| `set_max_transition` | **Verified** | Reduces DRVs, lowers density | **Both submissions** |

## Final Submissions (SDC-fixed, March 23)

| | HP (D1) | EE (v3) |
|---|---|---|
| Architecture | Register-file (recursive twiddle) | Register-file + LUT + clock gating |
| Cycles | 220 @ 12 MHz | 210 @ 12 MHz |
| Latency | **18.33 $\mu s$** | 17.50 $\mu s$ |
| Target | < 61 $\mu s$ (3.33× margin) | < 24.6 nJ |
| Setup WNS | **+34.442 ns** | **+34.317 ns** |
| **Hold WNS** | **+0.050 ns** | **+0.049 ns** |
| **Hold violations** | **0** | **0** |
| DRC | Clean | Clean |
| Connectivity | Clean | Clean |
| Antenna | Clean | Clean |
| Density | 56.9% | 70.2% |
| All sims | PASS | PASS |
| Packaged | `finaldesign_hp/` | `finaldesign_ee/` |
| MD5 verified different | Yes | Yes |

## What Changed (SDC Fixes from Lynn's Analysis)

| Fix | Change | Effect |
|-----|--------|--------|
| CLK_UNCERTAINTY | 0.25 → 0.10 ns | Eliminated all hold violations (0.25 was 125× actual skew) |
| `set_max_transition` | Added 0.28 ns | Genus picks stronger cells → fewer DRVs → lower density |
| CTS holdTargetSlack | 0.1 → 0.2 | More pre-route hold margin |
| Route holdTargetSlack | Added 0.05 + 2nd pass | Insurance for remaining hold violations |
