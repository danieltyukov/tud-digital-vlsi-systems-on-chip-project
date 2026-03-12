# Why Trivial-Twiddle Fast Paths Can Reduce Energy

## Change
The `tt_fastpaths` variant keeps the same FFT schedule and cycle count as the baseline, but in `BUTTERFLY_COMPUTE` it avoids the full complex multiply when the twiddle is one of these trivial values:

- `+1`
- `-1`
- `+j`
- `-j`

In those cases, the result can be computed with sign flips and real/imag swaps instead of multiplier activity.

## Why This Can Reduce Energy
Energy is approximately:

`Energy = Power x Time`

This change does not reduce time:

- same FSM
- same number of states
- same number of cycles

But it can still reduce energy by reducing power:

- less multiplier switching in the butterfly datapath
- less internal glitching in the arithmetic logic
- simpler operations for common twiddle cases

So even with unchanged latency, average dynamic power can go down.

## Why It Is Relevant In This FFT
For a 32-point radix-2 FFT, there are:

- `5` stages
- `16` butterflies per stage
- `80` butterflies total

The number of butterflies using trivial twiddles is:

- stage `m = 2`: `16`
- stage `m = 4`: `16`
- stage `m = 8`: `8`
- stage `m = 16`: `4`
- stage `m = 32`: `2`

Total trivial-twiddle butterflies:

- `46 / 80 = 57.5%`

So the fast path can bypass the main butterfly complex multiply in more than half of all butterflies.

## Limitation
This is not a full compute-path removal:

- the baseline still updates the recursive twiddle state `w <- w * w_m`
- that twiddle-update arithmetic still exists in this variant

So the expected benefit is:

- lower datapath switching
- likely lower dynamic energy
- no cycle-count improvement
- smaller gain than a more aggressive rewrite that also removes recursive twiddle updates

## Conclusion
This optimization can work because a large fraction of butterflies use trivial twiddles, and those cases do not need a full complex multiply. Replacing multiply activity with sign/swap logic can reduce dynamic power, which can reduce total energy even when the runtime stays the same.
