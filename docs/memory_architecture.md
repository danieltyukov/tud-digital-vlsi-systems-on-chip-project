# Memory Resources and Datapaths

## Three separate storage blocks in this SoC

**1. PicoSoC on-chip SRAM** (`picosoc_mem` in `picosoc.v`) -- This is the 1 KB main memory at address `0x00000000-0x000003FF`, built from four `SRAM1RW256x8` macros. It holds the CPU's stack, variables, and .bss/.data sections. The CPU uses it for its own computation. The accelerator **never touches this** -- it's purely CPU territory.

**2. CSR registers** (`iomem_accel[0..34]` in `accelerator.v`) -- These are plain `reg [31:0]` flip-flops declared as an array inside the accelerator wrapper. The CPU writes to them via the `iomem` bus when the address falls in the "conf" range (`word_addr < NUM_REGS`). The accelerator hardware reads them as direct wires -- for config bits, that's simple assigns (`assign reset_accel = iomem_accel[0][0]`); for twiddles, they're packed into flat buses via the `generate` block.

**3. Accelerator memory** (`accelerator_mem` module) -- This is a **separate flip-flop array** instantiated inside `accelerator.v`, sitting alongside the CSR registers but as a distinct module. In the v3 design it's 64 entries deep (`MEM_DEPTH = 2 * 32 = 64`). It's implemented as:

```verilog
reg [31:0] mem [0:MEM_DEPTH-1];
assign rdata = mem[addr];  // combinational read
```

This is **not** the PicoSoC SRAM. It's not even a real SRAM macro -- it's a register file that Genus will synthesize into flip-flops, just like the CSR array. The project documentation and comments call it "SRAM" loosely, but physically it's the same kind of storage as the CSRs.

## How accelerator_mem connects to both the CPU and the FFT core

The key is the **mux logic** in `accelerator.v`. The `accelerator_mem` module has a single address port, a single write port, and a single read port. Two masters need to access it -- the CPU and the FFT core -- so there are muxes controlled by `iomem_access_mem`:

```verilog
// Address mux: CPU or FFT core drives the address
assign mem_addr = iomem_access_mem ? (iomem_addr[23:2] - NUM_REGS)
                                   : accel_mem_addr[ADDR_WIDTH-1:0];

// Write data mux: CPU or FFT core drives write data
assign mem_wdata = iomem_access_mem ? iomem_wdata : accel_mem_wdata;
assign mem_wstrb = iomem_access_mem ? iomem_wstrb : accel_mem_wstrb;
```

When `iomem_access_mem` is high (CPU is accessing the data region), the CPU's address and data go through to `accelerator_mem`. When it's low (accelerator is running its FSM), the FFT core's `accel_mem_addr`/`accel_mem_wdata` signals drive the memory instead.

For reads, the `mem_rdata` wire from `accelerator_mem` feeds **both** directions -- it goes to the CPU via the `iomem_rdata` mux, and it goes to the FFT core directly as `accel_mem_rdata`:

```verilog
// CPU read path
assign iomem_rdata = iomem_access_conf ? iomem_conf_rdata
                   : (iomem_access_mem ? mem_rdata : 32'b0);

// FFT core read path (always connected)
.accel_mem_rdata(mem_rdata),
```

## So what's the actual data flow per chunk?

Here's the sequence, with all three storage elements:

**Phase A -- CPU writes data (before `enable_accel`):**

```
Flash (off-chip) --[QSPI]--> PicoRV32 CPU --[iomem bus]--> accelerator_mem (flip-flops)
```

The CPU executes `*(volatile int*)(ACCEL_SRAM_START_ADDR + offset) = read_dec_entry_from_flash(...)`. The address `0x0300_008C+` satisfies `word_addr >= NUM_REGS`, so `iomem_access_mem` goes high, and the mux routes the CPU's data into `accelerator_mem`.

**Phase B -- FFT core loads from accelerator_mem (S_LOAD_DATA):**

```
accelerator_mem --[mem_rdata wire]--> FFT core's data_re[]/data_im[] register file
```

Now `iomem_access_mem` is low (CPU isn't accessing), so `accel_mem_addr` from the FSM drives the memory address. The FSM reads one word per cycle from `accelerator_mem` into its internal `data_re`/`data_im` register arrays. This takes 64 cycles.

**Phase C -- FFT compute (S_COMPUTE):**
The FFT core operates entirely on its internal `data_re`/`data_im` registers. `accelerator_mem` is idle.

**Phase D -- FFT core stores back (S_STORE_DATA):**

```
FFT core's data_re[]/data_im[] --> accelerator_mem (via accel_mem_wdata/wstrb)
```

The FSM writes results back to `accelerator_mem`, 64 cycles.

**Phase E -- CPU reads results:**

```
accelerator_mem --[mem_rdata]--> iomem_rdata --[iomem bus]--> PicoRV32 CPU --> UART
```

## Why S_LOAD_DATA and S_STORE_DATA exist

Here's the crucial part: the FFT core has its **own internal register file** (`data_re[0:31]`, `data_im[0:31]` -- 64 registers inside `accelerator_fft.v`). The butterfly computation needs random access to any pair of data elements simultaneously (for the two parallel butterfly units). The `accelerator_mem` module only has a **single address port**, so you can only read one word per cycle from it.

The `S_LOAD_DATA` phase copies data sequentially from the single-ported `accelerator_mem` into the multi-ported internal register file, and `S_STORE_DATA` copies it back. It's essentially a transfer between two flip-flop arrays -- one that's CPU-accessible (shared via the mux) and one that's private to the FFT datapath.

## Key insight: accelerator_mem is fully customizable

Since `accelerator_mem` is a synthesized register file (`reg [31:0] mem [0:MEM_DEPTH-1]`), not an instantiation of the `SRAM1RW256x8` macro, you have complete freedom over its interface. The SRAM macro constraints -- fixed 256x8 configuration, single port, no memory compiler -- only apply to the `picosoc_mem` module used for the CPU's 1 KB main memory. Your accelerator's internal memory is just Verilog `reg` arrays that Genus maps to flip-flops, so you can do things like:

**Dual-port or multi-port reads** -- You could declare two separate read address inputs and two read data outputs, letting the FSM load two words per cycle (cutting S_LOAD_DATA from 64 to 32 cycles). The synthesis tool just instantiates more muxing logic -- there's no physical memory constraint stopping you.

**Wider data paths** -- Instead of reading one 32-bit word per cycle, you could restructure `accelerator_mem` to output 2 or 4 words simultaneously by banking the storage (e.g., even/odd addresses on separate arrays). This directly halves or quarters the LOAD/STORE cycle count.

**Separate read/write ports** -- You could give the CPU a dedicated write-only port and the FFT core a dedicated read-only port, avoiding the mux contention entirely. This would even allow overlapping: the CPU could start writing the next chunk while the FFT core is still reading the current one (double-buffering).

The only real constraints you face are area (more ports means more mux logic and flip-flops, all of which must fit in the ~596x596 um^2 core) and timing (wider/more complex muxing adds combinational delay, which must still meet your clock period). But those are synthesis-level trade-offs you can evaluate with Genus, not hard architectural limits imposed by the technology.
