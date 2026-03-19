# EE Summary

## Final Working EE Design

The final EE design that worked is based on:

- the merged low-toggle FFT RTL in `/home/nfs/rlongomalinski/project_ee/src/design/accelerator_fft.v`
- local accelerator clock gating in `/home/nfs/rlongomalinski/project_ee/src/design/accelerator.v`
- a final clean post-route checkpoint in `/home/nfs/rlongomalinski/project_ee/pnr/checkpoints/et4351_cg_fix_n494_from_drv_iter11.enc`

What was implemented in the FFT:

- local twiddle LUT instead of recursive twiddle generation
- no twiddle-memory reads
- fast paths for trivial twiddles (`+1`, `-1`, `+j`, `-j`)

What was implemented physically:

- local clock gating for the accelerator only
- fresh ECO rebuild from `cg_drv_iter1`
- local perturbation `soc/cpu/FE_OFC1177_n_495 -> INVX2`
- preserved hold-fix ECO `soc/cpu/FE_PHC12280_n_2025 -> DLY2X1`
- preserved hold-fix ECO `soc/cpu/FE_PHC11129_iomem_addr_14 -> DLY2X1`
- preserved hold-fix ECO `soc/spimemio/FE_PHC10756_xfer_resetn -> DLY3X1`

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

- WNS: `33.733 ns`
- TNS: `0`
- violating paths: `0`

Post-route hold:

- WNS: `0.000 ns`
- TNS: `0`
- violating paths: `0`

DRV:

- `0` real `max_tran`
- remaining total `max_tran`: `4` nets / `12` terms, all non-real flash IO entries

## Final Energy Result

VCD capture window:

- `60.997560 us`

Post-route accelerator power:

- `0.01942 mW`

Final accelerator energy:

- `1.184573 nJ`

Baseline energy:

- `24.6 nJ`

Improvement:

- `95.18%` lower than baseline

Power-flow notes:

- VCD annotation coverage: `100%`
- VCD-derived clock frequency: about `11.90 MHz`

## Final Status

The final kept EE design:

- is functionally correct
- is setup clean
- is hold clean
- is real-DRV clean
- is connectivity clean
- is DRC clean
- is antenna clean
- meets the EE frequency requirement (`>= 10 MHz`)
- beats the EE baseline energy target

## Final Artifacts

Main outputs:

- `/home/nfs/rlongomalinski/project_ee/pnr/outputs/et4351.phys.v`
- `/home/nfs/rlongomalinski/project_ee/pnr/outputs/et4351.phys.sdf`
- `/home/nfs/rlongomalinski/project_ee/pnr/outputs/et4351.phys.gds`

Packaged copies:

- `/home/nfs/rlongomalinski/project_ee/finaldesign/et4351.phys.v`
- `/home/nfs/rlongomalinski/project_ee/finaldesign/et4351.phys.sdf`
- `/home/nfs/rlongomalinski/project_ee/finaldesign/et4351.phys.gds`
- `/home/nfs/rlongomalinski/project_ee/finaldesign/accel_audio.hex`
