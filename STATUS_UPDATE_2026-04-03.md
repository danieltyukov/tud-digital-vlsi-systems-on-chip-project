# EE Design v2 Status Update

This note explains what changed between the earlier project state described in the old `README.md` and the current repo state after the latest debugging and reruns.

## Previous State

The previous project note said:

- the EE Design v2 architecture was functionally correct
- `verify.py` was not aligned with the new RFFT/Radix-4 behavior yet
- expected outputs needed regenerating
- full synthesis + PnR still needed to be rerun

That description matched an intermediate state of the repo, but it is no longer the current status.

## Main Issue We Investigated

There were actually two separate problems mixed together:

1. Verification-flow problem
- `verify.py` assumed fragile relative paths
- firmware/golden generation for full-audio vs `N_CHUNKS=1` was easy to desynchronize
- this made it hard to trust a failure, because artifacts could be inconsistent

2. Real backend mismatch
- after fixing the verifier/generation flow, behavioral simulation passed
- but structural simulation still failed
- that meant the checker was not the real remaining issue
- the synthesized hardware was not matching the behavioral RTL result

## What Changed

### 1. Verification flow was fixed

The following files were updated:

- `sw/verify.py`
- `firmware/prepare_fft.py`
- `firmware/Makefile`

Changes made:

- `verify.py` now resolves paths from the project root reliably
- it can be run from the repo root without breaking file lookups
- firmware generation is now deterministic for both:
  - full audio
  - single chunk (`N_CHUNKS=1`)
- the generated `expected_output.txt` and `fft_data.hex` now stay aligned with the intended mode

Result:

- `verify.py sim_behav` passes
- `verify.py sim_struct` passes
- `verify.py sim_phys` passes

So the earlier `verify.py fails` statement is no longer accurate for the current repo.

### 2. The synthesized mismatch was fixed in RTL

The key RTL file updated was:

- `src/design/accelerator_fft.v`

Issue:

- behavioral simulation was correct
- structural simulation was wrong even after fresh synthesis
- that pointed to a synthesis-safety issue in the FFT arithmetic, not a checker issue

Fix:

- the Q12 complex multiply arithmetic was rewritten with explicit signed helper functions and wider intermediate widths
- this removed ambiguity between RTL simulation and synthesis for multiply/add/shift behavior

Result:

- fresh synthesis produced a structural netlist that now matches behavioral simulation
- structural verification now passes

### 3. Post-layout VCD capture window was refreshed

The following files were updated:

- `sim_phys/scripts/run_vcd_setup.cmd`
- `sim_phys/scripts/run_vcd_hold.cmd`

Change made:

- the VCD runtime window was updated from the old baseline `60.997560us`
- to the measured current accelerator runtime `10.832900us`

Why:

- the old power window was stale and would not represent the actual accelerated interval anymore

## Current Functional Status

The design is now functionally consistent across the full simulation chain:

- behavioral simulation: pass
- structural simulation: pass
- post-layout simulation: pass

This means the FFT output numbers match the generated expected output all the way through `sim_phys`.

## Current Backend Status

Fresh PnR was rerun after the RTL fix.

Good:

- post-route setup timing is clean
- DRC is clean
- antenna is clean
- post-layout functional simulation passes

Not yet clean:

- hold timing is still negative
- many `max_tran` violations remain

So the design is functionally working, but not fully backend-signoff-clean yet.

## What We Have Now

Compared with the earlier version, the repo has moved from:

- "architecture seems correct, but verify flow is not fixed yet"

to:

- "verify flow fixed"
- "synthesis mismatch fixed"
- "behavioral/structural/physical simulation all functionally pass"
- "remaining work is backend cleanup, not FFT correctness/debugging"

## Recommended Current Summary

Short status line for teammates:

> EE Design v2 is now functionally passing behavioral, structural, and post-layout verification. The old `verify.py` mismatch issue has been fixed. The remaining open work is backend signoff cleanup, mainly hold timing and max transition violations after PnR.
