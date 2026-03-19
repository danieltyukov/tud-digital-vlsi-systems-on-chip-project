# Contribution Summary

## Daniel's Work

### HP Design (D1 Register-File)
- **RTL**: Used Shanghong's D1 `accelerator_fft.v` — register file replaces per-butterfly SRAM access
- **Files modified**: None — D1 is a drop-in replacement, same firmware and wrapper as baseline
- **Flow**: Ran full back-end: firmware build → behav sim → synthesis → struct sim (VCD) → PnR → phys sim (setup + hold)
- **Result**: 220 cycles, 18.33 us, all sims pass
- **Issue found**: D3 (twiddle preload) hangs in structural sim — accelerator never completes post-synthesis. Fell back to D1.

### EE Design (D1 + Hardcoded Twiddle LUT)
- **RTL**: New `accelerator_fft.v` — combines D1 register-file with Romeu's twiddle LUT concept
- **What was changed vs D1**:
  - Removed `S_LOAD_TWIDDLE` FSM state (twiddles no longer read from SRAM)
  - Removed `tw_re[0:4]`, `tw_im[0:4]` twiddle register file
  - Removed recursive twiddle update (`w = w * w_m`) and `w_re`, `w_im` registers
  - Added `twiddle_lut(m, k)` function with hardcoded Q12 values for all 31 twiddle entries
  - Butterfly now reads twiddle directly from LUT instead of running registers
- **What was changed vs Romeu's no_recursive_twiddle**:
  - Applied the LUT concept to D1 architecture (register-file, 5-state FSM) instead of baseline (9-state per-butterfly FSM)
  - Saves 10 extra cycles by eliminating LOAD_TWIDDLE entirely (Romeu kept the baseline FSM with dead `READ_W_M_*` states)
- **Files modified**: `src/design/accelerator_fft.v` only — wrapper and firmware unchanged from baseline
- **Flow**: Full back-end: behav sim → synthesis → struct sim → PnR → phys sim (setup + hold)
- **Result**: 210 cycles, 17.50 us, ~12.2 nJ, all sims pass

### Infrastructure & Documentation
- Baseline full flow reproduction with all signoff reports
- Project repo organization (docs/, scripts/, tools/, report/)
- Reusable scripts: SSH, report extraction, metrics extraction
- Report section drafts (Sections I-III)
- Theory reference from course lectures
- Memory architecture analysis
- Teammate branch reviews (all branches)
- Decision worklog with timestamps

---

## Teammates' Work

### Shanghong Lin — HP Lead
- **D1**: Register-file architecture (`accelerator_fft.v`, `accelerator.v`, `accelerator_mem.v`). Bulk LOAD/COMPUTE/STORE replaces per-butterfly SRAM access. 732 → 220 cycles.
- **D2**: Added second parallel butterfly datapath. 220 → 206 cycles.
- **D3**: Moved twiddle factors to firmware CSR preload. New firmware (`accel_audio.c`), new CSR interface in wrapper, halved SRAM. 206 → 170 cycles.
- **D6**: 4-stage pipelined butterfly (FETCH/MUL1/MUL2/ADD). Targets ~60 MHz. 185 cycles at higher clock.
- **D5**: Wide 64-bit paired memory port in `accelerator_mem.v`. Halves LOAD/STORE. 121 cycles at 48 MHz = 2.52 us.

### Romeu — EE Lead
- **no_recursive_twiddle**: Added `twiddle_lut()` function to baseline `accelerator_fft.v`. Replaced recursive `w = w * w_m` with direct LUT lookup. −3.2% energy.
- **no_twiddle_mem_reads**: Replaced SRAM reads for `w_m` with stage-local constants. −2.4% energy.
- **fastpaths**: Added trivial twiddle detection (+1, −1, +j, −j) with sign-flip/swap bypass. −0.3% energy.
- **comb_3**: Combined all three above in one RTL. −18.4% energy (20.1 nJ).
- **comb_3_gc**: Added manual clock gating (2 ICG cells in `accelerator.v`) — gates FFT and memory clocks when idle. −95.2% energy (1.19 nJ). 11 ECO iterations for hold closure.

### FranzJosef
- **Radix-4**: Single commit on D1 branch. Mixed radix-4/2 FFT (2 radix-4 stages + 1 radix-2). Added `digit_reverse_mixed()` to firmware. 176 cycles claimed. **Unverified** — no sim, no synthesis, no PnR.

### Alessandro
- **v1**: Register-file FFT (similar to Shanghong D1). 220 cycles.
- **v2**: 2-stage pipeline variant targeting 80 MHz. **No PnR or verification.**
