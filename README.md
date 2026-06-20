# ET4351 — Digital VLSI Systems on Chip Project (Group 9)

A hardware **FFT accelerator** for a PicoRV32 RISC-V SoC (`et4351`), taken through the
full ASIC flow — RTL → constraints → synthesis (Genus) → place-and-route (Innovus) →
signoff → post-layout simulation → power analysis — on the TU Delft `gpdk045` 45 nm PDK.

Two complete tape-out-ready designs were delivered against a common SoC:

- **HP** — High-Performance: minimise FFT latency.
- **EE** — Energy-Efficient: minimise total energy.

> TU Delft, Faculty of EEMCS — Academic Year 2025/2026. Final submission delivered
> 10 April 2026. This repository is the personal archive of **Daniel Tyukov** (team of 8).

📊 **[See SHOWCASE.md](SHOWCASE.md)** for an illustrated tour of both architectures with
diagrams and results.

---

## Final results

Baseline (given): 596.4 µm × 596.4 µm core, 12 MHz, 732 cycles, **61.00 µs** latency,
**0.403 mW** accelerator power, **24.6 nJ** energy, N = 32 complex FFT.

| Metric            | Baseline | **HP design**        | **EE design**            |
|-------------------|----------|----------------------|--------------------------|
| Architecture      | iterative | reg-file + pipelined butterflies | 2-stage Radix-4 RFFT + clock gating |
| Clock             | 12 MHz   | **66.2 MHz** (15.1 ns) | 12 MHz (83.33 ns)        |
| Cycles / chunk    | 732      | **121**              | —                        |
| Latency           | 61.00 µs | **≈1.83 µs (~33×)**  | 10.83 µs (first chunk)   |
| Total energy      | 24.6 nJ  | 5.107 nJ (4.8×)      | **2.59 nJ (9.5×)**       |
| Total power       | 0.403 mW | 2.795 mW             | **0.239 mW**             |
| Cell area (`et4351`) | —     | 251,294 µm²          | 268,311 µm²              |

**Signoff status (post-route):**

| Check            | HP                       | EE                       |
|------------------|--------------------------|--------------------------|
| Setup WNS / viol | +0.226 ns / **0**        | +35.299 ns / **0**       |
| Hold WNS / viol  | +0.015 ns / **0**        | +0.056 ns / **0**        |
| SI glitches      | **0**                    | 2 (within risk budget)   |
| DRV / connectivity / antenna | clean        | clean                    |

> HP trades higher instantaneous power for a ~33× latency cut, so its *energy* still
> drops 4.8×. EE keeps the 12 MHz baseline clock and attacks power directly via a
> Radix-4 real-FFT datapath plus manual integrated clock gating (TLATNCAX2 ICG cells).

---

## Repository layout

```
.
├── Group9/                  ← OFFICIAL FINAL SUBMISSION (graded deliverable)
│   ├── finaldesign_hp/       High-Performance design
│   │   ├── src/{design,sdc,srams,testbench}/   RTL, constraints, SRAM, TB
│   │   ├── scripts_synth/    Genus synthesis scripts
│   │   ├── scripts_pnr/      Innovus place-and-route scripts
│   │   ├── Reports/          signoff: timing / hold / DRV / area / power
│   │   ├── accel_audio.hex   firmware image      ┐
│   │   ├── et4351.phys.v     signoff netlist     ├ required deliverables
│   │   └── et4351.phys.sdf   signoff timing      ┘
│   ├── finaldesign_ee/       Energy-Efficient design (same structure; pnr/, reports/)
│   └── ET4351_Project_Report___Groupred (1).pdf   submitted 6-page report (IEEE)
│
├── daniels_work/            ← my personal exploration & verification
│   ├── baseline/  hp_design*/  ee_design*(v1–v5)/   design iterations
│   ├── finaldesign_hp/  finaldesign_ee/             my full-flow runs
│   ├── results/             per-experiment analysis notes (HP, EE, power, SDC)
│   ├── report_sections/     drafted report sections
│   ├── WORKLOG.md           chronological worklog
│   └── CONTRIBUTION_SUMMARY.md
│
├── docs/                    course material: project brief, requirements, rubric,
│                            midterm slides/notes, theory reference
├── report/                  LaTeX source of the report (report.tex, IEEEtran.cls)
├── teammate_reviews/        my reviews of each teammate's branch
└── tools/                   helper scripts (md_to_pdf.py, connect-et4351.sh)
```

The canonical deliverable graders receive is **`Group9/`**. Everything else is supporting
material that documents how the designs were explored, verified, and reported.

---

## Toolflow

EDA tools (TU Delft server): **Genus** (synthesis), **Innovus** (PnR), **QuestaSim/Xcelium**
(simulation). End-to-end flow per design:

1. Build firmware → `accel_audio.hex`
2. Behavioural simulation + `verify.py`
3. Synthesis (`scripts_synth/`)
4. Structural simulation with VCD + `verify.py`
5. Place & route (`scripts_pnr/` / `pnr/`)
6. Physical (setup + hold) simulation + `verify.py`
7. Power analysis with VCD activity annotation → reports under `Reports/` (HP) / `reports/` (EE)

Key RTL: `src/design/accelerator_fft.v` (FFT core), `accelerator.v` (CSR/SRAM wrapper),
`et4351.v` (top-level SoC), `picorv32.v` (RISC-V core). Constraints: `src/sdc/et4351.sdc`.
The testbench `src/testbench/tb_et4351.sv` must not be modified.

---

## Team

Group 9 — 8 members (TU Delft 2025/2026). Per-member primary responsibilities are listed
in **§I of the report PDF**. This repository documents the full-flow / baseline / signoff /
documentation work and the cross-branch reviews carried out by Daniel Tyukov.

---

## Notes

- **Large history (~1.5 GB).** Multi-MB signoff netlists, SDFs, and power-report dumps are
  versioned here. For a fast checkout use a shallow clone:
  ```bash
  git clone --depth 1 git@github.com:danieltyukov/tud-digital-vlsi-systems-on-chip-project.git
  ```
- `.gitignore` excludes regenerable EDA artifacts (`*.gds`, `*.spef`, `*.vcd`, `*.enc`,
  databases, logs). The signoff `et4351.phys.sdf` is explicitly **kept** as a deliverable.
- `credentials.txt` (server login) is intentionally untracked — do not commit it.
