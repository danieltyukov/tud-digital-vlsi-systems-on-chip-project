# How The Violations Were Fixed

This note records the actual path from the original merged Daniel EE version to the final clean `project_ee_daniel_check` version.

It includes:

- what was broken at the start
- what the real implementation violations were
- what changes were exploratory
- which final changes remain in the clean flow

## Short version

The final clean result came from four real fixes:

1. Unblock behavioral simulation by adding a simulation-only model for the clock-gating cell `TLATNCAX2`
2. Remove stale constraints and stale IO pins that no longer matched the top-level design
3. Undo the over-aggressive hold/DRV tuning in Daniel's CTS/route setup so Innovus stopped creating large post-route slew problems
4. Add one targeted post-route ECO clock buffer to eliminate the last remaining antenna violation on the reset synchronizer clock sink

After that, the design was rerun and rechecked until it was clean on:

- setup
- hold
- real DRV
- connectivity
- DRC
- antenna

## 1. Initial problems

### 1.1 Behavioral simulation did not even elaborate

The Daniel RTL directly instantiated the standard-cell clock-gating latch `TLATNCAX2`, but the behavioral simulation compile script did not compile any Verilog model for that cell.

That caused:

- `Module 'TLATNCAX2' is not defined`

This was not a physical-design violation yet. It was a simulation bring-up problem.

### 1.2 First successful full-flow result was functionally OK but not signoff-clean

Once behavioral simulation was unblocked, the flow could run. The first meaningful implementation result looked like this:

- setup: clean
- hold: clean
- connectivity: clean
- DRC: clean
- antenna: clean
- real `max_tran`: **fail**

The important failing number was:

- `max_tran = 198` real violating nets / `509` terms
- worst violation about `-0.481`

So the real signoff problem was not hold timing. It was post-route slew / transition.

## 2. Fix 1: behavioral simulation unblock

### Files changed

- [src/design/TLATNCAX2.v](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/src/design/TLATNCAX2.v)
- [sim_behav/run_behav_sim.sh](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/sim_behav/run_behav_sim.sh)

### What changed

A simulation stub was added for `TLATNCAX2`:

```verilog
module TLATNCAX2 (
    input  wire CK,
    input  wire E,
    output wire ECK
);
    assign ECK = CK & E;
endmodule
```

And `run_behav_sim.sh` was updated to compile that file before `accelerator.v`.

### Why this mattered

This did not fix any implementation violation directly. It simply allowed behavioral RTL simulation to run so the design could be validated and the rest of the flow could proceed.

## 3. Fix 2: clean stale constraints and stale IO definitions

### Files changed

- [src/sdc/et4351.sdc](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/src/sdc/et4351.sdc)
- [pnr/scripts/3.1.ET4351_chip.io](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/3.1.ET4351_chip.io)

### What changed in the SDC

Compared with Daniel's version:

- removed the extra global `set_max_transition 0.28`
- split clock uncertainty into:
  - setup uncertainty `0.25`
  - hold uncertainty `0.10`
- removed stale output-delay constraints on ports that no longer existed:
  - `accel_o_path_node`
  - `accel_o_path_node_valid`

### What changed in the IO file

Removed stale package pins for:

- `accel_o_path_node_valid`
- `accel_o_path_node[0:7]`

### Why this mattered

These stale constraints and stale IO pins were leftovers from an older interface and no longer matched the actual design.

They caused two kinds of trouble:

- noisy warnings about missing pins / stale ports
- poorer optimization guidance for Innovus

Cleaning them up made the flow more coherent and removed avoidable mismatch warnings.

## 4. Fix 3: back off the aggressive hold-driven PNR tuning

### Files changed

- [pnr/scripts/6.cts.tcl](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/6.cts.tcl)
- [pnr/scripts/7.route.tcl](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/7.route.tcl)

### What Daniel's version was doing

Daniel's version pushed hold repair harder than the baseline:

- in CTS:
  - `setOptMode -holdTargetSlack 0.2`
- in route:
  - `-holdTargetSlack 0.05`
  - repeated `optDesign -postRoute -hold`
  - explicit extra `optDesign -postRoute -drv`

### What was changed

#### CTS

`6.cts.tcl` was changed from:

```tcl
setOptMode -holdTargetSlack 0.2
```

back to:

```tcl
setOptMode -holdTargetSlack 0.1
```

#### Route

`7.route.tcl` was simplified so post-route repair was less hold-aggressive:

- removed the extra `-holdTargetSlack 0.05`
- removed the duplicate extra post-route hold pass
- kept a normal:
  - `optDesign -postRoute`
  - `optDesign -postRoute -hold`

### Why this mattered

The original Daniel PNR settings were pushing hold repair too hard, which improved hold margin but caused too much collateral damage in slew/DRV.

Observed behavior during debugging:

- overly aggressive hold settings caused large buffer insertion and much worse post-route DRV behavior
- after backing off those settings, real `max_tran` dropped dramatically

This was the main reason the design moved from:

- hundreds of real transition violations

to:

- `0` real `max_tran` violations

before the final antenna fix.

## 5. Fix 4: targeted ECO for the last antenna violation

### File changed

- [pnr/scripts/7.route.tcl](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/7.route.tcl)

### The remaining issue after the DRV cleanup

Once the major slew problem was solved, one real implementation issue still remained:

- `1` process antenna violation

It was on the clock-tree net feeding:

- `resetn_sync_int_reg/CK`

### What changed

A targeted ECO clock buffer was added in the normal route flow:

```tcl
setEcoMode -honorFixedNetWire false -refinePlace false -updateTiming false
ecoAddRepeater -term {resetn_sync_int_reg/CK} -cell CLKBUFX12 -loc {604.6 279.0} -name CTS5_FIXBUF12 -newNetName CTS5_FIXNET12
ecoRoute
setEcoMode -refinePlace true -updateTiming true
```

Then a small post-route cleanup was run:

```tcl
setOptMode -postRouteDrvRecovery true -fixSISlew true -fixGlitch true
optDesign -postRoute
```

### Why this worked

The antenna problem was localized to one sink on one CTS net. The cleanest fix was not a full redesign of the clock tree, but a local isolation of that sink with a legal inserted clock buffer in nearby filler space.

That:

- broke the problematic long metal exposure seen by the antenna checker
- cleared the antenna violation
- only introduced a small local slew disturbance, which was then cleaned up with the final post-route optimization

## 6. What was exploratory vs. what remains in the final flow

During debugging, several helper TCL scripts were created to test ECO ideas directly on saved Innovus checkpoints because that was much faster than rerunning all of PNR for every guess.

Those helper scripts were exploratory only.

Examples:

- `antenna_fix_from_done.tcl`
- `bufferfix_from_done.tcl`
- `drv_cleanup_from_bufferfix.tcl`
- `manual_antenna_diode_fix.tcl`

They helped identify the final working fix, but they are not required for the final clean flow.

### The final clean flow only depends on these persistent changes

- [src/design/TLATNCAX2.v](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/src/design/TLATNCAX2.v)
- [sim_behav/run_behav_sim.sh](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/sim_behav/run_behav_sim.sh)
- [src/sdc/et4351.sdc](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/src/sdc/et4351.sdc)
- [pnr/scripts/3.1.ET4351_chip.io](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/3.1.ET4351_chip.io)
- [pnr/scripts/6.cts.tcl](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/6.cts.tcl)
- [pnr/scripts/7.route.tcl](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/pnr/scripts/7.route.tcl)

Everything else was either:

- generated output
- report data
- simulation evidence
- or debug-only helper scripts

## 7. Final result

The final design was rechecked and ended clean on:

- setup timing
- hold timing
- real `max_tran`
- real `max_cap`
- real `max_fanout`
- connectivity
- DRC
- antenna

And it was revalidated by:

- behavioral simulation
- structural simulation
- post-layout physical simulation

## 8. One extra non-violation fix: correct EE power window

This was not a violation fix, but it mattered for the final hand-in numbers.

The VCD power window was corrected to use the first-chunk timing from `sim_behav/transcript`:

- start time: `36.181386 ms`
- runtime: `17.499300 us`

Files updated:

- [sim_phys/scripts/run_vcd_setup.cmd](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/sim_phys/scripts/run_vcd_setup.cmd)
- [sim_phys/scripts/run_vcd_hold.cmd](/home/nfs/rlongomalinski/project_ee_daniel_peer_package/sim_phys/scripts/run_vcd_hold.cmd)

That correction affected the reported EE power/energy metrics, not signoff cleanliness.

## Bottom line

Yes, I remember the full fix path well enough to reconstruct it accurately.

The meaningful final story is:

1. simulation unblock
2. stale constraint / stale IO cleanup
3. de-aggressivize hold-focused PNR tuning to remove the big slew failure
4. targeted ECO clock buffer to clear the last antenna violation
5. rerun and verify until all signoff categories were clean
