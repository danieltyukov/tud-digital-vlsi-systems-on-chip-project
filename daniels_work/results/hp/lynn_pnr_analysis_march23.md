# Lynn's PnR Analysis & Sprint Plan — March 23, 2026

## Key Findings from Lynn's Notion Docs

### D5 Updated Run (March 22) — 24-bit Narrowed Datapath
- Density reduced: 91.9% → 82.6% (narrowing from 32 to 24 bits)
- Hold violations: 1,356 → **199** (85% reduction!)
- Setup: **18 NEW violations** (WNS = -0.505 ns) — caused by hold buffers on flash_io paths
- max_tran DRVs: 1,895 → 1,146 (40% reduction)

### Root Cause Analysis (excellent work by Lynn)
1. **Hold violations** dominated by over-pessimistic clock uncertainty (0.250 ns vs actual 0.002 ns skew)
2. **Setup violations** caused by DLY4X1 hold buffers on flash_io→CPU paths (~3.2 ns added delay)
3. **Setup vs Hold conflict**: hold buffers fix hold but break setup on the same paths
4. **DRV**: no `set_max_transition` in SDC forces synthesis to pick weak-drive cells

### Proposed SDC Fixes
| Fix | Change | Impact |
|-----|--------|--------|
| **A** | Reduce flash_clk hold uncertainty: 0.25 → 0.10 ns | Eliminates all 18 setup violations + 1 hold |
| **E** | Reduce clk hold uncertainty: 0.25 → 0.10 ns | Eliminates 198 reg2reg hold violations |
| **D** | Add `set_max_transition 0.28` | Reduces DRVs at source (synthesis picks stronger cells) |
| **C** | Add holdTargetSlack 0.05 + 2nd hold pass | Insurance for remaining hold violations |
| **B** | CTS holdTargetSlack 0.1 → 0.2 | More pre-route hold margin |

### Expected Outcome
Fixes A+E+D together → re-synthesis → full PnR should eliminate all violations.

### Team Plan
- P2+P3 (Alessandro + Anastasis): SDC fixes + PnR iterations
- Sam (Lynn): Architecture section, diagrams, integration
- Leo/Yaonan: Post-layout sim + PPA extraction
- Report: everyone contributes

**Hard deadline:** Timing-clean layout by April 1.

## Relevance to Our Work

### The SDC fix approach applies to ALL our designs
The over-pessimistic clock uncertainty (0.25 ns vs 0.002 ns actual skew) is the root cause of hold violations in ALL register-file designs:
- Our D1: 462 hold violations
- Our EE v3: 59 hold violations (clean on rebuild, but may benefit from SDC fix)
- D5 (24-bit): 199 hold violations

**We should apply the same SDC fixes to our HP D1 and EE v3 designs.**

### Action Items for Daniel's Work
1. Apply SDC fixes (A+E+D) to our designs and re-run
2. This could finally get D1 to 0 hold violations within 596.4 um
3. Could also improve D5 to submission-ready quality
