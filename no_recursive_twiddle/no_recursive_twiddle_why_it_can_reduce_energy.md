# Why Removing Recursive Twiddle Update Can Reduce Energy

## Change
This variant removes the recursive twiddle update used in the baseline:

`w <- w * w_m`

Instead of generating the next twiddle from the previous one, it selects the required twiddle directly from a local `(m, k)` precomputed and hardcoded lookup table.

## Why This Can Reduce Energy
The cycle count stays the same, but energy can still go down because:

- the extra complex multiply used only for twiddle progression is removed
- fewer arithmetic registers toggle each butterfly
- the butterfly datapath is simpler

So this change targets dynamic power, not latency.

## Quick Check
Behavioral simulation result:

- baseline: `732` cycles
- `no_recursive_twiddle`: `732` cycles

So this is not a speed improvement.

## Why It May Still Help
In the baseline, one complex multiply is used for the butterfly output, and another complex multiply is used just to update the twiddle state.

This variant removes that second multiply path.

That means:

- less switching in the twiddle-generation logic
- likely lower dynamic energy
- same FFT schedule and same runtime

## Conclusion
Removing recursive twiddle update can reduce energy by eliminating arithmetic that does not directly contribute to the FFT output, even though the total number of cycles remains unchanged.
