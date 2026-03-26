
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

  assign axi4l_conf.arvalid = 1'b0;
  assign axi4l_conf.rready  = 1'b0;
  assign axi4l_conf.araddr  = '0;
  
  logic awvalid;
  logic wvalid;
  logic awaddr;
  logic wdata;
  logic wstrb;
  logic bready;
  logic awready;
  logic wready;
  
  assign axi4l_conf.awvalid = awvalid;
  assign axi4l_conf.wvalid = wvalid;
  assign axi4l_conf.awaddr = awaddr;
  assign axi4l_conf.wdata = wdata;
  assign axi4l_conf.wstrb = wstrb;
  assign axi4l_conf.bready = bready;
  assign awready = axi4l_conf.awready;
  assign wready = axi4l_conf.wready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      awvalid <= 1'b0;
      wvalid <= 1'b0;
      awaddr <= '0;
      wdata <= '0;
      wstrb <= '0;
      bready <= 1'b0;
      w_done <= 1'b0;
      aw_done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          state <= WRITE;
          done <= 1'b0;
          awaddr <= CONF_ADDR;
          wdata <= CONF_DATA;
          wstrb <= {(DATA_WIDTH / 8) {1'b1}};
          awvalid <= 1'b1;
          wvalid <= 1'b1;
          bready <= 1'b1;
        end
        WRITE: begin
          if (awready && awvalid) begin
            aw_done <= 1'b1;
            awvalid <= 1'b0;  // Deassert after handshake
          end
          if (wready && wvalid) begin
            w_done <= 1'b1;
            wvalid <= 1'b0;  // Deassert after handshake
          end

          if ((aw_done || (awvalid && awready))
              && (w_done || (axi4l_conf.wready && wvalid))) begin
            state <= RESP;
          end
        end

        RESP: begin
          if (axi4l_conf.bvalid && bready) begin
            bready <= 1'b0;
            state <= DONE;
          end
        end
        DONE: begin
          done  <= 1'b1;
          state <= DONE;
        end
        d
endmodule
