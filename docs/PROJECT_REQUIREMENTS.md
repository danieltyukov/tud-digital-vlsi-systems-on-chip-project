# ET4351 Digital VLSI Systems on Chip -- FFT Accelerator Project

**Group 9 -- TU Delft**
**Team:** Shanghong Lin, Alessandro Cagnacci, Yaonan Hu, Leonardo Castello, Anastasis Kazakos
**Deadline:** Friday, April 10, 2026 at 16:59 CET

---

## 1. Project Overview

Design a hardware FFT accelerator integrated into a PicoRV32 RISC-V SoC. Two distinct design variants are required:

| Variant | Goal | Key Constraint |
|---------|------|----------------|
| **High-Performance (HP)** | Minimize latency | Latency < 61.00 us (baseline) |
| **Energy-Efficient (EE)** | Minimize energy | Energy < 24.6 nJ (baseline), clock >= 10 MHz |

Both designs share a **fixed core area of $596.4 \mu m \times 596.4 \mu m$** and must implement a correct N=32 FFT (5 stages, radix-2 DIT) that handles any audio input with a variable number of chunks.

### Baseline Reference

| Metric | Value |
|--------|-------|
| Core area | $596.4 \mu m \times 596.4 \mu m$ |
| Clock period | 83.33 ns (12 MHz) |
| Latency | $N = 732$ cycles $= 61.00 \mu s$ |
| Post-layout total power | $P = 0.403$ mW |
| Energy ($E = P \times T$) | 24.6 nJ |

Source code and scripts must originate from `/data/labs/2026/project`.

---

## 2. Hard Requirements (Knock-Out Criteria)

Failing any of these results in a failing grade regardless of other work.

### 2.1 Design Constraints

- [ ] **Fixed core area**: $596.4 \mu m \times 596.4 \mu m$ -- no changes allowed
- [ ] **Timing clean**: Setup and Hold timing reports must be clean (no violations)
- [ ] **DRV clean**: Design Rule Violations must be zero (max_tran violations are technically acceptable but risky -- avoid if possible)
- [ ] **Connectivity report**: Must be clean (zero errors)
- [ ] **Geometry report**: Must be clean (zero errors)
- [ ] **Antenna report**: Must be clean (zero errors)
- [ ] **Functional correctness**: FFT of any audio input with variable number of chunks must compute correctly
- [ ] **HP latency**: Strictly less than 61.00 us
- [ ] **EE energy**: Strictly less than 24.6 nJ, with minimum clock speed of 10 MHz
- [ ] **Accelerator protocol**: Software MUST start accelerator as soon as algorithm starts; accelerator MUST set finish flag when done
- [ ] **Testbench unmodified**: `tb_et4351.sv` MUST NOT be modified

### 2.2 Submission Deliverables

- [ ] **Report**: Max 6 pages (excluding cover page and appendices), 10pt font, IEEE double-column format
- [ ] **Report sections**: Must follow mandatory structure (Sections I through IV)
- [ ] **Short introduction**: Required
- [ ] **Both HP and EE designs presented** in the report

#### Directory: `finaldesign_hp/`
- [ ] `accel_audio.hex`
- [ ] `et4351.phys.sdf`
- [ ] `et4351.phys.v`

#### Directory: `finaldesign_ee/`
- [ ] `accel_audio.hex`
- [ ] `et4351.phys.sdf`
- [ ] `et4351.phys.v`

#### Supporting Files
- [ ] All SystemVerilog/Verilog source files
- [ ] All synthesis scripts
- [ ] All Place & Route scripts
- [ ] All signoff reports (as files)
- [ ] All activity annotation reports (as files)
- [ ] All full power reports (as files)
- [ ] Screenshots/excerpts of all reports in PDF appendix
- [ ] Proper technical terminology throughout
- [ ] Proofread report with clean, readable diagrams

---

## 3. Grading Criteria Breakdown (100%)

### Section 1: Architecture and Design Methodology

#### SoC Digital HW/SW Architecture -- 30%

| Grade | Criteria |
|-------|----------|
| **Excellent (9-10)** | Quantitative and exhaustive specs; bottleneck identified with numbers; memory hierarchy discussed; clean diagrams of SoC, memory map, and accelerator; creative power-performance-area tradeoff |
| **Good (7-8)** | Clear specs with justified HW/SW co-design; bottleneck analysis present; accelerator design choices explained; IP/memory selection justified quantitatively |
| **Adequate (5-6)** | Basic specs provided; some justification for design choices; diagrams present but may lack clarity |
| **Poor (<5)** | Missing specs, unjustified choices, no diagrams |

**What to demonstrate:**
- Clear functional specifications for the accelerator
- Justified HW/SW co-design partitioning
- Bottleneck analysis with quantitative data (cycle counts, utilization)
- Accelerator microarchitecture design choices with rationale
- IP and memory selection justified with numbers
- Clean block diagrams: SoC top-level, memory map, accelerator internals
- Creative exploration of the power-performance-area design space

### Section 2: Implementation

#### Design-Target-Driven Use of Tools -- 20%

| Grade | Criteria |
|-------|----------|
| **Excellent (9-10)** | Tool options/constraints creatively tuned for design target; documented with before/after comparisons; floorplan discussed with congestion analysis |
| **Good (7-8)** | Tools used appropriately with some optimization; floorplan considered |
| **Adequate (5-6)** | Default tool settings with minor adjustments |
| **Poor (<5)** | No evidence of tool exploration |

**What to demonstrate:**
- Synthesis constraints and options explored (clock targets, optimization effort, etc.)
- PnR floorplan decisions with congestion impact analysis
- Before/after comparisons when changing tool settings
- Clear documentation of which settings drove improvements

#### Signoff Verification -- 20%

| Grade | Criteria |
|-------|----------|
| **Excellent (9-10)** | Convincingly shown timing-clean and DRV-free; all reports in appendix with clear annotations |
| **Good (7-8)** | Timing-clean and DRV-free demonstrated; reports present |
| **Adequate (5-6)** | Reports present but not clearly explained |
| **Poor (<5)** | Missing or failing reports |

**What to demonstrate:**
- Post-layout timing reports: setup and hold both clean
- DRV report: zero violations (max_tran acceptable but flagged)
- Connectivity, Geometry, Antenna reports: all clean
- All reports included in appendix as screenshots/excerpts

### Section 3: Performance Metrics and Validation

#### Performance Metric Extraction -- 15%

| Grade | Criteria |
|-------|----------|
| **Excellent (9-10)** | Rigorous PPA extraction; activity annotation at ~100% coverage; annotation report and full power report in appendix |
| **Good (7-8)** | Metrics extracted correctly; good annotation coverage |
| **Adequate (5-6)** | Basic metrics present; annotation may be incomplete |
| **Poor (<5)** | Missing or incorrect metrics |

**What to demonstrate:**
- Power, performance, area metrics extracted rigorously
- Activity annotation performed with ~100% toggle coverage
- Annotation report included in appendix
- Full power report included in appendix

#### Quality of Post-Layout Simulations -- 15%

| Grade | Criteria |
|-------|----------|
| **Excellent (9-10)** | Exhaustive test specs derived from functional specs; readable simulation waveforms; activity annotation clearly highlighted |
| **Good (7-8)** | Good test coverage; waveforms present and readable |
| **Adequate (5-6)** | Basic simulation shown; waveforms present |
| **Poor (<5)** | Insufficient simulation evidence |

**What to demonstrate:**
- Test specifications derived exhaustively from functional specs
- Readable simulation waveforms with annotations
- Activity annotation section clearly highlighted in waveforms
- Multiple test cases (different audio inputs, variable chunks)

---

## 4. Current Status (as of 2026-03-18, Midterm)

### Midterm Oral Feedback (2026-03-18)

**Positive:** Microarchitecture explorations are strong — no dedicated comments or concerns from examiners on the design exploration work done so far.

**Action required:** Must proceed with physical implementation steps (synthesis, PnR, signoff) and produce validated results/outputs for the report. The back-end flow is now the critical path.

**Key examiner guidance:**

1. **Explanation is the main goal, not necessarily the best performance.** The report should prioritize *why* each design decision was made over raw speedup numbers. A well-reasoned design with clear justification scores higher than a fast design with no explanation.

2. **HP progress should be presented incrementally (bottleneck-driven).** Structure like a table: identify the current bottleneck → solve it → re-profile → identify the next bottleneck → solve → etc. Each optimization step should clearly show what bottleneck it addresses and what becomes the new bottleneck after the fix.

3. **Questions can be modified, but decisions must be explained in the report. Optimizations should be done at the end.** The team may adapt the project questions to their design choices, but every modification and design decision needs documented rationale. Tool/flow optimizations (aggressive clock targets, synthesis effort levels, etc.) should come after the base flow produces clean results.

**Next steps:** Study grading rubric and report template to understand expectations for later stages, then split remaining tasks across the team.

### 4.1 HP Design Progress

| ID | Optimization | Cycles | Speedup vs Baseline | Status |
|----|-------------|--------|---------------------|--------|
| D1 | Register-file architecture | 732 -> 220 | 3.33x | VERIFIED (synth) |
| D2 | 2x parallel butterflies | 220 -> 206 | 3.55x | VERIFIED (synth) |
| D3 | SW twiddle preload (CSR) | 206 -> 170 | 4.31x | VERIFIED (synth) |
| D4 | Preload input data (CSR) | 170 -> 42 | ~17.4x | PARKED (routing pressure from 2048-bit bus) |
| D5 | Wider memory bus / burst accelerator mem | -- | -- | OPEN |
| D6 | 4-stage pipelined butterfly (FETCH/MUL1/MUL2/ADD) | 185 cycles @ ~60 MHz -> ~3.1 us | ~20x | VERIFIED (synth) |
| D7 | Radix-4 FFT | -- | -- | OPEN |
| D8 | Design space exploration in physical design | -- | -- | OPEN |

**Best verified candidate for HP:** D6 at ~3.1 us latency (~20x improvement over baseline).

### 4.2 EE Design Progress (Early Stage)

Ideas explored:
- Radix-4 FFT
- Real-valued FFT (RFFT)
- Clock gating
- Offload computation to register file
- Trivial-twiddle fast paths (W = 1, W = -j)
- Removing recursive twiddle update logic
- No twiddle memory reads (LUT-based)
- Bit-width reduction

**Working variants on Romeu's branch:**
- `no_twiddle_mem_reads` -- eliminates SRAM reads for twiddle factors
- `fastpaths` -- skips full multiplication for trivial twiddle factors
- `no_recursive_twiddle` -- removes recursive twiddle computation

### 4.3 Build Flow

```
1. Generate firmware          firmware/Makefile
2. Behavioral simulation      sim_behav/  +  verify.py
3. Re-generate firmware       (single chunk for synthesis)
4. Synthesis                  synth/
5. Structural simulation      sim_struct/  +  verify.py  (with VCD)
6. Place & Route              pnr/
7. Physical simulation        sim_phys/  +  verify.py  (setup/hold)
```

### 4.4 Key Source Files

| File | Description |
|------|-------------|
| `src/design/accelerator_fft.v` | FFT core RTL |
| `src/design/accelerator.v` | Wrapper with CSR/SRAM interface |
| `src/design/accelerator_mem.v` | Accelerator data memory (flip-flop array, NOT SRAM macro) |
| `src/design/et4351.v` | Top-level SoC |
| `firmware/accel_audio.c` | C firmware |
| `src/testbench/tb_et4351.sv` | Testbench (DO NOT MODIFY) |

### 4.5 Memory Architecture (Three Separate Storage Blocks)

Understanding the memory hierarchy is critical for optimization. The SoC has **three distinct storage blocks**:

| Block | Location | Type | Size | Who accesses it |
|-------|----------|------|------|-----------------|
| **PicoSoC SRAM** | `picosoc.v` (`picosoc_mem`) | 4x `SRAM1RW256x8` macros | 1 KB (0x000-0x3FF) | CPU only |
| **CSR registers** | `accelerator.v` (`iomem_accel[0..34]`) | `reg [31:0]` flip-flops | 35 words | CPU writes, HW reads |
| **Accelerator memory** | `accelerator_mem.v` | `reg [31:0] mem[]` flip-flops | 64 words (v3) | CPU + FFT core (muxed) |

**Key insight:** `accelerator_mem` is **not** an SRAM macro -- it's a register file synthesized into flip-flops by Genus. Unlike the fixed `SRAM1RW256x8` macros, its interface is fully customizable: dual-port reads, wider datapaths, separate read/write ports are all possible. The only constraints are area and timing.

**Data flow per chunk:**
1. CPU writes input data: Flash -> QSPI -> PicoRV32 -> iomem bus -> `accelerator_mem`
2. FFT core loads: `accelerator_mem` -> internal `data_re[]/data_im[]` registers (64 cycles)
3. FFT compute: entirely on internal registers (accelerator_mem idle)
4. FFT stores back: internal registers -> `accelerator_mem` (64 cycles)
5. CPU reads results: `accelerator_mem` -> iomem bus -> PicoRV32 -> UART

**Why LOAD/STORE phases exist:** The FFT butterfly needs random access to any pair of data elements simultaneously (for 2x parallel units). `accelerator_mem` has a single address port (one word/cycle). The LOAD phase copies data into the multi-read internal register file; STORE copies it back.

**Optimization opportunities (D5):**
- Dual-port reads: load 2 words/cycle, cut LOAD_DATA from 64 to 32 cycles
- Wider datapaths: bank storage (even/odd) to output 2-4 words/cycle
- Separate CPU write port + FFT read port: enables double-buffering (CPU writes next chunk while FFT reads current)

See `docs/memory_architecture.md` for full technical details.

### 4.6 Theory Quick Reference

Key formulas and concepts from course lectures relevant to design decisions:

- **Setup slack** $= t_{clk} - t_{cq} - t_{pd} - t_{setup} > 0$ (frequency-dependent)
- **Hold slack** $= t_{cq} + t_{cd} - t_{hold} > 0$ (frequency-INDEPENDENT — violations are fatal)
- **Switching power**: $P_{sw} \sim \alpha \cdot f_{clk} \cdot V_{DD}^2 \cdot C_L$
- **Energy per task**: $E = P_{total} \times N_{cycles} \times T_{clk}$
- **DRVs present → timing analysis untrustworthy** (must fix before signoff)
- **Clock tree = ~30% of power** (CTS also fixes hold violations)
- **Congestion is your enemy. Setup slack is your exchange currency.**

See `docs/theory_reference.md` for full theory reference with project-specific annotations.

---

## 5. Remaining TODO Items

### CRITICAL (Must complete -- blocking submission)

#### Front-End (RTL)
- [ ] **Finalize HP RTL**: Select best HP candidate (D6 pipelined butterfly is leading at ~3.1 us) and freeze RTL
- [ ] **Finalize EE RTL**: Select and integrate best EE optimizations (from `no_twiddle_mem_reads`, `fastpaths`, `no_recursive_twiddle` branches); verify energy < 24.6 nJ
- [ ] **Behavioral simulation**: Both HP and EE pass `verify.py` with multiple audio inputs and variable chunk counts
- [ ] **Firmware**: Finalize `accel_audio.c` for both HP and EE (may differ if CSR interfaces differ)

#### Back-End (Physical Design)
- [ ] **Synthesis (HP)**: Run synthesis with optimized constraints; target aggressive clock period for HP
- [ ] **Synthesis (EE)**: Run synthesis with power-optimized constraints; clock >= 10 MHz
- [ ] **PnR (HP)**: Place & Route with timing closure; resolve any congestion issues
- [ ] **PnR (EE)**: Place & Route with power-optimized floorplan
- [ ] **Timing signoff (HP)**: Setup and Hold reports must be clean
- [ ] **Timing signoff (EE)**: Setup and Hold reports must be clean
- [ ] **DRV signoff (HP)**: Zero DRV violations
- [ ] **DRV signoff (EE)**: Zero DRV violations
- [ ] **Connectivity/Geometry/Antenna (HP)**: All clean
- [ ] **Connectivity/Geometry/Antenna (EE)**: All clean
- [ ] **Physical simulation (HP)**: Post-layout sim with SDF back-annotation passes `verify.py`
- [ ] **Physical simulation (EE)**: Post-layout sim with SDF back-annotation passes `verify.py`

#### Deliverables
- [ ] **Generate `finaldesign_hp/`**: `accel_audio.hex`, `et4351.phys.sdf`, `et4351.phys.v`
- [ ] **Generate `finaldesign_ee/`**: `accel_audio.hex`, `et4351.phys.sdf`, `et4351.phys.v`

### HIGH (Required for good grade)

#### Power Analysis
- [ ] **Activity annotation (HP)**: Run VCD-based annotation; achieve ~100% toggle coverage
- [ ] **Activity annotation (EE)**: Run VCD-based annotation; achieve ~100% toggle coverage
- [ ] **Full power report (HP)**: Extract post-layout power numbers
- [ ] **Full power report (EE)**: Extract post-layout power numbers
- [ ] **Compute final metrics**: Latency (cycles x clock period), Power (from report), Energy (P x T), Area (from PnR)

#### Report -- Section 1: Architecture and Design Methodology
- [ ] Write clear functional specifications for the accelerator
- [ ] Document HW/SW co-design partitioning with justification
- [ ] Perform and document bottleneck analysis with quantitative data
- [ ] Justify accelerator microarchitecture choices (pipelining, parallelism, etc.)
- [ ] Justify IP and memory selection with numbers
- [ ] Create clean block diagrams: SoC top-level, memory map, accelerator internals
- [ ] Discuss power-performance-area tradeoff exploration

#### Report -- Section 2: Implementation
- [ ] Document synthesis tool options/constraints and their impact
- [ ] Document PnR floorplan decisions with congestion analysis
- [ ] Include before/after comparisons for tool setting changes
- [ ] Compile all signoff reports into appendix with annotations

#### Report -- Section 3: Performance Metrics and Validation
- [ ] Extract and tabulate PPA metrics for both HP and EE
- [ ] Include annotation reports in appendix
- [ ] Include full power reports in appendix
- [ ] Capture readable simulation waveforms
- [ ] Highlight activity annotation in waveforms
- [ ] Document test specifications derived from functional specs

### MEDIUM (Potential additional improvements)

#### Design Exploration
- [ ] **D5 -- Wider memory bus**: Explore dual-port reads, banked storage, or separate CPU/FFT ports to cut LOAD/STORE from 128 to 32-64 cycles (see `docs/memory_architecture.md` for full analysis)
- [ ] **D7 -- Radix-4 FFT**: Could reduce stage count from 5 to 3 (significant cycle savings)
- [ ] **D8 -- Physical design exploration**: Explore placement/routing strategies, clock tree options
- [ ] **D4 revisit**: Investigate whether 2048-bit bus routing pressure can be resolved with floorplan changes
- [ ] **Clock gating (EE)**: Add fine-grained clock gating for idle pipeline stages
- [ ] **Bit-width reduction (EE)**: Evaluate if reduced precision still passes verification
- [ ] **RFFT optimization (EE)**: Exploit real-valued input symmetry to halve computation

#### Report Polish
- [ ] Proofread entire report
- [ ] Verify all diagrams are clean and readable
- [ ] Check proper technical terminology throughout
- [ ] Ensure IEEE double-column formatting is correct
- [ ] Verify page count <= 6 (excl. cover and appendices)
- [ ] Cross-check all numbers in report against actual tool outputs

---

## 6. Timeline

### Week 6: March 17--22 (Front-End Closure)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| Mon Mar 17 | Midterm presentation | All | Done |
| Tue Mar 18 | Finalize HP RTL (freeze D6 pipelined butterfly) | -- | TODO |
| Wed Mar 19 | Finalize EE RTL (merge best EE optimizations) | -- | TODO |
| Thu Mar 20 | Behavioral sim: HP + EE pass all tests | -- | TODO |
| Fri Mar 21 | Firmware finalized for both variants | -- | TODO |
| Sat Mar 22 | Buffer / fix any remaining RTL issues | -- | TODO |

### Week 7: March 23--29 (Back-End and Optimization)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| Mon Mar 23 | Synthesis: HP (aggressive clock) | -- | TODO |
| Tue Mar 24 | Synthesis: EE (power-optimized) | -- | TODO |
| Wed Mar 25 | PnR: HP (timing closure) | -- | TODO |
| Thu Mar 26 | PnR: EE (power-optimized floorplan) | -- | TODO |
| Fri Mar 27 | Signoff: timing, DRV, connectivity, geometry, antenna (both) | -- | TODO |
| Sat Mar 28 | Physical simulation (both HP and EE) | -- | TODO |
| Sun Mar 29 | Power analysis: VCD annotation + full power reports (both) | -- | TODO |

### Week 8: March 30 -- April 3 (Testing and Report)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| Mon Mar 30 | Final verification: all tests pass post-layout (both) | -- | TODO |
| Tue Mar 31 | Report: Section 1 (Architecture) | -- | TODO |
| Wed Apr 1 | Report: Section 2 (Implementation) | -- | TODO |
| Thu Apr 2 | Report: Section 3 (Metrics and Validation) | -- | TODO |
| Fri Apr 3 | Report: Introduction + Appendices + Proofreading | -- | TODO |

### Week 9: April 4--10 (Final Polish and Submission)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| Mon Apr 4 | Report review and revision | All | TODO |
| Tue Apr 5 | Final design directories assembled and verified | -- | TODO |
| Wed Apr 6 | Dry-run: verify all deliverables are complete | All | TODO |
| Thu Apr 7 | Final report polish | All | TODO |
| Fri Apr 8 | Buffer day | -- | -- |
| Wed Apr 9 | Final checks | All | TODO |
| **Fri Apr 10** | **SUBMISSION DEADLINE -- 16:59 CET** | **All** | **TODO** |

---

## 7. Submission Checklist

Run through this checklist before submitting. Every item must be checked.

### Design Files
- [ ] `finaldesign_hp/accel_audio.hex` exists and is correct
- [ ] `finaldesign_hp/et4351.phys.sdf` exists and is correct
- [ ] `finaldesign_hp/et4351.phys.v` exists and is correct
- [ ] `finaldesign_ee/accel_audio.hex` exists and is correct
- [ ] `finaldesign_ee/et4351.phys.sdf` exists and is correct
- [ ] `finaldesign_ee/et4351.phys.v` exists and is correct
- [ ] All SystemVerilog/Verilog source files included
- [ ] All synthesis scripts included
- [ ] All PnR scripts included

### Signoff Reports (as files)
- [ ] HP: Setup timing report -- clean
- [ ] HP: Hold timing report -- clean
- [ ] HP: DRV report -- clean (no violations, or only max_tran)
- [ ] HP: Connectivity report -- clean
- [ ] HP: Geometry report -- clean
- [ ] HP: Antenna report -- clean
- [ ] EE: Setup timing report -- clean
- [ ] EE: Hold timing report -- clean
- [ ] EE: DRV report -- clean (no violations, or only max_tran)
- [ ] EE: Connectivity report -- clean
- [ ] EE: Geometry report -- clean
- [ ] EE: Antenna report -- clean

### Power and Annotation Reports (as files)
- [ ] HP: Activity annotation report (~100% coverage)
- [ ] HP: Full power report
- [ ] EE: Activity annotation report (~100% coverage)
- [ ] EE: Full power report

### Report
- [ ] Cover page present
- [ ] Introduction (short)
- [ ] Section I: Architecture and Design Methodology
- [ ] Section II: Implementation (tools, floorplan, signoff)
- [ ] Section III: Performance Metrics and Validation
- [ ] Section IV: Conclusion / both HP and EE presented
- [ ] Appendix: All signoff reports (screenshots/excerpts)
- [ ] Appendix: All annotation reports (screenshots/excerpts)
- [ ] Appendix: All full power reports (screenshots/excerpts)
- [ ] IEEE double-column format
- [ ] 10pt font
- [ ] <= 6 pages (excl. cover and appendices)
- [ ] Proper technical terminology
- [ ] Proofread -- no spelling/grammar errors
- [ ] All diagrams clean and readable
- [ ] All numbers cross-checked against tool outputs

### Functional Verification
- [ ] HP: Behavioral simulation passes `verify.py` (multiple chunks)
- [ ] HP: Structural simulation passes `verify.py`
- [ ] HP: Physical simulation (setup) passes `verify.py`
- [ ] HP: Physical simulation (hold) passes `verify.py`
- [ ] EE: Behavioral simulation passes `verify.py` (multiple chunks)
- [ ] EE: Structural simulation passes `verify.py`
- [ ] EE: Physical simulation (setup) passes `verify.py`
- [ ] EE: Physical simulation (hold) passes `verify.py`
- [ ] Testbench `tb_et4351.sv` is UNMODIFIED from original

### Performance Targets
- [ ] HP latency < 61.00 us (baseline) -- actual: ______ us
- [ ] EE energy < 24.6 nJ (baseline) -- actual: ______ nJ
- [ ] EE clock frequency >= 10 MHz -- actual: ______ MHz

---

## Quick Reference: Key Formulas

- **Latency:** $L = N_{cycles} \times T_{clk}$
- **Energy:** $E = P_{total} \times L = P_{total} \times N_{cycles} \times T_{clk}$
- **Power:** From post-layout power report with activity annotation
- **Speedup:** $S = \frac{L_{baseline}}{L_{design}} = \frac{61.00 \mu s}{L_{design}}$
- **Energy reduction:** $R = \frac{E_{baseline}}{E_{design}} = \frac{24.6 \text{ nJ}}{E_{design}}$

---

*Last updated: 2026-03-18*
