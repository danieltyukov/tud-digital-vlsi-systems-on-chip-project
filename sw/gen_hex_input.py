"""
Convert a list of real integer samples to fft_data.hex lines.
Paste the output into lines 14-45 of firmware/fft_data.hex.
"""

SAMPLES = [
      30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
     30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
     30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
     30000+0j,  21213+0j,      0+0j, -21213+0j,
    -30000+0j, -21213+0j,      0+0j,  21213+0j,
]

assert len(SAMPLES) == 32, f"Need 32 samples, got {len(SAMPLES)}"

for v in SAMPLES:
    w = int(v.real) & 0xFFFFFFFF
    print(" ".join(f"{(w >> (8*i)) & 0xFF:02X}" for i in range(4)) + " ")
