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
- Teammate branch reviews (all branches, including all final branches)
- Decision worklog with timestamps

### Note on EE v3 Signoff
Daniel's EE v3 (D1+LUT+CG) was the RTL and flow base for the team's cleanest EE
signoff, achieved by Romeu on `romeu_no_violations`. Romeu identified that Daniel's
aggressive hold PNR settings (holdTargetSlack 0.2 CTS, 0.05 route) caused collateral
max_tran DRV damage. Reverting to standard settings (0.1) and applying SDC cleanup
produced the team's only fully DRV-clean EE design (0.451 nJ, 100% annotation).

---

## Teammates' Work

### Shanghong Lin -- HP Lead
- **D1**: Register-file architecture. Bulk LOAD/COMPUTE/STORE replaces per-butterfly SRAM access. 732 -> 220 cycles.
- **D2**: Added second parallel butterfly datapath. 220 -> 206 cycles.
- **D3**: Moved twiddle factors to firmware CSR preload. 206 -> 170 cycles.
- **D6**: 4-stage pipelined butterfly (FETCH/MUL1/MUL2/ADD). Targets ~60 MHz. 185 cycles at higher clock.
- **D5**: Wide 64-bit paired memory port. Halves LOAD/STORE. 121 cycles at 66 MHz.
- **HP-pnrClean** (FINAL): 24-bit narrowed D5, re-run PnR with tighter hold target. 0 setup violations, 0 hold violations (WNS +0.015 ns). 10 real max_tran DRV issues remain. Total power 0.560 mW (struct VCD). This is the team's final HP submission.

### Leonardo Castello -- HP Sign-Off
- **leonardo-final-signoff**: Took Shanghong's clean HP D5 checkpoint. Ran physical sim (setup + hold), VCD extraction, and VCD-annotated power report. Same timing results as HP-pnrClean. VCD power 2.795 mW (possibly incorrect VCD window -- anomalously high).

### Romeu Longo Malinski -- EE Signoff Lead
- **Earlier work**: Combined twiddle LUT + no-mem-reads + fastpaths + clock gating (comb_3_gc). 1.19 nJ.
- **romeu_no_violations** (FINAL): Took Daniel's EE v3 (D1+LUT+CG) and achieved FULL signoff cleanliness:
  - Added TLATNCAX2 simulation stub for behavioral sim
  - Removed stale SDC constraints and IO pin definitions
  - **Critical fix**: Reverted Daniel's aggressive hold PNR settings (holdTargetSlack 0.2->0.1 CTS, removed 0.05 route target) -- this eliminated hundreds of max_tran violations
  - ECO clock buffer for last antenna violation
  - VCD window correction (start 36.181386 ms, runtime 17.4993 us)
  - **Result**: 0 setup, 0 hold (WNS +0.002 ns), 0 real DRV, 0 DRC, 0 antenna, 100% VCD annotation. Accelerator energy 0.451 nJ. The only fully signoff-clean EE design in the team.

### Ali Sakr -- EE RFFT + Radix-4
- **Ali_final_final_w_o_cg**: RFFT + pure Radix-4 DIT. 32-point real FFT via 16-point complex FFT + Hermitian recombine. 130 cycles (vs 210 for D1+LUT). No clock gating. 0 timing violations, 487 real max_tran. Power 0.684 mW.
- **Ali_final_final_with_cg**: Same with manual ICG. 0 timing violations, 316 real max_tran. Power 0.242 mW (VCD). Energy ~2.59 nJ. Architecturally the fastest EE design but NOT DRV clean.

### Franz Josef -- EE_FINAL
- **EE_FINAL**: Ali's RFFT+Radix-4 design with Franz Josef's manual clock gating. 130 cycles. 0 timing violations, 791 real max_tran (worst DRV of all finals). Power 0.250 mW. Built on Franz Josef's NFS home (`franzjosefzuai`). Density 79.4%.

### Jiahui Que -- EE Clean PnR
- **Jiahui_FinalEE_cleanpnr**: D1 + hardcoded twiddle LUT + CG (same arch as Daniel EE v2). 210 cycles. 0 timing violations, 237 real max_tran. VCD power 0.236 mW. Good hold margin (+0.119 ns). Some merge conflicts in report files.

### Alessandro
- **v1**: Register-file FFT (similar to Shanghong D1). 220 cycles.
- **v2**: 2-stage pipeline variant targeting 80 MHz. **No PnR or verification.**
- **Alessandro_D5_pnr**: PnR attempt on D5. No final branch.
