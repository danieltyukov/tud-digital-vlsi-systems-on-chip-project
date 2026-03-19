#!/bin/bash

# Run the synthesis script
SYNTH_SCRIPT="${SYNTH_SCRIPT:-scripts/synth.tcl}"
genus -legacy_ui -64 -f "${SYNTH_SCRIPT}" || exit 1
