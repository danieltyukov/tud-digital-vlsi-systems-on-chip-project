/*##########################################################################
###
### EE v2: D1 register-file + hardcoded twiddle LUT
###
###     Based on the D1 register-file architecture but replaces the
###     recursive twiddle update and SRAM twiddle loading with a
###     hardcoded combinational twiddle look-up table (LUT).
###
###     FSM phases:
###       1. LOAD_DATA – read input data from SRAM into registers
###       2. COMPUTE   – all 5 FFT stages execute from a 32x2 register file
###                      with twiddle factors sourced from a hardcoded LUT
###       3. STORE     – write results back to SRAM
###
###     The S_LOAD_TWIDDLE state from D1 is removed entirely since twiddle
###     factors are now provided by the LUT function.
###
###     Expected cycle count for N=32:
###       INIT(1) + LOAD_DATA(64) + COMPUTE(80) + STORE(64) + FINISH(1) = 210
###
###     SRAM layout is unchanged from baseline (twiddle data still present
###     in SRAM[0..2*stages-1], but simply ignored). The start_input_address
###     offset is preserved so LOAD_DATA and STORE_DATA address correctly.
###
###     Interface is 100% compatible with the baseline accelerator.v wrapper.
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
  localparam IO_CNT_W       = $clog2(2 * MAX_FFT_N) + 1;   // = 7  (counter width for LOAD/STORE)

  // Fixed-point scale (must match firmware)
  localparam SCALE = 12;

  /*========================================================================================
        FSM STATE ENCODING
    ========================================================================================*/
  localparam [2:0] S_INIT       = 3'd0,
                   S_LOAD_DATA  = 3'd1,
                   S_COMPUTE    = 3'd2,
                   S_STORE_DATA = 3'd3,
                   S_FINISH     = 3'd4;

  reg [2:0] state_reg;
  reg [2:0] next_state;   // combinational – declared reg for always-block usage

  /*========================================================================================
        REGISTER FILE  (the core of the optimisation)
    ========================================================================================*/
  // Data register file: 32 complex values = 64 x 32-bit registers
  reg signed [MEM_WIDTH-1:0] data_re [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] data_im [0:MAX_FFT_N-1];

  // No twiddle register file – twiddles come from hardcoded LUT

  /*========================================================================================
        LOAD / STORE COUNTER
    ========================================================================================*/
  reg [IO_CNT_W-1:0] io_cnt;    // shared counter for LOAD_DATA, STORE_DATA

  /*========================================================================================
        FFT LOOP VARIABLES  (identical semantics to baseline)
    ========================================================================================*/
  reg [LOG_MAX_FFT_STAGES-1:0] stage;   // current FFT stage  (1 ... fft_stages)
  reg [LOG_MAX_N-1:0]          m;       // butterflies span    (2, 4, 8, ..., N)
  reg [LOG_MAX_N-2:0]          half;    // half-span           (1, 2, 4, ..., N/2)
  reg [LOG_MAX_N-1:0]          base;    // base group start    (0, m, 2m, ...)
  reg [LOG_MAX_N-2:0]          k;       // butterfly index within group  (0 ... half-1)

  // No w_re / w_im running twiddle – replaced by LUT

  // Loop termination wires (same as baseline)
  wire [LOG_MAX_N-2:0]          next_k;
  wire [LOG_MAX_N-1:0]          next_base;
  wire [LOG_MAX_FFT_STAGES-1:0] next_stage;
  wire butterfly_loop_finished;
  wire base_loop_finished;
  wire stage_loop_finished;

  assign next_k    = k + 1;
  assign next_base = base + m;
  assign next_stage = stage + 1;
  assign butterfly_loop_finished = (next_k == half);
  assign base_loop_finished      = (next_base == number_data);
  assign stage_loop_finished     = (stage == fft_stages);

  /*========================================================================================
        ADDRESS HELPERS
    ========================================================================================*/
  // Twiddle factors still occupy SRAM[0 ... 2*fft_stages - 1] (written by firmware)
  // Input data occupies  SRAM[2*fft_stages ... 2*fft_stages + 2*N - 1]
  // We keep start_input_address to maintain correct SRAM addressing
  wire [31:0] start_input_address;
  assign start_input_address = fft_stages << 1;   // = 2 * fft_stages

  // LOAD/STORE totals
  wire [IO_CNT_W-1:0] data_total;
  assign data_total  = number_data[IDX_W:0] << 1;  // = 2 * N           (64 for N=32)

  /*========================================================================================
        HARDCODED TWIDDLE LUT
        Returns {w_re, w_im} for twiddle factor W_N^k given stage span m and index k.
        Values are Q12 fixed-point, matching Romeu's recursive computation exactly.
    ========================================================================================*/
  function [2*MEM_WIDTH-1:0] twiddle_lut;
    input [LOG_MAX_N-1:0] tf_m;
    input [LOG_MAX_N-2:0] tf_k;
    reg signed [MEM_WIDTH-1:0] tw_r, tw_i;
    begin
      tw_r = 32'sd4096;   // default: W^0 = (1, 0) in Q12
      tw_i = 32'sd0;

      case (tf_m)
        // Stage 1: m=2, only k=0
        32'd2: begin
          tw_r = 32'sd4096;  tw_i = 32'sd0;
        end

        // Stage 2: m=4, k=0..1
        32'd4: begin
          case (tf_k[0])
            1'd0: begin tw_r =  32'sd4096; tw_i =  32'sd0;     end
            1'd1: begin tw_r =  32'sd0;    tw_i = -32'sd4096;  end
          endcase
        end

        // Stage 3: m=8, k=0..3
        32'd8: begin
          case (tf_k[1:0])
            2'd0: begin tw_r =  32'sd4096; tw_i =  32'sd0;     end
            2'd1: begin tw_r =  32'sd2896; tw_i = -32'sd2896;  end
            2'd2: begin tw_r =  32'sd0;    tw_i = -32'sd4096;  end
            2'd3: begin tw_r = -32'sd2896; tw_i = -32'sd2896;  end
          endcase
        end

        // Stage 4: m=16, k=0..7
        32'd16: begin
          case (tf_k[2:0])
            3'd0: begin tw_r =  32'sd4096; tw_i =  32'sd0;     end
            3'd1: begin tw_r =  32'sd3784; tw_i = -32'sd1567;  end
            3'd2: begin tw_r =  32'sd2896; tw_i = -32'sd2896;  end
            3'd3: begin tw_r =  32'sd1567; tw_i = -32'sd3784;  end
            3'd4: begin tw_r =  32'sd0;    tw_i = -32'sd4096;  end
            3'd5: begin tw_r = -32'sd1567; tw_i = -32'sd3784;  end
            3'd6: begin tw_r = -32'sd2896; tw_i = -32'sd2897;  end
            3'd7: begin tw_r = -32'sd3784; tw_i = -32'sd1569;  end
          endcase
        end

        // Stage 5: m=32, k=0..15
        32'd32: begin
          case (tf_k[3:0])
            4'd0:  begin tw_r =  32'sd4096; tw_i =  32'sd0;     end
            4'd1:  begin tw_r =  32'sd4017; tw_i = -32'sd799;   end
            4'd2:  begin tw_r =  32'sd3783; tw_i = -32'sd1568;  end
            4'd3:  begin tw_r =  32'sd3404; tw_i = -32'sd2276;  end
            4'd4:  begin tw_r =  32'sd2894; tw_i = -32'sd2897;  end
            4'd5:  begin tw_r =  32'sd2273; tw_i = -32'sd3406;  end
            4'd6:  begin tw_r =  32'sd1564; tw_i = -32'sd3784;  end
            4'd7:  begin tw_r =  32'sd795;  tw_i = -32'sd4017;  end
            4'd8:  begin tw_r = -32'sd4;    tw_i = -32'sd4095;  end
            4'd9:  begin tw_r = -32'sd803;  tw_i = -32'sd4016;  end
            4'd10: begin tw_r = -32'sd1571; tw_i = -32'sd3782;  end
            4'd11: begin tw_r = -32'sd2279; tw_i = -32'sd3403;  end
            4'd12: begin tw_r = -32'sd2899; tw_i = -32'sd2893;  end
            4'd13: begin tw_r = -32'sd3408; tw_i = -32'sd2272;  end
            4'd14: begin tw_r = -32'sd3786; tw_i = -32'sd1564;  end
            4'd15: begin tw_r = -32'sd4019; tw_i = -32'sd796;   end
          endcase
        end

        default: begin
          tw_r = 32'sd4096;  tw_i = 32'sd0;
        end
      endcase

      twiddle_lut = {tw_r, tw_i};
    end
  endfunction

  /*========================================================================================
        BUTTERFLY COMPUTATION  (purely combinational)
    ========================================================================================*/
  // Register-file read indices (combinational from loop variables)
  wire [IDX_W-1:0] idx_u;
  wire [IDX_W-1:0] idx_v;
  assign idx_u = base[IDX_W-1:0] + k[IDX_W-1:0];
  assign idx_v = base[IDX_W-1:0] + k[IDX_W-1:0] + half[IDX_W-1:0];

  // LUT-based twiddle lookup
  wire [2*MEM_WIDTH-1:0] lut_result;
  wire signed [MEM_WIDTH-1:0] lut_w_re;
  wire signed [MEM_WIDTH-1:0] lut_w_im;
  assign lut_result = twiddle_lut(m, k);
  assign lut_w_re = lut_result[2*MEM_WIDTH-1:MEM_WIDTH];
  assign lut_w_im = lut_result[MEM_WIDTH-1:0];

  // Combinational butterfly datapath
  reg signed [MEM_WIDTH-1:0] t_re, t_im;
  reg signed [MEM_WIDTH-1:0] bf_e_re, bf_e_im;
  reg signed [MEM_WIDTH-1:0] bf_o_re, bf_o_im;

  always @(*) begin
    // --- Twiddle x v multiplication (twiddle from LUT) ---
    t_re = (data_re[idx_v] * lut_w_re - data_im[idx_v] * lut_w_im) >>> SCALE;
    t_im = (data_re[idx_v] * lut_w_im + data_im[idx_v] * lut_w_re) >>> SCALE;

    // --- Butterfly add / subtract ---
    bf_e_re = data_re[idx_u] + t_re;
    bf_e_im = data_im[idx_u] + t_im;
    bf_o_re = data_re[idx_u] - t_re;
    bf_o_im = data_im[idx_u] - t_im;
  end

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
        if (io_cnt == data_total - 1)
          next_state = S_COMPUTE;
        else
          next_state = S_LOAD_DATA;

      S_COMPUTE:
        if (butterfly_loop_finished && base_loop_finished && stage_loop_finished)
          next_state = S_STORE_DATA;
        else
          next_state = S_COMPUTE;

      S_STORE_DATA:
        if (io_cnt == data_total - 1)
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

      // ---- LOAD: present read address, SRAM responds combinationally ----
      S_LOAD_DATA: begin
        accel_mem_addr = start_input_address + {{(32 - IO_CNT_W){1'b0}}, io_cnt};
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
      // ---- Reset loop variables (same initial values as baseline) ----
      stage <= 'b1;
      m     <= 'd2;
      half  <= 'b1;
      base  <= '0;
      k     <= '0;
      io_cnt <= '0;
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
          stage <= 'b1;
          m     <= 'd2;
          half  <= 'b1;
          base  <= '0;
          k     <= '0;
          io_cnt <= '0;
          fft_finished <= 1'b0;
        end

        // ==============================================================
        //  LOAD_DATA – capture input data from SRAM into register file
        //  SRAM layout: [X[0].re, X[0].im, X[1].re, X[1].im, ...]
        //  Data starts at SRAM[start_input_address] (after twiddle region)
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
        //  COMPUTE – one butterfly per cycle, purely register-to-register
        //  Twiddle factors sourced from hardcoded LUT (no running w update)
        // ==============================================================
        S_COMPUTE: begin
          // ---- Write butterfly results to register file ----
          data_re[idx_u] <= bf_e_re;
          data_im[idx_u] <= bf_e_im;
          data_re[idx_v] <= bf_o_re;
          data_im[idx_v] <= bf_o_im;

          // ---- Update loop variables (mirrors baseline logic) ----
          if (butterfly_loop_finished && base_loop_finished && stage_loop_finished) begin
            // FFT complete – no counter update needed; next state -> STORE_DATA
          end else if (butterfly_loop_finished && base_loop_finished) begin
            // ---- Advance to next stage ----
            stage <= next_stage;
            m     <= 1 << next_stage;
            half  <= 1 << stage;        // stage hasn't updated yet -> this is correct
            base  <= '0;
            k     <= '0;
          end else if (butterfly_loop_finished) begin
            // ---- Advance to next base group (same stage) ----
            base  <= next_base;
            k     <= '0;
          end else begin
            // ---- Next butterfly in current group ----
            k    <= next_k;
          end
        end

        // ==============================================================
        //  STORE_DATA – write register file contents back to SRAM
        //  Write strobe + data driven by combinational output block above
        // ==============================================================
        S_STORE_DATA: begin
          if (io_cnt == data_total - 1)
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
