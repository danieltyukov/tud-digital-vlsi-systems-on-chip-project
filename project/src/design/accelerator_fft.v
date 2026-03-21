/*##########################################################################
###
### Mixed-Radix-4/2 SRAM-based FFT accelerator
###
###     For N=32 (fft_stages=5): 2 radix-4 stages + 1 radix-2 stage
###     32 is not a power of 4, so pure radix-4 is impossible.
###     Mixed-radix greedily takes radix-4 stages (consuming 2 bits of log2(N)
###     each), then finishes with a radix-2 stage if an odd bit remains.
###
###     Stage decomposition for N=32:
###       Stage 1: radix-4, m= 4, q=1,  8 groups x 1 bfly =  8 bflies
###       Stage 2: radix-4, m=16, q=4,  2 groups x 4 bflies = 8 bflies
###       Stage 3: radix-2, m=32, h=16, 1 group  x 16 bflies = 16 bflies
###
###     Cycles per radix-4 butterfly: 8 read + 1 compute + 8 write = 17
###     Cycles per radix-2 butterfly: 4 read + 1 compute + 4 write = 9
###     Twiddle read per stage: 2 cycles
###     Twiddle precompute per radix-4 stage: 2 cycles (tw^2, tw^3)
###
###     Compute cycles: 2*(2+2+8*17) + (2+16*9) = 2*140 + 146 = 426
###     vs baseline:    5*(2+16*9) = 730
###     ~42% reduction in compute cycles
###
###     Interface is 100% compatible with the baseline accelerator.v wrapper.
###     Same twiddle layout, same SRAM layout, same CSR interface.
###     Firmware only needs digit-reversal instead of bit-reversal for input
###     permutation.
###
###     TU Delft ET4351 -- 2026 Project
###
##########################################################################*/

module accelerator_fft #(
    parameter integer LOG_MAX_N   = 32,                // Bit-width to represent max N
    parameter integer MEM_WIDTH = 32,                  // Width of memory data
    parameter integer ADDR_WIDTH = 32,                 // Width of memory address
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)  // Bit-width for stage counter
) (
    input wire clk,
    input wire resetn,

    // Control inputs
    input wire reset_accel,
    input wire enable_accel,

    // Data inputs from configuration registers
    input wire [LOG_MAX_N-1:0] number_data,            // N (number of samples)
    input  wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,   // log2(N)

    // Memory interface (directly drives accelerator_mem)
    output reg  [ 4-1:0] accel_mem_wstrb,              // byte write strobe
    input  wire [32-1:0] accel_mem_rdata,              // read data (async)
    output reg  [32-1:0] accel_mem_wdata,              // write data
    output reg  [32-1:0] accel_mem_addr,               // address

    // Status output
    output reg fft_finished
);

  /*========================================================================================
        FSM STATE ENCODING
        Extended from the baseline's 13 states to handle both radix-4 and radix-2
        butterfly sequences.  Radix-4 needs 8 reads + 1 compute + 8 writes = 17 states,
        while radix-2 keeps the baseline's 4 reads + 1 compute + 4 writes = 9 states.
    ========================================================================================*/
  parameter [4:0] INIT                = 5'd0;   // Wait for enable, set up first stage
  parameter [4:0] READ_W_M_RE         = 5'd1;   // Read twiddle real from SRAM
  parameter [4:0] READ_W_M_IM         = 5'd2;   // Read twiddle imag from SRAM
  parameter [4:0] PRECOMPUTE_TW2      = 5'd3;   // Compute tw^2 for radix-4 twiddle advancement
  parameter [4:0] PRECOMPUTE_TW3      = 5'd4;   // Compute tw^3 for radix-4 twiddle advancement

  // Radix-4 butterfly states: read 4 complex inputs, compute, write 4 complex outputs
  parameter [4:0] R4_READ_X0_RE       = 5'd5;
  parameter [4:0] R4_READ_X0_IM       = 5'd6;
  parameter [4:0] R4_READ_X1_RE       = 5'd7;
  parameter [4:0] R4_READ_X1_IM       = 5'd8;
  parameter [4:0] R4_READ_X2_RE       = 5'd9;
  parameter [4:0] R4_READ_X2_IM       = 5'd10;
  parameter [4:0] R4_READ_X3_RE       = 5'd11;
  parameter [4:0] R4_READ_X3_IM       = 5'd12;
  parameter [4:0] R4_COMPUTE          = 5'd13;  // Radix-4 butterfly + twiddle advancement
  parameter [4:0] R4_WRITE_X0_RE      = 5'd14;
  parameter [4:0] R4_WRITE_X0_IM      = 5'd15;
  parameter [4:0] R4_WRITE_X1_RE      = 5'd16;
  parameter [4:0] R4_WRITE_X1_IM      = 5'd17;
  parameter [4:0] R4_WRITE_X2_RE      = 5'd18;
  parameter [4:0] R4_WRITE_X2_IM      = 5'd19;
  parameter [4:0] R4_WRITE_X3_RE      = 5'd20;
  parameter [4:0] R4_WRITE_X3_IM      = 5'd21;  // Also handles loop advancement

  // Radix-2 butterfly states (same structure as baseline)
  parameter [4:0] R2_READ_1_RE        = 5'd22;  // Read X[base+k] real
  parameter [4:0] R2_READ_1_IM        = 5'd23;  // Read X[base+k] imag
  parameter [4:0] R2_READ_2_RE        = 5'd24;  // Read X[base+k+half] real
  parameter [4:0] R2_READ_2_IM        = 5'd25;  // Read X[base+k+half] imag
  parameter [4:0] R2_COMPUTE          = 5'd26;  // Radix-2 butterfly + twiddle advancement
  parameter [4:0] R2_WRITE_1_RE       = 5'd27;  // Write even output real
  parameter [4:0] R2_WRITE_1_IM       = 5'd28;  // Write even output imag
  parameter [4:0] R2_WRITE_2_RE       = 5'd29;  // Write odd output real
  parameter [4:0] R2_WRITE_2_IM       = 5'd30;  // Write odd output imag + loop advancement

  parameter [4:0] FINISH              = 5'd31;  // Assert done, wait for CPU to de-assert enable

  /*========================================================================================
        REGISTERS AND WIRES
    ========================================================================================*/
  // State registers
  reg [4:0] state_reg;
  reg [4:0] next_state;   // combinational -- declared reg for always-block usage

  /*========================================================================================
        FFT LOOP VARIABLES
    ========================================================================================*/
  reg [LOG_MAX_N-1:0] m;                   // Butterfly span: 4, 16, 32 for mixed-radix N=32
  reg [LOG_MAX_FFT_STAGES:0] log2_m;      // Cumulative bits consumed (replaces baseline's stage counter)
  reg [LOG_MAX_N-2:0] half;               // Butterflies per group: m/4 for radix-4, m/2 for radix-2
  reg [LOG_MAX_N-1:0] base;               // Base index of current group (0, m, 2m, ...)
  reg [LOG_MAX_N-2:0] k;                  // Butterfly index within group (0 .. half-1)
  reg is_radix4;                           // 1 = current stage is radix-4, 0 = radix-2

  /*========================================================================================
        TWIDDLE FACTOR REGISTERS
        w_m: primitive twiddle factor loaded from SRAM (one per stage)
        tw2, tw3: precomputed w_m^2 and w_m^3 (for radix-4 twiddle advancement)
        w1, w2, w3: running twiddle factors advanced after each butterfly
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] w_m_re, w_m_im;     // primitive twiddle tw (from SRAM)
  reg signed [MEM_WIDTH-1:0] tw2_re, tw2_im;     // tw^2 (precomputed per radix-4 stage)
  reg signed [MEM_WIDTH-1:0] tw3_re, tw3_im;     // tw^3 (precomputed per radix-4 stage)

  // Running twiddles: reset to 1+0j at each group start, advanced after each butterfly
  reg signed [MEM_WIDTH-1:0] w1_re, w1_im;       // W^k     (used by both radix-4 and radix-2)
  reg signed [MEM_WIDTH-1:0] w2_re, w2_im;       // W^{2k}  (radix-4 only)
  reg signed [MEM_WIDTH-1:0] w3_re, w3_im;       // W^{3k}  (radix-4 only)

  /*========================================================================================
        DATA REGISTERS FOR BUTTERFLY I/O
        Since SRAM can only read/write one word per cycle, we buffer all inputs
        before computing and all outputs before writing back.
    ========================================================================================*/
  // Radix-4 input registers (read from SRAM before compute)
  reg signed [MEM_WIDTH-1:0] x0_re, x0_im;
  reg signed [MEM_WIDTH-1:0] x1_re, x1_im;
  reg signed [MEM_WIDTH-1:0] x2_re, x2_im;
  reg signed [MEM_WIDTH-1:0] x3_re, x3_im;

  // Radix-4 output registers (written to SRAM after compute)
  reg signed [MEM_WIDTH-1:0] y0_re, y0_im;
  reg signed [MEM_WIDTH-1:0] y1_re, y1_im;
  reg signed [MEM_WIDTH-1:0] y2_re, y2_im;
  reg signed [MEM_WIDTH-1:0] y3_re, y3_im;

  // Radix-2 I/O registers
  reg signed [MEM_WIDTH-1:0] u_re, u_im;         // u = X[base + k]
  reg signed [MEM_WIDTH-1:0] v_re, v_im;         // v = X[base + k + half]
  reg signed [MEM_WIDTH-1:0] e_re, e_im;         // even output = u + t
  reg signed [MEM_WIDTH-1:0] o_re, o_im;         // odd output  = u - t

  // Fixed-point scale (must match firmware SCALE = 12)
  localparam SCALE = 12;

  /*========================================================================================
        LOOP TERMINATION WIRES
    ========================================================================================*/
  wire [LOG_MAX_N-2:0] next_k;
  wire [LOG_MAX_N-1:0] next_base;
  wire butterfly_done;     // Last butterfly in current group?
  wire base_done;          // Last group in current stage?
  wire all_stages_done;    // All mixed-radix stages complete?

  assign next_k    = k + 1;
  assign next_base = base + m;
  assign butterfly_done  = (next_k == half);           // k has reached half-1
  assign base_done       = (next_base == number_data); // no more groups
  assign all_stages_done = (log2_m == fft_stages);     // consumed all bits

  // Bits remaining after the current stage -- used to decide if the NEXT stage
  // can be radix-4 (needs >= 2 remaining bits) or must be radix-2 (1 bit left).
  wire [LOG_MAX_FFT_STAGES:0] bits_remaining;
  assign bits_remaining = fft_stages - log2_m;

  /*========================================================================================
        ADDRESS HELPERS
        SRAM layout (set by firmware):
          [0            .. 2*fft_stages-1]        Twiddle factors (interleaved re/im)
          [2*fft_stages .. 2*fft_stages+2*N-1]    Input/output data (interleaved re/im)
    ========================================================================================*/
  wire [ADDR_WIDTH-1:0] start_input_address;
  assign start_input_address = fft_stages << 1;   // = 2 * fft_stages

  /*========================================================================================
        INDEX WIRES (combinational from loop variables)
    ========================================================================================*/
  // ---- Radix-4 indices ----
  // For a radix-4 butterfly at position k within a group starting at 'base':
  //   x0 = base + k              (no twiddle)
  //   x1 = base + k + q          (multiplied by W^k)
  //   x2 = base + k + 2q         (multiplied by W^{2k})
  //   x3 = base + k + 3q         (multiplied by W^{3k})
  // where q = half = m/4
  // The << 1 converts element index to SRAM word address (interleaved re/im)
  wire [ADDR_WIDTH-1:0] mem_addr_x0, mem_addr_x1, mem_addr_x2, mem_addr_x3;
  assign mem_addr_x0 = (base + k) << 1;
  assign mem_addr_x1 = (base + k + half) << 1;
  assign mem_addr_x2 = (base + k + {half, 1'b0}) << 1;            // + 2*half
  assign mem_addr_x3 = (base + k + half + {half, 1'b0}) << 1;     // + 3*half

  // ---- Radix-2 indices ----
  // For radix-2, half = m/2 and we use base+k as u, base+k+half as v
  wire [ADDR_WIDTH-1:0] mem_addr_u, mem_addr_v;
  assign mem_addr_u = (base + k) << 1;
  assign mem_addr_v = (base + k + half) << 1;

  /*========================================================================================
        TWIDDLE INDEX
        The primitive twiddle for the current stage is tw[log2_m - 1].
        e.g. for m=4  (log2_m=2): tw[1] = W_4  = e^{-j*2*pi/4}
             for m=16 (log2_m=4): tw[3] = W_16 = e^{-j*2*pi/16}
             for m=32 (log2_m=5): tw[4] = W_32 = e^{-j*2*pi/32}
    ========================================================================================*/
  wire [LOG_MAX_FFT_STAGES-1:0] tw_idx;
  assign tw_idx = log2_m - 1;

  /*========================================================================================
        RADIX-4 BUTTERFLY (purely combinational)

        Given 4 inputs x0, x1, x2, x3 and twiddle factors w1, w2, w3:
          t1 = w1 * x1       (complex multiply)
          t2 = w2 * x2       (complex multiply)
          t3 = w3 * x3       (complex multiply)

        4-point DFT kernel (j-rotation is free -- just swap re/im with sign):
          X[0] = x0 + t1 + t2 + t3
          X[1] = x0 - j*t1 - t2 + j*t3     (-j*z: re'=+z.im, im'=-z.re)
          X[2] = x0 - t1 + t2 - t3
          X[3] = x0 + j*t1 - t2 - j*t3     (+j*z: re'=-z.im, im'=+z.re)
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] t1_re, t1_im;   // w1 * x1
  reg signed [MEM_WIDTH-1:0] t2_re, t2_im;   // w2 * x2
  reg signed [MEM_WIDTH-1:0] t3_re, t3_im;   // w3 * x3

  always @(*) begin
    // --- Twiddle x inputs: 3 independent complex multiplies ---
    t1_re = (x1_re * w1_re - x1_im * w1_im) >>> SCALE;
    t1_im = (x1_re * w1_im + x1_im * w1_re) >>> SCALE;

    t2_re = (x2_re * w2_re - x2_im * w2_im) >>> SCALE;
    t2_im = (x2_re * w2_im + x2_im * w2_re) >>> SCALE;

    t3_re = (x3_re * w3_re - x3_im * w3_im) >>> SCALE;
    t3_im = (x3_re * w3_im + x3_im * w3_re) >>> SCALE;
  end

  // 4-point DFT kernel results
  reg signed [MEM_WIDTH-1:0] bf4_0_re, bf4_0_im;
  reg signed [MEM_WIDTH-1:0] bf4_1_re, bf4_1_im;
  reg signed [MEM_WIDTH-1:0] bf4_2_re, bf4_2_im;
  reg signed [MEM_WIDTH-1:0] bf4_3_re, bf4_3_im;

  always @(*) begin
    // --- 4-point DFT: additions/subtractions with j-rotations ---
    // X[0] = x0 + t1 + t2 + t3
    bf4_0_re = x0_re + t1_re + t2_re + t3_re;
    bf4_0_im = x0_im + t1_im + t2_im + t3_im;

    // X[1] = x0 - j*t1 - t2 + j*t3   (multiply by -j: re' = +im, im' = -re)
    bf4_1_re = x0_re + t1_im - t2_re - t3_im;
    bf4_1_im = x0_im - t1_re - t2_im + t3_re;

    // X[2] = x0 - t1 + t2 - t3
    bf4_2_re = x0_re - t1_re + t2_re - t3_re;
    bf4_2_im = x0_im - t1_im + t2_im - t3_im;

    // X[3] = x0 + j*t1 - t2 - j*t3   (multiply by +j: re' = -im, im' = +re)
    bf4_3_re = x0_re - t1_im - t2_re + t3_im;
    bf4_3_im = x0_im + t1_re - t2_im - t3_re;
  end

  /*========================================================================================
        RADIX-2 BUTTERFLY (purely combinational, same as baseline)

        Standard Cooley-Tukey butterfly:
          t = w * v
          even = u + t
          odd  = u - t
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] t_re, t_im;     // w1 * v

  always @(*) begin
    t_re = (v_re * w1_re - v_im * w1_im) >>> SCALE;
    t_im = (v_re * w1_im + v_im * w1_re) >>> SCALE;
  end

  /*========================================================================================
        TWIDDLE ADVANCEMENT (combinational)

        After each butterfly, advance the running twiddles to the next k:
          w1' = w1 * tw         -- primitive twiddle (loaded from SRAM)
          w2' = w2 * tw2        -- tw squared (precomputed per stage)
          w3' = w3 * tw3        -- tw cubed   (precomputed per stage)
        All three multiplies are independent (no cascading).
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] w1_re_next, w1_im_next;
  reg signed [MEM_WIDTH-1:0] w2_re_next, w2_im_next;
  reg signed [MEM_WIDTH-1:0] w3_re_next, w3_im_next;

  always @(*) begin
    // w1' = w1 * tw   (advance W^k to W^{k+1})
    w1_re_next = (w1_re * w_m_re - w1_im * w_m_im) >>> SCALE;
    w1_im_next = (w1_re * w_m_im + w1_im * w_m_re) >>> SCALE;

    // w2' = w2 * tw^2  (advance W^{2k} to W^{2(k+1)})
    w2_re_next = (w2_re * tw2_re - w2_im * tw2_im) >>> SCALE;
    w2_im_next = (w2_re * tw2_im + w2_im * tw2_re) >>> SCALE;

    // w3' = w3 * tw^3  (advance W^{3k} to W^{3(k+1)})
    w3_re_next = (w3_re * tw3_re - w3_im * tw3_im) >>> SCALE;
    w3_im_next = (w3_re * tw3_im + w3_im * tw3_re) >>> SCALE;
  end

  /*========================================================================================
        FSM -- STATE REGISTER
    ========================================================================================*/
  always @(posedge clk) begin
    if (reset_accel) state_reg <= INIT;
    else state_reg <= next_state;
  end

  /*========================================================================================
        FSM -- NEXT-STATE LOGIC (combinational)
    ========================================================================================*/
  always @(*) begin
    case (state_reg)

      // Wait for CPU to assert enable_accel
      INIT:
        if (enable_accel)
          if (number_data[LOG_MAX_N-1:1] == 0)
            next_state = FINISH;               // N < 2 --> nothing to do
          else
            next_state = READ_W_M_RE;
        else
          next_state = INIT;

      // Read twiddle factor from SRAM (2 cycles: real then imag)
      READ_W_M_RE: next_state = READ_W_M_IM;
      READ_W_M_IM:
        if (is_radix4)
          next_state = PRECOMPUTE_TW2;         // radix-4: need tw^2 and tw^3
        else
          next_state = R2_READ_1_RE;           // radix-2: go straight to butterfly

      // Precompute tw^2 and tw^3 (2 cycles, radix-4 only)
      PRECOMPUTE_TW2: next_state = PRECOMPUTE_TW3;
      PRECOMPUTE_TW3: next_state = R4_READ_X0_RE;

      // ---- Radix-4 butterfly sequence (17 cycles) ----
      R4_READ_X0_RE: next_state = R4_READ_X0_IM;
      R4_READ_X0_IM: next_state = R4_READ_X1_RE;
      R4_READ_X1_RE: next_state = R4_READ_X1_IM;
      R4_READ_X1_IM: next_state = R4_READ_X2_RE;
      R4_READ_X2_RE: next_state = R4_READ_X2_IM;
      R4_READ_X2_IM: next_state = R4_READ_X3_RE;
      R4_READ_X3_RE: next_state = R4_READ_X3_IM;
      R4_READ_X3_IM: next_state = R4_COMPUTE;
      R4_COMPUTE:    next_state = R4_WRITE_X0_RE;
      R4_WRITE_X0_RE: next_state = R4_WRITE_X0_IM;
      R4_WRITE_X0_IM: next_state = R4_WRITE_X1_RE;
      R4_WRITE_X1_RE: next_state = R4_WRITE_X1_IM;
      R4_WRITE_X1_IM: next_state = R4_WRITE_X2_RE;
      R4_WRITE_X2_RE: next_state = R4_WRITE_X2_IM;
      R4_WRITE_X2_IM: next_state = R4_WRITE_X3_RE;
      R4_WRITE_X3_RE: next_state = R4_WRITE_X3_IM;

      // Last radix-4 write state: decide what's next
      R4_WRITE_X3_IM:
        if (butterfly_done && base_done && all_stages_done)
          next_state = FINISH;                 // FFT complete
        else if (butterfly_done && base_done)
          next_state = READ_W_M_RE;            // next stage: read new twiddle
        else
          next_state = R4_READ_X0_RE;          // next butterfly in same group

      // ---- Radix-2 butterfly sequence (9 cycles, same as baseline) ----
      R2_READ_1_RE: next_state = R2_READ_1_IM;
      R2_READ_1_IM: next_state = R2_READ_2_RE;
      R2_READ_2_RE: next_state = R2_READ_2_IM;
      R2_READ_2_IM: next_state = R2_COMPUTE;
      R2_COMPUTE:   next_state = R2_WRITE_1_RE;
      R2_WRITE_1_RE: next_state = R2_WRITE_1_IM;
      R2_WRITE_1_IM: next_state = R2_WRITE_2_RE;
      R2_WRITE_2_RE: next_state = R2_WRITE_2_IM;

      // Last radix-2 write state: decide what's next
      R2_WRITE_2_IM:
        if (butterfly_done && base_done && all_stages_done)
          next_state = FINISH;
        else if (butterfly_done && base_done)
          next_state = READ_W_M_RE;
        else
          next_state = R2_READ_1_RE;

      // Assert fft_finished, hold until CPU clears enable_accel
      FINISH:
        if (!enable_accel)
          next_state = INIT;
        else
          next_state = FINISH;

      default: next_state = INIT;
    endcase
  end

  /*========================================================================================
        FSM -- SRAM ADDRESS AND WRITE DATA (combinational)
        Drives SRAM address, write data, and write strobe based on current state.
    ========================================================================================*/
  always @(*) begin
    // Safe defaults: no memory write, address 0
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = '0;
    accel_mem_addr  = '0;

    case (state_reg)
      INIT: ;   // no memory access

      // ---- Twiddle read: present SRAM address ----
      READ_W_M_RE: accel_mem_addr = tw_idx << 1;
      READ_W_M_IM: accel_mem_addr = (tw_idx << 1) + 1;

      // ---- Precompute: no SRAM access ----
      PRECOMPUTE_TW2: ;
      PRECOMPUTE_TW3: ;

      // ---- Radix-4 reads: present SRAM address for each component ----
      R4_READ_X0_RE: accel_mem_addr = start_input_address + mem_addr_x0;
      R4_READ_X0_IM: accel_mem_addr = start_input_address + mem_addr_x0 + 1;
      R4_READ_X1_RE: accel_mem_addr = start_input_address + mem_addr_x1;
      R4_READ_X1_IM: accel_mem_addr = start_input_address + mem_addr_x1 + 1;
      R4_READ_X2_RE: accel_mem_addr = start_input_address + mem_addr_x2;
      R4_READ_X2_IM: accel_mem_addr = start_input_address + mem_addr_x2 + 1;
      R4_READ_X3_RE: accel_mem_addr = start_input_address + mem_addr_x3;
      R4_READ_X3_IM: accel_mem_addr = start_input_address + mem_addr_x3 + 1;

      // ---- Radix-4 compute: no SRAM access ----
      R4_COMPUTE: ;

      // ---- Radix-4 writes: drive write strobe, address, and data ----
      R4_WRITE_X0_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x0;
        accel_mem_wdata = y0_re;
      end
      R4_WRITE_X0_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x0 + 1;
        accel_mem_wdata = y0_im;
      end
      R4_WRITE_X1_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x1;
        accel_mem_wdata = y1_re;
      end
      R4_WRITE_X1_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x1 + 1;
        accel_mem_wdata = y1_im;
      end
      R4_WRITE_X2_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x2;
        accel_mem_wdata = y2_re;
      end
      R4_WRITE_X2_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x2 + 1;
        accel_mem_wdata = y2_im;
      end
      R4_WRITE_X3_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x3;
        accel_mem_wdata = y3_re;
      end
      R4_WRITE_X3_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_x3 + 1;
        accel_mem_wdata = y3_im;
      end

      // ---- Radix-2 reads ----
      R2_READ_1_RE: accel_mem_addr = start_input_address + mem_addr_u;
      R2_READ_1_IM: accel_mem_addr = start_input_address + mem_addr_u + 1;
      R2_READ_2_RE: accel_mem_addr = start_input_address + mem_addr_v;
      R2_READ_2_IM: accel_mem_addr = start_input_address + mem_addr_v + 1;

      // ---- Radix-2 compute: no SRAM access ----
      R2_COMPUTE: ;

      // ---- Radix-2 writes ----
      R2_WRITE_1_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_u;
        accel_mem_wdata = e_re;
      end
      R2_WRITE_1_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_u + 1;
        accel_mem_wdata = e_im;
      end
      R2_WRITE_2_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_v;
        accel_mem_wdata = o_re;
      end
      R2_WRITE_2_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_v + 1;
        accel_mem_wdata = o_im;
      end

      FINISH: ;
      default: ;
    endcase
  end

  /*========================================================================================
        FSM -- SEQUENTIAL DATAPATH (posedge clk)
    ========================================================================================*/
  always @(posedge clk) begin
    if (reset_accel) begin
      // ---- Reset all loop variables ----
      log2_m     <= '0;
      m          <= 'd2;
      half       <= 'b1;
      base       <= '0;
      k          <= '0;
      is_radix4  <= 1'b0;
      w_m_re     <= '0;
      w_m_im     <= '0;
      tw2_re     <= '0;
      tw2_im     <= '0;
      tw3_re     <= '0;
      tw3_im     <= '0;
      w1_re      <= 'b1 << SCALE;
      w1_im      <= '0;
      w2_re      <= 'b1 << SCALE;
      w2_im      <= '0;
      w3_re      <= 'b1 << SCALE;
      w3_im      <= '0;
      x0_re      <= '0; x0_im <= '0;
      x1_re      <= '0; x1_im <= '0;
      x2_re      <= '0; x2_im <= '0;
      x3_re      <= '0; x3_im <= '0;
      y0_re      <= '0; y0_im <= '0;
      y1_re      <= '0; y1_im <= '0;
      y2_re      <= '0; y2_im <= '0;
      y3_re      <= '0; y3_im <= '0;
      u_re       <= '0; u_im  <= '0;
      v_re       <= '0; v_im  <= '0;
      e_re       <= '0; e_im  <= '0;
      o_re       <= '0; o_im  <= '0;
      fft_finished <= '0;
    end else begin
      case (state_reg)

        // ==============================================================
        //  INIT -- set up loop variables for the first FFT stage
        //  Decide whether the first stage is radix-4 or radix-2 based
        //  on fft_stages (log2(N)).  If >= 2 bits available, use radix-4.
        // ==============================================================
        INIT: begin
          base  <= '0;
          k     <= '0;
          w1_re <= 'b1 << SCALE; w1_im <= '0;
          w2_re <= 'b1 << SCALE; w2_im <= '0;
          w3_re <= 'b1 << SCALE; w3_im <= '0;
          fft_finished <= '0;

          // First stage: radix-4 if fft_stages >= 2, else radix-2
          if (fft_stages >= 2) begin
            log2_m    <= 'd2;             // m = 4 --> log2(4) = 2
            m         <= 'd4;
            half      <= 'd1;             // q = m/4 = 1 butterfly per group
            is_radix4 <= 1'b1;
          end else begin
            log2_m    <= 'd1;             // m = 2 --> log2(2) = 1
            m         <= 'd2;
            half      <= 'd1;             // half = m/2 = 1
            is_radix4 <= 1'b0;
          end
        end

        // ==============================================================
        //  READ_W_M -- capture twiddle factor from SRAM
        //  SRAM has async read --> rdata valid same cycle
        // ==============================================================
        READ_W_M_RE: w_m_re <= accel_mem_rdata;
        READ_W_M_IM: w_m_im <= accel_mem_rdata;

        // ==============================================================
        //  PRECOMPUTE -- compute tw^2 and tw^3 for radix-4 stages
        //  tw2 is computed in one cycle, tw3 uses tw2 the next cycle
        // ==============================================================
        PRECOMPUTE_TW2: begin
          tw2_re <= (w_m_re * w_m_re - w_m_im * w_m_im) >>> SCALE;
          tw2_im <= (w_m_re * w_m_im + w_m_im * w_m_re) >>> SCALE;
        end
        PRECOMPUTE_TW3: begin
          tw3_re <= (tw2_re * w_m_re - tw2_im * w_m_im) >>> SCALE;
          tw3_im <= (tw2_re * w_m_im + tw2_im * w_m_re) >>> SCALE;
        end

        // ==============================================================
        //  RADIX-4 BUTTERFLY -- read 4 complex inputs from SRAM
        // ==============================================================
        R4_READ_X0_RE: x0_re <= accel_mem_rdata;
        R4_READ_X0_IM: x0_im <= accel_mem_rdata;
        R4_READ_X1_RE: x1_re <= accel_mem_rdata;
        R4_READ_X1_IM: x1_im <= accel_mem_rdata;
        R4_READ_X2_RE: x2_re <= accel_mem_rdata;
        R4_READ_X2_IM: x2_im <= accel_mem_rdata;
        R4_READ_X3_RE: x3_re <= accel_mem_rdata;
        R4_READ_X3_IM: x3_im <= accel_mem_rdata;

        // ==============================================================
        //  RADIX-4 COMPUTE -- latch butterfly outputs and advance twiddles
        //  The combinational butterfly (bf4_*) and twiddle advancement
        //  (w*_next) are computed above; here we just register them.
        // ==============================================================
        R4_COMPUTE: begin
          y0_re <= bf4_0_re; y0_im <= bf4_0_im;
          y1_re <= bf4_1_re; y1_im <= bf4_1_im;
          y2_re <= bf4_2_re; y2_im <= bf4_2_im;
          y3_re <= bf4_3_re; y3_im <= bf4_3_im;

          // Advance running twiddles for next butterfly
          w1_re <= w1_re_next; w1_im <= w1_im_next;
          w2_re <= w2_re_next; w2_im <= w2_im_next;
          w3_re <= w3_re_next; w3_im <= w3_im_next;
        end

        // ==============================================================
        //  RADIX-4 WRITE -- SRAM writes driven by combinational block.
        //  Loop advancement happens on the last write state (R4_WRITE_X3_IM).
        // ==============================================================
        R4_WRITE_X0_RE: ;
        R4_WRITE_X0_IM: ;
        R4_WRITE_X1_RE: ;
        R4_WRITE_X1_IM: ;
        R4_WRITE_X2_RE: ;
        R4_WRITE_X2_IM: ;
        R4_WRITE_X3_RE: ;
        R4_WRITE_X3_IM: begin
          if (butterfly_done && base_done && all_stages_done) begin
            // FFT complete -- next state logic will transition to FINISH
          end else if (butterfly_done && base_done) begin
            // ---- Advance to next stage ----
            base  <= '0;
            k     <= '0;
            w1_re <= 'b1 << SCALE; w1_im <= '0;
            w2_re <= 'b1 << SCALE; w2_im <= '0;
            w3_re <= 'b1 << SCALE; w3_im <= '0;

            // Decide if next stage is radix-4 or radix-2
            if (bits_remaining >= 2) begin
              // Next stage is radix-4: consume 2 bits
              log2_m    <= log2_m + 2;
              m         <= m << 2;         // m *= 4
              half      <= m;              // new q = new_m/4 = old_m
              is_radix4 <= 1'b1;
            end else begin
              // Next stage is radix-2: consume 1 bit (last stage)
              log2_m    <= log2_m + 1;
              m         <= m << 1;         // m *= 2
              half      <= m;              // new half = new_m/2 = old_m
              is_radix4 <= 1'b0;
            end
          end else if (butterfly_done) begin
            // ---- Advance to next group (same stage) ----
            base  <= next_base;
            k     <= '0;
            w1_re <= 'b1 << SCALE; w1_im <= '0;
            w2_re <= 'b1 << SCALE; w2_im <= '0;
            w3_re <= 'b1 << SCALE; w3_im <= '0;
          end else begin
            // ---- Next butterfly in current group ----
            k <= next_k;
          end
        end

        // ==============================================================
        //  RADIX-2 BUTTERFLY -- read 2 complex inputs from SRAM
        // ==============================================================
        R2_READ_1_RE: u_re <= accel_mem_rdata;
        R2_READ_1_IM: u_im <= accel_mem_rdata;
        R2_READ_2_RE: v_re <= accel_mem_rdata;
        R2_READ_2_IM: v_im <= accel_mem_rdata;

        // ==============================================================
        //  RADIX-2 COMPUTE -- standard Cooley-Tukey butterfly
        // ==============================================================
        R2_COMPUTE: begin
          e_re <= u_re + t_re;
          e_im <= u_im + t_im;
          o_re <= u_re - t_re;
          o_im <= u_im - t_im;

          // Advance twiddle for next butterfly
          w1_re <= w1_re_next; w1_im <= w1_im_next;
        end

        // ==============================================================
        //  RADIX-2 WRITE -- SRAM writes driven by combinational block.
        //  Loop advancement happens on the last write state (R2_WRITE_2_IM).
        // ==============================================================
        R2_WRITE_1_RE: ;
        R2_WRITE_1_IM: ;
        R2_WRITE_2_RE: ;
        R2_WRITE_2_IM: begin
          if (butterfly_done && base_done && all_stages_done) begin
            // FFT complete
          end else if (butterfly_done && base_done) begin
            // ---- Advance to next stage ----
            log2_m <= log2_m + 1;
            m      <= m << 1;
            half   <= m;              // new half = new_m/2 = old_m
            base   <= '0;
            k      <= '0;
            w1_re  <= 'b1 << SCALE; w1_im <= '0;
          end else if (butterfly_done) begin
            // ---- Advance to next group (same stage) ----
            base  <= next_base;
            k     <= '0;
            w1_re <= 'b1 << SCALE; w1_im <= '0;
          end else begin
            // ---- Next butterfly in current group ----
            k <= next_k;
          end
        end

        // ==============================================================
        //  FINISH -- assert done flag, wait for CPU to de-assert enable
        // ==============================================================
        FINISH: begin
          fft_finished <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule
