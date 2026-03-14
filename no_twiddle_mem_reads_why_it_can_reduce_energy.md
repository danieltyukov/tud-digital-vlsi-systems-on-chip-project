# Why `no_twiddle_mem_reads` Can Work and Reduce Energy

## Change
The `no_twiddle_mem_reads` variant removes twiddle-factor memory reads and replaces them with stage-local constants:

- baseline behavior: read `W_m` real/imag from memory in `READ_W_M_RE` / `READ_W_M_IM`
- new behavior: assign `w_m_re` / `w_m_im` from `stage_twiddle_step(stage)`

The rest of the butterfly flow is kept:

- same FSM sequence (including `READ_W_M_*` states)
- same recursive twiddle update `w <- w * w_m`
- same butterfly math and memory writeback schedule

## Why It Still Works
This is correct because `W_m = exp(-j*2pi/m)` depends only on the FFT stage (`m = 2,4,8,16,32`), not on `base` or `k`.

So preloading stage constants is mathematically equivalent to reading those same constants from memory, as long as fixed-point values match.

In this RTL, the stage constants are explicitly provided in Q12:

- stage 1 (`m=2`): `(-4096, 0)`
- stage 2 (`m=4`): `(0, -4096)`
- stage 3 (`m=8`): `(2896, -2896)`
- stage 4 (`m=16`): `(3784, -1567)`
- stage 5 (`m=32`): `(4017, -799)`

Then each butterfly still advances twiddle with:

`w_next = w * W_m`

So the per-butterfly twiddle sequence is preserved.

## Why This Can Reduce Energy
Energy is approximately:

`Energy = Power x Time`

This change primarily targets power, not time:

- removes twiddle-memory read activity and associated address/data toggles
- removes dependence on memory path for `W_m`
- keeps compute schedule the same

Since the FSM keeps the same state sequence here, cycle count is expected to stay unchanged, but dynamic switching in memory/read-path logic can drop.

## Limitation
Because `READ_W_M_RE` and `READ_W_M_IM` states are still present in this specific variant, latency is not expected to improve from this change alone.

So expected outcome is:

- similar runtime
- potentially lower dynamic energy

## Conclusion
`no_twiddle_mem_reads` works because it replaces a stage-only twiddle lookup from memory with equivalent hardcoded stage constants, while preserving recursive twiddle progression and butterfly ordering. The main benefit is reduced switching on twiddle-read paths, which can reduce power even if cycle count remains the same.
