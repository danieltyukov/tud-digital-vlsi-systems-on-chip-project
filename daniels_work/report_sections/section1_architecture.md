# Section I: Architecture and Design Methodology

## 1.1 System-on-Chip Architecture

The ET4351 SoC is built around a PicoRV32 RISC-V core (RV32I ISA) connected to peripherals via a 32-bit memory-mapped bus. The key components are:

- **PicoRV32 CPU** — executes firmware from external Flash via QSPI
- **On-chip SRAM** (1 KB) — CPU stack/variables, four `SRAM1RW256x8` macros
- **QSPI interface** — 4 MB Flash access at half the system clock
- **UART** — serial output for FFT results
- **Custom FFT accelerator** — memory-mapped at `0x03000000`+

### Memory Map

| Address Range | Peripheral |
|---|---|
| `0x00000000–0x000003FF` | On-chip SRAM (1 KB) |
| `0x00100000–0x004FFFFF` | External Flash (4 MB) |
| `0x02000000–0x0200000B` | QSPI config, UART |
| `0x03000000`+ | FFT accelerator (CSR + data memory) |

## 1.2 FFT Algorithm: Radix-2 DIT

The accelerator implements a 32-point decimation-in-time (DIT) FFT using the Cooley-Tukey radix-2 algorithm:

- **Input size**: $N = 32$ (fixed, power of 2)
- **Stages**: $\log_2(N) = 5$
- **Butterflies per stage**: $N/2 = 16$
- **Total butterflies**: $5 \times 16 = 80$
- **Twiddle factors**: $N/2 = 16$ unique values $W_N^k = e^{-j2\pi k/N}$, $k = 0, 1, \ldots, 15$

Each butterfly computes:
$$X_{even} = u + t, \quad X_{odd} = u - t$$
where $t = W_N^k \cdot v$ is a complex multiplication with scaling:
$$t_{re} = (v_{re} \cdot w_{re} - v_{im} \cdot w_{im}) \gg 12$$
$$t_{im} = (v_{re} \cdot w_{im} + v_{im} \cdot w_{re}) \gg 12$$

Fixed-point arithmetic uses Q12 format (12 fractional bits, `SCALE = 12`).

## 1.3 Baseline Profiling

The baseline accelerator processes each butterfly sequentially through 9 FSM states (4 reads + 1 compute + 4 writes), resulting in:

| Category | Cycles | % of Total |
|----------|--------|-----------|
| Memory access (reads + writes) | 650 | 88.8% |
| Compute | 80 | 10.9% |
| Control overhead | 2 | 0.3% |
| **Total** | **732** | **100%** |

**Key bottleneck**: The single-ported SRAM forces sequential word-by-word access. Each butterfly touches 8 words (4 read + 4 write) but computes in only 1 cycle. The design is severely **memory-bound**.

## 1.4 HW/SW Co-Design Partitioning

### Software (firmware) responsibilities:
1. Read audio samples from Flash via QSPI
2. Write input data to accelerator memory (bit-reversed order)
3. **Pre-compute twiddle factors** and write to CSR registers (HP design)
4. Start accelerator, poll for completion
5. Read results and transmit via UART

### Hardware (accelerator) responsibilities:
1. Load data from accelerator memory into internal register file
2. Execute all 5 FFT stages using butterfly datapath(s)
3. Store results back to accelerator memory
4. Assert completion flag

**Key co-design decision (HP):** Moving twiddle factor computation from hardware to firmware eliminates the LOAD_TWIDDLE FSM state and per-stage FILL sub-phase, saving both cycles and area. The twiddle table is pre-computed in Q12 fixed-point by the firmware and written to 32 CSR registers outside the timed accelerator window.

## 1.5 HP Accelerator Architecture

### Optimization Journey

| Step | Change | Cycles | Speedup |
|------|--------|--------|---------|
| Baseline | Sequential SRAM butterflies | 732 | 1.00× |
| D1: Register file | Bulk LOAD/COMPUTE/STORE | 220 | 3.33× |
| D2: 2× parallel BF | Dual butterfly datapaths | 206 | 3.55× |
| **D3: SW twiddle preload** | **Twiddles via CSR, SRAM halved** | **170** | **4.31×** |

### D3 Architecture Details

**FSM**: 5 states — `INIT → LOAD_DATA → COMPUTE → STORE_DATA → FINISH`

**Memory hierarchy**:
- 35 CSR registers: 3 config + 32 twiddle values (loaded by firmware pre-enable)
- Accelerator memory: 64 words (32 complex samples, interleaved re/im)
- Internal register file: 64 × 32-bit (`data_re[0:31]`, `data_im[0:31]`)

**Cycle breakdown (D3)**:

| Phase | Cycles | % |
|-------|--------|---|
| INIT | 1 | 0.6% |
| LOAD_DATA | 64 | 37.6% |
| COMPUTE | 40 | 23.5% |
| STORE_DATA | 64 | 37.6% |
| FINISH | 1 | 0.6% |
| **Total** | **170** | **100%** |

**Compute phase**: 2× parallel butterfly units process pairs simultaneously. Global twiddle indexing: $tw\_idx = k\_loc \ll (fft\_stages - stage)$, mapping per-stage needs into the pre-loaded $W_N^k$ table.

**Latency at 12 MHz**: $170 \times 83.33\text{ ns} = 14.17 \mu s$ (well under 61.00 $\mu s$ requirement)

### Key Design Choices
1. **Register file vs SRAM for data**: Eliminates inter-stage SRAM round-trips (largest single optimization). Trade-off: 2,048 flip-flops for data storage.
2. **SW twiddle preload**: Firmware pre-computes Q12 twiddle table once; hardware receives it via CSR flat bus. Eliminates LOAD_TWIDDLE state and per-stage FILL overhead. Reduces SRAM from 128 to 64 words (−50.5% memory area).
3. **2× parallel butterflies**: Dual datapaths halve compute phase from 80 to 40 cycles. Area cost: second multiplier set.

## 1.6 EE Accelerator Architecture

### Strategy: Reduce Switching Activity

The baseline energy is $E = P \times T = 0.403\text{ mW} \times 61.00 \mu s = 24.6\text{ nJ}$.

Since $P_{sw} \sim \alpha \cdot f_{clk} \cdot V_{DD}^2 \cdot C_L$, we target $\alpha$ reduction — reducing unnecessary switching without changing the cycle count or clock frequency.

### No-Recursive-Twiddle Optimization

The baseline updates twiddle factors recursively each butterfly: $w \leftarrow w \cdot w_m$. This requires an **extra complex multiplication** purely for twiddle progression (not for the butterfly output itself).

**Change**: Replace recursive twiddle update with a precomputed hardcoded lookup table indexed by $(m, k)$. The twiddle values are stored as RTL constants matching the exact fixed-point values the recursive method would produce (preserving bit-identical output).

**Energy impact**:
- Removes the recursive complex multiply → fewer arithmetic register toggles
- Less switching in twiddle-generation logic
- Same FSM, same states, same cycle count → latency unchanged
- **Result**: 23.795 nJ (−3.20% from baseline)

### Additional EE Techniques Considered
- **Trivial-twiddle fast paths**: Skip full multiply when $w \in \{+1, -1, +j, -j\}$ — use sign flips and real/imag swaps instead
- **No twiddle memory reads**: Replace `READ_W_M_RE`/`READ_W_M_IM` states with stage-local constants
- **Clock gating**: Gate idle register file during LOAD/STORE phases

## 1.7 Memory Architecture

The SoC contains three distinct storage blocks:

| Block | Type | Size | Access |
|-------|------|------|--------|
| PicoSoC SRAM | 4× `SRAM1RW256x8` macros | 1 KB | CPU only |
| CSR registers | `reg [31:0]` flip-flops | 35 words | CPU write, HW read |
| Accelerator memory | `reg [31:0]` flip-flop array | 64 words | CPU + FFT (muxed) |

**Critical insight**: `accelerator_mem` is synthesized into flip-flops by Genus, not instantiated as an SRAM macro. Its interface is fully customizable — dual-port reads, wider datapaths, and separate CPU/FFT ports are all possible. The only constraints are area and timing.
