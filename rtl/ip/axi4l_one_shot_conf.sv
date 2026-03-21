
module axi4l_one_shot_conf #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter logic [DATA_WIDTH-1:0] CONF_DATA = 32'hDEADBEEF,
    parameter logic [ADDR_WIDTH-1:0] CONF_ADDR = 32'h0000_0000
) (
    input logic clk,
    input logic rst_n,
    output logic done,
    axi4l_if.m axi4l_conf
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    WRITE = 2'b01,
    RESP  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state;

  logic aw_done, w_done;


  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      axi4l_conf.awvalid <= 1'b0;
      axi4l_conf.wvalid <= 1'b0;
      axi4l_conf.awaddr <= '0;
      axi4l_conf.wdata <= '0;
      axi4l_conf.wstrb <= '0;
      axi4l_conf.bready <= 1'b0;
      axi4l_conf.arvalid <= 1'b0;
      axi4l_conf.rready <= 1'b0;
      axi4l_conf.araddr <= '0;
      w_done <= 1'b0;
      aw_done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          state <= WRITE;
          axi4l_conf.awaddr <= CONF_ADDR;
          axi4l_conf.wdata <= CONF_DATA;
          axi4l_conf.wstrb <= {(DATA_WIDTH / 8) {1'b1}};
          axi4l_conf.araddr <= '0;
          axi4l_conf.awvalid <= 1'b1;
          axi4l_conf.wvalid <= 1'b1;
          axi4l_conf.bready <= 1'b1;
        end
        WRITE: begin
          if (axi4l_conf.awready && axi4l_conf.awvalid) begin
            aw_done <= 1'b1;
            axi4l_conf.awvalid <= 1'b0;  // Deassert after handshake
          end
          if (axi4l_conf.wready && axi4l_conf.wvalid) begin
            w_done <= 1'b1;
            axi4l_conf.wvalid <= 1'b0;  // Deassert after handshake
          end

          if ((aw_done || (axi4l_conf.awvalid && axi4l_conf.awready))
              && (w_done || (axi4l_conf.wready && axi4l_conf.wvalid))) begin
            state <= RESP;
          end
        end

        RESP: begin
          if (axi4l_conf.bvalid && axi4l_conf.bready) begin
            done <= 1'b1;
            axi4l_conf.bready <= 1'b0;
            state <= DONE;
          end
        end
        DONE: begin
          done  <= 1'b1;
          state <= DONE;
        end
        d
endmodule
