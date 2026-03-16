/*##########################################################################
###
### Register-file FFT accelerator (data-reuse optimisation)
###
###     Replaces the baseline's per-butterfly SRAM read/write pattern with
###     three bulk phases:
###       1. LOAD  – read twiddles + input data from SRAM into registers
###       2. COMPUTE – all 5 FFT stages execute from a 32×2 register file
###       3. STORE – write results back to SRAM
###
###     Expected cycle count for N=32:
###       INIT(1) + LOAD_TW(10) + LOAD_DATA(64) + COMPUTE(80) + STORE(64) + FINISH(1) = 220
###
###     Interface is 100% compatible with the baseline accelerator.v wrapper.
###
###     TU Delft ET4351 – 2026 Project
###
##########################################################################*/
module accelerator_fft #(
    parameter integer LOG_MAX_N        = 32,
    parameter integer MEM_WIDTH        = 32,
    parameter integer ADDR_WIDTH       = 32,
    localparam        LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)
) (
    input  wire clk,
    input  wire resetn,

    input  wire reset_accel,
    input  wire enable_accel,

    input  wire [LOG_MAX_N-1:0]          number_data,
    input  wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,

    output reg  [ 3:0] accel_mem_wstrb,
    input  wire [31:0] accel_mem_rdata,
    output reg  [31:0] accel_mem_wdata,
    output reg  [31:0] accel_mem_addr,

    output reg fft_finished
);

  /*============================================================
      PARAMETERS
  ============================================================*/
  localparam MAX_FFT_N      = 32;
  localparam MAX_FFT_STAGES = $clog2(MAX_FFT_N);          // 5
  localparam IDX_W          = $clog2(MAX_FFT_N);          // 5
  localparam IO_CNT_W       = $clog2(2 * MAX_FFT_N) + 1;  // 7
  localparam SCALE          = 12;

  /*============================================================
      FSM — encoding unchanged from baseline
  ============================================================*/
  localparam [2:0]
    S_INIT         = 3'd0,
    S_LOAD_TWIDDLE = 3'd1,
    S_LOAD_DATA    = 3'd2,
    S_COMPUTE      = 3'd3,
    S_STORE_DATA   = 3'd4,
    S_FINISH       = 3'd5;

  reg [2:0] state_reg;
  reg [2:0] next_state;

  /*============================================================
      REGISTER FILES
  ============================================================*/
  reg signed [MEM_WIDTH-1:0] data_re [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] data_im [0:MAX_FFT_N-1];
  reg signed [MEM_WIDTH-1:0] tw_re   [0:MAX_FFT_STAGES-1];
  reg signed [MEM_WIDTH-1:0] tw_im   [0:MAX_FFT_STAGES-1];

  /*============================================================
      COUNTERS
  ============================================================*/
  reg [IO_CNT_W-1:0] io_cnt;

  /*============================================================
      FFT LOOP VARIABLES
  ============================================================*/
  reg [LOG_MAX_FFT_STAGES-1:0] stage;
  reg [LOG_MAX_N-1:0]          m;
  reg [LOG_MAX_N-2:0]          half;
  reg [LOG_MAX_N-1:0]          base;
  reg [LOG_MAX_N-2:0]          k;
  reg signed [MEM_WIDTH-1:0]   w_re;
  reg signed [MEM_WIDTH-1:0]   w_im;

  /*============================================================
      LOOP TERMINATION WIRES
  ============================================================*/
  wire [LOG_MAX_N-2:0]          next_k;
  wire [LOG_MAX_N-1:0]          next_base;
  wire [LOG_MAX_FFT_STAGES-1:0] next_stage;
  wire                          butterfly_loop_finished;
  wire                          base_loop_finished;
  wire                          stage_loop_finished;
  wire                          all_done;

  assign next_k                  = k + 1'b1;
  assign next_base               = base + m;
  assign next_stage              = stage + 1'b1;
  assign butterfly_loop_finished = (next_k == half);
  assign base_loop_finished      = (next_base == number_data);
  assign stage_loop_finished     = (stage == fft_stages);
  assign all_done                = butterfly_loop_finished & base_loop_finished
                                   & stage_loop_finished;

  /*============================================================
      ADDRESS HELPERS
      Identical to baseline — SRAM has async read so driving
      the current io_cnt each cycle is correct; rdata is valid
      before the next rising edge.
  ============================================================*/
  wire [31:0]         start_input_address;
  wire [IO_CNT_W-1:0] tw_total;
  wire [IO_CNT_W-1:0] data_total;
  wire                tw_load_done;
  wire                data_load_done;

  assign start_input_address = {{(32-LOG_MAX_FFT_STAGES-1){1'b0}}, fft_stages, 1'b0};
  assign tw_total             = {fft_stages, 1'b0};
  // number_data[IDX_W:0] is IDX_W+1 = 6 bits, correctly capturing N=32 = 6'b100000.
  assign data_total           = {number_data[IDX_W:0], 1'b0};
  assign tw_load_done         = (io_cnt == tw_total   - 1'b1);
  assign data_load_done       = (io_cnt == data_total - 1'b1);

  /*============================================================
      BUTTERFLY INDICES
      idx_v reuses idx_u, removing one adder from the critical
      path to the register-file read address.
  ============================================================*/
  wire [IDX_W-1:0] idx_u;
  wire [IDX_W-1:0] idx_v;

  assign idx_u = base[IDX_W-1:0] + k[IDX_W-1:0];
  assign idx_v = idx_u + half[IDX_W-1:0];

  /*============================================================
      BUTTERFLY DATAPATH — fully combinational wires.

      Declaring the datapath as continuous assignments (wires)
      rather than a combinational always @(*) block gives the
      synthesiser maximum freedom to optimise the critical path:
      it can share partial products across the four multipliers
      and pipeline the tree however timing demands.

      The shift is applied once after accumulation (matching the
      original exactly) so fixed-point rounding is identical.
  ============================================================*/

  // t = w * data[v]
  wire signed [2*MEM_WIDTH-1:0] t_re_full;
  wire signed [2*MEM_WIDTH-1:0] t_im_full;
  wire signed [MEM_WIDTH-1:0]   t_re;
  wire signed [MEM_WIDTH-1:0]   t_im;

  assign t_re_full = data_re[idx_v] * w_re - data_im[idx_v] * w_im;
  assign t_im_full = data_re[idx_v] * w_im + data_im[idx_v] * w_re;
  assign t_re      = t_re_full >>> SCALE;
  assign t_im      = t_im_full >>> SCALE;

  // butterfly outputs
  wire signed [MEM_WIDTH-1:0] bf_e_re;
  wire signed [MEM_WIDTH-1:0] bf_e_im;
  wire signed [MEM_WIDTH-1:0] bf_o_re;
  wire signed [MEM_WIDTH-1:0] bf_o_im;

  assign bf_e_re = data_re[idx_u] + t_re;
  assign bf_e_im = data_im[idx_u] + t_im;
  assign bf_o_re = data_re[idx_u] - t_re;
  assign bf_o_im = data_im[idx_u] - t_im;

  // twiddle rotation: w' = w * tw[stage-1]
  wire signed [2*MEM_WIDTH-1:0] w_re_next_full;
  wire signed [2*MEM_WIDTH-1:0] w_im_next_full;
  wire signed [MEM_WIDTH-1:0]   w_re_next;
  wire signed [MEM_WIDTH-1:0]   w_im_next;

  assign w_re_next_full = w_re * tw_re[stage - 1'b1] - w_im * tw_im[stage - 1'b1];
  assign w_im_next_full = w_re * tw_im[stage - 1'b1] + w_im * tw_re[stage - 1'b1];
  assign w_re_next      = w_re_next_full >>> SCALE;
  assign w_im_next      = w_im_next_full >>> SCALE;

  /*============================================================
      FSM — STATE REGISTER
  ============================================================*/
  always @(posedge clk) begin
    if (reset_accel)
      state_reg <= S_INIT;
    else
      state_reg <= next_state;
  end

  /*============================================================
      FSM — NEXT-STATE LOGIC (combinational)
  ============================================================*/
  always @(*) begin
    case (state_reg)
      S_INIT:
        if (enable_accel)
          next_state = (number_data[LOG_MAX_N-1:1] == {(LOG_MAX_N-1){1'b0}})
                       ? S_FINISH
                       : S_LOAD_TWIDDLE;
        else
          next_state = S_INIT;

      S_LOAD_TWIDDLE:
        next_state = tw_load_done   ? S_LOAD_DATA : S_LOAD_TWIDDLE;

      S_LOAD_DATA:
        next_state = data_load_done ? S_COMPUTE   : S_LOAD_DATA;

      S_COMPUTE:
        next_state = all_done ? S_STORE_DATA : S_COMPUTE;

      S_STORE_DATA:
        next_state = data_load_done ? S_FINISH : S_STORE_DATA;

      S_FINISH:
        next_state = enable_accel ? S_FINISH : S_INIT;

      default:
        next_state = S_INIT;
    endcase
  end

  /*============================================================
      FSM — MEMORY INTERFACE (combinational)
  ============================================================*/
  always @(*) begin
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = 32'd0;
    accel_mem_addr  = 32'd0;

    case (state_reg)
      S_LOAD_TWIDDLE:
        accel_mem_addr = {{(32-IO_CNT_W){1'b0}}, io_cnt};

      S_LOAD_DATA:
        accel_mem_addr = start_input_address + {{(32-IO_CNT_W){1'b0}}, io_cnt};

      S_STORE_DATA: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + {{(32-IO_CNT_W){1'b0}}, io_cnt};
        accel_mem_wdata = io_cnt[0]
                          ? data_im[io_cnt[IO_CNT_W-1:1]]
                          : data_re[io_cnt[IO_CNT_W-1:1]];
      end

      default: ;
    endcase
  end

  /*============================================================
      FSM — SEQUENTIAL DATAPATH
  ============================================================*/
  integer i;

  always @(posedge clk) begin
    if (reset_accel) begin
      stage        <= 1'b1;
      m            <= 'd2;
      half         <= 1'b1;
      base         <= {LOG_MAX_N{1'b0}};
      k            <= {(LOG_MAX_N-1){1'b0}};
      w_re         <= {{(MEM_WIDTH-SCALE-1){1'b0}}, 1'b1, {SCALE{1'b0}}};
      w_im         <= {MEM_WIDTH{1'b0}};
      io_cnt       <= {IO_CNT_W{1'b0}};
      fft_finished <= 1'b0;
      // data_re/im and tw_re/im are not reset here — they are fully
      // overwritten by S_LOAD_TWIDDLE and S_LOAD_DATA before any read.
      // This reduces the reset fanout by 74 registers.
    end else begin
      case (state_reg)

        // ----------------------------------------------------------
        //  INIT — re-initialise loop variables for a fresh run
        // ----------------------------------------------------------
        S_INIT: begin
          stage        <= 1'b1;
          m            <= 'd2;
          half         <= 1'b1;
          base         <= {LOG_MAX_N{1'b0}};
          k            <= {(LOG_MAX_N-1){1'b0}};
          w_re         <= {{(MEM_WIDTH-SCALE-1){1'b0}}, 1'b1, {SCALE{1'b0}}};
          w_im         <= {MEM_WIDTH{1'b0}};
          io_cnt       <= {IO_CNT_W{1'b0}};
          fft_finished <= 1'b0;
        end

        // ----------------------------------------------------------
        //  LOAD_TWIDDLE
        // ----------------------------------------------------------
        S_LOAD_TWIDDLE: begin
          if (io_cnt[0] == 1'b0)
            tw_re[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;
          else
            tw_im[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;

          io_cnt <= tw_load_done ? {IO_CNT_W{1'b0}} : io_cnt + 1'b1;
        end

        // ----------------------------------------------------------
        //  LOAD_DATA
        // ----------------------------------------------------------
        S_LOAD_DATA: begin
          if (io_cnt[0] == 1'b0)
            data_re[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;
          else
            data_im[io_cnt[IO_CNT_W-1:1]] <= accel_mem_rdata;

          io_cnt <= data_load_done ? {IO_CNT_W{1'b0}} : io_cnt + 1'b1;
        end

        // ----------------------------------------------------------
        //  COMPUTE — one butterfly per cycle, register-to-register
        // ----------------------------------------------------------
        S_COMPUTE: begin
          data_re[idx_u] <= bf_e_re;
          data_im[idx_u] <= bf_e_im;
          data_re[idx_v] <= bf_o_re;
          data_im[idx_v] <= bf_o_im;

          if (all_done) begin
            // nothing — transition handled by next-state logic
          end else if (butterfly_loop_finished && base_loop_finished) begin
            stage <= next_stage;
            m     <= 1 << next_stage;
            half  <= 1 << stage;
            base  <= {LOG_MAX_N{1'b0}};
            k     <= {(LOG_MAX_N-1){1'b0}};
            w_re  <= {{(MEM_WIDTH-SCALE-1){1'b0}}, 1'b1, {SCALE{1'b0}}};
            w_im  <= {MEM_WIDTH{1'b0}};
          end else if (butterfly_loop_finished) begin
            base  <= next_base;
            k     <= {(LOG_MAX_N-1){1'b0}};
            w_re  <= {{(MEM_WIDTH-SCALE-1){1'b0}}, 1'b1, {SCALE{1'b0}}};
            w_im  <= {MEM_WIDTH{1'b0}};
          end else begin
            k    <= next_k;
            w_re <= w_re_next;
            w_im <= w_im_next;
          end
        end

        // ----------------------------------------------------------
        //  STORE_DATA
        // ----------------------------------------------------------
        S_STORE_DATA: begin
          io_cnt <= data_load_done ? {IO_CNT_W{1'b0}} : io_cnt + 1'b1;
        end

        // ----------------------------------------------------------
        //  FINISH
        // ----------------------------------------------------------
        S_FINISH: begin
          fft_finished <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule
