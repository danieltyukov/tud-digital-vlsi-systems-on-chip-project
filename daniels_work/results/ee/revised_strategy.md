# EE Revised Strategy

## Problem with using same design for HP and EE
The rubric knock-out criteria states: "Both a High-Performance (HP) and an Energy-Efficient (EE) accelerator design are presented, with `finaldesign_hp/` and `finaldesign_ee/` directories each containing accel_audio.hex, et4351.phys.sdf, and et4351.phys.v."

If HP and EE submit identical files, the examiner will likely reject this — the intent is two DIFFERENT designs exploring different parts of the PPA space.

## Revised approach: D1 + no_recursive_twiddle for EE

Combine the D1 register-file architecture with the `no_recursive_twiddle` optimization:
- D1 gives 220 cycles (3.33× fewer than baseline)
- `no_recursive_twiddle` reduces switching activity in the twiddle-generation path
- This produces a **genuinely different RTL** from the HP D1 design
- Energy: fewer cycles × less switching = significantly under 24.6 nJ

### Implementation
1. Start from D1 `accelerator_fft.v`
2. Apply the no_recursive_twiddle modification: replace the recursive `w = w * w_m` update with hardcoded LUT indexed by (stage, k)
3. This changes the COMPUTE phase logic but keeps the same LOAD/STORE/FSM structure
4. Re-run full flow: synth → struct sim → PnR → phys sim → power

### Why this is a distinct design
- HP (D1): Register-file + standard recursive twiddle computation
- EE (D1 + no_recursive_twiddle): Register-file + LUT-based twiddle (less switching)
- Different `accelerator_fft.v` → different synthesis → different netlist → different PnR
