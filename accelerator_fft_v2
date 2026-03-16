/*##########################################################################
###
### Register-file FFT accelerator (data-reuse optimisation, pipelining)
###
###     Replaces the baseline's per-butterfly SRAM read/write pattern with
###     three bulk phases:
###       1. LOAD  – read twiddles + input data from SRAM into registers
###       2. COMPUTE – all 5 FFT stages execute from a 32×2 register file
###       3. STORE – write results back to SRAM
###
###     TU Delft ET4351 – 2026 Project
###
##########################################################################*/
module accelerator_fft #(
    parameter integer LOG_MAX_N   = 32,
    parameter integer MEM_WIDTH   = 32,
    parameter integer ADDR_WIDTH  = 32,
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)
) (
    input wire clk,
    input wire resetn,

    input wire reset_accel,
    input wire enable_accel,

    input wire [LOG_MAX_N-1:0]          number_data,
    input wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,

    output reg  [ 3:0] accel_mem_wstrb,
    input  wire [31:0] accel_mem_rdata,
    output reg  [31:0] accel_mem_wdata,
    output reg  [31:0] accel_mem_addr,

    output reg fft_finished
);

  /*========================================================================================
        PARAMETERS  (unchanged)
    ========================================================================================*/
  localparam MAX_FFT_N      = 32;
  localparam MAX_FFT_STAGES = $clog2(MAX_FFT_N);
  localparam IDX_W          = $clog2(MAX_FFT_N);
  localparam IO_CNT_W       = $clog2(2 * MAX_FFT_N) + 1;
  localparam SCALE          = 12;

  /*========================================================================================
        FSM STATE ENCODING  (unchanged)
    ========================================================================================*/
  localparam [2:0] S_INIT         = 3'd0,
                   S_LOAD_TWIDDLE = 3'd1,
                   S_LOAD_DATA    = 3'd2,
                   S_COMPUTE      = 3'd3,
                   S_STORE_DATA   = 3'd4,
                   S_FINISH       = 3'd5;

  reg [2:0] state_reg;
  reg [2:0] next_state;

  /*========================================================================================
        REGISTER FILES  (unchanged)
    ========================================================================================*/
  reg signed [MEM_WIDTH-1:0] data_re [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] data_im [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] tw_re   [0:MAX_FFT_STAGES-1];
  reg signed [MEM_WIDTH-1:0] tw_im   [0:MAX_FFT_STAGES-1];

  /*========================================================================================
        LOAD / STORE COUNTER  (unchanged)
    ========================================================================================*/
  reg [IO_CNT_W-1:0] io_cnt;

  /*========================================================================================
        FFT LOOP VARIABLES  (unchanged)
    ========================================================================================*/
  reg [LOG_MAX_FFT_STAGES-1:0] stage;
  reg [LOG_MAX_N-1:0]          m;
  reg [LOG_MAX_N-2:0]          half;
  reg [LOG_MAX_N-1:0]          base;
  reg [LOG_MAX_N-2:0]          k;
  reg signed [MEM_WIDTH-1:0]   w_re;
  reg signed [MEM_WIDTH-1:0]   w_im;

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
        ADDRESS HELPERS  (unchanged)
    ========================================================================================*/
  wire [31:0]        start_input_address;
  assign start_input_address = fft_stages << 1;

  wire [IO_CNT_W-1:0] tw_total;
  wire [IO_CNT_W-1:0] data_total;
  assign tw_total   = fft_stages << 1;
  assign data_total = number_data[IDX_W:0] << 1;

  /*========================================================================================
        REGISTER FILE READ INDICES  (unchanged)
    ========================================================================================*/
  wire [IDX_W-1:0] idx_u;
  wire [IDX_W-1:0] idx_v;
  assign idx_u = base[IDX_W-1:0] + k[IDX_W-1:0];
  assign idx_v = base[IDX_W-1:0] + k[IDX_W-1:0] + half[IDX_W-1:0];

  /*========================================================================================
        PIPELINE STAGE 1 – MULTIPLY
        -----------------------------------------------------------------------
        Registered at the END of the cycle in which S_COMPUTE is entered.
        Inputs : data_re/im[idx_v], w_re, w_im, tw_re/im[stage-1]
        Outputs: four products for the butterfly (p_*) and two for twiddle
                 rotation (pr_*). All registered → no combinational chain
                 from multiply into add.
    ========================================================================================*/

  // Combinational multiply results (wide to avoid overflow before >>>SCALE)
  // Only the four products needed by the butterfly t_re/t_im are pipelined.
  // Twiddle rotation is handled by a separate path below (see TWIDDLE ROTATION).
  wire signed [2*MEM_WIDTH-1:0] comb_v_re_x_w_re;
  wire signed [2*MEM_WIDTH-1:0] comb_v_im_x_w_im;
  wire signed [2*MEM_WIDTH-1:0] comb_v_re_x_w_im;
  wire signed [2*MEM_WIDTH-1:0] comb_v_im_x_w_re;

  assign comb_v_re_x_w_re = data_re[idx_v] * w_re;
  assign comb_v_im_x_w_im = data_im[idx_v] * w_im;
  assign comb_v_re_x_w_im = data_re[idx_v] * w_im;
  assign comb_v_im_x_w_re = data_im[idx_v] * w_re;

  // Pipeline stage-1 flops (hold the four butterfly products between cycles)
  reg signed [2*MEM_WIDTH-1:0] p_v_re_x_w_re;
  reg signed [2*MEM_WIDTH-1:0] p_v_im_x_w_im;
  reg signed [2*MEM_WIDTH-1:0] p_v_re_x_w_im;
  reg signed [2*MEM_WIDTH-1:0] p_v_im_x_w_re;

  // Stage-1 captures the write-back addresses, u operands, and loop-done
  // flags so that stage 2 can complete its write-back one cycle later.
  reg [IDX_W-1:0]               p_idx_u,  p_idx_v;
  reg signed [MEM_WIDTH-1:0]    p_data_re_u, p_data_im_u;  // u operands for butterfly
  reg                            p_bf_done;   // butterfly_loop_finished
  reg                            p_base_done; // base_loop_finished
  reg                            p_stage_done;// stage_loop_finished
  reg                            p_valid;     // stage-1 output is valid

  /*========================================================================================
        PIPELINE STAGE 2 – ACCUMULATE / BUTTERFLY   (purely combinational)
        -----------------------------------------------------------------------
        Reads the registered products from stage 1, performs subtraction /
        addition (single adder depth) to produce t_re/t_im and the four
        butterfly outputs.  Results are written to the register file on the
        same posedge that latches stage-1 products for the NEXT butterfly.
    ========================================================================================*/
  wire signed [MEM_WIDTH-1:0] s2_t_re;
  wire signed [MEM_WIDTH-1:0] s2_t_im;
  wire signed [MEM_WIDTH-1:0] s2_bf_e_re;
  wire signed [MEM_WIDTH-1:0] s2_bf_e_im;
  wire signed [MEM_WIDTH-1:0] s2_bf_o_re;
  wire signed [MEM_WIDTH-1:0] s2_bf_o_im;

  // t = (v * w) >> SCALE  — subtraction/addition of already-computed products
  assign s2_t_re = (p_v_re_x_w_re - p_v_im_x_w_im) >>> SCALE;
  assign s2_t_im = (p_v_re_x_w_im + p_v_im_x_w_re) >>> SCALE;

  // butterfly add/subtract
  assign s2_bf_e_re = p_data_re_u + s2_t_re;
  assign s2_bf_e_im = p_data_im_u + s2_t_im;
  assign s2_bf_o_re = p_data_re_u - s2_t_re;
  assign s2_bf_o_im = p_data_im_u - s2_t_im;

  /*========================================================================================
        TWIDDLE ROTATION  (separate combinational path, NOT part of stage 2)
        -----------------------------------------------------------------------
        w_re_next = (w_re * tw_re[stage-1] - w_im * tw_im[stage-1]) >> SCALE
        w_im_next = (w_re * tw_im[stage-1] + w_im * tw_re[stage-1]) >> SCALE
        -----------------------------------------------------------------------
        Critically, this is computed from the CURRENT-CYCLE registered values
        of w_re/w_im and tw_re/im[stage-1] — not from any pipeline-stage-1
        product register.  This means the rotation result is always in phase
        with the butterfly being issued this cycle:
          cycle N issues butterfly k  →  w holds W^k
          w_re_next = W^k * W_m = W^(k+1)  →  stored into w_re on cycle N
          cycle N+1 issues butterfly k+1 with w = W^(k+1)  ✓
        The critical path of this path is one multiplier + one adder, which
        is identical to stage-1 and does NOT chain through any pipeline flop.
    ========================================================================================*/
  wire signed [MEM_WIDTH-1:0] w_re_next;
  wire signed [MEM_WIDTH-1:0] w_im_next;

  assign w_re_next = ((w_re * tw_re[stage - 1]) - (w_im * tw_im[stage - 1])) >>> SCALE;
  assign w_im_next = ((w_re * tw_im[stage - 1]) + (w_im * tw_re[stage - 1])) >>> SCALE;

  /*========================================================================================
        PIPELINE STALL / DRAIN CONTROL
        -----------------------------------------------------------------------
        When S_COMPUTE finishes its last butterfly (all three loop-done flags
        set in stage-1 context), we must let stage 2 drain before moving to
        S_STORE_DATA.  We hold S_COMPUTE for one extra cycle (drain_cycle)
        so the final butterfly result gets written back.
    ========================================================================================*/
  reg drain_cycle; // '1' during the one-cycle drain after the last butterfly

  /*========================================================================================
        FSM – STATE REGISTER  (unchanged)
    ========================================================================================*/
  always @(posedge clk) begin
    if (reset_accel)
      state_reg <= S_INIT;
    else
      state_reg <= next_state;
  end

  /*========================================================================================
        FSM – NEXT-STATE LOGIC  (combinational)
        Only the S_COMPUTE exit condition changes: we now also wait for
        drain_cycle to clear.
    ========================================================================================*/
  always @(*) begin
    case (state_reg)

      S_INIT:
        if (enable_accel)
          if (number_data[LOG_MAX_N-1:1] == 0)
            next_state = S_FINISH;
          else
            next_state = S_LOAD_TWIDDLE;
        else
          next_state = S_INIT;

      S_LOAD_TWIDDLE:
        if (io_cnt == tw_total - 1)
          next_state = S_LOAD_DATA;
        else
          next_state = S_LOAD_TWIDDLE;

      S_LOAD_DATA:
        if (io_cnt == data_total - 1)
          next_state = S_COMPUTE;
        else
          next_state = S_LOAD_DATA;

      // Exit only after drain_cycle has fired, ensuring the last butterfly
      // result has been written back to the register file.
      S_COMPUTE:
        if (p_valid && p_bf_done && p_base_done && p_stage_done && drain_cycle)
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
        FSM – OUTPUT / MEMORY INTERFACE  (unchanged)
    ========================================================================================*/
  always @(*) begin
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = 32'd0;
    accel_mem_addr  = 32'd0;

    case (state_reg)

      S_INIT: ;

      S_LOAD_TWIDDLE: begin
        accel_mem_addr = {{(32 - IO_CNT_W){1'b0}}, io_cnt};
      end

      S_LOAD_DATA: begin
        accel_mem_addr = start_input_address + {{(32 - IO_CNT_W){1'b0}}, io_cnt};
      end

      S_COMPUTE: ;

      S_STORE_DATA: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + {{(32 - IO_CNT_W){1'b0}}, io_cnt};
        if (io_cnt[0] == 1'b0)
          accel_mem_wdata = data_re[io_cnt[IO_CNT_W-1:1]];
        else
          accel_mem_wdata = data_im[io_cnt[IO_CNT_W-1:1]];
      end

      S_FINISH: ;
      default:  ;

    endcase
  end

  /*========================================================================================
        FSM – SEQUENTIAL DATAPATH  (posedge clk)

        S_COMPUTE is the only state that changes structurally.
        Every other state is byte-for-byte identical to the baseline.

        S_COMPUTE cycle-by-cycle behaviour:
        ─────────────────────────────────────────────────────────────────────
          cycle A  │ Stage-1 flops capture 8 raw products + loop context.
                   │ Stage-2 combinational output is based on the PREVIOUS
                   │ cycle's products (p_*), so the first valid write-back
                   │ occurs one cycle after S_COMPUTE is entered (p_valid).
                   │
          cycle A+1│ Stage-2 results (s2_bf_*) are written to data_re/im.
                   │ Stage-1 simultaneously latches the next butterfly.
                   │
        After the last butterfly's products are latched (p_bf/base/stage_done
        all '1'), drain_cycle is set for one cycle so that stage 2 can write
        the final result. Next-state logic only allows the transition to
        S_STORE_DATA once drain_cycle is asserted AND p_valid is '1'.
    ========================================================================================*/
  integer i;

  always @(posedge clk) begin
    if (reset_accel) begin
      stage        <= 'b1;
      m            <= 'd2;
      half         <= 'b1;
      base         <= '0;
      k            <= '0;
      w_re         <= 'b1 << SCALE;
      w_im         <= '0;
      io_cnt       <= '0;
      fft_finished <= 1'b0;
      p_valid      <= 1'b0;
      drain_cycle  <= 1'b0;

      for (i = 0; i < MAX_FFT_N; i = i + 1) begin
        data_re[i] <= 32'sd0;
        data_im[i] <= 32'sd0;
      end
      for (i = 0; i < MAX_FFT_STAGES; i = i + 1) begin
        tw_re[i] <= 32'sd0;
        tw_im[i] <= 32'sd0;
      end

      // Clear pipeline-stage-1 flops
      p_v_re_x_w_re <= 'sd0; p_v_im_x_w_im <= 'sd0;
      p_v_re_x_w_im <= 'sd0; p_v_im_x_w_re <= 'sd0;
      p_idx_u      <= '0;    p_idx_v      <= '0;
      p_data_re_u  <= '0;    p_data_im_u  <= '0;
      p_bf_done    <= 1'b0;
      p_base_done  <= 1'b0;
      p_stage_done <= 1'b0;

    end else begin
      case (state_reg)

        // ============================================================
        //  INIT  (unchanged)
        // ============================================================
        S_INIT: begin
          stage        <= 'b1;
          m            <= 'd2;
          half         <= 'b1;
          base         <= '0;
          k            <= '0;
          w_re         <= 'b1 << SCALE;
          w_im         <= '0;
          io_cnt       <= '0;
          fft_finished <= 1'b0;
          p_valid      <= 1'b0;
          drain_cycle  <= 1'b0;
        end

        // ============================================================
        //  LOAD_TWIDDLE  (unchanged)
        // ============================================================
        S_LOAD_TWIDDLE: begin
          if (io_cnt[0] == 1'b0)
            tw_re[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;
          else
            tw_im[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;

          if (io_cnt == tw_total - 1)
            io_cnt <= '0;
          else
            io_cnt <= io_cnt + 1;
        end

        // ============================================================
        //  LOAD_DATA  (unchanged)
        // ============================================================
        S_LOAD_DATA: begin
          if (io_cnt[0] == 1'b0)
            data_re[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;
          else
            data_im[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;

          if (io_cnt == data_total - 1)
            io_cnt <= '0;
          else
            io_cnt <= io_cnt + 1;
        end

        // ============================================================
        //  COMPUTE  — pipelined
        //
        //  Every cycle (while not draining):
        //    1. Stage-1 flops latch raw products + context for the
        //       CURRENT loop iteration (base, k, w, idx_u/v).
        //    2. If p_valid, stage-2 combinational results are written
        //       back to the register file (one cycle delayed write-back).
        //    3. Loop variables (stage, m, half, base, k, w) advance to
        //       the NEXT iteration — unless we are about to drain.
        //
        //  Drain cycle:
        //    When the last butterfly has been captured in stage-1
        //    (p_bf_done && p_base_done && p_stage_done), we set
        //    drain_cycle='1' and stop issuing new butterflies (no
        //    further stage-1 captures). Stage-2 still writes back the
        //    final result. Next-state logic sees drain_cycle and moves
        //    to S_STORE_DATA on the following edge.
        // ============================================================
        S_COMPUTE: begin

          // ----------------------------------------------------------
          //  Stage-2 write-back (one cycle after stage-1 latch)
          // ----------------------------------------------------------
          if (p_valid) begin
            data_re[p_idx_u] <= s2_bf_e_re;
            data_im[p_idx_u] <= s2_bf_e_im;
            data_re[p_idx_v] <= s2_bf_o_re;
            data_im[p_idx_v] <= s2_bf_o_im;
          end

          // ----------------------------------------------------------
          //  Drain: stage-1 has already captured the last butterfly;
          //  just let stage-2 write back and exit.
          // ----------------------------------------------------------
          if (drain_cycle) begin
            // Nothing more to issue. p_valid is still '1' so the
            // write-back above completes. Next state will be S_STORE_DATA.
            p_valid     <= 1'b0;
            drain_cycle <= 1'b0;

          // ----------------------------------------------------------
          //  Normal issue: latch products + context into stage-1 flops
          // ----------------------------------------------------------
          end else begin

            // Stage-1: latch the four butterfly products
            p_v_re_x_w_re <= comb_v_re_x_w_re;
            p_v_im_x_w_im <= comb_v_im_x_w_im;
            p_v_re_x_w_im <= comb_v_re_x_w_im;
            p_v_im_x_w_re <= comb_v_im_x_w_re;

            // Stage-1: latch register-file operands for the u element
            // (v operands already captured implicitly through products)
            p_data_re_u <= data_re[idx_u];
            p_data_im_u <= data_im[idx_u];

            // Stage-1: latch write-back addresses
            p_idx_u <= idx_u;
            p_idx_v <= idx_v;

            // Stage-1: latch loop-termination flags for this iteration
            p_bf_done    <= butterfly_loop_finished;
            p_base_done  <= base_loop_finished;
            p_stage_done <= stage_loop_finished;

            p_valid <= 1'b1;

            // ----------------------------------------------------------
            //  Advance loop variables for the NEXT butterfly
            //  (mirrors baseline exactly; uses CURRENT cycle's signals)
            // ----------------------------------------------------------
            if (butterfly_loop_finished && base_loop_finished && stage_loop_finished) begin
              // Last butterfly: stop issuing; next cycle is drain.
              drain_cycle <= 1'b1;
              // Loop variables do not need updating (we are done).
            end else if (butterfly_loop_finished && base_loop_finished) begin
              // Advance stage
              stage <= next_stage;
              m     <= 1 << next_stage;
              half  <= 1 << stage;
              base  <= '0;
              k     <= '0;
              w_re  <= 'b1 << SCALE;
              w_im  <= '0;
            end else if (butterfly_loop_finished) begin
              // Advance base group
              base  <= next_base;
              k     <= '0;
              w_re  <= 'b1 << SCALE;
              w_im  <= '0;
            end else begin
              // Next butterfly in current group.
              // w_re_next is computed combinationally from the CURRENT
              // cycle's w_re/w_im (registered) and tw_re/im[stage-1],
              // so it is always in phase with the butterfly being issued.
              k    <= next_k;
              w_re <= w_re_next;
              w_im <= w_im_next;
            end
          end
        end

        // ============================================================
        //  STORE_DATA  (unchanged)
        // ============================================================
        S_STORE_DATA: begin
          if (io_cnt == data_total - 1)
            io_cnt <= '0;
          else
            io_cnt <= io_cnt + 1;
        end

        // ============================================================
        //  FINISH  (unchanged)
        // ============================================================
        S_FINISH: begin
          fft_finished <= 1'b1;
        end

        default: ;

      endcase
    end
  end

endmodule
