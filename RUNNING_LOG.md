# Running Log

This file tracks the changes and debugging steps performed in this workspace during the current recovery effort.

## 2026-04-03

### Goal
- Make the ET4351 project flow reproducible again.
- Fix the verification/golden-generation path first.
- Then determine whether the remaining mismatch is caused by stale backend artifacts or a real RTL-to-netlist issue.

### Files Changed

#### `firmware/prepare_fft.py`
- Replaced brittle manual `sys.argv` parsing with `argparse`.
- Made the script chdir to the firmware directory before writing outputs, so `fft_data.hex` and `expected_output.txt` are always written to the intended location.
- Purpose:
  - ensure `N_CHUNKS=1` generation is reproducible
  - avoid path-dependent behavior when the script is run from different working directories

#### `firmware/Makefile`
- Added `PYTHON = /usr/bin/python3`.
- Switched helper invocations from `python` to `$(PYTHON)`.
- Purpose:
  - avoid depending on the activated environment's default `python`
  - make firmware/golden generation deterministic

#### `sw/verify.py`
- Changed path resolution to use the script location / project root instead of assuming the current working directory.
- Changed recovered audio output path to write into the selected simulation directory.
- Improved the mismatch message for output-length failures so it explicitly points to likely asset desynchronization.
- Purpose:
  - make verification usable from both the repo root and the sim directories
  - make failures easier to interpret

### Observed Results After Fixes

#### Full-audio / behavioral mode
- `make clean && make` now regenerates:
  - `firmware/fft_data.hex` with header consistent with `768 samples / 24 chunks`
  - `firmware/expected_output.txt` with `768` lines
- `python3 sw/verify.py sim_behav` passes from the repo root.

#### Single-chunk generation
- `make clean && N_CHUNKS=1 make` now regenerates:
  - `firmware/fft_data.hex` with header consistent with `32 samples / 1 chunk`
  - `firmware/expected_output.txt` with `32` lines

### Remaining Problem
- Behavioral outputs match the current reference.
- Structural and physical outputs still match the older backend result, not the current behavioral/reference result.
- This means the remaining failure is not in `verify.py`.
- Likely causes:
  - stale synthesized / PnR outputs
  - or a synthesis-specific mismatch in the current RTL

### Current Investigation
- A fresh synthesis run was started to regenerate `synth/outputs/et4351.struct.v` from the current RTL.
- The next intended step after synthesis is:
  1. rerun structural simulation
  2. rerun `verify.py` on the new structural output
  3. decide whether the backend was stale or whether RTL debugging is needed

### New Findings
- Fresh synthesis completed and regenerated:
  - `synth/outputs/et4351.struct.v`
  - `synth/outputs/et4351.struct.sdf`
- Fresh structural simulation still failed against the regenerated single-chunk golden.
- Conclusion:
  - the mismatch is not caused by stale synthesis artifacts anymore
  - the remaining issue is a real RTL-to-synthesis mismatch

### Additional File Changed

#### `src/design/accelerator_fft.v`
- Replaced inline twiddle multiplications with explicit helper functions:
  - `q12_mul`
  - `q12_cmul_re`
  - `q12_cmul_im`
- Purpose:
  - force explicit signed fixed-point arithmetic widths
  - remove simulator-vs-synthesis ambiguity around multiply/add/shift expressions
  - make the radix-4 and recombine math safer for synthesis

### Next Step
- Re-run:
  1. behavioral simulation
  2. synthesis
  3. structural simulation
  4. verification
- Then check whether the explicit arithmetic patch closes the mismatch.

### Result Of Rebuild
- Behavioral simulation still passed after the arithmetic patch.
- Fresh synthesis completed successfully and regenerated:
  - `synth/outputs/et4351.struct.v`
  - `synth/outputs/et4351.struct.sdf`
- Fresh structural simulation now produces the corrected FFT bins.
- `python3 sw/verify.py sim_struct` now passes.

### Current Conclusion
- `verify.py` was not the root cause of the failing structural flow.
- The structural mismatch was fixed by making the FFT Q12 complex-multiply arithmetic explicit and synthesis-safe in `src/design/accelerator_fft.v`.
- The checker and single-chunk/full-audio generation flow are now consistent with the design.

### Remaining Follow-Up
- Physical / PnR outputs are now stale relative to the fixed RTL and fresh synthesis.
- If final signoff is needed, the next required steps are:
  1. rerun PnR
  2. rerun post-layout simulation
  3. rerun physical verification and power estimation

#### `sim_phys/scripts/run_vcd_setup.cmd`
- Updated the VCD capture runtime from the old baseline `60.997560us` to the current measured accelerator runtime `10.832900us`.

#### `sim_phys/scripts/run_vcd_hold.cmd`
- Updated the VCD capture runtime from the old baseline `60.997560us` to the current measured accelerator runtime `10.832900us`.

### Power Window Note
- The accelerator start time remained correct at `36.181386ms`.
- The runtime had to be refreshed after the FFT RTL fix so the final post-layout power measurement covers the actual accelerated window.

### Fresh PnR / Post-Layout Results
- Ran a fresh Innovus place-and-route from the fixed synthesized netlist.
- Fresh exported physical outputs were generated:
  - `pnr/outputs/et4351.phys.v`
  - `pnr/outputs/et4351.phys.sdf`
- Fresh backend verification status:
  - `verifyReports/verify_drc.rpt`: no DRC violations
  - `verifyReports/verifyProcessAntenna.rpt`: no antenna violations
  - post-route setup summary: setup clean
  - post-route hold summary: not hold clean
  - post-route summaries also show many `max_tran` violations

### Post-Layout Functional Check
- Ran fresh post-layout hold-corner simulation.
- `python3 sw/verify.py sim_phys` passes on the fresh physical outputs.

### Current Overall Status
- Functional correctness is now consistent across:
  - behavioral simulation
  - structural simulation
  - physical/post-layout simulation
- Backend signoff quality is mixed:
  - setup timing: clean
  - DRC: clean
  - antenna: clean
  - hold timing: still failing
  - many `max_tran` violations remain

### External Handoff Package
- Created an external handoff folder outside the project tree:
  - `/home/nfs/rlongomalinski/et4351_handoff_2026-04-03`
- Purpose:
  - give teammates a download-ready snapshot
  - preserve the runnable project directory structure
  - include the fresh generated outputs and key reports
- Included:
  - `src/`, `sw/`, `firmware/`
  - `sim_behav/`, `sim_struct/`, `sim_phys/` without scratch `workLib/`
  - `synth/` scripts, logs, outputs, reports
  - `pnr/` scripts, outputs, timing/verify/final reports
  - top-level docs, setup script, and full-flow script
- Added teammate guide:
  - `/home/nfs/rlongomalinski/et4351_handoff_2026-04-03/HANDOFF_README.md`
