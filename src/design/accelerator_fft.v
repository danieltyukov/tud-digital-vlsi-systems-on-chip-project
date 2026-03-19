/*##########################################################################
###
### Mixed-Radix-4/2 Register-file FFT accelerator
###
###     For N=32 (fft_stages=5): 2 radix-4 stages + 1 radix-2 stage = 3 stages
###     32 is not a power of 4, so pure radix-4 is impossible.
###     Mixed-radix greedily takes radix-4 stages (consuming 2 bits of log2(N)
###     each), then finishes with a radix-2 stage if an odd bit remains.
###
###     Stage decomposition for N=32:
###       Stage 1: radix-4, m= 4, q=1,  8 groups × 1 bfly =  8 bflies
###       Stage 2: radix-4, m=16, q=4,  2 groups × 4 bflies = 8 bflies
###       Stage 3: radix-2, m=32, h=16, 1 group  × 16 bflies = 16 bflies
###       + 2 precompute cycles per radix-4 stage (tw^2, tw^3)
###
###     Compute cycles: (2+8) + (2+8) + 16 = 36  (vs 80 for pure radix-2)
###
###     Total cycle count for N=32:
###       INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(36) + STORE(64) + FINISH(1) = 176
###
###     Interface is 100% compatible with the baseline accelerator.v wrapper.
###     Firmware does NOT need to change -- same 5 twiddle factors, same SRAM layout.
###     The hardware indexes into the existing twiddle array using tw_idx = log2_m - 1.
###
###     TU Delft ET4351 -- 2026 Project
###
##########################################################################*/

module accelerator_fft #(
    parameter integer LOG_MAX_N   = 32,                // Bit-width to represent max N
    parameter integer MEM_WIDTH   = 32,                // Width of memory data
    parameter integer ADDR_WIDTH  = 32,                // Width of memory address (overridden to 7 by wrapper)
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)  // Bit-width for stage counter
) (
    input wire clk,
    input wire resetn,

    // Control inputs
    input wire reset_accel,
    input wire enable_accel,

    // Data inputs from configuration registers
    input wire [LOG_MAX_N-1:0]          number_data,   // N (number of samples)
    input wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,    // log2(N)

    // Memory interface (directly drives accelerator_mem)
    output reg  [ 3:0] accel_mem_wstrb,                // byte write strobe
    input  wire [31:0] accel_mem_rdata,                // read data (async)
    output reg  [31:0] accel_mem_wdata,                // write data
    output reg  [31:0] accel_mem_addr,                 // address

    // Status output
    output reg fft_finished
);

  /*========================================================================================
        PARAMETERS
    ========================================================================================*/
  // Register file dimensioning -- sized for max 32-point FFT
  localparam MAX_FFT_N      = 32;
  localparam MAX_FFT_STAGES = $clog2(MAX_FFT_N);           // = 5
  localparam IDX_W          = $clog2(MAX_FFT_N);            // = 5  (index width for reg file)
  localparam IO_CNT_W       = $clog2(2 * MAX_FFT_N) + 1;   // = 7  (counter width for LOAD/STORE)

  // Fixed-point scale (must match firmware SCALE = 12)
  localparam SCALE = 12;

  /*========================================================================================
        FSM STATE ENCODING
        Same 6 states as the baseline -- only S_COMPUTE behaviour changes.
    ========================================================================================*/
  localparam [2:0] S_INIT         = 3'd0,   // Wait for enable, set up first stage
                   S_LOAD_TWIDDLE = 3'd1,   // Read twiddle factors from SRAM into tw registers
                   S_LOAD_DATA    = 3'd2,   // Read input data from SRAM into data registers
                   S_COMPUTE      = 3'd3,   // Execute FFT butterflies (radix-4 or radix-2)
                   S_STORE_DATA   = 3'd4,   // Write results from data registers back to SRAM
                   S_FINISH       = 3'd5;   // Assert done flag, wait for CPU to de-assert enable

  reg [2:0] state_reg;
  reg [2:0] next_state;   // combinational -- declared reg for always-block usage

  /*========================================================================================
        REGISTER FILE  (the core data-reuse optimisation)
        All FFT computation happens register-to-register, avoiding per-butterfly SRAM access.
    ========================================================================================*/
  // Data register file: 32 complex values = 64 x 32-bit registers
  reg signed [MEM_WIDTH-1:0] data_re [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] data_im [0:MAX_FFT_N-1];

  // Twiddle register file: up to 5 primitive twiddle factors (one per radix-2 equivalent stage)
  // Loaded once, then indexed by log2_m-1 during compute
  reg signed [MEM_WIDTH-1:0] tw_re [0:MAX_FFT_STAGES-1];
  reg signed [MEM_WIDTH-1:0] tw_im [0:MAX_FFT_STAGES-1];

  /*========================================================================================
        LOAD / STORE COUNTER
        Shared counter for S_LOAD_TWIDDLE, S_LOAD_DATA, S_STORE_DATA.
        Counts through interleaved real/imag words: [re0, im0, re1, im1, ...]
    ========================================================================================*/
  reg [IO_CNT_W-1:0] io_cnt;

  /*========================================================================================
        FFT LOOP VARIABLES
    ========================================================================================*/
  reg [LOG_MAX_N-1:0]  m;       // Butterfly span: 4, 16, 32 for mixed-radix N=32
  reg [LOG_MAX_N-2:0]  half;    // Butterflies per group: m/4 for radix-4, m/2 for radix-2
  reg [LOG_MAX_N-1:0]  base;    // Base index of current group  (0, m, 2m, ...)
  reg [LOG_MAX_N-2:0]  k;       // Butterfly index within group (0 .. half-1)

  // ---- Mixed-radix stage tracking ----
  // log2_m tracks cumulative "bits consumed" -- replaces the old linear stage counter.
  // For radix-4 stages, log2_m advances by 2; for radix-2, by 1.
  // The FFT is complete when log2_m == fft_stages.
  reg [LOG_MAX_FFT_STAGES:0]  log2_m;
  reg                         is_radix4;   // 1 = current stage is radix-4, 0 = radix-2

  // ---- Running twiddle factors ----
  // For radix-4: w1 = W^k, w2 = W^{2k}, w3 = W^{3k}  (three independent rotations)
  // For radix-2: only w1 is used (same as baseline's 'w')
  // Reset to 1+0j at the start of each base group; advanced by multiplying with
  // the primitive twiddle (tw, tw^2, tw^3) after each butterfly.
  reg signed [MEM_WIDTH-1:0]  w1_re, w1_im;   // W^k
  reg signed [MEM_WIDTH-1:0]  w2_re, w2_im;   // W^{2k}  (radix-4 only)
  reg signed [MEM_WIDTH-1:0]  w3_re, w3_im;   // W^{3k}  (radix-4 only)

  // ---- Precomputed stage twiddle powers ----
  // tw2 = tw[log2_m-1]^2  and  tw3 = tw[log2_m-1]^3
  // These are computed in 2 extra cycles at the start of each radix-4 stage,
  // then used to advance w2 and w3 independently (avoiding cascaded multiplies).
  reg signed [MEM_WIDTH-1:0]  tw2_re, tw2_im;
  reg signed [MEM_WIDTH-1:0]  tw3_re, tw3_im;

  // ---- Compute sub-state ----
  // Within S_COMPUTE, radix-4 stages need 2 precompute cycles before butterflies.
  //   0 = precompute tw2 (tw squared)
  //   1 = precompute tw3 (tw cubed)
  //   2 = execute butterflies
  // Radix-2 stages skip directly to sub-state 2.
  reg [1:0] compute_sub;

  /*========================================================================================
        LOOP TERMINATION WIRES
    ========================================================================================*/
  wire [LOG_MAX_N-2:0]  next_k;
  wire [LOG_MAX_N-1:0]  next_base;
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
  wire [31:0] start_input_address;
  assign start_input_address = fft_stages << 1;   // = 2 * fft_stages

  // Total number of interleaved words to load/store
  wire [IO_CNT_W-1:0] tw_total;
  wire [IO_CNT_W-1:0] data_total;
  assign tw_total   = fft_stages << 1;             // = 2 * fft_stages  (10 for 5 stages)
  assign data_total  = number_data[IDX_W:0] << 1;  // = 2 * N           (64 for N=32)

  /*========================================================================================
        INDEX WIRES  (combinational from loop variables)
    ========================================================================================*/
  // ---- Radix-4 indices ----
  // For a radix-4 butterfly at position k within a group starting at 'base':
  //   x0 = base + k          (no twiddle)
  //   x1 = base + k + q      (multiplied by W^k)
  //   x2 = base + k + 2q     (multiplied by W^{2k})
  //   x3 = base + k + 3q     (multiplied by W^{3k})
  // where q = half = m/4
  wire [IDX_W-1:0] idx_x0, idx_x1, idx_x2, idx_x3;
  assign idx_x0 = base[IDX_W-1:0] + k[IDX_W-1:0];
  assign idx_x1 = idx_x0 + half[IDX_W-1:0];
  assign idx_x2 = idx_x0 + {half[IDX_W-2:0], 1'b0};                       // + 2*q
  assign idx_x3 = idx_x0 + half[IDX_W-1:0] + {half[IDX_W-2:0], 1'b0};    // + 3*q

  // ---- Radix-2 indices ----
  // For radix-2, half = m/2 and we reuse x0 as idx_u, x0+half as idx_v
  wire [IDX_W-1:0] idx_u, idx_v;
  assign idx_u = idx_x0;
  assign idx_v = idx_x0 + half[IDX_W-1:0];

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
        RADIX-4 BUTTERFLY  (purely combinational)

        Given 4 inputs at x0, x1, x2, x3 and twiddle factors w1, w2, w3:
          t1 = w1 * x[x1]       (complex multiply)
          t2 = w2 * x[x2]       (complex multiply)
          t3 = w3 * x[x3]       (complex multiply)

        4-point DFT kernel (j-rotation is free -- just swap re/im with sign):
          X[0] = x0 + t1 + t2 + t3
          X[1] = x0 - j*t1 - t2 + j*t3     (-j*z: re'=+z.im, im'=-z.re)
          X[2] = x0 - t1 + t2 - t3
          X[3] = x0 + j*t1 - t2 - j*t3     (+j*z: re'=-z.im, im'=+z.re)
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] t1_re, t1_im;
  reg signed [MEM_WIDTH-1:0] t2_re, t2_im;
  reg signed [MEM_WIDTH-1:0] t3_re, t3_im;
  reg signed [MEM_WIDTH-1:0] bf4_0_re, bf4_0_im;
  reg signed [MEM_WIDTH-1:0] bf4_1_re, bf4_1_im;
  reg signed [MEM_WIDTH-1:0] bf4_2_re, bf4_2_im;
  reg signed [MEM_WIDTH-1:0] bf4_3_re, bf4_3_im;

  always @(*) begin
    // --- Twiddle x inputs: 3 independent complex multiplies ---
    t1_re = (data_re[idx_x1] * w1_re - data_im[idx_x1] * w1_im) >>> SCALE;
    t1_im = (data_re[idx_x1] * w1_im + data_im[idx_x1] * w1_re) >>> SCALE;

    t2_re = (data_re[idx_x2] * w2_re - data_im[idx_x2] * w2_im) >>> SCALE;
    t2_im = (data_re[idx_x2] * w2_im + data_im[idx_x2] * w2_re) >>> SCALE;

    t3_re = (data_re[idx_x3] * w3_re - data_im[idx_x3] * w3_im) >>> SCALE;
    t3_im = (data_re[idx_x3] * w3_im + data_im[idx_x3] * w3_re) >>> SCALE;

    // --- 4-point DFT: additions/subtractions with j-rotations ---
    // X[0] = x0 + t1 + t2 + t3
    bf4_0_re = data_re[idx_x0] + t1_re + t2_re + t3_re;
    bf4_0_im = data_im[idx_x0] + t1_im + t2_im + t3_im;

    // X[1] = x0 - j*t1 - t2 + j*t3   (multiply by -j: re' = +im, im' = -re)
    bf4_1_re = data_re[idx_x0] + t1_im - t2_re - t3_im;
    bf4_1_im = data_im[idx_x0] - t1_re - t2_im + t3_re;

    // X[2] = x0 - t1 + t2 - t3
    bf4_2_re = data_re[idx_x0] - t1_re + t2_re - t3_re;
    bf4_2_im = data_im[idx_x0] - t1_im + t2_im - t3_im;

    // X[3] = x0 + j*t1 - t2 - j*t3   (multiply by +j: re' = -im, im' = +re)
    bf4_3_re = data_re[idx_x0] - t1_im - t2_re + t3_im;
    bf4_3_im = data_im[idx_x0] + t1_re - t2_im - t3_re;
  end

  /*========================================================================================
        RADIX-2 BUTTERFLY  (purely combinational, same as baseline)

        Standard Cooley-Tukey butterfly:
          t = w * x[v]
          X[u] = x[u] + t       (even output)
          X[v] = x[u] - t       (odd output)
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] r2_t_re, r2_t_im;
  reg signed [MEM_WIDTH-1:0] bf_e_re, bf_e_im;    // even output (u)
  reg signed [MEM_WIDTH-1:0] bf_o_re, bf_o_im;    // odd output  (v)

  always @(*) begin
    // --- Twiddle x v multiplication ---
    r2_t_re = (data_re[idx_v] * w1_re - data_im[idx_v] * w1_im) >>> SCALE;
    r2_t_im = (data_re[idx_v] * w1_im + data_im[idx_v] * w1_re) >>> SCALE;

    // --- Butterfly add / subtract ---
    bf_e_re = data_re[idx_u] + r2_t_re;
    bf_e_im = data_im[idx_u] + r2_t_im;
    bf_o_re = data_re[idx_u] - r2_t_re;
    bf_o_im = data_im[idx_u] - r2_t_im;
  end

  /*========================================================================================
        TWIDDLE ADVANCEMENT  (combinational)

        After each butterfly, advance the running twiddles to the next k:
          w1' = w1 * tw[stage]       -- primitive twiddle (loaded from SRAM)
          w2' = w2 * tw2             -- tw squared (precomputed per stage)
          w3' = w3 * tw3             -- tw cubed   (precomputed per stage)
        All three multiplies are independent (no cascading), so they can
        execute in parallel without deepening the critical path.
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] w1_re_next, w1_im_next;
  reg signed [MEM_WIDTH-1:0] w2_re_next, w2_im_next;
  reg signed [MEM_WIDTH-1:0] w3_re_next, w3_im_next;

  always @(*) begin
    // w1' = w1 * tw[log2_m - 1]   (advance W^k to W^{k+1})
    w1_re_next = (w1_re * tw_re[tw_idx] - w1_im * tw_im[tw_idx]) >>> SCALE;
    w1_im_next = (w1_re * tw_im[tw_idx] + w1_im * tw_re[tw_idx]) >>> SCALE;

    // w2' = w2 * tw^2              (advance W^{2k} to W^{2(k+1)})
    w2_re_next = (w2_re * tw2_re - w2_im * tw2_im) >>> SCALE;
    w2_im_next = (w2_re * tw2_im + w2_im * tw2_re) >>> SCALE;

    // w3' = w3 * tw^3              (advance W^{3k} to W^{3(k+1)})
    w3_re_next = (w3_re * tw3_re - w3_im * tw3_im) >>> SCALE;
    w3_im_next = (w3_re * tw3_im + w3_im * tw3_re) >>> SCALE;
  end

  /*========================================================================================
        FSM -- STATE REGISTER
    ========================================================================================*/
  always @(posedge clk) begin
    if (reset_accel)
      state_reg <= S_INIT;
    else
      state_reg <= next_state;
  end

  /*========================================================================================
        FSM -- NEXT-STATE LOGIC  (combinational)
    ========================================================================================*/
  always @(*) begin
    case (state_reg)

      // Wait for CPU to assert enable_accel
      S_INIT:
        if (enable_accel)
          if (number_data[LOG_MAX_N-1:1] == 0)
            next_state = S_FINISH;               // N < 2 --> nothing to do
          else
            next_state = S_LOAD_TWIDDLE;
        else
          next_state = S_INIT;

      // Load all twiddle words from SRAM
      S_LOAD_TWIDDLE:
        if (io_cnt == tw_total - 1)
          next_state = S_LOAD_DATA;
        else
          next_state = S_LOAD_TWIDDLE;

      // Load all input data words from SRAM
      S_LOAD_DATA:
        if (io_cnt == data_total - 1)
          next_state = S_COMPUTE;
        else
          next_state = S_LOAD_DATA;

      // Execute all FFT stages -- only transition out when the last butterfly
      // of the last group of the last stage is complete (compute_sub must be 2
      // to ensure precompute cycles are not mistaken for completion)
      S_COMPUTE:
        if (compute_sub == 2'd2 && butterfly_done && base_done && all_stages_done)
          next_state = S_STORE_DATA;
        else
          next_state = S_COMPUTE;

      // Write all result words back to SRAM
      S_STORE_DATA:
        if (io_cnt == data_total - 1)
          next_state = S_FINISH;
        else
          next_state = S_STORE_DATA;

      // Assert fft_finished, hold until CPU clears enable_accel
      S_FINISH:
        if (!enable_accel)
          next_state = S_INIT;
        else
          next_state = S_FINISH;

      default:
        next_state = S_INIT;

    endcase
  end

  /*========================================================================================
        FSM -- OUTPUT / MEMORY INTERFACE  (combinational)
        Drives SRAM address, write data, and write strobe based on current state.
    ========================================================================================*/
  always @(*) begin
    // Safe defaults: no memory write, address 0
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = 32'd0;
    accel_mem_addr  = 32'd0;

    case (state_reg)

      S_INIT: ;   // no memory access

      // ---- LOAD: present read address, SRAM responds combinationally ----
      S_LOAD_TWIDDLE: begin
        accel_mem_addr = {{(32 - IO_CNT_W){1'b0}}, io_cnt};   // addr = io_cnt (0..9)
      end

      S_LOAD_DATA: begin
        accel_mem_addr = start_input_address + {{(32 - IO_CNT_W){1'b0}}, io_cnt};
      end

      S_COMPUTE: ;  // no SRAM access -- everything in register file

      // ---- STORE: drive write address + data ----
      S_STORE_DATA: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + {{(32 - IO_CNT_W){1'b0}}, io_cnt};
        if (io_cnt[0] == 1'b0)
          accel_mem_wdata = data_re[io_cnt[IO_CNT_W-1:1]];    // even address --> real
        else
          accel_mem_wdata = data_im[io_cnt[IO_CNT_W-1:1]];    // odd address  --> imag
      end

      S_FINISH: ;
      default:  ;

    endcase
  end

  /*========================================================================================
        FSM -- SEQUENTIAL DATAPATH  (posedge clk)
    ========================================================================================*/
  integer i;   // for loop in reset

  always @(posedge clk) begin
    if (reset_accel) begin
      // ---- Reset all loop variables ----
      log2_m      <= '0;
      m           <= 'd2;
      half        <= 'b1;
      base        <= '0;
      k           <= '0;
      is_radix4   <= 1'b0;
      w1_re       <= 'b1 << SCALE;
      w1_im       <= '0;
      w2_re       <= 'b1 << SCALE;
      w2_im       <= '0;
      w3_re       <= 'b1 << SCALE;
      w3_im       <= '0;
      tw2_re      <= '0;
      tw2_im      <= '0;
      tw3_re      <= '0;
      tw3_im      <= '0;
      compute_sub <= 2'd0;
      io_cnt      <= '0;
      fft_finished <= 1'b0;

      // ---- Zero-initialise register files (avoid X in simulation) ----
      for (i = 0; i < MAX_FFT_N; i = i + 1) begin
        data_re[i] <= 32'sd0;
        data_im[i] <= 32'sd0;
      end
      for (i = 0; i < MAX_FFT_STAGES; i = i + 1) begin
        tw_re[i] <= 32'sd0;
        tw_im[i] <= 32'sd0;
      end

    end else begin
      case (state_reg)

        // ==============================================================
        //  INIT -- set up loop variables for the first FFT stage
        //  Decide whether the first stage is radix-4 or radix-2 based
        //  on fft_stages (log2(N)).  If >= 2 bits available, use radix-4.
        // ==============================================================
        S_INIT: begin
          base        <= '0;
          k           <= '0;
          w1_re       <= 'b1 << SCALE;   // w1 = 1.0 + 0j  (unity)
          w1_im       <= '0;
          w2_re       <= 'b1 << SCALE;   // w2 = 1.0 + 0j
          w2_im       <= '0;
          w3_re       <= 'b1 << SCALE;   // w3 = 1.0 + 0j
          w3_im       <= '0;
          io_cnt      <= '0;
          fft_finished <= 1'b0;

          // First stage: radix-4 if fft_stages >= 2, else radix-2
          if (fft_stages >= 2) begin
            log2_m    <= 'd2;             // m = 4 --> log2(4) = 2
            m         <= 'd4;
            half      <= 'd1;             // q = m/4 = 1 butterfly per group
            is_radix4 <= 1'b1;
            compute_sub <= 2'd0;          // start with tw2 precompute
          end else begin
            log2_m    <= 'd1;             // m = 2 --> log2(2) = 1
            m         <= 'd2;
            half      <= 'd1;             // half = m/2 = 1
            is_radix4 <= 1'b0;
            compute_sub <= 2'd2;          // skip precompute, go straight to butterfly
          end
        end

        // ==============================================================
        //  LOAD_TWIDDLE -- capture twiddle factors from SRAM into regs
        //  SRAM layout: [tw[0].re, tw[0].im, tw[1].re, tw[1].im, ...]
        //  accelerator_mem has async read --> rdata valid same cycle
        // ==============================================================
        S_LOAD_TWIDDLE: begin
          if (io_cnt[0] == 1'b0)
            tw_re[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;   // even addr --> real
          else
            tw_im[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;   // odd addr  --> imag

          if (io_cnt == tw_total - 1)
            io_cnt <= '0;          // reset counter for LOAD_DATA
          else
            io_cnt <= io_cnt + 1;
        end

        // ==============================================================
        //  LOAD_DATA -- capture input data from SRAM into register file
        //  SRAM layout: [X[0].re, X[0].im, X[1].re, X[1].im, ...]
        // ==============================================================
        S_LOAD_DATA: begin
          if (io_cnt[0] == 1'b0)
            data_re[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;
          else
            data_im[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;

          if (io_cnt == data_total - 1)
            io_cnt <= '0;          // reset counter for STORE_DATA (after COMPUTE)
          else
            io_cnt <= io_cnt + 1;
        end

        // ==============================================================
        //  COMPUTE -- execute all FFT stages, register-to-register
        //
        //  For radix-4 stages (is_radix4 == 1):
        //    Sub-state 0: precompute tw2 = tw[stage]^2  (1 cycle)
        //    Sub-state 1: precompute tw3 = tw2 * tw[stage]  (1 cycle)
        //    Sub-state 2: execute radix-4 butterflies (N/4 per stage)
        //
        //  For radix-2 stages (is_radix4 == 0):
        //    Sub-state 2 only: execute radix-2 butterflies (N/2 per stage)
        //
        //  Loop structure (same for both radix types):
        //    for each stage:
        //      for base = 0, m, 2m, ... (groups)
        //        for k = 0 .. half-1 (butterflies within group)
        //          execute butterfly, advance twiddles
        // ==============================================================
        S_COMPUTE: begin
          if (is_radix4) begin
            case (compute_sub)

              // ---- Precompute tw2 = tw[log2_m-1]^2 ----
              // Squaring the primitive twiddle to get the W^{2k} advancement factor.
              2'd0: begin
                tw2_re <= (tw_re[tw_idx] * tw_re[tw_idx] - tw_im[tw_idx] * tw_im[tw_idx]) >>> SCALE;
                tw2_im <= (tw_re[tw_idx] * tw_im[tw_idx] + tw_im[tw_idx] * tw_re[tw_idx]) >>> SCALE;
                compute_sub <= 2'd1;
              end

              // ---- Precompute tw3 = tw2 * tw[log2_m-1] ----
              // Cubing the primitive twiddle to get the W^{3k} advancement factor.
              // Uses the tw2 computed in the previous cycle.
              2'd1: begin
                tw3_re <= (tw2_re * tw_re[tw_idx] - tw2_im * tw_im[tw_idx]) >>> SCALE;
                tw3_im <= (tw2_re * tw_im[tw_idx] + tw2_im * tw_re[tw_idx]) >>> SCALE;
                compute_sub <= 2'd2;
              end

              // ---- Radix-4 butterfly execution ----
              // Writes 4 outputs per cycle from the combinational butterfly above.
              2'd2: begin
                // Write 4 butterfly outputs to register file
                data_re[idx_x0] <= bf4_0_re;
                data_im[idx_x0] <= bf4_0_im;
                data_re[idx_x1] <= bf4_1_re;
                data_im[idx_x1] <= bf4_1_im;
                data_re[idx_x2] <= bf4_2_re;
                data_im[idx_x2] <= bf4_2_im;
                data_re[idx_x3] <= bf4_3_re;
                data_im[idx_x3] <= bf4_3_im;

                // ---- Loop advancement ----
                if (butterfly_done && base_done && all_stages_done) begin
                  // FFT complete -- next state logic will transition to STORE_DATA
                end else if (butterfly_done && base_done) begin
                  // ---- Advance to next stage ----
                  // Reset group/butterfly counters and twiddles to unity
                  base  <= '0;
                  k     <= '0;
                  w1_re <= 'b1 << SCALE;  w1_im <= '0;
                  w2_re <= 'b1 << SCALE;  w2_im <= '0;
                  w3_re <= 'b1 << SCALE;  w3_im <= '0;

                  // Decide if next stage is radix-4 or radix-2
                  if (bits_remaining >= 2) begin
                    // Next stage is radix-4: consume 2 bits
                    log2_m      <= log2_m + 2;
                    m           <= m << 2;         // m *= 4
                    half        <= m;              // new q = new_m/4 = 4*old_m/4 = old_m
                    is_radix4   <= 1'b1;
                    compute_sub <= 2'd0;           // precompute tw2/tw3 for new stage
                  end else begin
                    // Next stage is radix-2: consume 1 bit (last stage)
                    log2_m      <= log2_m + 1;
                    m           <= m << 1;         // m *= 2
                    half        <= m;              // new half = new_m/2 = 2*old_m/2 = old_m
                    is_radix4   <= 1'b0;
                    compute_sub <= 2'd2;           // no precompute needed for radix-2
                  end
                end else if (butterfly_done) begin
                  // ---- Advance to next base group (same stage) ----
                  base  <= next_base;
                  k     <= '0;
                  w1_re <= 'b1 << SCALE;  w1_im <= '0;   // reset twiddles to unity
                  w2_re <= 'b1 << SCALE;  w2_im <= '0;
                  w3_re <= 'b1 << SCALE;  w3_im <= '0;
                end else begin
                  // ---- Next butterfly in current group ----
                  k     <= next_k;
                  w1_re <= w1_re_next;  w1_im <= w1_im_next;   // advance W^k
                  w2_re <= w2_re_next;  w2_im <= w2_im_next;   // advance W^{2k}
                  w3_re <= w3_re_next;  w3_im <= w3_im_next;   // advance W^{3k}
                end
              end

              default: ;

            endcase

          end else begin
            // ==============================================================
            //  Radix-2 butterfly (for trailing stage when fft_stages is odd)
            //  Same logic as the baseline -- one butterfly per cycle.
            // ==============================================================

            // Write 2 butterfly outputs to register file
            data_re[idx_u] <= bf_e_re;
            data_im[idx_u] <= bf_e_im;
            data_re[idx_v] <= bf_o_re;
            data_im[idx_v] <= bf_o_im;

            // ---- Loop advancement ----
            if (butterfly_done && base_done && all_stages_done) begin
              // FFT complete
            end else if (butterfly_done && base_done) begin
              // ---- Advance to next stage (always radix-2 if we're already in r2) ----
              log2_m <= log2_m + 1;
              m      <= m << 1;
              half   <= m;             // new half = new_m/2 = old_m
              base   <= '0;
              k      <= '0;
              w1_re  <= 'b1 << SCALE;  w1_im <= '0;
            end else if (butterfly_done) begin
              // ---- Advance to next base group (same stage) ----
              base  <= next_base;
              k     <= '0;
              w1_re <= 'b1 << SCALE;  w1_im <= '0;
            end else begin
              // ---- Next butterfly in current group ----
              k     <= next_k;
              w1_re <= w1_re_next;  w1_im <= w1_im_next;
            end
          end
        end

        // ==============================================================
        //  STORE_DATA -- write register file contents back to SRAM
        //  Write strobe + data driven by combinational output block above.
        //  Interleaved: even address = real, odd address = imag.
        // ==============================================================
        S_STORE_DATA: begin
          if (io_cnt == data_total - 1)
            io_cnt <= '0;
          else
            io_cnt <= io_cnt + 1;
        end

        // ==============================================================
        //  FINISH -- assert done flag, wait for CPU to de-assert enable
        // ==============================================================
        S_FINISH: begin
          fft_finished <= 1'b1;
        end

        default: ;

      endcase
    end
  end

endmodule