#!/bin/bash

# Run the synthesis script (added clock gating)
genus -legacy_ui -64 -f scripts/synth_cg.tcl || exit 1