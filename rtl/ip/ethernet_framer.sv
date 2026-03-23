
/* IN DEVELOPMENT - NOT TESTED */
module ethernet_framer #(
    parameter bit INSERT_FCS = 1'b0
) (
    input logic clk,
    input logic rst_n,
    input logic [47:0] dest_mac,
    input logic [47:0] src_mac,
    input logic [15:0] ethertype,  // Ethertypes below 0x0600
    axi4s_if.s payload_in,  // AXI4-Stream interface for payload
    axi4s_if.m framed_out  // AXI4-Stream interface for framed Ethernet output
);

  localparam int PAYLOAD_WIDTH = $bits(payload_in.tdata);
  localparam int PAYLOAD_KEEP = $bits(payload_in.tkeep);
  localparam int OUT_WIDTH = $bits(framed_out.tdata);
  localparam int OUT_KEEP = $bits(framed_out.tkeep);
  localparam int CLOCK_DELAY = PAYLOAD_WIDTH / OUT_WIDTH; // Number of cycles to transfer one payload beat if PAYLOAD_WIDTH > OUT_WIDTH

  logic [(48 + 48 + 16 - 1):0] header; // Ethernet header: dest MAC (48 bits) + src MAC (48 bits) + ethertype (16 bits)

  typedef enum logic [1:0] {
    R_IDLE,
    R_READING,
    R_DONE
  } read_state_t;

  typedef enum logic [3:0] {
    W_IDLE,
    W_HEADER,
    W_PAYLOAD,
    W_FCS,
    W_DONE
  } write_state_t;

  read_state_t  read_state;
  write_state_t write_state;

  generate

    /* Same width payload and out */

    if (PAYLOAD_WIDTH == OUT_WIDTH) begin
      always_ff @(posedge clk, negedge rst_n) begin : output_write
        if (!rst_n) begin
        end else begin
          case (write_state)
            W_IDLE: begin
              framed_out.tvalid <= 1'b0;
              framed_out.tdata  <= '0;
              framed_out.tkeep  <= '0;
              framed_out.tlast  <= 1'b0;
              framed_out.tuser  <= '0;
              if (payload_in.tvalid) begin
                state <= W_HEADER;
              end
            end

            W_HEADER: begin
              framed_out.tvalid <= 1'b1;
              if (PAYLOAD_WIDTH >= 14 * 8) begin
                framed_out.tdata <= {payload_in.tdata[OUT_WIDTH-1 +: (OUT_WIDTH - 14*8)]};
                framed_out.tkeep <= {(OUT_KEEP) {1'b1}};  // All bytes valid for header
                framed_out.tlast <= 1'b0;  // Not last beat
                framed_out.tuser <= '0;  // Set user signal as needed
              end else begin
              end

            end

            default: begin
              framed_out.tvalid <= 1'b0;
              framed_out.tdata  <= '0;
              framed_out.tkeep  <= '0;
              framed_out.tlast  <= 1'b0;
              framed_out.tuser  <= '0;
            end
          endcase
        end
      end
    end

    /* Payload wider than out */

    if (PAYLOAD_WIDTH > OUT_WIDTH) begin
      // Logic to split payload into multiple output beats
      logic [$clog2(
CLOCK_DELAY
)-1:0] cycle_count;  // Counter for tracking cycles when PAYLOAD_WIDTH > OUT_WIDTH
    end


    /* Payload narrower than out */

    if (PAYLOAD_WIDTH < OUT_WIDTH) begin
      // Logic to pack multiple payload beats into one output beat
    end
  endgenerate

endmodule
