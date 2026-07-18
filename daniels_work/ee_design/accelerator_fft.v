module accelerator_fft #(
    parameter integer LOG_MAX_N   = 32,                // Number of bits to represent the maximum number of input samples
    parameter integer MEM_WIDTH = 32,  // Width of memory data
    parameter integer ADDR_WIDTH = 32,  // Width of memory address
    localparam LOG_MAX_FFT_STAGES = $clog2(LOG_MAX_N)  // Maximum number of stage in the FFT
) (
    input wire clk,
    input wire resetn,

    // Control input
    input wire reset_accel,
    input wire enable_accel,

    // Data input
    input wire [LOG_MAX_N-1:0] number_data,  // number_data is N in the algorithm
    input  wire [LOG_MAX_FFT_STAGES-1:0] fft_stages,          // Number of FFT stages required for the number of data provided

    // Memory inputs/outputs
    output reg  [ 4-1:0] accel_mem_wstrb,
    input  wire [32-1:0] accel_mem_rdata,
    output reg  [32-1:0] accel_mem_wdata,
    output reg  [32-1:0] accel_mem_addr,

    // Data output
    output reg fft_finished
);
  /*----------------------------------------------------------------------------------------
        Define FSM states and inner variables
    ----------------------------------------------------------------------------------------*/
  parameter INIT = 4'd0;
  parameter READ_W_M_RE = 4'd1;
  parameter READ_W_M_IM = 4'd2;
  parameter BUTTERFLY_READ_1_RE = 4'd3;
  parameter BUTTERFLY_READ_1_IM = 4'd4;
  parameter BUTTERFLY_READ_2_RE = 4'd5;
  parameter BUTTERFLY_READ_2_IM = 4'd6;
  parameter BUTTERFLY_COMPUTE = 4'd7;
  parameter BUTTERFLY_WRITE_1_RE = 4'd8;
  parameter BUTTERFLY_WRITE_1_IM = 4'd9;
  parameter BUTTERFLY_WRITE_2_RE = 4'd10;
  parameter BUTTERFLY_WRITE_2_IM = 4'd11;
  parameter FINISH = 4'd12;

  // Define state registers and next_state wires
  reg [3:0] state_reg;
  reg [3:0] next_state;  // THIS IS A WIRE. REG BECAUSE USED INSIDE AN ALWAYS BLOCK.

  // Define FFT variables
  // Registers
  reg [LOG_MAX_N-1:0] m;  // Support for a sequence of N=2**(LOG_MAX_N) input samples
  reg [LOG_MAX_FFT_STAGES-1:0] stage;  // Maximum number of stage in the FFT
  reg [LOG_MAX_N-1:0] base;  // Max is N = 2**(LOG_MAX_N)
  reg [LOG_MAX_N-2:0] k;  // Max is N/2 = 2**(LOG_MAX_N-1)
  reg [LOG_MAX_N-2:0] half;  // Max is N/2 = 2**(LOG_MAX_N-1)
  reg signed [MEM_WIDTH-1:0] w_m_re;  // Retained for baseline FSM compatibility
  reg signed [MEM_WIDTH-1:0] w_m_im;  // Retained for baseline FSM compatibility
  reg signed [MEM_WIDTH-1:0] u_re;  // Real part of u = X[base + k]
  reg signed [MEM_WIDTH-1:0] u_im;  // Imaginary part of u = X[base + k]
  reg signed [MEM_WIDTH-1:0] v_re;  // Real part of v = X[base + k + half]
  reg signed [MEM_WIDTH-1:0] v_im;  // Imaginary part of v = X[base + k + half]
  reg signed [MEM_WIDTH-1:0] e_re;  // Real part of e = u + t
  reg signed [MEM_WIDTH-1:0] e_im;  // Imaginary part of e = u + t
  reg signed [MEM_WIDTH-1:0] o_re;  // Real part of o = u - t
  reg signed [MEM_WIDTH-1:0] o_im;  // Imaginary part of o = u - t

  // Wires
  wire [LOG_MAX_FFT_STAGES-1:0] next_stage;
  wire [LOG_MAX_N-1:0] next_base;
  wire [LOG_MAX_N-2:0] next_k;
  wire [ADDR_WIDTH-1:0] start_input_address;
  wire [ADDR_WIDTH-1:0] mem_addr_base_k;
  wire [ADDR_WIDTH-1:0] mem_addr_base_k_plus_half;
  reg signed [MEM_WIDTH-1:0] t_re;  // Real part of t = w * X[base + k + half]
  reg signed [MEM_WIDTH-1:0] t_im;  // Imaginary part of t = w * X[base + k + half]

  wire [2*MEM_WIDTH-1:0] twiddle_pair;
  wire signed [MEM_WIDTH-1:0] w_re_lut;
  wire signed [MEM_WIDTH-1:0] w_im_lut;

  // Constants
  localparam SCALE = 12;  // Number of bits to right shift the multiplication results

  // Q12 twiddles for the supported 32-point FFT stages.
  function automatic [2*MEM_WIDTH-1:0] twiddle_lut;
    input [LOG_MAX_N-1:0] m_val;
    input [LOG_MAX_N-2:0] k_val;
    begin
      case (m_val)
        32'd2: begin
          twiddle_lut = {32'sd4096, 32'sd0};
        end
        32'd4: begin
          case (k_val)
            31'd0: twiddle_lut = {32'sd4096, 32'sd0};
            31'd1: twiddle_lut = {32'sd0, -32'sd4096};
            default: twiddle_lut = {32'sd4096, 32'sd0};
          endcase
        end
        32'd8: begin
          case (k_val)
            31'd0: twiddle_lut = {32'sd4096, 32'sd0};
            31'd1: twiddle_lut = {32'sd2896, -32'sd2896};
            31'd2: twiddle_lut = {32'sd0, -32'sd4096};
            31'd3: twiddle_lut = {-32'sd2896, -32'sd2896};
            default: twiddle_lut = {32'sd4096, 32'sd0};
          endcase
        end
        32'd16: begin
          case (k_val)
            31'd0: twiddle_lut = {32'sd4096, 32'sd0};
            31'd1: twiddle_lut = {32'sd3784, -32'sd1567};
            31'd2: twiddle_lut = {32'sd2896, -32'sd2896};
            31'd3: twiddle_lut = {32'sd1567, -32'sd3784};
            31'd4: twiddle_lut = {32'sd0, -32'sd4096};
            31'd5: twiddle_lut = {-32'sd1567, -32'sd3784};
            31'd6: twiddle_lut = {-32'sd2896, -32'sd2897};
            31'd7: twiddle_lut = {-32'sd3784, -32'sd1569};
            default: twiddle_lut = {32'sd4096, 32'sd0};
          endcase
        end
        32'd32: begin
          case (k_val)
            31'd0: twiddle_lut = {32'sd4096, 32'sd0};
            31'd1: twiddle_lut = {32'sd4017, -32'sd799};
            31'd2: twiddle_lut = {32'sd3783, -32'sd1568};
            31'd3: twiddle_lut = {32'sd3404, -32'sd2276};
            31'd4: twiddle_lut = {32'sd2894, -32'sd2897};
            31'd5: twiddle_lut = {32'sd2273, -32'sd3406};
            31'd6: twiddle_lut = {32'sd1564, -32'sd3784};
            31'd7: twiddle_lut = {32'sd795, -32'sd4017};
            31'd8: twiddle_lut = {-32'sd4, -32'sd4095};
            31'd9: twiddle_lut = {-32'sd803, -32'sd4016};
            31'd10: twiddle_lut = {-32'sd1571, -32'sd3782};
            31'd11: twiddle_lut = {-32'sd2279, -32'sd3403};
            31'd12: twiddle_lut = {-32'sd2899, -32'sd2893};
            31'd13: twiddle_lut = {-32'sd3408, -32'sd2272};
            31'd14: twiddle_lut = {-32'sd3786, -32'sd1564};
            31'd15: twiddle_lut = {-32'sd4019, -32'sd796};
            default: twiddle_lut = {32'sd4096, 32'sd0};
          endcase
        end
        default: begin
          twiddle_lut = {32'sd4096, 32'sd0};
        end
      endcase
    end
  endfunction

  assign twiddle_pair = twiddle_lut(m, k);
  assign w_re_lut = twiddle_pair[2*MEM_WIDTH-1:MEM_WIDTH];
  assign w_im_lut = twiddle_pair[MEM_WIDTH-1:0];

  /*----------------------------------------------------------------------------------------
        Iterative (in-place) Cooley-Tukey FFT algorithm - MOORE FSM
    ----------------------------------------------------------------------------------------*/

  // Sequential logic for state transition
  always @(posedge clk) begin
    if (reset_accel) state_reg <= INIT;
    else state_reg <= next_state;
  end

  // Combinational logic for next state computation
  assign butterfly_loop_finished = next_k == half;
  assign base_loop_finished = next_base == number_data;  // Only if N is a power of 2 number
  assign stage_loop_finished = stage == fft_stages;
  assign next_k = k + 1;
  assign next_base = base + m;
  assign next_stage = stage + 1;

  always @(*) begin
    case (state_reg)
      INIT:
      if (enable_accel)
        if (number_data[LOG_MAX_N-1:1] == 0)
          next_state = FINISH;  // If number_data < 2, finish FFT as the input does not change
        else next_state = READ_W_M_RE;
      else next_state = INIT;
      READ_W_M_RE: next_state = READ_W_M_IM;  // Kept for baseline FSM compatibility
      READ_W_M_IM:
      next_state = BUTTERFLY_READ_1_RE;
      BUTTERFLY_READ_1_RE:
      next_state = BUTTERFLY_READ_1_IM;
      BUTTERFLY_READ_1_IM:
      next_state = BUTTERFLY_READ_2_RE;
      BUTTERFLY_READ_2_RE:
      next_state = BUTTERFLY_READ_2_IM;
      BUTTERFLY_READ_2_IM:
      next_state = BUTTERFLY_COMPUTE;
      BUTTERFLY_COMPUTE: next_state = BUTTERFLY_WRITE_1_RE;
      BUTTERFLY_WRITE_1_RE:
      next_state = BUTTERFLY_WRITE_1_IM;
      BUTTERFLY_WRITE_1_IM:
      next_state = BUTTERFLY_WRITE_2_RE;
      BUTTERFLY_WRITE_2_RE:
      next_state = BUTTERFLY_WRITE_2_IM;
      BUTTERFLY_WRITE_2_IM:
      if (butterfly_loop_finished && base_loop_finished && stage_loop_finished) next_state = FINISH;
      else if (butterfly_loop_finished && base_loop_finished) next_state = READ_W_M_RE;
      else next_state = BUTTERFLY_READ_1_RE;
      FINISH:
      if (!enable_accel) next_state = INIT;
      else next_state = FINISH;
      default: next_state = INIT;
    endcase
  end

  // Sequential logic based on the current state
  always @(posedge clk) begin
    if (reset_accel) begin
      stage <= 'b1;
      m <= 'd2;
      half <= 'b1;
      base <= '0;
      k <= '0;
      w_m_re <= '0;
      w_m_im <= '0;
      u_re <= '0;
      u_im <= '0;
      v_re <= '0;
      v_im <= '0;
      e_re <= '0;
      e_im <= '0;
      o_re <= '0;
      o_im <= '0;
      fft_finished <= '0;
    end else begin
      case (state_reg)
        INIT: begin
          stage <= 'b1;
          m <= 'd2;
          half <= 'b1;
          base <= '0;
          k <= '0;
          w_m_re <= '0;
          w_m_im <= '0;
          u_re <= '0;
          u_im <= '0;
          v_re <= '0;
          v_im <= '0;
          e_re <= '0;
          e_im <= '0;
          o_re <= '0;
          o_im <= '0;
          fft_finished <= '0;
        end
        READ_W_M_RE: begin
          w_m_re <= accel_mem_rdata;
        end
        READ_W_M_IM: begin
          w_m_im <= accel_mem_rdata;
        end
        BUTTERFLY_READ_1_RE: begin
          u_re <= accel_mem_rdata;
        end
        BUTTERFLY_READ_1_IM: begin
          u_im <= accel_mem_rdata;
        end
        BUTTERFLY_READ_2_RE: begin
          v_re <= accel_mem_rdata;
        end
        BUTTERFLY_READ_2_IM: begin
          v_im <= accel_mem_rdata;
        end
        BUTTERFLY_COMPUTE: begin
          e_re <= u_re + t_re;
          e_im <= u_im + t_im;
          o_re <= u_re - t_re;
          o_im <= u_im - t_im;
        end
        BUTTERFLY_WRITE_1_RE: ;
        BUTTERFLY_WRITE_1_IM: ;
        BUTTERFLY_WRITE_2_RE: ;
        BUTTERFLY_WRITE_2_IM: begin
          if (butterfly_loop_finished && base_loop_finished) begin
            stage <= next_stage;
            m <= 1 << next_stage;
            half <= 1 << stage;
            base <= '0;
            k <= '0;
          end else if (butterfly_loop_finished) begin
            base <= next_base;
            k <= '0;
          end else begin
            k <= next_k;
          end
        end
        FINISH: begin
          fft_finished <= 1'b1;
        end
        default: ;
      endcase
    end
  end

  // Combinational logic for current state output computation
  assign start_input_address = fft_stages << 1;  // Each complex number uses 2 memory locations
  assign mem_addr_base_k = (base + k) << 1;
  assign mem_addr_base_k_plus_half = (base + k + half) << 1;

  always @(*) begin
    accel_mem_wstrb = 4'b0000;
    accel_mem_wdata = '0;
    accel_mem_addr = '0;
    t_re = '0;
    t_im = '0;

    case (state_reg)
      INIT: ;
      READ_W_M_RE: begin
        accel_mem_addr = (stage - 1) << 1;
      end
      READ_W_M_IM: begin
        accel_mem_addr = ((stage - 1) << 1) + 1;
      end
      BUTTERFLY_READ_1_RE: begin
        accel_mem_addr = start_input_address + mem_addr_base_k;
      end
      BUTTERFLY_READ_1_IM: begin
        accel_mem_addr = start_input_address + mem_addr_base_k + 1;
      end
      BUTTERFLY_READ_2_RE: begin
        accel_mem_addr = start_input_address + mem_addr_base_k_plus_half;
      end
      BUTTERFLY_READ_2_IM: begin
        accel_mem_addr = start_input_address + mem_addr_base_k_plus_half + 1;
      end
      BUTTERFLY_COMPUTE: begin
        t_re = (v_re * w_re_lut - v_im * w_im_lut) >>> SCALE;
        t_im = (v_re * w_im_lut + v_im * w_re_lut) >>> SCALE;
      end
      BUTTERFLY_WRITE_1_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k;
        accel_mem_wdata = e_re;
      end
      BUTTERFLY_WRITE_1_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k + 1;
        accel_mem_wdata = e_im;
      end
      BUTTERFLY_WRITE_2_RE: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k_plus_half;
        accel_mem_wdata = o_re;
      end
      BUTTERFLY_WRITE_2_IM: begin
        accel_mem_wstrb = 4'b1111;
        accel_mem_addr  = start_input_address + mem_addr_base_k_plus_half + 1;
        accel_mem_wdata = o_im;
      end
      FINISH: ;
      default: ;
    endcase
  end
endmodule
