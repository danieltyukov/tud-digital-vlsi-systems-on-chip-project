# HP D5 Hold Fix — Failed

## Attempts
- ECO iteration 1: `optDesign -postRoute -hold` with `holdTargetSlack 0.050` → 4,177 violations remain
- ECO iteration 2: Raised density limit, more aggressive settings → 4,176 violations
- ECO iteration 3+: Multiple rounds with `setOptMode -effort high`, `fixHoldAllowSetupTnsDegrade true` → ~3,900 violations
- Setup WNS degraded from +0.113 ns to -0.07 ns (now also failing setup)

## Root Cause
At 95% density and 48 MHz, there is no physical space to insert hold-fixing delay buffers without displacing existing cells and breaking setup timing. The design is over-constrained.

## Conclusion
D5 cannot achieve 0 hold violations at this density. Switching to D1 (register-file at 12 MHz, ~66% density) which should achieve clean hold closure like EE v3 did.

D5 remains valuable for the report as the most aggressive HP exploration, but cannot be the final submission design.
