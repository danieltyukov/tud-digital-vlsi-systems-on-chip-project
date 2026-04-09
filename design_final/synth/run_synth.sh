#!/bin/bash

# Run the synthesis script (no clock gating — CG caused 337 hold violations)
genus -legacy_ui -64 -f scripts/synth.tcl || exit 1