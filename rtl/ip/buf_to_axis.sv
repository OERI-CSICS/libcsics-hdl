import interfaces::axis_if;

module buf_to_axis #(
    parameter int unsigned STREAM_WIDTH = 32,
    parameter int unsigned BUFFER_SIZE  = 16
) (
    input logic clk,
    input logic rst_n,
    input logic valid_in,
    output logic finished,
    input logic [BUFFER_SIZE-1:0] buf_in,
    axis_if.s axis_out
);

  typedef enum logic [3:0] {
    IDLE = 4'b0000,
    SENDING = 4'b0001,
    DONE = 4'b0010
  } state_t;

  generate

    if (BUFFER_SIZE <= STREAM_WIDTH) begin : gen_small_buffer

      assign axis_out.tkeep = $clog2(BUFFER_SIZE) + 1'b1;
      assign axis_out.tdata = {{(STREAM_WIDTH - BUFFER_SIZE) {1'b0}}, buf_in};

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          axis_out.tvalid <= 1'b0;
          axis_out.tlast <= 1'b0;
          finished <= 1'b0;
        end else begin
          if (axis_out.tready && valid_in) begin
            axis_out.tvalid <= 1'b1;
            axis_out.tlast <= 1'b1;
            finished <= 1'b1;
          end else if (axis_out.tready) begin
            axis_out.tvalid <= 1'b0;
            axis_out.tlast <= 1'b0;
            finished <= 1'b0;
          end
        end
      end
  end else begin : gen_normal_buffer

  end
  endgenerate


endmodule
