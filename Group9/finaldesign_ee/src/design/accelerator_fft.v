/*##########################################################################
###
### Ali EE v2: RFFT + pure Radix-4 DIT on D1 register-file architecture
###
###     32-point real FFT implemented as a 16-point complex FFT followed
###     by a Hermitian-symmetry RECOMBINE step.
###
###     FSM phases:
###       1. LOAD_DATA  – read 32 real samples from SRAM (stride-2, real only)
###                       imaginary registers stay 0 from reset → 32 cycles
###       2. COMPUTE    – 16-point Radix-4 DIT FFT, register-to-register
###                       Stage 1 (1 cycle):  4 trivial butterflies in parallel
###                       Stage 2 (13 cycles): 4 butterflies × 3 multiply-cycles
###                       Twiddles hardcoded inline — no LUT function needed
###       3. RECOMBINE  – unpack Y[k] into X[k] using Hermitian symmetry
###                       X[k] = (E[k] - j·W_32^k·D[k]) / 2
###                       Writes results into register file → 18 cycles
###       4. STORE_DATA – write 32 complex outputs (64 words) to SRAM → 64 cycles
###       5. FINISH     – assert fft_finished
###
###     Expected cycle count:
###       INIT(1) + LOAD(32) + COMPUTE(14) + RECOMBINE(18) + STORE(64) + FINISH(1) = 130
###
###     RFFT packing (combinational, 0 cycles):
###       Firmware loads SRAM in bit-reversed order → data_re[i] = audio[BR5(i)]
###       z[k] = data_re[BR5(2·DR4(k))] + j·data_re[BR5(2·DR4(k)+1)]
###       Implemented as hardwired assign statements (z_re/z_im wires).
###
###     SRAM layout unchanged from baseline: twiddle region still present
###     but ignored. start_input_address offset preserved for correct addressing.
###
###     Interface 100% compatible with accelerator.v wrapper.
###
###     TU Delft ET4351 – 2026 Project
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

    // Control input
    input wire reset_accel,
    input wire enable_accel,

    // Data input
    input wire [LOG_MAX_N-1:0]          number_data,   // N (number of samples)
    input wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,    // log2(N)

    // Memory inputs/outputs
    output reg  [ 3:0] accel_mem_wstrb,
    input  wire [31:0] accel_mem_rdata,
    output reg  [31:0] accel_mem_wdata,
    output reg  [31:0] accel_mem_addr,

    // Data output
    output reg fft_finished
);

  /*========================================================================================
        PARAMETERS
    ========================================================================================*/
  // Register file dimensioning – sized for max 32-point FFT
  localparam MAX_FFT_N      = 32;
  localparam MAX_FFT_STAGES = $clog2(MAX_FFT_N);           // = 5
  localparam IDX_W          = $clog2(MAX_FFT_N);            // = 5  (index width for reg file)
  localparam IO_CNT_W       = $clog2(MAX_FFT_N) + 1;       // = 6  (counter for LOAD: N cycles, not 2N)

  // Fixed-point scale (must match firmware)
  localparam SCALE = 12;

  /*========================================================================================
        FSM STATE ENCODING
    ========================================================================================*/
  localparam [2:0] S_INIT       = 3'd0,
                   S_LOAD_DATA  = 3'd1,
                   S_COMPUTE    = 3'd2,
                   S_STORE_DATA = 3'd3,
                   S_FINISH     = 3'd4,
                   S_RECOMBINE  = 3'd5;

  reg [2:0] state_reg;
  reg [2:0] next_state;   // combinational – declared reg for always-block usage

  /*========================================================================================
        REGISTER FILE  (the core of the optimisation)
    ========================================================================================*/
  // Data register file: 32 entries × 2 (re+im) = 64 × 32-bit registers
  // During LOAD:      data_re[0..31] = real audio samples (bit-reversed), data_im = 0
  // During COMPUTE:   data_re/im[0..15] = 16-point complex FFT working registers
  // After RECOMBINE:  data_re/im[0..31] = full 32-point RFFT output
  reg signed [MEM_WIDTH-1:0] data_re [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] data_im [0:MAX_FFT_N-1];

  // No twiddle register file – twiddles come from hardcoded LUT

  /*========================================================================================
        RFFT PACKING  (purely combinational – zero extra cycles)
        After LOAD_DATA: data_re[i] = x[BR5(i)]  (32 real samples in 5-bit bit-reversed order)
        RFFT: z[n] = x[2n] + j*x[2n+1]  →  z[n].re = data_re[BR5(2n)], z[n].im = data_re[BR5(2n+1)]
        Combined with Radix-4 DIT digit-reversal (swap 2 base-4 digits) so the COMPUTE stage
        can start directly on digit-reversed input without a separate PACK state.
    ========================================================================================*/
  wire signed [MEM_WIDTH-1:0] z_re [0:15];
  wire signed [MEM_WIDTH-1:0] z_im [0:15];

  // Permutation: z_re[k] = data_re[BR5(2*DR4(k))], z_im[k] = data_re[BR5(2*DR4(k)+1)]
  // data_re[i] = audio[BR5(i)]  (bit-reversed order: firmware loads SRAM[10+2i]=audio[BR5(i)])
  // DR4 = [0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15]
  // BR5(2*DR4(k)) always in 0..15; BR5(2*DR4(k)+1) always in 16..31
  assign z_re[0]  = data_re[0];   assign z_im[0]  = data_re[16];
  assign z_re[1]  = data_re[2];   assign z_im[1]  = data_re[18];
  assign z_re[2]  = data_re[1];   assign z_im[2]  = data_re[17];
  assign z_re[3]  = data_re[3];   assign z_im[3]  = data_re[19];
  assign z_re[4]  = data_re[8];   assign z_im[4]  = data_re[24];
  assign z_re[5]  = data_re[10];  assign z_im[5]  = data_re[26];
  assign z_re[6]  = data_re[9];   assign z_im[6]  = data_re[25];
  assign z_re[7]  = data_re[11];  assign z_im[7]  = data_re[27];
  assign z_re[8]  = data_re[4];   assign z_im[8]  = data_re[20];
  assign z_re[9]  = data_re[6];   assign z_im[9]  = data_re[22];
  assign z_re[10] = data_re[5];   assign z_im[10] = data_re[21];
  assign z_re[11] = data_re[7];   assign z_im[11] = data_re[23];
  assign z_re[12] = data_re[12];  assign z_im[12] = data_re[28];
  assign z_re[13] = data_re[14];  assign z_im[13] = data_re[30];
  assign z_re[14] = data_re[13];  assign z_im[14] = data_re[29];
  assign z_re[15] = data_re[15];  assign z_im[15] = data_re[31];

  /*========================================================================================
        LOAD / STORE COUNTER
    ========================================================================================*/
  reg [IO_CNT_W-1:0] io_cnt;    // shared counter for LOAD_DATA, STORE_DATA

  /*========================================================================================
        COMPUTE STEP COUNTER  (Radix-4 RFFT)
        Step 0         : Stage 1 — 4 trivial butterflies in parallel (no multiplies)
        Step 1         : Stage 2, group g=0 — trivial twiddles W_16^0=1
        Steps 2..5     : Stage 2, group g=1 — twiddles W_16^1, W_16^2, W_16^3
        Steps 6..9     : Stage 2, group g=2 — twiddles W_16^2, W_16^4=-j, W_16^6
        Steps 10..13   : Stage 2, group g=3 — twiddles W_16^3, W_16^6, W_16^9
        Total: 14 cycles (steps 0..13)
    ========================================================================================*/
  localparam COMPUTE_LAST = 4'd13;  // step 0=Stage1, 1=g0, 2-5=g1, 6-9=g2, 10-13=g3
  reg [3:0] compute_step;

  // Temporary registers for Stage 2 intermediate products (q1, q2, q3)
  reg signed [MEM_WIDTH-1:0] temp1_re, temp1_im;
  reg signed [MEM_WIDTH-1:0] temp2_re, temp2_im;
  reg signed [MEM_WIDTH-1:0] temp3_re, temp3_im;

  /*========================================================================================
        RECOMBINE COUNTER + TWIDDLE W_32^k
        recomb_step [4:0]: 0..31  (16 k-values × 2 sub-steps each)
        recomb_k    [3:0]: k index = recomb_step[4:1]
        recomb_sub       : sub-step = recomb_step[0]  (0=compute E/D,  1=multiply+write)
    ========================================================================================*/
  reg  [4:0] recomb_step;
  wire [3:0] recomb_k    = recomb_step[4:1];
  wire       recomb_sub  = recomb_step[0];

  // Conjugate index: Y[16-k] lives in data_re[(16-k) mod 16]
  // 4-bit wrap: 4'd0 - recomb_k gives 0,15,14,...,1 for k=0,1,...,15
  wire [3:0] recomb_k_conj = 4'd0 - recomb_k;

  // Hermitian copy destination: X[32-k] → data_re[32-k] for k=1..15
  wire [4:0] recomb_k_herm = 5'd32 - {1'b0, recomb_k};

  // W_32^k twiddle factors for RECOMBINE (Q12, same values as Daniel's LUT m=32)
  reg signed [MEM_WIDTH-1:0] w32_re, w32_im;
  always @(*) begin
    case (recomb_k)
      4'd0:  begin w32_re =  32'sd4096; w32_im =  32'sd0;     end
      4'd1:  begin w32_re =  32'sd4017; w32_im = -32'sd799;   end
      4'd2:  begin w32_re =  32'sd3783; w32_im = -32'sd1568;  end
      4'd3:  begin w32_re =  32'sd3404; w32_im = -32'sd2276;  end
      4'd4:  begin w32_re =  32'sd2894; w32_im = -32'sd2897;  end
      4'd5:  begin w32_re =  32'sd2273; w32_im = -32'sd3406;  end
      4'd6:  begin w32_re =  32'sd1564; w32_im = -32'sd3784;  end
      4'd7:  begin w32_re =  32'sd795;  w32_im = -32'sd4017;  end
      4'd8:  begin w32_re = -32'sd4;    w32_im = -32'sd4095;  end
      4'd9:  begin w32_re = -32'sd803;  w32_im = -32'sd4016;  end
      4'd10: begin w32_re = -32'sd1571; w32_im = -32'sd3782;  end
      4'd11: begin w32_re = -32'sd2279; w32_im = -32'sd3403;  end
      4'd12: begin w32_re = -32'sd2899; w32_im = -32'sd2893;  end
      4'd13: begin w32_re = -32'sd3408; w32_im = -32'sd2272;  end
      4'd14: begin w32_re = -32'sd3786; w32_im = -32'sd1564;  end
      4'd15: begin w32_re = -32'sd4019; w32_im = -32'sd796;   end
      default: begin w32_re = 32'sd4096; w32_im = 32'sd0;     end
    endcase
  end

  // Combinational twiddle product: W_32^k * temp2 (= W_32^k * D[k])
  // Used in recomb_sub=1 to form X[k] = (E[k] - j*W_32^k*D[k]) / 2
  wire signed [MEM_WIDTH-1:0] recomb_prod_re;
  wire signed [MEM_WIDTH-1:0] recomb_prod_im;
  assign recomb_prod_re = (w32_re * temp2_re - w32_im * temp2_im) >>> SCALE;
  assign recomb_prod_im = (w32_re * temp2_im + w32_im * temp2_re) >>> SCALE;


  /*========================================================================================
        ADDRESS HELPERS
    ========================================================================================*/
  // Twiddle factors still occupy SRAM[0 ... 2*fft_stages - 1] (written by firmware)
  // Input data occupies  SRAM[2*fft_stages ... 2*fft_stages + 2*N - 1]
  // We keep start_input_address to maintain correct SRAM addressing
  wire [31:0] start_input_address;
  assign start_input_address = fft_stages << 1;   // = 2 * fft_stages

  // LOAD total: N cycles (real parts only — imaginary is always 0)
  // STORE total: 2*N cycles (write back full 32 complex = 64 words)
  wire [IO_CNT_W-1:0] load_total;
  wire [IO_CNT_W:0]   store_total;
  assign load_total  = number_data[IDX_W:0];        // = N     (32 for N=32)
  assign store_total = number_data[IDX_W:0] << 1;   // = 2*N   (64 for N=32)

  /*========================================================================================
        FSM – STATE REGISTER
    ========================================================================================*/
  always @(posedge clk) begin
    if (reset_accel)
      state_reg <= S_INIT;
    else
      state_reg <= next_state;
  end

  /*========================================================================================
        FSM – NEXT-STATE LOGIC  (combinational)
    ========================================================================================*/
  always @(*) begin
    case (state_reg)

      S_INIT:
        if (enable_accel)
          if (number_data[LOG_MAX_N-1:1] == 0)
            next_state = S_FINISH;               // N < 2 -> nothing to do
          else
            next_state = S_LOAD_DATA;            // skip twiddle load – LUT provides them
        else
          next_state = S_INIT;

      S_LOAD_DATA:
        if (io_cnt == load_total - 1)
          next_state = S_COMPUTE;
        else
          next_state = S_LOAD_DATA;

      S_COMPUTE:
        if (compute_step == COMPUTE_LAST)
          next_state = S_RECOMBINE;
        else
          next_state = S_COMPUTE;

      S_RECOMBINE:
        if (recomb_step == 5'd17)
          next_state = S_STORE_DATA;
        else
          next_state = S_RECOMBINE;

      S_STORE_DATA:
        if (io_cnt == store_total - 1)
          next_state = S_FINISH;
        else
          next_state = S_STORE_DATA;

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
        FSM – OUTPUT / MEMORY INTERFACE  (combinational)
    ========================================================================================*/
  always @(*) begin
    // Safe defaults: no memory write, address 0
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = 32'd0;
    accel_mem_addr  = 32'd0;

    case (state_reg)

      S_INIT: ;   // no memory access

      // ---- LOAD: read only real parts (stride 2), imaginary is always 0 ----
      S_LOAD_DATA: begin
        accel_mem_addr = start_input_address + {{(32 - IO_CNT_W - 1){1'b0}}, io_cnt, 1'b0}; // io_cnt * 2
      end

      S_COMPUTE: ;  // no SRAM access – everything in register file

      // ---- STORE: drive write address + data ----
      S_STORE_DATA: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + {{(32 - IO_CNT_W){1'b0}}, io_cnt};
        if (io_cnt[0] == 1'b0)
          accel_mem_wdata = data_re[io_cnt[IO_CNT_W-1:1]];    // even -> real
        else
          accel_mem_wdata = data_im[io_cnt[IO_CNT_W-1:1]];    // odd  -> imag
      end

      S_FINISH: ;
      default:  ;

    endcase
  end

  /*========================================================================================
        FSM – SEQUENTIAL DATAPATH  (posedge clk)
    ========================================================================================*/
  integer i;   // for loop in reset

  always @(posedge clk) begin
    if (reset_accel) begin
      io_cnt       <= '0;
      compute_step <= '0;
      recomb_step  <= '0;
      fft_finished <= 1'b0;

      // ---- Zero-initialise register file (avoid X in simulation) ----
      for (i = 0; i < MAX_FFT_N; i = i + 1) begin
        data_re[i] <= 32'sd0;
        data_im[i] <= 32'sd0;
      end

    end else begin
      case (state_reg)

        // ==============================================================
        //  INIT – re-initialise all loop variables for a fresh FFT run
        // ==============================================================
        S_INIT: begin
          io_cnt       <= '0;
          compute_step <= '0;
          recomb_step  <= '0;
          fft_finished <= 1'b0;
        end

        // ==============================================================
        //  LOAD_DATA – capture input data from SRAM into register file
        //  SRAM layout: [X[0].re, X[0].im, X[1].re, X[1].im, ...]
        //  Data starts at SRAM[start_input_address] (after twiddle region)
        // ==============================================================
        S_LOAD_DATA: begin
          // Load real parts only — imaginary is always 0 (set at reset)
          data_re[io_cnt] <= accel_mem_rdata;

          if (io_cnt == load_total - 1)
            io_cnt <= '0;
          else
            io_cnt <= io_cnt + 1;
        end

        // ==============================================================
        //  COMPUTE – 16-point Radix-4 DIT FFT, register-to-register
        //  Stage 1 (step 0): 4 trivial butterflies in parallel, no multiplies
        //  Stage 2 (steps 1-10): 4 butterflies x 3 multiply-cycles each (TBD)
        // ==============================================================
        S_COMPUTE: begin
          compute_step <= compute_step + 1;

          case (compute_step)

            // ----------------------------------------------------------
            //  Step 0: Stage 1 — all 4 Radix-4 butterflies in parallel
            //  Twiddles are W_4^k = {1, -j, -1, j} — no multiplications.
            //  Formula (s0=a0+a2, s1=a1+a3, d0=a0-a2, d1=a1-a3):
            //    A[0] = s0 + s1
            //    A[1] = d0 - j*d1  →  re = d0.re + d1.im,  im = d0.im - d1.re
            //    A[2] = s0 - s1
            //    A[3] = d0 + j*d1  →  re = d0.re - d1.im,  im = d0.im + d1.re
            //  Reads from z_re/z_im (combinational packing wires, zero extra cycles).
            // ----------------------------------------------------------
            4'd0: begin
              // Group 0: z[0..3] → data[0..3]
              data_re[0]  <= (z_re[0]+z_re[2]) + (z_re[1]+z_re[3]);
              data_im[0]  <= (z_im[0]+z_im[2]) + (z_im[1]+z_im[3]);
              data_re[1]  <= (z_re[0]-z_re[2]) + (z_im[1]-z_im[3]);
              data_im[1]  <= (z_im[0]-z_im[2]) - (z_re[1]-z_re[3]);
              data_re[2]  <= (z_re[0]+z_re[2]) - (z_re[1]+z_re[3]);
              data_im[2]  <= (z_im[0]+z_im[2]) - (z_im[1]+z_im[3]);
              data_re[3]  <= (z_re[0]-z_re[2]) - (z_im[1]-z_im[3]);
              data_im[3]  <= (z_im[0]-z_im[2]) + (z_re[1]-z_re[3]);

              // Group 1: z[4..7] → data[4..7]
              data_re[4]  <= (z_re[4]+z_re[6]) + (z_re[5]+z_re[7]);
              data_im[4]  <= (z_im[4]+z_im[6]) + (z_im[5]+z_im[7]);
              data_re[5]  <= (z_re[4]-z_re[6]) + (z_im[5]-z_im[7]);
              data_im[5]  <= (z_im[4]-z_im[6]) - (z_re[5]-z_re[7]);
              data_re[6]  <= (z_re[4]+z_re[6]) - (z_re[5]+z_re[7]);
              data_im[6]  <= (z_im[4]+z_im[6]) - (z_im[5]+z_im[7]);
              data_re[7]  <= (z_re[4]-z_re[6]) - (z_im[5]-z_im[7]);
              data_im[7]  <= (z_im[4]-z_im[6]) + (z_re[5]-z_re[7]);

              // Group 2: z[8..11] → data[8..11]
              data_re[8]  <= (z_re[8]+z_re[10]) + (z_re[9]+z_re[11]);
              data_im[8]  <= (z_im[8]+z_im[10]) + (z_im[9]+z_im[11]);
              data_re[9]  <= (z_re[8]-z_re[10]) + (z_im[9]-z_im[11]);
              data_im[9]  <= (z_im[8]-z_im[10]) - (z_re[9]-z_re[11]);
              data_re[10] <= (z_re[8]+z_re[10]) - (z_re[9]+z_re[11]);
              data_im[10] <= (z_im[8]+z_im[10]) - (z_im[9]+z_im[11]);
              data_re[11] <= (z_re[8]-z_re[10]) - (z_im[9]-z_im[11]);
              data_im[11] <= (z_im[8]-z_im[10]) + (z_re[9]-z_re[11]);

              // Group 3: z[12..15] → data[12..15]
              data_re[12] <= (z_re[12]+z_re[14]) + (z_re[13]+z_re[15]);
              data_im[12] <= (z_im[12]+z_im[14]) + (z_im[13]+z_im[15]);
              data_re[13] <= (z_re[12]-z_re[14]) + (z_im[13]-z_im[15]);
              data_im[13] <= (z_im[12]-z_im[14]) - (z_re[13]-z_re[15]);
              data_re[14] <= (z_re[12]+z_re[14]) - (z_re[13]+z_re[15]);
              data_im[14] <= (z_im[12]+z_im[14]) - (z_im[13]+z_im[15]);
              data_re[15] <= (z_re[12]-z_re[14]) - (z_im[13]-z_im[15]);
              data_im[15] <= (z_im[12]-z_im[14]) + (z_re[13]-z_re[15]);
            end

            // ----------------------------------------------------------
            //  Step 1: Stage 2, group g=0 — twiddles all W_16^0=1 (trivial)
            //  Same formula as Stage 1 but on data[] not z[] wires, stride-4.
            // ----------------------------------------------------------
            4'd1: begin
              data_re[0]  <= (data_re[0]+data_re[8])  + (data_re[4]+data_re[12]);
              data_im[0]  <= (data_im[0]+data_im[8])  + (data_im[4]+data_im[12]);
              data_re[4]  <= (data_re[0]-data_re[8])  + (data_im[4]-data_im[12]);
              data_im[4]  <= (data_im[0]-data_im[8])  - (data_re[4]-data_re[12]);
              data_re[8]  <= (data_re[0]+data_re[8])  - (data_re[4]+data_re[12]);
              data_im[8]  <= (data_im[0]+data_im[8])  - (data_im[4]+data_im[12]);
              data_re[12] <= (data_re[0]-data_re[8])  - (data_im[4]-data_im[12]);
              data_im[12] <= (data_im[0]-data_im[8])  + (data_re[4]-data_re[12]);
            end

            // ----------------------------------------------------------
            //  Steps 2-5: Stage 2, group g=1 — twiddles W_16^1, W_16^2, W_16^3
            //  Elements: p0=data[1], p1=data[5], p2=data[9], p3=data[13]
            // ----------------------------------------------------------
            4'd2: begin  // q1 = data[5] * W_16^1 = (3784, -1567)
              temp1_re <= ( data_re[5] * 32'sd3784 + data_im[5] * 32'sd1567) >>> SCALE;
              temp1_im <= (-data_re[5] * 32'sd1567 + data_im[5] * 32'sd3784) >>> SCALE;
            end
            4'd3: begin  // q2 = data[9] * W_16^2 = (2896, -2896)
              temp2_re <= ( data_re[9] * 32'sd2896 + data_im[9] * 32'sd2896) >>> SCALE;
              temp2_im <= (-data_re[9] * 32'sd2896 + data_im[9] * 32'sd2896) >>> SCALE;
            end
            4'd4: begin  // q3 = data[13] * W_16^3 = (1567, -3784)
              temp3_re <= ( data_re[13] * 32'sd1567 + data_im[13] * 32'sd3784) >>> SCALE;
              temp3_im <= (-data_re[13] * 32'sd3784 + data_im[13] * 32'sd1567) >>> SCALE;
            end
            4'd5: begin  // combine: write data[1,5,9,13]
              data_re[1]  <= (data_re[1]+temp2_re) + (temp1_re+temp3_re);
              data_im[1]  <= (data_im[1]+temp2_im) + (temp1_im+temp3_im);
              data_re[5]  <= (data_re[1]-temp2_re) + (temp1_im-temp3_im);
              data_im[5]  <= (data_im[1]-temp2_im) - (temp1_re-temp3_re);
              data_re[9]  <= (data_re[1]+temp2_re) - (temp1_re+temp3_re);
              data_im[9]  <= (data_im[1]+temp2_im) - (temp1_im+temp3_im);
              data_re[13] <= (data_re[1]-temp2_re) - (temp1_im-temp3_im);
              data_im[13] <= (data_im[1]-temp2_im) + (temp1_re-temp3_re);
            end

            // ----------------------------------------------------------
            //  Steps 6-9: Stage 2, group g=2 — twiddles W_16^2, W_16^4=-j, W_16^6
            //  Elements: p0=data[2], p1=data[6], p2=data[10], p3=data[14]
            // ----------------------------------------------------------
            4'd6: begin  // q1 = data[6] * W_16^2 = (2896, -2896)
              temp1_re <= ( data_re[6] * 32'sd2896 + data_im[6] * 32'sd2896) >>> SCALE;
              temp1_im <= (-data_re[6] * 32'sd2896 + data_im[6] * 32'sd2896) >>> SCALE;
            end
            4'd7: begin  // q2 = data[10] * W_16^4 = -j  (trivial: re'=+im, im'=-re)
              temp2_re <=  data_im[10];
              temp2_im <= -data_re[10];
            end
            4'd8: begin  // q3 = data[14] * W_16^6 = (-2896, -2897)
              temp3_re <= (-data_re[14] * 32'sd2896 + data_im[14] * 32'sd2897) >>> SCALE;
              temp3_im <= (-data_re[14] * 32'sd2897 - data_im[14] * 32'sd2896) >>> SCALE;
            end
            4'd9: begin  // combine: write data[2,6,10,14]
              data_re[2]  <= (data_re[2]+temp2_re) + (temp1_re+temp3_re);
              data_im[2]  <= (data_im[2]+temp2_im) + (temp1_im+temp3_im);
              data_re[6]  <= (data_re[2]-temp2_re) + (temp1_im-temp3_im);
              data_im[6]  <= (data_im[2]-temp2_im) - (temp1_re-temp3_re);
              data_re[10] <= (data_re[2]+temp2_re) - (temp1_re+temp3_re);
              data_im[10] <= (data_im[2]+temp2_im) - (temp1_im+temp3_im);
              data_re[14] <= (data_re[2]-temp2_re) - (temp1_im-temp3_im);
              data_im[14] <= (data_im[2]-temp2_im) + (temp1_re-temp3_re);
            end

            // ----------------------------------------------------------
            //  Steps 10-13: Stage 2, group g=3 — twiddles W_16^3, W_16^6, W_16^9
            //  W_16^9 = conj(W_16^7) = (-3784, +1569)
            //  Elements: p0=data[3], p1=data[7], p2=data[11], p3=data[15]
            // ----------------------------------------------------------
            4'd10: begin  // q1 = data[7] * W_16^3 = (1567, -3784)
              temp1_re <= ( data_re[7] * 32'sd1567 + data_im[7] * 32'sd3784) >>> SCALE;
              temp1_im <= (-data_re[7] * 32'sd3784 + data_im[7] * 32'sd1567) >>> SCALE;
            end
            4'd11: begin  // q2 = data[11] * W_16^6 = (-2896, -2897)
              temp2_re <= (-data_re[11] * 32'sd2896 + data_im[11] * 32'sd2897) >>> SCALE;
              temp2_im <= (-data_re[11] * 32'sd2897 - data_im[11] * 32'sd2896) >>> SCALE;
            end
            4'd12: begin  // q3 = data[15] * W_16^9 = (-3784, +1569)
              temp3_re <= (-data_re[15] * 32'sd3784 - data_im[15] * 32'sd1569) >>> SCALE;
              temp3_im <= ( data_re[15] * 32'sd1569 - data_im[15] * 32'sd3784) >>> SCALE;
            end
            4'd13: begin  // combine: write data[3,7,11,15]
              data_re[3]  <= (data_re[3]+temp2_re) + (temp1_re+temp3_re);
              data_im[3]  <= (data_im[3]+temp2_im) + (temp1_im+temp3_im);
              data_re[7]  <= (data_re[3]-temp2_re) + (temp1_im-temp3_im);
              data_im[7]  <= (data_im[3]-temp2_im) - (temp1_re-temp3_re);
              data_re[11] <= (data_re[3]+temp2_re) - (temp1_re+temp3_re);
              data_im[11] <= (data_im[3]+temp2_im) - (temp1_im+temp3_im);
              data_re[15] <= (data_re[3]-temp2_re) - (temp1_im-temp3_im);
              data_im[15] <= (data_im[3]-temp2_im) + (temp1_re-temp3_re);
            end

            default: ;

          endcase
        end

        // ==============================================================
        //  RECOMBINE – unpack 16-pt FFT Y[k] into 32-pt FFT X[k]
        //  X[k] = (E[k] - j*W_32^k*D[k]) / 2  where
        //    E[k] = Y[k] + conj(Y[16-k]),  D[k] = Y[k] - conj(Y[16-k])
        //
        //  Paired approach: process k=0..8 (18 cycles total).
        //  Each pair (k, 16-k) shares E,D inputs so both X[k] and X[16-k]
        //  (plus their Hermitian copies) are written in the same sub=1 cycle.
        //  This avoids in-place corruption: reads of Y[16-k] (indices 9..15)
        //  would fail if k=9..15 were processed after their Y[] values were
        //  overwritten by earlier writes to X[7..1].
        //
        //  Sub=0: load E[k] → temp1, D[k] → temp2 from data_re/im[k] and [16-k]
        //  Sub=1: combinational recomb_prod = W_32^k * temp2, write outputs
        //
        //  k=0 (steps 0-1): writes X[0] (DC) and X[16] (Nyquist), both real
        //  k=1..7 (steps 2-15): writes X[k], X[32-k]=conj(X[k]),
        //                              X[16-k],  X[16+k]=conj(X[16-k])
        //  k=8 (steps 16-17): writes X[8] and X[24]=conj(X[8])
        // ==============================================================
        S_RECOMBINE: begin
          recomb_step <= recomb_step + 1;

          if (recomb_sub == 1'b0) begin
            // sub=0: compute E[k] and D[k]
            // conj(Y[16-k]) indexed by recomb_k_conj = (16-k) mod 16 = 4'd0-recomb_k
            temp1_re <= data_re[recomb_k] + data_re[recomb_k_conj];  // E.re
            temp1_im <= data_im[recomb_k] - data_im[recomb_k_conj];  // E.im
            temp2_re <= data_re[recomb_k] - data_re[recomb_k_conj];  // D.re
            temp2_im <= data_im[recomb_k] + data_im[recomb_k_conj];  // D.im

          end else begin
            // sub=1: recomb_prod = W_32^k * D[k] (combinational via w32/temp2)
            // P16 = conj(P) since W_32^(16-k) = -conj(W_32^k) and D[16-k] = -conj(D[k])
            case (recomb_k)

              4'd0: begin
                // X[0] and X[16] are purely real for real input
                data_re[0]  <= (temp1_re + recomb_prod_im) >>> 1;
                data_im[0]  <=  32'sd0;
                data_re[16] <= (temp1_re - recomb_prod_im) >>> 1;
                data_im[16] <=  32'sd0;
              end

              4'd8: begin
                // 16-k = k = 8, so only 2 unique outputs: X[8] and X[24]=conj(X[8])
                data_re[8]  <= (temp1_re + recomb_prod_im) >>> 1;
                data_im[8]  <= (temp1_im - recomb_prod_re) >>> 1;
                data_re[24] <= (temp1_re + recomb_prod_im) >>> 1;
                data_im[24] <= (recomb_prod_re - temp1_im) >>> 1;
              end

              default: begin
                // k=1..7: 4 unique outputs per pair
                // X[k]        .re = (E.re + P.im)/2
                // X[k]        .im = (E.im - P.re)/2
                // X[32-k]     .re = X[k].re              (Hermitian)
                // X[32-k]     .im = -X[k].im             (Hermitian)
                // X[16-k]     .re = (E.re - P.im)/2      (P16 = conj(P))
                // X[16-k]     .im = -(E.im + P.re)/2
                // X[16+k]     .re = X[16-k].re           (Hermitian)
                // X[16+k]     .im = -X[16-k].im = (E.im + P.re)/2
                data_re[recomb_k]                    <= (temp1_re + recomb_prod_im) >>> 1;
                data_im[recomb_k]                    <= (temp1_im - recomb_prod_re) >>> 1;
                data_re[5'd32 - {1'b0, recomb_k}]   <= (temp1_re + recomb_prod_im) >>> 1;
                data_im[5'd32 - {1'b0, recomb_k}]   <= (recomb_prod_re - temp1_im) >>> 1;
                data_re[5'd16 - {1'b0, recomb_k}]   <= (temp1_re - recomb_prod_im) >>> 1;
                data_im[5'd16 - {1'b0, recomb_k}]   <= (-temp1_im - recomb_prod_re) >>> 1;
                data_re[5'd16 + {1'b0, recomb_k}]   <= (temp1_re - recomb_prod_im) >>> 1;
                data_im[5'd16 + {1'b0, recomb_k}]   <= (temp1_im + recomb_prod_re) >>> 1;
              end
            endcase
          end
        end

        // ==============================================================
        //  STORE_DATA – write register file contents back to SRAM
        //  Write strobe + data driven by combinational output block above
        // ==============================================================
        S_STORE_DATA: begin
          if (io_cnt == store_total - 1)
            io_cnt <= '0;
          else
            io_cnt <= io_cnt + 1;
        end

        // ==============================================================
        //  FINISH – assert done flag, wait for CPU to de-assert enable
        // ==============================================================
        S_FINISH: begin
          fft_finished <= 1'b1;
        end

        default: ;

      endcase
    end
  end

endmodule
