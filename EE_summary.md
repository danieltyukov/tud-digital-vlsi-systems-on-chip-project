# EE Summary

## Final Working EE Design

The final EE design that worked is based on:

- a merged FFT RTL in `/home/nfs/rlongomalinski/project_ee/src/design/accelerator_fft.v`
- no broad clock gating in the final kept flow

What was implemented in the FFT:

- local twiddle LUT instead of recursive twiddle generation
- no twiddle-memory reads
- fast paths for trivial twiddles (`+1`, `-1`, `+j`, `-j`)

## What Passed

The final kept EE design passed:

- behavioral simulation
- structural simulation
- post-layout setup simulation
- post-layout hold simulation
- physical output verification
- connectivity check
- DRC check
- antenna check

## Final Timing Results

Post-route setup:

- WNS: `34.016 ns`
- TNS: `0`
- violating paths: `0`

Post-route hold:

- WNS: `0.081 ns`
- TNS: `0`
- violating paths: `0`

## Final Energy Result

Behavioral accelerator runtime:

- `60.997560 us`

Post-route accelerator power:

- `0.3291 mW`

Final accelerator energy:

- `20.074297 nJ`

Baseline energy:

- `24.6 nJ`

Improvement:

- `18.40%` lower than baseline

## Final Status

The final kept EE design:

- is functionally correct
- is setup clean
- is hold clean
- is connectivity clean
- is DRC clean
- is antenna clean
- runs at `12 MHz`
- beats the EE baseline energy target

## Final Artifacts

Main outputs:

- `/home/nfs/rlongomalinski/project_ee/pnr/outputs/et4351.phys.v`
- `/home/nfs/rlongomalinski/project_ee/pnr/outputs/et4351.phys.sdf`
- `/home/nfs/rlongomalinski/project_ee/pnr/outputs/et4351.phys.gds`

Packaged copies:

- `/home/nfs/rlongomalinski/project_ee/finaldesign/et4351.phys.v`
- `/home/nfs/rlongomalinski/project_ee/finaldesign/et4351.phys.sdf`
- `/home/nfs/rlongomalinski/project_ee/finaldesign/accel_audio.hex`
